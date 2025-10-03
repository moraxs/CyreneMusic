import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';
import '../models/song_detail.dart';
import '../models/track.dart';
import 'music_service.dart';
import 'cache_service.dart';
import 'proxy_service.dart';

/// 播放状态枚举
enum PlayerState {
  idle,     // 空闲
  loading,  // 加载中
  playing,  // 播放中
  paused,   // 暂停
  error,    // 错误
}

/// 音乐播放器服务
class PlayerService extends ChangeNotifier {
  static final PlayerService _instance = PlayerService._internal();
  factory PlayerService() => _instance;
  PlayerService._internal();

  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();
  
  PlayerState _state = PlayerState.idle;
  SongDetail? _currentSong;
  Track? _currentTrack;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _errorMessage;
  String? _currentTempFilePath;  // 记录当前临时文件路径
  final Map<String, Color> _themeColorCache = {}; // 主题色缓存
  final ValueNotifier<Color?> themeColorNotifier = ValueNotifier<Color?>(null); // 主题色通知器

  PlayerState get state => _state;
  SongDetail? get currentSong => _currentSong;
  Track? get currentTrack => _currentTrack;
  Duration get duration => _duration;
  Duration get position => _position;
  String? get errorMessage => _errorMessage;
  bool get isPlaying => _state == PlayerState.playing;
  bool get isPaused => _state == PlayerState.paused;
  bool get isLoading => _state == PlayerState.loading;

  /// 初始化播放器监听
  Future<void> initialize() async {
    // 监听播放状态
    _audioPlayer.onPlayerStateChanged.listen((state) {
      switch (state) {
        case ap.PlayerState.playing:
          _state = PlayerState.playing;
          break;
        case ap.PlayerState.paused:
          _state = PlayerState.paused;
          break;
        case ap.PlayerState.stopped:
          _state = PlayerState.idle;
          break;
        case ap.PlayerState.completed:
          _state = PlayerState.idle;
          _position = Duration.zero;
          break;
        default:
          break;
      }
      notifyListeners();
    });

    // 监听播放进度
    _audioPlayer.onPositionChanged.listen((position) {
      _position = position;
      notifyListeners();
    });

    // 监听总时长
    _audioPlayer.onDurationChanged.listen((duration) {
      _duration = duration;
      notifyListeners();
    });

    // 启动本地代理服务器
    print('🌐 [PlayerService] 启动本地代理服务器...');
    final proxyStarted = await ProxyService().start();
    if (proxyStarted) {
      print('✅ [PlayerService] 本地代理服务器已就绪');
    } else {
      print('⚠️ [PlayerService] 本地代理服务器启动失败，将使用备用方案');
    }

    print('🎵 [PlayerService] 播放器初始化完成');
  }

