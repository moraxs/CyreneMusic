import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/player_service.dart';

/// 歌曲列表项组件
class TrackListTile extends StatelessWidget {
  final Track track;
  final int? index;
  final VoidCallback? onTap;

  const TrackListTile({
    super.key,
    required this.track,
    this.index,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 排名
          if (index != null)
            SizedBox(
              width: 32,
              child: Text(
                '${index! + 1}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: index! < 3
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(width: 8),
          // 封面
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              track.picUrl,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 50,
                  height: 50,
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.music_note,
                    color: colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      title: Text(
        track.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Row(
        children: [
          // 音乐来源图标
          Text(
            track.getSourceIcon(),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${track.artists} - ${track.album}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      trailing: Icon(
        Icons.play_circle_outline,
        color: colorScheme.primary,
      ),
      onTap: onTap ?? () {
        // 播放歌曲
        PlayerService().playTrack(track);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('正在加载：${track.name}'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
    );
  }
}

