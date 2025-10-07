import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../services/android_floating_lyric_service.dart';

/// Android 悬浮歌词设置组件
class AndroidFloatingLyricSettings extends StatefulWidget {
  const AndroidFloatingLyricSettings({super.key});

  @override
  State<AndroidFloatingLyricSettings> createState() => _AndroidFloatingLyricSettingsState();
}

class _AndroidFloatingLyricSettingsState extends State<AndroidFloatingLyricSettings> {
  final AndroidFloatingLyricService _lyricService = AndroidFloatingLyricService();
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  /// 检查权限状态
  Future<void> _checkPermission() async {
    final hasPermission = await _lyricService.checkPermission();
    if (mounted) {
      setState(() {
        _hasPermission = hasPermission;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return const SizedBox.shrink();
    }

    return _buildSettingCard([
      _buildPermissionStatusTile(),
      const Divider(height: 1),
      _buildSwitchTile(
        title: '启用悬浮歌词',
        subtitle: _lyricService.isVisible
            ? '悬浮歌词窗口已显示'
            : '悬浮歌词窗口已隐藏',
        icon: Icons.subtitles,
        value: _lyricService.isVisible,
        onChanged: (value) async {
          if (value) {
            // 使用新的权限管理流程
            final granted = await _lyricService.requestPermissionWithDialog(context);
            
            if (granted) {
              await _lyricService.show();
              await _checkPermission(); // 更新权限状态
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ 悬浮歌词已启用'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ 需要悬浮窗权限才能启用悬浮歌词'),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            }
          } else {
            await _lyricService.hide();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('悬浮歌词已关闭'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
          setState(() {});
        },
      ),
      const Divider(height: 1),
      _buildListTile(
        title: '字体大小',
        subtitle: '当前大小: ${_lyricService.config['fontSize']}px',
        icon: Icons.format_size,
        onTap: () => _showFontSizeDialog(),
      ),
      const Divider(height: 1),
      _buildListTile(
        title: '文字颜色',
        subtitle: '自定义悬浮歌词文字颜色',
        icon: Icons.color_lens,
        onTap: () => _showTextColorPicker(),
        trailing: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Color(_lyricService.config['textColor']),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey),
          ),
        ),
      ),
      const Divider(height: 1),
      _buildListTile(
        title: '描边颜色',
        subtitle: '文字描边颜色，增加可读性',
        icon: Icons.border_color,
        onTap: () => _showStrokeColorPicker(),
        trailing: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Color(_lyricService.config['strokeColor']),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey),
          ),
        ),
      ),
      const Divider(height: 1),
      _buildListTile(
        title: '描边宽度',
        subtitle: '当前宽度: ${_lyricService.config['strokeWidth']}px',
        icon: Icons.line_weight,
        onTap: () => _showStrokeWidthDialog(),
      ),
      const Divider(height: 1),
      _buildListTile(
        title: '透明度',
        subtitle: '当前透明度: ${(_lyricService.config['alpha'] * 100).toInt()}%',
        icon: Icons.opacity,
        onTap: () => _showAlphaDialog(),
      ),
      const Divider(height: 1),
      _buildSwitchTile(
        title: '允许拖动',
        subtitle: _lyricService.config['isDraggable']
            ? '可以拖动悬浮窗位置'
            : '悬浮窗位置固定',
        icon: Icons.pan_tool,
        value: _lyricService.config['isDraggable'],
        onChanged: (value) async {
          await _lyricService.setDraggable(value);
          setState(() {});
        },
      ),
    ]);
  }

  /// 构建权限状态指示器
  Widget _buildPermissionStatusTile() {
    return ListTile(
      title: const Text('权限状态'),
      subtitle: Text(_hasPermission 
          ? '✅ 已获得悬浮窗权限' 
          : '❌ 需要悬浮窗权限'),
      leading: Icon(
        _hasPermission ? Icons.verified : Icons.warning,
        color: _hasPermission ? Colors.green : Colors.orange,
      ),
      trailing: _hasPermission 
          ? null 
          : TextButton(
              onPressed: () async {
                final granted = await _lyricService.requestPermissionWithDialog(context);
                if (granted) {
                  await _checkPermission();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ 权限已授予'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              child: const Text('授权'),
            ),
    );
  }

  /// 构建设置卡片
  Widget _buildSettingCard(List<Widget> children) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: children,
      ),
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
      title: Text(title),
      subtitle: Text(subtitle),
      secondary: Icon(icon),
      value: value,
      onChanged: onChanged,
    );
  }

  /// 构建普通列表项
  Widget _buildListTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      leading: Icon(icon),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  /// 显示字体大小对话框
  void _showFontSizeDialog() {
    int currentSize = _lyricService.config['fontSize'];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('字体大小'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('当前大小: ${currentSize}px'),
              const SizedBox(height: 16),
              Slider(
                value: currentSize.toDouble(),
                min: 12.0,
                max: 48.0,
                divisions: 36,
                label: '${currentSize}px',
                onChanged: (value) {
                  setState(() {
                    currentSize = value.round();
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                await _lyricService.setFontSize(currentSize);
                Navigator.pop(context);
                this.setState(() {});
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示文字颜色选择器
  void _showTextColorPicker() {
    Color currentColor = Color(_lyricService.config['textColor']);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择文字颜色'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (color) {
              currentColor = color;
            },
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await _lyricService.setTextColor(currentColor.value);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 显示描边颜色选择器
  void _showStrokeColorPicker() {
    Color currentColor = Color(_lyricService.config['strokeColor']);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择描边颜色'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (color) {
              currentColor = color;
            },
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await _lyricService.setStrokeColor(currentColor.value);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 显示描边宽度对话框
  void _showStrokeWidthDialog() {
    int currentWidth = _lyricService.config['strokeWidth'];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('描边宽度'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('当前宽度: ${currentWidth}px'),
              const SizedBox(height: 16),
              Slider(
                value: currentWidth.toDouble(),
                min: 0.0,
                max: 8.0,
                divisions: 8,
                label: '${currentWidth}px',
                onChanged: (value) {
                  setState(() {
                    currentWidth = value.round();
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                await _lyricService.setStrokeWidth(currentWidth);
                Navigator.pop(context);
                this.setState(() {});
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示透明度对话框
  void _showAlphaDialog() {
    double currentAlpha = _lyricService.config['alpha'];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('透明度'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('当前透明度: ${(currentAlpha * 100).toInt()}%'),
              const SizedBox(height: 16),
              Slider(
                value: currentAlpha,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                label: '${(currentAlpha * 100).toInt()}%',
                onChanged: (value) {
                  setState(() {
                    currentAlpha = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                await _lyricService.setAlpha(currentAlpha);
                Navigator.pop(context);
                this.setState(() {});
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }
}
