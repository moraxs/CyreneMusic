import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/version_info.dart';
import 'url_service.dart';
import 'developer_mode_service.dart';

/// 版本检查服务
/// 
/// ⚠️⚠️⚠️ 重要：发布新版本时的更新步骤 ⚠️⚠️⚠️
/// 1. 更新 lib/services/version_service.dart 中的 kAppVersion 常量
/// 2. 更新 pubspec.yaml 中的 version 字段
/// 3. 更新后端 backend/src/index.ts 中的版本信息
/// 
/// 示例：
///   kAppVersion: '1.0.0' → '1.0.1'
///   pubspec.yaml: version: 1.0.0+1 → version: 1.0.1+2
///   backend: version: "1.0.0" → version: "1.0.1"
class VersionService extends ChangeNotifier {
  static final VersionService _instance = VersionService._internal();
  factory VersionService() => _instance;
  VersionService._internal();

  /// ⚠️⚠️⚠️ 应用当前版本（硬编码）⚠️⚠️⚠️
  /// 发布新版本时 **必须** 手动更新此值！
  static const String kAppVersion = '1.0.5';

  /// 当前应用版本
  String _currentVersion = kAppVersion;
  String get currentVersion => _currentVersion;

  /// 最新版本信息
  VersionInfo? _latestVersion;
  VersionInfo? get latestVersion => _latestVersion;

  /// 是否正在检查更新
  bool _isChecking = false;
  bool get isChecking => _isChecking;

  /// 是否有可用更新
  bool get hasUpdate {
    if (_latestVersion == null || _currentVersion.isEmpty) {
      return false;
    }
    return _compareVersions(_latestVersion!.version, _currentVersion) > 0;
  }

  /// 检查是否应该提示更新（考虑用户已忽略的版本）
  Future<bool> shouldShowUpdateDialog(VersionInfo versionInfo) async {
    try {
      // 如果是强制更新，总是提示
      if (versionInfo.forceUpdate) {
        return true;
      }

      // 检查用户是否已忽略此版本
      final prefs = await SharedPreferences.getInstance();
      final ignoredVersion = prefs.getString('ignored_update_version') ?? '';
      
      // 如果用户已忽略某个版本，检查最新版本是否更新
      if (ignoredVersion.isNotEmpty) {
        // 只有当最新版本 > 已忽略版本时，才提示
        final comparison = _compareVersions(versionInfo.version, ignoredVersion);
        if (comparison <= 0) {
          print('🔕 [VersionService] 用户已忽略版本 $ignoredVersion，当前版本 ${versionInfo.version} 不更新');
          return false;
        } else {
          print('✅ [VersionService] 发现新版本 ${versionInfo.version}，大于已忽略版本 $ignoredVersion');
        }
      }

      return true;
    } catch (e) {
      print('❌ [VersionService] 检查忽略版本失败: $e');
      return true; // 出错时默认提示
    }
  }

