import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../utils/theme_manager.dart';
import '../widgets/custom_color_picker_dialog.dart';
import '../models/song_detail.dart';
import '../models/version_info.dart';
import '../services/url_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/layout_preference_service.dart';
import '../services/cache_service.dart';
import '../services/download_service.dart';
import '../services/audio_quality_service.dart';
import '../services/version_service.dart';
import '../services/player_background_service.dart';
import '../pages/auth/login_page.dart';

/// 设置页面
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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
    // 监听缓存服务变化
    CacheService().addListener(_onCacheChanged);
    // 监听下载服务变化
    DownloadService().addListener(_onDownloadChanged);
    // 监听音质服务变化
    AudioQualityService().addListener(_onAudioQualityChanged);
    // 监听播放器背景服务变化
    PlayerBackgroundService().addListener(_onPlayerBackgroundChanged);
    
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
    CacheService().removeListener(_onCacheChanged);
    DownloadService().removeListener(_onDownloadChanged);
    AudioQualityService().removeListener(_onAudioQualityChanged);
    PlayerBackgroundService().removeListener(_onPlayerBackgroundChanged);
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

  void _onCacheChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onDownloadChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onAudioQualityChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onPlayerBackgroundChanged() {
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
                  _buildSwitchTile(
                    title: '跟随系统主题色',
                    subtitle: _getFollowSystemColorSubtitle(),
                    icon: Icons.auto_awesome,
                    value: ThemeManager().followSystemColor,
                    onChanged: (value) async {
                      await ThemeManager().setFollowSystemColor(value, context: context);
                      setState(() {});
                    },
                  ),
                  const Divider(height: 1),
                  _buildListTile(
                    title: '主题色',
                    subtitle: _getCurrentThemeColorName(),
                    icon: Icons.color_lens,
                    onTap: ThemeManager().followSystemColor 
                        ? null  // 跟随系统主题色时禁用手动选择
                        : () => _showThemeColorPicker(),
                    trailing: ThemeManager().followSystemColor
                        ? Icon(Icons.lock_outline, color: Theme.of(context).disabledColor)
                        : null,
                  ),
                  const Divider(height: 1),
                  _buildListTile(
                    title: '播放器背景',
                    subtitle: '${PlayerBackgroundService().getBackgroundTypeName()} - ${PlayerBackgroundService().getBackgroundTypeDescription()}',
                    icon: Icons.wallpaper,
                    onTap: () => _showPlayerBackgroundDialog(),
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
                    subtitle: '${AudioQualityService().getQualityName()} - ${AudioQualityService().getQualityDescription()}',
                    icon: Icons.high_quality,
                    onTap: () => _showAudioQualityDialog(),
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
                
                // 存储
                _buildSectionTitle('存储'),
                _buildSettingCard([
                  _buildSwitchTile(
                    title: '启用缓存',
                    subtitle: CacheService().cacheEnabled
                        ? '自动缓存播放过的歌曲'
                        : '缓存已禁用',
                    icon: Icons.cloud_download,
                    value: CacheService().cacheEnabled,
                    onChanged: (value) async {
                      await CacheService().setCacheEnabled(value);
                      setState(() {});
                    },
                  ),
                  // Windows 平台显示缓存目录设置
                  if (Platform.isWindows) ...[
                    const Divider(height: 1),
                    _buildListTile(
                      title: '缓存目录',
                      subtitle: _getCacheDirSubtitle(),
                      icon: Icons.folder,
                      onTap: () => _showCacheDirSettings(),
                    ),
                  ],
                  const Divider(height: 1),
                  _buildListTile(
                    title: '缓存管理',
                    subtitle: _getCacheSubtitle(),
                    icon: Icons.storage,
                    onTap: () => _showCacheManagement(),
                  ),
                  // Windows 平台显示下载目录设置
                  if (Platform.isWindows) ...[
                    const Divider(height: 1),
                    _buildListTile(
                      title: '下载目录',
                      subtitle: _getDownloadDirSubtitle(),
                      icon: Icons.download,
                      onTap: () => _showDownloadDirSettings(),
                    ),
                  ],
                ]),
                
                const SizedBox(height: 24),
                
                // 关于
                _buildSectionTitle('关于'),
                _buildSettingCard([
                  _buildListTile(
                    title: '版本信息',
                    subtitle: 'v${VersionService().currentVersion}',
                    icon: Icons.info_outline,
                    onTap: () => _showAboutDialog(),
                  ),
                  const Divider(height: 1),
                  _buildListTile(
                    title: '检查更新',
                    subtitle: '查看是否有新版本',
                    icon: Icons.system_update,
                    onTap: _checkForUpdate,
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
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
      enabled: onTap != null,
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
    if (ThemeManager().followSystemColor) {
      return '${ThemeManager().getThemeColorSource()} (当前跟随系统)';
    }
    final currentIndex = ThemeManager().getCurrentColorIndex();
    return ThemeColors.presets[currentIndex].name;
  }

  /// 获取跟随系统主题色的副标题
  String _getFollowSystemColorSubtitle() {
    if (ThemeManager().followSystemColor) {
      if (Platform.isAndroid) {
        return '自动获取 Material You 动态颜色 (Android 12+)';
      } else if (Platform.isWindows) {
        return '从系统个性化设置读取强调色';
      }
      return '自动跟随系统主题色';
    } else {
      return '手动选择主题色';
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
    final currentQuality = AudioQualityService().currentQuality;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择音质'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<AudioQuality>(
              title: const Text('标准音质'),
              subtitle: const Text('128kbps，节省流量'),
              value: AudioQuality.standard,
              groupValue: currentQuality,
              onChanged: (value) {
                if (value != null) {
                  AudioQualityService().setQuality(value);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('音质设置已更新'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
            RadioListTile<AudioQuality>(
              title: const Text('极高音质'),
              subtitle: const Text('320kbps，推荐'),
              value: AudioQuality.exhigh,
              groupValue: currentQuality,
              onChanged: (value) {
                if (value != null) {
                  AudioQualityService().setQuality(value);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('音质设置已更新'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
            RadioListTile<AudioQuality>(
              title: const Text('无损音质'),
              subtitle: const Text('FLAC，音质最佳'),
              value: AudioQuality.lossless,
              groupValue: currentQuality,
              onChanged: (value) {
                if (value != null) {
                  AudioQualityService().setQuality(value);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('音质设置已更新'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
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
      applicationVersion: VersionService().currentVersion,
      applicationIcon: const Icon(Icons.music_note, size: 48),
      children: [
        const Text('一个跨平台的音乐与视频聚合播放器'),
        const SizedBox(height: 16),
        const Text('支持网易云音乐、QQ音乐、酷狗音乐、Bilibili等平台'),
      ],
    );
  }

  /// 检查更新
  Future<void> _checkForUpdate() async {
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      print('🔍 [SettingsPage] 开始检查更新...');
      
      final versionInfo = await VersionService().checkForUpdate(silent: false);
      
      if (!mounted) return;
      
      // 关闭加载对话框
      Navigator.pop(context);
      
      if (versionInfo != null && VersionService().hasUpdate) {
        print('✅ [SettingsPage] 发现新版本: ${versionInfo.version}');
        _showUpdateDialog(versionInfo);
      } else {
        print('✅ [SettingsPage] 已是最新版本');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('已是最新版本'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ [SettingsPage] 检查更新失败: $e');
      
      if (!mounted) return;
      
      // 关闭加载对话框
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('检查更新失败: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 显示更新提示对话框
  void _showUpdateDialog(VersionInfo versionInfo) {
    if (!mounted) return;

    final isForceUpdate = versionInfo.forceUpdate;

    showDialog(
      context: context,
      barrierDismissible: !isForceUpdate,
      builder: (context) => PopScope(
        canPop: !isForceUpdate,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.system_update, size: 28),
              SizedBox(width: 12),
              Text('发现新版本'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 版本信息
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '最新版本',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                versionInfo.version,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '当前版本',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                VersionService().currentVersion,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 更新内容
                Text(
                  '更新内容',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    versionInfo.changelog,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),

                // 强制更新提示
                if (isForceUpdate) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Theme.of(context).colorScheme.error,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '此版本为强制更新\n请立即更新',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
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
            // 稍后提醒按钮（仅非强制更新时显示）
            if (!isForceUpdate)
              TextButton(
                onPressed: () async {
                  await VersionService().ignoreCurrentVersion(versionInfo.version);
                  if (mounted) {
                    Navigator.pop(context);
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

            // 立即更新按钮
            FilledButton.icon(
              onPressed: () async {
                final url = versionInfo.downloadUrl;
                print('🔗 [SettingsPage] 打开下载链接: $url');

                try {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                    print('✅ [SettingsPage] 已打开浏览器');
                  } else {
                    throw Exception('无法打开链接');
                  }
                } catch (e) {
                  print('❌ [SettingsPage] 打开链接失败: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('打开链接失败: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.download),
              label: const Text('立即更新'),
            ),
          ],
        ),
      ),
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

  /// 获取缓存副标题
  String _getCacheSubtitle() {
    if (!CacheService().isInitialized) {
      return '初始化中...';
    }

    if (!CacheService().cacheEnabled) {
      return '缓存功能已禁用';
    }

    final count = CacheService().cachedCount;
    if (count == 0) {
      return '暂无缓存';
    }

    return '已缓存 $count 首歌曲';
  }

  /// 获取缓存目录副标题
  String _getCacheDirSubtitle() {
    final customDir = CacheService().customCacheDir;
    if (customDir != null && customDir.isNotEmpty) {
      return '自定义：$customDir';
    }
    return '默认位置';
  }

  /// 获取下载目录副标题
  String _getDownloadDirSubtitle() {
    final downloadPath = DownloadService().downloadPath;
    if (downloadPath != null && downloadPath.isNotEmpty) {
      return downloadPath;
    }
    return '未设置';
  }

  /// 显示缓存管理
  Future<void> _showCacheManagement() async {
    final stats = await CacheService().getCacheStats();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.storage),
            SizedBox(width: 8),
            Text('缓存管理'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 占用空间
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '占用空间',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stats.formattedSize,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.folder_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 文件数量
            Row(
              children: [
                Icon(
                  Icons.audiotrack,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  '已缓存 ${stats.totalFiles} 首歌曲',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          if (stats.totalFiles > 0)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _confirmClearCache();
              },
              icon: const Icon(Icons.delete_sweep),
              label: const Text('清除缓存'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }

  /// 构建缓存统计行
  Widget _buildCacheStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// 显示缓存目录设置
  Future<void> _showCacheDirSettings() async {
    final currentCustomDir = CacheService().customCacheDir;
    final currentDir = CacheService().currentCacheDir;
    final defaultDir = await CacheService().getDefaultCacheDir();
    
    final dirController = TextEditingController(text: currentCustomDir ?? '');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.folder),
              SizedBox(width: 8),
              Text('缓存目录设置'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前目录：',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  currentDir ?? '未知',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  '默认目录：',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  defaultDir,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: dirController,
                        decoration: const InputDecoration(
                          labelText: '自定义目录（留空使用默认）',
                          hintText: '例：D:\\Music\\Cache',
                          prefixIcon: Icon(Icons.edit_location),
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () async {
                        // 打开目录选择器
                        String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
                          dialogTitle: '选择缓存目录',
                          lockParentWindow: true,
                        );

                        if (selectedDirectory != null) {
                          setState(() {
                            dirController.text = selectedDirectory;
                          });
                        }
                      },
                      icon: const Icon(Icons.folder_open),
                      tooltip: '浏览选择目录',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '提示',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• 点击文件夹图标选择目录\n'
                        '• 更改目录需要重启应用生效\n'
                        '• 确保目录有读写权限\n'
                        '• 旧缓存不会自动迁移',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (currentCustomDir != null && currentCustomDir.isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  final success = await CacheService().setCustomCacheDir(null);
                  if (success && mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已恢复默认目录，请重启应用生效'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.restore),
                label: const Text('恢复默认'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final newDir = dirController.text.trim();
                
                if (newDir.isEmpty || newDir == currentCustomDir) {
                  Navigator.pop(context);
                  return;
                }

                // 验证并保存
                final success = await CacheService().setCustomCacheDir(newDir);
                
                if (mounted) {
                  Navigator.pop(context);
                  if (success) {
                    // 显示更明显的重启提示
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        icon: const Icon(Icons.restart_alt, size: 48),
                        title: const Text('需要重启应用'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '缓存目录已设置为：',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              newDir,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning,
                                    color: Theme.of(context).colorScheme.error,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '必须重启应用才能使用新目录！\n当前播放的歌曲仍会缓存到旧目录。',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onErrorContainer,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('知道了'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('目录设置失败，请检查路径是否正确'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  /// 确认清除缓存
  Future<void> _confirmClearCache() async {
    final stats = await CacheService().getCacheStats();

    if (stats.totalFiles == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂无缓存可清除')),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: Text(
          '确定要清除所有缓存吗？\n\n'
          '将删除 ${stats.totalFiles} 首歌曲的缓存\n'
          '释放 ${stats.formattedSize} 空间',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // 显示加载提示
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 16),
                        Text('正在清除缓存...'),
                      ],
                    ),
                    duration: Duration(seconds: 3),
                  ),
                );
              }

              // 清除缓存
              await CacheService().clearAllCache();

              // 显示完成提示
              if (mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已清除 ${stats.totalFiles} 首歌曲的缓存'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }

  /// 显示下载目录设置
  Future<void> _showDownloadDirSettings() async {
    final currentDownloadPath = DownloadService().downloadPath;
    final dirController = TextEditingController(text: currentDownloadPath ?? '');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('下载目录设置'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当前下载目录：',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(
                currentDownloadPath ?? '未设置',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: dirController,
                decoration: const InputDecoration(
                  labelText: '新下载目录',
                  border: OutlineInputBorder(),
                  hintText: '例如: D:\\Music\\Cyrene',
                ),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.getDirectoryPath(
                          dialogTitle: '选择下载目录',
                        );

                        if (result != null) {
                          dirController.text = result;
                        }
                      },
                      icon: const Icon(Icons.folder_open),
                      label: const Text('浏览'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '下载的音乐文件将保存到指定目录',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final newDir = dirController.text.trim();

              if (newDir.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请选择下载目录')),
                );
                return;
              }

              // 设置新的下载目录
              final success = await DownloadService().setDownloadPath(newDir);

              if (mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('下载目录已更新')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('设置下载目录失败')),
                  );
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 显示播放器背景设置对话框
  void _showPlayerBackgroundDialog() {
    showDialog(
      context: context,
      builder: (context) => _PlayerBackgroundDialog(
        onChanged: () {
          // 当对话框内的设置改变时，刷新设置页面
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }
}

/// 播放器背景设置对话框
class _PlayerBackgroundDialog extends StatefulWidget {
  final VoidCallback onChanged;
  
  const _PlayerBackgroundDialog({required this.onChanged});

  @override
  State<_PlayerBackgroundDialog> createState() => _PlayerBackgroundDialogState();
}

class _PlayerBackgroundDialogState extends State<_PlayerBackgroundDialog> {
  @override
  Widget build(BuildContext context) {
    final backgroundService = PlayerBackgroundService();
    final currentType = backgroundService.backgroundType;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.wallpaper),
          SizedBox(width: 8),
          Text('播放器背景设置'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 自适应背景
            RadioListTile<PlayerBackgroundType>(
              title: const Text('自适应背景'),
              subtitle: const Text('基于专辑封面提取颜色'),
              value: PlayerBackgroundType.adaptive,
              groupValue: currentType,
              onChanged: (value) async {
                await backgroundService.setBackgroundType(value!);
                setState(() {});
                widget.onChanged();
              },
            ),
            
            // 纯色背景
            RadioListTile<PlayerBackgroundType>(
              title: const Text('纯色背景'),
              subtitle: const Text('使用自定义纯色'),
              value: PlayerBackgroundType.solidColor,
              groupValue: currentType,
              onChanged: (value) async {
                await backgroundService.setBackgroundType(value!);
                setState(() {});
                widget.onChanged();
              },
            ),
            
            // 纯色选择器（仅在选择纯色时显示）
            if (currentType == PlayerBackgroundType.solidColor) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: OutlinedButton.icon(
                  onPressed: _showSolidColorPicker,
                  icon: Icon(
                    Icons.palette,
                    color: backgroundService.solidColor,
                  ),
                  label: const Text('选择颜色'),
                ),
              ),
            ],
            
            const SizedBox(height: 8),
            
            // 图片背景
            RadioListTile<PlayerBackgroundType>(
              title: const Text('图片背景'),
              subtitle: Text(
                backgroundService.imagePath != null
                    ? '已设置自定义图片'
                    : '未设置图片',
              ),
              value: PlayerBackgroundType.image,
              groupValue: currentType,
              onChanged: (value) async {
                await backgroundService.setBackgroundType(value!);
                setState(() {});
                widget.onChanged();
              },
            ),
                
            // 图片选择和模糊设置（仅在选择图片背景时显示）
            if (currentType == PlayerBackgroundType.image) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 选择图片按钮
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectBackgroundImage,
                            icon: const Icon(Icons.image),
                            label: const Text('选择图片'),
                          ),
                        ),
                        if (backgroundService.imagePath != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () async {
                              await backgroundService.clearImageBackground();
                              setState(() {});
                              widget.onChanged();
                            },
                            icon: const Icon(Icons.clear),
                            tooltip: '清除图片',
                          ),
                        ],
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 模糊程度调节
                    Text(
                      '模糊程度: ${backgroundService.blurAmount.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Slider(
                      value: backgroundService.blurAmount,
                      min: 0,
                      max: 50,
                      divisions: 50,
                      label: backgroundService.blurAmount.toStringAsFixed(0),
                      onChanged: (value) async {
                        await backgroundService.setBlurAmount(value);
                        setState(() {});
                        widget.onChanged();
                      },
                    ),
                    Text(
                      '0 = 清晰，50 = 最模糊',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  /// 显示纯色选择器
  Future<void> _showSolidColorPicker() async {
    final backgroundService = PlayerBackgroundService();
    Color? selectedColor;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择纯色'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 预设颜色
              const Text(
                '预设颜色',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Colors.grey[900]!,
                  Colors.black,
                  Colors.blue[900]!,
                  Colors.purple[900]!,
                  Colors.red[900]!,
                  Colors.green[900]!,
                  Colors.orange[900]!,
                  Colors.teal[900]!,
                ].map((color) => InkWell(
                  onTap: () {
                    selectedColor = color;
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: color == backgroundService.solidColor
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                )).toList(),
              ),
              
              const SizedBox(height: 20),
              
              // 自定义颜色按钮
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showCustomColorPicker();
                },
                icon: const Icon(Icons.palette),
                label: const Text('自定义颜色'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (selectedColor != null) {
      await backgroundService.setSolidColor(selectedColor!);
      setState(() {});
      widget.onChanged();
    }
  }
  
  /// 显示自定义颜色选择器（调色盘）
  Future<void> _showCustomColorPicker() async {
    final backgroundService = PlayerBackgroundService();
    Color pickerColor = backgroundService.solidColor;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义颜色'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) {
              pickerColor = color;
            },
            enableAlpha: false, // 不需要透明度调节
            displayThumbColor: true,
            pickerAreaHeightPercent: 0.8,
            labelTypes: const [
              ColorLabelType.rgb,
              ColorLabelType.hsv,
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await backgroundService.setSolidColor(pickerColor);
              setState(() {});
              widget.onChanged();
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 选择背景图片
  Future<void> _selectBackgroundImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      dialogTitle: '选择背景图片',
    );

    if (result != null && result.files.single.path != null) {
      final imagePath = result.files.single.path!;
      await PlayerBackgroundService().setImageBackground(imagePath);
      setState(() {});
      widget.onChanged();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('背景图片已设置'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
