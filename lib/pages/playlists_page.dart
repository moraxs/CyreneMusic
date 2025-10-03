import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/playlist_service.dart';
import '../services/player_service.dart';
import '../services/playlist_queue_service.dart';
import '../services/auth_service.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../widgets/import_playlist_dialog.dart';

/// 歌单页面
class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage>
    with AutomaticKeepAliveClientMixin {
  final PlaylistService _playlistService = PlaylistService();
  Playlist? _selectedPlaylist; // 当前选中的歌单
  
  // 批量删除相关状态
  bool _isEditMode = false; // 是否处于编辑模式
  final Set<String> _selectedTrackIds = {}; // 选中的歌曲ID集合（trackId + source）

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _playlistService.addListener(_onPlaylistsChanged);

    // 加载歌单列表
    if (AuthService().isLoggedIn) {
      _playlistService.loadPlaylists();
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;

    // 检查登录状态
    if (!AuthService().isLoggedIn) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: CustomScrollView(
          slivers: [
            _buildAppBar(colorScheme),
            SliverFillRemaining(
              child: _buildLoginPrompt(colorScheme),
            ),
          ],
        ),
      );
    }

    // 如果选中了歌单，显示歌单详情
    if (_selectedPlaylist != null) {
      return _buildPlaylistDetail(_selectedPlaylist!, colorScheme);
    }

    // 否则显示歌单列表
    final playlists = _playlistService.playlists;
    final isLoading = _playlistService.isLoading;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // 顶部标题栏
          _buildAppBar(colorScheme),

          // 加载状态
          if (isLoading && playlists.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          // 歌单列表
          else if (playlists.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(colorScheme),
            )
          else ...[
            // 统计信息
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildStatisticsCard(colorScheme, playlists.length),
              ),
            ),

            // 歌单列表
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final playlist = playlists[index];
                    return _buildPlaylistItem(playlist, colorScheme);
                  },
                  childCount: playlists.length,
                ),
              ),
            ),

            // 底部留白
            const SliverToBoxAdapter(
              child: SizedBox(height: 16),
            ),
          ],
        ],
      ),
      floatingActionButton: AuthService().isLoggedIn
          ? FloatingActionButton.extended(
              onPressed: _showCreatePlaylistDialog,
              icon: const Icon(Icons.add),
              label: const Text('新建歌单'),
            )
          : null,
    );
  }

  /// 构建顶部栏
  Widget _buildAppBar(ColorScheme colorScheme) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: colorScheme.surface,
      title: Text(
        '我的歌单',
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.cloud_download),
          onPressed: () {
            if (AuthService().isLoggedIn) {
              _showImportPlaylistDialog();
            }
          },
          tooltip: '从网易云导入歌单',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            if (AuthService().isLoggedIn) {
              _playlistService.loadPlaylists();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('正在刷新...'),
                  duration: Duration(seconds: 1),
                ),
              );
            }
          },
          tooltip: '刷新',
        ),
      ],
    );
  }

  /// 构建统计信息卡片
  Widget _buildStatisticsCard(ColorScheme colorScheme, int count) {
    final totalTracks = _playlistService.playlists
        .fold<int>(0, (sum, playlist) => sum + playlist.trackCount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              colorScheme,
              Icons.library_music,
              '歌单',
              count.toString(),
            ),
            Container(
              width: 1,
              height: 40,
              color: colorScheme.outlineVariant,
            ),
            _buildStatItem(
              colorScheme,
              Icons.music_note,
              '歌曲',
              totalTracks.toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      ColorScheme colorScheme, IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  /// 构建歌单项
  Widget _buildPlaylistItem(Playlist playlist, ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: playlist.isDefault
              ? colorScheme.primaryContainer
              : colorScheme.secondaryContainer,
          child: Icon(
            playlist.isDefault ? Icons.favorite : Icons.queue_music,
            color: playlist.isDefault
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSecondaryContainer,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                playlist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (playlist.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '默认',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text('${playlist.trackCount} 首歌曲'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              onPressed: () => _openPlaylistDetail(playlist),
              tooltip: '查看详情',
            ),
            if (!playlist.isDefault) ...[
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _showRenamePlaylistDialog(playlist),
                tooltip: '重命名',
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 20),
                color: Colors.redAccent,
                onPressed: () => _confirmDeletePlaylist(playlist),
                tooltip: '删除',
              ),
            ],
          ],
        ),
        onTap: () => _openPlaylistDetail(playlist),
      ),
    );
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
        // 当前全选，则取消全选
        _selectedTrackIds.clear();
      } else {
        // 未全选，则全选
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
    if (_selectedPlaylist == null || _selectedTrackIds.isEmpty) {
      return;
    }

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

    // 获取要删除的歌曲列表
    final tracksToDelete = _playlistService.currentTracks
        .where((track) => _selectedTrackIds.contains(_getTrackKey(track)))
        .toList();

    // 调用批量删除
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

      // 退出编辑模式
      setState(() {
        _isEditMode = false;
        _selectedTrackIds.clear();
      });
    }
  }

  /// 显示导入歌单对话框
  void _showImportPlaylistDialog() {
    ImportPlaylistDialog.show(context);
  }

  /// 显示创建歌单对话框
  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建歌单'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '歌单名称',
            hintText: '请输入歌单名称',
          ),
          autofocus: true,
          maxLength: 30,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('歌单名称不能为空')),
                );
                return;
              }

              Navigator.pop(context);

              final success = await _playlistService.createPlaylist(name);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? '创建成功' : '创建失败'),
                  ),
                );
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  /// 显示重命名歌单对话框
  void _showRenamePlaylistDialog(Playlist playlist) {
    final controller = TextEditingController(text: playlist.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名歌单'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '歌单名称',
          ),
          autofocus: true,
          maxLength: 30,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('歌单名称不能为空')),
                );
                return;
              }

              Navigator.pop(context);

              final success =
                  await _playlistService.updatePlaylist(playlist.id, name);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? '重命名成功' : '重命名失败'),
                  ),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 确认删除歌单
  void _confirmDeletePlaylist(Playlist playlist) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除歌单'),
        content: Text('确定要删除歌单「${playlist.name}」吗？\n歌单中的所有歌曲也会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);

              final success = await _playlistService.deletePlaylist(playlist.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? '删除成功' : '删除失败'),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_music_outlined,
            size: 80,
            color: colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无歌单',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角按钮创建新歌单',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
          ),
        ],
      ),
    );
  }

  /// 构建登录提示
  Widget _buildLoginPrompt(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.login,
            size: 80,
            color: colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '请先登录',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '登录后即可使用歌单功能',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
          ),
        ],
      ),
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
          _buildDetailAppBar(playlist, colorScheme),

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

            // 底部留白
            const SliverToBoxAdapter(
              child: SizedBox(height: 16),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建歌单详情顶部栏
  Widget _buildDetailAppBar(Playlist playlist, ColorScheme colorScheme) {
    final tracks = _playlistService.currentTracks;
    
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

  /// 构建歌曲项
  Widget _buildTrackItem(
      PlaylistTrack item, int index, ColorScheme colorScheme) {
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
                  // 序号标记
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
                    onPressed: () => _playTrack(index),
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
            : () => _playTrack(index),
      ),
    );
  }

  /// 播放指定歌曲
  void _playTrack(int index) {
    final tracks = _playlistService.currentTracks;
    if (tracks.isEmpty) return;

    // 将歌单歌曲转换为 Track 列表
    final trackList = tracks.map((t) => t.toTrack()).toList();

    // 设置播放队列
    PlaylistQueueService().setQueue(
      trackList,
      index,
      QueueSource.playlist,
    );

    // 播放选中的歌曲
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

  /// 播放全部歌曲
  void _playAll() {
    final tracks = _playlistService.currentTracks;
    if (tracks.isEmpty) return;

    // 将歌单歌曲转换为 Track 列表
    final trackList = tracks.map((t) => t.toTrack()).toList();

    // 设置播放队列并播放第一首
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
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// 确认从歌单移除
  void _confirmRemoveTrack(PlaylistTrack track) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从歌单移除'),
        content: Text('确定要从「${_selectedPlaylist?.name ?? "歌单"}」中移除「${track.name}」吗？'),
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

    if (confirmed == true && _selectedPlaylist != null) {
      await _playlistService.removeTrackFromPlaylist(
          _selectedPlaylist!.id, track);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已从歌单移除'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
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
    }
  }

  /// 构建详情页空状态
  Widget _buildDetailEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note_outlined,
            size: 80,
            color: colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '歌单还是空的',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '在播放器中可以将歌曲添加到歌单',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
          ),
        ],
      ),
    );
  }
}

