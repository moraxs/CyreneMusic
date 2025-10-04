import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../services/player_service.dart';
import '../services/playback_mode_service.dart';
import '../services/download_service.dart';
import '../services/playlist_service.dart';
import '../services/playlist_queue_service.dart';
import '../services/play_history_service.dart';
import '../services/player_background_service.dart';
import '../services/sleep_timer_service.dart';
import '../models/lyric_line.dart';
import '../models/track.dart';
import '../models/song_detail.dart';
import '../utils/lyric_parser.dart';
import 'mobile_lyric_page.dart';

/// 移动端播放器页面（适用于 Android/iOS）
class MobilePlayerPage extends StatefulWidget {
  const MobilePlayerPage({super.key});

  @override
  State<MobilePlayerPage> createState() => _MobilePlayerPageState();
}

class _MobilePlayerPageState extends State<MobilePlayerPage> {
  List<LyricLine> _lyrics = [];
  int _currentLyricIndex = -1;
  String? _lastTrackId;

  @override
  void initState() {
    super.initState();
    
    // 监听播放器状态
    PlayerService().addListener(_onPlayerStateChanged);
    
    // 延迟加载歌词
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentTrack = PlayerService().currentTrack;
      _lastTrackId = currentTrack != null 
          ? '${currentTrack.source.name}_${currentTrack.id}' 
          : null;
      _loadLyrics();
    });
  }

  @override
  void dispose() {
    PlayerService().removeListener(_onPlayerStateChanged);
    super.dispose();
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

    // Windows 平台：添加圆角边框包裹
    final scaffoldWidget = Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: PlayerBackgroundService(),
        builder: (context, child) {
          return Stack(
            children: [
              // 背景层
              _buildBackground(song, track),
              
              // 内容层
              child!,
            ],
          );
        },
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 根据屏幕高度动态分配空间
              final screenHeight = constraints.maxHeight;
              
              return Column(
                children: [
                  // 顶部栏（Windows 平台显示窗口控制按钮，移动平台显示返回按钮）
                  _buildAppBar(context),
                  
                  // 歌曲信息区域 - 使用 Expanded 让它占据剩余空间
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          SizedBox(height: screenHeight * 0.015),
                          
                          // 封面
                          _buildAlbumCover(song, track),
                          
                          SizedBox(height: screenHeight * 0.02),
                          
                          // 歌曲名称和歌手
                          _buildSongInfo(song, track),
                          
                          SizedBox(height: screenHeight * 0.015),
                          
                          // 当前歌词（单行，可点击）
                          _buildCurrentLyric(),
                          
                          SizedBox(height: screenHeight * 0.02),
                        ],
                      ),
                    ),
                  ),
                  
                  // 底部控制区域 - 让它自动调整大小
                  _buildControlArea(),
                ],
              );
            },
          ),
        ),
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

  /// 构建背景
  Widget _buildBackground(SongDetail? song, Track? track) {
    final backgroundService = PlayerBackgroundService();
    
    switch (backgroundService.backgroundType) {
      case PlayerBackgroundType.adaptive:
        // 自适应背景（默认行为）
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                Colors.black,
                Colors.black,
              ],
            ),
          ),
        );
        
      case PlayerBackgroundType.solidColor:
        // 纯色背景（添加到灰色的渐变）
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                backgroundService.solidColor,
                Colors.grey[900]!,
                Colors.black,
              ],
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
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.grey[900]!,
                Colors.black,
                Colors.black,
              ],
            ),
          ),
        );
    }
  }

  /// 构建顶部应用栏
  Widget _buildAppBar(BuildContext context) {
    // Windows 平台：显示窗口控制按钮和拖动区域
    if (Platform.isWindows) {
      return Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
        ),
        child: Row(
          children: [
            // 左侧：返回按钮
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              iconSize: 24,
              onPressed: () => Navigator.pop(context),
              tooltip: '返回',
            ),
            
            // 中间：可拖动区域
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (details) {
                  appWindow.startDragging();
                },
                child: const Center(
                  child: Text(
                    '正在播放',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            
            // 右侧：窗口控制按钮
            _buildWindowButton(
              icon: Icons.remove,
              tooltip: '最小化',
              onPressed: () => appWindow.minimize(),
            ),
            _buildWindowButton(
              icon: Icons.crop_square,
              tooltip: '最大化（已禁用）',
              onPressed: null, // 禁用最大化
              isDisabled: true,
            ),
            _buildWindowButton(
              icon: Icons.close,
              tooltip: '关闭',
              onPressed: () => appWindow.close(),
              isClose: true,
            ),
          ],
        ),
      );
    }
    
    // 移动平台：显示普通返回按钮
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            iconSize: 32,
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            '正在播放',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // TODO: 显示更多选项
            },
          ),
        ],
      ),
    );
  }
  
  /// 构建窗口控制按钮（Windows 专用）
  Widget _buildWindowButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool isClose = false,
    bool isDisabled = false,
  }) {
    return SizedBox(
      width: 46,
      height: 40,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            hoverColor: isClose 
                ? Colors.red.withOpacity(0.8)
                : isDisabled
                    ? Colors.transparent
                    : Colors.white.withOpacity(0.1),
            child: Center(
              child: Icon(
                icon,
                size: 18,
                color: isDisabled 
                    ? Colors.white.withOpacity(0.3)
                    : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建专辑封面
  Widget _buildAlbumCover(SongDetail? song, Track? track) {
    final picUrl = song?.pic ?? track?.picUrl ?? '';
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据屏幕宽度自适应调整封面大小
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        
        // 动态计算边距：屏幕宽度的 12%
        final horizontalMargin = screenWidth * 0.12;
        
        // 优化封面大小计算：限制为屏幕高度的 28% 或宽度的 65%（取较小值）
        final maxCoverByHeight = screenHeight * 0.28;
        final maxCoverByWidth = screenWidth * 0.65;
        final maxCoverSize = maxCoverByHeight < maxCoverByWidth ? maxCoverByHeight : maxCoverByWidth;
        
        // 计算封面大小，确保 min 不大于 max
        final calculatedSize = screenWidth - horizontalMargin * 2;
        final minCoverSize = 180.0;
        final baseCoverSize = calculatedSize.clamp(minCoverSize, maxCoverSize > minCoverSize ? maxCoverSize : calculatedSize);
        
        // 缩小到原大小的 80%
        final coverSize = baseCoverSize * 0.8;
        
        return Hero(
          tag: 'album_cover',
          child: Center(
            child: Container(
              width: coverSize,
              height: coverSize,
              margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: picUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: picUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[900],
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white30,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[900],
                          child: Icon(
                            Icons.music_note,
                            size: coverSize * 0.3,
                            color: Colors.white30,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[900],
                        child: Icon(
                          Icons.music_note,
                          size: coverSize * 0.3,
                          color: Colors.white30,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建歌曲信息
  Widget _buildSongInfo(SongDetail? song, Track? track) {
    final name = song?.name ?? track?.name ?? '未知歌曲';
    final artists = song?.arName ?? track?.artists ?? '未知艺术家';
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final titleFontSize = (screenWidth * 0.055).clamp(20.0, 26.0);
        final artistFontSize = (screenWidth * 0.04).clamp(14.0, 17.0);
        
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
          child: Column(
            children: [
              Text(
                name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: screenWidth * 0.015),
              Text(
                artists,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: artistFontSize,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建当前歌词（单行，可点击）
  Widget _buildCurrentLyric() {
    String lyricText = '暂无歌词';
    
    if (_lyrics.isNotEmpty && _currentLyricIndex >= 0 && _currentLyricIndex < _lyrics.length) {
      lyricText = _lyrics[_currentLyricIndex].text;
      if (lyricText.trim().isEmpty) {
        lyricText = '♪';
      }
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final lyricFontSize = (screenWidth * 0.038).clamp(14.0, 16.0);
        
        return GestureDetector(
          onTap: () {
            // 跳转到全屏滚动歌词页面
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MobileLyricPage(),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    lyricText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: lyricFontSize,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Microsoft YaHei',
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_right,
                  color: Colors.white.withOpacity(0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建底部控制区域
  Widget _buildControlArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据屏幕宽度自适应调整边距
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final horizontalPadding = (screenWidth * 0.05).clamp(16.0, 24.0);
        final verticalPadding = (screenHeight * 0.015).clamp(12.0, 16.0);
        final itemSpacing = (screenHeight * 0.015).clamp(12.0, 20.0);
        
        return Container(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 进度条
              _buildProgressBar(),
              
              SizedBox(height: itemSpacing),
              
              // 第一行：播放模式、上一首、播放/暂停、下一首、播放列表
              _buildMainControlRow(),
              
              SizedBox(height: itemSpacing * 0.8),
              
              // 第二行：收藏、下载、评论、添加到歌单
              _buildSecondaryControlRow(),
            ],
          ),
        );
      },
    );
  }

  /// 构建进度条
  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: PlayerService(),
      builder: (context, child) {
        final player = PlayerService();
        final position = player.position;
        final duration = player.duration;
        
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withOpacity(0.3),
                thumbColor: Colors.white,
                overlayColor: Colors.white.withOpacity(0.2),
              ),
              child: Slider(
                value: duration.inMilliseconds > 0
                    ? position.inMilliseconds.toDouble()
                    : 0,
                max: duration.inMilliseconds.toDouble(),
                onChanged: (value) {
                  player.seek(Duration(milliseconds: value.toInt()));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// 构建主控制按钮行（第一行）
  Widget _buildMainControlRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据可用宽度自适应按钮大小和间距
        final availableWidth = constraints.maxWidth;
        final buttonSpacing = (availableWidth * 0.02).clamp(8.0, 16.0);
        final sideIconSize = (availableWidth * 0.065).clamp(24.0, 32.0);
        final skipIconSize = (availableWidth * 0.09).clamp(36.0, 48.0);
        final playButtonSize = (availableWidth * 0.15).clamp(56.0, 72.0);
        final playIconSize = (availableWidth * 0.08).clamp(32.0, 40.0);
        
        return AnimatedBuilder(
          animation: PlayerService(),
          builder: (context, child) {
            final player = PlayerService();
            
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 播放模式
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
                      iconSize: sideIconSize,
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
                
                SizedBox(width: buttonSpacing),
                
                // 上一首
                IconButton(
                  icon: Icon(
                    Icons.skip_previous_rounded,
                    color: player.hasPrevious ? Colors.white : Colors.white38,
                  ),
                  iconSize: skipIconSize,
                  onPressed: player.hasPrevious ? () => player.playPrevious() : null,
                  tooltip: '上一首',
                ),
                
                SizedBox(width: buttonSpacing),
                
                // 播放/暂停
                Container(
                  width: playButtonSize,
                  height: playButtonSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: player.isLoading
                      ? Padding(
                          padding: EdgeInsets.all(playButtonSize * 0.28),
                          child: const CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.black87,
                          ),
                        )
                      : IconButton(
                          icon: Icon(
                            player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.black87,
                          ),
                          iconSize: playIconSize,
                          onPressed: () => player.togglePlayPause(),
                          tooltip: player.isPlaying ? '暂停' : '播放',
                        ),
                ),
                
                SizedBox(width: buttonSpacing),
                
                // 下一首
                IconButton(
                  icon: Icon(
                    Icons.skip_next_rounded,
                    color: player.hasNext ? Colors.white : Colors.white38,
                  ),
                  iconSize: skipIconSize,
                  onPressed: player.hasNext ? () => player.playNext() : null,
                  tooltip: '下一首',
                ),
                
                SizedBox(width: buttonSpacing),
                
                // 播放列表
                IconButton(
                  icon: const Icon(Icons.queue_music_rounded, color: Colors.white),
                  iconSize: sideIconSize,
                  onPressed: _showPlaylistBottomSheet,
                  tooltip: '播放列表',
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 构建次要控制按钮行（第二行）
  Widget _buildSecondaryControlRow() {
    final player = PlayerService();
    final track = player.currentTrack;
    final song = player.currentSong;
    
    if (track == null) {
      return const SizedBox.shrink();
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 添加到歌单
        IconButton(
          icon: const Icon(Icons.playlist_add_rounded, color: Colors.white),
          iconSize: 28,
          onPressed: () => _showAddToPlaylistDialog(track),
          tooltip: '添加到歌单',
        ),
        
        const SizedBox(width: 32),
        
        // 睡眠定时器
        AnimatedBuilder(
          animation: SleepTimerService(),
          builder: (context, child) {
            final timer = SleepTimerService();
            final isActive = timer.isActive;
            
            return IconButton(
              icon: Icon(
                isActive ? Icons.bedtime : Icons.bedtime_outlined,
                color: isActive ? Colors.amber : Colors.white,
              ),
              iconSize: 28,
              onPressed: () => _showSleepTimerDialog(context),
              tooltip: isActive ? '定时停止: ${timer.remainingTimeString}' : '睡眠定时器',
            );
          },
        ),
        
        const SizedBox(width: 32),
        
        // 下载
        if (song != null)
          AnimatedBuilder(
            animation: DownloadService(),
            builder: (context, child) {
              final downloadService = DownloadService();
              final trackId = '${track.source.name}_${track.id}';
              final isDownloading = downloadService.downloadTasks.containsKey(trackId);
              
              return IconButton(
                icon: Icon(
                  isDownloading ? Icons.downloading_rounded : Icons.download_rounded,
                  color: Colors.white,
                ),
                iconSize: 28,
                onPressed: isDownloading ? null : () async {
                  try {
                    // 检查是否已下载
                    final isDownloaded = await DownloadService().isDownloaded(track);
                    
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
                    
                    // 开始下载
                    final success = await DownloadService().downloadSong(track, song);
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? '开始下载' : '下载失败'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('下载失败: $e'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
                tooltip: isDownloading ? '下载中...' : '下载',
              );
            },
          ),
      ],
    );
  }

  /// 显示睡眠定时器对话框
  void _showSleepTimerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _SleepTimerDialog(),
    );
  }

  /// 格式化时长
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
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
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AnimatedBuilder(
        animation: playlistService,
        builder: (context, child) {
          final playlists = playlistService.playlists;
          
          if (playlists.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
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
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24),
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
                        title: Text(
                          playlist.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '${playlist.trackCount} 首歌曲',
                          style: const TextStyle(color: Colors.white70),
                        ),
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

  /// 显示播放列表底部抽屉
  void _showPlaylistBottomSheet() {
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

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 拖动指示器
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
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
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${displayList.length} 首',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          tooltip: '关闭',
                        ),
                      ],
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
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: displayList.length,
                        itemBuilder: (context, index) {
                          final item = displayList[index];
                          // 转换为 Track
                          final track = item is Track ? item : (item as PlayHistoryItem).toTrack();
                          final isCurrentTrack = currentTrack != null &&
                              track.id.toString() == currentTrack.id.toString() &&
                              track.source == currentTrack.source;

                          return _buildPlaylistItem(track, index, isCurrentTrack);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 构建播放列表项
  Widget _buildPlaylistItem(Track track, int index, bool isCurrentTrack) {
    return Material(
      color: isCurrentTrack 
          ? Colors.white.withOpacity(0.1) 
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          PlayerService().playTrack(track);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('正在播放: ${track.name}'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // 序号或正在播放图标
              SizedBox(
                width: 32,
                child: isCurrentTrack
                    ? const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 20,
                      )
                    : Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),

              const SizedBox(width: 8),

              // 封面
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: track.picUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 48,
                    height: 48,
                    color: Colors.white12,
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 48,
                    height: 48,
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
                        color: isCurrentTrack ? Colors.white : Colors.white.withOpacity(0.87),
                        fontSize: 15,
                        fontWeight: isCurrentTrack ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artists,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 睡眠定时器对话框（移动端版本）
class _SleepTimerDialog extends StatefulWidget {
  @override
  State<_SleepTimerDialog> createState() => _SleepTimerDialogState();
}

class _SleepTimerDialogState extends State<_SleepTimerDialog> {
  int _selectedTabIndex = 0; // 0: 时长, 1: 时间
  int _selectedDuration = 30; // 默认30分钟

  // 预设时长选项（分钟）
  final List<int> _durationOptions = [15, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final timer = SleepTimerService();

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('睡眠定时器'),
          if (timer.isActive)
            TextButton.icon(
              onPressed: () {
                timer.cancel();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('定时器已取消')),
                );
              },
              icon: const Icon(Icons.cancel),
              label: const Text('取消定时'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 当前定时器状态
            if (timer.isActive)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bedtime,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '定时器运行中',
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedBuilder(
                            animation: timer,
                            builder: (context, child) {
                              return Text(
                                '剩余时间: ${timer.remainingTimeString}',
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    if (timer.isActive)
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          timer.extend(15);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已延长15分钟')),
                          );
                        },
                        tooltip: '延长15分钟',
                        color: colorScheme.onPrimaryContainer,
                      ),
                  ],
                ),
              ),

            // 标签选择器
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('播放时长'),
                  icon: Icon(Icons.timer_outlined),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('指定时间'),
                  icon: Icon(Icons.schedule),
                ),
              ],
              selected: {_selectedTabIndex},
              onSelectionChanged: (Set<int> selected) {
                setState(() {
                  _selectedTabIndex = selected.first;
                });
              },
            ),

            const SizedBox(height: 24),

            // 内容区域
            if (_selectedTabIndex == 0) _buildDurationTab(colorScheme),
            if (_selectedTabIndex == 1) _buildTimeTab(context, colorScheme),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }

  /// 时长选择标签页
  Widget _buildDurationTab(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择播放时长',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _durationOptions.map((duration) {
            final isSelected = duration == _selectedDuration;
            return FilterChip(
              label: Text('${duration}分钟'),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedDuration = duration;
                  });
                  SleepTimerService().setTimerByDuration(duration);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('定时器已设置: ${duration}分钟后停止播放'),
                    ),
                  );
                }
              },
              showCheckmark: false,
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 时间选择标签页
  Widget _buildTimeTab(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择停止时间',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              final TimeOfDay? selectedTime = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
                builder: (context, child) {
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      alwaysUse24HourFormat: true,
                    ),
                    child: child!,
                  );
                },
              );

              if (selectedTime != null) {
                SleepTimerService().setTimerByTime(selectedTime);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '定时器已设置: ${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')} 停止播放',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.access_time),
            label: const Text('选择时间'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '音乐将在指定时间自动停止播放',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

