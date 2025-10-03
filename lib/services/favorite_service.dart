import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/track.dart';
import 'auth_service.dart';
import 'url_service.dart';

/// 收藏歌曲模型
class FavoriteTrack {
  final String id;
  final String name;
  final String artists;
  final String album;
  final String picUrl;
  final MusicSource source;
  final DateTime addedAt;

  FavoriteTrack({
    required this.id,
    required this.name,
    required this.artists,
    required this.album,
    required this.picUrl,
    required this.source,
    required this.addedAt,
  });

  /// 从 Track 创建
  factory FavoriteTrack.fromTrack(Track track) {
    return FavoriteTrack(
      id: track.id.toString(),
      name: track.name,
      artists: track.artists,
      album: track.album,
      picUrl: track.picUrl,
      source: track.source,
      addedAt: DateTime.now(),
    );
  }

  /// 从 JSON 创建
  factory FavoriteTrack.fromJson(Map<String, dynamic> json) {
    return FavoriteTrack(
      id: json['trackId'] as String,
      name: json['name'] as String,
      artists: json['artists'] as String,
      album: json['album'] as String,
      picUrl: json['picUrl'] as String,
      source: MusicSource.values.firstWhere(
        (e) => e.toString().split('.').last == json['source'],
        orElse: () => MusicSource.netease,
      ),
      addedAt: DateTime.parse(json['addedAt'] as String),
    );
  }

  /// 转换为 Track
  Track toTrack() {
    return Track(
      id: id,
      name: name,
      artists: artists,
      album: album,
      picUrl: picUrl,
      source: source,
    );
  }

  /// 转换为 JSON（用于发送到后端）
  Map<String, dynamic> toJson() {
    return {
      'trackId': id,
      'name': name,
      'artists': artists,
      'album': album,
      'picUrl': picUrl,
      'source': source.toString().split('.').last,
    };
  }
}

/// 收藏服务
class FavoriteService extends ChangeNotifier {
  static final FavoriteService _instance = FavoriteService._internal();
  factory FavoriteService() => _instance;
  FavoriteService._internal() {
    // 监听登录状态变化
    AuthService().addListener(_onAuthChanged);
  }

  List<FavoriteTrack> _favorites = [];
  List<FavoriteTrack> get favorites => _favorites;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Set<String> _favoriteIds = {}; // 用于快速查找

  /// 监听认证状态变化
  void _onAuthChanged() {
    if (!AuthService().isLoggedIn) {
      // 用户登出时清空收藏列表
      clear();
    }
  }

  /// 检查歌曲是否已收藏
  bool isFavorite(Track track) {
    final key = '${track.source}_${track.id}';
    return _favoriteIds.contains(key);
  }

  /// 加载收藏列表
  Future<void> loadFavorites() async {
    if (!AuthService().isLoggedIn) {
      print('⚠️ [FavoriteService] 未登录，无法加载收藏');
      return;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final baseUrl = UrlService().baseUrl;
      final userId = AuthService().currentUser?.id;
      if (userId == null) {
        throw Exception('无法获取用户ID');
      }
      final token = 'user_$userId';
      
      final response = await http.get(
        Uri.parse('$baseUrl/favorites'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('请求超时'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        
        if (data['status'] == 200) {
          final List<dynamic> favoritesJson = data['favorites'] ?? [];
          _favorites = favoritesJson
              .map((item) => FavoriteTrack.fromJson(item as Map<String, dynamic>))
              .toList();
          
          // 更新快速查找集合
          _favoriteIds = _favorites
              .map((f) => '${f.source}_${f.id}')
              .toSet();
          
          print('✅ [FavoriteService] 加载收藏列表: ${_favorites.length} 首');
        } else {
          throw Exception(data['message'] ?? '加载失败');
        }
      } else if (response.statusCode == 401) {
        print('⚠️ [FavoriteService] 未授权，需要重新登录');
        AuthService().logout();
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [FavoriteService] 加载收藏列表失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 添加收藏
  Future<bool> addFavorite(Track track) async {
    if (!AuthService().isLoggedIn) {
      print('⚠️ [FavoriteService] 未登录，无法添加收藏');
      return false;
    }

    try {
      final baseUrl = UrlService().baseUrl;
      final userId = AuthService().currentUser?.id;
      if (userId == null) {
        throw Exception('无法获取用户ID');
      }
      final token = 'user_$userId';
      final favoriteTrack = FavoriteTrack.fromTrack(track);

      final response = await http.post(
        Uri.parse('$baseUrl/favorites'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(favoriteTrack.toJson()),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('请求超时'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        
        if (data['status'] == 200) {
          // 添加到本地列表
          _favorites.insert(0, favoriteTrack);
          _favoriteIds.add('${track.source}_${track.id}');
          
          print('✅ [FavoriteService] 添加收藏成功: ${track.name}');
          notifyListeners();
          return true;
        } else {
          throw Exception(data['message'] ?? '添加失败');
        }
      } else if (response.statusCode == 401) {
        print('⚠️ [FavoriteService] 未授权，需要重新登录');
        AuthService().logout();
        return false;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [FavoriteService] 添加收藏失败: $e');
      return false;
    }
  }

  /// 删除收藏
  Future<bool> removeFavorite(Track track) async {
    if (!AuthService().isLoggedIn) {
      print('⚠️ [FavoriteService] 未登录，无法删除收藏');
      return false;
    }

    try {
      final baseUrl = UrlService().baseUrl;
      final userId = AuthService().currentUser?.id;
      if (userId == null) {
        throw Exception('无法获取用户ID');
      }
      final token = 'user_$userId';
      final trackId = track.id.toString();
      final source = track.source.toString().split('.').last;

      final response = await http.delete(
        Uri.parse('$baseUrl/favorites/$trackId/$source'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('请求超时'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        
        if (data['status'] == 200) {
          // 从本地列表删除
          _favorites.removeWhere((f) => f.id == trackId && f.source == track.source);
          _favoriteIds.remove('${track.source}_${track.id}');
          
          print('✅ [FavoriteService] 删除收藏成功: ${track.name}');
          notifyListeners();
          return true;
        } else {
          throw Exception(data['message'] ?? '删除失败');
        }
      } else if (response.statusCode == 401) {
        print('⚠️ [FavoriteService] 未授权，需要重新登录');
        AuthService().logout();
        return false;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [FavoriteService] 删除收藏失败: $e');
      return false;
    }
  }

  /// 切换收藏状态
  Future<bool> toggleFavorite(Track track) async {
    if (isFavorite(track)) {
      return await removeFavorite(track);
    } else {
      return await addFavorite(track);
    }
  }

  /// 清空收藏列表（登出时调用）
  void clear() {
    _favorites.clear();
    _favoriteIds.clear();
    notifyListeners();
  }
}

