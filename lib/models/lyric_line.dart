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
      // LRC 格式支持: [mm:ss.xx], [mm:ss.xxx], 以及部分平台的 [mm:ss:SS]
      // 先尝试匹配常见的小数点毫秒格式
      final dotRegex = RegExp(r'\[(\d+):(\d+)\.(\d+)\]');
      final dotMatch = dotRegex.firstMatch(timeStr);
      if (dotMatch != null) {
        final minutes = int.parse(dotMatch.group(1)!);
        final seconds = int.parse(dotMatch.group(2)!);
        final milliseconds = int.parse(dotMatch.group(3)!.padRight(3, '0').substring(0, 3));
        return Duration(minutes: minutes, seconds: seconds, milliseconds: milliseconds);
      }

      // 再尝试匹配冒号作为分隔的毫秒格式 [mm:ss:SS] 或 [mm:ss:SSS]
      final colonRegex = RegExp(r'\[(\d+):(\d+):(\d+)\]');
      final colonMatch = colonRegex.firstMatch(timeStr);
      if (colonMatch != null) {
        final minutes = int.parse(colonMatch.group(1)!);
        final seconds = int.parse(colonMatch.group(2)!);
        final msToken = colonMatch.group(3)!;
        // 一些源返回两位“百分之一秒”，需要转换为毫秒
        // 两位 -> 1/100秒；三位 -> 毫秒；其他长度按右填充到3位处理
        int milliseconds;
        if (msToken.length == 2) {
          // 例如 26 -> 260ms（约等于 26/100 秒）
          milliseconds = int.parse(msToken) * 10;
        } else {
          milliseconds = int.parse(msToken.padRight(3, '0').substring(0, 3));
        }
        return Duration(minutes: minutes, seconds: seconds, milliseconds: milliseconds);
      }
      
      // 兼容无毫秒的纯时间戳 [mm:ss]
      final noMsRegex = RegExp(r'\[(\d+):(\d+)\]');
      final noMsMatch = noMsRegex.firstMatch(timeStr);
      if (noMsMatch != null) {
        final minutes = int.parse(noMsMatch.group(1)!);
        final seconds = int.parse(noMsMatch.group(2)!);
        return Duration(minutes: minutes, seconds: seconds);
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

