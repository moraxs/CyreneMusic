import 'package:flutter/material.dart';
import '../../services/sleep_timer_service.dart';
import '../../services/playlist_service.dart';
import '../../models/track.dart';

/// 播放器对话框工具类
/// 包含睡眠定时器对话框和添加到歌单对话框
class PlayerDialogs {
  /// 显示睡眠定时器对话框
  static void showSleepTimer(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SleepTimerDialog(),
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
      builder: (context) => AnimatedBuilder(
        animation: playlistService,
        builder: (context, child) {
          final playlists = playlistService.playlists;
          
          if (playlists.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
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
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(),
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
                        title: Text(playlist.name),
                        subtitle: Text('${playlist.trackCount} 首歌曲'),
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
}

/// 睡眠定时器对话框
class SleepTimerDialog extends StatefulWidget {
  const SleepTimerDialog({super.key});

  @override
  State<SleepTimerDialog> createState() => _SleepTimerDialogState();
}

class _SleepTimerDialogState extends State<SleepTimerDialog> {
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
        width: 400,
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
                      Icons.bedtime,
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
