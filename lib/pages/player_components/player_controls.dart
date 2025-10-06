import 'package:flutter/material.dart';
import '../../services/player_service.dart';
import '../../services/playback_mode_service.dart';
import '../../services/sleep_timer_service.dart';
import '../../services/download_service.dart';
import '../../services/playlist_service.dart';
import '../../models/track.dart';
import '../../models/song_detail.dart';
import '../../models/lyric_line.dart';

/// 播放器控制面板
/// 包含进度条和所有播放控制按钮
class PlayerControls extends StatelessWidget {
  final PlayerService player;
  final VoidCallback onVolumeControlPressed;
  final VoidCallback onPlaylistPressed;
  final VoidCallback? onSleepTimerPressed;
  final Function(Track)? onAddToPlaylistPressed;
  final List<LyricLine> lyrics;
  final bool showTranslation;
  final VoidCallback? onTranslationToggle;

  const PlayerControls({
    super.key,
    required this.player,
    required this.onVolumeControlPressed,
    required this.onPlaylistPressed,
    this.onSleepTimerPressed,
    this.onAddToPlaylistPressed,
    required this.lyrics,
    required this.showTranslation,
    this.onTranslationToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withOpacity(0.3),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withOpacity(0.2),
            ),
            child: Slider(
              value: player.duration.inMilliseconds > 0
                  ? player.position.inMilliseconds / player.duration.inMilliseconds
                  : 0.0,
              onChanged: (value) {
                final position = Duration(
                  milliseconds: (value * player.duration.inMilliseconds).round(),
                );
                player.seek(position);
              },
            ),
          ),
          
          // 时间显示
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 左侧：当前时间
                Text(
                  _formatDuration(player.position),
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                ),
                
