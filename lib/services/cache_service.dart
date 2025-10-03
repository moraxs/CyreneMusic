import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import '../models/song_detail.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

/// 缓存元数据模型
class CacheMetadata {
  final String songId;
  final String songName;
  final String artists;
  final String album;
  final String picUrl;
  final String source;
  final String quality;
  final String originalUrl;
  final int fileSize;
  final DateTime cachedAt;
  final String checksum;
  final String lyric;
  final String tlyric;

  CacheMetadata({
    required this.songId,
    required this.songName,
    required this.artists,
    required this.album,
    required this.picUrl,
    required this.source,
    required this.quality,
    required this.originalUrl,
    required this.fileSize,
    required this.cachedAt,
    required this.checksum,
    required this.lyric,
    required this.tlyric,
  });

  factory CacheMetadata.fromJson(Map<String, dynamic> json) {
    return CacheMetadata(
      songId: json['songId'],
      songName: json['songName'],
      artists: json['artists'],
      album: json['album'] ?? '',
      picUrl: json['picUrl'] ?? '',
      source: json['source'],
      quality: json['quality'],
      originalUrl: json['originalUrl'],
      fileSize: json['fileSize'],
      cachedAt: DateTime.parse(json['cachedAt']),
      checksum: json['checksum'],
      lyric: json['lyric'] ?? '',
      tlyric: json['tlyric'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'songId': songId,
      'songName': songName,
      'artists': artists,
      'album': album,
      'picUrl': picUrl,
      'source': source,
      'quality': quality,
      'originalUrl': originalUrl,
      'fileSize': fileSize,
      'cachedAt': cachedAt.toIso8601String(),
      'checksum': checksum,
      'lyric': lyric,
      'tlyric': tlyric,
    };
  }
}

/// 缓存统计信息
class CacheStats {
  final int totalFiles;
  final int totalSize;
  final int neteaseCount;
  final int qqCount;
  final int kugouCount;

  CacheStats({
    required this.totalFiles,
    required this.totalSize,
    required this.neteaseCount,
    required this.qqCount,
    required this.kugouCount,
  });

