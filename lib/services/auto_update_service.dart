import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/version_info.dart';
import 'developer_mode_service.dart';
import 'persistent_storage_service.dart';
import 'url_service.dart';

/// 自动更新服务
class AutoUpdateService extends ChangeNotifier {
  static final AutoUpdateService _instance = AutoUpdateService._internal();
  factory AutoUpdateService() => _instance;
  AutoUpdateService._internal();

  static const String _storageKey = 'auto_update_enabled';

  bool _isInitialized = false;
  bool _enabled = false;
  bool _isUpdating = false;
  bool _requiresRestart = false;
  double _progress = 0.0;
  String _statusMessage = '未开始';
  String? _lastError;
  VersionInfo? _pendingVersion;
  DateTime? _lastSuccessAt;

  /// 初始化自动更新服务
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      final storedValue = PersistentStorageService().getBool(_storageKey);
      _enabled = storedValue ?? false;
      _isInitialized = true;
      DeveloperModeService().addLog('🔄 自动更新服务初始化，当前状态: ${_enabled ? '已开启' : '已关闭'}');
    } catch (e) {
      DeveloperModeService().addLog('❌ 自动更新服务初始化失败: $e');
    }
  }

  bool get isInitialized => _isInitialized;
  bool get isEnabled => _enabled;
  bool get isUpdating => _isUpdating;
  bool get requiresRestart => _requiresRestart;
  double get progress => _progress;
  String get statusMessage => _statusMessage;
  String? get lastError => _lastError;
  VersionInfo? get pendingVersion => _pendingVersion;
  DateTime? get lastSuccessAt => _lastSuccessAt;

  /// 当前平台是否支持自动更新
  bool get isPlatformSupported => Platform.isWindows || Platform.isAndroid;

  /// 设置自动更新开关
  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;

    _enabled = value;
    notifyListeners();

    final saved = await PersistentStorageService().setBool(_storageKey, value);
    if (!saved) {
      DeveloperModeService().addLog('⚠️ 自动更新状态保存失败');
    }

    DeveloperModeService().addLog(value ? '⚙️ 自动更新已开启' : '⏸️ 自动更新已关闭');

    if (value && _pendingVersion != null && !_isUpdating && isPlatformSupported) {
      // 延迟触发，确保调用方已有机会更新 UI
      unawaited(Future.delayed(const Duration(milliseconds: 200), () {
        startUpdate(versionInfo: _pendingVersion!, autoTriggered: true);
      }));
    }
  }

  /// 监听到新版本信息
  void onNewVersionDetected(VersionInfo versionInfo) {
    _pendingVersion = versionInfo;
    _lastError = null;
    _requiresRestart = false;
    notifyListeners();

    if (_enabled && !_isUpdating && isPlatformSupported && !versionInfo.forceUpdate) {
      startUpdate(versionInfo: versionInfo, autoTriggered: true);
    }
  }

  /// 清除待更新版本（例如确认已是最新版本时）
  void clearPendingVersion() {
    if (_pendingVersion == null) return;
    _pendingVersion = null;
    notifyListeners();
  }

  /// 手动或自动触发更新
  Future<void> startUpdate({VersionInfo? versionInfo, bool autoTriggered = false}) async {
    versionInfo ??= _pendingVersion;

    if (versionInfo == null) {
      _statusMessage = '未检测到可用更新';
      _lastError = '没有可用的版本信息';
      notifyListeners();
      return;
    }

    if (!isPlatformSupported) {
      _statusMessage = '当前平台暂不支持自动更新';
      _lastError = _statusMessage;
      notifyListeners();
      return;
    }

    if (_isUpdating) {
      DeveloperModeService().addLog('⚠️ 自动更新任务已在执行中，跳过重复触发');
      return;
    }

    final downloadUrl = _resolveDownloadUrl(versionInfo);
    if (downloadUrl == null) {
      final message = '后端未提供当前平台的更新包链接';
      _statusMessage = message;
      _lastError = message;
      notifyListeners();
      DeveloperModeService().addLog('❌ $message');
      return;
    }

    _isUpdating = true;
    _progress = 0.0;
    _lastError = null;
    _requiresRestart = false;
    _statusMessage = autoTriggered ? '正在后台自动下载更新...' : '正在下载更新包...';
    notifyListeners();

    DeveloperModeService().addLog('⬇️ 原始下载URL: $downloadUrl');
    DeveloperModeService().addLog('🌐 当前后端baseUrl: ${UrlService().baseUrl}');

    try {
      final normalizedUrl = _normalizeDownloadUrl(downloadUrl);
      DeveloperModeService().addLog('🔄 归一化后URL: $normalizedUrl');
      final downloadedFile = await _downloadToFile(normalizedUrl);

      _statusMessage = '下载完成，正在安装...';
      _progress = 1.0;
      notifyListeners();

      if (Platform.isWindows) {
        await _installOnDesktop(downloadedFile, versionInfo);
      } else if (Platform.isAndroid) {
        await _installOnAndroid(downloadedFile);
      } else {
        // 兜底处理
        await _openFile(downloadedFile);
      }

      _statusMessage = '更新安装完成，请重启应用生效';
      _requiresRestart = Platform.isWindows;
      _lastSuccessAt = DateTime.now();
      DeveloperModeService().addLog('✅ 自动更新完成，等待用户重启应用');
    } catch (e, stackTrace) {
      _lastError = e.toString();
      _statusMessage = '更新失败: $e';
      DeveloperModeService().addLog('❌ 自动更新失败: $e');
      DeveloperModeService().addLog(stackTrace.toString());
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  /// 辅助方法：根据平台解析下载地址
  String? _resolveDownloadUrl(VersionInfo versionInfo) {
    if (Platform.isWindows) {
      return versionInfo.platformDownloadUrl('windows') ?? versionInfo.downloadUrl;
    }
    if (Platform.isAndroid) {
      return versionInfo.platformDownloadUrl('android') ?? versionInfo.downloadUrl;
    }
    if (Platform.isIOS) {
      return versionInfo.platformDownloadUrl('ios') ?? versionInfo.downloadUrl;
    }
    if (Platform.isMacOS) {
      return versionInfo.platformDownloadUrl('macos') ?? versionInfo.downloadUrl;
    }
    if (Platform.isLinux) {
      return versionInfo.platformDownloadUrl('linux') ?? versionInfo.downloadUrl;
    }
    return versionInfo.downloadUrl;
  }

  /// 归一化下载地址：支持相对路径和绝对路径
  /// 如果URL是完整URL但host不匹配，则使用当前baseUrl替换
  String _normalizeDownloadUrl(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl);
      
      // 如果有scheme（完整URL），检查是否需要替换host
      if (uri.hasScheme) {
        final currentBaseUrl = UrlService().baseUrl;
        final currentUri = Uri.parse(currentBaseUrl);
        
        // 如果host不匹配，使用当前baseUrl替换
        if (uri.host != currentUri.host || uri.port != currentUri.port || uri.scheme != currentUri.scheme) {
          final path = uri.path;
          final normalized = '$currentBaseUrl${path.startsWith('/') ? '' : '/'}$path';
          DeveloperModeService().addLog('🔄 URL host不匹配，替换为: $normalized');
          return normalized;
        }
        return rawUrl;
      }

      // 相对路径，使用baseUrl拼接
      final base = UrlService().baseUrl;
      final cleanedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
      return '$cleanedBase${rawUrl.startsWith('/') ? '' : '/'}$rawUrl';
    } catch (e) {
      DeveloperModeService().addLog('❌ URL归一化失败: $e, 原始URL: $rawUrl');
      // 如果解析失败，尝试直接拼接
      final base = UrlService().baseUrl;
      final cleanedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
      return '$cleanedBase${rawUrl.startsWith('/') ? '' : '/'}$rawUrl';
    }
  }

  /// 下载文件到临时目录
  Future<File> _downloadToFile(String url) async {
    DeveloperModeService().addLog('📥 开始下载，URL: $url');
    
    final uri = Uri.parse(url);
    final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'update.bin';

    final downloadDir = await _resolveDownloadDirectory();
    final file = File(p.join(downloadDir.path, fileName));

    if (await file.exists()) {
      await file.delete();
    }

    DeveloperModeService().addLog('📁 下载目录: ${downloadDir.path}');
    DeveloperModeService().addLog('📄 文件名: $fileName');

    final request = http.Request('GET', uri);
    DeveloperModeService().addLog('🌐 发送请求: ${request.method} ${request.url}');
    
    final response = await request.send();
    
    DeveloperModeService().addLog('📥 收到响应: 状态码 ${response.statusCode}');
    DeveloperModeService().addLog('📥 响应头: ${response.headers}');

    if (response.statusCode != 200) {
      final errorMsg = '下载失败，状态码: ${response.statusCode}, URL: $url';
      DeveloperModeService().addLog('❌ $errorMsg');
      throw HttpException(errorMsg);
    }

    final contentLength = response.contentLength ?? 0;
    int received = 0;

    final sink = file.openWrite();
    await for (final chunk in response.stream) {
      received += chunk.length;
      sink.add(chunk);

      if (contentLength > 0) {
        _progress = received / contentLength;
        notifyListeners();
      }
    }

    await sink.close();
    return file;
  }

  Future<Directory> _resolveDownloadDirectory() async {
    Directory baseDir;
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final installDir = Directory(_resolveInstallDirectory());
      baseDir = Directory(p.join(installDir.path, 'updates'));
    } else {
      final supportDir = await getApplicationSupportDirectory();
      baseDir = Directory(p.join(supportDir.path, 'updates'));
    }

    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    return baseDir;
  }

  String _resolveInstallDirectory() {
    try {
      final executable = File(Platform.resolvedExecutable);
      final executableName = executable.uri.pathSegments.isNotEmpty
          ? executable.uri.pathSegments.last.toLowerCase()
          : '';

      if (executableName.contains('flutter') || executableName.contains('dart')) {
        return Directory.current.path;
      }
      return executable.parent.path;
    } catch (_) {
      return Directory.current.path;
    }
  }

  Future<void> _installOnDesktop(File archiveFile, VersionInfo versionInfo) async {
    if (!archiveFile.path.endsWith('.zip')) {
      // 非 Zip 包直接尝试打开
      await _openFile(archiveFile);
      return;
    }

    _statusMessage = '正在解压更新包...';
    notifyListeners();

    final bytes = await archiveFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);

    final installDir = Directory(_resolveInstallDirectory());
    final rootSegments = <String>{};
    for (final entry in archive) {
      final sanitizedName = _sanitizeArchiveEntry(entry.name);
      if (sanitizedName.isEmpty) continue;
      final parts = sanitizedName.split('/');
      if (parts.isNotEmpty) {
        rootSegments.add(parts.first);
      }
    }

    final shouldStripRoot = rootSegments.length == 1 && rootSegments.first.isNotEmpty;
    final rootToStrip = shouldStripRoot ? '${rootSegments.first}/' : null;

    int successCount = 0;
    int skipCount = 0;
    final skippedFiles = <String>[];

    for (final entry in archive) {
      var sanitizedName = _sanitizeArchiveEntry(entry.name);
      if (sanitizedName.isEmpty) {
        continue;
      }

      if (rootToStrip != null && sanitizedName.startsWith(rootToStrip)) {
        sanitizedName = sanitizedName.substring(rootToStrip.length);
      }

      if (sanitizedName.isEmpty) {
        continue;
      }

      final outputPath = p.join(installDir.path, sanitizedName);

      if (entry.isDirectory) {
        final directory = Directory(outputPath);
        if (!directory.existsSync()) {
          try {
            directory.createSync(recursive: true);
            successCount++;
          } catch (e) {
            DeveloperModeService().addLog('⚠️ 创建目录失败: $outputPath - $e');
            skipCount++;
          }
        }
      } else {
        final file = File(outputPath);
        try {
          file.parent.createSync(recursive: true);
          final data = entry.content as List<int>;
          
          // 尝试写入文件，如果文件被锁定则跳过
          try {
            await file.writeAsBytes(data, flush: true);
            successCount++;
            DeveloperModeService().addLog('✅ 更新文件: $sanitizedName');
          } catch (e) {
            // Windows错误1224表示文件在使用用户映射区域，无法覆盖
            if (e.toString().contains('1224') || 
                e.toString().contains('用户映射区域') ||
                e.toString().contains('无法在使用') ||
                e.toString().contains('file is being used')) {
              skipCount++;
              skippedFiles.add(sanitizedName);
              DeveloperModeService().addLog('⏭️ 跳过锁定文件: $sanitizedName (将在重启后生效)');
            } else {
              // 其他错误，记录并继续
              DeveloperModeService().addLog('⚠️ 更新文件失败: $sanitizedName - $e');
              skipCount++;
              skippedFiles.add(sanitizedName);
            }
          }
        } catch (e) {
          DeveloperModeService().addLog('⚠️ 处理文件失败: $sanitizedName - $e');
          skipCount++;
          skippedFiles.add(sanitizedName);
        }
      }
    }

    DeveloperModeService().addLog('📦 解压完成: 成功 $successCount 个，跳过 $skipCount 个');
    if (skippedFiles.isNotEmpty) {
      DeveloperModeService().addLog('⏭️ 跳过的文件: ${skippedFiles.take(10).join(', ')}${skippedFiles.length > 10 ? '...' : ''}');
    }
    
    archiveFile.delete().ignore();
    
    if (skipCount > 0) {
      _statusMessage = '更新完成（部分文件将在重启后生效）';
    } else {
      _statusMessage = '更新文件已覆盖，等待重启';
    }
    notifyListeners();
  }

  Future<void> _installOnAndroid(File packageFile) async {
    if (!packageFile.path.endsWith('.apk')) {
      await _openFile(packageFile);
      return;
    }

    _statusMessage = '正在调用系统安装程序...';
    notifyListeners();

    final result = await OpenFilex.open(packageFile.path);
    DeveloperModeService().addLog('📱 APK 安装结果: ${result.message}');
  }

  Future<void> _openFile(File file) async {
    await OpenFilex.open(file.path);
  }

  String _sanitizeArchiveEntry(String originalName) {
    var name = originalName.replaceAll('\\', '/');
    name = p.normalize(name);

    while (name.startsWith('../')) {
      name = name.substring(3);
    }
    while (name.startsWith('./')) {
      name = name.substring(2);
    }

    if (name.contains('..')) {
      return '';
    }
    return name;
  }
}

extension on Future<void> {
  void ignore() {}
}

