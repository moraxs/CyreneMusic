import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/track.dart';
import '../services/player_service.dart';
import '../services/auth_service.dart';
import '../pages/auth/auth_page.dart';

/// 歌曲列表项组件
class TrackListTile extends StatefulWidget {
  final Track track;
  final int? index;
  final VoidCallback? onTap;
  final bool showIndex;
  final void Function(ImageProvider provider)? onCoverReady;

  const TrackListTile({
    super.key,
    required this.track,
    this.index,
    this.onTap,
    this.showIndex = true, // 默认显示索引
    this.onCoverReady,
  });

  @override
  State<TrackListTile> createState() => _TrackListTileState();
}

class _TrackListTileState extends State<TrackListTile> {
  bool _reportedCover = false;

  @override
  void didUpdateWidget(covariant TrackListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id || oldWidget.track.picUrl != widget.track.picUrl) {
      _reportedCover = false;
    }
  }

  /// 检查登录状态，如果未登录则跳转到登录页面
  /// 返回 true 表示已登录或登录成功，返回 false 表示未登录或取消登录
  Future<bool> _checkLoginStatus() async {
    if (AuthService().isLoggedIn) {
      return true;
    }

    // 显示提示并询问是否要登录
    final shouldLogin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('需要登录'),
          ],
        ),
        content: const Text('此功能需要登录后才能使用，是否前往登录？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('去登录'),
          ),
        ],
      ),
    );

    if (shouldLogin == true && mounted) {
      // 跳转到登录页面
      final result = await showAuthDialog(context);
      
      // 返回登录是否成功
      return result == true && AuthService().isLoggedIn;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 排名
          if (widget.index != null && widget.showIndex)
            SizedBox(
              width: 32,
              child: Text(
                '${widget.index! + 1}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.index! < 3
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
            child: CachedNetworkImage(
              imageUrl: widget.track.picUrl,
              imageBuilder: (context, imageProvider) {
                if (!_reportedCover) {
                  widget.onCoverReady?.call(imageProvider);
                  _reportedCover = true;
                }
                return Image(
                  image: imageProvider,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                );
              },
              placeholder: (context, url) => Container(
                width: 50,
                height: 50,
                color: colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 50,
                height: 50,
                color: colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.music_note,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        widget.track.name,
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
            widget.track.getSourceIcon(),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${widget.track.artists} - ${widget.track.album}',
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
      onTap: widget.onTap ?? () async {
        // 检查登录状态
        final isLoggedIn = await _checkLoginStatus();
        if (isLoggedIn && mounted) {
          // 预取封面 Provider，供播放器复用，避免再次请求
          ImageProvider? provider;
          if (widget.track.picUrl.isNotEmpty) {
            provider = CachedNetworkImageProvider(widget.track.picUrl);
          }
          PlayerService().playTrack(widget.track, coverProvider: provider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('正在加载：${widget.track.name}'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      },
    );
  }
}

