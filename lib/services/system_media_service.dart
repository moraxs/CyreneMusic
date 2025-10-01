import 'dart:io';
import 'player_service.dart';

// 条件导入系统媒体控件
import 'package:smtc_windows/smtc_windows.dart' if (dart.library.html) '';

/// 系统媒体控件服务
/// 用于在 Windows 和 Android 平台上集成原生媒体控件
class SystemMediaService {
  static final SystemMediaService _instance = SystemMediaService._internal();
  factory SystemMediaService() => _instance;
  SystemMediaService._internal();

  SMTCWindows? _smtcWindows;
  bool _initialized = false;

  /// 初始化系统媒体控件
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (Platform.isWindows) {
        await _initializeWindows();
      } else if (Platform.isAndroid) {
        await _initializeAndroid();
      }
      
      // 监听播放器状态变化
      PlayerService().addListener(_onPlayerStateChanged);
      
      _initialized = true;
      print('🎵 [SystemMediaService] 系统媒体控件初始化完成');
    } catch (e) {
      print('❌ [SystemMediaService] 初始化失败: $e');
    }
  }

  /// 初始化 Windows 媒体控件 (SMTC)
  Future<void> _initializeWindows() async {
    try {
      _smtcWindows = SMTCWindows(
        metadata: const MusicMetadata(
          title: 'Cyrene Music',
          album: '',
          albumArtist: '',
          artist: '',
          thumbnail: '',
        ),
        timeline: const PlaybackTimeline(
          startTimeMs: 0,
          endTimeMs: 0,
          positionMs: 0,
          minSeekTimeMs: 0,
          maxSeekTimeMs: 0,
        ),
        config: const SMTCConfig(
          fastForwardEnabled: false,
          nextEnabled: false,
          pauseEnabled: true,
          playEnabled: true,
          rewindEnabled: false,
          prevEnabled: false,
          stopEnabled: true,
        ),
      );

      // 监听 SMTC 按钮事件
      _smtcWindows!.buttonPressStream.listen((button) {
        _handleButtonPress(button);
      });

      // 启用 SMTC
      _smtcWindows!.enableSmtc();
      _smtcWindows!.setPlaybackStatus(PlaybackStatus.stopped);
      
      print('✅ [SystemMediaService] Windows SMTC 初始化成功');
    } catch (e) {
      print('❌ [SystemMediaService] Windows SMTC 初始化失败: $e');
    }
  }

  /// 初始化 Android 媒体控件
  Future<void> _initializeAndroid() async {
    // TODO: 集成 audio_service
    // Android 平台需要更复杂的设置，包括创建后台服务
    // 这里暂时预留接口
    print('🔧 [SystemMediaService] Android audio_service 待实现');
  }

  /// 处理媒体按钮事件
  void _handleButtonPress(PressedButton button) {
    final player = PlayerService();
    
    switch (button) {
      case PressedButton.play:
        print('▶️ [SystemMediaService] 系统媒体控件: 播放');
        player.resume();
        break;
      case PressedButton.pause:
        print('⏸️ [SystemMediaService] 系统媒体控件: 暂停');
        player.pause();
        break;
      case PressedButton.stop:
        print('⏹️ [SystemMediaService] 系统媒体控件: 停止');
        player.stop();
        break;
      case PressedButton.next:
        print('⏭️ [SystemMediaService] 系统媒体控件: 下一曲');
        // TODO: 实现下一曲
        break;
      case PressedButton.previous:
        print('⏮️ [SystemMediaService] 系统媒体控件: 上一曲');
        // TODO: 实现上一曲
        break;
      default:
        break;
    }
  }

  /// 监听播放器状态变化，同步到系统媒体控件
  void _onPlayerStateChanged() {
    if (!_initialized) return;

    final player = PlayerService();
    final song = player.currentSong;
    final track = player.currentTrack;

    if (Platform.isWindows && _smtcWindows != null) {
      _updateWindowsMedia(player, song, track);
    } else if (Platform.isAndroid) {
      _updateAndroidMedia(player, song, track);
    }
  }

  /// 更新 Windows 媒体信息
  void _updateWindowsMedia(PlayerService player, dynamic song, dynamic track) {
    try {
      // 更新播放状态
      final status = _getPlaybackStatus(player.state);
      
      // 更新媒体信息
      if (song != null || track != null) {
        final title = song?.name ?? track?.name ?? '未知歌曲';
        final artist = song?.arName ?? track?.artists ?? '未知艺术家';
        final album = song?.alName ?? track?.album ?? '未知专辑';
        var thumbnail = song?.pic ?? track?.picUrl ?? '';
        
        // 确保使用 HTTPS 协议
        if (thumbnail.startsWith('http://')) {
          thumbnail = thumbnail.replaceFirst('http://', 'https://');
        }
        
        print('🖼️ [SystemMediaService] 更新媒体信息:');
        print('   标题: $title');
        print('   艺术家: $artist');
        print('   专辑: $album');
        print('   封面 URL: $thumbnail');
        print('   封面 URL 长度: ${thumbnail.length}');
        print('   封面 URL 是否为空: ${thumbnail.isEmpty}');
        
        // 先更新元数据，再更新状态
        _smtcWindows!.updateMetadata(
          MusicMetadata(
            title: title,
            artist: artist,
            album: album,
            albumArtist: artist,
            thumbnail: thumbnail,
          ),
        );
        
        print('✅ [SystemMediaService] 元数据已更新到 SMTC');
      }
      
      // 更新播放状态（在元数据之后）
      _smtcWindows!.setPlaybackStatus(status);

      // 更新时间轴信息
      if (player.duration.inMilliseconds > 0) {
        _smtcWindows!.updateTimeline(
          PlaybackTimeline(
            startTimeMs: 0,
            endTimeMs: player.duration.inMilliseconds,
            positionMs: player.position.inMilliseconds,
            minSeekTimeMs: 0,
            maxSeekTimeMs: player.duration.inMilliseconds,
          ),
        );
      }
    } catch (e) {
      print('❌ [SystemMediaService] 更新 Windows 媒体信息失败: $e');
      print('   错误堆栈: ${StackTrace.current}');
    }
  }

  /// 更新 Android 媒体信息
  void _updateAndroidMedia(PlayerService player, dynamic song, dynamic track) {
    // TODO: 实现 Android audio_service 更新
    // 需要使用 audio_service 包的 API
  }

  /// 将播放状态转换为 SMTC 播放状态
  PlaybackStatus _getPlaybackStatus(PlayerState state) {
    switch (state) {
      case PlayerState.playing:
        return PlaybackStatus.playing;
      case PlayerState.paused:
        return PlaybackStatus.paused;
      case PlayerState.loading:
        return PlaybackStatus.changing;
      default:
        return PlaybackStatus.stopped;
    }
  }

  /// 清理资源
  void dispose() {
    PlayerService().removeListener(_onPlayerStateChanged);
    _smtcWindows?.dispose();
    _initialized = false;
    print('🎵 [SystemMediaService] 系统媒体控件已清理');
  }
}

