import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'url_service.dart';

class NeteaseArtistBrief {
  final int id;
  final String name;
  final String picUrl;
  NeteaseArtistBrief({required this.id, required this.name, required this.picUrl});
  factory NeteaseArtistBrief.fromJson(Map<String, dynamic> json) => NeteaseArtistBrief(
        id: (json['id'] as num).toInt(),
        name: (json['name'] ?? '') as String,
        picUrl: (json['picUrl'] ?? '') as String,
      );
}

class NeteaseArtistDetailService extends ChangeNotifier {
  static final NeteaseArtistDetailService _instance = NeteaseArtistDetailService._internal();
  factory NeteaseArtistDetailService() => _instance;
  NeteaseArtistDetailService._internal();

  /// 搜索歌手列表
  Future<List<NeteaseArtistBrief>> searchArtists(String keywords, {int limit = 20}) async {
    try {
      if (keywords.trim().isEmpty) return [];
      final baseUrl = UrlService().baseUrl;
      final url = '$baseUrl/artist/search';
      final resp = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'keywords': keywords, 'limit': '$limit'},
          )
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return [];
      final data = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (data['status'] != 200) return [];
      final resultList = (data['result'] as List<dynamic>? ?? [])
          .map((e) => NeteaseArtistBrief.fromJson(e as Map<String, dynamic>))
          .toList();
      return resultList;
    } catch (_) {
      return [];
    }
  }

  /// 通过歌手名查ID（优先精确匹配）
  Future<int?> resolveArtistIdByName(String name) async {
    try {
      final baseUrl = UrlService().baseUrl;
      final url = '$baseUrl/artist/search';
      final resp = await http
          .post(Uri.parse(url),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: {'keywords': name, 'limit': '5'})
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return null;
      final data = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (data['status'] != 200) return null;
      final results = (data['result'] as List<dynamic>? ?? [])
          .map((e) => NeteaseArtistBrief.fromJson(e as Map<String, dynamic>))
          .toList();
      if (results.isEmpty) return null;
      // 精确匹配优先
      final exact = results.firstWhere(
        (a) => a.name.toLowerCase() == name.toLowerCase(),
        orElse: () => results.first,
      );
      return exact.id;
    } catch (_) {
      return null;
    }
  }

  /// 获取歌手详情
  Future<Map<String, dynamic>?> fetchArtistDetail(int id) async {
    try {
      final baseUrl = UrlService().baseUrl;
      final url = '$baseUrl/artist/detail?id=$id';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final data = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (data['status'] != 200) return null;
      return data['data'] as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}