  /// 播放歌曲（通过Track对象）
  Future<void> playTrack(Track track, {AudioQuality quality = AudioQuality.exhigh}) async {
    try {
      // 清理上一首歌的临时文件
      await _cleanupCurrentTempFile();
      
      _state = PlayerState.loading;
      _currentTrack = track;
      _errorMessage = null;
      notifyListeners();

      print('🎵 [PlayerService] 开始播放: ${track.name} - ${track.artists}');

      // 1. 检查缓存
      final qualityStr = quality.toString().split('.').last;
      final isCached = CacheService().isCached(track);

      if (isCached) {
        print('💾 [PlayerService] 使用缓存播放');
        
        // 获取缓存的元数据
        final metadata = CacheService().getCachedMetadata(track);
        final cachedFilePath = await CacheService().getCachedFilePath(track);

        if (cachedFilePath != null && metadata != null) {
          // 记录临时文件路径（用于后续清理）
          _currentTempFilePath = cachedFilePath;
          
          _currentSong = SongDetail(
            id: track.id,
            name: track.name,
            url: cachedFilePath,
            pic: metadata.picUrl,
            arName: metadata.artists,
            alName: metadata.album,
            level: metadata.quality,
            size: metadata.fileSize.toString(),
            lyric: metadata.lyric,      // 从缓存恢复歌词
            tlyric: metadata.tlyric,    // 从缓存恢复翻译
            source: track.source,
          );

          // 播放缓存文件
          await _audioPlayer.play(ap.DeviceFileSource(cachedFilePath));
          print('✅ [PlayerService] 从缓存播放: $cachedFilePath');
          print('📝 [PlayerService] 歌词已从缓存恢复');
          return;
        } else {
          print('⚠️ [PlayerService] 缓存文件无效，从网络获取');
        }
      }

      // 2. 从网络获取歌曲详情
      print('🌐 [PlayerService] 从网络获取歌曲');
      final songDetail = await MusicService().fetchSongDetail(
        songId: track.id,
        quality: quality,
        source: track.source,
      );

      if (songDetail == null || songDetail.url.isEmpty) {
        _state = PlayerState.error;
        _errorMessage = '无法获取播放链接';
        print('❌ [PlayerService] 播放失败: $_errorMessage');
        notifyListeners();
        return;
      }

      _currentSong = songDetail;

      // 3. 播放音乐
      if (track.source == MusicSource.qq || track.source == MusicSource.kugou) {
        // QQ音乐和酷狗音乐使用本地代理播放（边下载边播放）
        if (ProxyService().isRunning) {
          print('🎶 [PlayerService] 使用本地代理播放 ${track.getSourceName()}');
          final platform = track.source == MusicSource.qq ? 'qq' : 'kugou';
          final proxyUrl = ProxyService().getProxyUrl(songDetail.url, platform);
          await _audioPlayer.play(ap.UrlSource(proxyUrl));
          print('✅ [PlayerService] 通过代理开始流式播放');
        } else {
          // 备用方案：下载后播放
          print('⚠️ [PlayerService] 代理不可用，使用备用方案（下载后播放）');
          final tempFilePath = await _downloadAndPlay(songDetail);
          if (tempFilePath != null) {
            _currentTempFilePath = tempFilePath;
          }
        }
      } else {
        // 网易云音乐直接播放
        await _audioPlayer.play(ap.UrlSource(songDetail.url));
        print('✅ [PlayerService] 开始播放: ${songDetail.url}');
      }

      // 4. 异步缓存歌曲（不阻塞播放）
      if (!isCached) {
        _cacheSongInBackground(track, songDetail, qualityStr);
      }
      
      // 5. 后台提取主题色（为播放器页面预加载）
      _extractThemeColorInBackground(songDetail.pic);
    } catch (e) {
      _state = PlayerState.error;
      _errorMessage = '播放失败: $e';
      print('❌ [PlayerService] 播放异常: $e');
      notifyListeners();
    }
  }

  /// 下载音频文件并播放（用于QQ音乐和酷狗音乐）
  Future<String?> _downloadAndPlay(SongDetail songDetail) async {
    try {
      print('📥 [PlayerService] 开始下载音频: ${songDetail.name}');
      
      // 获取临时目录
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFilePath = '${tempDir.path}/temp_audio_$timestamp.mp3';
      
      // 设置请求头（QQ音乐需要 referer）
      final headers = <String, String>{};
      if (songDetail.source == MusicSource.qq) {
        headers['referer'] = 'https://y.qq.com';
        print('🔐 [PlayerService] 设置 referer: https://y.qq.com');
      }
      
      // 下载音频文件
      final response = await http.get(
        Uri.parse(songDetail.url),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        // 保存到临时文件
        final file = File(tempFilePath);
        await file.writeAsBytes(response.bodyBytes);
        print('✅ [PlayerService] 下载完成: ${response.bodyBytes.length} bytes');
        print('📁 [PlayerService] 临时文件: $tempFilePath');
        
        // 播放临时文件
        await _audioPlayer.play(ap.DeviceFileSource(tempFilePath));
        print('▶️ [PlayerService] 开始播放临时文件');
        
        return tempFilePath;
      } else {
        print('❌ [PlayerService] 下载失败: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ [PlayerService] 下载音频失败: $e');
      return null;
    }
  }

  /// 后台缓存歌曲
  Future<void> _cacheSongInBackground(
    Track track,
    SongDetail songDetail,
    String quality,
  ) async {
    try {
      print('💾 [PlayerService] 开始后台缓存: ${track.name}');
      await CacheService().cacheSong(track, songDetail, quality);
      print('✅ [PlayerService] 缓存完成: ${track.name}');
    } catch (e) {
      print('⚠️ [PlayerService] 缓存失败: $e');
      // 缓存失败不影响播放
    }
  }

  /// 后台提取主题色（为播放器页面预加载）
  Future<void> _extractThemeColorInBackground(String imageUrl) async {
    if (imageUrl.isEmpty) return;

    try {
      // 检查缓存
      if (_themeColorCache.containsKey(imageUrl)) {
        final cachedColor = _themeColorCache[imageUrl];
        themeColorNotifier.value = cachedColor; // 更新 ValueNotifier
        print('🎨 [PlayerService] 使用缓存的主题色: $cachedColor');
        return;
      }

      print('🎨 [PlayerService] 开始提取主题色...');
      
      // 使用 CachedNetworkImageProvider 利用已缓存的图片
      final imageProvider = CachedNetworkImageProvider(imageUrl);
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 12, // 进一步减少采样数，提升速度
        timeout: const Duration(seconds: 2), // 缩短超时时间
      );

      // 优先使用鲜艳色，其次使用主色调
      final themeColor = paletteGenerator.vibrantColor?.color ?? 
                        paletteGenerator.dominantColor?.color ??
                        paletteGenerator.darkVibrantColor?.color;

      if (themeColor != null) {
        _themeColorCache[imageUrl] = themeColor; // 缓存主题色
        themeColorNotifier.value = themeColor;   // 更新 ValueNotifier（只触发背景重建）
        print('✅ [PlayerService] 主题色提取完成: $themeColor');
      }
    } catch (e) {
      print('⚠️ [PlayerService] 主题色提取失败（不影响播放）: $e');
      // 主题色提取失败不影响播放
    }
  }