                // 右侧：总时长
                Text(
                  _formatDuration(player.duration),
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 控制按钮
          _buildControlButtons(context),
        ],
      ),
    );
  }

  /// 构建控制按钮
  Widget _buildControlButtons(BuildContext context) {
    final currentTrack = player.currentTrack;
    const double buttonSpacing = 12.0; // 统一的按钮间距
    
    return Row(
      children: [
        // 左侧按钮组
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 译文显示开关（只在非中文歌词且有翻译时显示）
              if (_shouldShowTranslationButton()) ...[
                IconButton(
                  icon: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: showTranslation ? Colors.white.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child: Text(
                        '译',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Microsoft YaHei',
                        ),
                      ),
                    ),
                  ),
                  onPressed: onTranslationToggle,
                  tooltip: showTranslation ? '隐藏译文' : '显示译文',
                ),
                const SizedBox(width: buttonSpacing),
              ],
              
              // 播放模式切换
              AnimatedBuilder(
                animation: PlaybackModeService(),
                builder: (context, child) {
                  final mode = PlaybackModeService().currentMode;
                  IconData icon;
                  switch (mode) {
                    case PlaybackMode.sequential:
                      icon = Icons.repeat_rounded;
                      break;
                    case PlaybackMode.repeatOne:
                      icon = Icons.repeat_one_rounded;
                      break;
                    case PlaybackMode.shuffle:
                      icon = Icons.shuffle_rounded;
                      break;
                  }
                  
                  return IconButton(
                    icon: Icon(icon, color: Colors.white),
                    iconSize: 30,
                    onPressed: () {
                      PlaybackModeService().toggleMode();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('播放模式: ${PlaybackModeService().getModeName()}'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    tooltip: PlaybackModeService().getModeName(),
                  );
                },
              ),
              const SizedBox(width: buttonSpacing),
              
              // 睡眠定时器
              if (onSleepTimerPressed != null)
                AnimatedBuilder(
                  animation: SleepTimerService(),
                  builder: (context, child) {
                    final timer = SleepTimerService();
                    final isActive = timer.isActive;
                    
                     return IconButton(
                       icon: Icon(
                         isActive ? Icons.schedule : Icons.schedule_outlined,
                         color: isActive ? Colors.amber : Colors.white,
                       ),
                       iconSize: 30,
                       onPressed: onSleepTimerPressed,
                       tooltip: isActive ? '定时停止: ${timer.remainingTimeString}' : '睡眠定时器',
                     );
                  },
                ),
              if (onSleepTimerPressed != null)
                const SizedBox(width: buttonSpacing),
              
              // 添加到歌单按钮
              if (currentTrack != null && onAddToPlaylistPressed != null) ...[
                IconButton(
                  icon: const Icon(
                    Icons.playlist_add_rounded,
                    color: Colors.white,
                  ),
                  iconSize: 30,
                  onPressed: () => onAddToPlaylistPressed!(currentTrack),
                  tooltip: '添加到歌单',
                ),
                const SizedBox(width: buttonSpacing),
              ],
              
              const SizedBox(width: 8), // 左侧组与中间组的额外间距
            ],
          ),
        ),
        
        // 中间核心按钮组（上一首、播放/暂停、下一首）- 始终居中
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 上一首
            IconButton(
              icon: Icon(
                Icons.skip_previous_rounded,
                color: player.hasPrevious ? Colors.white : Colors.white38,
              ),
              iconSize: 42,
              onPressed: player.hasPrevious ? player.playPrevious : null,
              tooltip: '上一首',
            ),
            
            const SizedBox(width: buttonSpacing),
            
            // 播放/暂停
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: player.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : IconButton(
                      icon: Icon(
                        player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.black87,
                      ),
                      iconSize: 40,
                      onPressed: player.togglePlayPause,
                    ),
            ),
            
            const SizedBox(width: buttonSpacing),
            
            // 下一首
            IconButton(
              icon: Icon(
                Icons.skip_next_rounded,
                color: player.hasNext ? Colors.white : Colors.white38,
              ),
              iconSize: 42,
              onPressed: player.hasNext ? player.playNext : null,
              tooltip: '下一首',
            ),
            
            const SizedBox(width: buttonSpacing),
            
            // 音量控制（常驻显示，悬停弹出滑动条）
            _buildVolumeControl(),
          ],
        ),
        
        // 右侧按钮组
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(width: 8), // 中间组与右侧组的额外间距
              
              // 下载按钮
              if (currentTrack != null && player.currentSong != null) ...[
                const SizedBox(width: buttonSpacing),
                _buildDownloadButton(context, currentTrack, player.currentSong!),
              ],
              const SizedBox(width: buttonSpacing),
              
              // 播放列表按钮
              IconButton(
                icon: const Icon(Icons.queue_music_rounded, color: Colors.white),
                iconSize: 30,
                onPressed: onPlaylistPressed,
                tooltip: '播放列表',
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建音量控制按钮
  Widget _buildVolumeControl() {
    final volume = player.volume;
    
    return IconButton(
      icon: Icon(
        volume == 0 
            ? Icons.volume_off_rounded 
            : volume < 0.5 
                ? Icons.volume_down_rounded 
                : Icons.volume_up_rounded,
        color: Colors.white,
      ),
      iconSize: 30,
      onPressed: onVolumeControlPressed,
      tooltip: '控制中心',
    );
  }

  /// 构建下载按钮
  Widget _buildDownloadButton(BuildContext context, Track currentTrack, SongDetail currentSong) {
    return AnimatedBuilder(
      animation: DownloadService(),
      builder: (context, child) {
        final downloadService = DownloadService();
        final isDownloading = downloadService.downloadTasks.containsKey(
          '${currentTrack.source.name}_${currentTrack.id}'
        );
        
        return IconButton(
          icon: Icon(
            isDownloading ? Icons.downloading_rounded : Icons.download_rounded,
            color: Colors.white,
          ),
          iconSize: 30,
          onPressed: isDownloading ? null : () => _handleDownload(context, currentTrack, currentSong),
          tooltip: isDownloading ? '下载中...' : '下载',
        );
      },
    );
  }

  /// 处理下载
  Future<void> _handleDownload(BuildContext context, Track currentTrack, SongDetail currentSong) async {
    try {
      // 检查是否已下载
      final isDownloaded = await DownloadService().isDownloaded(currentTrack);
      
      if (isDownloaded) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('该歌曲已下载'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // 显示下载确认
      if (context.mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('下载歌曲'),
            content: Text('确定要下载《${currentTrack.name}》吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('下载'),
              ),
            ],
          ),
        );

        if (confirm != true) return;
      }

      // 开始下载
      final success = await DownloadService().downloadSong(
        currentTrack,
        currentSong,
        onProgress: (progress) {
          // 下载进度会通过 DownloadService 的 notifyListeners 自动更新UI
        },
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '下载成功！' : '下载失败'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ [PlayerControls] 下载失败: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 判断是否应该显示译文按钮
  /// 只有当歌词非中文且存在翻译时才显示
  bool _shouldShowTranslationButton() {
    if (lyrics.isEmpty) return false;
    
    // 检查是否有翻译
    final hasTranslation = lyrics.any((lyric) => 
      lyric.translation != null && lyric.translation!.isNotEmpty
    );
    
    if (!hasTranslation) return false;
    
    // 检查原文是否为中文（检查前几行非空歌词）
    final sampleLyrics = lyrics
        .where((lyric) => lyric.text.trim().isNotEmpty)
        .take(5)
        .map((lyric) => lyric.text)
        .join('');
    
    if (sampleLyrics.isEmpty) return false;
    
    // 判断是否主要为中文（中文字符占比）
    final chineseCount = sampleLyrics.runes.where((rune) {
      return (rune >= 0x4E00 && rune <= 0x9FFF) || // 基本汉字
             (rune >= 0x3400 && rune <= 0x4DBF) || // 扩展A
             (rune >= 0x20000 && rune <= 0x2A6DF); // 扩展B
    }).length;
    
    final totalCount = sampleLyrics.runes.length;
    final chineseRatio = totalCount > 0 ? chineseCount / totalCount : 0;
    
    // 如果中文字符占比小于30%，认为是非中文歌词
    return chineseRatio < 0.3;
  }

  /// 格式化时长
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
