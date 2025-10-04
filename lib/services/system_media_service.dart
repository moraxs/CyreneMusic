import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'player_service.dart';
import 'tray_service.dart';
import 'audio_handler_service.dart';

// 条件导入系统媒体控件
// 使用平台抽象层，在 Windows 平台使用真实实现，其他平台使用桩实现
import 'smtc_platform.dart';

/// 系统媒体控件服务
/// 用于在 Windows 和 Android 平台上集成原生媒体控件
class SystemMediaService {
  static final SystemMediaService _instance = SystemMediaService._internal();
  factory SystemMediaService() => _instance;
  SystemMediaService._internal();

  SMTCWindows? _smtcWindows;
  CyreneAudioHandler? _audioHandler;  // Android 媒体处理器
  bool _initialized = false;
  bool _isDisposed = false; // 是否已释放
  
  // 缓存上次更新的信息，避免重复更新
  int? _lastSongId;  // 使用 hashCode 作为唯一标识
  PlayerState? _lastPlayerState;

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
          nextEnabled: true,        // 启用下一首
          pauseEnabled: true,
          playEnabled: true,
          rewindEnabled: false,
          prevEnabled: true,         // 启用上一首
          stopEnabled: true,
        ),
      );

      // 监听 SMTC 按钮事件
      _smtcWindows!.buttonPressStream.listen((button) {
        _handleButtonPress(button);
      });

      // 启用 SMTC
      try {
        _smtcWindows!.enableSmtc();
        _smtcWindows!.setPlaybackStatus(PlaybackStatus.stopped);
      } catch (e) {
        // 忽略初始化时的 SharedMemory 错误
        if (!e.toString().contains('SharedMemory')) {
          throw e;
        }
      }
      
      print('✅ [SystemMediaService] Windows SMTC 初始化成功');
    } catch (e) {
      print('❌ [SystemMediaService] Windows SMTC 初始化失败: $e');
    }
  }

  /// 初始化 Android 媒体控件
  Future<void> _initializeAndroid() async {
    try {
      print('📱 [SystemMediaService] 开始初始化 Android audio_service...');
      
      // 初始化 audio_service 并创建 AudioHandler
      // 根据文档：androidStopForegroundOnPause = false 时，androidNotificationOngoing 必须也为 false
      // 这样可以避免 Android 12+ 的 ForegroundServiceStartNotAllowedException
      _audioHandler = await AudioService.init(
        builder: () => CyreneAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.cyrene.music.channel.audio',
          androidNotificationChannelName: 'Cyrene Music',
          androidNotificationOngoing: false,  // 必须为 false（配合 androidStopForegroundOnPause = false）
          // 不设置 androidNotificationIcon，使用 audio_service 的默认图标（避免黑色方块）
          // 如果需要自定义图标，需要在 drawable 目录创建单色透明背景的图标
          androidShowNotificationBadge: true,
          androidStopForegroundOnPause: false,  // 保持服务在前台，避免 Android 12+ 重启问题
        ),
      ) as CyreneAudioHandler;
      
      if (_audioHandler != null) {
        print('✅ [SystemMediaService] Android audio_service 初始化成功');
        print('   AudioHandler 类型: ${_audioHandler.runtimeType}');
        print('   通知渠道 ID: com.cyrene.music.channel.audio');
        print('   ⚠️ 如果通知未显示，请检查：');
        print('      1. 是否授予了通知权限（Android 13+）');
        print('      2. 是否播放了歌曲触发状态更新');
        print('      3. 查看 AudioHandler 日志确认状态是否更新');
      } else {
        print('❌ [SystemMediaService] AudioHandler 为 null');
      }
    } catch (e, stackTrace) {
      print('❌ [SystemMediaService] Android audio_service 初始化失败: $e');
      print('   堆栈跟踪: $stackTrace');
    }
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
        player.playNext();
        break;
      case PressedButton.previous:
        print('⏮️ [SystemMediaService] 系统媒体控件: 上一曲');
        player.playPrevious();
        break;
      default:
        break;
    }
  }

  /// 监听播放器状态变化，同步到系统媒体控件
  void _onPlayerStateChanged() {
    // 如果已释放或未初始化，不再处理
    if (!_initialized || _isDisposed) {
      print('⚠️ [SystemMediaService] 已释放，跳过状态更新');
      return;
    }

    final player = PlayerService();
    final song = player.currentSong;
    final track = player.currentTrack;

    if (Platform.isWindows && _smtcWindows != null) {
      _updateWindowsMedia(player, song, track);
    }
    // Android 平台的媒体通知由 AudioHandler 自动处理，无需在此手动更新
    
    // 同时更新系统托盘菜单（updateMenu 内部已有智能检测，不会频繁更新）
    if (!_isDisposed) {
      TrayService().updateMenu();
    }
  }
  
  /// 获取当前歌曲的唯一 ID（使用 hashCode 统一处理 int 和 String）
  int? _getCurrentSongId(dynamic song, dynamic track) {
    if (song != null) {
      // song.id 可能是 int 或 String，使用 hashCode 统一处理
      return song.id?.hashCode ?? song.name.hashCode;
    } else if (track != null) {
      // track.id 可能是 int 或 String，使用 hashCode 统一处理
      return track.id?.hashCode ?? track.name.hashCode;
    }
    return null;
  }

  /// 更新 Windows 媒体信息（智能更新，避免频繁刷新）
  void _updateWindowsMedia(PlayerService player, dynamic song, dynamic track) {
    try {
      final currentSongId = _getCurrentSongId(song, track);
      final currentState = player.state;
      
      // 检查 SMTC 是否需要重新启用（在歌曲切换或状态改变时）
      final shouldEnableSmtc = _lastSongId == null && 
                               currentSongId != null && 
                               currentState != PlayerState.idle &&
                               currentState != PlayerState.error;
      
      if (shouldEnableSmtc) {
        print('▶️ [SystemMediaService] 重新启用 SMTC');
        try {
          _smtcWindows!.enableSmtc();
        } catch (e) {
          // 忽略 SharedMemory 错误
          if (!e.toString().contains('SharedMemory')) {
            print('⚠️ [SystemMediaService] 启用 SMTC 失败: $e');
          }
        }
      }
      
      // 1. 检查是否是新歌曲，只在歌曲切换时更新元数据
      final isSongChanged = currentSongId != _lastSongId && currentSongId != null;
      if (isSongChanged) {
        print('🎵 [SystemMediaService] 歌曲切换，更新元数据...');
        _updateMetadata(song, track);
        _lastSongId = currentSongId;
      }
      
      // 2. 检查播放状态是否改变，只在状态改变时更新
      final isStateChanged = currentState != _lastPlayerState;
      if (isStateChanged) {
        final status = _getPlaybackStatus(currentState);
        print('🎮 [SystemMediaService] 状态改变: ${currentState.name} -> ${status.name}');
        
        try {
          _smtcWindows!.setPlaybackStatus(status);
        } catch (e) {
          // 忽略 SharedMemory 错误，不影响播放
          if (!e.toString().contains('SharedMemory')) {
            print('⚠️ [SystemMediaService] 更新状态失败: $e');
          }
        }
        
        _lastPlayerState = currentState;
        
        // 如果是停止或空闲状态，禁用 SMTC
        if (status == PlaybackStatus.stopped && currentState == PlayerState.idle) {
          print('⏹️ [SystemMediaService] 停止播放，禁用 SMTC');
          try {
            _smtcWindows!.disableSmtc();
          } catch (e) {
            // 忽略错误
            if (!e.toString().contains('SharedMemory')) {
              print('⚠️ [SystemMediaService] 禁用 SMTC 失败: $e');
            }
          }
          _lastSongId = null; // 清除缓存，下次播放时重新更新元数据
        }
      }
      
      // 3. 只在播放中且有有效时长时更新 timeline（进度信息）
      // 注意：不要每次都更新，timeline 会自动推进
      if (currentState == PlayerState.playing && 
          player.duration.inMilliseconds > 0 &&
          (isSongChanged || isStateChanged)) {
        print('⏱️ [SystemMediaService] 更新播放进度');
        
        try {
          _smtcWindows!.updateTimeline(
            PlaybackTimeline(
              startTimeMs: 0,
              endTimeMs: player.duration.inMilliseconds,
              positionMs: player.position.inMilliseconds,
              minSeekTimeMs: 0,
              maxSeekTimeMs: player.duration.inMilliseconds,
            ),
          );
        } catch (e) {
          // 忽略 SharedMemory 错误，不影响播放
          if (!e.toString().contains('SharedMemory')) {
            print('⚠️ [SystemMediaService] 更新进度失败: $e');
          }
        }
      }
    } catch (e) {
      print('❌ [SystemMediaService] 更新 Windows 媒体信息失败: $e');
    }
  }
  
  /// 更新元数据（标题、艺术家、封面等）
  void _updateMetadata(dynamic song, dynamic track) {
    if (song == null && track == null) {
      print('⚠️ [SystemMediaService] 没有歌曲信息，跳过元数据更新');
      return;
    }
    
    final title = song?.name ?? track?.name ?? '未知歌曲';
    final artist = song?.arName ?? track?.artists ?? '未知艺术家';
    final album = song?.alName ?? track?.album ?? '未知专辑';
    var thumbnail = song?.pic ?? track?.picUrl ?? '';
    
    // 确保使用 HTTPS 协议（SMTC 要求）
    if (thumbnail.startsWith('http://')) {
      thumbnail = thumbnail.replaceFirst('http://', 'https://');
    }
    
    print('🖼️ [SystemMediaService] 更新元数据:');
    print('   📝 标题: $title');
    print('   👤 艺术家: $artist');
    print('   💿 专辑: $album');
    print('   🖼️ 封面: ${thumbnail.isNotEmpty ? "已设置" : "无"}');
    
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
    if (_isDisposed) {
      print('⚠️ [SystemMediaService] 已经清理过，跳过');
      return;
    }
    
    print('🎵 [SystemMediaService] 开始清理系统媒体控件...');
    
    // 立即设置标志，阻止继续更新（必须在最前面）
    _isDisposed = true;
    _initialized = false;
    
    try {
      // 移除播放器监听器（防止后续状态改变触发更新）
      print('🔌 [SystemMediaService] 移除播放器监听器...');
      PlayerService().removeListener(_onPlayerStateChanged);
      
      // 清除缓存状态
      _lastSongId = null;
      _lastPlayerState = null;
      
      // 释放 SMTC（不等待，让系统自动清理）
      if (_smtcWindows != null) {
        print('🗑️ [SystemMediaService] 释放 SMTC 资源...');
        _smtcWindows?.dispose();
        _smtcWindows = null;
      }
      
      // 释放 Android AudioHandler
      if (_audioHandler != null) {
        print('🗑️ [SystemMediaService] 释放 AudioHandler 资源...');
        _audioHandler = null;
      }
      
      print('✅ [SystemMediaService] 系统媒体控件已清理');
    } catch (e) {
      print('⚠️ [SystemMediaService] 清理失败: $e');
    }
  }
}