  /// 暂停
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      print('⏸️ [PlayerService] 暂停播放');
    } catch (e) {
      print('❌ [PlayerService] 暂停失败: $e');
    }
  }

  /// 继续播放
  Future<void> resume() async {
    try {
      await _audioPlayer.resume();
      print('▶️ [PlayerService] 继续播放');
    } catch (e) {
      print('❌ [PlayerService] 继续播放失败: $e');
    }
  }

  /// 停止
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      
      // 清理临时文件
      await _cleanupCurrentTempFile();
      
      _state = PlayerState.idle;
      _currentSong = null;
      _currentTrack = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      notifyListeners();
      print('⏹️ [PlayerService] 停止播放');
    } catch (e) {
      print('❌ [PlayerService] 停止失败: $e');
    }
  }

  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
      print('⏩ [PlayerService] 跳转到: ${position.inSeconds}s');
    } catch (e) {
      print('❌ [PlayerService] 跳转失败: $e');
    }
  }

  /// 设置音量 (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    try {
      await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
      print('🔊 [PlayerService] 音量设置为: ${(volume * 100).toInt()}%');
    } catch (e) {
      print('❌ [PlayerService] 音量设置失败: $e');
    }
  }

  /// 切换播放/暂停
  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else if (isPaused) {
      await resume();
    }
  }

  /// 清理当前临时文件
  Future<void> _cleanupCurrentTempFile() async {
    if (_currentTempFilePath != null) {
      try {
        final tempFile = File(_currentTempFilePath!);
        if (await tempFile.exists()) {
          await tempFile.delete();
          print('🧹 [PlayerService] 已删除临时文件: $_currentTempFilePath');
        }
      } catch (e) {
        print('⚠️ [PlayerService] 删除临时文件失败: $e');
      } finally {
        _currentTempFilePath = null;
      }
    }
  }

  /// 清理资源
  @override
  void dispose() {
    print('🗑️ [PlayerService] 释放播放器资源...');
    // 同步清理当前临时文件
    _cleanupCurrentTempFile();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    // 停止代理服务器
    ProxyService().stop();
    // 清理主题色通知器
    themeColorNotifier.dispose();
    super.dispose();
  }
  
  /// 强制释放所有资源（用于应用退出时）
  Future<void> forceDispose() async {
    try {
      print('🗑️ [PlayerService] 强制释放播放器资源...');
      
      // 清理当前播放的临时文件
      await _cleanupCurrentTempFile();
      
      // 清理所有临时缓存文件
      await CacheService().cleanTempFiles();
      
      // 停止代理服务器
      await ProxyService().stop();
      
      // 先移除所有监听器，防止状态改变时触发通知
      print('🔌 [PlayerService] 移除所有监听器...');
      // 注意：这里不能直接访问 _listeners，因为 ChangeNotifier 不暴露它
      // 但是我们可以通过设置一个标志来阻止 notifyListeners 生效
      
      // 立即清理状态（不触发通知）
      _state = PlayerState.idle;
      _currentSong = null;
      _currentTrack = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      
      // 使用 unawaited 方式，不等待完成，直接继续
      // 因为应用即将退出，操作系统会自动清理资源
      _audioPlayer.stop().catchError((e) {
        print('⚠️ [PlayerService] 停止播放失败: $e');
      });
      
      _audioPlayer.dispose().catchError((e) {
        print('⚠️ [PlayerService] 释放资源失败: $e');
      });
      
      print('✅ [PlayerService] 播放器资源清理指令已发出');
    } catch (e) {
      print('❌ [PlayerService] 释放资源失败: $e');
    }
  }
}

