import 'dart:io';
import 'package:flutter/material.dart';
import '../services/player_service.dart';
import '../services/player_background_service.dart';
import '../models/lyric_line.dart';
import '../models/track.dart';
import '../models/song_detail.dart';
import '../utils/lyric_parser.dart';
import 'mobile_lyric_page.dart';
import 'mobile_player_components/mobile_player_background.dart';
import 'mobile_player_components/mobile_player_app_bar.dart';
import 'mobile_player_components/mobile_player_song_info.dart';
import 'mobile_player_components/mobile_player_current_lyric.dart';
import 'mobile_player_components/mobile_player_controls.dart';
import 'mobile_player_components/mobile_player_control_center.dart';
import 'mobile_player_components/mobile_player_dialogs.dart';

/// 移动端播放器页面（重构版本）
/// 适用于 Android/iOS，现在使用组件化架构
class MobilePlayerPage extends StatefulWidget {
  const MobilePlayerPage({super.key});

  @override
  State<MobilePlayerPage> createState() => _MobilePlayerPageState();
}

class _MobilePlayerPageState extends State<MobilePlayerPage> with TickerProviderStateMixin {
  // 歌词相关
  List<LyricLine> _lyrics = [];
  int _currentLyricIndex = -1;
  String? _lastTrackId;
  
