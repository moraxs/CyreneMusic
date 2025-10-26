import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/player_service.dart';
import '../pages/player_page.dart';
import '../services/playlist_queue_service.dart';
import '../services/play_history_service.dart';
import '../models/track.dart';

/// 迷你播放器组件（底部播放栏）
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: PlayerService(),
      builder: (context, child) {
        final player = PlayerService();
        final track = player.currentTrack;
        final song = player.currentSong;

        // 如果没有正在播放的歌曲，不显示
        if (track == null && song == null) {
          return const SizedBox.shrink();
        }

        final colorScheme = Theme.of(context).colorScheme;

        return GestureDetector(
          excludeFromSemantics: true,
          onTap: () {
            // 点击打开全屏播放器（从底部滑出）
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const PlayerPage(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  // 从底部向上滑出
                  const begin = Offset(0.0, 1.0);  // 从底部开始
                  const end = Offset.zero;          // 到达正常位置
                  const curve = Curves.easeOutCubic;

                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                  var offsetAnimation = animation.drive(tween);

                  return SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 300),
                reverseTransitionDuration: const Duration(milliseconds: 250),
              ),
            );
          },
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // 进度条
                _buildProgressBar(player, colorScheme),
                
                // 播放器控制栏
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 左侧：封面 + 歌曲信息
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildCover(song, track, colorScheme),
                              const SizedBox(width: 12),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 360),
                                child: _buildSongInfo(song, track, context),
                              ),
                            ],
                          ),
                        ),

                        // 中间：上一首/播放(暂停)/下一首
                        Align(
                          alignment: Alignment.center,
                          child: _buildCenterControls(player, colorScheme),
                        ),

                        // 右侧：时长 + 音量 + 歌曲列表按钮
                        Align(
                          alignment: Alignment.centerRight,
                          child: _buildRightPanel(player, colorScheme, context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建进度条
  Widget _buildProgressBar(PlayerService player, ColorScheme colorScheme) {
    final progress = player.duration.inMilliseconds > 0
        ? player.position.inMilliseconds / player.duration.inMilliseconds
        : 0.0;

    return LinearProgressIndicator(
      value: progress,
      minHeight: 2,
      backgroundColor: colorScheme.surfaceContainerHighest,
      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
    );
  }

  /// 构建封面
  Widget _buildCover(dynamic song, dynamic track, ColorScheme colorScheme) {
    final imageUrl = song?.pic ?? track?.picUrl ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: imageUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 48,
                height: 48,
                color: colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 48,
                height: 48,
                color: colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.music_note,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : Container(
              width: 48,
              height: 48,
              color: colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.music_note,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }

  /// 构建歌曲信息
  Widget _buildSongInfo(dynamic song, dynamic track, BuildContext context) {
    final name = song?.name ?? track?.name ?? '未知歌曲';
    final artist = song?.arName ?? track?.artists ?? '未知艺术家';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          artist,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// 中间控制（上一首/播放暂停/下一首）
  Widget _buildCenterControls(PlayerService player, ColorScheme colorScheme) {
    const double skipIconSize = 24;
    const double playIconSize = 28;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            Icons.skip_previous_rounded,
            color: player.hasPrevious ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          ),
          iconSize: skipIconSize,
          onPressed: player.hasPrevious ? () => player.playPrevious() : null,
          tooltip: '上一首',
        ),
        if (player.isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colorScheme.primary,
              ),
            ),
          )
        else
          IconButton(
            icon: Icon(player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
            color: colorScheme.primary,
            iconSize: playIconSize,
            onPressed: () => player.togglePlayPause(),
            tooltip: player.isPlaying ? '暂停' : '播放',
          ),
        IconButton(
          icon: Icon(
            Icons.skip_next_rounded,
            color: player.hasNext ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          ),
          iconSize: skipIconSize,
          onPressed: player.hasNext ? () => player.playNext() : null,
          tooltip: '下一首',
        ),
      ],
    );
  }

  /// 右侧面板（时长 + 音量 + 列表）
  Widget _buildRightPanel(PlayerService player, ColorScheme colorScheme, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 时长
        Text(
          _formatDuration(player.position),
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Text(' / '),
        Text(
          _formatDuration(player.duration),
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        // 音量
        IconButton(
          icon: Icon(_volumeIcon(player.volume), color: colorScheme.onSurface),
          tooltip: '音量',
          onPressed: () => _showVolumeDialog(context, player),
        ),
        // 列表
        IconButton(
          icon: Icon(Icons.queue_music_rounded, color: colorScheme.onSurface),
          tooltip: '播放列表',
          onPressed: () => _showQueueSheet(context),
        ),
      ],
    );
  }

  IconData _volumeIcon(double volume) {
    if (volume == 0) return Icons.volume_off_rounded;
    if (volume < 0.5) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  Future<void> _showVolumeDialog(BuildContext context, PlayerService player) async {
    double temp = player.volume;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('音量'),
          content: StatefulBuilder(
            builder: (context, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    value: temp,
                    onChanged: (v) {
                      setLocal(() => temp = v);
                      player.setVolume(v);
                    },
                  ),
                  Text('${(temp * 100).toInt()}%'),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showQueueSheet(BuildContext context) async {
    final queueService = PlaylistQueueService();
    final history = PlayHistoryService().history;
    final currentTrack = PlayerService().currentTrack;

    // 与全屏播放器一致：优先展示播放队列，否则展示播放历史
    final bool hasQueue = queueService.hasQueue;
    final List<dynamic> displayList = hasQueue
        ? queueService.queue
        : history.map((h) => h.toTrack()).toList();

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: displayList.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text('播放列表为空', style: Theme.of(context).textTheme.bodyMedium),
                  ),
                )
              : ListView.separated(
                  itemCount: displayList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final item = displayList[i];
                    final Track t = item as Track; // displayList 已保证为 Track
                    final isCurrent = currentTrack != null &&
                        t.id.toString() == currentTrack.id.toString() &&
                        t.source == currentTrack.source;

                    return ListTile(
                      tileColor: isCurrent ? Theme.of(context).colorScheme.surfaceContainerHigh : null,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: t.picUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(width: 44, height: 44, color: Colors.black12),
                          errorWidget: (context, url, error) => Container(
                            width: 44,
                            height: 44,
                            color: Colors.black12,
                            child: Icon(Icons.music_note, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                      title: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(t.artists, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        PlayerService().playTrack(t);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('正在播放: ${t.name}'), duration: const Duration(seconds: 1)),
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  /// 格式化时长
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

