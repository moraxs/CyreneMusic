import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'player_service.dart';

/// Android 媒体通知处理器
/// 使用 audio_service 包实现 Android 系统通知栏的媒体控件
class CyreneAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  Timer? _updateTimer;  // 防抖定时器
  bool _updatePending = false;  // 是否有待处理的更新
  
  // 构造函数
  CyreneAudioHandler() {
    print('🎵 [AudioHandler] 开始初始化...');
    
    // 🔧 关键修复：立即设置初始播放状态（必需，否则通知不会显示）
    _setInitialPlaybackState();
    
    // 监听播放器状态变化
    PlayerService().addListener(_onPlayerStateChanged);
    
    print('✅ [AudioHandler] 初始化完成');
  }
  
  @override
  Future<void> onTaskRemoved() async {
    // 清理定时器
    _updateTimer?.cancel();
    await super.onTaskRemoved();
  }

  /// 设置初始播放状态（必需）
  void _setInitialPlaybackState() {
    // 设置初始 MediaItem（即使没有歌曲也要设置）
    mediaItem.add(MediaItem(
      id: '0',
      title: 'Cyrene Music',
      artist: '等待播放...',
      album: '',
      duration: Duration.zero,
    ));
    
    // 设置初始 PlaybackState（这是显示通知的关键）
    // 只显示 3 个按钮：上一首、播放、下一首
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,  // 上一首
        MediaControl.play,            // 播放
        MediaControl.skipToNext,      // 下一首
      ],
      systemActions: const {
        MediaAction.seek,
      },
      androidCompactActionIndices: const [0, 1, 2],  // 全部 3 个按钮都显示
      processingState: AudioProcessingState.idle,
      playing: false,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      speed: 0.0,
      queueIndex: 0,
    ));
    
    print('✅ [AudioHandler] 初始播放状态已设置（3个按钮：上一首/播放/下一首）');
  }

  /// 播放器状态变化回调（带防抖）
  void _onPlayerStateChanged() {
    // 🔧 性能优化：使用防抖机制，避免过于频繁的更新（例如调整音量时）
    // 取消之前的定时器
    _updateTimer?.cancel();
    
    // 标记有待处理的更新
    _updatePending = true;
    
    // 设置新的定时器，延迟 100ms 执行更新
    _updateTimer = Timer(const Duration(milliseconds: 100), () {
      if (_updatePending) {
        _performUpdate();
        _updatePending = false;
      }
    });
  }
  
  /// 实际执行更新操作
  void _performUpdate() {
    final player = PlayerService();
    final song = player.currentSong;
    final track = player.currentTrack;
    
    // 更新播放状态
    _updatePlaybackState(player.state, player.position, player.duration);

    // 更新媒体信息
    if (song != null || track != null) {
      _updateMediaItem(song, track);
    }
  }

  /// 更新媒体信息
  void _updateMediaItem(dynamic song, dynamic track) {
    final title = song?.name ?? track?.name ?? '未知歌曲';
    final artist = song?.arName ?? track?.artists ?? '未知歌手';
    final album = song?.alName ?? track?.album ?? '';
    final artUri = song?.pic ?? track?.picUrl ?? '';

    mediaItem.add(MediaItem(
      id: track?.id.toString() ?? '0',
      title: title,
      artist: artist,
      album: album,
      artUri: artUri.isNotEmpty ? Uri.parse(artUri) : null,
      duration: PlayerService().duration,
    ));
  }

  /// 更新播放状态
  void _updatePlaybackState(PlayerState playerState, Duration position, Duration duration) {
    // 只保留 3 个核心按钮：上一首、播放/暂停、下一首
    final controls = [
      MediaControl.skipToPrevious,  // 上一首
      if (playerState == PlayerState.playing)
        MediaControl.pause          // 暂停
      else
        MediaControl.play,          // 播放
      MediaControl.skipToNext,      // 下一首
    ];

    final playing = playerState == PlayerState.playing;
    final processingState = _getProcessingState(playerState);

    playbackState.add(playbackState.value.copyWith(
      controls: controls,
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2], // 全部3个按钮都显示在紧凑视图
      processingState: processingState,
      playing: playing,
      updatePosition: position,
      bufferedPosition: duration,
      speed: playing ? 1.0 : 0.0,
      queueIndex: 0,
    ));
  }

  /// 转换播放状态
  AudioProcessingState _getProcessingState(PlayerState state) {
    switch (state) {
      case PlayerState.idle:
        return AudioProcessingState.idle;
      case PlayerState.loading:
        return AudioProcessingState.loading;
      case PlayerState.playing:
      case PlayerState.paused:
        return AudioProcessingState.ready;
      case PlayerState.error:
        return AudioProcessingState.error;
    }
  }

  // ============== 媒体控制按钮回调 ==============

  @override
  Future<void> play() async {
    await PlayerService().resume();
  }

  @override
  Future<void> pause() async {
    await PlayerService().pause();
  }

  @override
  Future<void> stop() async {
    await PlayerService().stop();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    // 🔧 修复：使用 PlayerService 的 playNext 方法
    // 这样可以正确处理播放队列和播放历史
    await PlayerService().playNext();
  }

  @override
  Future<void> skipToPrevious() async {
    // 🔧 修复：使用 PlayerService 的 playPrevious 方法
    // 这样可以正确处理播放队列和播放历史
    await PlayerService().playPrevious();
  }

  @override
  Future<void> seek(Duration position) async {
    await PlayerService().seek(position);
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    // 自定义操作处理
  }
}


