import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';
import '../models/song_detail.dart';
import '../models/track.dart';
import '../models/lyric_line.dart';
import '../utils/lyric_parser.dart';
import 'music_service.dart';
import 'cache_service.dart';
import 'proxy_service.dart';
import 'play_history_service.dart';
import 'playback_mode_service.dart';
import 'playlist_queue_service.dart';
import 'audio_quality_service.dart';
import 'listening_stats_service.dart';
import 'desktop_lyric_service.dart';
import 'player_background_service.dart';
import 'dart:async' as async_lib;

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
  
  // 听歌统计相关
  async_lib.Timer? _statsTimer; // 统计定时器
  DateTime? _playStartTime; // 播放开始时间
  int _sessionListeningTime = 0; // 当前会话累积的听歌时长

  // 桌面歌词相关
  List<LyricLine> _lyrics = [];
  int _currentLyricIndex = -1;

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
          _startListeningTimeTracking(); // 开始听歌时长追踪
          break;
        case ap.PlayerState.paused:
          _state = PlayerState.paused;
          _pauseListeningTimeTracking(); // 暂停听歌时长追踪
          break;
        case ap.PlayerState.stopped:
          _state = PlayerState.idle;
          _pauseListeningTimeTracking(); // 暂停听歌时长追踪
          break;
        case ap.PlayerState.completed:
          _state = PlayerState.idle;
          _position = Duration.zero;
          _pauseListeningTimeTracking(); // 暂停听歌时长追踪
          // 歌曲播放完毕，自动播放下一首
          _playNextFromHistory();
          break;
        default:
          break;
      }
      notifyListeners();
    });

    // 监听播放进度
    _audioPlayer.onPositionChanged.listen((position) {
      _position = position;
      _updateDesktopLyric(); // 更新桌面歌词
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
  Future<void> playTrack(Track track, {AudioQuality? quality}) async {
    try {
      // 使用用户设置的音质，如果没有传入特定音质
      final selectedQuality = quality ?? AudioQualityService().currentQuality;
      print('🎵 [PlayerService] 播放音质: ${selectedQuality.toString()}');
      
      // 清理上一首歌的临时文件
      await _cleanupCurrentTempFile();
      
      _state = PlayerState.loading;
      _currentTrack = track;
      _errorMessage = null;
      notifyListeners();

      print('🎵 [PlayerService] 开始播放: ${track.name} - ${track.artists}');
      print('   Track ID: ${track.id} (类型: ${track.id.runtimeType})');
      
      // 记录到播放历史
      await PlayHistoryService().addToHistory(track);
      
      // 记录播放次数
      await ListeningStatsService().recordPlayCount(track);

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
          
          // 🔧 立即通知监听器，确保 PlayerPage 能获取到包含歌词的 currentSong
          notifyListeners();
          print('✅ [PlayerService] 已更新 currentSong（从缓存，包含歌词）');
          
          // 加载桌面歌词
          _loadLyricsForDesktop();

          // 播放缓存文件
          await _audioPlayer.play(ap.DeviceFileSource(cachedFilePath));
          print('✅ [PlayerService] 从缓存播放: $cachedFilePath');
          print('📝 [PlayerService] 歌词已从缓存恢复');
          
          // 提取主题色（即使是缓存播放也需要更新主题色）
          _extractThemeColorInBackground(metadata.picUrl);
          return;
        } else {
          print('⚠️ [PlayerService] 缓存文件无效，从网络获取');
        }
      }

      // 2. 从网络获取歌曲详情
      print('🌐 [PlayerService] 从网络获取歌曲');
      final songDetail = await MusicService().fetchSongDetail(
        songId: track.id,
        quality: selectedQuality,
        source: track.source,
      );

      if (songDetail == null || songDetail.url.isEmpty) {
        _state = PlayerState.error;
        _errorMessage = '无法获取播放链接';
        print('❌ [PlayerService] 播放失败: $_errorMessage');
        notifyListeners();
        return;
      }

      // 检查歌词是否获取成功
      print('📝 [PlayerService] 从网络获取的歌曲详情:');
      print('   歌曲名: ${songDetail.name}');
      print('   歌词长度: ${songDetail.lyric.length} 字符');
      print('   翻译长度: ${songDetail.tlyric.length} 字符');
      if (songDetail.lyric.isEmpty) {
        print('   ⚠️ 警告：从网络获取的歌曲详情中歌词为空！');
      } else {
        print('   ✅ 歌词获取成功');
      }

      _currentSong = songDetail;
      
      // 🔧 修复：立即通知监听器，让 PlayerPage 能获取到包含歌词的 currentSong
      notifyListeners();
      print('✅ [PlayerService] 已更新 currentSong 并通知监听器（包含歌词）');
      
      // 加载桌面歌词
      _loadLyricsForDesktop();

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
    if (imageUrl.isEmpty) {
      // 如果没有图片URL，设置一个默认颜色
      themeColorNotifier.value = Colors.deepPurple;
      return;
    }

    try {
      // 检查缓存（为移动端渐变模式添加特殊缓存键）
      final backgroundService = PlayerBackgroundService();
      final isMobileGradientMode = Platform.isAndroid && 
                                   backgroundService.enableGradient &&
                                   backgroundService.backgroundType == PlayerBackgroundType.adaptive;
      final cacheKey = isMobileGradientMode ? '${imageUrl}_bottom' : imageUrl;
      
      if (_themeColorCache.containsKey(cacheKey)) {
        final cachedColor = _themeColorCache[cacheKey];
        themeColorNotifier.value = cachedColor;
        print('🎨 [PlayerService] 使用缓存的主题色: $cachedColor');
        return;
      }

      print('🎨 [PlayerService] 开始提取主题色${isMobileGradientMode ? '（从封面底部）' : ''}...');
      
      Color? themeColor;
      
      // 移动端渐变模式：从封面底部区域提取颜色
      if (isMobileGradientMode) {
        themeColor = await _extractColorFromBottomRegion(imageUrl);
      } else {
        // 其他模式：从整张图片提取颜色
        themeColor = await _extractColorFromFullImage(imageUrl);
      }

      // 如果仍然无法提取颜色，使用默认值
      if (themeColor == null) {
        print('⚠️ [PlayerService] 无法从封面提取颜色，使用默认颜色');
        themeColor = Colors.deepPurple;
      }

      _themeColorCache[cacheKey] = themeColor;
      themeColorNotifier.value = themeColor;
      print('✅ [PlayerService] 主题色提取完成: $themeColor');
    } catch (e) {
      print('⚠️ [PlayerService] 主题色提取失败: $e');
      final defaultColor = Colors.deepPurple;
      themeColorNotifier.value = defaultColor;
      print('🎨 [PlayerService] 使用默认主题色: $defaultColor');
    }
  }

  /// 从整张图片提取主题色
  Future<Color?> _extractColorFromFullImage(String imageUrl) async {
    final imageProvider = CachedNetworkImageProvider(imageUrl);
    final timeout = Platform.isAndroid 
        ? const Duration(seconds: 5) 
        : const Duration(seconds: 2);
    
    final paletteGenerator = await PaletteGenerator.fromImageProvider(
      imageProvider,
      maximumColorCount: Platform.isAndroid ? 16 : 12,
      timeout: timeout,
    );

    return paletteGenerator.vibrantColor?.color ?? 
           paletteGenerator.dominantColor?.color ??
           paletteGenerator.darkVibrantColor?.color ??
           paletteGenerator.lightVibrantColor?.color ??
           paletteGenerator.mutedColor?.color;
  }

  /// 从图片底部区域提取主题色（用于移动端渐变模式）
  Future<Color?> _extractColorFromBottomRegion(String imageUrl) async {
    try {
      final imageProvider = CachedNetworkImageProvider(imageUrl);
      
      // 加载图片
      final imageStream = imageProvider.resolve(const ImageConfiguration());
      final completer = async_lib.Completer<ui.Image>();
      late ImageStreamListener listener;
      
      listener = ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(info.image);
        imageStream.removeListener(listener);
      }, onError: (exception, stackTrace) {
        completer.completeError(exception, stackTrace);
        imageStream.removeListener(listener);
      });
      
      imageStream.addListener(listener);
      final image = await completer.future.timeout(const Duration(seconds: 5));
      
      // 计算底部区域（底部 30%）
      final width = image.width;
      final height = image.height;
      final bottomHeight = (height * 0.3).toInt();
      final topOffset = height - bottomHeight;
      
      // 创建一个自定义的 ImageProvider 用于底部区域
      final region = Rect.fromLTWH(0, topOffset.toDouble(), width.toDouble(), bottomHeight.toDouble());
      
      // 对底部区域进行颜色提取
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        region: region,
        maximumColorCount: 20, // 增加采样数以获得更准确的底部颜色
        timeout: const Duration(seconds: 5),
      );

      print('🎨 [PlayerService] 从底部区域提取颜色（区域: ${region.toString()}）');
      
      return paletteGenerator.vibrantColor?.color ?? 
             paletteGenerator.dominantColor?.color ??
             paletteGenerator.darkVibrantColor?.color ??
             paletteGenerator.lightVibrantColor?.color ??
             paletteGenerator.mutedColor?.color;
    } catch (e) {
      print('⚠️ [PlayerService] 从底部区域提取颜色失败: $e，回退到全图提取');
      return _extractColorFromFullImage(imageUrl);
    }
  }

  /// 暂停
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      _pauseListeningTimeTracking();
      print('⏸️ [PlayerService] 暂停播放');
    } catch (e) {
      print('❌ [PlayerService] 暂停失败: $e');
    }
  }

  /// 继续播放
  Future<void> resume() async {
    try {
      await _audioPlayer.resume();
      _startListeningTimeTracking();
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
      
      // 停止听歌时长追踪
      _pauseListeningTimeTracking();
      
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

  /// 开始听歌时长追踪
  void _startListeningTimeTracking() {
    // 如果已经在追踪，不重复启动
    if (_statsTimer != null && _statsTimer!.isActive) return;
    
    _playStartTime = DateTime.now();
    
    // 每5秒记录一次听歌时长
    _statsTimer = async_lib.Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_playStartTime != null) {
        final now = DateTime.now();
        final elapsed = now.difference(_playStartTime!).inSeconds;
        
        if (elapsed > 0) {
          _sessionListeningTime += elapsed;
          ListeningStatsService().accumulateListeningTime(elapsed);
          _playStartTime = now;
          
          print('📊 [PlayerService] 累积听歌时长: +${elapsed}秒 (会话总计: ${_sessionListeningTime}秒)');
        }
      }
    });
    
    print('📊 [PlayerService] 开始听歌时长追踪');
  }
  
  /// 暂停听歌时长追踪
  void _pauseListeningTimeTracking() {
    if (_statsTimer != null) {
      // 在停止定时器前，记录最后一段时间
      if (_playStartTime != null) {
        final now = DateTime.now();
        final elapsed = now.difference(_playStartTime!).inSeconds;
        
        if (elapsed > 0) {
          _sessionListeningTime += elapsed;
          ListeningStatsService().accumulateListeningTime(elapsed);
          print('📊 [PlayerService] 累积听歌时长: +${elapsed}秒 (会话总计: ${_sessionListeningTime}秒)');
        }
      }
      
      _statsTimer?.cancel();
      _statsTimer = null;
      _playStartTime = null;
      print('📊 [PlayerService] 暂停听歌时长追踪');
    }
  }

  /// 清理资源
  @override
  void dispose() {
    print('🗑️ [PlayerService] 释放播放器资源...');
    // 停止统计定时器
    _pauseListeningTimeTracking();
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

  /// 播放完毕后自动播放下一首（根据播放模式）
  Future<void> _playNextFromHistory() async {
    try {
      print('⏭️ [PlayerService] 歌曲播放完毕，检查播放模式...');
      
      final mode = PlaybackModeService().currentMode;
      
      switch (mode) {
        case PlaybackMode.repeatOne:
          // 单曲循环：重新播放当前歌曲
          if (_currentTrack != null) {
            print('🔂 [PlayerService] 单曲循环，重新播放当前歌曲');
            await Future.delayed(const Duration(milliseconds: 500));
            await playTrack(_currentTrack!);
          }
          break;
          
        case PlaybackMode.sequential:
          // 顺序播放：播放历史中的下一首
          await _playNext();
          break;
          
        case PlaybackMode.shuffle:
          // 随机播放：从历史中随机选一首
          await _playRandomFromHistory();
          break;
      }
    } catch (e) {
      print('❌ [PlayerService] 自动播放下一首失败: $e');
    }
  }

  /// 播放下一首（顺序播放模式）
  Future<void> playNext() async {
    final mode = PlaybackModeService().currentMode;
    
    if (mode == PlaybackMode.shuffle) {
      await _playRandomFromHistory();
    } else {
      await _playNext();
    }
  }

  /// 内部方法：播放下一首
  Future<void> _playNext() async {
    try {
      print('⏭️ [PlayerService] 尝试播放下一首...');
      
      // 优先使用播放队列
      if (PlaylistQueueService().hasQueue) {
        final nextTrack = PlaylistQueueService().getNext();
        if (nextTrack != null) {
          print('✅ [PlayerService] 从播放队列获取下一首: ${nextTrack.name}');
          await Future.delayed(const Duration(milliseconds: 500));
          await playTrack(nextTrack);
          return;
        } else {
          print('ℹ️ [PlayerService] 队列已播放完毕，清空队列');
          PlaylistQueueService().clear();
        }
      }
      
      // 如果没有队列，使用播放历史
      final nextTrack = PlayHistoryService().getNextTrack();
      
      if (nextTrack != null) {
        print('✅ [PlayerService] 从播放历史获取下一首: ${nextTrack.name}');
        await Future.delayed(const Duration(milliseconds: 500));
        await playTrack(nextTrack);
      } else {
        print('ℹ️ [PlayerService] 没有更多歌曲可播放');
      }
    } catch (e) {
      print('❌ [PlayerService] 播放下一首失败: $e');
    }
  }

  /// 播放上一首
  Future<void> playPrevious() async {
    try {
      print('⏮️ [PlayerService] 尝试播放上一首...');
      
      // 优先使用播放队列
      if (PlaylistQueueService().hasQueue) {
        final previousTrack = PlaylistQueueService().getPrevious();
        if (previousTrack != null) {
          print('✅ [PlayerService] 从播放队列获取上一首: ${previousTrack.name}');
          await playTrack(previousTrack);
          return;
        }
      }
      
      // 如果没有队列，使用播放历史
      final history = PlayHistoryService().history;
      
      // 当前歌曲在历史记录的第0位，上一首在第2位（第1位是当前歌曲之前播放的）
      if (history.length >= 3) {
        final previousTrack = history[2].toTrack();
        print('✅ [PlayerService] 从播放历史获取上一首: ${previousTrack.name}');
        await playTrack(previousTrack);
      } else {
        print('ℹ️ [PlayerService] 没有上一首可播放');
      }
    } catch (e) {
      print('❌ [PlayerService] 播放上一首失败: $e');
    }
  }

  /// 随机播放：从队列或历史中随机选一首
  Future<void> _playRandomFromHistory() async {
    try {
      print('🔀 [PlayerService] 随机播放模式');
      
      // 优先使用播放队列
      if (PlaylistQueueService().hasQueue) {
        final randomTrack = PlaylistQueueService().getRandomTrack();
        if (randomTrack != null) {
          print('✅ [PlayerService] 从播放队列随机选择: ${randomTrack.name}');
          await Future.delayed(const Duration(milliseconds: 500));
          await playTrack(randomTrack);
          return;
        }
      }
      
      // 如果没有队列，使用播放历史
      final history = PlayHistoryService().history;
      
      if (history.length >= 2) {
        // 排除当前歌曲（第0位），从其他歌曲中随机选择
        final random = Random();
        final randomIndex = random.nextInt(history.length - 1) + 1;
        final randomTrack = history[randomIndex].toTrack();
        
        print('✅ [PlayerService] 从播放历史随机选择: ${randomTrack.name}');
        await Future.delayed(const Duration(milliseconds: 500));
        await playTrack(randomTrack);
      } else {
        print('ℹ️ [PlayerService] 历史记录不足，无法随机播放');
      }
    } catch (e) {
      print('❌ [PlayerService] 随机播放失败: $e');
    }
  }

  /// 检查是否有上一首
  bool get hasPrevious {
    // 优先检查播放队列
    if (PlaylistQueueService().hasQueue) {
      return PlaylistQueueService().hasPrevious;
    }
    // 否则检查播放历史
    return PlayHistoryService().history.length >= 3;
  }

  /// 检查是否有下一首
  bool get hasNext {
    // 优先检查播放队列
    if (PlaylistQueueService().hasQueue) {
      return PlaylistQueueService().hasNext;
    }
    // 否则检查播放历史
    return PlayHistoryService().history.length >= 2;
  }

  /// 加载桌面歌词（Windows平台）
  void _loadLyricsForDesktop() {
    if (!Platform.isWindows) return;
    
    final currentSong = _currentSong;
    if (currentSong == null || currentSong.lyric.isEmpty) {
      print('📝 [PlayerService] 桌面歌词：无歌词可显示');
      _lyrics = [];
      _currentLyricIndex = -1;
      
      // 清空桌面歌词显示
      if (DesktopLyricService().isVisible) {
        DesktopLyricService().setLyricText('');
      }
      return;
    }

    try {
      // 根据音乐来源选择不同的解析器
      switch (currentSong.source.name) {
        case 'netease':
          _lyrics = LyricParser.parseNeteaseLyric(
            currentSong.lyric,
            translation: currentSong.tlyric.isNotEmpty ? currentSong.tlyric : null,
          );
          break;
        case 'qq':
          _lyrics = LyricParser.parseQQLyric(
            currentSong.lyric,
            translation: currentSong.tlyric.isNotEmpty ? currentSong.tlyric : null,
          );
          break;
        case 'kugou':
          _lyrics = LyricParser.parseKugouLyric(
            currentSong.lyric,
            translation: currentSong.tlyric.isNotEmpty ? currentSong.tlyric : null,
          );
          break;
        default:
          _lyrics = LyricParser.parseNeteaseLyric(
            currentSong.lyric,
            translation: currentSong.tlyric.isNotEmpty ? currentSong.tlyric : null,
          );
      }

      _currentLyricIndex = -1;
      print('🎵 [PlayerService] 桌面歌词已加载: ${_lyrics.length} 行');
      
      // 立即更新当前歌词
      _updateDesktopLyric();
    } catch (e) {
      print('❌ [PlayerService] 桌面歌词加载失败: $e');
      _lyrics = [];
      _currentLyricIndex = -1;
    }
  }

  /// 更新桌面歌词显示
  void _updateDesktopLyric() {
    if (!Platform.isWindows) return;
    if (_lyrics.isEmpty) return;
    if (!DesktopLyricService().isVisible) return;

    try {
      final newIndex = LyricParser.findCurrentLineIndex(_lyrics, _position);

      if (newIndex != _currentLyricIndex && newIndex >= 0) {
        _currentLyricIndex = newIndex;
        final currentLine = _lyrics[newIndex];
        
        // 构建显示文本（如果有翻译则显示原文 + 翻译）
        String displayText = currentLine.text;
        if (currentLine.translation != null && currentLine.translation!.isNotEmpty) {
          displayText = '${currentLine.text}\n${currentLine.translation}';
        }
        
        // 更新桌面歌词
        DesktopLyricService().setLyricText(displayText);
      }
    } catch (e) {
      // 忽略更新错误，不影响播放
      print('⚠️ [PlayerService] 桌面歌词更新失败: $e');
    }
  }
}

