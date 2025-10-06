import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/sleep_timer_service.dart';
import '../../services/playlist_service.dart';
import '../../services/playlist_queue_service.dart';
import '../../services/play_history_service.dart';
import '../../services/player_service.dart';
import '../../models/track.dart';

/// 移动端播放器对话框工具类
/// 包含睡眠定时器、添加到歌单、播放列表等对话框
class MobilePlayerDialogs {
  /// 显示睡眠定时器对话框
  static void showSleepTimer(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const MobileSleepTimerDialog(),
    );
  }

  /// 显示添加到歌单对话框
  static void showAddToPlaylist(BuildContext context, Track track) {
    final playlistService = PlaylistService();
    
    // 确保已加载歌单列表
    if (playlistService.playlists.isEmpty) {
      playlistService.loadPlaylists();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AnimatedBuilder(
        animation: playlistService,
        builder: (context, child) {
          final playlists = playlistService.playlists;
          
          if (playlists.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            );
          }

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text(
                        '添加到歌单',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: playlist.isDefault
                              ? Colors.red.withOpacity(0.2)
                              : Colors.blue.withOpacity(0.2),
                          child: Icon(
                            playlist.isDefault
                                ? Icons.favorite
                                : Icons.queue_music,
                            color: playlist.isDefault ? Colors.red : Colors.blue,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          playlist.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '${playlist.trackCount} 首歌曲',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          final success = await playlistService.addTrackToPlaylist(
                            playlist.id,
                            track,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? '已添加到「${playlist.name}」'
                                      : '添加失败',
                                ),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 显示播放列表底部抽屉
  static void showPlaylistBottomSheet(BuildContext context) {
    final queueService = PlaylistQueueService();
    final history = PlayHistoryService().history;
    final currentTrack = PlayerService().currentTrack;
    
    // 优先使用播放队列，如果没有队列则使用播放历史
    final bool hasQueue = queueService.hasQueue;
    final List<dynamic> displayList = hasQueue 
        ? queueService.queue 
        : history.map((h) => h.toTrack()).toList();
    final String listTitle = hasQueue 
        ? '播放队列 (${queueService.source.name})' 
        : '播放历史';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 拖动指示器
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.queue_music,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          listTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${displayList.length} 首',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          tooltip: '关闭',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const Divider(color: Colors.white24, height: 1),
              
              // 播放列表
              Expanded(
                child: displayList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.music_off,
                              size: 64,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '播放列表为空',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: displayList.length,
                        itemBuilder: (context, index) {
                          final item = displayList[index];
                          // 转换为 Track
                          final track = item is Track ? item : (item as PlayHistoryItem).toTrack();
                          final isCurrentTrack = currentTrack != null &&
                              track.id.toString() == currentTrack.id.toString() &&
                              track.source == currentTrack.source;

                          return _buildPlaylistItem(context, track, index, isCurrentTrack);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 构建播放列表项
  static Widget _buildPlaylistItem(BuildContext context, Track track, int index, bool isCurrentTrack) {
    return Material(
      color: isCurrentTrack 
          ? Colors.white.withOpacity(0.1) 
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          PlayerService().playTrack(track);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('正在播放: ${track.name}'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // 序号或正在播放图标
              SizedBox(
                width: 32,
                child: isCurrentTrack
                    ? const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 20,
                      )
                    : Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),

              const SizedBox(width: 8),

              // 封面
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: track.picUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 48,
                    height: 48,
                    color: Colors.white12,
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 48,
                    height: 48,
                    color: Colors.white12,
                    child: const Icon(
                      Icons.music_note,
                      color: Colors.white38,
                      size: 24,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // 歌曲信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCurrentTrack ? Colors.white : Colors.white.withOpacity(0.87),
                        fontSize: 15,
                        fontWeight: isCurrentTrack ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artists,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
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
}

/// 睡眠定时器对话框（移动端版本）
class MobileSleepTimerDialog extends StatefulWidget {
  const MobileSleepTimerDialog({super.key});

  @override
  State<MobileSleepTimerDialog> createState() => _MobileSleepTimerDialogState();
}

class _MobileSleepTimerDialogState extends State<MobileSleepTimerDialog> {
  int _selectedTabIndex = 0; // 0: 时长, 1: 时间
  int _selectedDuration = 30; // 默认30分钟

  // 预设时长选项（分钟）
  final List<int> _durationOptions = [15, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final timer = SleepTimerService();

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('睡眠定时器'),
          if (timer.isActive)
            TextButton.icon(
              onPressed: () {
                timer.cancel();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('定时器已取消')),
                );
              },
              icon: const Icon(Icons.cancel),
              label: const Text('取消定时'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 当前定时器状态
            if (timer.isActive)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '定时器运行中',
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedBuilder(
                            animation: timer,
                            builder: (context, child) {
                              return Text(
                                '剩余时间: ${timer.remainingTimeString}',
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    if (timer.isActive)
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          timer.extend(15);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已延长15分钟')),
                          );
                        },
                        tooltip: '延长15分钟',
                        color: colorScheme.onPrimaryContainer,
                      ),
                  ],
                ),
              ),

            // 标签选择器
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('播放时长'),
                  icon: Icon(Icons.timer_outlined),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('指定时间'),
                  icon: Icon(Icons.schedule),
                ),
              ],
              selected: {_selectedTabIndex},
              onSelectionChanged: (Set<int> selected) {
                setState(() {
                  _selectedTabIndex = selected.first;
                });
              },
            ),

            const SizedBox(height: 24),

            // 内容区域
            if (_selectedTabIndex == 0) _buildDurationTab(colorScheme),
            if (_selectedTabIndex == 1) _buildTimeTab(context, colorScheme),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }

  /// 时长选择标签页
  Widget _buildDurationTab(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择播放时长',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _durationOptions.map((duration) {
            final isSelected = duration == _selectedDuration;
            return FilterChip(
              label: Text('${duration}分钟'),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedDuration = duration;
                  });
                  SleepTimerService().setTimerByDuration(duration);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('定时器已设置: ${duration}分钟后停止播放'),
                    ),
                  );
                }
              },
              showCheckmark: false,
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 时间选择标签页
  Widget _buildTimeTab(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择停止时间',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              final TimeOfDay? selectedTime = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
                builder: (context, child) {
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      alwaysUse24HourFormat: true,
                    ),
                    child: child!,
                  );
                },
              );

              if (selectedTime != null) {
                SleepTimerService().setTimerByTime(selectedTime);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '定时器已设置: ${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')} 停止播放',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.access_time),
            label: const Text('选择时间'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '音乐将在指定时间自动停止播放',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}
