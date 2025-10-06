import 'package:flutter/material.dart';
import '../../models/lyric_line.dart';

/// 移动端播放器当前歌词组件
/// 显示当前正在播放的歌词行，可点击跳转到全屏歌词页面
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
    String lyricText = '暂无歌词';
    
    if (lyrics.isNotEmpty && currentLyricIndex >= 0 && currentLyricIndex < lyrics.length) {
      lyricText = lyrics[currentLyricIndex].text;
      if (lyricText.trim().isEmpty) {
        lyricText = '♪';
      }
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final lyricFontSize = (screenWidth * 0.038).clamp(14.0, 16.0);
        
        return GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
            child: Text(
              lyricText,
              style: TextStyle(
                color: Colors.white,
                fontSize: lyricFontSize,
                fontWeight: FontWeight.w500,
                fontFamily: 'Microsoft YaHei',
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}
