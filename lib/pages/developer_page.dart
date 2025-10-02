import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../services/developer_mode_service.dart';
import '../services/music_service.dart';
import '../services/auth_service.dart';

/// 开发者页面
class DeveloperPage extends StatefulWidget {
  const DeveloperPage({super.key});

  @override
  State<DeveloperPage> createState() => _DeveloperPageState();
}

class _DeveloperPageState extends State<DeveloperPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // 监听日志更新，自动滚动到底部
    DeveloperModeService().addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _logScrollController.dispose();
    DeveloperModeService().removeListener(_scrollToBottom);
    super.dispose();
  }

  void _scrollToBottom() {
    if (_logScrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_logScrollController.hasClients) {
          _logScrollController.animateTo(
            _logScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.code, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text('开发者模式'),
          ],
        ),
        backgroundColor: colorScheme.surface,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.bug_report), text: '日志'),
            Tab(icon: Icon(Icons.storage), text: '数据'),
            Tab(icon: Icon(Icons.settings), text: '设置'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new),
            tooltip: '退出开发者模式',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('退出开发者模式'),
                  content: const Text('确定要退出开发者模式吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () {
                        DeveloperModeService().disableDeveloperMode();
                        Navigator.pop(context);
                      },
                      child: const Text('确定'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLogTab(),
          _buildDataTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  /// 构建日志标签页
  Widget _buildLogTab() {
    return AnimatedBuilder(
      animation: DeveloperModeService(),
      builder: (context, child) {
        final logs = DeveloperModeService().logs;
        
        return Column(
          children: [
            // 工具栏
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Text(
                    '共 ${logs.length} 条日志',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: '复制全部',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: logs.join('\n')));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制到剪贴板')),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: '清除日志',
                    onPressed: () {
                      DeveloperModeService().clearLogs();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            // 日志列表
            Expanded(
              child: logs.isEmpty
                  ? const Center(child: Text('暂无日志'))
                  : ListView.builder(
                      controller: _logScrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: SelectableText(
                            log,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  /// 构建数据标签页
  Widget _buildDataTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDataSection(
          '音乐服务',
          Icons.music_note,
          [
            '榜单数量: ${MusicService().toplists.length}',
            '是否缓存: ${MusicService().isCached ? "是" : "否"}',
            '加载状态: ${MusicService().isLoading ? "加载中" : "空闲"}',
            '错误信息: ${MusicService().errorMessage ?? "无"}',
          ],
        ),
        const SizedBox(height: 16),
        _buildDataSection(
          '用户认证',
          Icons.person,
          [
            '登录状态: ${AuthService().isLoggedIn ? "已登录" : "未登录"}',
            '用户名: ${AuthService().currentUser?.username ?? "无"}',
            '邮箱: ${AuthService().currentUser?.email ?? "无"}',
            '验证状态: ${AuthService().currentUser?.isVerified ?? false ? "已验证" : "未验证"}',
          ],
        ),
        const SizedBox(height: 16),
        _buildDataSection(
          '榜单详情',
          Icons.list,
          MusicService().toplists.map((toplist) {
            return '${toplist.name}: ${toplist.tracks.length} 首歌曲';
          }).toList(),
        ),
      ],
    );
  }

  /// 构建设置标签页
  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('版本信息'),
            subtitle: const Text('Cyrene Music v1.0.0'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.flutter_dash),
            title: const Text('Flutter 版本'),
            subtitle: const Text('3.32.7'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.smartphone),
            title: const Text('平台'),
            subtitle: Text(_getPlatformName()),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () {
            DeveloperModeService().addLog('📋 触发测试日志');
          },
          icon: const Icon(Icons.bug_report),
          label: const Text('添加测试日志'),
        ),
      ],
    );
  }

  /// 构建数据区块
  Widget _buildDataSection(String title, IconData icon, List<String> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SelectableText(
                item,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  String _getPlatformName() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    if (kIsWeb) return 'Web';
    return 'Unknown';
  }
}

