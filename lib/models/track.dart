/// 音乐平台枚举
enum MusicSource {
  netease,  // 网易云音乐
  qq,       // QQ音乐
  kugou,    // 酷狗音乐
}

/// 歌曲模型
class Track {
  final int id;
  final String name;
  final String artists;
  final String album;
  final String picUrl;
  final MusicSource source;

  Track({
    required this.id,
    required this.name,
    required this.artists,
    required this.album,
    required this.picUrl,
    this.source = MusicSource.netease, // 默认网易云音乐
  });

  /// 从 JSON 创建 Track 对象
  factory Track.fromJson(Map<String, dynamic> json, {MusicSource? source}) {
    return Track(
      id: json['id'] as int,
      name: json['name'] as String,
      artists: json['artists'] as String,
      album: json['album'] as String,
      picUrl: json['picUrl'] as String,
      source: source ?? MusicSource.netease,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'artists': artists,
      'album': album,
      'picUrl': picUrl,
      'source': source.name,
    };
  }

  /// 获取音乐来源的中文名称
  String getSourceName() {
    switch (source) {
      case MusicSource.netease:
        return '网易云音乐';
      case MusicSource.qq:
        return 'QQ音乐';
      case MusicSource.kugou:
        return '酷狗音乐';
    }
  }

  /// 获取音乐来源的图标
  String getSourceIcon() {
    switch (source) {
      case MusicSource.netease:
        return '🎵';
      case MusicSource.qq:
        return '🎶';
      case MusicSource.kugou:
        return '🎼';
    }
  }
}

