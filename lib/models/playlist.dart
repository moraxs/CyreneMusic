import 'track.dart';

/// 歌单模型
class Playlist {
  final int id;
  final String name;
  final bool isDefault; // 是否为默认歌单（我的收藏）
  final int trackCount; // 歌曲数量
  final DateTime createdAt;
  final DateTime updatedAt;

  Playlist({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.trackCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as int,
      name: json['name'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
      trackCount: json['trackCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isDefault': isDefault,
      'trackCount': trackCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

/// 歌单中的歌曲模型
class PlaylistTrack {
  final String trackId;
  final String name;
  final String artists;
  final String album;
  final String picUrl;
  final MusicSource source;
  final DateTime addedAt;

  PlaylistTrack({
    required this.trackId,
    required this.name,
    required this.artists,
    required this.album,
    required this.picUrl,
    required this.source,
    required this.addedAt,
  });

  factory PlaylistTrack.fromJson(Map<String, dynamic> json) {
    return PlaylistTrack(
      trackId: json['trackId'] as String,
      name: json['name'] as String,
      artists: json['artists'] as String,
      album: json['album'] as String,
      picUrl: json['picUrl'] as String,
      source: _parseSource(json['source'] as String),
      addedAt: DateTime.parse(json['addedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trackId': trackId,
      'name': name,
      'artists': artists,
      'album': album,
      'picUrl': picUrl,
      'source': source.toString().split('.').last,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  /// 从 Track 创建 PlaylistTrack
  factory PlaylistTrack.fromTrack(Track track) {
    return PlaylistTrack(
      trackId: track.id.toString(),
      name: track.name,
      artists: track.artists,
      album: track.album,
      picUrl: track.picUrl,
      source: track.source,
      addedAt: DateTime.now(),
    );
  }

  /// 转换为 Track 对象
  Track toTrack() {
    // 尝试解析为 int，如果失败则保持为字符串（用于 QQ 音乐和酷狗音乐）
    final dynamic trackIdValue = int.tryParse(trackId) ?? trackId;
    
    return Track(
      id: trackIdValue,  // 支持 int 和 String 类型
      name: name,
      artists: artists,
      album: album,
      picUrl: picUrl,
      source: source,
    );
  }

  /// 解析音乐源
  static MusicSource _parseSource(String source) {
    switch (source.toLowerCase()) {
      case 'netease':
        return MusicSource.netease;
      case 'qq':
        return MusicSource.qq;
      case 'kugou':
        return MusicSource.kugou;
      default:
        return MusicSource.netease;
    }
  }
}

