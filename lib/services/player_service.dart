import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import '../models/song_detail.dart';
import '../models/track.dart';
import 'music_service.dart';

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
  void initialize() {
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

    print('🎵 [PlayerService] 播放器初始化完成');
  }

  /// 播放歌曲（通过Track对象）
  Future<void> playTrack(Track track, {AudioQuality quality = AudioQuality.exhigh}) async {
    try {
      _state = PlayerState.loading;
      _currentTrack = track;
      _errorMessage = null;
      notifyListeners();

      print('🎵 [PlayerService] 开始播放: ${track.name} - ${track.artists}');

      // 获取歌曲详情
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

      // 播放音乐
      await _audioPlayer.play(ap.UrlSource(songDetail.url));

      print('✅ [PlayerService] 开始播放: ${songDetail.url}');
    } catch (e) {
      _state = PlayerState.error;
      _errorMessage = '播放失败: $e';
      print('❌ [PlayerService] 播放异常: $e');
      notifyListeners();
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

  /// 清理资源
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

