import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/playlist_service.dart';
import '../services/listening_stats_service.dart';
import '../services/player_service.dart';
import '../services/playlist_queue_service.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../widgets/import_playlist_dialog.dart';
import 'auth/auth_page.dart';

/// 我的页面 - 包含歌单和听歌统计
class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final PlaylistService _playlistService = PlaylistService();
  ListeningStatsData? _statsData;
  bool _isLoadingStats = true;
  Playlist? _selectedPlaylist; // 当前选中的歌单
  bool _isEditMode = false; // 是否处于编辑模式
  final Set<String> _selectedTrackIds = {}; // 选中的歌曲ID集合

  @override
  void initState() {
    super.initState();
    _playlistService.addListener(_onPlaylistsChanged);
    
    if (AuthService().isLoggedIn) {
      _playlistService.loadPlaylists();
      _loadStats();
    }
  }

  @override
  void dispose() {
    _playlistService.removeListener(_onPlaylistsChanged);
    super.dispose();
  }

  void _onPlaylistsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      await ListeningStatsService().syncNow();
      final stats = await ListeningStatsService().fetchStats();
      setState(() {
        _statsData = stats;
        _isLoadingStats = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoggedIn = AuthService().isLoggedIn;

    // 如果未登录，显示登录提示
    if (!isLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 80,
              color: colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              '登录后查看更多',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '登录即可管理歌单和查看听歌统计',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                showAuthDialog(context).then((_) {
                  if (mounted) setState(() {});
                });
              },
              icon: const Icon(Icons.login),
              label: const Text('立即登录'),
            ),
          ],
        ),
      );
    }

    // 如果选中了歌单，显示歌单详情
    if (_selectedPlaylist != null) {
      return _buildPlaylistDetail(_selectedPlaylist!, colorScheme);
    }

    // 已登录，显示完整内容
    return RefreshIndicator(
      onRefresh: () async {
        await _playlistService.loadPlaylists();
        await _loadStats();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 用户信息卡片
          _buildUserCard(colorScheme),
          
          const SizedBox(height: 16),
          
          // 听歌统计卡片
          _buildStatsCard(colorScheme),
          
          const SizedBox(height: 24),
          
          // 我的歌单标题
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '我的歌单',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.cloud_download),
                    onPressed: _showImportPlaylistDialog,
                    tooltip: '从网易云导入歌单',
                  ),
                  TextButton.icon(
                    onPressed: _showCreatePlaylistDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('新建'),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // 歌单列表
          _buildPlaylistsList(colorScheme),
          
          const SizedBox(height: 24),
          
          // 播放排行榜
          if (_statsData != null && _statsData!.playCounts.isNotEmpty) ...[
            Text(
              '播放排行榜 Top 10',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            _buildTopPlaysList(colorScheme),
          ],
        ],
      ),
    );
  }

  /// 构建用户信息卡片
  Widget _buildUserCard(ColorScheme colorScheme) {
    final user = AuthService().currentUser;
    if (user == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
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
    if (_isLoadingStats) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_statsData == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '暂无统计数据',
            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
          ),
        ),
      );
    }

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

  /// 构建歌单列表
  Widget _buildPlaylistsList(ColorScheme colorScheme) {
    final playlists = _playlistService.playlists;

    if (playlists.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.library_music_outlined,
                  size: 48,
                  color: colorScheme.onSurface.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无歌单',
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
      children: playlists.map((playlist) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              playlist.isDefault ? Icons.favorite : Icons.library_music,
              color: playlist.isDefault ? Colors.red : colorScheme.primary,
            ),
            title: Text(playlist.name),
            subtitle: Text('${playlist.trackCount} 首歌曲'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openPlaylistDetail(playlist),
          ),
        );
      }).toList(),
    );
  }

  /// 构建播放排行榜
  Widget _buildTopPlaysList(ColorScheme colorScheme) {
    final topPlays = _statsData!.playCounts.take(10).toList();

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: topPlays.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = topPlays[index];
          return _buildPlayCountItem(item, index + 1, colorScheme);
        },
      ),
    );
  }

  /// 构建播放次数列表项
  Widget _buildPlayCountItem(
    PlayCountItem item,
    int rank,
    ColorScheme colorScheme,
  ) {
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
                  color: rankColor != null
                      ? Colors.white
                      : colorScheme.onPrimaryContainer,
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
            style: const TextStyle(fontWeight: FontWeight.bold),
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

  /// 打开歌单详情
  void _openPlaylistDetail(Playlist playlist) {
    setState(() {
      _selectedPlaylist = playlist;
    });
    // 加载歌单歌曲
    _playlistService.loadPlaylistTracks(playlist.id);
  }

  /// 返回歌单列表
  void _backToList() {
    setState(() {
      _selectedPlaylist = null;
      _isEditMode = false;
      _selectedTrackIds.clear();
    });
  }

  /// 生成歌曲唯一标识
  String _getTrackKey(PlaylistTrack track) {
    return '${track.trackId}_${track.source.toString().split('.').last}';
  }

  /// 切换编辑模式
  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (!_isEditMode) {
        _selectedTrackIds.clear();
      }
    });
  }

  /// 全选/取消全选
  void _toggleSelectAll() {
    setState(() {
      if (_selectedTrackIds.length == _playlistService.currentTracks.length) {
        _selectedTrackIds.clear();
      } else {
        _selectedTrackIds.clear();
        for (var track in _playlistService.currentTracks) {
          _selectedTrackIds.add(_getTrackKey(track));
        }
      }
    });
  }

  /// 切换单个歌曲的选中状态
  void _toggleTrackSelection(PlaylistTrack track) {
    setState(() {
      final key = _getTrackKey(track);
      if (_selectedTrackIds.contains(key)) {
        _selectedTrackIds.remove(key);
      } else {
        _selectedTrackIds.add(key);
      }
    });
  }

  /// 批量删除选中的歌曲
  Future<void> _batchRemoveTracks() async {
    if (_selectedPlaylist == null || _selectedTrackIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量删除'),
        content: Text('确定要删除选中的 ${_selectedTrackIds.length} 首歌曲吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final tracksToDelete = _playlistService.currentTracks
        .where((track) => _selectedTrackIds.contains(_getTrackKey(track)))
        .toList();

    final deletedCount = await _playlistService.removeTracksFromPlaylist(
      _selectedPlaylist!.id,
      tracksToDelete,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已删除 $deletedCount 首歌曲'),
          duration: const Duration(seconds: 2),
        ),
      );

      setState(() {
        _isEditMode = false;
        _selectedTrackIds.clear();
      });
    }
  }

  /// 显示导入歌单对话框
  void _showImportPlaylistDialog() {
    ImportPlaylistDialog.show(context).then((_) {
      // 导入完成后刷新歌单列表
      if (mounted) {
        _playlistService.loadPlaylists();
      }
    });
  }

  /// 显示创建歌单对话框
  void _showCreatePlaylistDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String playlistName = '';
        return AlertDialog(
          title: const Text('新建歌单'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '请输入歌单名称',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              playlistName = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (playlistName.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('歌单名称不能为空')),
                  );
                  return;
                }

                Navigator.pop(context);
                await _playlistService.createPlaylist(playlistName.trim());

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('歌单「$playlistName」创建成功')),
                  );
                }
              },
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
  }

  /// 构建歌单详情
  Widget _buildPlaylistDetail(Playlist playlist, ColorScheme colorScheme) {
    final tracks = _playlistService.currentPlaylistId == playlist.id
        ? _playlistService.currentTracks
        : <PlaylistTrack>[];
    final isLoading = _playlistService.isLoadingTracks;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // 顶部标题栏
          _buildDetailAppBar(playlist, colorScheme, tracks),

          // 加载状态
          if (isLoading && tracks.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          // 歌曲列表
          else if (tracks.isEmpty)
            SliverFillRemaining(
              child: _buildDetailEmptyState(colorScheme),
            )
          else ...[
            // 统计信息和播放按钮
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildDetailStatisticsCard(colorScheme, tracks.length),
              ),
            ),

            // 歌曲列表
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final track = tracks[index];
                    return _buildTrackItem(track, index, colorScheme);
                  },
                  childCount: tracks.length,
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 16),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建歌单详情顶部栏
  Widget _buildDetailAppBar(Playlist playlist, ColorScheme colorScheme, List<PlaylistTrack> tracks) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: colorScheme.surface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _backToList,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditMode ? '已选择 ${_selectedTrackIds.length} 首' : playlist.name,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (!_isEditMode && playlist.isDefault)
            Text(
              '默认歌单',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
        ],
      ),
      actions: [
        if (_isEditMode) ...[
          // 全选按钮
          IconButton(
            icon: Icon(
              _selectedTrackIds.length == tracks.length
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
            ),
            onPressed: tracks.isNotEmpty ? _toggleSelectAll : null,
            tooltip: _selectedTrackIds.length == tracks.length ? '取消全选' : '全选',
          ),
          // 批量删除按钮
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: _selectedTrackIds.isNotEmpty ? _batchRemoveTracks : null,
            tooltip: '删除选中',
          ),
          // 取消按钮
          TextButton(
            onPressed: _toggleEditMode,
            child: const Text('取消'),
          ),
        ] else ...[
          // 编辑按钮
          if (tracks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _toggleEditMode,
              tooltip: '批量管理',
            ),
          // 刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _playlistService.loadPlaylistTracks(playlist.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('正在刷新...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: '刷新',
          ),
        ],
      ],
    );
  }

  /// 构建详情页统计信息卡片
  Widget _buildDetailStatisticsCard(ColorScheme colorScheme, int count) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              Icons.music_note,
              size: 24,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              '共 $count 首歌曲',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Spacer(),
            if (count > 0)
              FilledButton.icon(
                onPressed: _playAll,
                icon: const Icon(Icons.play_arrow, size: 20),
                label: const Text('播放全部'),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建详情页空状态
  Widget _buildDetailEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off,
            size: 64,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '歌单为空',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '快去添加一些喜欢的歌曲吧',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建歌曲项
  Widget _buildTrackItem(PlaylistTrack item, int index, ColorScheme colorScheme) {
    final trackKey = _getTrackKey(item);
    final isSelected = _selectedTrackIds.contains(trackKey);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected && _isEditMode
          ? colorScheme.primaryContainer.withOpacity(0.3)
          : null,
      child: ListTile(
        leading: _isEditMode
            ? Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleTrackSelection(item),
              )
            : Stack(
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
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                '${item.artists} • ${item.album}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _getSourceIcon(item.source),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: _isEditMode
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => _playDetailTrack(index),
                    tooltip: '播放',
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    color: Colors.redAccent,
                    onPressed: () => _confirmRemoveTrack(item),
                    tooltip: '从歌单移除',
                  ),
                ],
              ),
        onTap: _isEditMode
            ? () => _toggleTrackSelection(item)
            : () => _playDetailTrack(index),
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

  /// 播放歌单中的指定歌曲
  void _playDetailTrack(int index) {
    final tracks = _playlistService.currentTracks;
    if (tracks.isEmpty) return;

    final trackList = tracks.map((t) => t.toTrack()).toList();

    PlaylistQueueService().setQueue(
      trackList,
      index,
      QueueSource.playlist,
    );

    PlayerService().playTrack(trackList[index]);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('正在播放: ${tracks[index].name}'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// 播放歌单全部歌曲
  void _playAll() {
    final tracks = _playlistService.currentTracks;
    if (tracks.isEmpty) return;

    final trackList = tracks.map((t) => t.toTrack()).toList();

    PlaylistQueueService().setQueue(
      trackList,
      0,
      QueueSource.playlist,
    );

    PlayerService().playTrack(trackList[0]);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('开始播放: ${_selectedPlaylist?.name ?? "歌单"}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 确认移除歌曲
  Future<void> _confirmRemoveTrack(PlaylistTrack track) async {
    if (_selectedPlaylist == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除歌曲'),
        content: Text('确定要从歌单中移除「${track.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('移除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _playlistService.removeTrackFromPlaylist(
      _selectedPlaylist!.id,
      track,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '已从歌单移除' : '移除失败'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

