part of 'my_page.dart';

/// Fluent UI 构建方法
extension MyPageFluentUI on _MyPageState {
  Widget _buildFluentPage(BuildContext context, bool isLoggedIn) {
    if (!isLoggedIn) {
      return fluent.ScaffoldPage(
        padding: EdgeInsets.zero,
        content: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(fluent.FluentIcons.contact, size: 80),
              const SizedBox(height: 24),
              const Text('登录后查看更多',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('登录即可管理歌单和查看听歌统计'),
              const SizedBox(height: 24),
              fluent.FilledButton(
                onPressed: () async {
                  final result = await showFluentLoginDialog(context);
                  if (result == true) {
                    refresh();
                  }
                },
                child: const Text('立即登录'),
              ),
            ],
          ),
        ),
      );
    }

    return _buildSlidingSwitcher(
      _selectedPlaylist != null
          ? _buildFluentPlaylistDetailPage(_selectedPlaylist!)
          : _buildFluentMainPage(context),
    );
  }

  Widget _buildFluentMainPage(BuildContext context) {
    final brightness = switch (_themeManager.themeMode) {
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
      ThemeMode.dark => Brightness.dark,
      _ => Brightness.light,
    };
    final materialTheme = _themeManager.buildThemeData(brightness);

    return fluent.ScaffoldPage(
      key: const ValueKey('my_page_main'),
      padding: EdgeInsets.zero,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FluentMyPageBreadcrumbs(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            items: const [
              MyPageBreadcrumbItem(
                label: '我的',
                isCurrent: true,
              ),
            ],
          ),
          Expanded(
            child: Theme(
              data: materialTheme,
              child: Material(
                color: Colors.transparent,
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _playlistService.loadPlaylists();
                    await _loadStats();
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildMaterialUserCard(materialTheme.colorScheme),
                        const SizedBox(height: 16),
                        if (_isLoadingStats)
                          const fluent.Card(
                              padding: EdgeInsets.all(16),
                              child: Center(child: fluent.ProgressRing()))
                        else if (_statsData == null)
                          fluent.InfoBar(
                              title: const Text('暂无统计数据'),
                              severity: fluent.InfoBarSeverity.info)
                        else
                          _buildFluentStatsCard(),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('我的歌单',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Microsoft YaHei')),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                fluent.IconButton(
                                    icon: const Icon(fluent.FluentIcons.auto_enhance_on),
                                    onPressed: _showMusicTasteDialog),
                                fluent.IconButton(
                                    icon: const Icon(fluent.FluentIcons.cloud_download),
                                    onPressed: _showImportPlaylistDialog),
                                const SizedBox(width: 8),
                                fluent.FilledButton(
                                    onPressed: _showCreatePlaylistDialog,
                                    child: const Text('新建')),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildFluentPlaylistsList(),
                        const SizedBox(height: 24),
                        if (_statsData != null &&
                            _statsData!.playCounts.isNotEmpty) ...[
                          const Text('播放排行榜 Top 10',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Microsoft YaHei')),
                          const SizedBox(height: 8),
                          _buildFluentTopPlaysList(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlidingSwitcher(Widget child) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) =>
          _buildSlideTransition(child, animation),
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: child,
    );
  }

  Widget _buildSlideTransition(Widget child, Animation<double> animation) {
    final bool isEntering = animation.status == AnimationStatus.forward;

    Offset begin;
    if (_reverseTransition) {
      begin = isEntering ? const Offset(-0.05, 0.0) : const Offset(0.05, 0.0);
    } else {
      begin = isEntering ? const Offset(0.05, 0.0) : const Offset(-0.05, 0.0);
    }

    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final positionAnimation = Tween<Offset>(
      begin: begin,
      end: Offset.zero,
    ).animate(curvedAnimation);

    return SlideTransition(
      position: positionAnimation,
      child: FadeTransition(opacity: curvedAnimation, child: child),
    );
  }

  Widget _buildFluentPlaylistDetailPage(Playlist playlist) {
    final allTracks = _playlistService.currentPlaylistId == playlist.id ? _playlistService.currentTracks : <PlaylistTrack>[];
    final isLoading = _playlistService.isLoadingTracks;
    final filteredTracks = _filterTracks(allTracks);

    return fluent.ScaffoldPage(
      key: ValueKey('my_page_playlist_${playlist.id}'),
      padding: EdgeInsets.zero,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _isEditMode
                      ? Text('已选择 ${_selectedTrackIds.length} 首',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis)
                      : FluentMyPageBreadcrumbs(
                          padding: EdgeInsets.zero,
                          items: [
                            MyPageBreadcrumbItem(
                              label: '我的',
                              onTap: _backToList,
                              isEmphasized: true,
                            ),
                            MyPageBreadcrumbItem(
                              label: playlist.name,
                              isCurrent: true,
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 8),
                if (_isEditMode) ...[
                  fluent.Button(
                      onPressed: allTracks.isNotEmpty ? _toggleSelectAll : null,
                      child: Text(
                          _selectedTrackIds.length == allTracks.length
                              ? '取消全选'
                              : '全选')),
                  const SizedBox(width: 8),
                  fluent.FilledButton(
                      onPressed: _selectedTrackIds.isNotEmpty
                          ? _batchRemoveTracks
                          : null,
                      child: const Text('删除选中')),
                  const SizedBox(width: 8),
                  fluent.Button(onPressed: _toggleEditMode, child: const Text('取消')),
                ] else ...[
                  if (allTracks.isNotEmpty) ...[
                    fluent.IconButton(
                        icon: Icon(_isSearchMode
                            ? fluent.FluentIcons.search_and_apps
                            : fluent.FluentIcons.search),
                        onPressed: _toggleSearchMode),
                    const SizedBox(width: 4),
                  ],
                  if (allTracks.isNotEmpty) ...[
                    fluent.IconButton(
                        icon: const Icon(fluent.FluentIcons.switch_widget),
                        onPressed: () =>
                            _showSourceSwitchDialog(playlist, allTracks)),
                    const SizedBox(width: 4),
                  ],
                  if (allTracks.isNotEmpty) ...[
                    fluent.IconButton(
                        icon: const Icon(fluent.FluentIcons.edit),
                        onPressed: _toggleEditMode),
                    const SizedBox(width: 4),
                  ],
                  fluent.IconButton(
                    icon: const Icon(fluent.FluentIcons.sync),
                    onPressed: () async {
                      if (!_hasImportConfig(playlist)) {
                        fluent.displayInfoBar(context,
                            builder: (context, close) => fluent.InfoBar(
                                title: const Text('同步'),
                                content: const Text('请先在"导入管理"中绑定来源后再同步'),
                                severity: fluent.InfoBarSeverity.warning,
                                action: fluent.IconButton(
                                    icon: const Icon(fluent.FluentIcons.clear),
                                    onPressed: close)));
                        return;
                      }
                      fluent.displayInfoBar(context,
                          builder: (context, close) => fluent.InfoBar(
                              title: const Text('同步'),
                              content: const Text('正在同步...'),
                              severity: fluent.InfoBarSeverity.info,
                              action: fluent.IconButton(
                                  icon: const Icon(fluent.FluentIcons.clear),
                                  onPressed: close)));
                      final result = await _playlistService.syncPlaylist(playlist.id);
                      if (!mounted) return;
                      fluent.displayInfoBar(context,
                          builder: (context, close) => fluent.InfoBar(
                              title: const Text('同步完成'),
                              content: Text(_formatSyncResultMessage(result)),
                              severity: fluent.InfoBarSeverity.success,
                              action: fluent.IconButton(
                                  icon: const Icon(fluent.FluentIcons.clear),
                                  onPressed: close)));
                      await _playlistService.loadPlaylistTracks(playlist.id);
                    },
                  ),
                ],
              ],
            ),
          ),
          if (_isSearchMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: fluent.TextBox(
                controller: _searchController,
                placeholder: '搜索歌曲、歌手、专辑...',
                prefix: const Padding(padding: EdgeInsets.only(left: 8), child: Icon(fluent.FluentIcons.search, size: 16)),
                suffix: _searchQuery.isNotEmpty ? fluent.IconButton(icon: const Icon(fluent.FluentIcons.clear, size: 12), onPressed: () { _searchController.clear(); _onSearchChanged(''); }) : null,
                onChanged: _onSearchChanged,
                autofocus: true,
              ),
            ),
          if (isLoading && allTracks.isEmpty)
            const Expanded(child: Center(child: fluent.ProgressRing()))
          else if (allTracks.isEmpty)
            Expanded(child: _buildFluentDetailEmptyState())
          else if (filteredTracks.isEmpty && _searchQuery.isNotEmpty)
            Expanded(child: _buildFluentSearchEmptyState())
          else ...[
            Padding(padding: const EdgeInsets.all(16.0), child: _buildFluentDetailStatisticsCard(filteredTracks.length, totalCount: allTracks.length)),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemBuilder: (context, index) {
                  final track = filteredTracks[index];
                  final originalIndex = allTracks.indexOf(track);
                  final isSelected = _selectedTrackIds.contains(_getTrackKey(track));
                  return RepaintBoundary(
                    child: _FluentMyTrackTile(
                      item: track,
                      index: originalIndex,
                      isEditMode: _isEditMode,
                      isSelected: isSelected,
                      onToggleSelection: () => _toggleTrackSelection(track),
                      onPlay: () => _playDetailTrack(originalIndex),
                      onDelete: () => _confirmRemoveTrack(track),
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: filteredTracks.length,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFluentSearchEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(fluent.FluentIcons.search, size: 64),
          SizedBox(height: 16),
          Text('未找到匹配的歌曲'),
          SizedBox(height: 8),
          Text('尝试其他关键词', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFluentDetailStatisticsCard(int count, {int? totalCount}) {
    final String countText = (totalCount != null && totalCount != count) ? '筛选出 $count / 共 $totalCount 首' : '共 $count 首';
    return fluent.Card(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Icon(fluent.FluentIcons.music_in_collection, size: 20),
          const SizedBox(width: 12),
          const Text('歌曲', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text(countText),
          const Spacer(),
          if (count > 0) fluent.FilledButton(onPressed: _playAll, child: const Text('播放全部')),
        ],
      ),
    );
  }

  Widget _buildFluentDetailEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(fluent.FluentIcons.music_in_collection, size: 64),
          SizedBox(height: 16),
          Text('歌单为空'),
          SizedBox(height: 8),
          Text('快去添加一些喜欢的歌曲吧', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

/// 独立的歌单单曲组件，用于性能优化
class _FluentMyTrackTile extends StatelessWidget {
  final PlaylistTrack item;
  final int index;
  final bool isEditMode;
  final bool isSelected;
  final VoidCallback onToggleSelection;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const _FluentMyTrackTile({
    required this.item,
    required this.index,
    required this.isEditMode,
    required this.isSelected,
    required this.onToggleSelection,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    final resources = theme.resources;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: fluent.Card(
        borderRadius: BorderRadius.circular(12),
        padding: EdgeInsets.zero,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isEditMode ? onToggleSelection : onPlay,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isEditMode) ...[
                  fluent.Checkbox(
                    checked: isSelected,
                    onChanged: (_) => onToggleSelection(),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${index + 1}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: resources.textFillColorSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: item.picUrl,
                    width: 64,
                    height: 64,
                    memCacheWidth: 128,
                    memCacheHeight: 128,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 64,
                      height: 64,
                      color: resources.controlAltFillColorSecondary,
                      alignment: Alignment.center,
                      child: const fluent.ProgressRing(strokeWidth: 2),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 64,
                      height: 64,
                      color: resources.controlAltFillColorSecondary,
                      alignment: Alignment.center,
                      child: Icon(
                        fluent.FluentIcons.music_in_collection,
                        color: resources.textFillColorTertiary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.artists} • ${item.album}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: resources.textFillColorSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isEditMode) ...[
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      fluent.IconButton(
                        icon: const Icon(fluent.FluentIcons.play),
                        onPressed: onPlay,
                      ),
                      fluent.IconButton(
                        icon: const Icon(fluent.FluentIcons.delete),
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension MyPageFluentUIComponents on _MyPageState {

  Widget _buildFluentStatsCard() {
    final stats = _statsData!;
    return fluent.Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('听歌统计', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildFluentStatTile(icon: fluent.FluentIcons.time_picker, label: '累计时长', value: ListeningStatsService.formatDuration(stats.totalListeningTime))),
              const SizedBox(width: 16),
              Expanded(child: _buildFluentStatTile(icon: fluent.FluentIcons.play, label: '播放次数', value: '${stats.totalPlayCount} 次')),
            ],
          ),
          const SizedBox(height: 12),
          // 听歌日历入口
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                fluent.FluentPageRoute(builder: (_) => const ListeningCalendarPage()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: fluent.FluentTheme.of(context).resources.controlAltFillColorSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(fluent.FluentIcons.calendar, size: 18),
                  const SizedBox(width: 8),
                  const Text('听歌日历', style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  const Icon(fluent.FluentIcons.chevron_right, size: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFluentStatTile({required IconData icon, required String label, required String value}) {
    final theme = fluent.FluentTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: theme.resources.controlAltFillColorSecondary, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: theme.resources.textFillColorSecondary)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFluentPlaylistsList() {
    final playlists = _playlistService.playlists;
    final theme = fluent.FluentTheme.of(context);

    if (playlists.isEmpty) {
      return fluent.Card(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(fluent.FluentIcons.music_in_collection, size: 48, color: theme.resources.textFillColorTertiary),
              const SizedBox(height: 16),
              Text('暂无歌单', style: TextStyle(color: theme.resources.textFillColorSecondary, fontFamily: 'Microsoft YaHei')),
            ],
          ),
        ),
      );
    }

    return Column(
      children: playlists.map((playlist) {
        final canSync = _hasImportConfig(playlist);
        return RepaintBoundary(
          child: _FluentMyPlaylistTile(
            playlist: playlist,
            canSync: canSync,
            onTap: () => _openPlaylistDetail(playlist),
            onSync: () => _syncPlaylistFromList(playlist),
            onDelete: () => _confirmDeletePlaylist(playlist),
          ),
        );
      }).toList(),
    );
  }
}

/// 独立的歌单列表项组件，用于性能优化
class _FluentMyPlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final bool canSync;
  final VoidCallback onTap;
  final VoidCallback onSync;
  final VoidCallback onDelete;

  const _FluentMyPlaylistTile({
    required this.playlist,
    required this.canSync,
    required this.onTap,
    required this.onSync,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    final resources = theme.resources;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: fluent.Card(
        borderRadius: BorderRadius.circular(12),
        padding: EdgeInsets.zero,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildCover(theme, resources),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${playlist.trackCount} 首歌曲',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: resources.textFillColorSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!playlist.isDefault) ...[
                      fluent.IconButton(
                        icon: Icon(
                          fluent.FluentIcons.sync,
                          color: canSync ? theme.accentColor : resources.textFillColorDisabled,
                        ),
                        onPressed: canSync ? onSync : null,
                      ),
                      fluent.IconButton(
                        icon: const Icon(fluent.FluentIcons.delete, color: Colors.redAccent),
                        onPressed: onDelete,
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(fluent.FluentIcons.chevron_right, size: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover(fluent.FluentThemeData theme, fluent.ResourceDictionary resources) {
    final hasCover = playlist.coverUrl != null && playlist.coverUrl!.isNotEmpty;
    final defaultIcon = Icon(
      playlist.isDefault ? fluent.FluentIcons.heart_fill : fluent.FluentIcons.music_in_collection,
      color: playlist.isDefault ? Colors.red : theme.accentColor,
      size: 24,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: hasCover
          ? CachedNetworkImage(
              imageUrl: playlist.coverUrl!,
              width: 64,
              height: 64,
              memCacheWidth: 128,
              memCacheHeight: 128,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 64,
                height: 64,
                color: resources.controlAltFillColorSecondary,
                alignment: Alignment.center,
                child: const fluent.ProgressRing(strokeWidth: 2),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 64,
                height: 64,
                color: resources.controlAltFillColorSecondary,
                alignment: Alignment.center,
                child: defaultIcon,
              ),
            )
          : Container(
              width: 64,
              height: 64,
              color: resources.controlAltFillColorSecondary,
              alignment: Alignment.center,
              child: defaultIcon,
            ),
    );
  }
}

extension MyPageFluentUITopPlays on _MyPageState {

  Widget _buildFluentTopPlaysList() {
    final topPlays = _statsData!.playCounts.take(10).toList();
    final theme = fluent.FluentTheme.of(context);

    return Column(
      children: topPlays.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final rank = index + 1;
        Color? rankColor;
        if (rank == 1) rankColor = Colors.amber;
        else if (rank == 2) rankColor = Colors.grey[400];
        else if (rank == 3) rankColor = Colors.orange[300];

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: fluent.Card(
            borderRadius: BorderRadius.circular(12),
            padding: EdgeInsets.zero,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _playTrack(item),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        '$rank',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: rankColor ?? theme.accentColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: item.picUrl,
                        width: 56,
                        height: 56,
                        memCacheWidth: 128,
                        memCacheHeight: 128,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 56,
                          height: 56,
                          color: theme.resources.controlAltFillColorSecondary,
                          alignment: Alignment.center,
                          child: const fluent.ProgressRing(strokeWidth: 2),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 56,
                          height: 56,
                          color: theme.resources.controlAltFillColorSecondary,
                          alignment: Alignment.center,
                          child: Icon(
                            fluent.FluentIcons.music_in_collection,
                            color: theme.resources.textFillColorTertiary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.trackName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.artists,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.resources.textFillColorSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(fluent.FluentIcons.play, size: 12, color: theme.resources.textFillColorSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${item.playCount}',
                          style: TextStyle(
                            color: theme.resources.textFillColorSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
