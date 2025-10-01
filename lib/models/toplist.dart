import 'track.dart';

/// 榜单模型
class Toplist {
  final int id;
  final String name;
  final String nameEn;
  final String coverImgUrl;
  final String creator;
  final int trackCount;
  final String description;
  final List<Track> tracks;
  final MusicSource source;

  Toplist({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.coverImgUrl,
    required this.creator,
    required this.trackCount,
    required this.description,
    required this.tracks,
    this.source = MusicSource.netease,
  });

  /// 从 JSON 创建 Toplist 对象
  factory Toplist.fromJson(Map<String, dynamic> json, {MusicSource? source}) {
    final musicSource = source ?? MusicSource.netease;
    
    return Toplist(
      id: json['id'] as int,
      name: json['name'] as String,
      nameEn: json['name_en'] as String? ?? '',
      coverImgUrl: json['coverImgUrl'] as String,
      creator: json['creator'] as String,
      trackCount: json['trackCount'] as int,
      description: json['description'] as String,
      tracks: (json['tracks'] as List<dynamic>?)
              ?.map((track) => Track.fromJson(track as Map<String, dynamic>, source: musicSource))
              .toList() ??
          [],
      source: musicSource,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_en': nameEn,
      'coverImgUrl': coverImgUrl,
      'creator': creator,
      'trackCount': trackCount,
      'description': description,
      'tracks': tracks.map((track) => track.toJson()).toList(),
      'source': source.name,
    };
  }
}

