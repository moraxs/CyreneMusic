import 'track.dart';

/// 合并后的歌曲模型（支持多平台）
class MergedTrack {
  final String name;      // 歌曲名
  final String artists;   // 歌手名
  final String album;     // 专辑名（取第一个平台的）
  final String picUrl;    // 封面图（取第一个平台的）
  final List<Track> tracks; // 所有平台的 Track

  MergedTrack({
    required this.name,
    required this.artists,
    required this.album,
    required this.picUrl,
    required this.tracks,
  });

  /// 获取所有可用的平台
  List<MusicSource> get availableSources {
    return tracks.map((t) => t.source).toList();
  }

  /// 获取平台图标列表
  List<String> get sourceIcons {
    return tracks.map((t) => t.getSourceIcon()).toList();
  }

  /// 按优先级获取最佳 Track（网易云 > QQ音乐 > 酷狗音乐）
  Track getBestTrack() {
    // 优先级：网易云 > QQ > 酷狗
    for (final source in [MusicSource.netease, MusicSource.qq, MusicSource.kugou]) {
      try {
        return tracks.firstWhere((t) => t.source == source);
      } catch (e) {
        // 该平台没有，继续下一个
      }
    }
    // 如果都没有，返回第一个
    return tracks.first;
  }

  /// 获取指定平台的 Track
  Track? getTrackBySource(MusicSource source) {
    try {
      return tracks.firstWhere((t) => t.source == source);
    } catch (e) {
      return null;
    }
  }

  /// 判断两首歌是否相同（歌曲名和歌手名完全一致）
  static bool isSameSong(Track a, Track b) {
    return _normalize(a.name) == _normalize(b.name) &&
           _normalize(a.artists) == _normalize(b.artists);
  }

  /// 标准化字符串（去除空格、转小写，便于比较）
  static String _normalize(String str) {
    return str
        .trim()
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('、', ',')
        .replaceAll('/', ',');
  }

  /// 从多个 Track 创建 MergedTrack
  static MergedTrack fromTracks(List<Track> tracks) {
    if (tracks.isEmpty) {
      throw Exception('tracks cannot be empty');
    }

    // 按平台优先级排序
    final sortedTracks = List<Track>.from(tracks);
    sortedTracks.sort((a, b) {
      final priorityA = _getPriority(a.source);
      final priorityB = _getPriority(b.source);
      return priorityA.compareTo(priorityB);
    });

    final first = sortedTracks.first;

    return MergedTrack(
      name: first.name,
      artists: first.artists,
      album: first.album,
      picUrl: first.picUrl,
      tracks: sortedTracks,
    );
  }

  /// 获取平台优先级（数字越小优先级越高）
  static int _getPriority(MusicSource source) {
    switch (source) {
      case MusicSource.netease:
        return 0;
      case MusicSource.qq:
        return 1;
      case MusicSource.kugou:
        return 2;
      case MusicSource.local:
        return 3;
    }
  }
}

