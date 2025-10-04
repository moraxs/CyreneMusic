import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:palette_generator/palette_generator.dart';
import '../services/player_service.dart';
import '../services/playback_mode_service.dart';
import '../services/play_history_service.dart';
import '../services/favorite_service.dart';
import '../services/playlist_service.dart';
import '../services/playlist_queue_service.dart';
import '../services/download_service.dart';
import '../services/player_background_service.dart';
import '../services/layout_preference_service.dart';
import '../models/lyric_line.dart';
import '../models/track.dart';
import '../models/song_detail.dart';
import '../utils/lyric_parser.dart';
import 'mobile_player_page.dart'; // 移动端播放器页面

/// 全屏播放器页面（根据平台自动选择布局）
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WindowListener, TickerProviderStateMixin {
  final ScrollController _lyricScrollController = ScrollController();
  List<LyricLine> _lyrics = [];
  int _currentLyricIndex = -1;
  bool _isMaximized = false; // 窗口是否最大化
  bool _showPlaylist = false; // 是否显示播放列表
  bool _showTranslation = true; // 是否显示译文
  late AnimationController _playlistAnimationController;
  late Animation<Offset> _playlistSlideAnimation;
  String? _lastTrackId; // 用于检测歌曲切换

  @override
  void initState() {
    super.initState();
    
    // 初始化播放列表动画控制器
    _playlistAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _playlistSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _playlistAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // 监听播放器状态
    PlayerService().addListener(_onPlayerStateChanged);
    
    // 监听布局模式变化（用于在 Windows 平台切换布局时刷新页面）
    if (Platform.isWindows) {
      LayoutPreferenceService().addListener(_onLayoutModeChanged);
    }
    
    // 监听窗口状态（用于检测最大化）
    if (Platform.isWindows) {
      windowManager.addListener(this);
      _checkMaximizedState();
    }
    
    // 延迟执行耗时操作，避免阻塞页面打开动画
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 初始化当前歌曲ID
      final currentTrack = PlayerService().currentTrack;
      _lastTrackId = currentTrack != null 
          ? '${currentTrack.source.name}_${currentTrack.id}' 
          : null;
      _loadLyrics(); // 歌词解析（可能耗时）
    });
  }
  
  /// 检查窗口是否最大化
  Future<void> _checkMaximizedState() async {
    if (Platform.isWindows) {
      final isMaximized = await windowManager.isMaximized();
      if (mounted) {
        setState(() {
          _isMaximized = isMaximized;
        });
      }
    }
  }
  
  @override
  void onWindowMaximize() {
    setState(() {
      _isMaximized = true;
    });
  }

  @override
  void onWindowUnmaximize() {
    setState(() {
      _isMaximized = false;
    });
  }

  @override
  void dispose() {
    _lyricScrollController.dispose();
    _playlistAnimationController.dispose();
    PlayerService().removeListener(_onPlayerStateChanged);
    
    // 移除布局模式监听器
    if (Platform.isWindows) {
      LayoutPreferenceService().removeListener(_onLayoutModeChanged);
    }
    
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }
  
  /// 布局模式变化回调
  void _onLayoutModeChanged() {
    if (!mounted) return;
    setState(() {
      // 触发重建，让 build 方法根据新的布局模式选择合适的页面
      print('🖥️ [PlayerPage] 布局模式已变化，刷新播放器页面');
    });
  }

  void _onPlayerStateChanged() {
    if (mounted) {
      // 检测歌曲是否切换
      final currentTrack = PlayerService().currentTrack;
      final currentTrackId = currentTrack != null 
          ? '${currentTrack.source.name}_${currentTrack.id}' 
          : null;
      
      if (currentTrackId != _lastTrackId) {
        // 歌曲已切换，重新加载歌词
        print('🎵 [PlayerPage] 检测到歌曲切换，重新加载歌词');
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
  }

  /// 切换播放列表显示状态
  void _togglePlaylist() {
    setState(() {
      _showPlaylist = !_showPlaylist;
      if (_showPlaylist) {
        _playlistAnimationController.forward();
      } else {
        _playlistAnimationController.reverse();
      }
    });
  }

  /// 加载歌词（异步执行，不阻塞 UI）
  Future<void> _loadLyrics() async {
    final currentTrack = PlayerService().currentTrack;
    if (currentTrack == null) return;

    print('🔍 [PlayerPage] 开始加载歌词，当前 Track: ${currentTrack.name}');
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
          print('🔍 [PlayerPage] 找到 currentSong: ${song.name}');
          print('   Song ID: ${song.id} (类型: ${song.id.runtimeType})');
          print('   Track ID: ${currentTrack.id} (类型: ${currentTrack.id.runtimeType})');
          print('   ID 匹配: ${songId == trackId}');
        }
        
        // 如果 ID 不匹配，说明 currentSong 还没更新
        if (songId != trackId) {
          if (attemptCount <= 3) {
            print('⚠️ [PlayerPage] ID 不匹配！Song ID: "$songId" vs Track ID: "$trackId"');
          }
          song = null;
          await Future.delayed(const Duration(milliseconds: 100));
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    
    if (song == null) {
      print('❌ [PlayerPage] 等待歌曲详情超时！');
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
      print('📝 [PlayerPage] 开始解析歌词');
      print('   歌曲名: ${songDetail.name}');
      print('   歌曲ID: ${songDetail.id}');
      print('   原始歌词长度: ${songDetail.lyric.length} 字符');
      print('   翻译长度: ${songDetail.tlyric.length} 字符');
      
      // 关键诊断：检查歌词内容
      if (songDetail.lyric.isEmpty) {
        print('   ❌ 错误：PlayerPage 读取到的 currentSong.lyric 为空！');
        print('   这说明 PlayerService.currentSong 中的歌词确实是空的');
      } else {
        print('   ✅ PlayerPage 成功读取到歌词数据');
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
        print('⚠️ [PlayerPage] 歌词解析结果为空，但原始歌词不为空！');
        print('   原始歌词前100字符: ${songDetail.lyric.substring(0, songDetail.lyric.length > 100 ? 100 : songDetail.lyric.length)}');
      }

      print('🎵 [PlayerPage] 加载歌词: ${_lyrics.length} 行 (${songDetail.name})');
      
      // 加载歌词后，更新并滚动到当前位置
      if (_lyrics.isNotEmpty && mounted) {
        setState(() {
          _updateCurrentLyric();
        });
      }
    } catch (e) {
      print('❌ [PlayerPage] 加载歌词失败: $e');
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
      // 固定显示方式，不需要滚动
    }
  }

  /// 判断是否应该显示译文按钮
  /// 只有当歌词非中文且存在翻译时才显示
  bool _shouldShowTranslationButton() {
    if (_lyrics.isEmpty) return false;
    
    // 检查是否有翻译
    final hasTranslation = _lyrics.any((lyric) => 
      lyric.translation != null && lyric.translation!.isNotEmpty
    );
    
    if (!hasTranslation) return false;
    
    // 检查原文是否为中文（检查前几行非空歌词）
    final sampleLyrics = _lyrics
        .where((lyric) => lyric.text.trim().isNotEmpty)
        .take(5)
        .map((lyric) => lyric.text)
        .join('');
    
    if (sampleLyrics.isEmpty) return false;
    
    // 判断是否主要为中文（中文字符占比）
    final chineseCount = sampleLyrics.runes.where((rune) {
      return (rune >= 0x4E00 && rune <= 0x9FFF) || // 基本汉字
             (rune >= 0x3400 && rune <= 0x4DBF) || // 扩展A
             (rune >= 0x20000 && rune <= 0x2A6DF); // 扩展B
    }).length;
    
    final totalCount = sampleLyrics.runes.length;
    final chineseRatio = totalCount > 0 ? chineseCount / totalCount : 0;
    
    // 如果中文字符占比小于30%，认为是非中文歌词
    return chineseRatio < 0.3;
  }

  /// 显示添加到歌单对话框
  void _showAddToPlaylistDialog(Track track) {
    final playlistService = PlaylistService();
    
    // 确保已加载歌单列表
    if (playlistService.playlists.isEmpty) {
      playlistService.loadPlaylists();
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => AnimatedBuilder(
        animation: playlistService,
        builder: (context, child) {
          final playlists = playlistService.playlists;
          
          if (playlists.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text(
                        '添加到歌单',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: playlist.isDefault
                              ? Colors.red.withOpacity(0.2)
                              : Colors.blue.withOpacity(0.2),
                          child: Icon(
                            playlist.isDefault
                                ? Icons.favorite
                                : Icons.queue_music,
                            color: playlist.isDefault ? Colors.red : Colors.blue,
                            size: 20,
                          ),
                        ),
                        title: Text(playlist.name),
                        subtitle: Text('${playlist.trackCount} 首歌曲'),
                        onTap: () async {
                          Navigator.pop(context);
                          final success = await playlistService.addTrackToPlaylist(
                            playlist.id,
                            track,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? '已添加到「${playlist.name}」'
                                      : '添加失败',
                                ),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // 移动平台使用专门的移动端播放器布局
    if (Platform.isAndroid || Platform.isIOS) {
      return const MobilePlayerPage();
    }
    
    // Windows 平台：如果启用了移动布局模式，也使用移动端播放器布局
    if (Platform.isWindows && LayoutPreferenceService().isMobileLayout) {
      return const MobilePlayerPage();
    }
    
    // 桌面平台使用原有的桌面布局
    final player = PlayerService();
    final song = player.currentSong;
    final track = player.currentTrack;

    if (song == null && track == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Text(
            '暂无播放内容',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ClipRRect(
        borderRadius: _isMaximized 
            ? BorderRadius.zero  // 最大化时无圆角
            : BorderRadius.circular(16), // 正常时圆角窗口
        child: AnimatedBuilder(
          animation: PlayerBackgroundService(),
          builder: (context, child) {
            return Stack(
              children: [
                // 背景层（根据设置显示不同背景）
                _buildGradientBackground(),
                
                // 主要内容区域
                child!,
              ],
            );
          },
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    // 可拖动的顶部区域
                    _buildDraggableTopBar(context),
                    
                    // 左右分栏内容区域（静态部分）
                    Expanded(
                      child: Row(
                        children: [
                          // 左侧：歌曲信息（静态，不随进度更新）
                          Expanded(
                            flex: 5,
                            child: _buildLeftPanel(song, track),
                          ),
                          
                          // 右侧：歌词（使用独立监听）
                          Expanded(
                            flex: 4,
                            child: _buildRightPanel(),
                          ),
                        ],
                      ),
                    ),
                    
                    // 底部进度条和控制按钮（使用 AnimatedBuilder 监听播放进度）
                    AnimatedBuilder(
                      animation: PlayerService(),
                      builder: (context, child) {
                        return _buildBottomControls(PlayerService());
                      },
                    ),
                  ],
                ),
              ),

              // 播放列表侧板背景遮罩
              if (_showPlaylist)
                GestureDetector(
                  onTap: _togglePlaylist,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ),
                ),
              
              // 播放列表内容
              SlideTransition(
                position: _playlistSlideAnimation,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildPlaylistPanel(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建可拖动的顶部栏
  Widget _buildDraggableTopBar(BuildContext context) {
    // Windows 平台使用可拖动区域
    if (Platform.isWindows) {
      return SizedBox(
        height: 56,
        child: Stack(
          children: [
            // 可拖动区域（整个顶部）
            Positioned.fill(
              child: MoveWindow(
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
            // 左侧：返回按钮
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, size: 32),
                  color: Colors.white,
                  onPressed: () => Navigator.pop(context),
                  tooltip: '返回',
                ),
              ),
            ),
            // 右侧：窗口控制按钮
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: _buildWindowButtons(),
            ),
          ],
        ),
      );
    } else {
      // 其他平台使用普通容器
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: 32),
              color: Colors.white,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }
  
  /// 构建窗口控制按钮（最小化、最大化、关闭）
  Widget _buildWindowButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildWindowButton(
          icon: Icons.remove,
          onPressed: () => appWindow.minimize(),
          tooltip: '最小化',
        ),
        _buildWindowButton(
          icon: _isMaximized ? Icons.fullscreen_exit : Icons.crop_square,
          onPressed: () => appWindow.maximizeOrRestore(),
          tooltip: _isMaximized ? '还原' : '最大化',
        ),
        _buildWindowButton(
          icon: Icons.close_rounded,
          onPressed: () => windowManager.close(),
          tooltip: '关闭',
          isClose: true,
        ),
      ],
    );
  }
  
  /// 构建单个窗口按钮
  Widget _buildWindowButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    bool isClose = false,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          hoverColor: isClose ? Colors.red : Colors.white.withOpacity(0.1),
          child: Container(
            width: 48,
            height: 56,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建渐变背景（根据设置选择背景类型）
  Widget _buildGradientBackground() {
    final backgroundService = PlayerBackgroundService();
    final greyColor = Colors.grey[900] ?? const Color(0xFF212121);
    
    switch (backgroundService.backgroundType) {
      case PlayerBackgroundType.adaptive:
        // 自适应背景（默认行为）- 使用主题色渐变
        return ValueListenableBuilder<Color?>(
          valueListenable: PlayerService().themeColorNotifier,
          builder: (context, themeColor, child) {
            final color = themeColor ?? Colors.deepPurple;
            print('🎨 [PlayerPage] 构建背景，主题色: $color');
            
            return RepaintBoundary(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500), // 主题色变化时平滑过渡
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color,        // 主题色（不透明）
                      greyColor,    // 灰色（不透明）
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            );
          },
        );
        
      case PlayerBackgroundType.solidColor:
        // 纯色背景（添加到灰色的渐变）
        return RepaintBoundary(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  backgroundService.solidColor,
                  greyColor,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        );
        
      case PlayerBackgroundType.image:
        // 图片背景
        if (backgroundService.imagePath != null) {
          final imageFile = File(backgroundService.imagePath!);
          if (imageFile.existsSync()) {
            return Stack(
              children: [
                // 图片层
                Positioned.fill(
                  child: Image.file(
                    imageFile,
                    fit: BoxFit.cover, // 保持原比例裁剪
                  ),
                ),
                // 模糊层
                if (backgroundService.blurAmount > 0)
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: backgroundService.blurAmount,
                        sigmaY: backgroundService.blurAmount,
                      ),
                      child: Container(
                        color: Colors.black.withOpacity(0.3), // 添加半透明遮罩
                      ),
                    ),
                  )
                else
                  // 无模糊时也添加浅色遮罩以确保文字可读
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.2),
                    ),
                  ),
              ],
            );
          }
        }
        // 如果没有设置图片，使用默认背景
        return RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  greyColor,
                  Colors.black,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        );
    }
  }

  /// 构建左侧面板（歌曲信息）
  Widget _buildLeftPanel(dynamic song, dynamic track) {
    final imageUrl = song?.pic ?? track?.picUrl ?? '';
    
    return RepaintBoundary(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              
              // 封面
              _buildCover(imageUrl),
              const SizedBox(height: 40),
              
              // 歌曲信息
              _buildSongInfo(song, track),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建右侧面板（歌词）
  Widget _buildRightPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: _lyrics.isEmpty
          ? _buildNoLyric()
          : _buildLyricList(),
    );
  }

  /// 构建封面
  Widget _buildCover(String imageUrl) {
    return Container(
      width: 320,
      height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 40,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[800],
                  child: const Center(
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.music_note, size: 100, color: Colors.white54),
                ),
              )
            : Container(
                color: Colors.grey[800],
                child: const Icon(Icons.music_note, size: 100, color: Colors.white54),
              ),
      ),
    );
  }

  /// 构建歌曲信息
  Widget _buildSongInfo(dynamic song, dynamic track) {
    final name = song?.name ?? track?.name ?? '未知歌曲';
    final artist = song?.arName ?? track?.artists ?? '未知艺术家';
    final album = song?.alName ?? track?.album ?? '';

    return Column(
      children: [
        // 歌曲名称
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        
        // 艺术家
        Text(
          artist,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        
        // 专辑
        if (album.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            album,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  /// 构建无歌词提示
  Widget _buildNoLyric() {
    return Center(
      child: Text(
        '暂无歌词',
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 16,
        ),
      ),
    );
  }

  /// 构建歌词列表（固定显示8行，当前歌词在第4行，丝滑滚动）
  Widget _buildLyricList() {
    // 使用 RepaintBoundary 隔离歌词区域的重绘
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
        const int totalVisibleLines = 8; // 总共显示8行
        const int currentLinePosition = 3; // 当前歌词在第4行（索引3）
        
        // 根据容器高度计算每行的实际高度
        final itemHeight = constraints.maxHeight / totalVisibleLines;
        
        // 计算显示范围
        int startIndex = _currentLyricIndex - currentLinePosition;
        
        // 生成要显示的歌词列表
        List<Widget> lyricWidgets = [];
        
        for (int i = 0; i < totalVisibleLines; i++) {
          int lyricIndex = startIndex + i;
          
          // 判断是否在有效范围内
          if (lyricIndex < 0 || lyricIndex >= _lyrics.length) {
            // 空行占位
            lyricWidgets.add(
              SizedBox(
                height: itemHeight,
                key: ValueKey('empty_$i'),
              ),
            );
          } else {
            // 显示歌词
            final lyric = _lyrics[lyricIndex];
            final isCurrent = lyricIndex == _currentLyricIndex;
            
            lyricWidgets.add(
              SizedBox(
                height: itemHeight,
                key: ValueKey('lyric_$lyricIndex'),
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      color: isCurrent ? Colors.white : Colors.white.withOpacity(0.45),
                      fontSize: isCurrent ? 18 : 15,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      height: 1.4,
                      fontFamily: 'Microsoft YaHei', // 使用微软雅黑字体
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 原文歌词
                          Text(
                            lyric.text,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // 翻译歌词（根据开关显示）
                          if (_showTranslation && lyric.translation != null && lyric.translation!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                lyric.translation!,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isCurrent
                                      ? Colors.white.withOpacity(0.75)
                                      : Colors.white.withOpacity(0.35),
                                  fontSize: isCurrent ? 13 : 12,
                                  fontFamily: 'Microsoft YaHei', // 使用微软雅黑字体
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        }
        
        // 使用 AnimatedSwitcher 实现丝滑滚动效果
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
            // 只显示当前的 child，不显示之前的 child
            return Stack(
              alignment: Alignment.center,
              children: <Widget>[
                if (currentChild != null) currentChild,
              ],
            );
          },
          transitionBuilder: (Widget child, Animation<double> animation) {
            // 向上滑动的过渡效果（无淡入淡出）
            final offsetAnimation = Tween<Offset>(
              begin: const Offset(0.0, 0.1), // 从下方10%处开始
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));
            
            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
          child: Column(
            key: ValueKey(_currentLyricIndex), // 关键：当索引变化时触发动画
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: lyricWidgets,
          ),
        );
        },
      ),
    );
  }

  /// 构建底部控制区域（进度条和控制按钮）
  Widget _buildBottomControls(PlayerService player) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withOpacity(0.3),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withOpacity(0.2),
            ),
            child: Slider(
              value: player.duration.inMilliseconds > 0
                  ? player.position.inMilliseconds / player.duration.inMilliseconds
                  : 0.0,
              onChanged: (value) {
                final position = Duration(
                  milliseconds: (value * player.duration.inMilliseconds).round(),
                );
                player.seek(position);
              },
            ),
          ),
          
          // 时间显示
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(player.position),
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                ),
                Text(
                  _formatDuration(player.duration),
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 控制按钮
          _buildControls(player),
        ],
      ),
    );
  }

  /// 构建控制按钮
  Widget _buildControls(PlayerService player) {
    final currentTrack = player.currentTrack;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 译文显示开关（只在非中文歌词且有翻译时显示）
        if (_shouldShowTranslationButton()) ...[
          IconButton(
            icon: Container(
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
            onPressed: () {
              setState(() {
                _showTranslation = !_showTranslation;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_showTranslation ? '已显示译文' : '已隐藏译文'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            tooltip: _showTranslation ? '隐藏译文' : '显示译文',
          ),
          const SizedBox(width: 20),
        ],
        
        // 播放模式切换
        AnimatedBuilder(
          animation: PlaybackModeService(),
          builder: (context, child) {
            final mode = PlaybackModeService().currentMode;
            IconData icon;
            switch (mode) {
              case PlaybackMode.sequential:
                icon = Icons.repeat_rounded;
                break;
              case PlaybackMode.repeatOne:
                icon = Icons.repeat_one_rounded;
                break;
              case PlaybackMode.shuffle:
                icon = Icons.shuffle_rounded;
                break;
            }
            
            return IconButton(
              icon: Icon(icon, color: Colors.white),
              iconSize: 30,
              onPressed: () {
                PlaybackModeService().toggleMode();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('播放模式: ${PlaybackModeService().getModeName()}'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              tooltip: PlaybackModeService().getModeName(),
            );
          },
        ),
        
        const SizedBox(width: 20),
        
        // 上一曲
        IconButton(
          icon: Icon(
            Icons.skip_previous_rounded,
            color: player.hasPrevious ? Colors.white : Colors.white38,
          ),
          iconSize: 42,
          onPressed: player.hasPrevious ? player.playPrevious : null,
          tooltip: '上一首',
        ),
        
        const SizedBox(width: 20),
        
        // 添加到歌单按钮
        if (currentTrack != null)
          IconButton(
            icon: const Icon(
              Icons.playlist_add_rounded,
              color: Colors.white,
            ),
            iconSize: 30,
            onPressed: () => _showAddToPlaylistDialog(currentTrack),
            tooltip: '添加到歌单',
          ),
        
        const SizedBox(width: 20),
        
        // 播放/暂停
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: player.isLoading
              ? const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              : IconButton(
                  icon: Icon(
                    player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.black87,
                  ),
                  iconSize: 40,
                  onPressed: player.togglePlayPause,
                ),
        ),
        
        const SizedBox(width: 20),
        
        // 下一曲
        IconButton(
          icon: Icon(
            Icons.skip_next_rounded,
            color: player.hasNext ? Colors.white : Colors.white38,
          ),
          iconSize: 42,
          onPressed: player.hasNext ? player.playNext : null,
          tooltip: '下一首',
        ),
        
        const SizedBox(width: 20),
        
        // 下载按钮
        if (currentTrack != null && player.currentSong != null)
          AnimatedBuilder(
            animation: DownloadService(),
            builder: (context, child) {
              final downloadService = DownloadService();
              final isDownloading = downloadService.downloadTasks.containsKey(
                '${currentTrack.source.name}_${currentTrack.id}'
              );
              
              return IconButton(
                icon: Icon(
                  isDownloading ? Icons.downloading_rounded : Icons.download_rounded,
                  color: Colors.white,
                ),
                iconSize: 30,
                onPressed: isDownloading ? null : () => _handleDownload(player),
                tooltip: isDownloading ? '下载中...' : '下载',
              );
            },
          ),
        
        const SizedBox(width: 20),
        
        // 播放列表按钮
        IconButton(
          icon: const Icon(Icons.queue_music_rounded, color: Colors.white),
          iconSize: 30,
          onPressed: _togglePlaylist,
          tooltip: '播放列表',
        ),
      ],
    );
  }

  /// 处理下载
  Future<void> _handleDownload(PlayerService player) async {
    final currentTrack = player.currentTrack;
    final currentSong = player.currentSong;
    
    if (currentTrack == null || currentSong == null) {
      return;
    }

    try {
      // 检查是否已下载
      final isDownloaded = await DownloadService().isDownloaded(currentTrack);
      
      if (isDownloaded) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('该歌曲已下载'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // 显示下载确认
      if (mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('下载歌曲'),
            content: Text('确定要下载《${currentTrack.name}》吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('下载'),
              ),
            ],
          ),
        );

        if (confirm != true) return;
      }

      // 开始下载
      final success = await DownloadService().downloadSong(
        currentTrack,
        currentSong,
        onProgress: (progress) {
          // 下载进度会通过 DownloadService 的 notifyListeners 自动更新UI
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '下载成功！' : '下载失败'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ [PlayerPage] 下载失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 格式化时长
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 构建播放列表面板
  Widget _buildPlaylistPanel() {
    final queueService = PlaylistQueueService();
    final history = PlayHistoryService().history;
    final currentTrack = PlayerService().currentTrack;
    
    // 优先使用播放队列，如果没有队列则使用播放历史
    final bool hasQueue = queueService.hasQueue;
    final List<dynamic> displayList = hasQueue 
        ? queueService.queue 
        : history.map((h) => h.toTrack()).toList();
    final String listTitle = hasQueue 
        ? '播放队列 (${queueService.source.name})' 
        : '播放历史';

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        bottomLeft: Radius.circular(16),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: 400,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(-5, 0),
              ),
            ],
          ),
          child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(
                  Icons.queue_music,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  listTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${displayList.length} 首',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: _togglePlaylist,
                  tooltip: '关闭',
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white24, height: 1),

          // 播放列表
          Expanded(
            child: displayList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.music_off,
                          size: 64,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '播放列表为空',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: displayList.length,
                    itemBuilder: (context, index) {
                      final item = displayList[index];
                      // 转换为 Track（如果是 Track 就直接用，如果是 PlayHistoryItem 就调用 toTrack）
                      final track = item is Track ? item : (item as PlayHistoryItem).toTrack();
                      final isCurrentTrack = currentTrack != null &&
                          track.id.toString() == currentTrack.id.toString() &&
                          track.source == currentTrack.source;

                      return _buildPlaylistItemFromTrack(track, index, isCurrentTrack);
                    },
                  ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  /// 构建播放列表项（从 Track）
  Widget _buildPlaylistItemFromTrack(Track track, int index, bool isCurrentTrack) {
    return Material(
      color: isCurrentTrack 
          ? Colors.white.withOpacity(0.1) 
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          PlayerService().playTrack(track);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('正在播放: ${track.name}'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // 序号或正在播放图标
              SizedBox(
                width: 40,
                child: isCurrentTrack
                    ? const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 20,
                      )
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),

              // 封面
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: track.picUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 50,
                    height: 50,
                    color: Colors.white12,
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 50,
                    height: 50,
                    color: Colors.white12,
                    child: const Icon(
                      Icons.music_note,
                      color: Colors.white38,
                      size: 24,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // 歌曲信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCurrentTrack ? Colors.white : Colors.white.withOpacity(0.9),
                        fontSize: 15,
                        fontWeight: isCurrentTrack ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.artists,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // 音乐平台图标
              Text(
                _getSourceIcon(track.source),
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 获取音乐平台图标
  String _getSourceIcon(source) {
    switch (source.toString()) {
      case 'MusicSource.netease':
        return '🎵';
      case 'MusicSource.qq':
        return '🎶';
      case 'MusicSource.kugou':
        return '🎼';
      default:
        return '🎵';
    }
  }
}

