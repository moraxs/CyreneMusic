import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/netease_recommend_service.dart';
import '../models/track.dart';
import '../services/player_service.dart';
import '../services/playlist_queue_service.dart';
import 'daily_recommend_detail_page.dart';
import 'discover_playlist_detail_page.dart';

/// 首页 - 为你推荐 Tab 内容
class HomeForYouTab extends StatefulWidget {
  const HomeForYouTab({super.key, this.onOpenPlaylistDetail});

  final void Function(int playlistId)? onOpenPlaylistDetail;

  @override
  State<HomeForYouTab> createState() => _HomeForYouTabState();
}

class _HomeForYouTabState extends State<HomeForYouTab> {
  late Future<_ForYouData> _future;
  bool _showDailyDetail = false;
  
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ForYouData> _load() async {
    final svc = NeteaseRecommendService();
    final dailySongs = await svc.fetchDailySongs();
    final fm = await svc.fetchPersonalFm();
    final dailyPlaylists = await svc.fetchDailyPlaylists();
    final personalized = await svc.fetchPersonalizedPlaylists(limit: 12);
    final radar = await svc.fetchRadarPlaylists();
    final newsongs = await svc.fetchPersonalizedNewsongs(limit: 10);
    return _ForYouData(
      dailySongs: dailySongs,
      fm: fm,
      dailyPlaylists: dailyPlaylists,
      personalizedPlaylists: personalized,
      radarPlaylists: radar,
      personalizedNewsongs: newsongs,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<_ForYouData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text('加载失败：${snapshot.error ?? ''}')));
        }
        final data = snapshot.data!;
        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _future = _load();
                });
                await _future;
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(title: '每日推荐'),
                  _DailyRecommendCard(
                    tracks: data.dailySongs,
                    onOpenDetail: () => setState(() => _showDailyDetail = true),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(title: '私人FM'),
                  _PersonalFm(list: data.fm),
                  const SizedBox(height: 24),
                  _SectionTitle(title: '每日推荐歌单'),
                  _PlaylistGrid(
                    list: data.dailyPlaylists,
                    onTap: (id) => widget.onOpenPlaylistDetail?.call(id),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(title: '专属歌单'),
                  _PlaylistGrid(
                    list: data.personalizedPlaylists,
                    onTap: (id) => widget.onOpenPlaylistDetail?.call(id),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(title: '雷达歌单'),
                  _PlaylistGrid(
                    list: data.radarPlaylists,
                    onTap: (id) => widget.onOpenPlaylistDetail?.call(id),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(title: '个性化新歌'),
                  _NewsongList(list: data.personalizedNewsongs),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            ),

            if (_showDailyDetail)
              Positioned.fill(
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: DailyRecommendDetailPage(
                    tracks: data.dailySongs,
                    embedded: true,
                    onClose: () => setState(() => _showDailyDetail = false),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ForYouData {
  final List<Map<String, dynamic>> dailySongs;
  final List<Map<String, dynamic>> fm;
  final List<Map<String, dynamic>> dailyPlaylists;
  final List<Map<String, dynamic>> personalizedPlaylists;
  final List<Map<String, dynamic>> radarPlaylists;
  final List<Map<String, dynamic>> personalizedNewsongs;
  _ForYouData({
    required this.dailySongs,
    required this.fm,
    required this.dailyPlaylists,
    required this.personalizedPlaylists,
    required this.radarPlaylists,
    required this.personalizedNewsongs,
  });
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}

/// 每日推荐卡片（点击跳转到详情页）
class _DailyRecommendCard extends StatelessWidget {
  final List<Map<String, dynamic>> tracks;
  final VoidCallback? onOpenDetail;
  const _DailyRecommendCard({required this.tracks, this.onOpenDetail});
  
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    // 获取前4首歌曲的封面
    final coverImages = tracks.take(4).map((s) {
      final al = (s['al'] ?? s['album'] ?? {}) as Map<String, dynamic>;
      return (al['picUrl'] ?? '').toString();
    }).where((url) => url.isNotEmpty).toList();
    
    return Card(
      clipBehavior: Clip.antiAlias,
      color: cs.surfaceContainerHighest,
      child: InkWell(
        onTap: () {
          if (onOpenDetail != null) {
            onOpenDetail!();
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => DailyRecommendDetailPage(tracks: tracks),
              ),
            );
          }
        },
        child: Container(
          height: 200,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // 左侧：封面网格（2x2）
              SizedBox(
                width: 160,
                height: 160,
                child: _buildCoverGrid(context, coverImages),
              ),
              const SizedBox(width: 24),
              // 右侧：信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '每日推荐',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${tracks.length} 首歌曲',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 16,
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 20,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '根据你的音乐品味每日更新',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 14,
                                color: cs.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: FilledButton.icon(
                          onPressed: () {
                            if (onOpenDetail != null) {
                              onOpenDetail!();
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => DailyRecommendDetailPage(tracks: tracks),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.chevron_right, size: 20),
                          label: const Text(
                            '查看全部',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 构建封面网格（2x2）
  Widget _buildCoverGrid(BuildContext context, List<String> coverImages) {
    final cs = Theme.of(context).colorScheme;
    
    // 填充到4张图片
    while (coverImages.length < 4) {
      coverImages.add('');
    }
    
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        final url = coverImages[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: url.isEmpty
              ? Container(
                  color: cs.surfaceContainerHighest,
                  child: Icon(
                    Icons.music_note,
                    color: cs.onSurface.withOpacity(0.3),
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: cs.surfaceContainerHighest,
                    child: Icon(
                      Icons.music_note,
                      color: cs.onSurface.withOpacity(0.3),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: cs.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image,
                      color: cs.onSurface.withOpacity(0.3),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _PersonalFm extends StatelessWidget {
  final List<Map<String, dynamic>> list;
  const _PersonalFm({required this.list});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (list.isEmpty) return Text('暂无数据', style: Theme.of(context).textTheme.bodySmall);
    return AnimatedBuilder(
      animation: PlayerService(),
      builder: (context, _) {
        // 选择展示的歌曲：优先显示当前播放且属于此FM列表的歌曲，否则显示第一首
        Map<String, dynamic> display = list.first;
        final current = PlayerService().currentTrack;
        if (current != null && current.source == MusicSource.netease) {
          for (final m in list) {
            final id = (m['id'] ?? (m['song'] != null ? (m['song'] as Map<String, dynamic>)['id'] : null)) as dynamic;
            if (id != null && id.toString() == current.id.toString()) {
              display = m;
              break;
            }
          }
        }

        final album = (display['album'] ?? display['al'] ?? {}) as Map<String, dynamic>;
        final artists = (display['artists'] ?? display['ar'] ?? []) as List<dynamic>;
        final artistsText = artists.map((e) => (e as Map<String, dynamic>)['name']?.toString() ?? '').where((e) => e.isNotEmpty).join('/');
        final pic = (album['picUrl'] ?? '').toString();

        // 仅当当前播放或当前队列属于此FM列表时，才把状态视为“播放中”
        final fmTracks = _convertListToTracks(list);
        final isFmCurrent = _currentTrackInList(fmTracks);
        final isFmQueue = _isSameQueueAs(fmTracks);
        final isFmPlaying = PlayerService().isPlaying && (isFmCurrent || isFmQueue);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(pic, width: 120, height: 120, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(display['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(artistsText, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () async {
                        final tracks = fmTracks;
                        if (tracks.isEmpty) return;
                        final ps = PlayerService();
                        if (isFmPlaying) {
                          await ps.pause();
                        } else if (ps.isPaused && (isFmQueue || isFmCurrent)) {
                          await ps.resume();
                        } else {
                          PlaylistQueueService().setQueue(tracks, 0, QueueSource.playlist);
                          await ps.playTrack(tracks.first);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('开始播放私人FM')),
                            );
                          }
                        }
                      },
                      style: IconButton.styleFrom(
                        hoverColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                        focusColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
                        overlayColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(isFmPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: cs.onSurface),
                      tooltip: isFmPlaying ? '暂停' : '播放',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () async {
                        final tracks = fmTracks;
                        if (tracks.isEmpty) return;
                        if (_isSameQueueAs(tracks)) {
                          await PlayerService().playNext();
                        } else {
                          final startIndex = tracks.length > 1 ? 1 : 0;
                          PlaylistQueueService().setQueue(tracks, startIndex, QueueSource.playlist);
                          await PlayerService().playTrack(tracks[startIndex]);
                        }
                      },
                      style: IconButton.styleFrom(
                        hoverColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                        focusColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
                        overlayColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(Icons.skip_next_rounded, color: cs.onSurface),
                      tooltip: '下一首',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Track> _convertListToTracks(List<Map<String, dynamic>> src) {
    return src.map((m) => _convertToTrack(m)).toList();
  }

  Track _convertToTrack(Map<String, dynamic> song) {
    final album = (song['al'] ?? song['album'] ?? {}) as Map<String, dynamic>;
    final artists = (song['ar'] ?? song['artists'] ?? []) as List<dynamic>;
    return Track(
      id: song['id'] ?? 0,
      name: song['name']?.toString() ?? '',
      artists: artists
          .map((e) => (e as Map<String, dynamic>)['name']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .join(' / '),
      album: album['name']?.toString() ?? '',
      picUrl: album['picUrl']?.toString() ?? '',
      source: MusicSource.netease,
    );
  }

  bool _isSameQueueAs(List<Track> tracks) {
    final q = PlaylistQueueService().queue;
    if (q.length != tracks.length) return false;
    for (var i = 0; i < q.length; i++) {
      if (q[i].id.toString() != tracks[i].id.toString() || q[i].source != tracks[i].source) {
        return false;
      }
    }
    return true;
  }

  bool _currentTrackInList(List<Track> tracks) {
    final ct = PlayerService().currentTrack;
    if (ct == null) return false;
    return tracks.any((t) => t.id.toString() == ct.id.toString() && t.source == ct.source);
  }
}

class _PlaylistGrid extends StatelessWidget {
  final List<Map<String, dynamic>> list;
  final void Function(int id)? onTap;
  const _PlaylistGrid({required this.list, this.onTap});
  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) return Text('暂无数据', style: Theme.of(context).textTheme.bodySmall);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 0.68,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final p = list[i];
        final pic = (p['picUrl'] ?? p['coverImgUrl'] ?? '').toString();
        final idVal = p['id'];
        final id = int.tryParse(idVal?.toString() ?? '');
        return InkWell(
          onTap: id != null && onTap != null ? () => onTap!(id) : null,
          child: _HoverPlaylistCard(
            name: p['name']?.toString() ?? '',
            picUrl: pic,
            description: (p['description'] ?? p['copywriter'] ?? '').toString(),
          ),
        );
      },
    );
  }
}

class _HoverPlaylistCard extends StatefulWidget {
  final String name;
  final String picUrl;
  final String description;
  const _HoverPlaylistCard({required this.name, required this.picUrl, required this.description});

  @override
  State<_HoverPlaylistCard> createState() => _HoverPlaylistCardState();
}

class _HoverPlaylistCardState extends State<_HoverPlaylistCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: cs.shadow.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 封面图片（容器固定，内部放大10%）
                      SizedBox.expand(
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOut,
                          scale: _hovering ? 1.10 : 1.0,
                          child: CachedNetworkImage(
                            imageUrl: widget.picUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: cs.surfaceContainerHighest,
                              child: Icon(
                                Icons.music_note,
                                color: cs.onSurface.withOpacity(0.3),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: cs.surfaceContainerHighest,
                              child: Icon(
                                Icons.broken_image,
                                color: cs.onSurface.withOpacity(0.3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 自底部滑出的渐变遮罩 + 描述
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          offset: _hovering ? Offset.zero : const Offset(0, 1),
                          child: FractionallySizedBox(
                            widthFactor: 1.0,
                            heightFactor: 0.38,
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.0),
                                    Colors.black.withOpacity(0.65),
                                  ],
                                ),
                              ),
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                              child: Align(
                                alignment: Alignment.bottomLeft,
                                child: Text(
                                  (widget.description.isNotEmpty ? widget.description : widget.name),
                                  style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.2),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      widget.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      textAlign: TextAlign.left,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsongList extends StatelessWidget {
  final List<Map<String, dynamic>> list;
  const _NewsongList({required this.list});
  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) return Text('暂无数据', style: Theme.of(context).textTheme.bodySmall);
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final s = list[i];
        final song = (s['song'] ?? s);
        final al = (song['al'] ?? song['album'] ?? {}) as Map<String, dynamic>;
        final ar = (song['ar'] ?? song['artists'] ?? []) as List<dynamic>;
        final pic = (al['picUrl'] ?? '').toString();
        final artists = ar.map((e) => (e as Map<String, dynamic>)['name']?.toString() ?? '').where((e) => e.isNotEmpty).join('/');
        return ListTile(
          leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(pic, width: 48, height: 48, fit: BoxFit.cover)),
          title: Text(song['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(artists, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      },
    );
  }
}


