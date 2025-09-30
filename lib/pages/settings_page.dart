import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/theme_manager.dart';
import '../widgets/custom_color_picker_dialog.dart';
import '../services/url_service.dart';

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
    // 监听主题变化
    ThemeManager().addListener(_onThemeChanged);
    // 监听 URL 服务变化
    UrlService().addListener(_onUrlServiceChanged);
  }

  @override
  void dispose() {
    ThemeManager().removeListener(_onThemeChanged);
    UrlService().removeListener(_onUrlServiceChanged);
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
}
