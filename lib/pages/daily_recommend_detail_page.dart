import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/player_service.dart';
import '../services/playlist_queue_service.dart';
import '../models/track.dart';

/// 每日推荐详情页
class DailyRecommendDetailPage extends StatelessWidget {
  final List<Map<String, dynamic>> tracks;
  final bool embedded;
  final VoidCallback? onClose;

  const DailyRecommendDetailPage({
    super.key,
    required this.tracks,
    this.embedded = false,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (embedded) {
      // 覆盖层嵌入模式：与歌单详情覆盖层保持一致的层级与二级菜单
      return SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 顶部栏：返回 + 标题
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () {
                      if (onClose != null) {
                        onClose!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    tooltip: '返回',
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '每日推荐',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: PrimaryScrollController.none(
                child: tracks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.music_note_outlined,
                              size: 64,
                              color: colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '暂无推荐',
                              style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        itemCount: tracks.length,
                        itemBuilder: (context, index) => _buildTrackTile(context, tracks[index], index),
                      ),
              ),
            ),
          ],
        ),
      );
    }

    // 独立页面模式
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: colorScheme.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (onClose != null) {
                  onClose!();
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '首页',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      Text(
                        '为你推荐',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      Text(
                        '每日推荐',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '每日推荐',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: FilledButton.icon(
                  onPressed: () => _playAll(context),
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: const Text('播放全部'),
                ),
              ),
            ],
          ),
          tracks.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.music_note_outlined,
                          size: 64,
                          color: colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无推荐',
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildTrackTile(context, tracks[index], index),
                      childCount: tracks.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  /// 构建歌曲列表项
  Widget _buildTrackTile(BuildContext context, Map<String, dynamic> song, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final album = (song['al'] ?? song['album'] ?? {}) as Map<String, dynamic>;
    final artists = (song['ar'] ?? song['artists'] ?? []) as List<dynamic>;
    final picUrl = (album['picUrl'] ?? '').toString();
    final artistsText = artists
        .map((e) => (e as Map<String, dynamic>)['name']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .join(' / ');
    final songName = song['name']?.toString() ?? '';
    final songId = song['id'];

    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _playSong(context, song, index),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // 序号
              SizedBox(
                width: 32,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              // 封面
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: picUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.music_note,
                      color: colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image,
                      color: colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // 歌曲信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      songName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      artistsText,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // 操作按钮
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showTrackMenu(context, song),
                tooltip: '更多',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 播放单曲
  void _playSong(BuildContext context, Map<String, dynamic> song, int index) async {
    try {
      final track = _convertToTrack(song);
      final allTracks = tracks.map((s) => _convertToTrack(s)).toList();
      
      // 设置播放队列
      PlaylistQueueService().setQueue(allTracks, index, QueueSource.playlist);
      
      // 播放歌曲
      await PlayerService().playTrack(track);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('开始播放: ${track.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('播放失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 播放全部
  void _playAll(BuildContext context) async {
    if (tracks.isEmpty) return;
    
    try {
      final allTracks = tracks.map((s) => _convertToTrack(s)).toList();
      
      // 设置播放队列
      PlaylistQueueService().setQueue(allTracks, 0, QueueSource.playlist);
      
      // 播放第一首
      await PlayerService().playTrack(allTracks.first);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('开始播放全部'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('播放失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 显示歌曲菜单
  void _showTrackMenu(BuildContext context, Map<String, dynamic> song) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('添加到播放队列'),
              onTap: () {
                Navigator.pop(context);
                try {
                  final track = _convertToTrack(song);
                  final currentQueue = PlaylistQueueService().queue;
                  final newQueue = [...currentQueue, track];
                  PlaylistQueueService().setQueue(
                    newQueue,
                    PlaylistQueueService().currentIndex,
                    QueueSource.playlist,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已添加到播放队列')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('添加失败: $e')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const Text('收藏'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('收藏功能开发中...')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 转换为 Track 对象
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
}

