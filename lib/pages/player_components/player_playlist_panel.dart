import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/player_service.dart';
import '../../services/playlist_queue_service.dart';
import '../../services/play_history_service.dart';
import '../../models/track.dart';

/// 播放器播放列表面板
/// 显示播放队列或播放历史
class PlayerPlaylistPanel extends StatelessWidget {
  final bool isVisible;
  final Animation<Offset>? slideAnimation;
  final VoidCallback onClose;

  const PlayerPlaylistPanel({
    super.key,
    required this.isVisible,
    this.slideAnimation,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();
    
    if (slideAnimation != null) {
      return SlideTransition(
        position: slideAnimation!,
        child: Align(
          alignment: Alignment.centerRight,
          child: _buildPanel(context),
        ),
      );
    }
    
    return Align(
      alignment: Alignment.centerRight,
      child: _buildPanel(context),
    );
  }

  Widget _buildPanel(BuildContext context) {
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
                      onPressed: onClose,
                      tooltip: '关闭',
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white24, height: 1),

              // 播放列表
              Expanded(
                child: displayList.isEmpty
                    ? _buildEmptyState()
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

                          return _buildPlaylistItem(context, track, index, isCurrentTrack);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
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
    );
  }

  /// 构建播放列表项
  Widget _buildPlaylistItem(BuildContext context, Track track, int index, bool isCurrentTrack) {
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
