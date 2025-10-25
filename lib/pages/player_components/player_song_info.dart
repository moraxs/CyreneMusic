import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/player_service.dart';
import '../../services/player_background_service.dart';
import '../../models/track.dart';
import '../../models/song_detail.dart';
import '../../widgets/search_widget.dart';
import '../../services/netease_artist_service.dart';
import '../artist_detail_page.dart';

/// 播放器歌曲信息面板
/// 显示专辑封面、歌曲名称、艺术家和专辑信息
class PlayerSongInfo extends StatelessWidget {
  final VoidCallback? onSearchTrigger; // 触发搜索的回调

  const PlayerSongInfo({super.key, this.onSearchTrigger});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: PlayerService(),
      builder: (context, child) {
        final player = PlayerService();
        final song = player.currentSong;
        final track = player.currentTrack;
        final imageUrl = song?.pic ?? track?.picUrl ?? '';
        final backgroundService = PlayerBackgroundService();
        
        return RepaintBoundary(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  
                  // 封面（开启渐变效果时不显示，因为封面已在背景中）
                  if (!backgroundService.enableGradient || 
                      backgroundService.backgroundType != PlayerBackgroundType.adaptive)
                    _buildCover(imageUrl),
                  
                  if (!backgroundService.enableGradient || 
                      backgroundService.backgroundType != PlayerBackgroundType.adaptive)
                    const SizedBox(height: 40),
                  
                  // 歌曲信息
                  _buildSongInfo(context, song, track),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
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
  Widget _buildSongInfo(BuildContext context, SongDetail? song, Track? track) {
    final name = song?.name ?? track?.name ?? '未知歌曲';
    final artistsStr = song?.arName ?? track?.artists ?? '未知艺术家';
    final album = song?.alName ?? track?.album ?? '';

    // 分割歌手（支持多种分隔符：/ , 、）
    final artists = _splitArtists(artistsStr);

    return ValueListenableBuilder<Color?>(
      valueListenable: PlayerService().themeColorNotifier,
      builder: (context, themeColor, child) {
        final titleColor = _getAdaptiveLyricColor(themeColor, true);
        final subtitleColor = _getAdaptiveLyricColor(themeColor, false);
        
        return Column(
          children: [
            // 歌曲名称
            Text(
              name,
              style: TextStyle(
                color: titleColor,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            
            // 艺术家（多个可点击）
            _buildArtistsRow(context, artists, subtitleColor, song),
            
            // 专辑（可点击）
            if (album.isNotEmpty) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _searchInDialog(context, album),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.album_outlined,
                        size: 14,
                        color: subtitleColor.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          album,
                          style: TextStyle(
                            color: subtitleColor.withOpacity(0.6),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// 构建多个艺术家的可点击行
  Widget _buildArtistsRow(BuildContext context, List<String> artists, Color baseColor, SongDetail? song) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 0,
      runSpacing: 4,
      children: artists.asMap().entries.map((entry) {
        final index = entry.key;
        final artist = entry.value;
        final isLast = index == artists.length - 1;
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => _onArtistTap(context, artist, song),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  artist,
                  style: TextStyle(
                    color: baseColor.withOpacity(0.8),
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Text(
                ' / ',
                style: TextStyle(
                  color: baseColor.withOpacity(0.6),
                  fontSize: 18,
                ),
              ),
          ],
        );
      }).toList(),
    );
  }

  Future<void> _onArtistTap(BuildContext context, String artistName, SongDetail? song) async {
    // 仅在网易云音乐来源时跳转歌手详情，否则沿用搜索
    if (song?.source != MusicSource.netease) {
      _searchInDialog(context, artistName);
      return;
    }
    // 解析歌手ID（后端无返回ID时，通过搜索解析）
    final id = await NeteaseArtistDetailService().resolveArtistIdByName(artistName);
    if (id == null) {
      _searchInDialog(context, artistName);
      return;
    }
    if (!context.mounted) return;
    // 悬浮窗展示（与搜索一致的 Dialog 样式）
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: ArtistDetailContent(artistId: id),
          ),
        ),
      ),
    );
  }

  /// 分割歌手字符串（支持多种分隔符）
  List<String> _splitArtists(String artistsStr) {
    // 支持的分隔符：/ , 、
    final separators = ['/', ',', '、'];
    
    for (final separator in separators) {
      if (artistsStr.contains(separator)) {
        return artistsStr
            .split(separator)
            .map((a) => a.trim())
            .where((a) => a.isNotEmpty)
            .toList();
      }
    }
    
    return [artistsStr];
  }

  /// 在对话框中打开搜索
  void _searchInDialog(BuildContext context, String keyword) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 800,
            maxHeight: 700,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SearchWidget(
              onClose: () => Navigator.pop(context),
              initialKeyword: keyword,
            ),
          ),
        ),
      ),
    );
  }

  /// 根据背景色亮度判断应该使用深色还是浅色文字
  /// 返回 true 表示背景亮，应该用深色文字；返回 false 表示背景暗，应该用浅色文字
  bool _shouldUseDarkText(Color backgroundColor) {
    // 计算颜色的相对亮度 (0.0 - 1.0)
    // 使用 W3C 推荐的计算公式
    final luminance = backgroundColor.computeLuminance();
    
    // 如果亮度大于 0.5，认为是亮色背景，应该用深色文字
    return luminance > 0.5;
  }

  /// 获取自适应的歌词颜色
  Color _getAdaptiveLyricColor(Color? themeColor, bool isCurrent) {
    final color = themeColor ?? Colors.grey[700]!;
    final useDarkText = _shouldUseDarkText(color);
    
    if (useDarkText) {
      // 亮色背景，使用深色文字
      return isCurrent 
          ? Colors.black87 
          : Colors.black54;
    } else {
      // 暗色背景，使用浅色文字
      return isCurrent 
          ? Colors.white 
          : Colors.white.withOpacity(0.45);
    }
  }
}
