import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/track.dart';
import '../models/merged_track.dart';
import '../services/search_service.dart';
import '../services/player_service.dart';

/// 搜索组件（内嵌版本）
class SearchWidget extends StatefulWidget {
  final VoidCallback onClose;

  const SearchWidget({
    super.key,
    required this.onClose,
  });

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final SearchService _searchService = SearchService();
  
  @override
  void initState() {
    super.initState();
    _searchService.addListener(_onSearchResultChanged);
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

  void _performSearch() {
    final keyword = _searchController.text.trim();
    if (keyword.isNotEmpty) {
      _searchService.search(keyword);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final searchResult = _searchService.searchResult;

    return Column(
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

        // 搜索结果
        Expanded(
          child: _buildSearchResults(searchResult),
        ),
      ],
    );
  }

  Widget _buildSearchResults(SearchResult result) {
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
            const Spacer(),
            // 平台统计
            if (result.neteaseResults.isNotEmpty) ...[
              const Text('🎵', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 2),
              Text(
                '${result.neteaseResults.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
            ],
            if (result.qqResults.isNotEmpty) ...[
              const Text('🎶', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 2),
              Text(
                '${result.qqResults.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
            ],
            if (result.kugouResults.isNotEmpty) ...[
              const Text('🎼', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 2),
              Text(
                '${result.kugouResults.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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
  void _playMergedTrack(MergedTrack mergedTrack) {
    final bestTrack = mergedTrack.getBestTrack();
    PlayerService().playTrack(bestTrack);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('正在播放: ${mergedTrack.name}'),
        duration: const Duration(seconds: 1),
      ),
    );
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
              onTap: () {
                Navigator.pop(context);
                PlayerService().playTrack(track);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('正在播放: ${track.name}'),
                    duration: const Duration(seconds: 1),
                  ),
                );
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

