import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/custom_title_bar.dart';
import '../pages/home_page.dart';
import '../pages/settings_page.dart';
import '../services/auth_service.dart';
import '../pages/auth/login_page.dart';

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
  final List<Widget> _pages = const [
    HomePage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    // 监听认证状态变化
    AuthService().addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthService().removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleUserButtonTap() {
    if (AuthService().isLoggedIn) {
      // 已登录，显示用户菜单
      _showUserMenu();
    } else {
      // 未登录，跳转到登录页面
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      ).then((_) {
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
              title: const Text('个人信息'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('个人信息功能开发中...')),
                );
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
      return _buildMobileLayout(context);
    } else {
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
        ],
      ),
    );
  }

  /// 构建移动端布局（Android/iOS）
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleUserButtonTap,
        child: AuthService().isLoggedIn
            ? const Icon(Icons.account_circle)
            : const Icon(Icons.account_circle_outlined),
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
        setState(() {
          _selectedIndex = index;
        });
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
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('首页'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('设置'),
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
                IconButton(
                  icon: AuthService().isLoggedIn
                      ? const Icon(Icons.account_circle)
                      : const Icon(Icons.account_circle_outlined),
                  tooltip: AuthService().isLoggedIn ? '用户中心' : '登录',
                  onPressed: _handleUserButtonTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
