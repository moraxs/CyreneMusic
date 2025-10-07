import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/mini_player.dart';
import '../pages/home_page.dart';
import '../pages/history_page.dart';
import '../pages/my_page.dart';
import '../pages/settings_page.dart';
import '../pages/developer_page.dart';
import '../services/auth_service.dart';
import '../services/layout_preference_service.dart';
import '../services/developer_mode_service.dart';
import '../utils/page_visibility_notifier.dart';
import '../utils/theme_manager.dart';
import '../pages/auth/auth_page.dart';

/// 主布局 - 包含侧边导航栏和内容区域
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  bool _isRailExtended = false;

  // 页面列表
  List<Widget> get _pages {
    final pages = <Widget>[
      const HomePage(),
      const HistoryPage(),
      const MyPage(), // 我的（歌单+听歌统计）
      const SettingsPage(),
    ];
    
    // 如果开发者模式启用，添加开发者页面
    if (DeveloperModeService().isDeveloperMode) {
      pages.add(const DeveloperPage());
    }
    
    return pages;
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
            if (_selectedIndex >= 4 && !DeveloperModeService().isDeveloperMode) {
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
      // 未登录，跳转到登录页面
      showAuthDialog(context).then((_) {
        if (mounted) setState(() {});
      });
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
                  _selectedIndex = 2; // 切换到我的页面
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
            child: Row(
              children: [
                // 侧边导航栏
                _buildNavigationRail(colorScheme),
                
                // 分割线
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: colorScheme.outlineVariant,
                ),
                
                // 内容区域
                Expanded(
                  child: _pages[_selectedIndex],
                ),
              ],
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
      body: Column(
        children: [
          // Windows 平台且使用移动布局时也显示自定义标题栏
          if (Platform.isWindows)
            const CustomTitleBar(),
          
          // 主要内容区域
          Expanded(
            child: _pages[_selectedIndex],
          ),
          
          // 迷你播放器
          const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          // 如果点击的是设置按钮，触发开发者模式检测
          if (index == 3) {
            DeveloperModeService().onSettingsClicked();
          }
          
          setState(() {
            _selectedIndex = index;
          });
          // 通知页面切换
          PageVisibilityNotifier().setCurrentPage(index);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          const NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: '历史',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
          // 开发者模式导航项（动态显示）
          if (DeveloperModeService().isDeveloperMode)
            const NavigationDestination(
              icon: Icon(Icons.code),
              selectedIcon: Icon(Icons.code),
              label: 'Dev',
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleUserButtonTap,
        child: _buildUserAvatar(),
      ),
    );
  }

  /// 构建侧边导航栏
  Widget _buildNavigationRail(ColorScheme colorScheme) {
    return NavigationRail(
      extended: _isRailExtended,
      backgroundColor: colorScheme.surface,
      selectedIndex: _selectedIndex,
      onDestinationSelected: (int index) {
        // 如果点击的是设置按钮，触发开发者模式检测
        if (index == 3) {
          DeveloperModeService().onSettingsClicked();
        }
        
        setState(() {
          _selectedIndex = index;
        });
        // 通知页面切换
        PageVisibilityNotifier().setCurrentPage(index);
      },
      labelType: _isRailExtended 
          ? NavigationRailLabelType.none 
          : NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: FloatingActionButton(
          elevation: 0,
          onPressed: () {
            setState(() {
              _isRailExtended = !_isRailExtended;
            });
          },
          child: Icon(_isRailExtended ? Icons.menu_open : Icons.menu),
        ),
      ),
        destinations: [
          const NavigationRailDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: Text('首页'),
          ),
          const NavigationRailDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: Text('历史'),
          ),
          const NavigationRailDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: Text('我的'),
          ),
          const NavigationRailDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: Text('设置'),
          ),
          // 开发者模式导航项（动态显示）
          if (DeveloperModeService().isDeveloperMode)
            const NavigationRailDestination(
              icon: Icon(Icons.code),
              selectedIcon: Icon(Icons.code),
              label: Text('Dev'),
            ),
        ],
      // 可以添加底部的额外按钮
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isRailExtended)
                  const Divider()
                else
                  Container(),
                Tooltip(
                  message: AuthService().isLoggedIn ? '用户中心' : '登录',
                  child: InkWell(
                    onTap: _handleUserButtonTap,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _buildUserAvatar(size: 32),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
