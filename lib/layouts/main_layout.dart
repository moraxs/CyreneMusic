import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/custom_title_bar.dart';
import '../pages/home_page.dart';
import '../pages/settings_page.dart';

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
        onPressed: () {
          // TODO: 打开用户页面
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('用户功能开发中...')),
          );
        },
        child: const Icon(Icons.account_circle_outlined),
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
                  icon: const Icon(Icons.account_circle_outlined),
                  tooltip: '用户',
                  onPressed: () {
                    // TODO: 打开用户页面
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('用户功能开发中...')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
