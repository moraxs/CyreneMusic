import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/listening_stats_service.dart';
import '../services/player_service.dart';
import '../models/track.dart';

/// 个人中心页面
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  ListeningStatsData? _statsData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  /// 加载统计数据
  Future<void> _loadStats() async {
    if (!AuthService().isLoggedIn) {
      setState(() {
        _isLoading = false;
        _errorMessage = '请先登录';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 先同步当前待同步的数据
      await ListeningStatsService().syncNow();
      
      // 然后获取最新统计数据
      final stats = await ListeningStatsService().fetchStats();
      setState(() {
        _statsData = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载统计数据失败: $e';
        _isLoading = false;
      });
    }
  }

  /// 播放歌曲
  Future<void> _playTrack(PlayCountItem item) async {
    try {
      final track = item.toTrack();
      await PlayerService().playTrack(track);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('开始播放: ${item.trackName}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('播放失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = AuthService().currentUser;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: colorScheme.error),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _loadStats,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStats,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 用户信息卡片
                      _buildUserCard(user, colorScheme),
                      
                      const SizedBox(height: 16),
                      
                      // 统计卡片
                      _buildStatsCard(colorScheme),
                      
                      const SizedBox(height: 16),
                      
                      // 播放排行榜
                      _buildPlayCountsSection(colorScheme),
                    ],
                  ),
                ),
    );
  }

  /// 构建用户信息卡片
  Widget _buildUserCard(User? user, ColorScheme colorScheme) {
    if (user == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 头像
            CircleAvatar(
              radius: 32,
              backgroundImage: user.avatarUrl != null
                  ? CachedNetworkImageProvider(user.avatarUrl!)
                  : null,
              child: user.avatarUrl == null
                  ? Text(
                      user.username[0].toUpperCase(),
                      style: const TextStyle(fontSize: 24),
                    )
                  : null,
            ),
            
            const SizedBox(width: 16),
            
            // 用户信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建统计卡片
  Widget _buildStatsCard(ColorScheme colorScheme) {
    if (_statsData == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '听歌统计',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            
            const SizedBox(height: 16),
            
            // 统计数据行
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.access_time,
                    label: '累计时长',
                    value: ListeningStatsService.formatDuration(
                      _statsData!.totalListeningTime,
                    ),
                    colorScheme: colorScheme,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.play_circle_outline,
                    label: '播放次数',
                    value: '${_statsData!.totalPlayCount} 次',
                    colorScheme: colorScheme,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建统计项
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建播放排行榜
  Widget _buildPlayCountsSection(ColorScheme colorScheme) {
    if (_statsData == null || _statsData!.playCounts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.music_note,
                  size: 64,
                  color: colorScheme.onSurface.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无播放记录',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '播放排行榜',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _statsData!.playCounts.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _statsData!.playCounts[index];
              return _buildPlayCountItem(item, index + 1, colorScheme);
            },
          ),
        ),
      ],
    );
  }

  /// 构建播放次数列表项
  Widget _buildPlayCountItem(
    PlayCountItem item,
    int rank,
    ColorScheme colorScheme,
  ) {
    // 前三名使用特殊颜色
    Color? rankColor;
    if (rank == 1) {
      rankColor = Colors.amber;
    } else if (rank == 2) {
      rankColor = Colors.grey.shade400;
    } else if (rank == 3) {
      rankColor = Colors.brown.shade300;
    }

    return ListTile(
      leading: Stack(
        children: [
          // 封面
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: item.picUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 48,
                height: 48,
                color: colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.music_note, size: 24),
              ),
              errorWidget: (context, url, error) => Container(
                width: 48,
                height: 48,
                color: colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.music_note, size: 24),
              ),
            ),
          ),
          
          // 排名徽章
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: rankColor ?? colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: rankColor != null ? Colors.white : colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        item.trackName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        item.artists.isNotEmpty ? item.artists : '未知艺术家',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${item.playCount} 次',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            item.toTrack().getSourceName(),
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
      onTap: () => _playTrack(item),
    );
  }
}