  String get formattedSize {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) return '${(totalSize / 1024).toStringAsFixed(2)} KB';
    if (totalSize < 1024 * 1024 * 1024) {
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// 音乐缓存服务
class CacheService extends ChangeNotifier {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // 加密密钥（用于简单的异或加密）
  static const String _encryptionKey = 'CyreneMusicCacheKey2025';

  Directory? _cacheDir;
  Map<String, CacheMetadata> _cacheIndex = {};
  bool _isInitialized = false;
  bool _cacheEnabled = false;  // 缓存开关，默认关闭
  String? _customCacheDir;    // 自定义缓存目录

  bool get isInitialized => _isInitialized;
  int get cachedCount => _cacheIndex.length;
  bool get cacheEnabled => _cacheEnabled;
  String? get customCacheDir => _customCacheDir;
  String? get currentCacheDir => _cacheDir?.path;

  /// 初始化缓存服务
  Future<void> initialize() async {
    if (_isInitialized) {
      print('ℹ️ [CacheService] 缓存服务已初始化，跳过');
      return;
    }

    try {
      print('💾 [CacheService] 开始初始化缓存服务...');

      // 加载缓存设置
      await _loadSettings();

      // 获取缓存目录
      if (_customCacheDir != null && _customCacheDir!.isNotEmpty) {
        // 使用自定义目录
        _cacheDir = Directory(_customCacheDir!);
        print('📂 [CacheService] 使用自定义目录: ${_customCacheDir!}');
      } else if (Platform.isWindows) {
        // Windows: 使用当前运行目录
        final executablePath = Platform.resolvedExecutable;
        final executableDir = path.dirname(executablePath);
        _cacheDir = Directory(path.join(executableDir, 'music_cache'));
        print('📂 [CacheService] 运行目录: $executableDir');
      } else {
        // 其他平台: 使用应用文档目录
        final appDir = await getApplicationDocumentsDirectory();
        _cacheDir = Directory('${appDir.path}/music_cache');
        print('📂 [CacheService] 应用文档目录: ${appDir.path}');
      }
      
      print('📂 [CacheService] 缓存目录路径: ${_cacheDir!.path}');
      print('🔧 [CacheService] 缓存开关状态: ${_cacheEnabled ? "已启用" : "已禁用"}');

      // 创建缓存目录
      if (!await _cacheDir!.exists()) {
        print('📁 [CacheService] 缓存目录不存在，创建中...');
        await _cacheDir!.create(recursive: true);
        print('✅ [CacheService] 缓存目录已创建: ${_cacheDir!.path}');
      } else {
        print('✅ [CacheService] 缓存目录已存在: ${_cacheDir!.path}');
      }

      // 验证目录是否可写
      try {
        final testFile = File('${_cacheDir!.path}/.test');
        await testFile.writeAsString('test');
        await testFile.delete();
        print('✅ [CacheService] 缓存目录可写');
      } catch (e) {
        print('❌ [CacheService] 缓存目录不可写: $e');
        throw Exception('缓存目录不可写');
      }

      // 加载缓存索引
      await _loadCacheIndex();

      _isInitialized = true;
      notifyListeners();

      print('✅ [CacheService] 缓存服务初始化完成！');
      print('📊 [CacheService] 已缓存歌曲数: ${_cacheIndex.length}');
      print('📁 [CacheService] 缓存位置: ${_cacheDir!.path}');
    } catch (e, stackTrace) {
      print('❌ [CacheService] 初始化失败: $e');
      print('❌ [CacheService] 错误堆栈: $stackTrace');
      _isInitialized = false;
    }
  }

  /// 生成缓存键（基于歌曲ID和来源，不包含音质）
  String _generateCacheKey(String songId, MusicSource source) {
    return '${source.name}_$songId';
  }

  /// 获取缓存文件路径
  String _getCacheFilePath(String cacheKey) {
    return '${_cacheDir!.path}/$cacheKey.cyrene';
  }

  /// 加密数据（简单的异或加密，防止直接播放）
  Uint8List _encryptData(Uint8List data) {
    final keyBytes = utf8.encode(_encryptionKey);
    final encrypted = Uint8List(data.length);

    for (int i = 0; i < data.length; i++) {
      encrypted[i] = data[i] ^ keyBytes[i % keyBytes.length];
    }

    return encrypted;
  }

  /// 解密数据
  Uint8List _decryptData(Uint8List encryptedData) {
    // 异或加密是对称的，加密和解密使用相同的方法
    return _encryptData(encryptedData);
  }

  /// 计算文件校验和
  String _calculateChecksum(Uint8List data) {
    return md5.convert(data).toString();
  }

  /// 检查缓存是否存在
  bool isCached(Track track) {
    if (!_isInitialized || !_cacheEnabled) return false;

    final cacheKey = _generateCacheKey(
      track.id.toString(),
      track.source,
    );

    return _cacheIndex.containsKey(cacheKey);
  }

  /// 获取缓存的元数据
  CacheMetadata? getCachedMetadata(Track track) {
    if (!_isInitialized || !_cacheEnabled) return null;

    final cacheKey = _generateCacheKey(
      track.id.toString(),
      track.source,
    );

    return _cacheIndex[cacheKey];
  }

  /// 获取缓存文件路径（用于播放）
  Future<String?> getCachedFilePath(Track track) async {
    if (!_isInitialized) {
      print('⚠️ [CacheService] 缓存服务未初始化');
      return null;
    }

    final cacheKey = _generateCacheKey(
      track.id.toString(),
      track.source,
    );

    if (!_cacheIndex.containsKey(cacheKey)) {
      return null;
    }

    final cacheFilePath = _getCacheFilePath(cacheKey);
    final cacheFile = File(cacheFilePath);

    if (!await cacheFile.exists()) {
      print('⚠️ [CacheService] 缓存文件不存在: $cacheFilePath');
      _cacheIndex.remove(cacheKey);
      await _saveCacheIndex();
      return null;
    }

    // 读取并解析 .cyrene 文件
    try {
      final fileData = await cacheFile.readAsBytes();

      // 读取元数据长度（前4字节）
      if (fileData.length < 4) {
        throw Exception('文件格式错误');
      }

      final metadataLength = (fileData[0] << 24) |
          (fileData[1] << 16) |
          (fileData[2] << 8) |
          fileData[3];

      if (fileData.length < 4 + metadataLength) {
        throw Exception('文件格式错误');
      }

      // 跳过元数据，读取加密的音频数据
      final encryptedAudioData = Uint8List.sublistView(
        fileData,
        4 + metadataLength,
      );

      // 解密音频数据
      final decryptedData = _decryptData(encryptedAudioData);

      // 创建临时文件
      final tempDir = await getTemporaryDirectory();
      final tempFilePath = '${tempDir.path}/temp_${cacheKey}_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final tempFile = File(tempFilePath);
      await tempFile.writeAsBytes(decryptedData);

      print('✅ [CacheService] 解密缓存文件: $tempFilePath');
      return tempFilePath;
    } catch (e) {
      print('❌ [CacheService] 解密缓存失败: $e');
      _cacheIndex.remove(cacheKey);
      await _saveCacheIndex();
      return null;
    }
  }

  /// 缓存歌曲
  Future<bool> cacheSong(
    Track track,
    SongDetail songDetail,
    String quality,
  ) async {
    if (!_isInitialized) {
      print('⚠️ [CacheService] 缓存服务未初始化');
      return false;
    }

    if (!_cacheEnabled) {
      print('ℹ️ [CacheService] 缓存功能已禁用，跳过缓存');
      return false;
    }

    try {
      final cacheKey = _generateCacheKey(
        track.id.toString(),
        track.source,
      );

      // 检查是否已缓存
      if (_cacheIndex.containsKey(cacheKey)) {
        print('ℹ️ [CacheService] 歌曲已缓存: ${track.name}');
        return true;
      }

      print('💾 [CacheService] 开始缓存: ${track.name} (${track.getSourceName()})');

      // 下载音频数据
      final response = await http.get(Uri.parse(songDetail.url));
      if (response.statusCode != 200) {
        print('❌ [CacheService] 下载失败: ${response.statusCode}');
        return false;
      }

      final audioData = response.bodyBytes;
      print('📥 [CacheService] 下载完成: ${audioData.length} bytes');

      // 计算校验和
      final checksum = _calculateChecksum(audioData);

      // 加密音频数据
      final encryptedAudioData = _encryptData(audioData);

      // 创建元数据
      final metadata = CacheMetadata(
        songId: track.id.toString(),
        songName: track.name,
        artists: track.artists,
        album: track.album,
        picUrl: track.picUrl,
        source: track.source.name,
        quality: quality,
        originalUrl: songDetail.url,
        fileSize: audioData.length,
        cachedAt: DateTime.now(),
        checksum: checksum,
        lyric: songDetail.lyric,
        tlyric: songDetail.tlyric,
      );

      // 将元数据转换为字节
      final metadataJson = jsonEncode(metadata.toJson());
      final metadataBytes = utf8.encode(metadataJson);
      final metadataLength = metadataBytes.length;

      // 构建 .cyrene 文件
      // 格式: [4字节元数据长度] [元数据JSON] [加密的音频数据]
      final cyreneFile = BytesBuilder();
      
      // 写入元数据长度（4字节，大端序）
      cyreneFile.addByte((metadataLength >> 24) & 0xFF);
      cyreneFile.addByte((metadataLength >> 16) & 0xFF);
      cyreneFile.addByte((metadataLength >> 8) & 0xFF);
      cyreneFile.addByte(metadataLength & 0xFF);
      
      // 写入元数据
      cyreneFile.add(metadataBytes);
      
      // 写入加密的音频数据
      cyreneFile.add(encryptedAudioData);

      // 保存 .cyrene 文件
      final cacheFilePath = _getCacheFilePath(cacheKey);
      final cacheFile = File(cacheFilePath);
      await cacheFile.writeAsBytes(cyreneFile.toBytes());

      print('🔒 [CacheService] 保存缓存文件: $cacheFilePath');
      print('📊 [CacheService] 文件大小: ${cyreneFile.length} bytes (元数据: $metadataLength bytes)');

      // 更新缓存索引
      _cacheIndex[cacheKey] = metadata;
      await _saveCacheIndex();

      print('✅ [CacheService] 缓存完成: ${track.name}');
      notifyListeners();

      return true;
    } catch (e) {
      print('❌ [CacheService] 缓存失败: $e');
      return false;
    }
  }

  /// 加载缓存索引
  Future<void> _loadCacheIndex() async {
    try {
      final indexFile = File('${_cacheDir!.path}/cache_index.cyrene');

      if (await indexFile.exists()) {
        print('📑 [CacheService] 发现缓存索引文件，读取中...');
        
        // 读取加密的索引文件
        final encryptedData = await indexFile.readAsBytes();
        
        // 解密
        final decryptedData = _decryptData(encryptedData);
        final indexJson = utf8.decode(decryptedData);
        
        final indexData = jsonDecode(indexJson);
        _cacheIndex = {};

        for (final entry in (indexData as Map<String, dynamic>).entries) {
          _cacheIndex[entry.key] = CacheMetadata.fromJson(entry.value);
        }

        print('📑 [CacheService] 加载缓存索引: ${_cacheIndex.length} 条记录');
      } else {
        print('📑 [CacheService] 缓存索引不存在，创建新索引');
        _cacheIndex = {};
      }
    } catch (e) {
      print('❌ [CacheService] 加载缓存索引失败: $e');
      _cacheIndex = {};
    }
  }

  /// 保存缓存索引
  Future<void> _saveCacheIndex() async {
    try {
      final indexFile = File('${_cacheDir!.path}/cache_index.cyrene');
      final indexData = <String, dynamic>{};

      for (final entry in _cacheIndex.entries) {
        indexData[entry.key] = entry.value.toJson();
      }

      // 转换为 JSON 字符串
      final jsonString = jsonEncode(indexData);
      final jsonBytes = utf8.encode(jsonString);
      
      // 加密索引数据
      final encryptedData = _encryptData(jsonBytes);
      
      // 保存加密后的索引文件
      await indexFile.writeAsBytes(encryptedData);
      print('💾 [CacheService] 保存加密的缓存索引: ${_cacheIndex.length} 条记录');
    } catch (e) {
      print('❌ [CacheService] 保存缓存索引失败: $e');
    }
  }

  /// 获取缓存统计信息
  Future<CacheStats> getCacheStats() async {
    int totalSize = 0;
    int neteaseCount = 0;
    int qqCount = 0;
    int kugouCount = 0;

    for (final metadata in _cacheIndex.values) {
      totalSize += metadata.fileSize;

      switch (metadata.source) {
        case 'netease':
          neteaseCount++;
          break;
        case 'qq':
          qqCount++;
          break;
        case 'kugou':
          kugouCount++;
          break;
      }
    }

    return CacheStats(
      totalFiles: _cacheIndex.length,
      totalSize: totalSize,
      neteaseCount: neteaseCount,
      qqCount: qqCount,
      kugouCount: kugouCount,
    );
  }

  /// 清除所有缓存
  Future<void> clearAllCache() async {
    if (!_isInitialized) return;

    try {
      print('🗑️ [CacheService] 清除所有缓存...');

      // 删除所有缓存文件
      final files = await _cacheDir!.list().toList();
      for (final file in files) {
        if (file is File) {
          await file.delete();
        }
      }

      // 清空索引
      _cacheIndex.clear();
      await _saveCacheIndex();

      print('✅ [CacheService] 缓存已清除');
      notifyListeners();
    } catch (e) {
      print('❌ [CacheService] 清除缓存失败: $e');
    }
  }

  /// 删除单个缓存
  Future<void> deleteCache(Track track) async {
    if (!_isInitialized) return;

    try {
      final cacheKey = _generateCacheKey(
        track.id.toString(),
        track.source,
      );

      if (!_cacheIndex.containsKey(cacheKey)) {
        return;
      }

      // 删除 .cyrene 缓存文件
      final cacheFilePath = _getCacheFilePath(cacheKey);
      final cacheFile = File(cacheFilePath);
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }

      // 从索引中移除
      _cacheIndex.remove(cacheKey);
      await _saveCacheIndex();

      print('🗑️ [CacheService] 删除缓存: ${track.name}');
      notifyListeners();
    } catch (e) {
      print('❌ [CacheService] 删除缓存失败: $e');
    }
  }

  /// 获取缓存列表
  List<CacheMetadata> getCachedList() {
    return _cacheIndex.values.toList()
      ..sort((a, b) => b.cachedAt.compareTo(a.cachedAt));
  }

  /// 清理临时文件
  Future<void> cleanTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = await tempDir.list().toList();

      for (final file in files) {
        if (file is File && file.path.contains('temp_') && file.path.endsWith('.mp3')) {
          try {
            await file.delete();
          } catch (e) {
            // 忽略删除失败的文件
          }
        }
      }

      print('🧹 [CacheService] 清理临时文件完成');
    } catch (e) {
      print('⚠️ [CacheService] 清理临时文件失败: $e');
    }
  }

