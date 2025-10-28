import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/mini_player.dart';
import '../pages/home_page.dart';
import '../pages/discover_page.dart';
import '../pages/history_page.dart';
import '../pages/my_page.dart';
import '../pages/local_page.dart';
import '../pages/settings_page.dart';
import '../pages/developer_page.dart';
import '../services/auth_service.dart';
import '../services/layout_preference_service.dart';
import '../services/developer_mode_service.dart';
import '../utils/page_visibility_notifier.dart';
import '../utils/theme_manager.dart';
import '../pages/auth/auth_page.dart';
import '../services/auth_overlay_service.dart';
import '../services/player_service.dart';

/// 主布局 - 包含侧边导航栏和内容区域
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  // NavigationDrawer 固定宽度与 NavigationRail 展开状态一致（Material 3 默认 256）
  static const double _drawerWidth = 256.0;
  static const double _collapsedWidth = 80.0; // 折叠状态宽度，仅显示图标
  bool _isDrawerCollapsed = false; // 抽屉是否处于折叠状态（默认展开）

  // 页面列表
  List<Widget> get _pages {
    final pages = <Widget>[
      const HomePage(),
      const DiscoverPage(),
      const HistoryPage(),
      const LocalPage(), // 本地
      const MyPage(), // 我的（歌单+听歌统计）
      const SettingsPage(),
    ];
    
    // 如果开发者模式启用，添加开发者页面
    if (DeveloperModeService().isDeveloperMode) {
      pages.add(const DeveloperPage());
    }
    
    return pages;
  }

  Future<void> _openMoreBottomSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.history_outlined),
                title: const Text('历史'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = 2); // 历史
                  PageVisibilityNotifier().setCurrentPage(2);
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('本地'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = 3); // 本地
                  PageVisibilityNotifier().setCurrentPage(3);
                },
              ),
              const Divider(height: 8),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('设置'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = 5); // 设置
                  PageVisibilityNotifier().setCurrentPage(5);
                  // 触发开发者模式（与设置点击一致）
                  DeveloperModeService().onSettingsClicked();
                },
              ),
              if (DeveloperModeService().isDeveloperMode)
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('Dev'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 6);
                    PageVisibilityNotifier().setCurrentPage(6);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // 监听认证状态变化
    AuthService().addListener(_onAuthChanged);
    // 监听布局偏好变化
    LayoutPreferenceService().addListener(_onLayoutPreferenceChanged);
    // 监听开发者模式变化
    DeveloperModeService().addListener(_onDeveloperModeChanged);
    
    // 初始化系统主题色（在 build 完成后执行）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ThemeManager().initializeSystemColor(context);
      }
    });
  }

  @override
  void dispose() {
    AuthService().removeListener(_onAuthChanged);
    LayoutPreferenceService().removeListener(_onLayoutPreferenceChanged);
    DeveloperModeService().removeListener(_onDeveloperModeChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) {
      // 使用 addPostFrameCallback 避免在构建期间调用 setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _onLayoutPreferenceChanged() {
    if (mounted) {
      // 使用 addPostFrameCallback 避免在构建期间调用 setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _onDeveloperModeChanged() {
    if (mounted) {
      // 使用 addPostFrameCallback 延迟到构建完成后再调用 setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            // 如果当前选中的是开发者页面但模式被关闭，切换到首页
            if (_selectedIndex >= 6 && !DeveloperModeService().isDeveloperMode) {
              _selectedIndex = 0;
            }
          });
        }
      });
    }
  }

  void _handleUserButtonTap() {
    if (AuthService().isLoggedIn) {
      // 已登录，显示用户菜单
      _showUserMenu();
    } else {
      // 未登录：桌面端使用覆盖层；移动端使用整页
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        AuthOverlayService().show().then((_) {
          if (mounted) setState(() {});
        });
      } else {
        showAuthDialog(context).then((_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  void _showUserMenu() {
    final user = AuthService().currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundImage: user.avatarUrl != null
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? Text(user.username[0].toUpperCase())
                    : null,
              ),
              title: Text(user.username),
              subtitle: Text(user.email),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('我的'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedIndex = 4; // 切换到我的页面
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('退出登录'),
              onTap: () {
                Navigator.pop(context);
                _confirmLogout();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              AuthService().logout();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已退出登录')),
              );
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 根据平台选择不同的布局
    if (Platform.isAndroid) {
      // Android 始终使用移动布局
      return _buildMobileLayout(context);
    } else if (Platform.isWindows) {
      // Windows 根据用户偏好选择布局，使用 AnimatedBuilder 确保更新
      return AnimatedBuilder(
        animation: LayoutPreferenceService(),
        builder: (context, child) {
          final isDesktop = LayoutPreferenceService().isDesktopLayout;
          print('🖥️ [MainLayout] 当前布局模式: ${isDesktop ? "桌面模式" : "移动模式"}');
          
          return isDesktop
              ? _buildDesktopLayout(context)
              : _buildMobileLayout(context);
        },
      );
    } else {
      // 其他桌面平台默认使用桌面布局
      return _buildDesktopLayout(context);
    }
  }

  /// 构建桌面端布局（Windows/Linux/macOS）
  Widget _buildDesktopLayout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: Column(
        children: [
          // Windows 平台显示自定义标题栏
          if (Platform.isWindows)
            const CustomTitleBar(),
          
          // 主要内容区域
          Expanded(
            child: AnimatedBuilder(
              animation: AuthOverlayService(),
              builder: (context, child) {
                final overlay = AuthOverlayService();
                return Stack(
                  children: [
                    Row(
                      children: [
                        // 侧边导航栏
                        _buildNavigationDrawer(colorScheme),
                        // 内容区域
                        Expanded(
                          child: _pages[_selectedIndex],
                        ),
                      ],
                    ),
                    if (overlay.isVisible)
                      // 完全参照首页-歌单详情样式：覆盖右侧内容区，保留侧栏与标题栏
                      Positioned.fill(
                        child: Row(
                          children: [
                            // 占位侧栏宽度
                            SizedBox(width: _isDrawerCollapsed ? _collapsedWidth : _drawerWidth),
                            // 右侧内容覆盖
                            Expanded(
                              child: Material(
                                color: Theme.of(context).colorScheme.surface,
                                child: SafeArea(
                                  child: Column(
                                    children: [
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: IconButton(
                                          icon: const Icon(Icons.arrow_back_rounded),
                                          onPressed: () => AuthOverlayService().hide(false),
                                          tooltip: '返回',
                                        ),
                                      ),
                                      Expanded(
                                        child: PrimaryScrollController.none(
                                          child: AuthPage(initialTab: overlay.initialTab),
                                        ),
                                      ),
                                    ],
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
            ),
          ),
          
          // 迷你播放器
          const MiniPlayer(),
        ],
      ),
    );
  }

  /// 构建移动端布局（Android/iOS）
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 主内容层
          Column(
            children: [
              if (Platform.isWindows)
                const CustomTitleBar(),
              Expanded(child: _pages[_selectedIndex]),
            ],
          ),
          // 悬浮迷你播放器（不占用布局空间）
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: PlayerService(),
              builder: (context, child) {
                final hasMiniPlayer = PlayerService().currentTrack != null || PlayerService().currentSong != null;
                if (!hasMiniPlayer) return const SizedBox.shrink();
                return const MiniPlayer();
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildGlassBottomNavigationBar(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: AnimatedBuilder(
        animation: PlayerService(),
        builder: (context, child) {
          final hasMiniPlayer = PlayerService().currentTrack != null || PlayerService().currentSong != null;
          return Padding(
            padding: EdgeInsets.only(bottom: hasMiniPlayer ? 120.0 : 0.0),
            child: FloatingActionButton(
              onPressed: _handleUserButtonTap,
              child: _buildUserAvatar(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGlassBottomNavigationBar(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final bool useGlass = Platform.isAndroid || orientation == Orientation.portrait;
    final baseNav = NavigationBar(
      selectedIndex: () {
        if (_selectedIndex == 0) return 0; // 首页
        if (_selectedIndex == 1) return 1; // 发现
        if (_selectedIndex == 4) return 2; // 我的
        return 3; // 其他 -> 更多
      }(),
      onDestinationSelected: (int tabIndex) async {
        if (tabIndex == 3) {
          await _openMoreBottomSheet(context);
          return;
        }

        int targetPageIndex = _selectedIndex;
        if (tabIndex == 0) targetPageIndex = 0; // 首页
        if (tabIndex == 1) targetPageIndex = 1; // 发现
        if (tabIndex == 2) targetPageIndex = 4; // 我的

        setState(() {
          _selectedIndex = targetPageIndex;
        });
        PageVisibilityNotifier().setCurrentPage(targetPageIndex);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: '首页',
        ),
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore),
          label: '发现',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outlined),
          selectedIcon: Icon(Icons.person),
          label: '我的',
        ),
        NavigationDestination(
          icon: Icon(Icons.more_horiz),
          selectedIcon: Icon(Icons.more_horiz),
          label: '更多',
        ),
      ],
    );

    if (!useGlass) return baseNav;

    final cs = Theme.of(context).colorScheme;
    final Color? themeTint = PlayerService().themeColorNotifier.value;
    return Theme(
      data: Theme.of(context).copyWith(
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          child: Stack(
            children: [
              // 毛玻璃模糊层
              Positioned.fill(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: const SizedBox.shrink(),
                  ),
                ),
              ),
              // 液态玻璃渐变层
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.16),
                        (themeTint ?? cs.primary).withOpacity(0.10),
                        Colors.white.withOpacity(0.05),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.18), width: 1),
                    ),
                  ),
                ),
              ),
              // 高光
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(-0.9, -0.9),
                        radius: 1.2,
                        colors: [
                          Color(0x33FFFFFF),
                          Color(0x0AFFFFFF),
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              baseNav,
            ],
          ),
        ),
      ),
    );
  }

  /// 构建侧边导航抽屉（Material Design 3 NavigationDrawer）
  Widget _buildNavigationDrawer(ColorScheme colorScheme) {
    final bool isCollapsed = _isDrawerCollapsed;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      width: isCollapsed ? _collapsedWidth : _drawerWidth,
      child: Column(
        children: [
          // 顶部折叠/展开按钮
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _isDrawerCollapsed = !_isDrawerCollapsed;
                  });
                },
                icon: AnimatedRotation(
                  turns: isCollapsed ? 0.0 : 0.5, // 旋转 180°
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: const Icon(Icons.chevron_left),
                ),
                tooltip: isCollapsed ? '展开' : '收起',
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
              child: isCollapsed
                  ? KeyedSubtree(
                      key: const ValueKey('collapsed'),
                      child: _buildCollapsedDestinations(colorScheme),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('expanded'),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          navigationDrawerTheme: const NavigationDrawerThemeData(
                            backgroundColor: Colors.transparent,
                            surfaceTintColor: Colors.transparent,
                          ),
                        ),
                        child: NavigationDrawer(
                          selectedIndex: _selectedIndex,
                          onDestinationSelected: (int index) {
                            // 如果点击的是设置按钮，触发开发者模式检测
                            if (index == 5) {
                              DeveloperModeService().onSettingsClicked();
                            }

                            setState(() {
                              _selectedIndex = index;
                            });
                            // 通知页面切换
                            PageVisibilityNotifier().setCurrentPage(index);
                          },
                          children: [
                            const SizedBox(height: 8),
                            const NavigationDrawerDestination(
                              icon: Icon(Icons.home_outlined),
                              selectedIcon: Icon(Icons.home),
                              label: Text('首页'),
                            ),
                            const NavigationDrawerDestination(
                              icon: Icon(Icons.explore_outlined),
                              selectedIcon: Icon(Icons.explore),
                              label: Text('发现'),
                            ),
                            const NavigationDrawerDestination(
                              icon: Icon(Icons.history_outlined),
                              selectedIcon: Icon(Icons.history),
                              label: Text('历史'),
                            ),
                            const NavigationDrawerDestination(
                              icon: Icon(Icons.folder_open),
                              selectedIcon: Icon(Icons.folder),
                              label: Text('本地'),
                            ),
                            const NavigationDrawerDestination(
                              icon: Icon(Icons.person_outlined),
                              selectedIcon: Icon(Icons.person),
                              label: Text('我的'),
                            ),
                            const NavigationDrawerDestination(
                              icon: Icon(Icons.settings_outlined),
                              selectedIcon: Icon(Icons.settings),
                              label: Text('设置'),
                            ),
                            if (DeveloperModeService().isDeveloperMode)
                              const NavigationDrawerDestination(
                                icon: Icon(Icons.code),
                                selectedIcon: Icon(Icons.code),
                                label: Text('Dev'),
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          // 底部用户头像入口（与原 trailing 行为一致）
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Tooltip(
              message: AuthService().isLoggedIn ? '用户中心' : '登录',
              child: InkWell(
                onTap: _handleUserButtonTap,
                borderRadius: BorderRadius.circular(28),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: _buildUserAvatar(size: 40),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 折叠状态下仅显示图标的目的地列表
  Widget _buildCollapsedDestinations(ColorScheme colorScheme) {
    final List<_CollapsedItem> items = [
      _CollapsedItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: '首页'),
      _CollapsedItem(icon: Icons.explore_outlined, selectedIcon: Icons.explore, label: '发现'),
      _CollapsedItem(icon: Icons.history_outlined, selectedIcon: Icons.history, label: '历史'),
      _CollapsedItem(icon: Icons.folder_open, selectedIcon: Icons.folder, label: '本地'),
      _CollapsedItem(icon: Icons.person_outlined, selectedIcon: Icons.person, label: '我的'),
      _CollapsedItem(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: '设置'),
    ];
    if (DeveloperModeService().isDeveloperMode) {
      items.add(_CollapsedItem(icon: Icons.code, selectedIcon: Icons.code, label: 'Dev'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final bool isSelected = _selectedIndex == index;
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: Tooltip(
            message: item.label,
            child: Material(
              color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (index == 5) {
                    DeveloperModeService().onSettingsClicked();
                  }
                  setState(() {
                    _selectedIndex = index;
                  });
                  PageVisibilityNotifier().setCurrentPage(index);
                },
                child: SizedBox(
                  height: 48,
                  child: Center(
                    child: Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建用户头像
  Widget _buildUserAvatar({double size = 24}) {
    final user = AuthService().currentUser;
    
    if (user == null || !AuthService().isLoggedIn) {
      return Icon(Icons.account_circle_outlined, size: size);
    }

    // 如果有QQ头像，显示头像
    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(user.avatarUrl!),
        onBackgroundImageError: (exception, stackTrace) {
          // 头像加载失败时的处理
          print('头像加载失败: $exception');
        },
        child: null,
      );
    }

    // 没有头像时显示用户名首字母
    return CircleAvatar(
      radius: size / 2,
      child: Text(
        user.username[0].toUpperCase(),
        style: TextStyle(fontSize: size / 2),
      ),
    );
  }
}

class _CollapsedItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _CollapsedItem({required this.icon, required this.selectedIcon, required this.label});
}
