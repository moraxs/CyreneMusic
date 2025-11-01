import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import '../services/player_service.dart';
import '../pages/player_page.dart';
import '../services/playlist_queue_service.dart';
import '../services/play_history_service.dart';
import '../models/track.dart';

/// 迷你播放器组件（底部播放栏）
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> with SingleTickerProviderStateMixin {
  bool _isCollapsed = false;
  bool _autoCollapseEnabled = false;
  Timer? _collapseTimer;
  String? _lastTrackKey;
  AnimationController? _breathingController;
  Animation<double>? _breathingScale;
  bool _breathingActive = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _breathingController?.dispose();
    super.dispose();
  }

  void _configureAutoCollapse(bool enable) {
    if (_autoCollapseEnabled == enable) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _autoCollapseEnabled = enable;
        if (!_autoCollapseEnabled) {
          _collapseTimer?.cancel();
          _isCollapsed = false;
        } else {
          _scheduleCollapseTimer();
        }
      });
      if (!enable) {
        _setBreathingActive(false);
      }
    });
  }

  void _scheduleCollapseTimer() {
    _collapseTimer?.cancel();
    if (!_autoCollapseEnabled) return;
    _collapseTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || !_autoCollapseEnabled) return;
      setState(() {
        _isCollapsed = true;
      });
      _setBreathingActive(true);
    });
  }

  void _resetCollapseTimer({bool expand = false}) {
    if (!_autoCollapseEnabled) return;
    _collapseTimer?.cancel();
    if (expand && _isCollapsed) {
      setState(() {
        _isCollapsed = false;
      });
      _setBreathingActive(false);
    }
    _scheduleCollapseTimer();
  }

  void _handlePointerDown() {
    if (!_autoCollapseEnabled) return;
    _collapseTimer?.cancel();
  }

  void _setBreathingActive(bool active) {
    if (_breathingActive == active) return;
    _breathingActive = active;
    if (active) {
      final controller = _breathingController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2800),
      );
      _breathingScale ??= Tween<double>(begin: 0.94, end: 1.06).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
      controller
        ..reset()
        ..repeat(reverse: true);
    } else {
      _breathingController?.stop();
      _breathingController?.reset();
    }
  }

  void _handleTrackChange(String? trackKey) {
    if (_lastTrackKey == trackKey) return;
    _lastTrackKey = trackKey;
    if (!_autoCollapseEnabled) {
      if (_isCollapsed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _isCollapsed = false);
          }
        });
        _setBreathingActive(false);
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isCollapsed = false;
      });
      _setBreathingActive(false);
      _scheduleCollapseTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: PlayerService(),
      builder: (context, child) {
        final player = PlayerService();
        final track = player.currentTrack;
        final song = player.currentSong;

        final mediaQuery = MediaQuery.of(context);
        final bool isCompactWidth = mediaQuery.size.width < 600;
        final bool isPortrait = mediaQuery.orientation == Orientation.portrait;
        final bool hasContent = track != null || song != null;

        _configureAutoCollapse(hasContent && isCompactWidth && isPortrait);

        final String? trackKey;
        if (track != null) {
          final sourceName = track.source.name;
          trackKey = 'track_${track.id}_$sourceName';
        } else if (song != null) {
          trackKey = 'song_${song.id}_${song.source.name}';
        } else {
          trackKey = null;
        }
        _handleTrackChange(trackKey);

        if (!hasContent) {
          return const SizedBox.shrink();
        }

        final colorScheme = Theme.of(context).colorScheme;
        final Color? themeTint = PlayerService().themeColorNotifier.value;
        final bool showCollapsed = _autoCollapseEnabled && _isCollapsed;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _setBreathingActive(showCollapsed);
        });

        final expanded = _buildExpandedPlayer(
          context: context,
          player: player,
          song: song,
          track: track,
          colorScheme: colorScheme,
          themeTint: themeTint,
          isCompactWidth: isCompactWidth,
        );

        final collapsed = _buildCollapsedPlayer(
          context: context,
          song: song,
          track: track,
          colorScheme: colorScheme,
          isCompactWidth: isCompactWidth,
          isActive: showCollapsed,
        );

        return Listener(
          onPointerDown: (_) => _handlePointerDown(),
          onPointerUp: (_) => _resetCollapseTimer(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: () {
              if (showCollapsed) {
                _resetCollapseTimer(expand: true);
                return;
              }
              _resetCollapseTimer();
              _openFullPlayer(context);
            },
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: showCollapsed ? collapsed : expanded,
              ),
            ),
          ),
        );
      },
    );
  }

  void _openFullPlayer(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const PlayerPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          final offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  Widget _buildExpandedPlayer({
    required BuildContext context,
    required PlayerService player,
    required dynamic song,
    required dynamic track,
    required ColorScheme colorScheme,
    required Color? themeTint,
    required bool isCompactWidth,
  }) {
    return Container(
      key: const ValueKey('mini_expanded'),
      height: 90,
      margin: isCompactWidth ? const EdgeInsets.fromLTRB(12, 8, 12, 8) : EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isCompactWidth ? Colors.transparent : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(isCompactWidth ? 28 : 0),
        border: isCompactWidth ? Border.all(color: Colors.white.withOpacity(0.18), width: 1) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isCompactWidth
          ? Stack(
              children: [
                Positioned.fill(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: const SizedBox.shrink(),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.16),
                          (themeTint ?? colorScheme.primary).withOpacity(0.10),
                          Colors.white.withOpacity(0.05),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: true,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: RadialGradient(
                          center: const Alignment(-0.9, -0.9),
                          radius: 1.2,
                          colors: [
                            Colors.white.withOpacity(0.20),
                            Colors.white.withOpacity(0.04),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    _buildProgressBar(player, colorScheme),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isCompact = constraints.maxWidth < 600;
                            final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
                            if (isCompact) {
                              if (isPortrait) {
                                return Row(
                                  children: [
                                    Expanded(
                                      flex: 8,
                                      child: Row(
                                        children: [
                                          _buildCover(song, track, colorScheme, size: 56),
                                          const SizedBox(width: 10),
                                          Expanded(child: _buildSongInfo(song, track, context)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 6,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _buildCenterControls(player, colorScheme, hideSkip: true),
                                            IconButton(
                                              icon: Icon(Icons.queue_music_rounded, color: colorScheme.onSurface),
                                              tooltip: '播放列表',
                                              onPressed: () => _showQueueSheet(context),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                return Row(
                                  children: [
                                    Expanded(
                                      flex: 6,
                                      child: Row(
                                        children: [
                                          _buildCover(song, track, colorScheme, size: 56),
                                          const SizedBox(width: 10),
                                          Expanded(child: _buildSongInfo(song, track, context)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Center(child: _buildCenterControls(player, colorScheme, hideSkip: true)),
                                    ),
                                    Expanded(
                                      flex: 5,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _formatDuration(player.position),
                                              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                            ),
                                            const Text(' / '),
                                            Text(
                                              _formatDuration(player.duration),
                                              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: Icon(Icons.queue_music_rounded, color: colorScheme.onSurface),
                                              tooltip: '播放列表',
                                              onPressed: () => _showQueueSheet(context),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                            }
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildCover(song, track, colorScheme, size: 56),
                                      const SizedBox(width: 12),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 420),
                                        child: _buildSongInfo(song, track, context),
                                      ),
                                    ],
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.center,
                                  child: _buildCenterControls(player, colorScheme),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: _buildRightPanel(player, colorScheme, context),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              children: [
                _buildProgressBar(player, colorScheme),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 600;
                        final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
                        if (isCompact) {
                          if (isPortrait) {
                            return Row(
                              children: [
                                Expanded(
                                  flex: 8,
                                  child: Row(
                                    children: [
                                      _buildCover(song, track, colorScheme, size: 56),
                                      const SizedBox(width: 10),
                                      Expanded(child: _buildSongInfo(song, track, context)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 6,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildCenterControls(player, colorScheme, hideSkip: true),
                                        IconButton(
                                          icon: Icon(Icons.queue_music_rounded, color: colorScheme.onSurface),
                                          tooltip: '播放列表',
                                          onPressed: () => _showQueueSheet(context),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return Row(
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: Row(
                                    children: [
                                      _buildCover(song, track, colorScheme, size: 56),
                                      const SizedBox(width: 10),
                                      Expanded(child: _buildSongInfo(song, track, context)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Center(child: _buildCenterControls(player, colorScheme, hideSkip: true)),
                                ),
                                Expanded(
                                  flex: 5,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _formatDuration(player.position),
                                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                        ),
                                        const Text(' / '),
                                        Text(
                                          _formatDuration(player.duration),
                                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: Icon(Icons.queue_music_rounded, color: colorScheme.onSurface),
                                          tooltip: '播放列表',
                                          onPressed: () => _showQueueSheet(context),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                        }
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildCover(song, track, colorScheme, size: 56),
                                  const SizedBox(width: 12),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 420),
                                    child: _buildSongInfo(song, track, context),
                                  ),
                                ],
                              ),
                            ),
                            Align(
                              alignment: Alignment.center,
                              child: _buildCenterControls(player, colorScheme),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: _buildRightPanel(player, colorScheme, context),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCollapsedPlayer({
    required BuildContext context,
    required dynamic song,
    required dynamic track,
    required ColorScheme colorScheme,
    required bool isCompactWidth,
    required bool isActive,
  }) {
    final margin = isCompactWidth ? const EdgeInsets.fromLTRB(12, 8, 12, 8) : EdgeInsets.zero;
    final cover = _buildCover(song, track, colorScheme, size: 64);

    if (!isActive) {
      return Container(
        key: const ValueKey('mini_collapsed'),
        margin: margin,
        alignment: Alignment.bottomLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: cover,
        ),
      );
    }

    return Container(
      key: const ValueKey('mini_collapsed'),
      margin: margin,
      alignment: Alignment.bottomLeft,
      child: AnimatedBuilder(
        animation: _breathingController ?? kAlwaysCompleteAnimation,
        child: cover,
        builder: (context, child) {
          final controller = _breathingController;
          final scaleAnim = _breathingScale;
          final t = controller?.value ?? 1.0;
          final scale = scaleAnim?.value ?? 1.0;
          final glowColor = colorScheme.primary.withOpacity(ui.lerpDouble(0.35, 0.6, t) ?? 0.45);
          final blur = ui.lerpDouble(18, 32, t) ?? 24;
          final spread = ui.lerpDouble(3, 10, t) ?? 6;

          return Transform.scale(
            scale: scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: glowColor,
                    blurRadius: blur,
                    spreadRadius: spread,
                  ),
                ],
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colorScheme.primary.withOpacity(ui.lerpDouble(0.25, 0.4, t) ?? 0.3)),
                  color: colorScheme.surface,
                ),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }

  /// 构建进度条
  Widget _buildProgressBar(PlayerService player, ColorScheme colorScheme) {
    final progress = player.duration.inMilliseconds > 0
        ? player.position.inMilliseconds / player.duration.inMilliseconds
        : 0.0;

    return LinearProgressIndicator(
      value: progress,
      minHeight: 2,
      backgroundColor: colorScheme.surfaceContainerHighest,
      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
    );
  }

  /// 构建封面
  Widget _buildCover(dynamic song, dynamic track, ColorScheme colorScheme, {double size = 48}) {
    final imageUrl = song?.pic ?? track?.picUrl ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: imageUrl.isNotEmpty
          ? _optimizedCover(imageUrl, size, colorScheme)
          : Container(
              width: size,
              height: size,
              color: colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.music_note,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }

  Widget _optimizedCover(String imageUrl, double size, ColorScheme colorScheme) {
    final provider = PlayerService().currentCoverImageProvider;
    if (provider != null) {
      return Image(
        image: provider,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        width: size,
        height: size,
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
        width: 48,
        height: 48,
        color: colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.music_note,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// 构建歌曲信息
  Widget _buildSongInfo(dynamic song, dynamic track, BuildContext context) {
    final name = song?.name ?? track?.name ?? '未知歌曲';
    final artist = song?.arName ?? track?.artists ?? '未知艺术家';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          artist,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// 中间控制（上一首/播放暂停/下一首）
  Widget _buildCenterControls(PlayerService player, ColorScheme colorScheme, {bool hideSkip = false}) {
    const double skipIconSize = 24;
    const double playIconSize = 28;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!hideSkip)
        IconButton(
          icon: Icon(
            Icons.skip_previous_rounded,
            color: player.hasPrevious ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          ),
          iconSize: skipIconSize,
          onPressed: player.hasPrevious ? () => player.playPrevious() : null,
          tooltip: '上一首',
        ),
        if (player.isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colorScheme.primary,
              ),
            ),
          )
        else
          IconButton(
            icon: Icon(player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
            color: colorScheme.primary,
            iconSize: playIconSize,
            onPressed: () => player.togglePlayPause(),
            tooltip: player.isPlaying ? '暂停' : '播放',
          ),
        if (!hideSkip)
        IconButton(
          icon: Icon(
            Icons.skip_next_rounded,
            color: player.hasNext ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          ),
          iconSize: skipIconSize,
          onPressed: player.hasNext ? () => player.playNext() : null,
          tooltip: '下一首',
        ),
      ],
    );
  }

  /// 右侧面板（时长 + 音量 + 列表）
  Widget _buildRightPanel(PlayerService player, ColorScheme colorScheme, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 时长
        Text(
          _formatDuration(player.position),
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Text(' / '),
        Text(
          _formatDuration(player.duration),
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        // 音量
        IconButton(
          icon: Icon(_volumeIcon(player.volume), color: colorScheme.onSurface),
          tooltip: '音量',
          onPressed: () => _showVolumeDialog(context, player),
        ),
        // 列表
        IconButton(
          icon: Icon(Icons.queue_music_rounded, color: colorScheme.onSurface),
          tooltip: '播放列表',
          onPressed: () => _showQueueSheet(context),
        ),
      ],
    );
  }

  IconData _volumeIcon(double volume) {
    if (volume == 0) return Icons.volume_off_rounded;
    if (volume < 0.5) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  Future<void> _showVolumeDialog(BuildContext context, PlayerService player) async {
    double temp = player.volume;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('音量'),
          content: StatefulBuilder(
            builder: (context, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    value: temp,
                    onChanged: (v) {
                      setLocal(() => temp = v);
                      player.setVolume(v);
                    },
                  ),
                  Text('${(temp * 100).toInt()}%'),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showQueueSheet(BuildContext context) async {
    final queueService = PlaylistQueueService();
    final history = PlayHistoryService().history;
    final currentTrack = PlayerService().currentTrack;

    // 与全屏播放器一致：优先展示播放队列，否则展示播放历史
    final bool hasQueue = queueService.hasQueue;
    final List<dynamic> displayList = hasQueue
        ? queueService.queue
        : history.map((h) => h.toTrack()).toList();

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: displayList.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text('播放列表为空', style: Theme.of(context).textTheme.bodyMedium),
                  ),
                )
              : ListView.separated(
                  itemCount: displayList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final item = displayList[i];
                    final Track t = item as Track; // displayList 已保证为 Track
                    final isCurrent = currentTrack != null &&
                        t.id.toString() == currentTrack.id.toString() &&
                        t.source == currentTrack.source;

                    return ListTile(
                      tileColor: isCurrent ? Theme.of(context).colorScheme.surfaceContainerHigh : null,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: t.picUrl,
                          imageBuilder: (context, imageProvider) {
                            PlaylistQueueService().updateCoverProvider(t, imageProvider);
                            return Image(
                              image: imageProvider,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                            );
                          },
                          placeholder: (context, url) => Container(width: 44, height: 44, color: Colors.black12),
                          errorWidget: (context, url, error) => Container(
                            width: 44,
                            height: 44,
                            color: Colors.black12,
                            child: Icon(Icons.music_note, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                      title: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(t.artists, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        final coverProvider = PlaylistQueueService().getCoverProvider(t);
                        PlayerService().playTrack(t, coverProvider: coverProvider);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('正在播放: ${t.name}'), duration: const Duration(seconds: 1)),
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  /// 格式化时长
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

