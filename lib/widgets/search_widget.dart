import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/track.dart';
import '../models/merged_track.dart';
import '../services/search_service.dart';
import '../services/netease_artist_service.dart';
import '../pages/artist_detail_page.dart';
import '../pages/album_detail_page.dart';
import '../services/player_service.dart';
import '../services/auth_service.dart';
import '../pages/auth/auth_page.dart';

/// 搜索组件（内嵌版本）
class SearchWidget extends StatefulWidget {
  final VoidCallback onClose;
  final String? initialKeyword; // 初始搜索关键词

  const SearchWidget({
    super.key,
    required this.onClose,
    this.initialKeyword,
  });

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final SearchService _searchService = SearchService();
  int _currentTabIndex = 0;

  // 歌手搜索状态
  List<NeteaseArtistBrief> _artistResults = [];
  bool _artistLoading = false;
  String? _artistError;
  // 二级页面（面包屑）状态
  int? _secondaryArtistId;
  String? _secondaryArtistName;
  int? _secondaryAlbumId;
  String? _secondaryAlbumName;
  
  @override
  void initState() {
    super.initState();
    _searchService.addListener(_onSearchResultChanged);
    
    // 如果有初始关键词，自动填充并搜索
    if (widget.initialKeyword != null && widget.initialKeyword!.isNotEmpty) {
      _searchController.text = widget.initialKeyword!;
      // 延迟执行搜索，确保 UI 已经构建完成
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _performSearch();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchService.removeListener(_onSearchResultChanged);
    super.dispose();
  }

  void _onSearchResultChanged() {
    if (mounted) {
      setState(() {});
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

  void _performSearch() async {
    // 检查登录状态
    final isLoggedIn = await _checkLoginStatus();
    if (!isLoggedIn) return;

    final keyword = _searchController.text.trim();
    if (keyword.isNotEmpty) {
      _searchService.search(keyword);
      if (_currentTabIndex == 1) {
        _searchArtists(keyword);
      }
    }
  }

  void _triggerArtistSearchIfNeeded() {
    final keyword = _searchController.text.trim();
    if (keyword.isNotEmpty) {
      _searchArtists(keyword);
    }
  }

  Future<void> _searchArtists(String keyword) async {
    setState(() {
      _artistLoading = true;
      _artistError = null;
      _artistResults = [];
    });
    try {
      final results = await NeteaseArtistDetailService().searchArtists(keyword, limit: 20);
      if (!mounted) return;
      setState(() {
        _artistResults = results;
        _artistLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _artistLoading = false;
        _artistError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final searchResult = _searchService.searchResult;

    return SafeArea(
      bottom: false,
      child: Stack(
      children: [
        Column(
          children: [
            // 搜索栏
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: widget.onClose,
                    tooltip: '返回',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: '搜索歌曲、歌手...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _searchService.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _performSearch(),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _performSearch,
                    child: const Text('搜索'),
                  ),
                ],
              ),
            ),

            // 选项卡 + 结果区域
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      onTap: (index) {
                        setState(() {
                          _currentTabIndex = index;
                        });
                        if (index == 1) _triggerArtistSearchIfNeeded();
                      },
                      tabs: const [
                        Tab(text: '歌曲'),
                        Tab(text: '歌手'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildSongResults(searchResult),
                          _buildArtistResults(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // 覆盖搜索栏的二级详情层（歌手/专辑）
        if (_secondaryArtistId != null || _secondaryAlbumId != null)
          Positioned.fill(
            child: Material(
              color: colorScheme.surface,
              child: Column(
                children: [
                  // 顶部面包屑栏
                  SafeArea(
                    bottom: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () {
                              setState(() {
                                if (_secondaryAlbumId != null) {
                                  _secondaryAlbumId = null;
                                } else {
                                  _secondaryArtistId = null;
                                  _secondaryArtistName = null;
                                }
                              });
                            },
                            tooltip: '返回',
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _secondaryAlbumId != null
                                  ? (_secondaryAlbumName ?? '专辑详情')
                                  : (_secondaryArtistName ?? '歌手详情'),
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  // 内容
                  Expanded(
                    child: _secondaryAlbumId != null
                        ? AlbumDetailPage(albumId: _secondaryAlbumId!, embedded: true)
                        : ArtistDetailContent(
                            artistId: _secondaryArtistId!,
                            onOpenAlbum: (albumId) {
                              setState(() {
                                _secondaryAlbumId = albumId;
                                _secondaryAlbumName = null;
                              });
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ));
  }

  Widget _buildSongResults(SearchResult result) {
    // 如果没有搜索或搜索结果为空，显示搜索历史
    if (_searchService.currentKeyword.isEmpty) {
      return _buildSearchHistory();
    }

    // 显示加载状态
    final isLoading = result.neteaseLoading || result.qqLoading || result.kugouLoading;
    
    // 获取合并后的结果
    final mergedResults = _searchService.getMergedResults();

    // 如果所有平台都加载完成且没有结果
    if (result.allCompleted && mergedResults.isEmpty) {
      return _buildEmptyState(
        icon: Icons.music_off,
        title: '没有找到相关歌曲',
        subtitle: '试试其他关键词吧',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 搜索统计
        _buildSearchHeader(mergedResults.length, result),
        
        const SizedBox(height: 16),
        
        // 加载提示
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('搜索中...'),
                ],
              ),
            ),
          ),
        
        // 合并后的歌曲列表
        ...mergedResults.map((mergedTrack) => _buildMergedTrackItem(mergedTrack)),
      ],
    );
  }

  Widget _buildArtistResults() {
    final keyword = _searchService.currentKeyword;
    if (keyword.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_search,
        title: '搜索歌手',
        subtitle: '输入关键词后切换到“歌手”',
      );
    }

    if (_artistLoading && _secondaryArtistId == null && _secondaryAlbumId == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_artistError != null && _secondaryArtistId == null && _secondaryAlbumId == null) {
      return Center(child: Text('搜索失败: $_artistError'));
    }
    if (_artistResults.isEmpty && _secondaryArtistId == null && _secondaryAlbumId == null) {
      return _buildEmptyState(
        icon: Icons.person_off,
        title: '没有找到相关歌手',
        subtitle: '试试其他关键词吧',
      );
    }

    // 二级（面包屑）区域
    if (_secondaryArtistId != null || _secondaryAlbumId != null) {
      return Column(
        children: [
          // 面包屑栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      if (_secondaryAlbumId != null) {
                        _secondaryAlbumId = null; // 返回到歌手详情
                      } else {
                        _secondaryArtistId = null; // 返回到歌手列表
                        _secondaryArtistName = null;
                      }
                    });
                  },
                  tooltip: '返回',
                ),
                const SizedBox(width: 4),
                Text(
                  _secondaryAlbumId != null
                      ? (_secondaryAlbumName ?? '专辑详情')
                      : (_secondaryArtistName ?? '歌手详情'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _secondaryAlbumId != null
                ? AlbumDetailPage(albumId: _secondaryAlbumId!, embedded: true)
                : ArtistDetailContent(
                    artistId: _secondaryArtistId!,
                    onOpenAlbum: (albumId) {
                      setState(() {
                        _secondaryAlbumId = albumId;
                        _secondaryAlbumName = null; // 可在专辑页加载后更新
                      });
                    },
                  ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _artistResults.length,
      itemBuilder: (context, index) {
        final artist = _artistResults[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: artist.picUrl.isEmpty
                  ? CircleAvatar(radius: 24, child: Icon(Icons.person, color: Theme.of(context).colorScheme.onSurfaceVariant))
                  : CachedNetworkImage(
                      imageUrl: artist.picUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 48,
                        height: 48,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      ),
                    ),
            ),
            title: Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              setState(() {
                _secondaryArtistId = artist.id;
                _secondaryArtistName = artist.name;
              });
            },
          ),
        );
      },
    );
  }

  /// 构建搜索头部（统计信息）
  Widget _buildSearchHeader(int totalCount, SearchResult result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            const Icon(Icons.music_note, size: 20),
            const SizedBox(width: 8),
            Text(
              '找到 $totalCount 首歌曲',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建合并后的歌曲项
  Widget _buildMergedTrackItem(MergedTrack mergedTrack) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CachedNetworkImage(
            imageUrl: mergedTrack.picUrl,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 50,
              height: 50,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.music_note,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        title: Text(
          mergedTrack.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${mergedTrack.artists} • ${mergedTrack.album}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        // 点击直接播放
        onTap: () => _playMergedTrack(mergedTrack),
        // 长按显示平台选择菜单
        onLongPress: () => _showPlatformSelector(mergedTrack),
      ),
    );
  }

  /// 播放合并后的歌曲（按优先级选择平台）
  void _playMergedTrack(MergedTrack mergedTrack) async {
    // 检查登录状态
    final isLoggedIn = await _checkLoginStatus();
    if (!isLoggedIn) return;

    final bestTrack = mergedTrack.getBestTrack();
    // 播放前注入封面 Provider，避免播放器再次请求
    ImageProvider? provider;
    if (bestTrack.picUrl.isNotEmpty) {
      provider = CachedNetworkImageProvider(bestTrack.picUrl);
      PlayerService().setCurrentCoverImageProvider(provider);
    }
    PlayerService().playTrack(bestTrack, coverProvider: provider);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('正在播放: ${mergedTrack.name}'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// 显示平台选择器（长按时）
  void _showPlatformSelector(MergedTrack mergedTrack) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择播放平台',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mergedTrack.name,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ...mergedTrack.tracks.map((track) => ListTile(
              leading: Text(
                track.getSourceIcon(),
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(track.getSourceName()),
              subtitle: Text(track.album),
              trailing: const Icon(Icons.play_arrow),
              onTap: () async {
                Navigator.pop(context);
                // 检查登录状态
                final isLoggedIn = await _checkLoginStatus();
                if (isLoggedIn && mounted) {
                  if (track.picUrl.isNotEmpty) {
                    final provider = CachedNetworkImageProvider(track.picUrl);
                    PlayerService().setCurrentCoverImageProvider(provider);
                    PlayerService().playTrack(track, coverProvider: provider);
                  } else {
                    PlayerService().playTrack(track);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('正在播放: ${track.name}'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              },
            )),
          ],
        ),
      ),
    );
  }

  /// 构建搜索历史列表
  Widget _buildSearchHistory() {
    final history = _searchService.searchHistory;
    final colorScheme = Theme.of(context).colorScheme;

    // 如果没有历史记录，显示空状态
    if (history.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search,
        title: '搜索音乐',
        subtitle: '支持网易云、QQ音乐、酷狗音乐',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 标题栏
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  '搜索历史',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('清空搜索历史'),
                    content: const Text('确定要清空所有搜索历史吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () {
                          _searchService.clearSearchHistory();
                          Navigator.pop(context);
                        },
                        child: const Text('清空'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('清空'),
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // 历史记录列表
        ...history.map((keyword) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              Icons.history,
              color: colorScheme.primary,
            ),
            title: Text(keyword),
            trailing: IconButton(
              icon: Icon(
                Icons.close,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: () {
                _searchService.removeSearchHistory(keyword);
              },
              tooltip: '删除',
            ),
            onTap: () {
              // 点击历史记录进行搜索
              _searchController.text = keyword;
              _performSearch();
            },
          ),
        )),
        
        const SizedBox(height: 16),
        
        // 提示信息
        Center(
          child: Text(
            '点击历史记录快速搜索',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
          ),
        ],
      ),
    );
  }

}

