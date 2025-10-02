import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:palette_generator/palette_generator.dart';
import '../services/player_service.dart';
import '../models/lyric_line.dart';
import '../utils/lyric_parser.dart';

/// 全屏播放器页面
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with SingleTickerProviderStateMixin {
  final ScrollController _lyricScrollController = ScrollController();
  List<LyricLine> _lyrics = [];
  int _currentLyricIndex = -1;
  late AnimationController _fadeController;
  Color? _dominantColor; // 主题色

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    
    // 监听播放器状态
    PlayerService().addListener(_onPlayerStateChanged);
    _loadLyrics();
    _extractThemeColor();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _lyricScrollController.dispose();
    PlayerService().removeListener(_onPlayerStateChanged);
    super.dispose();
  }

  void _onPlayerStateChanged() {
    if (mounted) {
      setState(() {
        _updateCurrentLyric();
      });
    }
  }

  /// 加载歌词
  void _loadLyrics() {
    final song = PlayerService().currentSong;
    if (song == null) return;

    // 根据音乐来源选择不同的解析器
    switch (song.source.name) {
      case 'netease':
        _lyrics = LyricParser.parseNeteaseLyric(
          song.lyric,
          translation: song.tlyric.isNotEmpty ? song.tlyric : null,
        );
        break;
      case 'qq':
        _lyrics = LyricParser.parseQQLyric(
          song.lyric,
          translation: song.tlyric.isNotEmpty ? song.tlyric : null,
        );
        break;
      case 'kugou':
        _lyrics = LyricParser.parseKugouLyric(
          song.lyric,
          translation: song.tlyric.isNotEmpty ? song.tlyric : null,
        );
        break;
    }

    print('🎵 [PlayerPage] 加载歌词: ${_lyrics.length} 行');
    
    // 加载歌词后，更新并滚动到当前位置
    if (_lyrics.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateCurrentLyric();
      });
    }
  }

  /// 更新当前歌词
  void _updateCurrentLyric() {
    final newIndex = LyricParser.findCurrentLineIndex(
      _lyrics,
      PlayerService().position,
    );

    if (newIndex != _currentLyricIndex && newIndex >= 0) {
      setState(() {
        _currentLyricIndex = newIndex;
      });
      // 固定显示方式，不需要滚动
    }
  }

  /// 提取专辑封面的主题色
  Future<void> _extractThemeColor() async {
    final song = PlayerService().currentSong;
    final track = PlayerService().currentTrack;
    final imageUrl = song?.pic ?? track?.picUrl ?? '';
    
    if (imageUrl.isEmpty) return;

    try {
      final imageProvider = NetworkImage(imageUrl);
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 20,
      );

      if (mounted) {
        setState(() {
          // 优先使用鲜艳色，其次使用主色调
          _dominantColor = paletteGenerator.vibrantColor?.color ?? 
                          paletteGenerator.dominantColor?.color ??
                          paletteGenerator.darkVibrantColor?.color;
        });
        print('🎨 [PlayerPage] 提取主题色: $_dominantColor');
      }
    } catch (e) {
      print('❌ [PlayerPage] 提取主题色失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ClipRRect(
        borderRadius: BorderRadius.circular(16), // 圆角窗口
        child: AnimatedBuilder(
          animation: PlayerService(),
          builder: (context, child) {
            final player = PlayerService();
            final song = player.currentSong;
            final track = player.currentTrack;

            if (song == null && track == null) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    '暂无播放内容',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              );
            }

            return Stack(
              children: [
                // 背景（主题色渐变）
                _buildGradientBackground(),

                // 主要内容 - 左右分栏布局 + 底部控制
                SafeArea(
                  child: FadeTransition(
                    opacity: _fadeController,
                    child: Column(
                      children: [
                        // 可拖动的顶部区域
                        _buildDraggableTopBar(context),
                        
                        // 左右分栏内容区域
                        Expanded(
                          child: Row(
                            children: [
                              // 左侧：歌曲信息
                              Expanded(
                                flex: 5,
                                child: _buildLeftPanel(song, track),
                              ),
                              
                              // 右侧：歌词（无分割线）
                              Expanded(
                                flex: 4,
                                child: _buildRightPanel(),
                              ),
                            ],
                          ),
                        ),
                        
                        // 底部进度条和控制按钮
                        _buildBottomControls(player),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
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
            // 返回按钮（覆盖在拖动区域之上，阻止拖动事件）
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, size: 32),
                  color: Colors.white,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
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

  /// 构建渐变背景（主题色到灰色）
  Widget _buildGradientBackground() {
    // 如果还没有提取到主题色，使用默认渐变
    final themeColor = _dominantColor ?? Colors.deepPurple;
    final greyColor = Colors.grey[900] ?? const Color(0xFF212121);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            themeColor,      // 主题色（不透明）
            greyColor,       // 灰色（不透明）
          ],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }

  /// 构建左侧面板（歌曲信息）
  Widget _buildLeftPanel(dynamic song, dynamic track) {
    final imageUrl = song?.pic ?? track?.picUrl ?? '';
    
    return SingleChildScrollView(
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
    return Hero(
      tag: 'player_cover',
      child: Container(
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
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.music_note, size: 100, color: Colors.white54),
                    );
                  },
                )
              : Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.music_note, size: 100, color: Colors.white54),
                ),
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
    return LayoutBuilder(
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 上一曲（暂未实现）
        IconButton(
          icon: const Icon(Icons.skip_previous, color: Colors.white54),
          iconSize: 40,
          onPressed: null, // TODO: 实现上一曲
        ),
        
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
                    player.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.black87,
                  ),
                  iconSize: 40,
                  onPressed: player.togglePlayPause,
                ),
        ),
        
        // 下一曲（暂未实现）
        IconButton(
          icon: const Icon(Icons.skip_next, color: Colors.white54),
          iconSize: 40,
          onPressed: null, // TODO: 实现下一曲
        ),
      ],
    );
  }

  /// 格式化时长
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

