import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/play_history_service.dart';
import '../services/player_service.dart';
import '../models/track.dart';

/// 播放历史页面
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with AutomaticKeepAliveClientMixin {
  final PlayHistoryService _historyService = PlayHistoryService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _historyService.addListener(_onHistoryChanged);
  }

  @override
  void dispose() {
    _historyService.removeListener(_onHistoryChanged);
    super.dispose();
  }

  void _onHistoryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;
    final history = _historyService.history;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // 顶部标题栏
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: colorScheme.surface,
            title: Text(
              '播放历史',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              if (history.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _showClearConfirmDialog,
                  tooltip: '清空历史',
                ),
            ],
          ),

          // 统计信息卡片
          if (history.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildStatisticsCard(colorScheme),
              ),
            ),

          // 历史记录列表
          if (history.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(colorScheme),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = history[index];
                    return _buildHistoryItem(item, index, colorScheme);
                  },
                  childCount: history.length,
                ),
              ),
            ),

          // 底部留白
          const SliverToBoxAdapter(
            child: SizedBox(height: 16),
          ),
        ],
      ),
    );
  }

  /// 构建统计信息卡片
  Widget _buildStatisticsCard(ColorScheme colorScheme) {
    final todayCount = _historyService.getTodayPlayCount();
    final weekCount = _historyService.getWeekPlayCount();
    final totalCount = _historyService.history.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '播放统计',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('今日', todayCount, colorScheme),
                _buildStatItem('本周', weekCount, colorScheme),
                _buildStatItem('总计', totalCount, colorScheme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建单个统计项
  Widget _buildStatItem(String label, int count, ColorScheme colorScheme) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  /// 构建历史记录项
  Widget _buildHistoryItem(PlayHistoryItem item, int index, ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: item.picUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 50,
                  height: 50,
                  color: colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
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
            // 播放序号标记
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                  ),
                ),
                child: Text(
                  '#${index + 1}',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.artists} • ${item.album}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  _getSourceIcon(item.source),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTime(item.playedAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () {
                PlayerService().playTrack(item.toTrack());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('正在播放: ${item.name}'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              tooltip: '播放',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () {
                _historyService.removeHistoryItem(item);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('已删除'),
                    duration: const Duration(seconds: 1),
                    action: SnackBarAction(
                      label: '撤销',
                      onPressed: () {
                        // TODO: 实现撤销功能
                      },
                    ),
                  ),
                );
              },
              tooltip: '删除',
            ),
          ],
        ),
        onTap: () {
          PlayerService().playTrack(item.toTrack());
        },
      ),
    );
  }

  /// 获取音乐平台图标
  String _getSourceIcon(MusicSource source) {
    switch (source) {
      case MusicSource.netease:
        return '🎵';
      case MusicSource.qq:
        return '🎶';
      case MusicSource.kugou:
        return '🎼';
      case MusicSource.local:
        return '📁';
    }
  }

  /// 格式化时间显示
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      // 简单格式化：MM月dd日
      return '${time.month}月${time.day}日';
    }
  }

  /// 构建空状态
  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无播放历史',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '播放歌曲后会自动记录',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
          ),
        ],
      ),
    );
  }

  /// 显示清空确认对话框
  void _showClearConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空播放历史'),
        content: const Text('确定要清空所有播放历史吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              _historyService.clearHistory();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已清空播放历史')),
              );
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

