import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/player_service.dart';
import '../../models/lyric_line.dart';

/// 移动端卡拉OK样式歌词组件
/// 支持从左到右的填充效果、上下滚动和手动滑动选择
class MobilePlayerKaraokeLyric extends StatefulWidget {
  final List<LyricLine> lyrics;
  final int currentLyricIndex;
  final VoidCallback onTap;

  const MobilePlayerKaraokeLyric({
    super.key,
    required this.lyrics,
    required this.currentLyricIndex,
    required this.onTap,
  });

  @override
  State<MobilePlayerKaraokeLyric> createState() => _MobilePlayerKaraokeLyricState();
}

class _MobilePlayerKaraokeLyricState extends State<MobilePlayerKaraokeLyric> with TickerProviderStateMixin {
  int? _selectedLyricIndex; // 手动选择的歌词索引
  bool _isManualMode = false; // 是否处于手动模式
  Timer? _autoResetTimer; // 自动回退定时器
  AnimationController? _timeCapsuleAnimationController;
  Animation<double>? _timeCapsuleFadeAnimation;
  
  // 滑动相关
  double _accumulatedDelta = 0.0; // 累积的滑动距离
  static const double _scrollSensitivity = 15.0; // 滑动敏感度

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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        
        return Stack(
          children: [
            // 主要歌词区域
            GestureDetector(
              onTap: widget.onTap,
              onVerticalDragStart: (details) {
                if (widget.lyrics.isEmpty) return;
                
                // 开始滑动时，如果还没有手动选择，使用当前播放索引作为起点
                if (!_isManualMode) {
                  _startManualMode(widget.currentLyricIndex);
                }
                _accumulatedDelta = 0.0;
              },
              onVerticalDragUpdate: (details) {
                if (widget.lyrics.isEmpty || !_isManualMode) return;
                
                // 累积滑动距离
                _accumulatedDelta += details.delta.dy;
                
                // 计算应该移动的行数
                final linesToMove = (_accumulatedDelta / _scrollSensitivity).floor();
                
                if (linesToMove.abs() >= 1) {
                  final currentIndex = _selectedLyricIndex ?? widget.currentLyricIndex;
                  int newIndex;
                  
                  if (linesToMove > 0) {
                    // 向下滑动，选择更前面的歌词
                    newIndex = (currentIndex - linesToMove).clamp(0, widget.lyrics.length - 1);
                  } else {
                    // 向上滑动，选择更后面的歌词
                    newIndex = (currentIndex - linesToMove).clamp(0, widget.lyrics.length - 1);
                  }
                  
                  if (newIndex != currentIndex) {
                    setState(() {
                      _selectedLyricIndex = newIndex;
                    });
                    
                    // 重置累积距离和定时器
                    _accumulatedDelta = 0.0;
                    _resetAutoTimer();
                  }
                }
              },
              onVerticalDragEnd: (details) {
                // 滑动结束时重置累积距离
                _accumulatedDelta = 0.0;
              },
              child: Container(
                height: 90, // 固定高度，容纳3行歌词
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
                child: widget.lyrics.isEmpty
                    ? _buildNoLyric(screenWidth)
                    : _buildKaraokeLyricLines(screenWidth),
              ),
            ),
            
            // 时间胶囊组件
            if (_isManualMode && _selectedLyricIndex != null)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: _buildTimeCapsule(),
              ),
          ],
        );
      },
    );
  }

  /// 构建无歌词提示
  Widget _buildNoLyric(double screenWidth) {
    final lyricFontSize = (screenWidth * 0.038).clamp(14.0, 16.0);
    
    return ValueListenableBuilder<Color?>(
      valueListenable: PlayerService().themeColorNotifier,
      builder: (context, themeColor, child) {
        final textColor = _getAdaptiveLyricColor(themeColor, false).withOpacity(0.5);
        
        return Center(
          child: Text(
            '暂无歌词',
            style: TextStyle(
              color: textColor,
              fontSize: lyricFontSize,
              fontFamily: 'Microsoft YaHei',
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  /// 构建卡拉OK样式的3行歌词显示
  Widget _buildKaraokeLyricLines(double screenWidth) {
    const int totalVisibleLines = 3; // 总共显示3行
    const int currentLinePosition = 1; // 当前歌词在第2行（索引1）
    const double lineHeight = 30.0; // 每行高度
    
    final lyricFontSize = (screenWidth * 0.038).clamp(14.0, 16.0);
    final smallFontSize = lyricFontSize * 0.85;
    
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
            height: lineHeight,
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
            height: lineHeight,
            key: ValueKey('lyric_$lyricIndex'),
            child: isCurrent 
                ? _buildKaraokeLyricLine(lyric, lyricFontSize, isActuallyPlaying)
                : _buildNormalLyricLine(lyric, smallFontSize, false),
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
          begin: const Offset(0.0, 0.3), // 从下方30%处开始
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
        children: lyricWidgets,
      ),
    );
  }

  /// 构建卡拉OK样式的歌词行（当前歌词）
  Widget _buildKaraokeLyricLine(LyricLine lyric, double fontSize, bool isActuallyPlaying) {
    final text = lyric.text.trim().isEmpty ? '♪' : lyric.text;
    
    return ValueListenableBuilder<Color?>(
      valueListenable: PlayerService().themeColorNotifier,
      builder: (context, themeColor, child) {
        return AnimatedBuilder(
          animation: PlayerService(),
          builder: (context, child) {
            final player = PlayerService();
            // 只有正在播放的歌词才显示填充效果，手动选择的显示静态高亮
            final fillProgress = isActuallyPlaying ? _calculateFillProgress(lyric, player.position) : 0.0;
            final isSelected = _isManualMode && !isActuallyPlaying;
            
            return Center(
              child: _buildKaraokeText(
                text: text,
                fontSize: fontSize,
                fillProgress: fillProgress,
                themeColor: themeColor,
                isSelected: isSelected,
              ),
            );
          },
        );
      },
    );
  }

  /// 构建普通歌词行（非当前歌词）
  Widget _buildNormalLyricLine(LyricLine lyric, double fontSize, bool isCurrent) {
    final text = lyric.text.trim().isEmpty ? '♪' : lyric.text;
    
    return ValueListenableBuilder<Color?>(
      valueListenable: PlayerService().themeColorNotifier,
      builder: (context, themeColor, child) {
        final lyricColor = _getAdaptiveLyricColor(themeColor, isCurrent);
        
        return Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              color: lyricColor,
              fontSize: fontSize,
              fontWeight: FontWeight.normal,
              fontFamily: 'Microsoft YaHei',
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
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
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        
        // 上层：填充的文字（高亮色或选中色）
        ClipRect(
          clipper: _KaraokeClipper(isSelected ? 1.0 : fillProgress),
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.orange : highlightColor,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              fontFamily: 'Microsoft YaHei',
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

  /// 构建时间胶囊组件
  Widget _buildTimeCapsule() {
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
        child: GestureDetector(
          onTap: _seekToSelectedLyric,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                // 跳转提示
                const Text(
                  '点击跳转',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ],
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
          : Colors.white.withOpacity(0.5);
    }
  }
}

/// 卡拉OK样式的自定义裁剪器
class _KaraokeClipper extends CustomClipper<Rect> {
  final double progress;

  _KaraokeClipper(this.progress);

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
