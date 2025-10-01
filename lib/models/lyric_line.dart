/// 歌词行模型
class LyricLine {
  final Duration startTime;
  final String text;
  final String? translation; // 翻译歌词

  LyricLine({
    required this.startTime,
    required this.text,
    this.translation,
  });

  /// 从时间戳字符串解析 Duration
  static Duration? parseTime(String timeStr) {
    try {
      // LRC 格式: [mm:ss.xx] 或 [mm:ss.xxx]
      final regex = RegExp(r'\[(\d+):(\d+)\.(\d+)\]');
      final match = regex.firstMatch(timeStr);
      
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final milliseconds = int.parse(match.group(3)!.padRight(3, '0').substring(0, 3));
        
        return Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );
      }
    } catch (e) {
      // 解析失败
    }
    return null;
  }

  @override
  String toString() {
    return '${startTime.inSeconds}s: $text';
  }
}