  // 控制中心
  bool _showControlCenter = false;
  AnimationController? _controlCenterAnimationController;
  Animation<double>? _controlCenterFadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupListeners();
    _initializeData();
  }

  @override
  void dispose() {
    _disposeAnimations();
    _removeListeners();
    super.dispose();
  }

  /// 初始化动画控制器
  void _initializeAnimations() {
    _controlCenterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _controlCenterFadeAnimation = CurvedAnimation(
      parent: _controlCenterAnimationController!,
      curve: Curves.easeInOut,
    );
  }

  /// 设置监听器
  void _setupListeners() {
    PlayerService().addListener(_onPlayerStateChanged);
  }

  /// 移除监听器
  void _removeListeners() {
    PlayerService().removeListener(_onPlayerStateChanged);
  }

  /// 释放动画控制器
  void _disposeAnimations() {
    _controlCenterAnimationController?.dispose();
  }

  /// 初始化数据
  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentTrack = PlayerService().currentTrack;
      _lastTrackId = currentTrack != null 
          ? '${currentTrack.source.name}_${currentTrack.id}' 
          : null;
      _loadLyrics();
    });
  }

  /// 播放器状态变化回调
  void _onPlayerStateChanged() {
    if (!mounted) return;
    
    final currentTrack = PlayerService().currentTrack;
    final currentTrackId = currentTrack != null 
        ? '${currentTrack.source.name}_${currentTrack.id}' 
        : null;
    
    // 检测歌曲切换
    if (currentTrackId != _lastTrackId) {
      _lastTrackId = currentTrackId;
      
      // 🔧 修复：立即清空歌词，避免显示上一首歌的歌词
      setState(() {
        _lyrics = [];
        _currentLyricIndex = -1;
      });
      
      // 延迟加载歌词，等待 PlayerService 更新 currentSong
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _loadLyrics();
        }
      });
    } else {
      // 只更新歌词高亮
      _updateCurrentLyric();
    }
  }

  /// 加载歌词
  Future<void> _loadLyrics() async {
    final currentTrack = PlayerService().currentTrack;
    final currentSong = PlayerService().currentSong;
    
    // 🔧 修复：检查 currentSong 的 ID 是否与 currentTrack 匹配
    if (currentSong != null && currentTrack != null) {
      final songId = currentSong.id.toString();
      final trackId = currentTrack.id.toString();
      
      // 如果 ID 不匹配，说明 currentSong 还是旧的，需要等待更新
      if (songId != trackId) {
        print('⚠️ [MobilePlayer] 歌曲数据不匹配，等待更新... (Song: $songId, Track: $trackId)');
        
        // 重试最多 5 次，每次等待 100ms
        for (int i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          final updatedSong = PlayerService().currentSong;
          if (updatedSong != null && updatedSong.id.toString() == trackId) {
            print('✅ [MobilePlayer] 歌曲数据已更新，继续加载歌词');
            return _loadLyrics(); // 递归调用，重新加载
          }
        }
        
        print('❌ [MobilePlayer] 等待超时，歌曲数据未更新');
      }
    }
    
    if (currentSong == null || currentSong.lyric == null || currentSong.lyric!.isEmpty) {
      if (mounted) {
        setState(() {
          _lyrics = [];
          _currentLyricIndex = -1;
        });
      }
      return;
    }

    try {
      final lyrics = LyricParser.parseNeteaseLyric(
        currentSong.lyric!,
        translation: currentSong.tlyric.isNotEmpty ? currentSong.tlyric : null,
      );
      if (mounted) {
        setState(() {
          _lyrics = lyrics;
          // 立即计算当前歌词索引
          if (_lyrics.isNotEmpty) {
            _currentLyricIndex = LyricParser.findCurrentLineIndex(
              _lyrics,
              PlayerService().position,
            );
          } else {
            _currentLyricIndex = -1;
          }
        });
        print('✅ [MobilePlayer] 歌词加载成功: ${currentSong.name}, 共 ${lyrics.length} 行');
      }
    } catch (e) {
      print('❌ [MobilePlayer] 歌词解析失败: $e');
      if (mounted) {
        setState(() {
          _lyrics = [];
          _currentLyricIndex = -1;
        });
      }
    }
  }

  /// 更新当前歌词
  void _updateCurrentLyric() {
    if (_lyrics.isEmpty) return;
    
    final newIndex = LyricParser.findCurrentLineIndex(
      _lyrics,
      PlayerService().position,
    );

    if (newIndex != _currentLyricIndex && newIndex >= 0 && mounted) {
      setState(() {
        _currentLyricIndex = newIndex;
      });
    }
  }

  /// 切换控制中心显示状态
  void _toggleControlCenter() {
    setState(() {
      _showControlCenter = !_showControlCenter;
      if (_showControlCenter) {
        _controlCenterAnimationController?.forward();
      } else {
        _controlCenterAnimationController?.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = PlayerService();
    final song = player.currentSong;
    final track = player.currentTrack;

    if (song == null && track == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            '暂无播放内容',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    // 构建主要内容
    final scaffoldWidget = Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 背景层
          const MobilePlayerBackground(),
          
          // 内容层
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final backgroundService = PlayerBackgroundService();
                final showCover = !backgroundService.enableGradient || 
                                backgroundService.backgroundType != PlayerBackgroundType.adaptive;
                
                return Column(
                  children: [
                    // 顶部栏
                    MobilePlayerAppBar(
                      onBackPressed: () => Navigator.pop(context),
                    ),
                    
                    // 主要内容区域 - 专辑封面和歌曲信息
                    Expanded(
                      child: MobilePlayerSongInfo(showCover: showCover),
                    ),
                    
                    // 当前歌词（位于控制器上方）
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: MobilePlayerCurrentLyric(
                        lyrics: _lyrics,
                        currentLyricIndex: _currentLyricIndex,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MobileLyricPage(),
                          ),
                        ),
                      ),
                    ),
                    
                    // 底部控制区域
                    MobilePlayerControls(
                      onPlaylistPressed: () => MobilePlayerDialogs.showPlaylistBottomSheet(context),
                      onSleepTimerPressed: () => MobilePlayerDialogs.showSleepTimer(context),
                      onVolumeControlPressed: _toggleControlCenter,
                      onAddToPlaylistPressed: (track) => MobilePlayerDialogs.showAddToPlaylist(context, track),
                    ),
                  ],
                );
              },
            ),
          ),

          // 控制中心面板
          MobilePlayerControlCenter(
            isVisible: _showControlCenter,
            fadeAnimation: _controlCenterFadeAnimation,
            onClose: _toggleControlCenter,
          ),
        ],
      ),
    );
    
    // Windows 平台：添加圆角边框
    if (Platform.isWindows) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: scaffoldWidget,
      );
    }
    
    return scaffoldWidget;
  }

}
