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
import '../services/playlist_queue_service.dart';
import '../services/download_service.dart';
import '../models/lyric_line.dart';
import '../models/track.dart';
import '../models/song_detail.dart';
import '../utils/lyric_parser.dart';

/// 全屏播放器页面
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
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    super.dispose();
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

    // 等待 currentSong 更新（最多等待3秒）
    SongDetail? song;
    final startTime = DateTime.now();
    
    while (song == null && DateTime.now().difference(startTime).inSeconds < 3) {
      song = PlayerService().currentSong;
      
      // 验证 currentSong 是否匹配 currentTrack
      if (song != null) {
        final songId = song.id.toString();
        final trackId = currentTrack.id.toString();
        
        // 如果 ID 不匹配，说明 currentSong 还没更新
        if (songId != trackId) {
          song = null;
          await Future.delayed(const Duration(milliseconds: 100));
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    
    if (song == null) {
      print('⚠️ [PlayerPage] 等待歌曲详情超时');
      return;
    }

    // 使用本地变量确保非空
    final songDetail = song;

    try {
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

      print('🎵 [PlayerPage] 加载歌词: ${_lyrics.length} 行 (${songDetail.name})');
      
      // 加载歌词后，更新并滚动到当前位置
      if (_lyrics.isNotEmpty && mounted) {
        setState(() {
          _updateCurrentLyric();
        });
      }
    } catch (e) {
      print('❌ [PlayerPage] 加载歌词失败: $e');
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


  @override
  Widget build(BuildContext context) {
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
        child: Stack(
          children: [
            // 背景（主题色渐变）- 使用 ValueListenableBuilder 精确监听主题色变化
            _buildGradientBackground(),

            // 主要内容区域
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

  /// 构建渐变背景（主题色到灰色）
  Widget _buildGradientBackground() {
    final greyColor = Colors.grey[900] ?? const Color(0xFF212121);
    
    // 使用 ValueListenableBuilder 精确监听主题色变化，不受播放进度影响
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
                          // 翻译歌词
                          if (lyric.translation != null && lyric.translation!.isNotEmpty)
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
        
        // 收藏按钮
        if (currentTrack != null)
          AnimatedBuilder(
            animation: FavoriteService(),
            builder: (context, child) {
              final isFavorite = FavoriteService().isFavorite(currentTrack);
              return IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFavorite ? Colors.redAccent : Colors.white,
                ),
                iconSize: 30,
                onPressed: () async {
                  final success = await FavoriteService().toggleFavorite(currentTrack);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isFavorite ? '已取消收藏' : '已添加到收藏',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
                tooltip: isFavorite ? '取消收藏' : '收藏',
              );
            },
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

