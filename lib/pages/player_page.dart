import 'dart:ui';
import 'package:flutter/material.dart';
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
      _scrollToCurrentLyric();
    }
  }

  /// 滚动到当前歌词
  void _scrollToCurrentLyric() {
    if (_currentLyricIndex < 0 || !_lyricScrollController.hasClients) return;

    final itemHeight = 80.0; // 每行歌词的高度
    final offset = _currentLyricIndex * itemHeight - 200; // 保持当前行在屏幕中央偏上

    _lyricScrollController.animateTo(
      offset.clamp(0.0, _lyricScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBuilder(
        animation: PlayerService(),
        builder: (context, child) {
          final player = PlayerService();
          final song = player.currentSong;
          final track = player.currentTrack;

          if (song == null && track == null) {
            return const Center(child: Text('暂无播放内容'));
          }

          return Stack(
            children: [
              // 背景（模糊的封面图）
              _buildBlurredBackground(song?.pic ?? track?.picUrl ?? ''),
              
              // 渐变遮罩
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),

              // 主要内容
              SafeArea(
                child: FadeTransition(
                  opacity: _fadeController,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      
                      // 封面
                      _buildCover(song?.pic ?? track?.picUrl ?? ''),
                      const SizedBox(height: 32),
                      
                      // 歌曲信息
                      _buildSongInfo(song, track),
                      const SizedBox(height: 24),
                      
                      // 歌词区域
                      Expanded(
                        child: _lyrics.isEmpty
                            ? _buildNoLyric()
                            : _buildLyricList(),
                      ),
                      
                      // 进度条
                      _buildProgressBar(player),
                      const SizedBox(height: 8),
                      
                      // 控制按钮
                      _buildControls(player),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 构建模糊背景
  Widget _buildBlurredBackground(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(color: Colors.black);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(color: Colors.black);
          },
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
          child: Container(color: Colors.black.withOpacity(0.3)),
        ),
      ],
    );
  }

  /// 构建封面
  Widget _buildCover(String imageUrl) {
    return Hero(
      tag: 'player_cover',
      child: Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
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
                      child: const Icon(Icons.music_note, size: 80, color: Colors.white54),
                    );
                  },
                )
              : Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.music_note, size: 80, color: Colors.white54),
                ),
        ),
      ),
    );
  }

  /// 构建歌曲信息
  Widget _buildSongInfo(dynamic song, dynamic track) {
    final name = song?.name ?? track?.name ?? '未知歌曲';
    final artist = song?.arName ?? track?.artists ?? '未知艺术家';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            artist,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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

  /// 构建歌词列表
  Widget _buildLyricList() {
    return ListView.builder(
      controller: _lyricScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 100),
      itemCount: _lyrics.length,
      itemBuilder: (context, index) {
        final lyric = _lyrics[index];
        final isCurrent = index == _currentLyricIndex;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              color: isCurrent ? Colors.white : Colors.white.withOpacity(0.4),
              fontSize: isCurrent ? 20 : 16,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              height: 1.5,
            ),
            child: Column(
              children: [
                Text(
                  lyric.text,
                  textAlign: TextAlign.center,
                ),
                if (lyric.translation != null && lyric.translation!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      lyric.translation!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isCurrent
                            ? Colors.white.withOpacity(0.8)
                            : Colors.white.withOpacity(0.3),
                        fontSize: isCurrent ? 14 : 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建进度条
  Widget _buildProgressBar(PlayerService player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(player.position),
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                ),
                Text(
                  _formatDuration(player.duration),
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                ),
              ],
            ),
          ),
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

