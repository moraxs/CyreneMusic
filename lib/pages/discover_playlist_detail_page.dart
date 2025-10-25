import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/netease_discover_service.dart';
import '../models/netease_discover.dart';
import '../models/track.dart';
import '../widgets/track_list_tile.dart';
import '../services/playlist_queue_service.dart';
import '../services/player_service.dart';
import '../services/auth_service.dart';
import '../pages/auth/auth_page.dart';

class DiscoverPlaylistDetailPage extends StatelessWidget {
  final int playlistId;
  const DiscoverPlaylistDetailPage({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        title: const Text('歌单详情'),
      ),
      body: DiscoverPlaylistDetailContent(playlistId: playlistId),
    );
  }
}

class DiscoverPlaylistDetailContent extends StatefulWidget {
  final int playlistId;
  const DiscoverPlaylistDetailContent({super.key, required this.playlistId});

  @override
  State<DiscoverPlaylistDetailContent> createState() => _DiscoverPlaylistDetailContentState();
}

class _DiscoverPlaylistDetailContentState extends State<DiscoverPlaylistDetailContent> {
  NeteasePlaylistDetail? _detail;
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
    final detail = await NeteaseDiscoverService().fetchPlaylistDetail(widget.playlistId);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _loading = false;
      if (detail == null) {
        _error = NeteaseDiscoverService().errorMessage ?? '加载失败';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }

    final detail = _detail!;
    final List<Track> allTracks = detail.tracks.map((t) => Track(
      id: t.id,
      name: t.name,
      artists: t.artists,
      album: t.album,
      picUrl: t.picUrl,
      source: MusicSource.netease,
    )).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: detail.coverImgUrl,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text('by ${detail.creator}', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: -6,
                      children: detail.tags.map((t) => Chip(label: Text(t))).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (detail.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              detail.description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: detail.tracks.length,
            itemBuilder: (context, index) {
              final track = allTracks[index];
              return TrackListTile(
                track: track,
                index: index,
                onTap: () async {
                  final ok = await _checkLoginStatus();
                  if (!ok) return;
                  // 替换播放队列为当前歌单
                  PlaylistQueueService().setQueue(allTracks, index, QueueSource.playlist);
                  // 播放所点歌曲
                  await PlayerService().playTrack(track);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('正在加载：${track.name}'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
              );
            },
          ),
        )
      ],
    );
  }

  Future<bool> _checkLoginStatus() async {
    if (AuthService().isLoggedIn) return true;
    final shouldLogin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('需要登录'),
          ],
        ),
        content: const Text('此功能需要登录后才能使用，是否前往登录？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('去登录'),
          ),
        ],
      ),
    );
    if (shouldLogin == true && mounted) {
      final result = await showAuthDialog(context);
      return result == true && AuthService().isLoggedIn;
    }
    return false;
  }
}


