import 'package:flutter/material.dart';
import '../../services/player_service.dart';
import '../../models/lyric_line.dart';

/// 播放器歌词面板
/// 显示歌词和翻译，支持自适应颜色和滚动动画
class PlayerLyricsPanel extends StatelessWidget {
  final List<LyricLine> lyrics;
  final int currentLyricIndex;
  final bool showTranslation;

  const PlayerLyricsPanel({
    super.key,
    required this.lyrics,
    required this.currentLyricIndex,
    required this.showTranslation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: lyrics.isEmpty
          ? _buildNoLyric()
          : _buildLyricList(),
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

  /// 构建歌词列表（固定显示8行，当前歌词在第4行，丝滑滚动）
  Widget _buildLyricList() {
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
                      height: itemHeight,
                      key: ValueKey('empty_$i'),
                    ),
                  );
                } else {
                  // 显示歌词
                  final lyric = lyrics[lyricIndex];
                  final isCurrent = lyricIndex == currentLyricIndex;
                  
                  // 获取自适应颜色
                  final lyricColor = _getAdaptiveLyricColor(themeColor, isCurrent);
                  final translationColor = _getAdaptiveLyricColor(
                    themeColor, 
                    false, // 翻译始终使用非当前行的颜色
                  ).withOpacity(isCurrent ? 0.75 : 0.5);
                  
                  lyricWidgets.add(
                    SizedBox(
                      height: itemHeight,
                      key: ValueKey('lyric_$lyricIndex'),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            color: lyricColor,
                            fontSize: isCurrent ? 18 : 15,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            height: 1.4,
                            fontFamily: 'Microsoft YaHei', // 使用微软雅黑字体
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
                                if (showTranslation && lyric.translation != null && lyric.translation!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      lyric.translation!,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: translationColor,
                                        fontSize: isCurrent ? 13 : 12,
                                        fontFamily: 'Microsoft YaHei', // 使用微软雅黑字体
                                      ),
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
              }
        
              // 使用 AnimatedSwitcher 实现丝滑滚动效果
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                  // 只显示当前的 child，不显示之前的 child
                  return Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                transitionBuilder: (Widget child, Animation<double> animation) {
                  // 向上滑动的过渡效果（无淡入淡出）
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
                  key: ValueKey(currentLyricIndex), // 关键：当索引变化时触发动画
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
    final color = themeColor ?? Colors.deepPurple;
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
