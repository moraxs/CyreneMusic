import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/theme_manager.dart';
import '../widgets/custom_color_picker_dialog.dart';
import '../services/url_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/layout_preference_service.dart';
import '../pages/auth/login_page.dart';

/// 设置页面
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _audioQuality = 'high';
  bool _autoPlay = true;

  @override
  void initState() {
    super.initState();
    print('⚙️ [SettingsPage] 初始化设置页面...');
    
    // 监听主题变化
    ThemeManager().addListener(_onThemeChanged);
    // 监听 URL 服务变化
    UrlService().addListener(_onUrlServiceChanged);
    // 监听认证状态变化
    AuthService().addListener(_onAuthChanged);
    // 监听位置信息变化
    LocationService().addListener(_onLocationChanged);
    // 监听布局偏好变化
    LayoutPreferenceService().addListener(_onLayoutPreferenceChanged);
    
    // 如果已登录，获取 IP 归属地
    final isLoggedIn = AuthService().isLoggedIn;
    print('⚙️ [SettingsPage] 当前登录状态: $isLoggedIn');
    
    if (isLoggedIn) {
      print('⚙️ [SettingsPage] 用户已登录，开始获取IP归属地...');
      LocationService().fetchLocation();
    } else {
      print('⚙️ [SettingsPage] 用户未登录，跳过获取IP归属地');
    }
  }

  @override
  void dispose() {
    ThemeManager().removeListener(_onThemeChanged);
    UrlService().removeListener(_onUrlServiceChanged);
    AuthService().removeListener(_onAuthChanged);
    LocationService().removeListener(_onLocationChanged);
    LayoutPreferenceService().removeListener(_onLayoutPreferenceChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onUrlServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onAuthChanged() {
    if (mounted) {
      setState(() {});
      // 登录状态变化时获取/清除位置信息
      if (AuthService().isLoggedIn) {
        print('👤 [SettingsPage] 用户已登录，开始获取IP归属地...');
        LocationService().fetchLocation();
      } else {
        print('👤 [SettingsPage] 用户已退出，清除IP归属地...');
        LocationService().clearLocation();
      }
    }
  }

  void _onLocationChanged() {
    print('🌍 [SettingsPage] 位置信息已更新，刷新UI...');
    if (mounted) {
      setState(() {});
    }
  }

  void _onLayoutPreferenceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // 顶部标题
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: colorScheme.surface,
            title: Text(
              '设置',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // 设置内容
          SliverPadding(
            padding: const EdgeInsets.all(24.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 用户卡片
                _buildUserCard(),
                const SizedBox(height: 24),
                
                // 外观设置
                _buildSectionTitle('外观'),
                _buildSettingCard([
                  _buildSwitchTile(
                    title: '深色模式',
                    subtitle: '启用深色主题',
                    icon: Icons.dark_mode,
                    value: ThemeManager().isDarkMode,
                    onChanged: (value) {
                      ThemeManager().toggleDarkMode(value);
                    },
                  ),
                  const Divider(height: 1),
                  _buildListTile(
                    title: '主题色',
                    subtitle: _getCurrentThemeColorName(),
                    icon: Icons.color_lens,
                    onTap: () => _showThemeColorPicker(),
                  ),
                  // Windows 平台显示布局模式选择
                  if (Platform.isWindows) ...[
                    const Divider(height: 1),
                    _buildListTile(
                      title: '布局模式',
                      subtitle: LayoutPreferenceService().getLayoutDescription(),
                      icon: Icons.view_quilt,
                      onTap: () => _showLayoutModeDialog(),
                    ),
                  ],
                ]),
                
                const SizedBox(height: 24),
                
                // 播放设置
                _buildSectionTitle('播放'),
                _buildSettingCard([
                  _buildListTile(
                    title: '音质选择',
                    subtitle: _getAudioQualityText(_audioQuality),
                    icon: Icons.high_quality,
                    onTap: () => _showAudioQualityDialog(),
                  ),
                  const Divider(height: 1),
                  _buildSwitchTile(
                    title: '自动播放',
                    subtitle: '启动时自动播放上次内容',
                    icon: Icons.play_circle_outline,
                    value: _autoPlay,
                    onChanged: (value) {
                      setState(() => _autoPlay = value);
                    },
                  ),
                ]),
                
                const SizedBox(height: 24),
                
                // 网络设置
                _buildSectionTitle('网络'),
                _buildSettingCard([
                  _buildListTile(
                    title: '后端源',
                    subtitle: UrlService().getSourceDescription(),
                    icon: Icons.dns,
                    onTap: () => _showBackendSourceDialog(),
                  ),
                  const Divider(height: 1),
                  _buildListTile(
                    title: '测试连接',
                    subtitle: '测试与后端服务器的连接',
                    icon: Icons.wifi_tethering,
                    onTap: () => _testConnection(),
                  ),
                ]),
                
                const SizedBox(height: 24),
                
                // 关于
                _buildSectionTitle('关于'),
                _buildSettingCard([
                  _buildListTile(
                    title: '版本信息',
                    subtitle: 'v1.0.0',
                    icon: Icons.info_outline,
                    onTap: () => _showAboutDialog(),
                  ),
                  const Divider(height: 1),
                  _buildListTile(
                    title: '检查更新',
                    subtitle: '查看是否有新版本',
                    icon: Icons.system_update,
                    onTap: () {
                      // TODO: 实现更新检查
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('检查更新功能开发中...')),
                      );
                    },
                  ),
                ]),
                
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建分区标题
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  /// 构建设置卡片容器
  Widget _buildSettingCard(List<Widget> children) {
    return Card(
      child: Column(
        children: children,
      ),
    );
  }

  /// 构建普通列表项
  Widget _buildListTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  /// 构建开关列表项
  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  /// 获取当前主题色名称
  String _getCurrentThemeColorName() {
    final currentIndex = ThemeManager().getCurrentColorIndex();
    return ThemeColors.presets[currentIndex].name;
  }

  /// 获取音质文本
  String _getAudioQualityText(String quality) {
    switch (quality) {
      case 'low':
        return '标准音质';
      case 'medium':
        return '较高音质';
      case 'high':
        return '高音质';
      case 'lossless':
        return '无损音质';
      default:
        return '高音质';
    }
  }

  /// 显示主题色选择器
  void _showThemeColorPicker() {
    final currentIndex = ThemeManager().getCurrentColorIndex();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择主题色'),
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: ThemeColors.presets.length + 1, // +1 for custom color option
            itemBuilder: (context, index) {
              // 自定义颜色选项
              if (index == ThemeColors.presets.length) {
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _showCustomColorPicker();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '自定义',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              // 预设颜色选项
              final colorScheme = ThemeColors.presets[index];
              final isSelected = index == currentIndex;
              
              return InkWell(
                onTap: () {
                  ThemeManager().setSeedColor(colorScheme.color);
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                          ? colorScheme.color 
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.color,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSelected ? Icons.check : colorScheme.icon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        colorScheme.name,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 显示自定义颜色选择器
  void _showCustomColorPicker() {
    showDialog(
      context: context,
      builder: (context) => CustomColorPickerDialog(
        currentColor: ThemeManager().seedColor,
        onColorSelected: (color) {
          ThemeManager().setSeedColor(color);
        },
      ),
    );
  }

  /// 显示布局模式选择对话框
  void _showLayoutModeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择布局模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Windows 专属功能',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• 切换布局时窗口会自动调整大小\n• 桌面模式：1200x800\n• 移动模式：400x850（竖屏）',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            RadioListTile<LayoutMode>(
              title: const Text('桌面模式'),
              subtitle: const Text('侧边导航栏，横屏宽屏布局'),
              secondary: const Icon(Icons.desktop_windows),
              value: LayoutMode.desktop,
              groupValue: LayoutPreferenceService().layoutMode,
              onChanged: (value) {
                LayoutPreferenceService().setLayoutMode(value!);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已切换到桌面模式，窗口已调整为 1200x800'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            RadioListTile<LayoutMode>(
              title: const Text('移动模式'),
              subtitle: const Text('底部导航栏，竖屏手机布局'),
              secondary: const Icon(Icons.smartphone),
              value: LayoutMode.mobile,
              groupValue: LayoutPreferenceService().layoutMode,
              onChanged: (value) {
                LayoutPreferenceService().setLayoutMode(value!);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已切换到移动模式，窗口已调整为 400x850'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 显示音质选择对话框
  void _showAudioQualityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择音质'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('标准音质'),
              value: 'low',
              groupValue: _audioQuality,
              onChanged: (value) {
                setState(() => _audioQuality = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('较高音质'),
              value: 'medium',
              groupValue: _audioQuality,
              onChanged: (value) {
                setState(() => _audioQuality = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('高音质'),
              value: 'high',
              groupValue: _audioQuality,
              onChanged: (value) {
                setState(() => _audioQuality = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('无损音质'),
              value: 'lossless',
              groupValue: _audioQuality,
              onChanged: (value) {
                setState(() => _audioQuality = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 显示后端源选择对话框
  void _showBackendSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择后端源'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<BackendSourceType>(
              title: const Text('官方源'),
              subtitle: Text(
                '默认后端服务',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              value: BackendSourceType.official,
              groupValue: UrlService().sourceType,
              onChanged: (value) {
                UrlService().useOfficialSource();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已切换到官方源')),
                );
              },
            ),
            RadioListTile<BackendSourceType>(
              title: const Text('自定义源'),
              subtitle: Text(
                UrlService().customBaseUrl.isNotEmpty 
                    ? UrlService().customBaseUrl 
                    : '点击设置自定义地址',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              value: BackendSourceType.custom,
              groupValue: UrlService().sourceType,
              onChanged: (value) {
                Navigator.pop(context);
                _showCustomUrlDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 显示自定义 URL 输入对话框
  void _showCustomUrlDialog() {
    final controller = TextEditingController(text: UrlService().customBaseUrl);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义后端源'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '请确保自定义源符合 OmniParse 标准',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '后端地址',
                hintText: 'http://example.com:4055',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
                helperText: '不要在末尾添加斜杠',
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final url = controller.text.trim();
              
              if (url.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入后端地址')),
                );
                return;
              }
              
              if (!UrlService.isValidUrl(url)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URL 格式不正确')),
                );
                return;
              }
              
              UrlService().useCustomSource(url);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已切换到自定义源: $url')),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 测试连接
  Future<void> _testConnection() async {
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final baseUrl = UrlService().baseUrl;
    bool isSuccess = false;
    String errorMessage = '';

    try {
      // 发送 GET 请求到根路径
      final response = await http.get(
        Uri.parse(baseUrl),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('连接超时');
        },
      );

      // 检查响应码是否为 200 且响应体是 "OK"
      if (response.statusCode == 200 && response.body.trim() == 'OK') {
        isSuccess = true;
      } else {
        errorMessage = '响应码: ${response.statusCode}\n响应内容: ${response.body}';
      }
    } catch (e) {
      errorMessage = e.toString();
    }

    // 关闭加载对话框
    if (mounted) {
      Navigator.pop(context);

      // 显示结果对话框
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              const Text('连接测试'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('后端地址: $baseUrl'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSuccess
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSuccess ? Icons.done : Icons.close,
                      color: isSuccess
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isSuccess ? '连接成功' : '连接失败',
                        style: TextStyle(
                          color: isSuccess
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isSuccess) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '错误详情:',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        errorMessage,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  /// 显示关于对话框
  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Cyrene Music',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.music_note, size: 48),
      children: [
        const Text('一个跨平台的音乐与视频聚合播放器'),
        const SizedBox(height: 16),
        const Text('支持网易云音乐、QQ音乐、酷狗音乐、Bilibili等平台'),
      ],
    );
  }

  /// 构建用户卡片
  Widget _buildUserCard() {
    final isLoggedIn = AuthService().isLoggedIn;
    final user = AuthService().currentUser;
    
    if (!isLoggedIn || user == null) {
      // 未登录状态
      return _buildLoginCard();
    }
    
    // 已登录状态
    return _buildUserInfoCard(user);
  }

  /// 构建登录卡片（未登录状态）
  Widget _buildLoginCard() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline,
                size: 32,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '未登录',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '登录后可享受更多功能',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: _handleLogin,
              child: const Text('登录'),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建用户信息卡片（已登录状态）
  Widget _buildUserInfoCard(User user) {
    final colorScheme = Theme.of(context).colorScheme;
    final qqNumber = _extractQQNumber(user.email);
    final avatarUrl = _getQQAvatarUrl(qqNumber);
    
    // 使用 AnimatedBuilder 确保状态更新
    return AnimatedBuilder(
      animation: LocationService(),
      builder: (context, child) {
        final location = LocationService().currentLocation;
        final isLoadingLocation = LocationService().isLoading;
        final errorMessage = LocationService().errorMessage;
        
        print('📱 [SettingsPage] 构建用户卡片 - 用户: ${user.username}');
        print('📱 [SettingsPage] 位置加载中: $isLoadingLocation');
        print('📱 [SettingsPage] 位置信息: ${location?.shortDescription ?? "null"}');
        print('📱 [SettingsPage] 错误信息: ${errorMessage ?? "无"}');
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // QQ 头像
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: colorScheme.primaryContainer,
                      backgroundImage: avatarUrl != null 
                          ? NetworkImage(avatarUrl) 
                          : null,
                      child: avatarUrl == null 
                          ? Icon(
                              Icons.person,
                              size: 32,
                              color: colorScheme.onPrimaryContainer,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 用户名
                          Text(
                            user.username,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // 邮箱
                          Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                size: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  user.email,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          // IP 归属地
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              if (isLoadingLocation)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '获取中...',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                )
                              else if (location != null)
                                Expanded(
                                  child: Text(
                                    location.shortDescription,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )
                              else
                                Expanded(
                                  child: Row(
                                    children: [
                                      Text(
                                        '获取失败',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: colorScheme.error,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () {
                                          print('🔄 [SettingsPage] 手动刷新IP归属地...');
                                          LocationService().fetchLocation();
                                        },
                                        child: Icon(
                                          Icons.refresh,
                                          size: 14,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 退出按钮
                    IconButton(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout),
                      tooltip: '退出登录',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 从邮箱中提取 QQ 号
  String? _extractQQNumber(String email) {
    // 判断是否是 QQ 邮箱格式 (数字@qq.com)
    final qqEmailPattern = RegExp(r'^(\d+)@qq\.com$');
    final match = qqEmailPattern.firstMatch(email.toLowerCase());
    
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    
    return null;
  }

  /// 获取 QQ 头像 URL
  String? _getQQAvatarUrl(String? qqNumber) {
    if (qqNumber == null || qqNumber.isEmpty) {
      return null;
    }
    
    // QQ 头像 URL 格式: https://q1.qlogo.cn/g?b=qq&nk={QQ号}&s=100
    return 'https://q1.qlogo.cn/g?b=qq&nk=$qqNumber&s=100';
  }

  /// 处理登录
  Future<void> _handleLogin() async {
    print('👤 [SettingsPage] 打开登录页面...');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginPage(),
      ),
    );
    
    print('👤 [SettingsPage] 登录页面返回，结果: $result');
    print('👤 [SettingsPage] 当前登录状态: ${AuthService().isLoggedIn}');
    
    // 如果登录成功，获取位置信息
    if (result == true && AuthService().isLoggedIn) {
      print('👤 [SettingsPage] 登录成功，开始获取IP归属地...');
      LocationService().fetchLocation();
    }
  }

  /// 处理退出登录
  void _handleLogout() {
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
              LocationService().clearLocation();
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
}
