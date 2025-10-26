import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'url_service.dart';

class NeteaseAlbumService extends ChangeNotifier {
  static final NeteaseAlbumService _instance = NeteaseAlbumService._internal();
  factory NeteaseAlbumService() => _instance;
  NeteaseAlbumService._internal();

  Future<Map<String, dynamic>?> fetchAlbumDetail(int id) async {
    try {
      final baseUrl = UrlService().baseUrl;
      final url = '$baseUrl/album?id=$id';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return null;
      final data = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (data['status'] != 200) return null;
      return data['data'] as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}
