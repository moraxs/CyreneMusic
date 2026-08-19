part of 'my_page.dart';

/// Cupertino UI 构建方法
extension MyPageCupertinoUI on _MyPageState {
  Widget _buildCupertinoPage(BuildContext context, bool isLoggedIn) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    if (!isLoggedIn) return _buildCupertinoLoginPrompt(context, isDark);
    if (_selectedPlaylist != null) return _buildCupertinoPlaylistDetail(_selectedPlaylist!);
    return _buildCupertinoMainView(context, isDark);
  }

  Widget _buildCupertinoLoginPrompt(BuildContext context, bool isDark) {
    return CupertinoPageScaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : CupertinoColors.systemGroupedBackground,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(color: CupertinoColors.systemBlue.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(CupertinoIcons.person_fill, size: 50, color: CupertinoColors.systemBlue),
            ),
            const SizedBox(height: 24),
            Text('登录后查看更多', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? CupertinoColors.white : CupertinoColors.black)),
            const SizedBox(height: 8),
            Text('登录即可管理歌单和查看听歌统计', style: TextStyle(fontSize: 15, color: CupertinoColors.systemGrey)),
            const SizedBox(height: 32),
            CupertinoButton.filled(onPressed: () => showAuthDialog(context).then((_) { refresh(); }), child: const Text('立即登录')),
          ],
        ),
      ),
    );
  }

  Widget _buildCupertinoMainView(BuildContext context, bool isDark) {
    return CupertinoPageScaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(middle: const Text('我的'), backgroundColor: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.systemBackground),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: () async { await _playlistService.loadPlaylists(); await _loadStats(); }),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCupertinoUserCard(isDark),
                    const SizedBox(height: 16),
                    _buildCupertinoStatsCard(isDark),
                    const SizedBox(height: 24),
                    _buildCupertinoSectionHeader('我的歌单', isDark, actions: [
                      CupertinoButton(padding: EdgeInsets.zero, onPressed: _showMusicTasteDialog, child: const Icon(CupertinoIcons.sparkles, size: 22)),
                      CupertinoButton(padding: EdgeInsets.zero, onPressed: _showImportPlaylistDialog, child: const Icon(CupertinoIcons.cloud_download, size: 22)),
                      const SizedBox(width: 8),
                      CupertinoButton(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), color: CupertinoColors.systemBlue, borderRadius: BorderRadius.circular(16), onPressed: _showCreatePlaylistDialog, child: const Text('新建', style: TextStyle(fontSize: 14, color: CupertinoColors.white))),
                    ]),
                    const SizedBox(height: 12),
                    _buildCupertinoPlaylistsList(isDark),
                    const SizedBox(height: 24),
                    if (_statsData != null && _statsData!.playCounts.isNotEmpty) ...[
                      _buildCupertinoSectionHeader('播放排行榜 Top 10', isDark),
                      const SizedBox(height: 12),
                      _buildCupertinoTopPlaysList(isDark),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCupertinoSectionHeader(String title, bool isDark, {List<Widget>? actions}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? CupertinoColors.white : CupertinoColors.black)),
        if (actions != null) Row(mainAxisSize: MainAxisSize.min, children: actions),
      ],
    );
  }

  Widget _buildCupertinoUserCard(bool isDark) {
    final user = AuthService().currentUser;
    if (user == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(shape: BoxShape.circle, color: CupertinoColors.systemBlue.withOpacity(0.1)),
            child: user.avatarUrl != null
                ? (user.avatarUrl!.contains('linux.do')
                    ? ClipOval(child: LinuxDoAvatarMaterial(url: user.avatarUrl!, userId: user.id, size: 60))
                    : ClipOval(child: CachedNetworkImage(imageUrl: user.avatarUrl!, fit: BoxFit.cover, placeholder: (_, __) => const CupertinoActivityIndicator(), errorWidget: (_, __, ___) => Text(user.username[0].toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)))))
                : Center(child: Text(user.username[0].toUpperCase(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: CupertinoColors.systemBlue))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.username, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? CupertinoColors.white : CupertinoColors.black)),
                if (user.displayEmail != null) ...[
                  const SizedBox(height: 4),
                  Text(user.displayEmail!, style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey)),
                ],

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCupertinoStatsCard(bool isDark) {
    if (_isLoadingStats) {
      return Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white, borderRadius: BorderRadius.circular(12)), child: const Center(child: CupertinoActivityIndicator()));
    }
    if (_statsData == null) {
      return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white, borderRadius: BorderRadius.circular(12)), child: Text('暂无统计数据', style: TextStyle(color: CupertinoColors.systemGrey)));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('听歌统计', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? CupertinoColors.white : CupertinoColors.black)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildCupertinoStatTile(icon: CupertinoIcons.time, label: '累计时长', value: ListeningStatsService.formatDuration(_statsData!.totalListeningTime), isDark: isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildCupertinoStatTile(icon: CupertinoIcons.play_fill, label: '播放次数', value: '${_statsData!.totalPlayCount} 次', isDark: isDark)),
            ],
          ),
          const SizedBox(height: 12),
          // 听歌日历入口
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const ListeningCalendarPage()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.calendar, size: 20, color: CupertinoColors.systemBlue),
                  const SizedBox(width: 8),
                  Text('听歌日历', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? CupertinoColors.white : CupertinoColors.black)),
                  const Spacer(),
                  Icon(CupertinoIcons.chevron_forward, size: 16, color: CupertinoColors.systemGrey3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCupertinoStatTile({required IconData icon, required String label, required String value, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemGrey6, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: CupertinoColors.systemBlue),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? CupertinoColors.white : CupertinoColors.black)),
        ],
      ),
    );
  }

  Widget _buildCupertinoPlaylistsList(bool isDark) {
    final playlists = _playlistService.playlists;
    if (playlists.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white, borderRadius: BorderRadius.circular(12)),
        child: Center(child: Column(children: [Icon(CupertinoIcons.music_albums, size: 48, color: CupertinoColors.systemGrey), const SizedBox(height: 16), Text('暂无歌单', style: TextStyle(color: CupertinoColors.systemGrey))])),
      );
    }

    return Container(
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: playlists.asMap().entries.map((entry) {
          final index = entry.key;
          final playlist = entry.value;
          final isLast = index == playlists.length - 1;

          return Column(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _openPlaylistDetail(playlist),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _buildCupertinoPlaylistCover(playlist, isDark),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(playlist.name, style: TextStyle(fontSize: 16, color: isDark ? CupertinoColors.white : CupertinoColors.black)),
                            const SizedBox(height: 2),
                            Text('${playlist.trackCount} 首歌曲', style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey)),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _showPlaylistMoreOptionsCupertino(playlist, isDark),
                        child: Icon(CupertinoIcons.ellipsis, size: 20, color: CupertinoColors.systemGrey),
                      ),
                      const SizedBox(width: 4),
                      Icon(CupertinoIcons.chevron_forward, size: 18, color: CupertinoColors.systemGrey3),
                    ],
                  ),
                ),
              ),
              if (!isLast) Padding(padding: const EdgeInsets.only(left: 76), child: Container(height: 0.5, color: CupertinoColors.systemGrey4)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCupertinoPlaylistCover(Playlist playlist, bool isDark) {
    if (playlist.coverUrl != null && playlist.coverUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: playlist.coverUrl!, width: 48, height: 48, fit: BoxFit.cover,
          placeholder: (_, __) => Container(width: 48, height: 48, decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemGrey5, borderRadius: BorderRadius.circular(8)), child: Icon(playlist.isDefault ? CupertinoIcons.heart_fill : CupertinoIcons.music_albums, color: playlist.isDefault ? CupertinoColors.systemRed : CupertinoColors.systemBlue, size: 20)),
          errorWidget: (_, __, ___) => Container(width: 48, height: 48, decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemGrey5, borderRadius: BorderRadius.circular(8)), child: Icon(playlist.isDefault ? CupertinoIcons.heart_fill : CupertinoIcons.music_albums, color: playlist.isDefault ? CupertinoColors.systemRed : CupertinoColors.systemBlue, size: 20)),
        ),
      );
    }
    return Container(width: 48, height: 48, decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemGrey5, borderRadius: BorderRadius.circular(8)), child: Icon(playlist.isDefault ? CupertinoIcons.heart_fill : CupertinoIcons.music_albums, color: playlist.isDefault ? CupertinoColors.systemRed : CupertinoColors.systemBlue, size: 20));
  }

  Widget _buildCupertinoTopPlaysList(bool isDark) {
    final topPlays = _statsData!.playCounts.take(10).toList();
    return Container(
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: topPlays.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final rank = index + 1;
          final isLast = index == topPlays.length - 1;
          Color rankColor;
          if (rank == 1) rankColor = const Color(0xFFFFD700);
          else if (rank == 2) rankColor = const Color(0xFFC0C0C0);
          else if (rank == 3) rankColor = const Color(0xFFCD7F32);
          else rankColor = CupertinoColors.systemBlue;

          return Column(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _playTrack(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(
                              imageUrl: item.picUrl, width: 48, height: 48, fit: BoxFit.cover,
                              placeholder: (_, __) => Container(width: 48, height: 48, color: isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemGrey5, child: const Icon(CupertinoIcons.music_note, size: 20)),
                              errorWidget: (_, __, ___) => Container(width: 48, height: 48, color: isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemGrey5, child: const Icon(CupertinoIcons.music_note, size: 20)),
                            ),
                          ),
                          Positioned(left: 0, top: 0, child: Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: rankColor, borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), bottomRight: Radius.circular(6))), child: Text('$rank', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CupertinoColors.white)))),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.trackName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, color: isDark ? CupertinoColors.white : CupertinoColors.black)),
                            const SizedBox(height: 2),
                            Text(item.artists, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
                          ],
                        ),
                      ),
                      Row(mainAxisSize: MainAxisSize.min, children: [Icon(CupertinoIcons.play_fill, size: 12, color: CupertinoColors.systemGrey), const SizedBox(width: 4), Text('${item.playCount}', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey))]),
                    ],
                  ),
                ),
              ),
              if (!isLast) Padding(padding: const EdgeInsets.only(left: 76), child: Container(height: 0.5, color: CupertinoColors.systemGrey4)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCupertinoPlaylistDetail(Playlist playlist) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final allTracks = _playlistService.currentPlaylistId == playlist.id ? _playlistService.currentTracks : <PlaylistTrack>[];
    final isLoading = _playlistService.isLoadingTracks;
    final filteredTracks = _filterTracks(allTracks);

    return CupertinoPageScaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.systemBackground,
        leading: CupertinoButton(padding: EdgeInsets.zero, onPressed: _backToList, child: const Icon(CupertinoIcons.back)),
        middle: Text(_isEditMode ? '已选择 ${_selectedTrackIds.length} 首' : playlist.name),
        trailing: _isEditMode
            ? CupertinoButton(padding: EdgeInsets.zero, onPressed: _toggleEditMode, child: const Text('取消'))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (allTracks.isNotEmpty) CupertinoButton(padding: EdgeInsets.zero, onPressed: _toggleSearchMode, child: Icon(_isSearchMode ? CupertinoIcons.search : CupertinoIcons.search)),
                  if (allTracks.isNotEmpty) CupertinoButton(padding: EdgeInsets.zero, onPressed: _toggleEditMode, child: const Icon(CupertinoIcons.pencil)),
                ],
              ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (_isSearchMode) Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: CupertinoSearchTextField(controller: _searchController, placeholder: '搜索歌曲、歌手、专辑...', onChanged: _onSearchChanged)),
            if (_isEditMode)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.systemBackground,
                child: Row(
                  children: [
                    CupertinoButton(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), onPressed: allTracks.isNotEmpty ? _toggleSelectAll : null, child: Text(_selectedTrackIds.length == allTracks.length ? '取消全选' : '全选', style: const TextStyle(fontSize: 14))),
                    const Spacer(),
                    CupertinoButton(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), color: CupertinoColors.systemRed, borderRadius: BorderRadius.circular(16), onPressed: _selectedTrackIds.isNotEmpty ? _batchRemoveTracksCupertino : null, child: const Text('删除选中', style: TextStyle(fontSize: 14, color: CupertinoColors.white))),
                  ],
                ),
              ),
            Expanded(
              child: isLoading && allTracks.isEmpty
                  ? const Center(child: CupertinoActivityIndicator())
                  : allTracks.isEmpty
                      ? _buildCupertinoDetailEmptyState(isDark)
                      : filteredTracks.isEmpty && _searchQuery.isNotEmpty
                          ? _buildCupertinoSearchEmptyState(isDark)
                          : CustomScrollView(
                              slivers: [
                                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: _buildCupertinoDetailStatsCard(isDark, filteredTracks.length, totalCount: allTracks.length))),
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                                    final track = filteredTracks[index];
                                    final originalIndex = allTracks.indexOf(track);
                                    return _buildCupertinoTrackItem(track, originalIndex, isDark);
                                  }, childCount: filteredTracks.length)),
                                ),
                                const SliverToBoxAdapter(child: SizedBox(height: 40)),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCupertinoDetailStatsCard(bool isDark, int count, {int? totalCount}) {
    final String countText = (totalCount != null && totalCount != count) ? '筛选出 $count / 共 $totalCount 首' : '共 $count 首歌曲';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [

          Text(countText, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? CupertinoColors.white : CupertinoColors.black)),
          const Spacer(),
          if (count > 0)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: CupertinoColors.systemBlue,
              borderRadius: BorderRadius.circular(18),
              onPressed: _playAll,
              child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(CupertinoIcons.play_fill, size: 16, color: CupertinoColors.white), SizedBox(width: 6), Text('播放全部', style: TextStyle(fontSize: 14, color: CupertinoColors.white))]),
            ),
        ],
      ),
    );
  }

  Widget _buildCupertinoTrackItem(PlaylistTrack item, int index, bool isDark) {
    final trackKey = _getTrackKey(item);
    final isSelected = _selectedTrackIds.contains(trackKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: isSelected && _isEditMode ? CupertinoColors.systemBlue.withOpacity(0.1) : (isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white), borderRadius: BorderRadius.circular(10)),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _isEditMode ? () => _toggleTrackSelection(item) : () => _playDetailTrack(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (_isEditMode)
                Padding(padding: const EdgeInsets.only(right: 12), child: Icon(isSelected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle, color: isSelected ? CupertinoColors.systemBlue : CupertinoColors.systemGrey3, size: 24))
              else
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: item.picUrl, width: 50, height: 50, fit: BoxFit.cover,
                        placeholder: (_, __) => Container(width: 50, height: 50, color: isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemGrey5, child: const Center(child: CupertinoActivityIndicator(radius: 10))),
                        errorWidget: (_, __, ___) => Container(width: 50, height: 50, color: isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemGrey5, child: const Icon(CupertinoIcons.music_note, size: 20)),
                      ),
                    ),
                    Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: CupertinoColors.systemBlue, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4))), child: Text('#${index + 1}', style: const TextStyle(color: CupertinoColors.white, fontSize: 9, fontWeight: FontWeight.bold)))),
                  ],
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, color: isDark ? CupertinoColors.white : CupertinoColors.black)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(child: Text('${item.artists} • ${item.album}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey))),

                      ],
                    ),
                  ],
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCupertinoDetailEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.music_note_2, size: 64, color: CupertinoColors.systemGrey),
          const SizedBox(height: 16),
          Text('歌单为空', style: TextStyle(fontSize: 16, color: isDark ? CupertinoColors.white : CupertinoColors.black)),
          const SizedBox(height: 8),
          Text('快去添加一些喜欢的歌曲吧', style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey)),
        ],
      ),
    );
  }

  Widget _buildCupertinoSearchEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.search, size: 64, color: CupertinoColors.systemGrey),
          const SizedBox(height: 16),
          Text('未找到匹配的歌曲', style: TextStyle(fontSize: 16, color: isDark ? CupertinoColors.white : CupertinoColors.black)),
          const SizedBox(height: 8),
          Text('尝试其他关键词', style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey)),
        ],
      ),
    );
  }

  /// 显示歌单更多操作 (Cupertino)
  void _showPlaylistMoreOptionsCupertino(Playlist playlist, bool isDark) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(playlist.name),
        message: Text('共 ${playlist.trackCount} 首歌曲'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _openPlaylistDetail(playlist);
            },
            child: const Text('播放全部'),
          ),
          if (_hasImportConfig(playlist))
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _syncPlaylistFromList(playlist);
              },
              child: const Text('同步歌单'),
            ),
          if (!playlist.isDefault)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _confirmDeletePlaylistCupertino(playlist);
              },
              isDestructiveAction: true,
              child: const Text('删除歌单'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDefaultAction: true,
          child: const Text('取消'),
        ),
      ),
    );
  }

  /// 确认删除歌单 (Cupertino)
  Future<void> _confirmDeletePlaylistCupertino(Playlist playlist) async {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('删除歌单'),
        content: Text('确定要删除歌单「${playlist.name}」吗？\n删除后将无法恢复。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              final success = await _playlistService.deletePlaylist(playlist.id);
              _showCupertinoToast(success ? '歌单已删除' : '删除失败');
              if (success && _selectedPlaylist?.id == playlist.id) {
                _backToList();
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }



  /// 批量移除单曲 (Cupertino)
  Future<void> _batchRemoveTracksCupertino() async {
    if (_selectedPlaylist == null || _selectedTrackIds.isEmpty) return;

    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('批量删除'),
        content: Text('确定要删除选中的 ${_selectedTrackIds.length} 首歌曲吗？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              final tracksToDelete = _playlistService.currentTracks
                  .where((track) => _selectedTrackIds.contains(_getTrackKey(track)))
                  .toList();

              final deletedCount = await _playlistService.removeTracksFromPlaylist(
                _selectedPlaylist!.id,
                tracksToDelete,
              );

              _showCupertinoToast('已删除 $deletedCount 首歌曲');

              setState(() {
                _isEditMode = false;
                _selectedTrackIds.clear();
              });
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
