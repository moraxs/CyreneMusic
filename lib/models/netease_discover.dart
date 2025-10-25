import 'track.dart';

/// 网易云歌单概要（发现页）
class NeteasePlaylistSummary {
  final int id;
  final String name;
  final String coverImgUrl;
  final String creatorNickname;
  final int trackCount;
  final int playCount;

  NeteasePlaylistSummary({
    required this.id,
    required this.name,
    required this.coverImgUrl,
    required this.creatorNickname,
    required this.trackCount,
    required this.playCount,
  });

  factory NeteasePlaylistSummary.fromJson(Map<String, dynamic> json) {
    final creator = (json['creator'] as Map<String, dynamic>?) ?? {};
    return NeteasePlaylistSummary(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '') as String,
      coverImgUrl: (json['coverImgUrl'] ?? '') as String,
      creatorNickname: (creator['nickname'] ?? '') as String,
      trackCount: (json['trackCount'] ?? 0) as int,
      playCount: (json['playCount'] ?? 0) as int,
    );
  }
}

/// 网易云歌单详情
class NeteasePlaylistDetail {
  final int id;
  final String name;
  final String coverImgUrl;
  final String creator;
  final int trackCount;
  final String description;
  final List<String> tags;
  final int playCount;
  final List<Track> tracks;

  NeteasePlaylistDetail({
    required this.id,
    required this.name,
    required this.coverImgUrl,
    required this.creator,
    required this.trackCount,
    required this.description,
    required this.tags,
    required this.playCount,
    required this.tracks,
  });

  factory NeteasePlaylistDetail.fromJson(Map<String, dynamic> json) {
    final playlist = (json['playlist'] as Map<String, dynamic>?) ?? {};
    final tracksJson = (playlist['tracks'] as List<dynamic>? ?? []);
    final tracks = tracksJson.map((t) {
      final m = t as Map<String, dynamic>;
      return Track(
        id: m['id'],
        name: (m['name'] ?? '') as String,
        artists: (m['artists'] ?? '') as String,
        album: (m['album'] ?? '') as String,
        picUrl: (m['picUrl'] ?? '') as String,
        source: MusicSource.netease,
      );
    }).toList();

    return NeteasePlaylistDetail(
      id: (playlist['id'] as num?)?.toInt() ?? 0,
      name: (playlist['name'] ?? '') as String,
      coverImgUrl: (playlist['coverImgUrl'] ?? '') as String,
      creator: (playlist['creator'] ?? '') as String,
      trackCount: (playlist['trackCount'] ?? tracks.length) as int,
      description: (playlist['description'] ?? '') as String,
      tags: (playlist['tags'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      playCount: (playlist['playCount'] ?? 0) as int,
      tracks: tracks,
    );
  }
}

/// 网易云高质量歌单标签
class NeteaseTag {
  final int id;
  final String name;
  final int type;
  final int category;
  final bool hot;

  NeteaseTag({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.hot,
  });

  factory NeteaseTag.fromJson(Map<String, dynamic> json) {
    return NeteaseTag(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '') as String,
      type: (json['type'] ?? 0) as int,
      category: (json['category'] ?? 0) as int,
      hot: (json['hot'] ?? false) as bool,
    );
  }
}


