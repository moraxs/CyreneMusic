import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../models/track.dart';
import '../models/song_detail.dart';
import 'cache_service.dart';

/// 下载进度回调
typedef DownloadProgressCallback = void Function(double progress);

/// 下载任务
class DownloadTask {
  final Track track;
  final String fileName;
  double progress;
  bool isCompleted;
  bool isFailed;
  String? errorMessage;

  DownloadTask({
    required this.track,
    required this.fileName,
    this.progress = 0.0,
    this.isCompleted = false,
    this.isFailed = false,
    this.errorMessage,
  });

  String get trackId => '${track.source.name}_${track.id}';
}

/// 下载服务
class DownloadService extends ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal() {
    _loadDownloadPath();
  }

  // 加密密钥（与 CacheService 保持一致）
  static const String _encryptionKey = 'CyreneMusicCacheKey2025';

  String? _downloadPath;
  final Map<String, DownloadTask> _downloadTasks = {};

  String? get downloadPath => _downloadPath;
  Map<String, DownloadTask> get downloadTasks => _downloadTasks;

  /// 加载下载路径
  Future<void> _loadDownloadPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _downloadPath = prefs.getString('download_path');

      // 如果没有设置下载路径，使用默认路径
      if (_downloadPath == null) {
        await _setDefaultDownloadPath();
      }

      print('📁 [DownloadService] 下载路径: $_downloadPath');
    } catch (e) {
      print('❌ [DownloadService] 加载下载路径失败: $e');
      await _setDefaultDownloadPath();
    }
    notifyListeners();
  }

  /// 设置默认下载路径
  Future<void> _setDefaultDownloadPath() async {
    try {
      if (Platform.isAndroid) {
        // Android: /storage/emulated/0/Download/Cyrene_Music
        final downloadsDir = Directory('/storage/emulated/0/Download');
        final appDownloadDir = Directory('${downloadsDir.path}/Cyrene_Music');

        if (!await appDownloadDir.exists()) {
          await appDownloadDir.create(recursive: true);
          print('✅ [DownloadService] 创建 Android 下载目录: ${appDownloadDir.path}');
        }

        _downloadPath = appDownloadDir.path;
      } else if (Platform.isWindows) {
        // Windows: 用户文档/Music/Cyrene_Music
        final documentsDir = await getApplicationDocumentsDirectory();
        final musicDir = Directory('${documentsDir.parent.path}\\Music\\Cyrene_Music');

        if (!await musicDir.exists()) {
          await musicDir.create(recursive: true);
          print('✅ [DownloadService] 创建 Windows 下载目录: ${musicDir.path}');
        }

        _downloadPath = musicDir.path;
      } else {
        // 其他平台：使用文档目录
        final documentsDir = await getApplicationDocumentsDirectory();
        final appDownloadDir = Directory('${documentsDir.path}/Cyrene_Music');

        if (!await appDownloadDir.exists()) {
          await appDownloadDir.create(recursive: true);
        }

        _downloadPath = appDownloadDir.path;
      }

      // 保存到偏好设置
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('download_path', _downloadPath!);
    } catch (e) {
      print('❌ [DownloadService] 设置默认下载路径失败: $e');
    }
  }

  /// 设置下载路径（Windows 用户自定义）
  Future<bool> setDownloadPath(String path) async {
    try {
      final dir = Directory(path);

      // 检查目录是否存在，不存在则创建
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 验证目录是否可写
      final testFile = File('${dir.path}${Platform.pathSeparator}.test');
      await testFile.writeAsString('test');
      await testFile.delete();

      _downloadPath = path;

      // 保存到偏好设置
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('download_path', path);

      print('✅ [DownloadService] 下载路径已更新: $path');
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ [DownloadService] 设置下载路径失败: $e');
      return false;
    }
  }

  /// 解密缓存数据
  Uint8List _decryptData(Uint8List encryptedData) {
    final keyBytes = utf8.encode(_encryptionKey);
    final decrypted = Uint8List(encryptedData.length);

    for (int i = 0; i < encryptedData.length; i++) {
      decrypted[i] = encryptedData[i] ^ keyBytes[i % keyBytes.length];
    }

    return decrypted;
  }

  /// 生成安全的文件名
  String _generateSafeFileName(Track track) {
    // 移除不安全的字符
    final safeName = '${track.name} - ${track.artists}'
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return '$safeName.mp3';
  }

  /// 从缓存下载（解密缓存文件）
  Future<bool> _downloadFromCache(Track track, String outputPath) async {
    try {
      print('📦 [DownloadService] 从缓存下载: ${track.name}');

      final cacheService = CacheService();
      final cacheKey = '${track.source.name}_${track.id}';
      final cacheFilePath = '${cacheService.currentCacheDir}/$cacheKey.cyrene';
      final cacheFile = File(cacheFilePath);

      if (!await cacheFile.exists()) {
        print('⚠️ [DownloadService] 缓存文件不存在');
        return false;
      }

      // 读取 .cyrene 文件
      final fileData = await cacheFile.readAsBytes();

      // 读取元数据长度（前4字节）
      if (fileData.length < 4) {
        throw Exception('缓存文件格式错误');
      }

      final metadataLength = (fileData[0] << 24) |
          (fileData[1] << 16) |
          (fileData[2] << 8) |
          fileData[3];

      if (fileData.length < 4 + metadataLength) {
        throw Exception('缓存文件格式错误');
      }

      // 跳过元数据，读取加密的音频数据
      final encryptedAudioData = Uint8List.sublistView(
        fileData,
        4 + metadataLength,
      );

      // 解密音频数据
      final decryptedData = _decryptData(encryptedAudioData);

      // 保存到目标路径
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(decryptedData);

      print('✅ [DownloadService] 从缓存下载成功: $outputPath');
      return true;
    } catch (e) {
      print('❌ [DownloadService] 从缓存下载失败: $e');
      return false;
    }
  }

  /// 直接下载音频文件
  Future<bool> _downloadFromUrl(
    String url,
    String outputPath,
    DownloadProgressCallback? onProgress,
  ) async {
    try {
      print('🌐 [DownloadService] 从网络下载: $url');

      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final outputFile = File(outputPath);
      final sink = outputFile.openWrite();

      int downloaded = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;

        if (contentLength > 0 && onProgress != null) {
          final progress = downloaded / contentLength;
          onProgress(progress);
        }
      }

      await sink.close();

      print('✅ [DownloadService] 从网络下载成功: $outputPath');
      return true;
    } catch (e) {
      print('❌ [DownloadService] 从网络下载失败: $e');
      return false;
    }
  }

  /// 下载歌曲
  Future<bool> downloadSong(
    Track track,
    SongDetail songDetail, {
    DownloadProgressCallback? onProgress,
  }) async {
    if (_downloadPath == null) {
      print('❌ [DownloadService] 下载路径未设置');
      return false;
    }

    try {
      final fileName = _generateSafeFileName(track);
      final outputPath = '$_downloadPath${Platform.pathSeparator}$fileName';
      final trackId = '${track.source.name}_${track.id}';

      // 检查文件是否已存在
      if (await File(outputPath).exists()) {
        print('⚠️ [DownloadService] 文件已存在: $outputPath');
        return false;
      }

      // 创建下载任务
      final task = DownloadTask(track: track, fileName: fileName);
      _downloadTasks[trackId] = task;
      notifyListeners();

      print('🎵 [DownloadService] 开始下载: ${track.name}');

      bool success = false;

      // 优先从缓存下载
      if (CacheService().isCached(track)) {
        print('📦 [DownloadService] 尝试从缓存下载');
        success = await _downloadFromCache(track, outputPath);
      }

      // 如果缓存下载失败或没有缓存，从网络下载
      if (!success) {
        print('🌐 [DownloadService] 从网络下载');
        success = await _downloadFromUrl(
          songDetail.url,
          outputPath,
          (progress) {
            task.progress = progress;
            notifyListeners();
            onProgress?.call(progress);
          },
        );
      }

      // 更新任务状态
      if (success) {
        task.isCompleted = true;
        task.progress = 1.0;
        print('✅ [DownloadService] 下载完成: $fileName');
      } else {
        task.isFailed = true;
        task.errorMessage = '下载失败';
        print('❌ [DownloadService] 下载失败: $fileName');
      }

      notifyListeners();

      // 5秒后移除任务
      Future.delayed(const Duration(seconds: 5), () {
        _downloadTasks.remove(trackId);
        notifyListeners();
      });

      return success;
    } catch (e) {
      print('❌ [DownloadService] 下载歌曲失败: $e');
      return false;
    }
  }

  /// 检查文件是否已下载
  Future<bool> isDownloaded(Track track) async {
    if (_downloadPath == null) return false;

    try {
      final fileName = _generateSafeFileName(track);
      final filePath = '$_downloadPath${Platform.pathSeparator}$fileName';
      return await File(filePath).exists();
    } catch (e) {
      return false;
    }
  }

  /// 获取下载的文件路径
  Future<String?> getDownloadedFilePath(Track track) async {
    if (_downloadPath == null) return null;

    try {
      final fileName = _generateSafeFileName(track);
      final filePath = '$_downloadPath${Platform.pathSeparator}$fileName';

      if (await File(filePath).exists()) {
        return filePath;
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}

