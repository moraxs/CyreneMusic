import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../models/track.dart';

/// 本地音乐库服务：负责扫描目录、管理本地歌曲与歌词
class LocalLibraryService extends ChangeNotifier {
  static final LocalLibraryService _instance = LocalLibraryService._internal();
  factory LocalLibraryService() => _instance;
  LocalLibraryService._internal();

  /// 支持的音频扩展名（全部小写，不带点）
  static const Set<String> supportedAudioExts = {
    'mp3', 'wav', 'flac', 'aac', 'm4a', 'ogg', 'opus', 'ape', 'wma', 'alac'
  };

  /// 歌词扩展名
  static const String lyricExt = 'lrc';

  /// 路径 -> 歌词内容缓存
  final Map<String, String> _pathToLyric = {};

  /// 已扫描的本地歌曲列表
  final List<Track> _tracks = [];

  List<Track> get tracks => List.unmodifiable(_tracks);

  /// 根据 Track.id（本地为完整文件路径）获取歌词文本
  String getLyricByTrackId(dynamic id) {
    if (id is String) {
      return _pathToLyric[id] ?? '';
    }
    return '';
  }

  /// 选择单首歌曲文件
  Future<void> pickSingleSong() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: supportedAudioExts.toList(),
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    await _addAudioFile(path);
    notifyListeners();
  }

  /// 选择并扫描一个文件夹（递归）
  Future<void> pickAndScanFolder() async {
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null || dirPath.isEmpty) return;
    await scanFolder(dirPath);
  }

  /// 扫描指定文件夹（递归）
  Future<void> scanFolder(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return;

    final List<Future<void>> futures = [];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase().replaceFirst('.', '');
        if (supportedAudioExts.contains(ext)) {
          futures.add(_addAudioFile(entity.path));
        }
      }
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
      notifyListeners();
    }
  }

  /// 清空已扫描结果
  void clear() {
    _tracks.clear();
    _pathToLyric.clear();
    notifyListeners();
  }

  /// 内部：将单个音频文件加入库
  Future<void> _addAudioFile(String filePath) async {
    try {
      // 去重
      if (_tracks.any((t) => t.id == filePath)) return;

      final file = File(filePath);
      if (!await file.exists()) return;

      final filename = p.basename(filePath);
      final nameNoExt = p.basenameWithoutExtension(filePath);

      // 尝试读取同名歌词
      String lyricText = '';
      final lyricPath = p.join(p.dirname(filePath), '$nameNoExt.$lyricExt');
      final lyricFile = File(lyricPath);
      if (await lyricFile.exists()) {
        lyricText = await lyricFile.readAsString();
      } else {
        // 兼容 Lyrics 子目录
        final altLyricPath = p.join(p.dirname(filePath), 'Lyrics', '$nameNoExt.$lyricExt');
        final altLyricFile = File(altLyricPath);
        if (await altLyricFile.exists()) {
          lyricText = await altLyricFile.readAsString();
        }
      }

      _pathToLyric[filePath] = lyricText;

      // 构造本地 Track（使用完整路径作为 id）
      final track = Track(
        id: filePath,
        name: nameNoExt,
        artists: '本地文件',
        album: '',
        picUrl: '', // 暂无封面，播放器会使用占位
        source: MusicSource.local,
      );

      _tracks.add(track);
    } catch (_) {
      // 忽略单个文件失败，避免中断扫描
    }
  }
}


