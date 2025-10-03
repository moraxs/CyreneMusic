import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/playlist.dart';
import '../models/track.dart';
import 'auth_service.dart';
import 'url_service.dart';

/// 歌单服务
class PlaylistService extends ChangeNotifier {
  static final PlaylistService _instance = PlaylistService._internal();
  factory PlaylistService() => _instance;
  PlaylistService._internal() {
    // 监听登录状态变化
    AuthService().addListener(_onAuthChanged);
  }

  List<Playlist> _playlists = [];
  List<Playlist> get playlists => _playlists;

  // 当前选中的歌单 ID
  int? _currentPlaylistId;
  int? get currentPlaylistId => _currentPlaylistId;

  // 当前歌单的歌曲列表
  List<PlaylistTrack> _currentTracks = [];
  List<PlaylistTrack> get currentTracks => _currentTracks;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingTracks = false;
  bool get isLoadingTracks => _isLoadingTracks;

  /// 监听认证状态变化
  void _onAuthChanged() {
    if (!AuthService().isLoggedIn) {
      // 用户登出时清空数据
      clear();
    }
  }

  /// 清空所有数据
  void clear() {
    _playlists = [];
    _currentPlaylistId = null;
    _currentTracks = [];
    notifyListeners();
  }

  /// 获取默认歌单（我的收藏）
  Playlist? get defaultPlaylist {
    return _playlists.firstWhere(
      (p) => p.isDefault,
      orElse: () => _playlists.isNotEmpty ? _playlists.first : Playlist(
        id: 0,
        name: '我的收藏',
        isDefault: true,
        trackCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// 加载歌单列表
  Future<void> loadPlaylists() async {
    if (!AuthService().isLoggedIn) {
      print('⚠️ [PlaylistService] 未登录，无法加载歌单');
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
        Uri.parse('$baseUrl/playlists'),
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
          final List<dynamic> playlistsJson = data['playlists'] ?? [];
          _playlists = playlistsJson
              .map((item) => Playlist.fromJson(item as Map<String, dynamic>))
              .toList();

          print('✅ [PlaylistService] 加载歌单列表: ${_playlists.length} 个');
        } else {
          throw Exception(data['message'] ?? '加载失败');
        }
      } else if (response.statusCode == 401) {
        print('⚠️ [PlaylistService] 未授权，需要重新登录');
        AuthService().logout();
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [PlaylistService] 加载歌单列表失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 创建新歌单
  Future<bool> createPlaylist(String name) async {
    if (!AuthService().isLoggedIn) {
      print('⚠️ [PlaylistService] 未登录，无法创建歌单');
      return false;
    }

    if (name.trim().isEmpty) {
      print('⚠️ [PlaylistService] 歌单名称不能为空');
      return false;
    }

    try {
      final baseUrl = UrlService().baseUrl;
      final userId = AuthService().currentUser?.id;
      if (userId == null) {
        throw Exception('无法获取用户ID');
      }
      final token = 'user_$userId';

      final response = await http.post(
        Uri.parse('$baseUrl/playlists'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'name': name.trim()}),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('请求超时'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        if (data['status'] == 200) {
          // 添加到本地列表
          final newPlaylist = Playlist.fromJson(data['playlist'] as Map<String, dynamic>);
          _playlists.add(newPlaylist);

          print('✅ [PlaylistService] 创建歌单成功: $name');
          notifyListeners();
          return true;
        } else {
          throw Exception(data['message'] ?? '创建失败');
        }
      } else if (response.statusCode == 401) {
        print('⚠️ [PlaylistService] 未授权，需要重新登录');
        AuthService().logout();
        return false;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [PlaylistService] 创建歌单失败: $e');
      return false;
    }
  }

  /// 更新歌单（重命名）
  Future<bool> updatePlaylist(int playlistId, String name) async {
    if (!AuthService().isLoggedIn) {
      print('⚠️ [PlaylistService] 未登录，无法更新歌单');
      return false;
    }

    if (name.trim().isEmpty) {
      print('⚠️ [PlaylistService] 歌单名称不能为空');
      return false;
    }

    try {
      final baseUrl = UrlService().baseUrl;
      final userId = AuthService().currentUser?.id;
      if (userId == null) {
        throw Exception('无法获取用户ID');
      }
      final token = 'user_$userId';

      final response = await http.put(
        Uri.parse('$baseUrl/playlists/$playlistId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'name': name.trim()}),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('请求超时'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        if (data['status'] == 200) {
          // 更新本地列表
          final index = _playlists.indexWhere((p) => p.id == playlistId);
          if (index != -1) {
            _playlists[index] = Playlist(
              id: _playlists[index].id,
              name: name.trim(),
              isDefault: _playlists[index].isDefault,
              trackCount: _playlists[index].trackCount,
              createdAt: _playlists[index].createdAt,
              updatedAt: DateTime.now(),
            );
          }

          print('✅ [PlaylistService] 更新歌单成功: $name');
          notifyListeners();
          return true;
        } else {
          throw Exception(data['message'] ?? '更新失败');
        }
      } else if (response.statusCode == 401) {
        print('⚠️ [PlaylistService] 未授权，需要重新登录');
        AuthService().logout();
        return false;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [PlaylistService] 更新歌单失败: $e');
      return false;
    }
  }

  /// 删除歌单
  Future<bool> deletePlaylist(int playlistId) async {
    if (!AuthService().isLoggedIn) {
      print('⚠️ [PlaylistService] 未登录，无法删除歌单');
      return false;
    }

    try {
      final baseUrl = UrlService().baseUrl;
      final userId = AuthService().currentUser?.id;
      if (userId == null) {
        throw Exception('无法获取用户ID');
      }
      final token = 'user_$userId';

      final response = await http.delete(
        Uri.parse('$baseUrl/playlists/$playlistId'),
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
          _playlists.removeWhere((p) => p.id == playlistId);

          // 如果删除的是当前选中的歌单，清空当前歌曲列表
          if (_currentPlaylistId == playlistId) {
            _currentPlaylistId = null;
            _currentTracks = [];
          }

          print('✅ [PlaylistService] 删除歌单成功');
          notifyListeners();
          return true;
        } else {
          throw Exception(data['message'] ?? '删除失败');
        }
      } else if (response.statusCode == 401) {
        print('⚠️ [PlaylistService] 未授权，需要重新登录');
        AuthService().logout();
        return false;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [PlaylistService] 删除歌单失败: $e');
      return false;
    }
  }

  /// 添加歌曲到歌单
  Future<bool> addTrackToPlaylist(int playlistId, Track track) async {
    if (!AuthService().isLoggedIn) {
      print('⚠️ [PlaylistService] 未登录，无法添加歌曲');
      return false;
    }

    try {
      final baseUrl = UrlService().baseUrl;
      final userId = AuthService().currentUser?.id;
      if (userId == null) {
        throw Exception('无法获取用户ID');
      }
      final token = 'user_$userId';
      final playlistTrack = PlaylistTrack.fromTrack(track);

      final response = await http.post(
        Uri.parse('$baseUrl/playlists/$playlistId/tracks'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(playlistTrack.toJson()),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('请求超时'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        if (data['status'] == 200) {
          // 更新歌单的歌曲数量
          final index = _playlists.indexWhere((p) => p.id == playlistId);
          if (index != -1) {
            _playlists[index] = Playlist(
              id: _playlists[index].id,
              name: _playlists[index].name,
              isDefault: _playlists[index].isDefault,
              trackCount: _playlists[index].trackCount + 1,
              createdAt: _playlists[index].createdAt,
              updatedAt: DateTime.now(),
            );
          }

          // 如果是当前选中的歌单，添加到当前列表
          if (_currentPlaylistId == playlistId) {
            _currentTracks.insert(0, playlistTrack);
          }

          print('✅ [PlaylistService] 添加歌曲成功: ${track.name}');
          notifyListeners();
          return true;
        } else {
          throw Exception(data['message'] ?? '添加失败');
        }
      } else if (response.statusCode == 401) {
        print('⚠️ [PlaylistService] 未授权，需要重新登录');
        AuthService().logout();
        return false;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [PlaylistService] 添加歌曲失败: $e');
      return false;
    }
  }

  /// 加载歌单中的歌曲
  Future<void> loadPlaylistTracks(int playlistId) async {
    if (!AuthService().isLoggedIn) {
      print('⚠️ [PlaylistService] 未登录，无法加载歌曲');
      return;
    }

    try {
      _isLoadingTracks = true;
      _currentPlaylistId = playlistId;
      notifyListeners();

      final baseUrl = UrlService().baseUrl;
      final userId = AuthService().currentUser?.id;
      if (userId == null) {
        throw Exception('无法获取用户ID');
      }
      final token = 'user_$userId';

      final response = await http.get(
        Uri.parse('$baseUrl/playlists/$playlistId/tracks'),
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
          final List<dynamic> tracksJson = data['tracks'] ?? [];
          _currentTracks = tracksJson
              .map((item) => PlaylistTrack.fromJson(item as Map<String, dynamic>))
              .toList();

          print('✅ [PlaylistService] 加载歌曲列表: ${_currentTracks.length} 首');
        } else {
          throw Exception(data['message'] ?? '加载失败');
        }
      } else if (response.statusCode == 401) {
        print('⚠️ [PlaylistService] 未授权，需要重新登录');
        AuthService().logout();
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [PlaylistService] 加载歌曲列表失败: $e');
    } finally {
      _isLoadingTracks = false;
      notifyListeners();
    }
  }

  /// 从歌单删除歌曲
  Future<bool> removeTrackFromPlaylist(int playlistId, PlaylistTrack track) async {
    if (!AuthService().isLoggedIn) {
      print('⚠️ [PlaylistService] 未登录，无法删除歌曲');
      return false;
    }

    try {
      final baseUrl = UrlService().baseUrl;
      final userId = AuthService().currentUser?.id;
      if (userId == null) {
        throw Exception('无法获取用户ID');
      }
      final token = 'user_$userId';
      final source = track.source.toString().split('.').last;
      
      // 诊断日志
      print('🗑️ [PlaylistService] 准备删除歌曲:');
      print('   PlaylistId: $playlistId');
      print('   TrackId: ${track.trackId}');
      print('   Source: $source');
      print('   URL: $baseUrl/playlists/$playlistId/tracks/remove');

      // 使用 POST 请求代替 DELETE（避免某些框架的解析问题）
      final response = await http.post(
        Uri.parse('$baseUrl/playlists/$playlistId/tracks/remove'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'trackId': track.trackId,
          'source': source,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('请求超时'),
      );
      
      print('📥 [PlaylistService] 删除请求响应状态码: ${response.statusCode}');
      if (response.statusCode != 200) {
        print('📄 [PlaylistService] 响应内容: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        if (data['status'] == 200) {
          // 更新歌单的歌曲数量
          final index = _playlists.indexWhere((p) => p.id == playlistId);
          if (index != -1) {
            _playlists[index] = Playlist(
              id: _playlists[index].id,
              name: _playlists[index].name,
              isDefault: _playlists[index].isDefault,
              trackCount: _playlists[index].trackCount - 1,
              createdAt: _playlists[index].createdAt,
              updatedAt: DateTime.now(),
            );
          }

          // 从当前列表删除
          if (_currentPlaylistId == playlistId) {
            _currentTracks.removeWhere((t) => 
              t.trackId == track.trackId && t.source == track.source
            );
          }

          print('✅ [PlaylistService] 删除歌曲成功');
          notifyListeners();
          return true;
        } else {
          throw Exception(data['message'] ?? '删除失败');
        }
      } else if (response.statusCode == 401) {
        print('⚠️ [PlaylistService] 未授权，需要重新登录');
        AuthService().logout();
        return false;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [PlaylistService] 删除歌曲失败: $e');
      return false;
    }
  }

  /// 检查歌曲是否在指定歌单中
  bool isTrackInPlaylist(int playlistId, Track track) {
    if (_currentPlaylistId != playlistId) {
      return false;
    }
    return _currentTracks.any((t) => 
      t.trackId == track.id.toString() && t.source == track.source
    );
  }
}

