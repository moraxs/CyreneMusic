import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/music_service.dart';
import '../services/player_service.dart';
import '../services/version_service.dart';
import '../models/toplist.dart';
import '../models/track.dart';
import '../models/version_info.dart';
import '../widgets/toplist_card.dart';
import '../widgets/track_list_tile.dart';
import '../widgets/search_widget.dart';
import '../utils/page_visibility_notifier.dart';

/// 首页 - 展示音乐和视频内容
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;
  List<Track> _cachedRandomTracks = []; // 缓存随机歌曲列表
  bool _isPageVisible = true; // 页面是否可见
  bool _showSearch = false; // 是否显示搜索界面

  @override
  bool get wantKeepAlive => true; // 保持页面状态

  @override
  void initState() {
    super.initState();
    
    // 添加应用生命周期监听
    WidgetsBinding.instance.addObserver(this);
    
    // 监听音乐服务变化
    MusicService().addListener(_onMusicServiceChanged);
    
    // 监听页面可见性变化
    PageVisibilityNotifier().addListener(_onPageVisibilityChanged);
    
    // 如果还没有数据，自动获取
    if (MusicService().toplists.isEmpty && !MusicService().isLoading) {
      print('🏠 [HomePage] 首次加载，获取榜单数据...');
      MusicService().fetchToplists();
    } else {
      // 如果已有数据，初始化缓存并启动定时器
      _updateCachedTracksAndStartTimer();
    }
    
    // 🔍 首次进入时检查更新
    _checkForUpdateOnce();
  }

  void _onPageVisibilityChanged() {
    final isVisible = PageVisibilityNotifier().isHomePage;
    
    if (isVisible && _isPageVisible == false) {
      // 从隐藏变为可见
      print('🏠 [HomePage] 页面重新显示，刷新轮播图...');
      _isPageVisible = true;
      _refreshBannerTracks();
    } else if (!isVisible && _isPageVisible == true) {
      // 从可见变为隐藏
      print('🏠 [HomePage] 页面隐藏，停止轮播图...');
      _isPageVisible = false;
      _stopBannerTimer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed && _isPageVisible) {
      // 应用恢复到前台且页面可见时，刷新轮播图
      print('🏠 [HomePage] 应用恢复，刷新轮播图...');
      _refreshBannerTracks();
    } else if (state == AppLifecycleState.paused) {
      // 应用进入后台时，停止定时器
      _stopBannerTimer();
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    MusicService().removeListener(_onMusicServiceChanged);
    PageVisibilityNotifier().removeListener(_onPageVisibilityChanged);
    _bannerController.dispose();
    super.dispose();
  }

  void _onMusicServiceChanged() {
    if (mounted) {
      setState(() {
        // 数据变化时更新缓存并重启定时器
        _updateCachedTracksAndStartTimer();
      });
    }
  }

  /// 更新缓存的随机歌曲列表并启动定时器
  void _updateCachedTracksAndStartTimer() {
    _cachedRandomTracks = MusicService().getRandomTracks(5);
    
    // 在下一帧启动定时器，确保 UI 已渲染完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBannerTimer();
    });
  }

  /// 刷新轮播图歌曲
  void _refreshBannerTracks() {
    print('🏠 [HomePage] 刷新轮播图歌曲...');
    if (mounted) {
      setState(() {
        // 重置当前索引
        _currentBannerIndex = 0;
        // 更新随机歌曲
        _updateCachedTracksAndStartTimer();
        // 跳转到第一页
        if (_bannerController.hasClients) {
          _bannerController.jumpToPage(0);
        }
      });
    }
  }

  /// 启动轮播图自动切换定时器
  void _startBannerTimer() {
    _bannerTimer?.cancel();
    
    // 只有当有轮播图内容时才启动定时器
    if (_cachedRandomTracks.length > 1) {
      print('🎵 [HomePage] 启动轮播图定时器，共 ${_cachedRandomTracks.length} 张');
      
      _bannerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (mounted && _bannerController.hasClients) {
          // 计算下一页索引
          final nextPage = (_currentBannerIndex + 1) % _cachedRandomTracks.length;
          
          print('🎵 [HomePage] 自动切换轮播图：$_currentBannerIndex -> $nextPage');
          
          // 平滑切换到下一页
          _bannerController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    } else {
      print('🎵 [HomePage] 轮播图数量不足，不启动定时器');
    }
  }

  /// 停止轮播图定时器
  void _stopBannerTimer() {
    _bannerTimer?.cancel();
    print('🎵 [HomePage] 停止轮播图定时器');
  }

  /// 重启轮播图定时器
  void _restartBannerTimer() {
    print('🎵 [HomePage] 重启轮播图定时器');
    _stopBannerTimer();
    _startBannerTimer();
  }

  /// 每次进入首页时检查更新
  Future<void> _checkForUpdateOnce() async {
    try {
      // 延迟2秒后检查，避免影响首页加载
      await Future.delayed(const Duration(seconds: 2));
      
      if (!mounted) return;
      
      print('🔍 [HomePage] 开始检查更新...');
      
      final versionInfo = await VersionService().checkForUpdate(silent: true);
      
      if (!mounted) return;
      
      // 如果有更新，检查是否应该提示
      if (versionInfo != null && VersionService().hasUpdate) {
        // 检查用户是否已忽略此版本
        final shouldShow = await VersionService().shouldShowUpdateDialog(versionInfo);
        if (shouldShow) {
          _showUpdateDialog(versionInfo);
        } else {
          print('🔕 [HomePage] 用户已忽略此版本，不再提示');
        }
      }
    } catch (e) {
      print('❌ [HomePage] 检查更新失败: $e');
    }
  }

  /// 显示更新提示对话框
  void _showUpdateDialog(VersionInfo versionInfo) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: !versionInfo.forceUpdate, // 强制更新时不能关闭对话框
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('发现新版本'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 版本信息
              Text(
                '最新版本: ${versionInfo.version}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '当前版本: ${VersionService().currentVersion}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              
              // 更新日志
              const Text(
                '更新内容：',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                versionInfo.changelog,
                style: const TextStyle(fontSize: 14),
              ),
              
              // 强制更新提示
              if (versionInfo.forceUpdate) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '此版本为强制更新，请立即更新',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          // 稍后提醒（仅非强制更新时显示）
          if (!versionInfo.forceUpdate)
            TextButton(
              onPressed: () async {
                // 保存用户忽略的版本号
                await VersionService().ignoreCurrentVersion(versionInfo.version);
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已忽略版本 ${versionInfo.version}，有新版本时将再次提醒'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('稍后提醒'),
            ),
          
          // 立即更新
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openDownloadUrl(versionInfo.downloadUrl);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  /// 打开下载链接
  Future<void> _openDownloadUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开下载链接')),
          );
        }
      }
    } catch (e) {
      print('❌ [HomePage] 打开下载链接失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开链接失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用以支持 AutomaticKeepAliveClientMixin
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: _showSearch 
          ? SearchWidget(
              onClose: () {
                setState(() {
                  _showSearch = false;
                });
              },
            )
          : CustomScrollView(
              slivers: [
                // 顶部标题
                SliverAppBar(
                  floating: true,
                  snap: true,
                  backgroundColor: colorScheme.surface,
                  title: Text(
                    '首页',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        setState(() {
                          _showSearch = true;
                        });
                      },
                      tooltip: '搜索',
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        MusicService().refreshToplists();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('正在刷新榜单...')),
                        );
                      },
                      tooltip: '刷新',
                    ),
                  ],
                ),
                
                // 内容区域
                SliverPadding(
                  padding: const EdgeInsets.all(24.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 加载状态或错误提示
                      if (MusicService().isLoading)
                        _buildLoadingSection()
                      else if (MusicService().errorMessage != null)
                        _buildErrorSection()
                      else if (MusicService().toplists.isEmpty)
                        _buildEmptySection()
                      else ...[
                        // 轮播图
                        _buildBannerSection(),
                        const SizedBox(height: 32),
                        
                        // 热门榜单
                        _buildToplistsGrid(),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  /// 构建加载状态
  Widget _buildLoadingSection() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(64.0),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载榜单...'),
          ],
        ),
      ),
    );
  }

  /// 构建错误状态
  Widget _buildErrorSection() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              MusicService().errorMessage ?? '未知错误',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                MusicService().refreshToplists();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptySection() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          children: [
            Icon(
              Icons.music_note,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无榜单',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '请检查后端服务是否正常',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                MusicService().fetchToplists();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('刷新'),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建轮播图区域
  Widget _buildBannerSection() {
    // 使用缓存的随机歌曲列表
    if (_cachedRandomTracks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '推荐歌曲',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              PageView.builder(
                controller: _bannerController,
                itemCount: _cachedRandomTracks.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentBannerIndex = index;
                  });
                  print('🎵 [HomePage] 页面切换到: $index');
                  // 用户手动滑动后重启定时器
                  _restartBannerTimer();
                },
                itemBuilder: (context, index) {
                  final track = _cachedRandomTracks[index];
                  return _TrackBannerCard(
                    track: track,
                    onTap: () {
                      // 播放歌曲
                      PlayerService().playTrack(track);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('正在加载：${track.name}'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  );
                },
              ),
              // 指示器
              Positioned(
                bottom: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _cachedRandomTracks.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentBannerIndex == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建榜单列表（每个榜单横向滚动显示歌曲）
  Widget _buildToplistsGrid() {
    final toplists = MusicService().toplists;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 遍历每个榜单
        for (int i = 0; i < toplists.length; i++) ...[
          _buildToplistSection(toplists[i]),
          if (i < toplists.length - 1) const SizedBox(height: 32),
        ],
      ],
    );
  }

  /// 构建单个榜单区域
  Widget _buildToplistSection(Toplist toplist) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 榜单标题行
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              toplist.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => _showToplistDetail(toplist),
              child: const Text('查看全部'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 横向滚动的歌曲卡片
        SizedBox(
          height: 220, // 增加高度以容纳所有内容
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: toplist.tracks.take(10).length, // 只显示前10首
            itemBuilder: (context, index) {
              final track = toplist.tracks[index];
              return _buildTrackCard(track, index);
            },
          ),
        ),
      ],
    );
  }

  /// 构建歌曲卡片
  Widget _buildTrackCard(Track track, int rank) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            PlayerService().playTrack(track);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('正在加载：${track.name}'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 专辑封面
              Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: track.picUrl,
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 140,
                      height: 140,
                      color: colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 140,
                      height: 140,
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.music_note,
                        size: 48,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  // 排名标签
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: rank < 3 
                            ? colorScheme.primary 
                            : colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${rank + 1}',
                        style: TextStyle(
                          color: rank < 3 
                              ? colorScheme.onPrimary 
                              : colorScheme.onSecondaryContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // 播放按钮覆盖层
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0),
                      child: Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          size: 48,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // 歌曲信息
              Container(
                height: 56, // 固定高度避免溢出
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      track.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artists,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  /// 显示榜单详情
  void _showToplistDetail(Toplist toplist) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // 拖动指示器
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 榜单头部
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: toplist.coverImgUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 80,
                            height: 80,
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
                            width: 80,
                            height: 80,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.music_note, size: 32),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              toplist.name,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              toplist.creator,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '共 ${toplist.trackCount} 首',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // 歌曲列表
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: toplist.tracks.length,
                    itemBuilder: (context, index) {
                      return TrackListTile(
                        track: toplist.tracks[index],
                        index: index,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 歌曲轮播图卡片
class _TrackBannerCard extends StatelessWidget {
  final Track track;
  final VoidCallback? onTap;

  const _TrackBannerCard({
    required this.track,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 4,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 封面图片
              CachedNetworkImage(
                imageUrl: track.picUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.music_note,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              // 渐变遮罩
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
              // 歌曲信息
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 歌曲名称
                    Text(
                      track.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 1),
                            blurRadius: 3.0,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // 艺术家
                    Text(
                      track.artists,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 1),
                            blurRadius: 3.0,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // 专辑和音乐来源
                    Row(
                      children: [
                        Text(
                          track.getSourceIcon(),
                          style: const TextStyle(
                            fontSize: 12,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 3.0,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            track.album,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.8),
                              shadows: [
                                Shadow(
                                  offset: const Offset(0, 1),
                                  blurRadius: 3.0,
                                  color: Colors.black.withOpacity(0.5),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 播放按钮
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    onPressed: onTap,
                    tooltip: '播放',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
