import 'package:flutter/material.dart';
import '../../services/player_service.dart';
import '../../models/lyric_line.dart';

/// 移动端播放器当前歌词组件
/// 显示3行歌词，当前歌词位于第2行，带有滚动动画效果
class MobilePlayerCurrentLyric extends StatelessWidget {
  final List<LyricLine> lyrics;
  final int currentLyricIndex;
  final VoidCallback onTap;

  const MobilePlayerCurrentLyric({
    super.key,
    required this.lyrics,
    required this.currentLyricIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        
        return GestureDetector(
          onTap: onTap,
          child: Container(
            height: 90, // 固定高度，容纳3行歌词
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
            child: lyrics.isEmpty
                ? _buildNoLyric(screenWidth)
                : _buildLyricLines(screenWidth),
          ),
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

  /// 构建3行歌词显示（当前歌词在第2行）
  Widget _buildLyricLines(double screenWidth) {
    const int totalVisibleLines = 3; // 总共显示3行
    const int currentLinePosition = 1; // 当前歌词在第2行（索引1）
    const double lineHeight = 30.0; // 每行高度
    
    final lyricFontSize = (screenWidth * 0.038).clamp(14.0, 16.0);
    final smallFontSize = lyricFontSize * 0.85;
    
    // 计算显示范围
    int startIndex = currentLyricIndex - currentLinePosition;
    
    // 生成要显示的歌词列表
    List<Widget> lyricWidgets = [];
    
    for (int i = 0; i < totalVisibleLines; i++) {
      int lyricIndex = startIndex + i;
      
      // 判断是否在有效范围内
      if (lyricIndex < 0 || lyricIndex >= lyrics.length) {
        // 空行占位
        lyricWidgets.add(
          SizedBox(
            height: lineHeight,
            key: ValueKey('empty_$i'),
          ),
        );
      } else {
        // 显示歌词
        final lyric = lyrics[lyricIndex];
        final isCurrent = lyricIndex == currentLyricIndex;
        
        lyricWidgets.add(
          ValueListenableBuilder<Color?>(
            valueListenable: PlayerService().themeColorNotifier,
            builder: (context, themeColor, child) {
              final lyricColor = _getAdaptiveLyricColor(themeColor, isCurrent);
              
              return SizedBox(
                height: lineHeight,
                key: ValueKey('lyric_$lyricIndex'),
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      color: lyricColor,
                      fontSize: isCurrent ? lyricFontSize : smallFontSize,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      fontFamily: 'Microsoft YaHei',
                    ),
                    child: Text(
                      lyric.text.trim().isEmpty ? '♪' : lyric.text,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              );
            },
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
        key: ValueKey(currentLyricIndex), // 关键：当索引变化时触发动画
        mainAxisAlignment: MainAxisAlignment.center,
        children: lyricWidgets,
      ),
    );
  }

  /// 根据背景色亮度判断应该使用深色还是浅色文字
  /// 返回 true 表示背景亮，应该用深色文字；返回 false 表示背景暗，应该用浅色文字
  bool _shouldUseDarkText(Color backgroundColor) {
    // 计算颜色的相对亮度 (0.0 - 1.0)
    // 使用 W3C 推荐的计算公式
    final luminance = backgroundColor.computeLuminance();
    
    // 如果亮度大于 0.5，认为是亮色背景，应该用深色文字
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
