import '../models/lyric_line.dart';

/// 歌词解析器
class LyricParser {
  /// 解析网易云音乐 LRC 格式歌词
  static List<LyricLine> parseNeteaseLyric(String lyric, {String? translation}) {
    if (lyric.isEmpty) return [];

    final lines = <LyricLine>[];
    final lyricLines = lyric.split('\n');
    
    // 解析翻译歌词（如果有）
    final Map<Duration, String> translationMap = {};
    if (translation != null && translation.isNotEmpty) {
      final translationLines = translation.split('\n');
      for (final line in translationLines) {
        final time = LyricLine.parseTime(line);
        if (time != null) {
          final text = line.replaceAll(RegExp(r'\[\d+:\d+\.\d+\]'), '').trim();
          if (text.isNotEmpty) {
            translationMap[time] = text;
          }
        }
      }
    }

    // 解析原歌词
    for (final line in lyricLines) {
      final time = LyricLine.parseTime(line);
      if (time != null) {
        final text = line.replaceAll(RegExp(r'\[\d+:\d+\.\d+\]'), '').trim();
        if (text.isNotEmpty) {
          lines.add(LyricLine(
            startTime: time,
            text: text,
            translation: translationMap[time],
          ));
        }
      }
    }

    // 按时间排序
    lines.sort((a, b) => a.startTime.compareTo(b.startTime));
    
    return lines;
  }

  /// 解析 QQ 音乐歌词（格式类似，但可能有差异）
  static List<LyricLine> parseQQLyric(String lyric, {String? translation}) {
    // QQ音乐格式与网易云类似，暂时使用相同解析方式
    // 后续如有差异可以在这里调整
    return parseNeteaseLyric(lyric, translation: translation);
  }

  /// 解析酷狗音乐歌词（可能需要特殊处理）
  static List<LyricLine> parseKugouLyric(String lyric, {String? translation}) {
    // 酷狗音乐格式可能有所不同，预留接口
    // 暂时使用相同解析方式
    return parseNeteaseLyric(lyric, translation: translation);
  }

  /// 根据当前播放时间查找当前歌词行索引
  static int findCurrentLineIndex(List<LyricLine> lyrics, Duration currentTime) {
    if (lyrics.isEmpty) return -1;

    for (int i = lyrics.length - 1; i >= 0; i--) {
      if (currentTime >= lyrics[i].startTime) {
        return i;
      }
    }

    return -1;
  }

  /// 获取当前显示的歌词（带前后几行）
  static List<LyricLine> getCurrentDisplayLines(
    List<LyricLine> lyrics,
    int currentIndex, {
    int beforeCount = 3,
    int afterCount = 5,
  }) {
    if (lyrics.isEmpty || currentIndex < 0) return [];

    final startIndex = (currentIndex - beforeCount).clamp(0, lyrics.length);
    final endIndex = (currentIndex + afterCount + 1).clamp(0, lyrics.length);

    return lyrics.sublist(startIndex, endIndex);
  }
}

