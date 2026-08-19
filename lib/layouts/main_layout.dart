import 'dart:io';
import 'dart:ui' as ui;
import '../services/audio_source_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/cupertino/cupertino_bottom_nav.dart';
import '../widgets/oculus/oculus_bottom_nav.dart';
import '../widgets/mini_player.dart';
import '../pages/home_page.dart';
import '../pages/discover_page.dart';
import '../pages/history_page.dart';
import '../pages/my_page/my_page.dart';
import '../pages/local_page.dart';
import '../pages/settings_page.dart';
import '../pages/developer_page.dart';
import '../pages/support_page.dart';
import '../services/auth_service.dart';
import '../services/layout_preference_service.dart';
import '../services/developer_mode_service.dart';
import '../services/global_back_handler_service.dart';
import '../utils/page_visibility_notifier.dart';
import '../utils/theme_manager.dart';
import '../pages/auth/auth_page.dart';
import '../services/auth_overlay_service.dart';
import '../services/player_service.dart';
import '../services/persistent_storage_service.dart';
import '../pages/mobile_setup_page.dart';
import '../widgets/global_watermark.dart';

/// 主布局 - 包含侧边导航栏和内容区域
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  // NavigationDrawer 固定宽度与 NavigationRail 展开状态一致（Material 3 默认 256）
  static const double _drawerWidth = 256.0;
  static const double _collapsedWidth = 80.0; // 折叠状态宽度，仅显示图标
  bool _isDrawerCollapsed = false; // 抽屉是否处于折叠状态（默认展开）

  // 页面列表
  List<Widget> get _pages {
    final isLocalMode = PersistentStorageService().enableLocalMode;

    if (isLocalMode) {
      return [
        const LocalPage(),
        MobileSetupPage(), // 本地模式下的“设置”显示引导页
      ];
    }

    final pages = <Widget>[
      const HomePage(),
      const DiscoverPage(),
      const HistoryPage(),
      const LocalPage(), // 本地
      const MyPage(), // 我的（歌单+听歌统计）
      const SupportPage(), // 支持
      const SettingsPage(),
    ];

    // 如果开发者模式启用，添加开发者页面
    if (DeveloperModeService().isDeveloperMode) {
      pages.add(const DeveloperPage());
    }

    return pages;
  }

  int get _supportIndex => _pages.indexWhere((w) => w is SupportPage);
  int get _settingsIndex => _pages.indexWhere((w) => w is SettingsPage);

  Future<void> _openMoreBottomSheet(BuildContext context) async {
    final isLocalMode = PersistentStorageService().enableLocalMode;
    if (isLocalMode) return; // 本地模式下没有“更多”选项，因为只有 2 个 Tab

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
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
                  final idx = _settingsIndex;
                  setState(() => _selectedIndex = idx); // 设置
                  PageVisibilityNotifier().setCurrentPage(idx);
                  // 触发开发者模式（与设置点击一致）
                  DeveloperModeService().onSettingsClicked();
                },
              ),
              if (isPortrait)
                ListTile(
                  leading: const Icon(Icons.favorite_outline),
                  title: const Text('支持'),
                  onTap: () {
                    Navigator.pop(context);
                    final idx = _supportIndex;
                    setState(() => _selectedIndex = idx); // 支持
                    PageVisibilityNotifier().setCurrentPage(idx);
                  },
                ),
              if (DeveloperModeService().isDeveloperMode)
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('Dev'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = _pages.length - 1);
                    PageVisibilityNotifier().setCurrentPage(_pages.length - 1);
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
    // 监听页面可见性通知器（用于跨组件切换 Tab）
    PageVisibilityNotifier().addListener(_onPageVisibilityNotifierChanged);
    // 监听开发者模式变化
    DeveloperModeService().addListener(_onDeveloperModeChanged);
    // 监听主题变化（包括移动端主题框架切换）
    ThemeManager().addListener(_onThemeChanged);
    // 监听音源服务变化（用于本地模式切换）
    AudioSourceService().addListener(_onThemeChanged); // 重用 _onThemeChanged 逻辑即可


    // 初始化系统主题色（在 build 完成后执行）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ThemeManager().initializeSystemColor(context);
      }
    });

    // 应用启动后验证持久化的登录状态（Material 布局）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AuthService().validateToken();
    });
    
    // 初始化 PageVisibilityNotifier 状态与当前页面一致
    // 避免因为热重启或某些情况导致状态不同步（Notifier 是单例可能保留了旧状态）
    PageVisibilityNotifier().setCurrentPage(_selectedIndex);
  }

  @override
  void dispose() {
    AuthService().removeListener(_onAuthChanged);
    LayoutPreferenceService().removeListener(_onLayoutPreferenceChanged);
    PageVisibilityNotifier().removeListener(_onPageVisibilityNotifierChanged);
    DeveloperModeService().removeListener(_onDeveloperModeChanged);
    ThemeManager().removeListener(_onThemeChanged);
    AudioSourceService().removeListener(_onThemeChanged);
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

  void _onThemeChanged() {
    print('🎨 [MainLayout] _onThemeChanged called (Theme or AudioSource change)');
    if (mounted) {
      // 使用 addPostFrameCallback 避免在构建期间调用 setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _onPageVisibilityNotifierChanged() {
    if (mounted) {
      final newIndex = PageVisibilityNotifier().currentPageIndex;
      if (_selectedIndex != newIndex && newIndex < _pages.length) {
        print('📡 [MainLayout] PageVisibilityNotifier triggered index: $newIndex (Current: $_selectedIndex)');
        // 使用 addPostFrameCallback 避免在构建期间调用 setState
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedIndex = newIndex;
              print('🔄 [MainLayout] _selectedIndex updated via Notifier to: $_selectedIndex');
            });
          }
        });
      }
    }
  }

  void _onDeveloperModeChanged() {
    if (mounted) {
      // 使用 addPostFrameCallback 延迟到构建完成后再调用 setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            // 如果当前选中的索引超出可用页面（例如从 Dev 切换为非 Dev），切换到首页
            final maxIndex = _pages.length - 1;
            if (_selectedIndex > maxIndex) {
              _selectedIndex = 0;
            }
          });
        }
      });
    }
  }

  /// 处理 Android 返回键
  void _handleAndroidBack() {
    // 1. 首先检查全局返回处理器（二级页面等）
    if (GlobalBackHandlerService().handleBack()) {
      return;
    }
    
    // 2. 如果不在首页，返回首页
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
      PageVisibilityNotifier().setCurrentPage(0);
      return;
    }
    
    // 3. 在首页，退出应用
    SystemNavigator.pop();
  }

  void _handleUserButtonTap() {
    if (AuthService().isLoggedIn) {
      // 已登录，显示用户菜单
      _showUserMenu();
    } else {
      // 未登录：真正的桌面端操作系统使用覆盖层；移动端操作系统（Android/iOS，含平板模式）使用弹窗/整页
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已退出登录')));
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🏗️ [MainLayout] build called. SelectedIndex: $_selectedIndex, LocalMode: ${PersistentStorageService().enableLocalMode}');
    // 根据平台选择不同的布局
    if (Platform.isAndroid || Platform.isIOS) {
      if (ThemeManager().isTablet) {
        // 平板设备使用桌面端布局逻辑
        return GlobalWatermark(child: _buildDesktopLayout(context));
      }
      // 手机始终使用移动布局
      return GlobalWatermark(child: _buildMobileLayout(context));
    } else if (Platform.isWindows) {
      // Windows 根据用户偏好选择布局，使用 AnimatedBuilder 确保更新
      return AnimatedBuilder(
        animation: LayoutPreferenceService(),
        builder: (context, child) {
          final isDesktop = LayoutPreferenceService().isDesktopLayout;
          print('🖥️ [MainLayout] 当前布局模式: ${isDesktop ? "桌面模式" : "移动模式"}');

      return GlobalWatermark(
        child: isDesktop
            ? _buildDesktopLayout(context)
            : _buildMobileLayout(context),
      );
        },
      );
    } else {
      // 其他桌面平台（macOS/Linux）默认使用桌面布局
      return _buildDesktopLayout(context);
    }
  }

  /// 构建桌面端布局（Windows/Linux/macOS）
  Widget _buildDesktopLayout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          // Windows 平台显示自定义标题栏
          if (Platform.isWindows) const CustomTitleBar(),

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
                        Expanded(child: _pages[_selectedIndex]),
                      ],
                    ),
                    if (overlay.isVisible)
                      // 完全参照首页-歌单详情样式：覆盖右侧内容区，保留侧栏与标题栏
                      Positioned.fill(
                        child: Row(
                          children: [
                            // 占位侧栏宽度
                            SizedBox(
                              width: _isDrawerCollapsed
                                  ? _collapsedWidth
                                  : _drawerWidth,
                            ),
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
                                          icon: const Icon(
                                            Icons.arrow_back_rounded,
                                          ),
                                          onPressed: () =>
                                              AuthOverlayService().hide(false),
                                          tooltip: '返回',
                                        ),
                                      ),
                                      Expanded(
                                        child: PrimaryScrollController.none(
                                          child: AuthPage(
                                            initialTab: overlay.initialTab,
                                          ),
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
    final isLocalMode = PersistentStorageService().enableLocalMode;
    print('📱 [MainLayout] Building Mobile Layout (LocalMode: $isLocalMode, SelectedIndex: $_selectedIndex)');
    
    final colorScheme = Theme.of(context).colorScheme;
    final isCupertinoUI = (Platform.isIOS || Platform.isAndroid) && ThemeManager().isCupertinoFramework;
    final isOculusUI = (Platform.isIOS || Platform.isAndroid) && ThemeManager().isOculusFramework;

    return PopScope(
      canPop: false, // 始终拦截返回键
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleAndroidBack();
      },
      child: Scaffold(
        backgroundColor: isCupertinoUI 
            ? (Theme.of(context).brightness == Brightness.dark 
                ? CupertinoColors.black 
                : CupertinoColors.systemGroupedBackground)
            : colorScheme.surface,
        body: Stack(
          children: [
            // 主内容层 - 使用 RepaintBoundary 隔离，防止 BackdropFilter 导致滚动残影
            RepaintBoundary(
              child: Column(
                children: [
                  if (Platform.isWindows) const CustomTitleBar(),
                  Expanded(child: _pages[_selectedIndex]),
                ],
              ),
            ),
            // 悬浮迷你播放器（不占用布局空间）
            Positioned(
              left: 0,
              right: 0,
              bottom: isOculusUI ? 100 : (isCupertinoUI ? 80 : 0), // Oculus 全宽底栏较高
              child: AnimatedBuilder(
                animation: PlayerService(),
                builder: (context, child) {
                  final hasMiniPlayer =
                      PlayerService().currentTrack != null ||
                      PlayerService().currentSong != null;
                  if (!hasMiniPlayer) return const SizedBox.shrink();
                  return const MiniPlayer();
                },
              ),
            ),
            // iOS 26 悬浮液态玻璃 Tab 栏
            if (isCupertinoUI)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildCupertinoTabBar(context),
              ),
            // Oculus 悬浮胶囊 Tab 栏
            if (isOculusUI)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildOculusTabBar(context),
              ),
          ],
        ),
        // 非悬浮模式使用 bottomNavigationBar
        bottomNavigationBar: (isCupertinoUI || isOculusUI) 
            ? null
            : _buildGlassBottomNavigationBar(context),
      ),
    );
  }

  /// 构建 iOS 26 风格的悬浮液态玻璃底部导航栏（使用 liquid_glass_widgets 库）
  Widget _buildCupertinoTabBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orientation = MediaQuery.of(context).orientation;
    final bool isLandscape = orientation == Orientation.landscape;
    final int supportIndex = _supportIndex;
    final int myIndex = _pages.indexWhere((w) => w is MyPage);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isLocalMode = PersistentStorageService().enableLocalMode;

    // 构建 GlassBottomBarTab 列表
    final List<GlassBottomBarTab> tabs = isLocalMode
        ? [
            GlassBottomBarTab(
              label: '本地',
              icon: SvgPicture.asset('assets/ui/FluentColorHistory16.svg', width: 22, height: 22),
            ),
            GlassBottomBarTab(
              label: '退出本地',
              icon: SvgPicture.asset('assets/ui/FluentColorSettings16.svg', width: 22, height: 22),
            ),
          ]
        : [
            GlassBottomBarTab(
              label: '首页',
              icon: SvgPicture.asset('assets/ui/FluentColorHome16.svg', width: 22, height: 22),
            ),
            GlassBottomBarTab(
              label: '发现',
              icon: SvgPicture.asset('assets/ui/FluentColorSearchSparkle16.svg', width: 22, height: 22),
            ),
            GlassBottomBarTab(
              label: '我的',
              icon: SvgPicture.asset('assets/ui/FluentColorPerson16.svg', width: 22, height: 22),
            ),
            if (isLandscape)
              GlassBottomBarTab(
                label: '支持',
                icon: SvgPicture.asset('assets/ui/FluentColorHeart16.svg', width: 22, height: 22),
              ),
            GlassBottomBarTab(
              label: '更多',
              icon: SvgPicture.asset('assets/ui/FluentColorAppsList20.svg', width: 22, height: 22),
            ),
          ];

    // 计算当前选中的 nav 索引
    int currentIndex;
    if (isLocalMode) {
      currentIndex = _selectedIndex;
    } else if (_selectedIndex == 0) {
      currentIndex = 0; // 首页
    } else if (_selectedIndex == 1) {
      currentIndex = 1; // 发现
    } else if (_selectedIndex == myIndex) {
      currentIndex = 2; // 我的
    } else if (isLandscape && _selectedIndex == supportIndex) {
      currentIndex = 3; // 支持
    } else {
      currentIndex = isLandscape ? 4 : 3; // 更多
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomPadding > 0 ? bottomPadding - 8 : 0,
      ),
      child: GlassBottomBar(
        tabs: tabs,
        selectedIndex: currentIndex.clamp(0, tabs.length - 1),
        onTabSelected: (index) {
          if (isLocalMode) {
            if (index == _selectedIndex) return;
            setState(() => _selectedIndex = index);
            PageVisibilityNotifier().setCurrentPage(index);
            return;
          }

          // “更多” Tab
          final int moreTab = tabs.length - 1;
          if (index == moreTab) {
            _openCupertinoMoreSheet(context);
            return;
          }

          int targetPageIndex;
          if (index == 0) {
            targetPageIndex = 0; // 首页
          } else if (index == 1) {
            targetPageIndex = 1; // 发现
          } else if (index == 2) {
            targetPageIndex = myIndex; // 我的
          } else if (isLandscape && index == 3) {
            targetPageIndex = supportIndex; // 支持 (横屏)
          } else {
            return;
          }

          setState(() => _selectedIndex = targetPageIndex);
          PageVisibilityNotifier().setCurrentPage(targetPageIndex);
        },
        barHeight: 60,
        verticalPadding: 8,
        horizontalPadding: 12,
        quality: GlassQuality.premium, // 底部栏是固定表面，使用 premium 获得完整 shader 管线
        showIndicator: true,
        magnification: 1.15, // 轻微透镜放大效果，选中 Tab 有视觉焦点感
        iconSize: 22,
        labelFontSize: 10,
        selectedIconColor: Colors.white,
        unselectedIconColor: isDark ? Colors.white70 : Colors.black54,
        // 主体玻璃面板的折射参数
        glassSettings: LiquidGlassSettings(
          thickness: isDark ? 40 : 25,           // 暗色模式下更厚实、更有质感
          blur: isDark ? 5 : 3,                   // 模糊强度
          chromaticAberration: 0.4,               // 色散效果 — 彩虹边缘折射
          refractiveIndex: 1.6,                   // 折射率 — 接近光学玻璃
          saturation: isDark ? 0.8 : 0.6,         // 饱和度 — 暗色下更丰富
          lightIntensity: isDark ? 0.8 : 0.5,     // 高光强度
          ambientStrength: 1.0,                   // 环境光
          specularSharpness: GlassSpecularSharpness.medium, // iOS 26 标准高光
          glassColor: isDark 
              ? const Color(0x3DFFFFFF)            // 暗色模式: white24
              : const Color(0x1AFFFFFF),           // 亮色模式: 更通透
        ),
        // 滑动指示器的折射参数 — 更强的折射感以突出选中态
        indicatorSettings: const LiquidGlassSettings(
          thickness: 20,
          blur: 0,
          chromaticAberration: 0.6,               // 指示器色散更强
          refractiveIndex: 1.2,                   // 略微折射
          saturation: 1.5,                        // 高饱和使选中态更鲜明
          lightIntensity: 2.0,                    // 强高光
          glassColor: Color.from(alpha: 0.12, red: 1, green: 1, blue: 1),
        ),
        // 发光效果参数
        glowBlurRadius: 36,
        glowSpreadRadius: 10,
        glowOpacity: isDark ? 0.7 : 0.5,
      ),
    );
  }
  
  /// Cupertino 风格的更多菜单
  Future<void> _openCupertinoMoreSheet(BuildContext context) async {
    final orientation = MediaQuery.of(context).orientation;
    final bool isPortrait = orientation == Orientation.portrait;
    
    await showCupertinoMoreSheet(
      context: context,
      onHistoryTap: () {
        setState(() => _selectedIndex = 2);
        PageVisibilityNotifier().setCurrentPage(2);
      },
      onLocalTap: () {
        setState(() => _selectedIndex = 3);
        PageVisibilityNotifier().setCurrentPage(3);
      },
      onSettingsTap: () {
        final idx = _settingsIndex;
        setState(() => _selectedIndex = idx);
        PageVisibilityNotifier().setCurrentPage(idx);
        DeveloperModeService().onSettingsClicked();
      },
      onSupportTap: () {
        final idx = _supportIndex;
        setState(() => _selectedIndex = idx);
        PageVisibilityNotifier().setCurrentPage(idx);
      },
      onDevTap: () {
        setState(() => _selectedIndex = _pages.length - 1);
        PageVisibilityNotifier().setCurrentPage(_pages.length - 1);
      },
      showSupport: isPortrait,
      showDev: DeveloperModeService().isDeveloperMode,
    );
  }

  /// 构建 Oculus 风格的悬浮精致底部导航栏
  Widget _buildOculusTabBar(BuildContext context) {
    final isLocalMode = PersistentStorageService().enableLocalMode;
    final int myIndex = _pages.indexWhere((w) => w is MyPage);
    
    // Tab 项目数据
    final List<OculusNavItem> tabItems = isLocalMode
        ? [
            const OculusNavItem(
              svgAsset: 'assets/ui/FluentColorHistory16.svg',
              label: '本地',
            ),
            const OculusNavItem(
              svgAsset: 'assets/ui/FluentColorSettings16.svg',
              label: '设置',
            ),
          ]
        : [
            const OculusNavItem(
              svgAsset: 'assets/ui/FluentColorHome16.svg',
              label: '首页',
            ),
            const OculusNavItem(
              svgAsset: 'assets/ui/FluentColorSearchSparkle16.svg',
              label: '发现',
            ),
            const OculusNavItem(
              svgAsset: 'assets/ui/FluentColorPerson16.svg',
              label: '我的',
            ),
            const OculusNavItem(
              svgAsset: 'assets/ui/FluentColorAppsList20.svg',
              label: '更多',
            ),
          ];

    int navSelectedIndex() {
      if (isLocalMode) return _selectedIndex;
      if (_selectedIndex == 0) return 0;
      if (_selectedIndex == 1) return 1;
      if (_selectedIndex == myIndex) return 2;
      return tabItems.length - 1; // 更多
    }

    return OculusBottomNavigationBar(
      currentIndex: navSelectedIndex(),
      onTap: (index) async {
        if (isLocalMode) {
          setState(() => _selectedIndex = index);
          PageVisibilityNotifier().setCurrentPage(index);
          return;
        }

        final int moreTab = tabItems.length - 1;
        if (index == moreTab) {
          await _openMoreBottomSheet(context);
          return;
        }

        int targetIndex = index;
        if (index == 2) targetIndex = myIndex;
        
        setState(() => _selectedIndex = targetIndex);
        PageVisibilityNotifier().setCurrentPage(targetIndex);
      },
      items: tabItems,
    );
  }

  Widget _buildGlassBottomNavigationBar(BuildContext context) {
    final isLocalMode = PersistentStorageService().enableLocalMode;
    print('🎨 [MainLayout] Building Glass Bottom Navigation (LocalMode: $isLocalMode)');
    final orientation = MediaQuery.of(context).orientation;
    final bool useGlass = Platform.isAndroid || orientation == Orientation.portrait;

    final bool isLandscape = orientation == Orientation.landscape;
    final int supportIndex = _supportIndex;
    final int myIndex = _pages.indexWhere((w) => w is MyPage);
    // Build destinations: landscape adds Support tab before More
    final List<NavigationDestination> destinations = isLocalMode
        ? [
            const NavigationDestination(
              icon: Icon(Icons.folder_open_outlined),
              selectedIcon: Icon(Icons.folder_open),
              label: '本地',
            ),
            const NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '设置',
            ),
          ]
        : [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '首页',
            ),
            const NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: '发现',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outlined),
              selectedIcon: Icon(Icons.person),
              label: '我的',
            ),
            if (isLandscape)
              const NavigationDestination(
                icon: Icon(Icons.favorite_outline),
                selectedIcon: Icon(Icons.favorite),
                label: '支持',
              ),
            const NavigationDestination(
              icon: Icon(Icons.more_horiz),
              selectedIcon: Icon(Icons.more_horiz),
              label: '更多',
            ),
          ];

    int navSelectedIndex() {
      final isLocalMode = PersistentStorageService().enableLocalMode;
      if (isLocalMode) return _selectedIndex;

      if (_selectedIndex == 0) return 0; // 首页
      if (_selectedIndex == 1) return 1; // 发现
      if (_selectedIndex == myIndex) return 2; // 我的
      if (isLandscape && _selectedIndex == supportIndex) return 3; // 支持
      return destinations.length - 1; // 更多
    }

    final baseNav = NavigationBar(
      selectedIndex: navSelectedIndex(),
      onDestinationSelected: (int tabIndex) async {
        final isLocalMode = PersistentStorageService().enableLocalMode;
        print('🖱️ [MainLayout] NavigationBar tab selected: $tabIndex (LocalMode: $isLocalMode)');
        
        int targetIndex = tabIndex;
        if (!isLocalMode) {
          final int moreTab = destinations.length - 1;
          if (tabIndex == moreTab) {
            print('📑 [MainLayout] Opening "More" bottom sheet');
            await _openMoreBottomSheet(context);
            return;
          }

          // 修复索引映射：从标签索引映射回真实的页面索引
          if (tabIndex == 0) {
            targetIndex = 0;
          } else if (tabIndex == 1) {
            targetIndex = 1;
          } else if (tabIndex == 2) {
            targetIndex = myIndex;
          } else if (isLandscape && tabIndex == 3) {
            targetIndex = supportIndex;
          }
        }

        setState(() {
          _selectedIndex = targetIndex;
          print('🔄 [MainLayout] _selectedIndex updated to: $_selectedIndex');
        });
        PageVisibilityNotifier().setCurrentPage(targetIndex);
      },
      destinations: destinations,
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
          borderRadius: BorderRadius.zero,
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
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.18),
                        width: 1,
                      ),
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
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: isCollapsed
                  ? KeyedSubtree(
                      key: const ValueKey('collapsed'),
                      child: _buildCollapsedDestinations(colorScheme),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('expanded'),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          navigationDrawerTheme:
                              const NavigationDrawerThemeData(
                                backgroundColor: Colors.transparent,
                                surfaceTintColor: Colors.transparent,
                              ),
                        ),
                        child: NavigationDrawer(
                          selectedIndex: _selectedIndex,
                          onDestinationSelected: (int index) {
                            final isLocalMode = PersistentStorageService().enableLocalMode;
                            print('🖱️ [MainLayout] NavigationDrawer index selected: $index (LocalMode: $isLocalMode)');

                            // 如果点击的是设置按钮，触发开发者模式检测
                            if (!isLocalMode && index == _settingsIndex) {
                              DeveloperModeService().onSettingsClicked();
                            }

                            setState(() {
                              _selectedIndex = index;
                              print('🔄 [MainLayout] _selectedIndex updated to: $_selectedIndex');
                            });
                            // 通知页面切换
                            PageVisibilityNotifier().setCurrentPage(index);
                          },
                          children: [
                            const SizedBox(height: 8),
                            if (PersistentStorageService().enableLocalMode) ...[
                              const NavigationDrawerDestination(
                                icon: Icon(Icons.folder_open),
                                selectedIcon: Icon(Icons.folder),
                                label: Text('本地'),
                              ),
                              const NavigationDrawerDestination(
                                icon: Icon(Icons.settings_outlined),
                                selectedIcon: Icon(Icons.settings),
                                label: Text('本地设置'),
                              ),
                            ] else ...[
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
                                icon: Icon(Icons.favorite_outline),
                                selectedIcon: Icon(Icons.favorite),
                                label: Text('支持'),
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
                                  label: Text('开发者'),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ),
              ),
          ],
      ),
    );
  }

  Widget _buildCollapsedDestinations(ColorScheme colorScheme) {
    final isLocalMode = PersistentStorageService().enableLocalMode;
    
    final List<_CollapsedItem> items = isLocalMode
        ? [
            _CollapsedItem(
              icon: Icons.folder_open,
              selectedIcon: Icons.folder,
              label: '本地',
            ),
            _CollapsedItem(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings,
              label: '本地设置',
            ),
          ]
        : [
            _CollapsedItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: '首页',
            ),
            _CollapsedItem(
              icon: Icons.explore_outlined,
              selectedIcon: Icons.explore,
              label: '发现',
            ),
            _CollapsedItem(
              icon: Icons.history_outlined,
              selectedIcon: Icons.history,
              label: '历史',
            ),
            _CollapsedItem(
              icon: Icons.folder_open,
              selectedIcon: Icons.folder,
              label: '本地',
            ),
            _CollapsedItem(
              icon: Icons.person_outlined,
              selectedIcon: Icons.person,
              label: '我的',
            ),
            _CollapsedItem(
              icon: Icons.favorite_outline,
              selectedIcon: Icons.favorite,
              label: '支持',
            ),
            _CollapsedItem(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings,
              label: '设置',
            ),
          ];
    if (DeveloperModeService().isDeveloperMode) {
      items.add(
        _CollapsedItem(
          icon: Icons.code,
          selectedIcon: Icons.code,
          label: 'Dev',
        ),
      );
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
              color: isSelected
                  ? colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  final isLocalMode = PersistentStorageService().enableLocalMode;
                  print('🖱️ [MainLayout] Collapsed Drawer item selected: $index (LocalMode: $isLocalMode)');
                  
                  if (!isLocalMode && index == _settingsIndex) {
                    DeveloperModeService().onSettingsClicked();
                  }
                  
                  setState(() {
                    _selectedIndex = index;
                    print('🔄 [MainLayout] _selectedIndex updated via Collapsed Drawer to: $_selectedIndex');
                  });
                  PageVisibilityNotifier().setCurrentPage(index);
                },
                child: SizedBox(
                  height: 48,
                  child: Center(
                    child: Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
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
  const _CollapsedItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
