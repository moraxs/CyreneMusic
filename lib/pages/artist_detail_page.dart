import 'package:flutter/material.dart';
import '../services/netease_artist_service.dart';
import '../services/player_service.dart';
import '../models/track.dart';
import 'album_detail_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ArtistDetailPage extends StatefulWidget {
  final int artistId;
  const ArtistDetailPage({super.key, required this.artistId});

  @override
  State<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends State<ArtistDetailPage> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final data = await NeteaseArtistDetailService().fetchArtistDetail(widget.artistId);
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
      if (data == null) _error = '加载失败';
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('歌手详情'),
        backgroundColor: cs.surface,
      ),
      body: ArtistDetailContent(artistId: widget.artistId),
    );
  }
}

/// 胶囊样式 Tabs
class _CapsuleTabs extends StatelessWidget {
  final List<String> tabs;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  const _CapsuleTabs({required this.tabs, required this.currentIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.surfaceContainerHighest;
    final pillColor = cs.primary;
    final selFg = cs.onPrimary;
    final unSelFg = cs.onSurfaceVariant;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = 48.0; // 提高高度
        final padding = 5.0;
        final radius = height / 2;
        final totalWidth = constraints.maxWidth;
        final count = tabs.length;
        final tabWidth = totalWidth / count;

        return SizedBox(
          height: height,
          child: Stack(
            children: [
              // 背景容器
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
              ),
              // 滑动胶囊指示器（位置与大小均有动画）
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                top: padding,
                bottom: padding,
                left: padding + currentIndex * (tabWidth - padding * 2),
                width: tabWidth - padding * 2,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOutCubic,
                  decoration: BoxDecoration(
                    color: pillColor,
                    borderRadius: BorderRadius.circular(radius - padding),
                    boxShadow: [
                      BoxShadow(
                        color: pillColor.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              // 标签点击与文字
              Row(
                children: List.generate(count, (i) {
                  final selected = i == currentIndex;
                  return SizedBox(
                    width: tabWidth,
                    height: height,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(radius),
                      onTap: () => onChanged(i),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeInOut,
                          style: TextStyle(
                            color: selected ? selFg : unSelFg,
                            fontWeight: FontWeight.w600,
                          ),
                          child: Text(tabs[i]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SongsListView extends StatelessWidget {
  final List<dynamic> songs;
  const _SongsListView({super.key, required this.songs});

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return Center(
        child: Text('暂无歌曲', style: Theme.of(context).textTheme.bodySmall),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final m = songs[index] as Map<String, dynamic>;
        final track = Track(
          id: m['id'],
          name: m['name']?.toString() ?? '',
          artists: m['artists']?.toString() ?? '',
          album: m['album']?.toString() ?? '',
          picUrl: m['picUrl']?.toString() ?? '',
          source: MusicSource.netease,
        );
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: track.picUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
            ),
            title: Text(track.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${track.artists} • ${track.album}', maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.play_arrow),
            onTap: () => PlayerService().playTrack(track),
          ),
        );
      },
    );
  }
}

class _AlbumsListView extends StatelessWidget {
  final List<dynamic> albums;
  final void Function(int albumId)? onOpenAlbum;
  const _AlbumsListView({super.key, required this.albums, this.onOpenAlbum});

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return Center(
        child: Text('暂无专辑', style: Theme.of(context).textTheme.bodySmall),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final a = albums[index] as Map<String, dynamic>;
        final cover = (a['coverImgUrl'] ?? '') as String;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(imageUrl: cover, width: 56, height: 56, fit: BoxFit.cover),
            ),
            title: Text(a['name']?.toString() ?? ''),
            subtitle: Text((a['company']?.toString() ?? '').isEmpty ? '' : a['company'].toString()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              final id = (a['id'] as num?)?.toInt();
              if (id != null) {
                if (onOpenAlbum != null) {
                  onOpenAlbum!(id);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AlbumDetailPage(albumId: id)),
                  );
                }
              }
            },
          ),
        );
      },
    );
  }
}

class _SongsThumbView extends StatelessWidget {
  final List<dynamic> songs;
  const _SongsThumbView({super.key, required this.songs});

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return Center(
        child: Text('暂无歌曲', style: Theme.of(context).textTheme.bodySmall),
      );
    }
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: songs.map((s0) {
          final m = s0 as Map<String, dynamic>;
          final name = m['name']?.toString() ?? '';
          final artists = m['artists']?.toString() ?? '';
          final album = m['album']?.toString() ?? '';
          final pic = m['picUrl']?.toString() ?? '';
          final track = Track(id: m['id'], name: name, artists: artists, album: album, picUrl: pic, source: MusicSource.netease);
          return ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 260, maxWidth: 440),
            child: InkWell(
              onTap: () => PlayerService().playTrack(track),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(imageUrl: pic, width: 80, height: 80, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text(artists, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 6),
                          Text(album, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.play_arrow),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AlbumsThumbView extends StatelessWidget {
  final List<dynamic> albums;
  final void Function(int albumId)? onOpenAlbum;
  const _AlbumsThumbView({super.key, required this.albums, this.onOpenAlbum});

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return Center(
        child: Text('暂无专辑', style: Theme.of(context).textTheme.bodySmall),
      );
    }
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: albums.map((a0) {
          final a = a0 as Map<String, dynamic>;
          final id = (a['id'] as num?)?.toInt();
          final cover = (a['coverImgUrl'] ?? '') as String;
          final name = (a['name'] ?? '').toString();
          final sub = (a['company'] ?? '').toString();
          return ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 260, maxWidth: 440),
            child: InkWell(
              onTap: () {
                if (id != null) {
                  if (onOpenAlbum != null) {
                    onOpenAlbum!(id);
                  } else {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AlbumDetailPage(albumId: id)));
                  }
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(imageUrl: cover, width: 80, height: 80, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
/// 无 AppBar 的内容组件，供悬浮窗使用
class ArtistDetailContent extends StatefulWidget {
  final int artistId;
  final void Function(int albumId)? onOpenAlbum;
  const ArtistDetailContent({super.key, required this.artistId, this.onOpenAlbum});

  @override
  State<ArtistDetailContent> createState() => _ArtistDetailContentState();
}

class _ArtistDetailContentState extends State<ArtistDetailContent> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  int _tabIndex = 0; // 0: 歌曲, 1: 专辑
  bool _useGrid = false; // false: 列表, true: 缩略图

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final data = await NeteaseArtistDetailService().fetchArtistDetail(widget.artistId);
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
      if (data == null) _error = '加载失败';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    final artist = _data!['artist'] as Map<String, dynamic>? ?? {};
    final albums = (_data!['albums'] as List<dynamic>? ?? []) as List<dynamic>;
    final songs = (_data!['songs'] as List<dynamic>? ?? []) as List<dynamic>;

    return Column(
      children: [
        // 顶部信息
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundImage: NetworkImage((artist['img1v1Url'] ?? artist['picUrl'] ?? '') as String),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(artist['name']?.toString() ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(artist['briefDesc']?.toString() ?? artist['description']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 胶囊 Tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _CapsuleTabs(
            tabs: [
              '歌曲',
              '专辑',
            ],
            currentIndex: _tabIndex,
            onChanged: (i) => setState(() => _tabIndex = i),
          ),
        ),

        const SizedBox(height: 8),

        // 视图模式切换（列表/缩略图）
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Icon(Icons.view_list, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Switch(
                value: _useGrid,
                onChanged: (v) => setState(() => _useGrid = v),
              ),
              const SizedBox(width: 8),
              Icon(Icons.grid_view, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const Spacer(),
              Text(_useGrid ? '缩略图' : '列表', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),

        // 内容列表
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: _tabIndex == 0
                ? (_useGrid
                    ? _SongsThumbView(key: const ValueKey('artist_songs_grid'), songs: songs)
                    : _SongsListView(key: const ValueKey('artist_songs_list'), songs: songs))
                : (_useGrid
                    ? _AlbumsThumbView(key: const ValueKey('artist_albums_grid'), albums: albums, onOpenAlbum: widget.onOpenAlbum)
                    : _AlbumsListView(key: const ValueKey('artist_albums_list'), albums: albums, onOpenAlbum: widget.onOpenAlbum)),
          ),
        ),
      ],
    );
  }
}