  /// 忽略当前版本的更新（永久忽略）
  Future<void> ignoreCurrentVersion(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ignored_update_version', version);
      print('🔕 [VersionService] 已永久忽略版本: $version');
    } catch (e) {
      print('❌ [VersionService] 保存忽略版本失败: $e');
    }
  }

  /// 稍后提醒（仅在本次会话中忽略）
  /// 记录本次会话中已提醒过的版本，避免重复提示
  final Set<String> _remindedVersions = {};

  /// 标记某个版本在本次会话中已提醒
  void markVersionReminded(String version) {
    _remindedVersions.add(version);
    print('⏰ [VersionService] 已标记版本 $version 为稍后提醒（本次会话）');
  }

  /// 检查某个版本在本次会话中是否已提醒过
  bool hasRemindedInSession(String version) {
    return _remindedVersions.contains(version);
  }

  /// 清除忽略的版本（用于测试或重置）
  Future<void> clearIgnoredVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ignored_update_version');
      print('✅ [VersionService] 已清除忽略的版本');
    } catch (e) {
      print('❌ [VersionService] 清除忽略版本失败: $e');
    }
  }

  /// 初始化服务（获取当前版本）
  Future<void> initialize() async {
    try {
      // 尝试从 package_info_plus 获取版本（可选）
      final packageInfo = await PackageInfo.fromPlatform();
      if (packageInfo.version.isNotEmpty) {
        _currentVersion = packageInfo.version;
        print('📱 [VersionService] 从 PackageInfo 获取版本: $_currentVersion');
      } else {
        // 如果获取失败，使用硬编码版本
        _currentVersion = kAppVersion;
        print('📱 [VersionService] 使用硬编码版本: $_currentVersion');
      }
      DeveloperModeService().addLog('📱 当前版本: $_currentVersion');
    } catch (e) {
      // 获取失败时使用硬编码版本
      print('⚠️ [VersionService] PackageInfo 获取失败，使用硬编码版本: $kAppVersion');
      _currentVersion = kAppVersion;
      DeveloperModeService().addLog('📱 当前版本: $_currentVersion');
    }
  }

  /// 检查更新
  Future<VersionInfo?> checkForUpdate({bool silent = false}) async {
    if (_isChecking) {
      print('⚠️ [VersionService] 正在检查更新，跳过重复请求');
      return null;
    }

    _isChecking = true;
    if (!silent) {
      notifyListeners();
    }

    try {
      print('🔍 [VersionService] 开始检查更新...');
      if (!silent) {
        DeveloperModeService().addLog('🔍 检查更新中...');
      }

      final baseUrl = UrlService().baseUrl;
      final url = '$baseUrl/version/latest';

      print('🔍 [VersionService] 请求URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('请求超时');
        },
      );

      print('🔍 [VersionService] 响应状态码: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        
        if (data['status'] == 200 && data['data'] != null) {
          _latestVersion = VersionInfo.fromJson(data['data']);
          
          print('✅ [VersionService] 最新版本: ${_latestVersion!.version}');
          print('✅ [VersionService] 当前版本: $_currentVersion');
          
          if (hasUpdate) {
            print('🆕 [VersionService] 发现新版本！');
            if (!silent) {
              DeveloperModeService().addLog('🆕 发现新版本: ${_latestVersion!.version}');
            }
          } else {
            print('✅ [VersionService] 已是最新版本');
            if (!silent) {
              DeveloperModeService().addLog('✅ 已是最新版本');
            }
          }
          
          _isChecking = false;
          notifyListeners();
          return _latestVersion;
        } else {
          throw Exception('响应数据格式错误');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [VersionService] 检查更新失败: $e');
      if (!silent) {
        DeveloperModeService().addLog('❌ 检查更新失败: $e');
      }
      _isChecking = false;
      notifyListeners();
      return null;
    }
  }

  /// 比较版本号
  /// 返回值：> 0 表示 v1 > v2，< 0 表示 v1 < v2，= 0 表示相等
  int _compareVersions(String v1, String v2) {
    try {
      // 移除可能的 'v' 前缀
      v1 = v1.replaceFirst('v', '');
      v2 = v2.replaceFirst('v', '');

      final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLength = parts1.length > parts2.length ? parts1.length : parts2.length;

      for (int i = 0; i < maxLength; i++) {
        final part1 = i < parts1.length ? parts1[i] : 0;
        final part2 = i < parts2.length ? parts2[i] : 0;

        if (part1 > part2) return 1;
        if (part1 < part2) return -1;
      }

      return 0;
    } catch (e) {
      print('❌ [VersionService] 版本比较失败: $e');
      return 0;
    }
  }

  /// 获取版本比较结果描述
  String getVersionCompareText() {
    if (_latestVersion == null || _currentVersion.isEmpty) {
      return '未知';
    }

    if (hasUpdate) {
      return '$_currentVersion → ${_latestVersion!.version}';
    } else {
      return '$_currentVersion (最新)';
    }
  }
}

