import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/toplist.dart';
import '../models/track.dart';
import '../models/song_detail.dart';
import 'url_service.dart';
import 'developer_mode_service.dart';

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

  /// 数据是否已缓存（是否已成功加载过）
  bool _isCached = false;
  bool get isCached => _isCached;

  /// 获取榜单列表（带缓存）
  Future<void> fetchToplists({
    MusicSource source = MusicSource.netease,
    bool forceRefresh = false,
  }) async {
    // 如果已有缓存且不是强制刷新，直接返回
    if (_isCached && !forceRefresh) {
      print('💾 [MusicService] 使用缓存数据，跳过加载');
      DeveloperModeService().addLog('💾 [MusicService] 使用缓存数据');
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🎵 [MusicService] 开始获取榜单列表...');
      print('🎵 [MusicService] 音乐源: ${source.name}');
      DeveloperModeService().addLog('🎵 [MusicService] 开始获取榜单 (${source.name})');
      
      if (forceRefresh) {
        print('🔄 [MusicService] 强制刷新模式');
        DeveloperModeService().addLog('🔄 [MusicService] 强制刷新');
      }

      final baseUrl = UrlService().baseUrl;
      final url = '$baseUrl/toplists';
      
      print('🎵 [MusicService] 请求URL: $url');
      DeveloperModeService().addLog('🌐 [Network] GET $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          DeveloperModeService().addLog('⏱️ [Network] 请求超时 (15s)');
          throw Exception('请求超时');
        },
      );

      print('🎵 [MusicService] 响应状态码: ${response.statusCode}');
      DeveloperModeService().addLog('📥 [Network] 状态码: ${response.statusCode}');
      
      // 记录响应体（前500字符）
      final responseBody = utf8.decode(response.bodyBytes);
      final truncatedBody = responseBody.length > 500 
          ? '${responseBody.substring(0, 500)}...' 
          : responseBody;
      DeveloperModeService().addLog('📄 [Network] 响应体: $truncatedBody');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        
        if (data['status'] == 200) {
          final toplistsData = data['toplists'] as List<dynamic>;
          _toplists = toplistsData
              .map((item) => Toplist.fromJson(item as Map<String, dynamic>, source: source))
              .toList();
          
          print('✅ [MusicService] 成功获取 ${_toplists.length} 个榜单');
          DeveloperModeService().addLog('✅ [MusicService] 成功获取 ${_toplists.length} 个榜单');
          
          // 打印每个榜单的歌曲数量
          for (var toplist in _toplists) {
            print('   📊 ${toplist.name}: ${toplist.tracks.length} 首歌曲');
          }
          
          _errorMessage = null;
          _isCached = true; // 标记数据已缓存
          print('💾 [MusicService] 数据已缓存');
          DeveloperModeService().addLog('💾 [MusicService] 数据已缓存');
        } else {
          _errorMessage = '获取榜单失败: 服务器返回状态 ${data['status']}';
          print('❌ [MusicService] $_errorMessage');
          DeveloperModeService().addLog('❌ [MusicService] $_errorMessage');
        }
      } else {
        _errorMessage = '获取榜单失败: HTTP ${response.statusCode}';
        print('❌ [MusicService] $_errorMessage');
        DeveloperModeService().addLog('❌ [MusicService] $_errorMessage');
      }
    } catch (e) {
      _errorMessage = '获取榜单失败: $e';
      print('❌ [MusicService] $_errorMessage');
      DeveloperModeService().addLog('❌ [MusicService] 获取榜单失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 刷新榜单（强制重新加载）
  Future<void> refreshToplists({MusicSource source = MusicSource.netease}) async {
    print('🔄 [MusicService] 手动刷新榜单');
    await fetchToplists(source: source, forceRefresh: true);
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
    required dynamic songId, // 支持 int 和 String
    AudioQuality quality = AudioQuality.exhigh,
    MusicSource source = MusicSource.netease,
  }) async {
    try {
      print('🎵 [MusicService] 获取歌曲详情: $songId (${source.name}), 音质: ${quality.displayName}');
      DeveloperModeService().addLog('🎵 [MusicService] 获取歌曲详情: $songId (${source.name})');

      final baseUrl = UrlService().baseUrl;
      String url;
      http.Response response;
      
      switch (source) {
        case MusicSource.netease:
          // 网易云音乐
          url = '$baseUrl/song';
          final requestBody = {
            'ids': songId.toString(),
            'level': quality.value,
            'type': 'json',
          };

          DeveloperModeService().addLog('🌐 [Network] POST $url');
          DeveloperModeService().addLog('📤 [Network] 请求体: ${requestBody.toString()}');

          response = await http.post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: requestBody,
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              DeveloperModeService().addLog('⏱️ [Network] 请求超时 (15s)');
              throw Exception('请求超时');
            },
          );
          break;

        case MusicSource.qq:
          // QQ音乐
          url = '$baseUrl/qq/song?ids=$songId';
          DeveloperModeService().addLog('🌐 [Network] GET $url');

          response = await http.get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
            },
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              DeveloperModeService().addLog('⏱️ [Network] 请求超时 (15s)');
              throw Exception('请求超时');
            },
          );
          break;

        case MusicSource.kugou:
          // 酷狗音乐
          url = '$baseUrl/kugou/song?emixsongid=$songId';
          DeveloperModeService().addLog('🌐 [Network] GET $url');

          response = await http.get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
            },
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              DeveloperModeService().addLog('⏱️ [Network] 请求超时 (15s)');
              throw Exception('请求超时');
            },
          );
          break;
      }

      print('🎵 [MusicService] 歌曲详情响应状态码: ${response.statusCode}');
      DeveloperModeService().addLog('📥 [Network] 状态码: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final truncatedBody = responseBody.length > 500 
            ? '${responseBody.substring(0, 500)}...' 
            : responseBody;
        DeveloperModeService().addLog('📄 [Network] 响应体: $truncatedBody');
        
        final data = json.decode(responseBody) as Map<String, dynamic>;

        if (data['status'] == 200) {
          SongDetail songDetail;
          
          if (source == MusicSource.qq) {
            // QQ音乐返回格式特殊处理
            final song = data['song'] as Map<String, dynamic>;
            final lyricData = data['lyric'] as Map<String, dynamic>?;
            final musicUrls = data['music_urls'] as Map<String, dynamic>?;
            
            // 选择音质（优先级：flac > 320 > 128）
            String playUrl = '';
            String bitrate = '';
            if (musicUrls != null) {
              if (musicUrls['flac'] != null) {
                playUrl = musicUrls['flac']['url'] ?? '';
                bitrate = musicUrls['flac']['bitrate'] ?? 'FLAC';
              } else if (musicUrls['320'] != null) {
                playUrl = musicUrls['320']['url'] ?? '';
                bitrate = musicUrls['320']['bitrate'] ?? '320kbps';
              } else if (musicUrls['128'] != null) {
                playUrl = musicUrls['128']['url'] ?? '';
                bitrate = musicUrls['128']['bitrate'] ?? '128kbps';
              }
            }
            
            songDetail = SongDetail(
              id: song['mid'] ?? song['id'] ?? songId,
              name: song['name'] ?? '',
              pic: song['pic'] ?? '',
              arName: song['singer'] ?? '',
              alName: song['album'] ?? '',
              level: bitrate,
              size: '0', // QQ音乐不返回文件大小
              url: playUrl,
              lyric: lyricData?['lyric'] ?? '',
              tlyric: lyricData?['tylyric'] ?? '',
              source: source,
            );
          } else if (source == MusicSource.kugou) {
            // 酷狗音乐返回格式
            final song = data['song'] as Map<String, dynamic>?;
            if (song == null) {
              print('❌ [MusicService] 酷狗音乐返回数据格式错误');
              return null;
            }
            
            // 处理 bitrate（可能是 int 或 String）
            final bitrateValue = song['bitrate'];
            final bitrate = bitrateValue != null ? '${bitrateValue}kbps' : '未知';
            
            songDetail = SongDetail(
              id: songId, // 使用传入的 emixsongid
              name: song['name'] ?? '',
              pic: song['pic'] ?? '',
              arName: song['singer'] ?? '',
              alName: song['album'] ?? '',
              level: bitrate,
              size: song['duration']?.toString() ?? '0', // 使用 duration 字段
              url: song['url'] ?? '',
              lyric: song['lyric'] ?? '',
              tlyric: '', // 酷狗音乐没有翻译歌词
              source: source,
            );
          } else {
            // 网易云音乐（原有格式）
            songDetail = SongDetail.fromJson(data, source: source);
          }
          
          print('✅ [MusicService] 成功获取歌曲详情: ${songDetail.name}');
          print('   🎵 艺术家: ${songDetail.arName}');
          print('   💿 专辑: ${songDetail.alName}');
          print('   🎼 音质: ${songDetail.level}');
          print('   📦 大小: ${songDetail.size}');
          print('   🔗 URL: ${songDetail.url.isNotEmpty ? "已获取" : "无"}');
          
          DeveloperModeService().addLog('✅ [MusicService] 成功获取歌曲: ${songDetail.name}');

          return songDetail;
        } else {
          print('❌ [MusicService] 获取歌曲详情失败: 服务器返回状态 ${data['status']}');
          DeveloperModeService().addLog('❌ [MusicService] 服务器状态 ${data['status']}');
          return null;
        }
      } else {
        print('❌ [MusicService] 获取歌曲详情失败: HTTP ${response.statusCode}');
        DeveloperModeService().addLog('❌ [Network] HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ [MusicService] 获取歌曲详情异常: $e');
      DeveloperModeService().addLog('❌ [MusicService] 异常: $e');
      return null;
    }
  }

  /// 清除数据和缓存
  void clear() {
    _toplists = [];
    _errorMessage = null;
    _isLoading = false;
    _isCached = false; // 清除缓存标志
    print('🗑️ [MusicService] 已清除数据和缓存');
    notifyListeners();
  }
}

