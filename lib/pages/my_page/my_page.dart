import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../../utils/theme_manager.dart';
import '../../services/auth_service.dart';
import '../../services/playlist_service.dart';
import '../../services/listening_stats_service.dart';
import '../../services/player_service.dart';
import '../../services/playlist_queue_service.dart';
import '../../services/track_source_switch_service.dart';
import '../../services/avatar_fetch_service.dart';
import '../../models/playlist.dart';
import '../../models/track.dart';
import '../../widgets/import_playlist_dialog.dart';
import '../../widgets/source_switch_dialog.dart';
import '../../widgets/music_taste_dialog.dart';
import '../auth/auth_page.dart';
import '../settings_page/user_card.dart';
import 'my_page_breadcrumbs.dart';
import '../../services/global_back_handler_service.dart';
import '../listening_calendar_page.dart';

// UI 组件分离到 part 文件
part 'my_page_material.dart';
part 'my_page_fluent.dart';
part 'my_page_cupertino.dart';

/// 我的页面 - 包含歌单和听歌统计
class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final PlaylistService _playlistService = PlaylistService();
  final ThemeManager _themeManager = ThemeManager();
  ListeningStatsData? _statsData;
  bool _isLoadingStats = true;
  Playlist? _selectedPlaylist;
  bool _isEditMode = false;
  final Set<String> _selectedTrackIds = {};
  
  bool _isSearchMode = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _reverseTransition = false; // 用于控制滑动动画方向

  @override
  void initState() {
    super.initState();
    _playlistService.addListener(_onPlaylistsChanged);
    
    if (AuthService().isLoggedIn) {
      _playlistService.loadPlaylists();
      _loadStats();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncGlobalBackHandler();
    });
  }

  @override
  void dispose() {
    _playlistService.removeListener(_onPlaylistsChanged);
    _searchController.dispose();
    GlobalBackHandlerService().unregister('my_page_overlay');
    super.dispose();
  }

  void _onPlaylistsChanged() {
    if (mounted) setState(() {});
  }

  /// 触发 UI 刷新 (供 extension 使用)
  void refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    try {
      await ListeningStatsService().syncNow();
      final stats = await ListeningStatsService().fetchStats();
      setState(() {
        _statsData = stats;
        _isLoadingStats = false;
      });
    } catch (e) {
      setState(() => _isLoadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoggedIn = AuthService().isLoggedIn;

    Widget page;
    if (_themeManager.isFluentFramework) {
      page = _buildFluentPage(context, isLoggedIn);
    } else if (_themeManager.isCupertinoFramework) {
      page = _buildCupertinoPage(context, isLoggedIn);
    } else {
      page = _buildMaterialPage(context, colorScheme, isLoggedIn);
    }

    return page;
  }

  // ==================== 工具方法 ====================

  void _showUserNotification(
    String message, {
    fluent.InfoBarSeverity severity = fluent.InfoBarSeverity.info,
    Duration duration = const Duration(seconds: 2),
    Color? materialBackground,
  }) {
    if (!mounted) return;
    if (_themeManager.isFluentFramework) {
      fluent.displayInfoBar(
        context,
        builder: (context, close) => fluent.InfoBar(
          title: const Text('提示'),
          content: Text(message),
          severity: severity,
          action: fluent.IconButton(
            icon: const Icon(fluent.FluentIcons.clear),
            onPressed: close,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
          backgroundColor: materialBackground,
        ),
      );
    }
  }

  bool _hasImportConfig(Playlist playlist) {
    return (playlist.source?.isNotEmpty ?? false) &&
        (playlist.sourcePlaylistId?.isNotEmpty ?? false);
  }

  String _formatSyncResultMessage(PlaylistSyncResult result) {
    if (result.insertedCount <= 0) return '同步完成，暂无新增歌曲';
    final preview = result.newTracks
        .map((t) => t.name)
        .where((name) => name.isNotEmpty)
        .take(3)
        .toList();
    final suffix = result.insertedCount > preview.length ? '…' : '';
    final details = preview.isEmpty ? '' : '：${preview.join('、')}$suffix';
    return '同步完成，新增 ${result.insertedCount} 首$details';
  }

  void _openPlaylistDetail(Playlist playlist) {
    setState(() {
      _reverseTransition = false;
      _selectedPlaylist = playlist;
    });
    _playlistService.loadPlaylistTracks(playlist.id);
    _syncGlobalBackHandler();
  }

  void _backToList() {
    setState(() {
      _reverseTransition = true;
      _selectedPlaylist = null;
      _isEditMode = false;
      _selectedTrackIds.clear();
      _isSearchMode = false;
      _searchQuery = '';
      _searchController.clear();
    });
    _syncGlobalBackHandler();
  }

  void _toggleSearchMode() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      if (!_isSearchMode) {
        _searchQuery = '';
        _searchController.clear();
      }
    });
    _syncGlobalBackHandler();
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
  }

  List<PlaylistTrack> _filterTracks(List<PlaylistTrack> tracks) {
    if (_searchQuery.isEmpty) return tracks;
    final query = _searchQuery.toLowerCase();
    return tracks.where((track) {
      return track.name.toLowerCase().contains(query) ||
          track.artists.toLowerCase().contains(query) ||
          track.album.toLowerCase().contains(query);
    }).toList();
  }

  String _getTrackKey(PlaylistTrack track) {
    return '${track.trackId}_${track.source.toString().split('.').last}';
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (!_isEditMode) _selectedTrackIds.clear();
    });
    _syncGlobalBackHandler();
  }

  void _syncGlobalBackHandler() {
    if (!mounted || (_selectedPlaylist == null && !_isSearchMode && !_isEditMode)) {
      GlobalBackHandlerService().unregister('my_page_overlay');
      return;
    }

    GlobalBackHandlerService().register('my_page_overlay', () {
      if (!mounted) return false;

      if (_isSearchMode) {
        _toggleSearchMode();
        return true;
      } else if (_isEditMode) {
        _toggleEditMode();
        return true;
      } else if (_selectedPlaylist != null) {
        _backToList();
        return true;
      }
      return false;
    });
  }

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

  String _getSourceIcon(source) {
    switch (source.toString()) {
      case 'MusicSource.netease': return '🎵';
      case 'MusicSource.qq': return '🎶';
      case 'MusicSource.kugou': return '🎼';
      default: return '🎵';
    }
  }

  Future<void> _playTrack(PlayCountItem item) async {
    try {
      final track = item.toTrack();
      await PlayerService().playTrack(track);
      _showUserNotification(
        '开始播放: ${item.trackName}',
        severity: fluent.InfoBarSeverity.success,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      _showUserNotification(
        '播放失败: $e',
        severity: fluent.InfoBarSeverity.error,
        materialBackground: Colors.red,
      );
    }
  }

  void _playDetailTrack(int index) {
    final tracks = _playlistService.currentTracks;
    if (tracks.isEmpty) return;

    final trackList = tracks.map((t) => t.toTrack()).toList();
    PlaylistQueueService().setQueue(trackList, index, QueueSource.playlist);
    PlayerService().playTrack(trackList[index]);

    _showUserNotification(
      '正在播放: ${tracks[index].name}',
      severity: fluent.InfoBarSeverity.success,
      duration: const Duration(seconds: 1),
    );
  }

  void _playAll() {
    final tracks = _playlistService.currentTracks;
    if (tracks.isEmpty) return;

    final trackList = tracks.map((t) => t.toTrack()).toList();
    PlaylistQueueService().setQueue(trackList, 0, QueueSource.playlist);
    PlayerService().playTrack(trackList[0]);

    _showUserNotification(
      '开始播放: ${_selectedPlaylist?.name ?? "歌单"}',
      severity: fluent.InfoBarSeverity.success,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _syncPlaylistFromList(Playlist playlist) async {
    if (!_hasImportConfig(playlist)) {
      _showUserNotification(
        '请先在"导入管理"中绑定歌单来源后再同步',
        severity: fluent.InfoBarSeverity.warning,
      );
      return;
    }

    _showUserNotification('正在同步...', duration: const Duration(seconds: 1));
    final result = await _playlistService.syncPlaylist(playlist.id);
    _showUserNotification(
      _formatSyncResultMessage(result),
      severity: result.insertedCount > 0
          ? fluent.InfoBarSeverity.success
          : fluent.InfoBarSeverity.info,
    );
    if (_selectedPlaylist?.id == playlist.id) {
      await _playlistService.loadPlaylistTracks(playlist.id);
    }
  }

  // ==================== 对话框方法 ====================

  void _showImportPlaylistDialog() {
    ImportPlaylistDialog.show(context).then((_) {
      if (mounted) _playlistService.loadPlaylists();
    });
  }

  void _showMusicTasteDialog() {
    MusicTasteDialog.show(context);
  }

  void _showCreatePlaylistDialog() {
    if (_themeManager.isFluentFramework) {
      _showCreatePlaylistDialogFluent();
    } else if (_themeManager.isCupertinoFramework) {
      _showCreatePlaylistDialogCupertino();
    } else {
      _showCreatePlaylistDialogMaterial();
    }
  }

  void _showCreatePlaylistDialogFluent() {
    fluent.showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return fluent.ContentDialog(
          title: const Text('新建歌单'),
          content: fluent.TextBox(
            controller: controller,
            placeholder: '请输入歌单名称',
            autofocus: true,
          ),
          actions: [
            fluent.Button(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            fluent.FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(context);
                final newPlaylist = await _playlistService.createPlaylist(name);
                _showUserNotification(
                  newPlaylist != null ? '歌单「$name」创建成功' : '创建歌单失败',
                  severity: newPlaylist != null ? fluent.InfoBarSeverity.success : fluent.InfoBarSeverity.error,
                );
              },
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
  }

  void _showCreatePlaylistDialogMaterial() {
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
            onChanged: (value) => playlistName = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (playlistName.trim().isEmpty) {
                  _showUserNotification(
                    '歌单名称不能为空',
                    severity: fluent.InfoBarSeverity.warning,
                  );
                  return;
                }
                Navigator.pop(context);
                final newPlaylist = await _playlistService.createPlaylist(playlistName.trim());
                _showUserNotification(
                  newPlaylist != null ? '歌单「$playlistName」创建成功' : '创建歌单失败',
                  severity: newPlaylist != null ? fluent.InfoBarSeverity.success : fluent.InfoBarSeverity.error,
                );
              },
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
  }

  void _showCreatePlaylistDialogCupertino() {
    final controller = TextEditingController();
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('新建歌单'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CupertinoTextField(
            controller: controller,
            placeholder: '请输入歌单名称',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              final newPlaylist = await _playlistService.createPlaylist(name);
              _showCupertinoToast(newPlaylist != null ? '歌单「$name」创建成功' : '创建歌单失败');
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  Future<void> _batchRemoveTracks() async {
    if (_selectedPlaylist == null || _selectedTrackIds.isEmpty) return;

    bool? confirmed;
    if (_themeManager.isFluentFramework) {
      confirmed = await fluent.showDialog<bool>(
        context: context,
        builder: (context) => fluent.ContentDialog(
          title: const Text('批量删除'),
          content: Text('确定要删除选中的 ${_selectedTrackIds.length} 首歌曲吗？'),
          actions: [
            fluent.Button(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            fluent.FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
    } else {
      confirmed = await showDialog<bool>(
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
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('删除'),
            ),
          ],
        ),
      );
    }

    if (confirmed != true) return;

    final tracksToDelete = _playlistService.currentTracks
        .where((track) => _selectedTrackIds.contains(_getTrackKey(track)))
        .toList();

    final deletedCount = await _playlistService.removeTracksFromPlaylist(
      _selectedPlaylist!.id,
      tracksToDelete,
    );

    if (!mounted) return;

    _showUserNotification(
      '已删除 $deletedCount 首歌曲',
      severity: fluent.InfoBarSeverity.success,
      duration: const Duration(seconds: 2),
    );

    setState(() {
      _isEditMode = false;
      _selectedTrackIds.clear();
    });
    _syncGlobalBackHandler();
  }

  Future<void> _confirmRemoveTrack(PlaylistTrack track) async {
    if (_selectedPlaylist == null) return;

    bool? confirmed;
    if (_themeManager.isFluentFramework) {
      confirmed = await fluent.showDialog<bool>(
        context: context,
        builder: (context) => fluent.ContentDialog(
          title: const Text('移除歌曲'),
          content: Text('确定要从歌单中移除「${track.name}」吗？'),
          actions: [
            fluent.Button(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            fluent.FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('移除'),
            ),
          ],
        ),
      );
    } else {
      confirmed = await showDialog<bool>(
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
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('移除'),
            ),
          ],
        ),
      );
    }

    if (confirmed != true) return;

    final success = await _playlistService.removePlaylistTrack(
      _selectedPlaylist!.id,
      track,
    );

    _showUserNotification(
      success ? '已从歌单移除' : '移除失败',
      severity: success ? fluent.InfoBarSeverity.success : fluent.InfoBarSeverity.error,
      materialBackground: success ? null : Colors.red,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _confirmDeletePlaylist(Playlist playlist) async {
    bool? confirmed;
    if (_themeManager.isFluentFramework) {
      confirmed = await fluent.showDialog<bool>(
        context: context,
        builder: (context) => fluent.ContentDialog(
          title: const Text('删除歌单'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('确定要删除歌单「${playlist.name}」吗？'),
              if (playlist.trackCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '该歌单包含 ${playlist.trackCount} 首歌曲，删除后将无法恢复。',
                  style: TextStyle(
                    fontSize: 12,
                    color: fluent.FluentTheme.of(context).resources.textFillColorSecondary,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            fluent.Button(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            fluent.FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
    } else {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除歌单'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('确定要删除歌单「${playlist.name}」吗？'),
              if (playlist.trackCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '该歌单包含 ${playlist.trackCount} 首歌曲，删除后将无法恢复。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('删除'),
            ),
          ],
        ),
      );
    }

    if (confirmed != true) return;

    final success = await _playlistService.deletePlaylist(playlist.id);

    if (!mounted) return;

    _showUserNotification(
      success ? '歌单「${playlist.name}」已删除' : '删除失败',
      severity: success ? fluent.InfoBarSeverity.success : fluent.InfoBarSeverity.error,
      materialBackground: success ? null : Colors.red,
      duration: const Duration(seconds: 2),
    );

    if (success && _selectedPlaylist?.id == playlist.id) {
      _backToList();
    }
  }

  Future<void> _showSourceSwitchDialog(Playlist playlist, List<PlaylistTrack> tracks) async {
    if (tracks.isEmpty) {
      _showUserNotification('歌单为空，无法换源', severity: fluent.InfoBarSeverity.warning);
      return;
    }

    final sourceCounts = <MusicSource, int>{};
    for (final track in tracks) {
      sourceCounts[track.source] = (sourceCounts[track.source] ?? 0) + 1;
    }
    final currentSource = sourceCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    Map<String, dynamic>? selectResult;
    if (_themeManager.isFluentFramework) {
      selectResult = await fluent.showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => SourceSwitchSelectDialog(tracks: tracks, currentSource: currentSource),
      );
    } else {
      selectResult = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => SourceSwitchSelectDialog(tracks: tracks, currentSource: currentSource),
      );
    }

    if (selectResult == null || !mounted) return;

    final targetSource = selectResult['targetSource'] as MusicSource;
    final selectedTracks = selectResult['selectedTracks'] as List<PlaylistTrack>;

    bool? progressResult;
    if (_themeManager.isFluentFramework) {
      progressResult = await fluent.showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => SourceSwitchProgressDialog(tracks: selectedTracks, targetSource: targetSource),
      );
    } else {
      progressResult = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => SourceSwitchProgressDialog(tracks: selectedTracks, targetSource: targetSource),
      );
    }

    if (progressResult != true || !mounted) {
      TrackSourceSwitchService().clear();
      return;
    }

    List<MapEntry<PlaylistTrack, Track>>? confirmResult;
    if (_themeManager.isFluentFramework) {
      confirmResult = await fluent.showDialog<List<MapEntry<PlaylistTrack, Track>>>(
        context: context,
        builder: (context) => const SourceSwitchResultDialog(),
      );
    } else {
      confirmResult = await showDialog<List<MapEntry<PlaylistTrack, Track>>>(
        context: context,
        builder: (context) => const SourceSwitchResultDialog(),
      );
    }

    if (confirmResult == null || confirmResult.isEmpty || !mounted) {
      TrackSourceSwitchService().clear();
      return;
    }

    await _executeSourceSwitch(playlist, confirmResult);
    TrackSourceSwitchService().clear();
  }

  Future<void> _executeSourceSwitch(
    Playlist playlist,
    List<MapEntry<PlaylistTrack, Track>> switchPairs,
  ) async {
    _showUserNotification('正在更新歌单...', duration: const Duration(seconds: 1));

    int successCount = 0;
    int failCount = 0;

    for (final pair in switchPairs) {
      final oldTrack = pair.key;
      final newTrack = pair.value;

      try {
        final removeSuccess = await _playlistService.removePlaylistTrack(playlist.id, oldTrack);
        if (removeSuccess) {
          final addSuccess = await _playlistService.addTrackToPlaylist(playlist.id, newTrack);
          if (addSuccess) {
            successCount++;
          } else {
            failCount++;
          }
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
      }
    }

    await _playlistService.loadPlaylistTracks(playlist.id);

    if (!mounted) return;

    if (failCount == 0) {
      _showUserNotification('换源完成，成功更新 $successCount 首歌曲', severity: fluent.InfoBarSeverity.success);
    } else {
      _showUserNotification('换源完成，成功 $successCount 首，失败 $failCount 首', severity: fluent.InfoBarSeverity.warning);
    }
  }

  // Cupertino 专用方法
  void _showCupertinoToast(String message) {
    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        Future.delayed(const Duration(seconds: 2), () {
          if (Navigator.canPop(context)) Navigator.pop(context);
        });
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: CupertinoColors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message,
              style: const TextStyle(color: CupertinoColors.white, fontSize: 14),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeletePlaylistCupertino(Playlist playlist) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('删除歌单'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              Text('确定要删除歌单「${playlist.name}」吗？'),
              if (playlist.trackCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '该歌单包含 ${playlist.trackCount} 首歌曲，删除后将无法恢复。',
                  style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
                ),
              ],
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _playlistService.deletePlaylist(playlist.id);
    if (!mounted) return;

    _showCupertinoToast(success ? '歌单「${playlist.name}」已删除' : '删除失败');

    if (success && _selectedPlaylist?.id == playlist.id) {
      _backToList();
    }
  }

  Future<void> _confirmRemoveTrackCupertino(PlaylistTrack track) async {
    if (_selectedPlaylist == null) return;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('移除歌曲'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text('确定要从歌单中移除「${track.name}」吗？'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _playlistService.removePlaylistTrack(_selectedPlaylist!.id, track);
    _showCupertinoToast(success ? '已从歌单移除' : '移除失败');
  }

  Future<void> _batchRemoveTracksCupertino() async {
    if (_selectedPlaylist == null || _selectedTrackIds.isEmpty) return;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('批量删除'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text('确定要删除选中的 ${_selectedTrackIds.length} 首歌曲吗？'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
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

    if (!mounted) return;

    _showCupertinoToast('已删除 $deletedCount 首歌曲');

    setState(() {
      _isEditMode = false;
      _selectedTrackIds.clear();
    });
    _syncGlobalBackHandler();
  }
}

/// Linux Do 头像组件 - Material 版本
/// 
/// 使用 WebView 服务获取头像，绕过 Cloudflare 保护
class LinuxDoAvatarMaterial extends StatefulWidget {
  final String url;
  final int userId;
  final double size;
  final Widget? placeholder;
  final Widget? errorWidget;

  const LinuxDoAvatarMaterial({
    super.key,
    required this.url,
    required this.userId,
    this.size = 60,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<LinuxDoAvatarMaterial> createState() => _LinuxDoAvatarMaterialState();
}

class _LinuxDoAvatarMaterialState extends State<LinuxDoAvatarMaterial> {
  Uint8List? _avatarData;
  bool _isLoading = true;
  bool _hasFailed = false;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  @override
  void didUpdateWidget(LinuxDoAvatarMaterial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loadAvatar();
    }
  }

  Future<void> _loadAvatar() async {
    setState(() {
      _isLoading = true;
      _hasFailed = false;
    });

    try {
      final data = await AvatarFetchService().fetchAvatar(
        widget.url,
        cacheKey: 'linuxdo_${widget.userId}',
      );

      if (mounted) {
        setState(() {
          _avatarData = data;
          _isLoading = false;
          _hasFailed = data == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder ?? 
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
    }

    if (_hasFailed || _avatarData == null) {
      return widget.errorWidget ?? 
        Container(
          width: widget.size,
          height: widget.size,
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(Icons.person, size: widget.size * 0.5),
        );
    }

    return Image.memory(
      _avatarData!,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return widget.errorWidget ?? 
          Container(
            width: widget.size,
            height: widget.size,
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(Icons.person, size: widget.size * 0.5),
          );
      },
    );
  }
}
