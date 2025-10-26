import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'url_service.dart';
import 'auth_service.dart';

class NeteaseRecommendService extends ChangeNotifier {
  static final NeteaseRecommendService _instance = NeteaseRecommendService._internal();
  factory NeteaseRecommendService() => _instance;
  NeteaseRecommendService._internal();

  Map<String, String> _authHeaders() {
    final token = AuthService().token;
    return token != null ? { 'Authorization': 'Bearer $token' } : {};
  }

  Future<List<Map<String, dynamic>>> fetchDailySongs() async {
    final resp = await http.get(
      Uri.parse(UrlService().neteaseRecommendSongsUrl),
      headers: _authHeaders(),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final data = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    if ((data['code'] as num?)?.toInt() != 200) throw Exception('code ${data['code']}');
    final list = (data['recommend'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return list;
  }

  Future<List<Map<String, dynamic>>> fetchDailyPlaylists() async {
    final resp = await http.get(
      Uri.parse(UrlService().neteaseRecommendResourceUrl),
      headers: _authHeaders(),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final data = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    if ((data['code'] as num?)?.toInt() != 200) throw Exception('code ${data['code']}');
    final list = (data['recommend'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return list;
  }

  Future<List<Map<String, dynamic>>> fetchPersonalFm() async {
    final resp = await http.get(
      Uri.parse(UrlService().neteasePersonalFmUrl),
      headers: _authHeaders(),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final data = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    if ((data['code'] as num?)?.toInt() != 200) throw Exception('code ${data['code']}');
    final list = (data['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return list;
  }

  Future<void> fmTrash(dynamic id) async {
    final resp = await http.post(
      Uri.parse(UrlService().neteaseFmTrashUrl),
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', ..._authHeaders() },
      body: 'id=$id',
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
  }

  Future<List<Map<String, dynamic>>> fetchPersonalizedPlaylists({int limit = 20}) async {
    final url = '${UrlService().neteasePersonalizedPlaylistsUrl}?limit=$limit';
    final resp = await http.get(Uri.parse(url), headers: _authHeaders()).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final data = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    if ((data['code'] as num?)?.toInt() != 200) throw Exception('code ${data['code']}');
    final list = (data['result'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return list;
  }

  Future<List<Map<String, dynamic>>> fetchPersonalizedNewsongs({int limit = 10}) async {
    final url = '${UrlService().neteasePersonalizedNewsongUrl}?limit=$limit';
    final resp = await http.get(Uri.parse(url), headers: _authHeaders()).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final data = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    if ((data['code'] as num?)?.toInt() != 200) throw Exception('code ${data['code']}');
    final list = (data['result'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return list;
  }

  /// 获取雷达歌单：使用一组预置歌单ID并请求后端歌单详情，提取概要信息
  Future<List<Map<String, dynamic>>> fetchRadarPlaylists() async {
    // 预置雷达歌单ID（由产品提供）
    const radarIds = <String>[
      '3136952023', // 私人雷达
      '8402996200', // 会员雷达
      '5320167908', // 时光雷达
      '5327906368', // 乐迷雷达
      '5362359247', // 宝藏雷达
      '5300458264', // 新歌雷达
      '5341776086', // 神秘雷达
    ];

    final futures = radarIds.map((id) async {
      final url = '${UrlService().neteasePlaylistDetailUrl}?id=$id&limit=0';
      final resp = await http.get(Uri.parse(url), headers: _authHeaders()).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final data = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if ((data['status'] as num?)?.toInt() != 200) throw Exception('status ${data['status']}');
      final playlist = (data['data'] as Map<String, dynamic>?)?['playlist'] as Map<String, dynamic>?;
      if (playlist == null) return <String, dynamic>{};
      return <String, dynamic>{
        'id': playlist['id'],
        'name': playlist['name'],
        'coverImgUrl': playlist['coverImgUrl'],
        'description': playlist['description'],
        'trackCount': playlist['trackCount'],
        'playCount': playlist['playCount'],
      };
    }).toList();

    final results = await Future.wait(futures);
    return results.where((e) => e.isNotEmpty).cast<Map<String, dynamic>>().toList();
  }
}