  /// 加载缓存设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 加载缓存开关状态（默认关闭）
      _cacheEnabled = prefs.getBool('cache_enabled') ?? false;
      
      // 加载自定义缓存目录
      _customCacheDir = prefs.getString('custom_cache_dir');
      
      print('⚙️ [CacheService] 加载设置 - 缓存开关: $_cacheEnabled, 自定义目录: ${_customCacheDir ?? "无"}');
    } catch (e) {
      print('❌ [CacheService] 加载设置失败: $e');
      _cacheEnabled = false;  // 加载失败时默认关闭
      _customCacheDir = null;
    }
  }

  /// 保存缓存开关状态
  Future<void> _saveCacheEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('cache_enabled', _cacheEnabled);
      print('💾 [CacheService] 缓存开关已保存: $_cacheEnabled');
    } catch (e) {
      print('❌ [CacheService] 保存缓存开关失败: $e');
    }
  }

  /// 保存自定义缓存目录
  Future<void> _saveCustomCacheDir() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_customCacheDir != null && _customCacheDir!.isNotEmpty) {
        await prefs.setString('custom_cache_dir', _customCacheDir!);
        print('💾 [CacheService] 自定义目录已保存: $_customCacheDir');
      } else {
        await prefs.remove('custom_cache_dir');
        print('💾 [CacheService] 已清除自定义目录');
      }
    } catch (e) {
      print('❌ [CacheService] 保存自定义目录失败: $e');
    }
  }

  /// 设置缓存开关
  Future<void> setCacheEnabled(bool enabled) async {
    if (_cacheEnabled != enabled) {
      _cacheEnabled = enabled;
      await _saveCacheEnabled();
      print('🔧 [CacheService] 缓存功能${enabled ? "已启用" : "已禁用"}');
      notifyListeners();
    }
  }

  /// 设置自定义缓存目录
  Future<bool> setCustomCacheDir(String? dirPath) async {
    try {
      // 验证目录
      if (dirPath != null && dirPath.isNotEmpty) {
        final dir = Directory(dirPath);
        
        // 检查目录是否存在或可创建
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        
        // 测试是否可写
        final testFile = File('${dir.path}/.test');
        await testFile.writeAsString('test');
        await testFile.delete();
        
        _customCacheDir = dirPath;
        print('✅ [CacheService] 自定义目录验证成功: $dirPath');
      } else {
        _customCacheDir = null;
        print('ℹ️ [CacheService] 清除自定义目录，使用默认目录');
      }
      
      await _saveCustomCacheDir();
      
      // 提示需要重启应用
      print('⚠️ [CacheService] 目录更改已保存，需要重启应用才能生效');
      print('ℹ️ [CacheService] 当前缓存目录: ${_cacheDir?.path}');
      print('ℹ️ [CacheService] 新目录将在重启后使用: ${dirPath ?? "默认目录"}');
      notifyListeners();
      
      return true;
    } catch (e) {
      print('❌ [CacheService] 设置自定义目录失败: $e');
      return false;
    }
  }

  /// 获取默认缓存目录路径
  Future<String> getDefaultCacheDir() async {
    if (Platform.isWindows) {
      final executablePath = Platform.resolvedExecutable;
      final executableDir = path.dirname(executablePath);
      return path.join(executableDir, 'music_cache');
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      return '${appDir.path}/music_cache';
    }
  }
}

