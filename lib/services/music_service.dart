import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/toplist.dart';
import '../models/track.dart';
import '../models/song_detail.dart';
import 'url_service.dart';

/// 音乐服务 - 处理与音乐相关的API请求
class MusicService extends ChangeNotifier {
  static final MusicService _instance = MusicService._internal();
  factory MusicService() => _instance;
  MusicService._internal();

  /// 榜单列表
  List<Toplist> _toplists = [];
  List<Toplist> get toplists => _toplists;

  /// 是否正在加载
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// 错误信息
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// 获取榜单列表
  Future<void> fetchToplists({MusicSource source = MusicSource.netease}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🎵 [MusicService] 开始获取榜单列表...');
      print('🎵 [MusicService] 音乐源: ${source.name}');

      final baseUrl = UrlService().baseUrl;
      final url = '$baseUrl/toplists';
      
      print('🎵 [MusicService] 请求URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('请求超时');
        },
      );

      print('🎵 [MusicService] 响应状态码: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        
        if (data['status'] == 200) {
          final toplistsData = data['toplists'] as List<dynamic>;
          _toplists = toplistsData
              .map((item) => Toplist.fromJson(item as Map<String, dynamic>, source: source))
              .toList();
          
          print('✅ [MusicService] 成功获取 ${_toplists.length} 个榜单');
          
          // 打印每个榜单的歌曲数量
          for (var toplist in _toplists) {
            print('   📊 ${toplist.name}: ${toplist.tracks.length} 首歌曲');
          }
          
          _errorMessage = null;
        } else {
          _errorMessage = '获取榜单失败: 服务器返回状态 ${data['status']}';
          print('❌ [MusicService] $_errorMessage');
        }
      } else {
        _errorMessage = '获取榜单失败: HTTP ${response.statusCode}';
        print('❌ [MusicService] $_errorMessage');
      }
    } catch (e) {
      _errorMessage = '获取榜单失败: $e';
      print('❌ [MusicService] $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 刷新榜单
  Future<void> refreshToplists({MusicSource source = MusicSource.netease}) async {
    await fetchToplists(source: source);
  }

  /// 根据英文名称获取榜单
  Toplist? getToplistByNameEn(String nameEn) {
    try {
      return _toplists.firstWhere((toplist) => toplist.nameEn == nameEn);
    } catch (e) {
      return null;
    }
  }

  /// 根据ID获取榜单
  Toplist? getToplistById(int id) {
    try {
      return _toplists.firstWhere((toplist) => toplist.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 获取推荐榜单（前4个）
  List<Toplist> getRecommendedToplists() {
    return _toplists.take(4).toList();
  }

  /// 从所有榜单中随机获取指定数量的歌曲
  List<Track> getRandomTracks(int count) {
    // 收集所有榜单的所有歌曲
    final allTracks = <Track>[];
    for (var toplist in _toplists) {
      allTracks.addAll(toplist.tracks);
    }

    if (allTracks.isEmpty) {
      return [];
    }

    // 去重（基于歌曲ID）
    final uniqueTracks = <int, Track>{};
    for (var track in allTracks) {
      uniqueTracks[track.id] = track;
    }

    final trackList = uniqueTracks.values.toList();
    
    // 如果歌曲数量不足，返回所有歌曲
    if (trackList.length <= count) {
      return trackList;
    }

    // 随机打乱并返回指定数量
    trackList.shuffle();
    return trackList.take(count).toList();
  }

  /// 获取歌曲详情
  Future<SongDetail?> fetchSongDetail({
    required int songId,
    AudioQuality quality = AudioQuality.exhigh,
    MusicSource source = MusicSource.netease,
  }) async {
    try {
      print('🎵 [MusicService] 获取歌曲详情: $songId, 音质: ${quality.displayName}');

      final baseUrl = UrlService().baseUrl;
      final url = '$baseUrl/song';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'ids': songId.toString(),
          'level': quality.value,
          'type': 'json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('请求超时');
        },
      );

      print('🎵 [MusicService] 歌曲详情响应状态码: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        if (data['status'] == 200) {
          final songDetail = SongDetail.fromJson(data, source: source);
          
          print('✅ [MusicService] 成功获取歌曲详情: ${songDetail.name}');
          print('   🎵 艺术家: ${songDetail.arName}');
          print('   💿 专辑: ${songDetail.alName}');
          print('   🎼 音质: ${songDetail.level}');
          print('   📦 大小: ${songDetail.size}');
          print('   🔗 URL: ${songDetail.url.isNotEmpty ? "已获取" : "无"}');

          return songDetail;
        } else {
          print('❌ [MusicService] 获取歌曲详情失败: 服务器返回状态 ${data['status']}');
          return null;
        }
      } else {
        print('❌ [MusicService] 获取歌曲详情失败: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ [MusicService] 获取歌曲详情异常: $e');
      return null;
    }
  }

  /// 清除数据
  void clear() {
    _toplists = [];
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}

