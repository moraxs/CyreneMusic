import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/track.dart';

/// 播放历史记录模型
class PlayHistoryItem {
  final String id;           // 歌曲唯一ID
  final String name;         // 歌曲名称
  final String artists;      // 艺术家
  final String album;        // 专辑
  final String picUrl;       // 封面图片URL
  final MusicSource source;  // 音乐平台
  final DateTime playedAt;   // 播放时间

  PlayHistoryItem({
    required this.id,
    required this.name,
    required this.artists,
    required this.album,
    required this.picUrl,
    required this.source,
    required this.playedAt,
  });

  /// 从 Track 对象创建
  factory PlayHistoryItem.fromTrack(Track track) {
    return PlayHistoryItem(
      id: track.id.toString(),
      name: track.name,
      artists: track.artists,
      album: track.album,
      picUrl: track.picUrl,
      source: track.source,
      playedAt: DateTime.now(),
    );
  }

  /// 转换为 Track 对象
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

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'artists': artists,
      'album': album,
      'picUrl': picUrl,
      'source': source.toString().split('.').last,
      'playedAt': playedAt.toIso8601String(),
    };
  }

  /// 从 JSON 创建
  factory PlayHistoryItem.fromJson(Map<String, dynamic> json) {
    return PlayHistoryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      artists: json['artists'] as String,
      album: json['album'] as String,
      picUrl: json['picUrl'] as String,
      source: MusicSource.values.firstWhere(
        (e) => e.toString().split('.').last == json['source'],
        orElse: () => MusicSource.netease,
      ),
      playedAt: DateTime.parse(json['playedAt'] as String),
    );
  }
}

/// 播放历史服务
class PlayHistoryService extends ChangeNotifier {
  static final PlayHistoryService _instance = PlayHistoryService._internal();
  factory PlayHistoryService() => _instance;
  PlayHistoryService._internal() {
    _loadHistory();
  }

  List<PlayHistoryItem> _history = [];
  List<PlayHistoryItem> get history => _history;

  static const String _historyKey = 'play_history';
  static const int _maxHistoryCount = 500; // 最多保存500条历史记录

  /// 加载播放历史
  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey);
      
      if (historyJson != null) {
        final List<dynamic> decoded = json.decode(historyJson);
        _history = decoded
            .map((item) => PlayHistoryItem.fromJson(item as Map<String, dynamic>))
            .toList();
        
        print('📚 [PlayHistoryService] 加载播放历史: ${_history.length} 条');
      }
    } catch (e) {
      print('❌ [PlayHistoryService] 加载播放历史失败: $e');
      _history = [];
    }
  }

  /// 添加播放记录
  Future<void> addToHistory(Track track) async {
    try {
      final historyItem = PlayHistoryItem.fromTrack(track);
      
      // 检查是否已存在相同的歌曲（同一平台、同一ID）
      _history.removeWhere((item) => 
        item.id == historyItem.id && item.source == historyItem.source
      );
      
      // 添加到列表开头
      _history.insert(0, historyItem);
      
      // 限制历史记录数量
      if (_history.length > _maxHistoryCount) {
        _history = _history.sublist(0, _maxHistoryCount);
      }
      
      // 保存到本地
      await _saveHistory();
      
      print('💾 [PlayHistoryService] 添加播放记录: ${track.name}');
      notifyListeners();
    } catch (e) {
      print('❌ [PlayHistoryService] 添加播放记录失败: $e');
    }
  }

  /// 保存播放历史到本地
  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = json.encode(
        _history.map((item) => item.toJson()).toList(),
      );
      await prefs.setString(_historyKey, historyJson);
    } catch (e) {
      print('❌ [PlayHistoryService] 保存播放历史失败: $e');
    }
  }

  /// 删除单条历史记录
  Future<void> removeHistoryItem(PlayHistoryItem item) async {
    try {
      _history.remove(item);
      await _saveHistory();
      
      print('🗑️ [PlayHistoryService] 删除播放记录: ${item.name}');
      notifyListeners();
    } catch (e) {
      print('❌ [PlayHistoryService] 删除播放记录失败: $e');
    }
  }

  /// 清空所有播放历史
  Future<void> clearHistory() async {
    try {
      _history.clear();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
      
      print('🗑️ [PlayHistoryService] 清空所有播放历史');
      notifyListeners();
    } catch (e) {
      print('❌ [PlayHistoryService] 清空播放历史失败: $e');
    }
  }

  /// 获取下一首要播放的歌曲
  Track? getNextTrack() {
    // 如果历史记录少于2条，没有下一首
    if (_history.length < 2) {
      return null;
    }
    
    // 返回历史记录中的第二首（索引1）
    return _history[1].toTrack();
  }

  /// 获取今天的播放统计
  int getTodayPlayCount() {
    final today = DateTime.now();
    return _history.where((item) {
      return item.playedAt.year == today.year &&
             item.playedAt.month == today.month &&
             item.playedAt.day == today.day;
    }).length;
  }

  /// 获取本周的播放统计
  int getWeekPlayCount() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return _history.where((item) => item.playedAt.isAfter(weekAgo)).length;
  }

  /// 获取最常播放的歌曲 Top 10
  List<MapEntry<String, int>> getTopTracks({int limit = 10}) {
    final Map<String, int> trackCounts = {};
    
    for (final item in _history) {
      final key = '${item.name}|${item.artists}';
      trackCounts[key] = (trackCounts[key] ?? 0) + 1;
    }
    
    final sorted = trackCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.take(limit).toList();
  }
}

