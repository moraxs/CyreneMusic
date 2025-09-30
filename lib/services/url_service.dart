import 'package:flutter/foundation.dart';

/// 后端源类型
enum BackendSourceType {
  official, // 官方源
  custom,   // 自定义源
}

/// URL 服务 - 管理所有后端 API 地址
class UrlService extends ChangeNotifier {
  static final UrlService _instance = UrlService._internal();
  factory UrlService() => _instance;
  UrlService._internal();

  /// 官方源地址
  static const String officialBaseUrl = 'http://127.0.0.1:4055';

  /// 当前源类型
  BackendSourceType _sourceType = BackendSourceType.official;

  /// 自定义源地址
  String _customBaseUrl = '';

  /// 获取当前源类型
  BackendSourceType get sourceType => _sourceType;

  /// 获取当前基础 URL
  String get baseUrl {
    switch (_sourceType) {
      case BackendSourceType.official:
        return officialBaseUrl;
      case BackendSourceType.custom:
        return _customBaseUrl.isNotEmpty ? _customBaseUrl : officialBaseUrl;
    }
  }

  /// 获取自定义源地址
  String get customBaseUrl => _customBaseUrl;

  /// 是否使用官方源
  bool get isUsingOfficialSource => _sourceType == BackendSourceType.official;

  /// 设置后端源类型
  void setSourceType(BackendSourceType type) {
    if (_sourceType != type) {
      _sourceType = type;
      notifyListeners();
    }
  }

  /// 设置自定义源地址
  void setCustomBaseUrl(String url) {
    // 移除末尾的斜杠
    final cleanUrl = url.trim().endsWith('/') 
        ? url.trim().substring(0, url.trim().length - 1) 
        : url.trim();
    
    if (_customBaseUrl != cleanUrl) {
      _customBaseUrl = cleanUrl;
      notifyListeners();
    }
  }

  /// 切换到官方源
  void useOfficialSource() {
    setSourceType(BackendSourceType.official);
  }

  /// 切换到自定义源
  void useCustomSource(String url) {
    setCustomBaseUrl(url);
    setSourceType(BackendSourceType.custom);
  }

  // ==================== API 端点 ====================

  // Netease API
  String get searchUrl => '$baseUrl/search';
  String get songUrl => '$baseUrl/song';
  String get toplistsUrl => '$baseUrl/toplists';

  // QQ Music API
  String get qqSearchUrl => '$baseUrl/qq/search';
  String get qqSongUrl => '$baseUrl/qq/song';

  // Kugou API
  String get kugouSearchUrl => '$baseUrl/kugou/search';
  String get kugouSongUrl => '$baseUrl/kugou/song';

  // Bilibili API
  String get biliRankingUrl => '$baseUrl/bili/ranking';
  String get biliCidUrl => '$baseUrl/bili/cid';
  String get biliPlayurlUrl => '$baseUrl/bili/playurl';
  String get biliPgcSeasonUrl => '$baseUrl/bili/pgc_season';
  String get biliPgcPlayurlUrl => '$baseUrl/bili/pgc_playurl';
  String get biliDanmakuUrl => '$baseUrl/bili/danmaku';
  String get biliSearchUrl => '$baseUrl/bili/search';
  String get biliCommentsUrl => '$baseUrl/bili/comments';
  String get biliProxyUrl => '$baseUrl/bili/proxy';

  // Douyin API
  String get douyinUrl => '$baseUrl/douyin';

  // Version API
  String get versionLatestUrl => '$baseUrl/version/latest';

  /// 验证 URL 格式
  static bool isValidUrl(String url) {
    if (url.isEmpty) return false;
    
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// 获取当前源描述
  String getSourceDescription() {
    switch (_sourceType) {
      case BackendSourceType.official:
        return '官方源（默认后端服务）';
      case BackendSourceType.custom:
        return '自定义源 (${_customBaseUrl.isNotEmpty ? _customBaseUrl : '未设置'})';
    }
  }

  /// 获取健康检查 URL
  String get healthCheckUrl => baseUrl;
}
