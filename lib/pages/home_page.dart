import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../services/music_service.dart';
import '../services/player_service.dart';
import '../services/version_service.dart';
import '../services/auth_service.dart';
import '../models/toplist.dart';
import '../models/track.dart';
import '../models/version_info.dart';
import '../widgets/toplist_card.dart';
import '../widgets/track_list_tile.dart';
import '../widgets/search_widget.dart';
import '../utils/page_visibility_notifier.dart';
import '../pages/auth/auth_page.dart';
import '../services/play_history_service.dart';
import '../services/playlist_service.dart';
import '../models/playlist.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/url_service.dart';

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
  Future<List<Track>>? _guessYouLikeFuture; // 缓存猜你喜欢的结果

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
    
    // 监听播放历史变化
    PlayHistoryService().addListener(_onHistoryChanged);

    // 监听登录状态变化
    AuthService().addListener(_onAuthChanged);
    
    // 如果还没有数据，自动获取
    if (MusicService().toplists.isEmpty && !MusicService().isLoading) {
      print('🏠 [HomePage] 首次加载，获取榜单数据...');
      MusicService().fetchToplists();
    } else {
      // 如果已有数据，初始化缓存并启动定时器
      _updateCachedTracksAndStartTimer();
    }
    
    // 首次加载“猜你喜欢”
    _prepareGuessYouLikeFuture();

    // 🔍 首次进入时检查更新
    _checkForUpdateOnce();
  }

  void _onAuthChanged() {
    if (mounted) {
      setState(() {
        // 登录状态变化时，重新加载“猜你喜欢”
        _prepareGuessYouLikeFuture();
      });
    }
  }

  void _onHistoryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onPlaylistChanged() {
    if (mounted) {
      setState(() {});
    }
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
    PlayHistoryService().removeListener(_onHistoryChanged);
    AuthService().removeListener(_onAuthChanged);
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
        
        // 检查本次会话是否已提醒过（稍后提醒）
        final hasReminded = VersionService().hasRemindedInSession(versionInfo.version);
        
        if (shouldShow && !hasReminded) {
          _showUpdateDialog(versionInfo);
        } else {
          if (hasReminded) {
            print('⏰ [HomePage] 用户选择了稍后提醒，本次会话不再提示');
          } else {
            print('🔕 [HomePage] 用户已忽略此版本，不再提示');
          }
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
          // 稍后提醒（仅非强制更新时显示，本次会话不再提醒）
          if (!versionInfo.forceUpdate)
            TextButton(
              onPressed: () {
                // 标记本次会话已提醒，不保存到持久化存储
                VersionService().markVersionReminded(versionInfo.version);
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('本次启动将不再提醒，下次启动时会再次提示'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('稍后提醒'),
            ),
          
          // 忽略此版本（仅非强制更新时显示，永久忽略）
          if (!versionInfo.forceUpdate)
            TextButton(
              onPressed: () async {
                // 永久保存用户忽略的版本号
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
              child: const Text('忽略此版本'),
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
                      onPressed: () async {
                        // 检查登录状态
                        final isLoggedIn = await _checkLoginStatus();
                        if (isLoggedIn && mounted) {
                          setState(() {
                            _showSearch = true;
                          });
                        }
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

                        // 最近播放 和 猜你喜欢（响应式布局）
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // 宽度小于 600px 或 Android 平台时使用纵向布局
                            final useVerticalLayout = constraints.maxWidth < 600 || Platform.isAndroid;
                            
                            if (useVerticalLayout) {
                              // 移动端竖屏：纵向排列
                              return Column(
                                children: [
                                  _buildHistorySection(),
                                  const SizedBox(height: 16),
                                  _buildGuessYouLikeSection(),
                                ],
                              );
                            } else {
                              // 桌面端或横屏：横向排列
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildHistorySection()),
                                  const SizedBox(width: 24),
                                  Expanded(child: _buildGuessYouLikeSection()),
                                ],
                              );
                            }
                          },
                        ),
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

  /// 构建最近播放区域
  Widget _buildHistorySection() {
    final history = PlayHistoryService().history.take(3).toList(); // 只取最近3条

    if (history.isEmpty) {
      return const SizedBox.shrink(); // 如果没有历史，不显示任何东西
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // TODO: 跳转到完整的历史记录页面
          print('跳转到历史记录页面');
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '最近播放',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // 封面
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: history.first.picUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 歌曲列表
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(history.length, (index) {
                        final item = history[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text.rich(
                            TextSpan(
                              style: Theme.of(context).textTheme.bodySmall,
                              children: [
                                TextSpan(
                                  text: '${index + 1}  ',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: '${item.name} - ${item.artists}'),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建猜你喜欢区域
  Widget _buildGuessYouLikeSection() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // TODO: 跳转到推荐页面或歌单
          print('跳转到推荐页面');
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '猜你喜欢',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 64, // 固定高度防止布局跳动
                child: _guessYouLikeFuture != null
                    ? _buildGuessYouLikeContent()
                    : _buildGuessYouLikePlaceholder(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建猜你喜欢内容
  Widget _buildGuessYouLikeContent() {
    return FutureBuilder<List<Track>>(
      future: _guessYouLikeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildGuessYouLikePlaceholder(isError: true);
        }

        final sampleTracks = snapshot.data!;

        return Row(
          children: [
            // 封面
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: sampleTracks.first.picUrl,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            // 歌曲列表
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(sampleTracks.length, (index) {
                  final track = sampleTracks[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text.rich(
                      TextSpan(
                        style: Theme.of(context).textTheme.bodySmall,
                        children: [
                          TextSpan(
                            text: '${index + 1}  ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: '${track.name} - ${track.artists}'),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 准备“猜你喜欢”的 Future
  void _prepareGuessYouLikeFuture() {
    if (AuthService().isLoggedIn) {
      _guessYouLikeFuture = _fetchRandomTracksFromPlaylists();
    } else {
      _guessYouLikeFuture = null;
    }
  }

  /// 从多个歌单中获取随机歌曲
  Future<List<Track>> _fetchRandomTracksFromPlaylists() async {
    final String baseUrl = UrlService().baseUrl;
    final String? token = AuthService().token;
    if (token == null) throw Exception('未登录');

    // 1. 获取所有歌单
    final playlistsResponse = await http.get(
      Uri.parse('$baseUrl/playlists'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (playlistsResponse.statusCode != 200) {
      throw Exception('获取歌单列表失败');
    }

    final playlistsBody = json.decode(utf8.decode(playlistsResponse.bodyBytes));
    if (playlistsBody['status'] != 200) {
      throw Exception(playlistsBody['message'] ?? '获取歌单列表失败');
    }
    
    final List<dynamic> playlistsJson = playlistsBody['playlists'] ?? [];
    final List<Playlist> allPlaylists = playlistsJson.map((p) => Playlist.fromJson(p)).toList();

    // 2. 筛选非空歌单
    final nonEmptyPlaylists = allPlaylists.where((p) => p.trackCount > 0).toList();
    if (nonEmptyPlaylists.isEmpty) {
      throw Exception('没有包含歌曲的歌单');
    }

    // 3. 随机选择一个歌单并获取其歌曲
    final randomPlaylist = nonEmptyPlaylists[Random().nextInt(nonEmptyPlaylists.length)];
    final tracksResponse = await http.get(
      Uri.parse('$baseUrl/playlists/${randomPlaylist.id}/tracks'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (tracksResponse.statusCode != 200) {
      throw Exception('获取歌曲失败');
    }
    
    final tracksBody = json.decode(utf8.decode(tracksResponse.bodyBytes));
    if (tracksBody['status'] != 200) {
      throw Exception(tracksBody['message'] ?? '获取歌曲失败');
    }
    
    final List<dynamic> tracksJson = tracksBody['tracks'] ?? [];
    final List<PlaylistTrack> tracks = tracksJson.map((t) => PlaylistTrack.fromJson(t)).toList();

    // 4. 随机挑选3首
    tracks.shuffle();
    return tracks.take(3).map((t) => t.toTrack()).toList();
  }

  /// 加载歌单中的一小部分歌曲用于展示
  Future<List<PlaylistTrack>> _loadPlaylistTracksSample(int playlistId) async {
    // 这里我们直接调用 PlaylistService 的方法，但理想情况下可以做一个缓存或优化
    // 为了简单起见，我们直接加载
    await PlaylistService().loadPlaylistTracks(playlistId);
    return PlaylistService().currentTracks;
  }

  /// 构建猜你喜欢占位符
  Widget _buildGuessYouLikePlaceholder({bool isError = false}) {
    final message = isError ? '加载推荐失败' : '导入歌单查看更多';
    return InkWell(
      onTap: () {
        // TODO: 跳转到我的页面，引导用户导入歌单
        print('引导用户导入歌单');
      },
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据屏幕宽度自适应轮播图高度
        final screenWidth = MediaQuery.of(context).size.width;
        final bannerHeight = (screenWidth * 0.5).clamp(160.0, 220.0);
        
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
              height: bannerHeight,
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
                        onTap: () async {
                          // 检查登录状态
                          final isLoggedIn = await _checkLoginStatus();
                          if (isLoggedIn && mounted) {
                            // 播放歌曲
                            PlayerService().playTrack(track);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('正在加载：${track.name}'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                  // 指示器
                  Positioned(
                    bottom: 12,
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
      },
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据屏幕宽度自适应卡片高度
        final screenWidth = MediaQuery.of(context).size.width;
        final cardHeight = (screenWidth * 0.55).clamp(200.0, 240.0);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 榜单标题行
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    toplist.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
              height: cardHeight,
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
      },
    );
  }

  /// 构建歌曲卡片
  Widget _buildTrackCard(Track track, int rank) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据可用高度自适应卡片宽度和封面大小
        final cardHeight = constraints.maxHeight;
        final coverSize = (cardHeight * 0.65).clamp(120.0, 160.0);
        final cardWidth = coverSize;
        
        return Container(
          width: cardWidth,
          margin: const EdgeInsets.only(right: 12),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () async {
                // 检查登录状态
                final isLoggedIn = await _checkLoginStatus();
                if (isLoggedIn && mounted) {
                  PlayerService().playTrack(track);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('正在加载：${track.name}'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 专辑封面
                  Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: track.picUrl,
                        width: coverSize,
                        height: coverSize,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: coverSize,
                          height: coverSize,
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
                          width: coverSize,
                          height: coverSize,
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.music_note,
                            size: coverSize * 0.3,
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
                              size: coverSize * 0.3,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // 歌曲信息 - 使用 Expanded 而不是固定高度，避免溢出
                  Expanded(
                    child: Padding(
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
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 显示榜单详情
  void _showToplistDetail(Toplist toplist) {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // 桌面端：从左侧弹出侧边栏
      _showToplistDetailSidebar(toplist);
    } else {
      // 移动端：从底部弹出抽屉
      _showToplistDetailBottomSheet(toplist);
    }
  }

  /// 桌面端：从左侧弹出侧边栏（Material Design 3 样式 + 高斯模糊背景）
  void _showToplistDetailSidebar(Toplist toplist) {
    final colorScheme = Theme.of(context).colorScheme;
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent, // 使用透明色，自定义背景
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        // M3 标准动画曲线
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        
        return Stack(
          children: [
            // 高斯模糊背景层（淡入效果 + 圆角裁剪）
            Padding(
              padding: const EdgeInsets.all(8.0), // 与主窗口外边距一致
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12), // 与主窗口圆角一致
                child: FadeTransition(
                  opacity: curvedAnimation,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(), // 点击背景关闭
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 10.0, // 水平模糊强度
                        sigmaY: 10.0, // 垂直模糊强度
                      ),
                      child: Container(
                        color: colorScheme.scrim.withOpacity(0.25), // 半透明遮罩
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Windows 标题栏可拖动区域（覆盖在模糊层上方）
            if (Platform.isWindows)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 48, // 标题栏高度
                child: MoveWindow(
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ),
            // 侧边栏内容（滑入 + 淡入效果）
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-1.0, 0.0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: FadeTransition(
                opacity: curvedAnimation,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0), // 与主窗口保持一致的外边距
                    child: Material(
                      elevation: 0,
                      type: MaterialType.card,
                      color: Colors.transparent,
                      child: Container(
                        width: 400,
                        // 减去上下的 padding，避免超出主窗口
                        height: MediaQuery.of(context).size.height - 16,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh, // M3 标准侧板背景色
                          borderRadius: BorderRadius.circular(12), // 与主窗口圆角保持一致
                          // M3 标准阴影
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.shadow.withOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(2, 0),
                            ),
                            BoxShadow(
                              color: colorScheme.shadow.withOpacity(0.16),
                              blurRadius: 12,
                              offset: const Offset(4, 0),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12), // 裁剪内容，与主窗口一致
                          child: _buildToplistDetailContent(toplist),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return child!;
      },
    );
  }

  /// 移动端：从底部弹出抽屉
  void _showToplistDetailBottomSheet(Toplist toplist) {
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
                // 榜单内容
                Expanded(
                  child: _buildToplistDetailContent(toplist, scrollController: scrollController),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建榜单详情内容（桌面端和移动端共用 - Material Design 3 样式）
  Widget _buildToplistDetailContent(Toplist toplist, {ScrollController? scrollController}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    
    return Column(
      children: [
        // M3 标准头部区域
        Container(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 24.0 : 16.0, // 桌面端使用更大的左右边距
            isDesktop ? 20.0 : 16.0,
            isDesktop ? 16.0 : 16.0,
            16.0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面 - M3 标准圆角
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // M3 标准圆角
                ),
                clipBehavior: Clip.antiAlias,
                child: CachedNetworkImage(
                  imageUrl: toplist.coverImgUrl,
                  width: isDesktop ? 96 : 80, // 桌面端稍大
                  height: isDesktop ? 96 : 80,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: isDesktop ? 96 : 80,
                    height: isDesktop ? 96 : 80,
                    color: colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: isDesktop ? 96 : 80,
                    height: isDesktop ? 96 : 80,
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.music_note_rounded, // M3 圆角图标
                      size: 40,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // 信息区域
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 榜单名称 - M3 headline 样式
                    Text(
                      toplist.name,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600, // M3 标准字重
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // 创建者 - M3 body 样式
                    Row(
                      children: [
                        Icon(
                          Icons.person_rounded,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            toplist.creator,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 歌曲数量 - M3 label 样式
                    Row(
                      children: [
                        Icon(
                          Icons.queue_music_rounded,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '共 ${toplist.trackCount} 首歌曲',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 关闭按钮（桌面端显示）- M3 标准图标按钮
              if (isDesktop)
                IconButton(
                  icon: Icon(
                    Icons.close_rounded, // M3 圆角图标
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: '关闭',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    hoverColor: colorScheme.onSurface.withOpacity(0.08), // M3 标准悬停效果
                  ),
                ),
            ],
          ),
        ),
        // M3 标准分隔线
        Divider(
          height: 1,
          thickness: 1,
          color: colorScheme.outlineVariant,
        ),
        // 歌曲列表
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: EdgeInsets.only(
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8, // 考虑底部安全区域
            ),
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
