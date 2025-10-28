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
import 'mobile_player_components/mobile_player_controls.dart';
import 'mobile_player_components/mobile_player_control_center.dart';
import 'mobile_player_components/mobile_player_karaoke_lyric.dart';
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
  bool _showTranslation = true;
  AnimationController? _controlCenterAnimationController;
  Animation<double>? _controlCenterFadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupListeners();
    _initializeData();
  }

  /// 是否应该显示译文按钮（与全屏歌词页一致逻辑）
  bool _shouldShowTranslationButton() {
    if (_lyrics.isEmpty) return false;
    final hasTranslation = _lyrics.any((l) => l.translation != null && l.translation!.isNotEmpty);
    if (!hasTranslation) return false;
    final sample = _lyrics.where((l) => l.text.trim().isNotEmpty).take(5).map((l) => l.text).join('');
    if (sample.isEmpty) return false;
    final chineseCount = sample.runes.where((r) =>
      (r >= 0x4E00 && r <= 0x9FFF) || (r >= 0x3400 && r <= 0x4DBF) || (r >= 0x20000 && r <= 0x2A6DF)
    ).length;
    final ratio = chineseCount / sample.length;
    return ratio < 0.3; // 中文占比小于30%判定为外文
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

  /// 播放器状态变化回调（与桌面端保持一致的逻辑）
  void _onPlayerStateChanged() {
    if (!mounted) return;
    
    final currentTrack = PlayerService().currentTrack;
    final currentTrackId = currentTrack != null 
        ? '${currentTrack.source.name}_${currentTrack.id}' 
        : null;
    
    if (currentTrackId != _lastTrackId) {
      // 歌曲已切换，重新加载歌词
      print('🎵 [MobilePlayerPage] 检测到歌曲切换，重新加载歌词');
      print('   上一首ID: $_lastTrackId');
      print('   当前ID: $currentTrackId');
      
      _lastTrackId = currentTrackId;
        _lyrics = [];
        _currentLyricIndex = -1;
          _loadLyrics();
      setState(() {}); // 触发重建以更新UI
    } else {
      // 只更新歌词行索引，不触发整页重建
      _updateCurrentLyric();
    }
  }

  /// 加载歌词（异步执行，不阻塞 UI）
  Future<void> _loadLyrics() async {
    final currentTrack = PlayerService().currentTrack;
    if (currentTrack == null) return;

    print('🔍 [MobilePlayerPage] 开始加载歌词，当前 Track: ${currentTrack.name}');
    print('   Track ID: ${currentTrack.id} (类型: ${currentTrack.id.runtimeType})');

    // 等待 currentSong 更新（最多等待3秒）
    SongDetail? song;
    final startTime = DateTime.now();
    int attemptCount = 0;
    
    while (song == null && DateTime.now().difference(startTime).inSeconds < 3) {
      song = PlayerService().currentSong;
      attemptCount++;
      
      // 验证 currentSong 是否匹配 currentTrack
      if (song != null) {
        final songId = song.id.toString();
      final trackId = currentTrack.id.toString();
      
        if (attemptCount == 1) {
          print('🔍 [MobilePlayerPage] 找到 currentSong: ${song.name}');
          print('   Song ID: ${song.id} (类型: ${song.id.runtimeType})');
          print('   Track ID: ${currentTrack.id} (类型: ${currentTrack.id.runtimeType})');
          print('   ID 匹配: ${songId == trackId}');
        }
        
        // 如果 ID 不匹配，说明 currentSong 还没更新
        if (songId != trackId) {
          if (attemptCount <= 3) {
            print('⚠️ [MobilePlayerPage] ID 不匹配！Song ID: "$songId" vs Track ID: "$trackId"');
          }
          song = null;
          await Future.delayed(const Duration(milliseconds: 100));
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    
    if (song == null) {
      print('❌ [MobilePlayerPage] 等待歌曲详情超时！');
      print('   尝试次数: $attemptCount');
      print('   Track: ${currentTrack.name} (ID: ${currentTrack.id})');
      final currentSong = PlayerService().currentSong;
      if (currentSong != null) {
        print('   CurrentSong 存在但 ID 不匹配: ${currentSong.name} (ID: ${currentSong.id})');
      } else {
        print('   CurrentSong 为 null');
      }
      return;
    }

    // 使用本地变量确保非空
    final songDetail = song;

    try {
      print('📝 [MobilePlayerPage] 开始解析歌词');
      print('   歌曲名: ${songDetail.name}');
      print('   歌曲ID: ${songDetail.id}');
      print('   原始歌词长度: ${songDetail.lyric.length} 字符');
      print('   翻译长度: ${songDetail.tlyric.length} 字符');
      
      // 关键诊断：检查歌词内容
      if (songDetail.lyric.isEmpty) {
        print('   ❌ 错误：MobilePlayerPage 读取到的 currentSong.lyric 为空！');
        print('   这说明 PlayerService.currentSong 中的歌词确实是空的');
      } else {
        print('   ✅ MobilePlayerPage 成功读取到歌词数据');
        print('   歌词预览: ${songDetail.lyric.substring(0, songDetail.lyric.length > 50 ? 50 : songDetail.lyric.length)}...');
      }
      
      // 使用 Future.microtask 确保异步执行
      await Future.microtask(() {
        // 根据音乐来源选择不同的解析器
        switch (songDetail.source.name) {
          case 'netease':
            _lyrics = LyricParser.parseNeteaseLyric(
              songDetail.lyric,
              translation: songDetail.tlyric.isNotEmpty ? songDetail.tlyric : null,
            );
            break;
          case 'qq':
            _lyrics = LyricParser.parseQQLyric(
              songDetail.lyric,
              translation: songDetail.tlyric.isNotEmpty ? songDetail.tlyric : null,
            );
            break;
          case 'kugou':
            _lyrics = LyricParser.parseKugouLyric(
              songDetail.lyric,
              translation: songDetail.tlyric.isNotEmpty ? songDetail.tlyric : null,
            );
            break;
        }
      });

      if (_lyrics.isEmpty && songDetail.lyric.isNotEmpty) {
        print('⚠️ [MobilePlayerPage] 歌词解析结果为空，但原始歌词不为空！');
        print('   原始歌词前100字符: ${songDetail.lyric.substring(0, songDetail.lyric.length > 100 ? 100 : songDetail.lyric.length)}');
      }

      print('🎵 [MobilePlayerPage] 加载歌词: ${_lyrics.length} 行 (${songDetail.name})');
      
      // 加载歌词后，更新并滚动到当前位置
      if (_lyrics.isNotEmpty && mounted) {
        setState(() {
          _updateCurrentLyric();
        });
      }
    } catch (e) {
      print('❌ [MobilePlayerPage] 加载歌词失败: $e');
      print('   Stack trace: ${StackTrace.current}');
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

  /// 强制刷新歌词（用于调试）
  void _forceRefreshLyrics() {
    final currentTrack = PlayerService().currentTrack;
    if (currentTrack != null) {
      print('🔄 [MobilePlayerPage] 强制刷新歌词');
      setState(() {
        _lyrics = [];
        _currentLyricIndex = -1;
      });
      _loadLyrics();
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
                    
                    // 主要内容区域 - 包含专辑封面、歌曲信息和歌词
            Expanded(
          child: Column(
            children: [
                          // 专辑封面和歌曲信息区域 (占 75% 空间)
                          Expanded(
                            flex: 75,
                            child: MobilePlayerSongInfo(showCover: showCover),
                          ),
                          
                          // 歌词区域 (大幅度上移，占 25% 空间)
                          Expanded(
                            flex: 25,
                            child: Transform.translate(
                              offset: const Offset(0, -80), // 向上移动80像素（增加上移幅度）
                          child: Align(
                            alignment: Alignment.center,
                            child: MobilePlayerKaraokeLyric(
                              lyrics: _lyrics,
                              currentLyricIndex: _currentLyricIndex,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const MobileLyricPage(),
                                ),
                              ),
                              showTranslation: _showTranslation && _shouldShowTranslationButton(),
                            ),
                          ),
                ),
              ),
            ],
          ),
                    ),
                    
                    // 底部控制区域 + 左下角译文开关
                    Stack(
                      children: [
                        MobilePlayerControls(
                          onPlaylistPressed: () => MobilePlayerDialogs.showPlaylistBottomSheet(context),
                          onSleepTimerPressed: () => MobilePlayerDialogs.showSleepTimer(context),
                          onVolumeControlPressed: _toggleControlCenter,
                          onAddToPlaylistPressed: (track) => MobilePlayerDialogs.showAddToPlaylist(context, track),
                        ),
                        if (_shouldShowTranslationButton())
                          Positioned(
                          left: 12,
                          bottom: 12,
                          child: Tooltip(
                            message: _showTranslation ? '隐藏译文' : '显示译文',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () {
                                setState(() => _showTranslation = !_showTranslation);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_showTranslation ? '已显示译文' : '已隐藏译文'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: _showTranslation ? Colors.white.withOpacity(0.2) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Center(
                                  child: Text(
                                    '译',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Microsoft YaHei',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
