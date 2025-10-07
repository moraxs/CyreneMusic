import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../../services/player_service.dart';
import '../../models/lyric_line.dart';

/// 桌面端卡拉OK样式歌词面板
/// 显示8行歌词，当前歌词位于第4行，支持从左到右的填充效果、上下滚动动画和鼠标滚轮跳转
class PlayerKaraokeLyricsPanel extends StatefulWidget {
  final List<LyricLine> lyrics;
  final int currentLyricIndex;
  final bool showTranslation;

  const PlayerKaraokeLyricsPanel({
    super.key,
    required this.lyrics,
    required this.currentLyricIndex,
    required this.showTranslation,
  });

  @override
  State<PlayerKaraokeLyricsPanel> createState() => _PlayerKaraokeLyricsPanelState();
}

class _PlayerKaraokeLyricsPanelState extends State<PlayerKaraokeLyricsPanel> with TickerProviderStateMixin {
  int? _selectedLyricIndex; // 手动选择的歌词索引
  bool _isManualMode = false; // 是否处于手动模式
  Timer? _autoResetTimer; // 自动回退定时器
  AnimationController? _timeCapsuleAnimationController;
  Animation<double>? _timeCapsuleFadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _autoResetTimer?.cancel();
    _timeCapsuleAnimationController?.dispose();
    super.dispose();
  }

  /// 初始化动画
  void _initializeAnimations() {
    _timeCapsuleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _timeCapsuleFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _timeCapsuleAnimationController!,
      curve: Curves.easeInOut,
    ));
  }

  /// 开始手动模式
  void _startManualMode(int lyricIndex) {
    setState(() {
      _isManualMode = true;
      _selectedLyricIndex = lyricIndex;
    });
    
    _timeCapsuleAnimationController?.forward();
    _resetAutoTimer();
  }

  /// 重置自动回退定时器
  void _resetAutoTimer() {
    _autoResetTimer?.cancel();
    _autoResetTimer = Timer(const Duration(seconds: 5), _exitManualMode);
  }

  /// 退出手动模式
  void _exitManualMode() {
    if (!mounted) return;
    
    setState(() {
      _isManualMode = false;
      _selectedLyricIndex = null;
    });
    
    _timeCapsuleAnimationController?.reverse();
    _autoResetTimer?.cancel();
  }

  /// 跳转到选中的歌词时间
  void _seekToSelectedLyric() {
    if (_selectedLyricIndex != null && 
        _selectedLyricIndex! >= 0 && 
        _selectedLyricIndex! < widget.lyrics.length) {
      
      final selectedLyric = widget.lyrics[_selectedLyricIndex!];
      if (selectedLyric.startTime != null) {
        PlayerService().seek(selectedLyric.startTime!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已跳转到: ${selectedLyric.text}'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
    
    _exitManualMode();
  }

  /// 处理鼠标滚轮滑动
  void _handleScrollEvent(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (widget.lyrics.isEmpty) return;
    
    final scrollDelta = event.scrollDelta.dy;
    final currentIndex = _selectedLyricIndex ?? widget.currentLyricIndex;
    int newIndex = currentIndex;
    
    if (scrollDelta > 0) {
      // 向下滚动，选择下一句歌词
      newIndex = (currentIndex + 1).clamp(0, widget.lyrics.length - 1);
    } else if (scrollDelta < 0) {
      // 向上滚动，选择上一句歌词
      newIndex = (currentIndex - 1).clamp(0, widget.lyrics.length - 1);
    }
    
    if (newIndex != currentIndex) {
      if (!_isManualMode) {
        _startManualMode(newIndex);
      } else {
        setState(() {
          _selectedLyricIndex = newIndex;
        });
        _resetAutoTimer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Stack(
        children: [
          // 主要歌词区域
          Listener(
            onPointerSignal: _handleScrollEvent,
            child: widget.lyrics.isEmpty
                ? _buildNoLyric()
                : _buildKaraokeLyricList(),
          ),
          
          // 时间胶囊组件（桌面端版本）
          if (_isManualMode && _selectedLyricIndex != null)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: _buildDesktopTimeCapsule(),
            ),
        ],
      ),
    );
  }

  /// 构建无歌词提示
  Widget _buildNoLyric() {
    return ValueListenableBuilder<Color?>(
      valueListenable: PlayerService().themeColorNotifier,
      builder: (context, themeColor, child) {
        final textColor = _getAdaptiveLyricColor(themeColor, false).withOpacity(0.5);
        return Center(
          child: Text(
            '暂无歌词',
            style: TextStyle(
              color: textColor,
              fontSize: 16,
            ),
          ),
        );
      },
    );
  }

  /// 构建卡拉OK样式歌词列表（显示8行，当前歌词在第4行，丝滑滚动）
  Widget _buildKaraokeLyricList() {
    // 使用 RepaintBoundary 隔离歌词区域的重绘
    return RepaintBoundary(
      child: ValueListenableBuilder<Color?>(
        valueListenable: PlayerService().themeColorNotifier,
        builder: (context, themeColor, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              const int totalVisibleLines = 8; // 总共显示8行
              const int currentLinePosition = 3; // 当前歌词在第4行（索引3）
              
              // 根据容器高度计算每行的实际高度
              final itemHeight = constraints.maxHeight / totalVisibleLines;
              
              // 使用手动选择的索引或当前播放索引
              final displayIndex = _selectedLyricIndex ?? widget.currentLyricIndex;
              
              // 计算显示范围
              int startIndex = displayIndex - currentLinePosition;
              
              // 生成要显示的歌词列表
              List<Widget> lyricWidgets = [];
              
              for (int i = 0; i < totalVisibleLines; i++) {
                int lyricIndex = startIndex + i;
                
                // 判断是否在有效范围内
                if (lyricIndex < 0 || lyricIndex >= widget.lyrics.length) {
                  // 空行占位
                  lyricWidgets.add(
                    SizedBox(
                      height: itemHeight,
                      key: ValueKey('empty_$i'),
                    ),
                  );
                } else {
                  // 显示歌词
                  final lyric = widget.lyrics[lyricIndex];
                  final isCurrent = lyricIndex == displayIndex;
                  final isActuallyPlaying = lyricIndex == widget.currentLyricIndex;
                  
                  lyricWidgets.add(
                    SizedBox(
                      height: itemHeight,
                      key: ValueKey('lyric_$lyricIndex'),
                      child: Center(
                        child: isCurrent
                            ? _buildKaraokeLyricLine(lyric, themeColor, itemHeight, isActuallyPlaying)
                            : _buildNormalLyricLine(lyric, themeColor, itemHeight, false),
                      ),
                    ),
                  );
                }
              }
        
              // 使用 AnimatedSwitcher 实现丝滑滚动效果
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                  return Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                transitionBuilder: (Widget child, Animation<double> animation) {
                  // 向上滑动的过渡效果
                  final offsetAnimation = Tween<Offset>(
                    begin: const Offset(0.0, 0.1), // 从下方10%处开始
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ));
                  
                  return SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  );
                },
                child: Column(
                  key: ValueKey(displayIndex), // 关键：当索引变化时触发动画
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: lyricWidgets,
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// 构建卡拉OK样式的歌词行（当前歌词）
  Widget _buildKaraokeLyricLine(LyricLine lyric, Color? themeColor, double itemHeight, bool isActuallyPlaying) {
    return AnimatedBuilder(
      animation: PlayerService(),
      builder: (context, child) {
        final player = PlayerService();
        // 只有正在播放的歌词才显示填充效果，手动选择的显示静态高亮
        final fillProgress = isActuallyPlaying ? _calculateFillProgress(lyric, player.position) : 0.0;
        final isSelected = _isManualMode && !isActuallyPlaying;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 原文歌词 - 卡拉OK效果
              _buildKaraokeText(
                text: lyric.text,
                fontSize: 18,
                fillProgress: fillProgress,
                themeColor: themeColor,
                isSelected: isSelected,
              ),
              
              // 翻译歌词（根据开关显示）- 普通高亮
              if (widget.showTranslation && lyric.translation != null && lyric.translation!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    lyric.translation!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _getAdaptiveLyricColor(themeColor, false).withOpacity(0.75),
                      fontSize: 13,
                      fontFamily: 'Microsoft YaHei',
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 构建普通歌词行（非当前歌词）
  Widget _buildNormalLyricLine(LyricLine lyric, Color? themeColor, double itemHeight, bool isCurrent) {
    // 获取自适应颜色
    final lyricColor = _getAdaptiveLyricColor(themeColor, isCurrent);
    final translationColor = _getAdaptiveLyricColor(
      themeColor, 
      false, // 翻译始终使用非当前行的颜色
    ).withOpacity(isCurrent ? 0.75 : 0.5);
    
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 300),
      style: TextStyle(
        color: lyricColor,
        fontSize: 15,
        fontWeight: FontWeight.normal,
        height: 1.4,
        fontFamily: 'Microsoft YaHei',
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 原文歌词
            Text(
              lyric.text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // 翻译歌词（根据开关显示）
            if (widget.showTranslation && lyric.translation != null && lyric.translation!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  lyric.translation!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: translationColor,
                    fontSize: 12,
                    fontFamily: 'Microsoft YaHei',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建卡拉OK文字效果
  Widget _buildKaraokeText({
    required String text,
    required double fontSize,
    required double fillProgress,
    required Color? themeColor,
    bool isSelected = false,
  }) {
    final baseColor = _getAdaptiveLyricColor(themeColor, false);
    final highlightColor = _getAdaptiveLyricColor(themeColor, true);
    
    return Stack(
      children: [
        // 底层：未填充的文字（半透明）
        Text(
          text,
          style: TextStyle(
            color: baseColor,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            fontFamily: 'Microsoft YaHei',
            height: 1.4,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        
        // 上层：填充的文字（高亮色或选中色）
        ClipRect(
          clipper: _DesktopKaraokeClipper(isSelected ? 1.0 : fillProgress),
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.orange : highlightColor,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              fontFamily: 'Microsoft YaHei',
              height: 1.4,
              // 添加发光效果
              shadows: [
                Shadow(
                  color: isSelected 
                      ? Colors.orange.withOpacity(0.6)
                      : highlightColor.withOpacity(0.5),
                  blurRadius: isSelected ? 12 : 8,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 计算填充进度（0.0 - 1.0）
  double _calculateFillProgress(LyricLine lyric, Duration currentPosition) {
    if (lyric.startTime == null) return 0.0;
    
    final startMs = lyric.startTime!.inMilliseconds;
    final currentMs = currentPosition.inMilliseconds;
    
    // 如果还没开始，返回0
    if (currentMs < startMs) return 0.0;
    
    // 计算歌词行的持续时间（到下一行开始或3秒默认）
    final nextLyricIndex = widget.currentLyricIndex + 1;
    Duration endTime;
    
    if (nextLyricIndex < widget.lyrics.length && widget.lyrics[nextLyricIndex].startTime != null) {
      endTime = widget.lyrics[nextLyricIndex].startTime!;
    } else {
      // 最后一行或下一行没有时间戳，使用3秒默认持续时间
      endTime = lyric.startTime! + const Duration(seconds: 3);
    }
    
    final endMs = endTime.inMilliseconds;
    final durationMs = endMs - startMs;
    
    if (durationMs <= 0) return 1.0; // 避免除零
    
    final elapsedMs = currentMs - startMs;
    final progress = (elapsedMs / durationMs).clamp(0.0, 1.0);
    
    return progress;
  }

  /// 构建桌面端时间胶囊组件
  Widget _buildDesktopTimeCapsule() {
    if (_selectedLyricIndex == null || 
        _selectedLyricIndex! < 0 || 
        _selectedLyricIndex! >= widget.lyrics.length) {
      return const SizedBox.shrink();
    }

    final selectedLyric = widget.lyrics[_selectedLyricIndex!];
    final timeText = selectedLyric.startTime != null 
        ? _formatDuration(selectedLyric.startTime!)
        : '00:00';

    return FadeTransition(
      opacity: _timeCapsuleFadeAnimation!,
      child: Center(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _seekToSelectedLyric,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 时间显示
                  Text(
                    timeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 跳转提示
                  const Text(
                    '点击跳转',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 格式化时间显示
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 根据背景色亮度判断应该使用深色还是浅色文字
  bool _shouldUseDarkText(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5;
  }

  /// 获取自适应的歌词颜色
  Color _getAdaptiveLyricColor(Color? themeColor, bool isCurrent) {
    final color = themeColor ?? Colors.grey[700]!;
    final useDarkText = _shouldUseDarkText(color);
    
    if (useDarkText) {
      // 亮色背景，使用深色文字
      return isCurrent 
          ? Colors.black87 
          : Colors.black54;
    } else {
      // 暗色背景，使用浅色文字
      return isCurrent 
          ? Colors.white 
          : Colors.white.withOpacity(0.45);
    }
  }
}

/// 桌面端卡拉OK样式的自定义裁剪器
class _DesktopKaraokeClipper extends CustomClipper<Rect> {
  final double progress;

  _DesktopKaraokeClipper(this.progress);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(
      0,
      0,
      size.width * progress, // 根据进度裁剪宽度
      size.height,
    );
  }

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) {
    return true; // 总是重新裁剪以实现动画效果
  }
}
