import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../services/desktop_lyric_service.dart';

/// 桌面歌词设置组件
class DesktopLyricSettings extends StatefulWidget {
  const DesktopLyricSettings({super.key});

  @override
  State<DesktopLyricSettings> createState() => _DesktopLyricSettingsState();
}

class _DesktopLyricSettingsState extends State<DesktopLyricSettings> {
  final _desktopLyricService = DesktopLyricService();
  
  late int _fontSize;
  late Color _textColor;
  late Color _strokeColor;
  late int _strokeWidth;
  late bool _isDraggable;
  late bool _isMouseTransparent;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final config = _desktopLyricService.config;
    setState(() {
      _fontSize = config['fontSize'] as int;
      _textColor = Color(config['textColor'] as int);
      _strokeColor = Color(config['strokeColor'] as int);
      _strokeWidth = config['strokeWidth'] as int;
      _isDraggable = config['isDraggable'] as bool;
      _isMouseTransparent = config['isMouseTransparent'] as bool;
    });
  }

  Future<void> _pickColor(String type) async {
    Color initialColor = type == 'text' ? _textColor : _strokeColor;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type == 'text' ? '选择文字颜色' : '选择描边颜色'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: initialColor,
            onColorChanged: (color) {
              setState(() {
                if (type == 'text') {
                  _textColor = color;
                  _desktopLyricService.setTextColor(color.value);
                } else {
                  _strokeColor = color;
                  _desktopLyricService.setStrokeColor(color.value);
                }
              });
            },
            enableAlpha: true,
            displayThumbColor: true,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('桌面歌词功能仅支持Windows平台'),
        ),
      );
    }

    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lyrics, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '桌面歌词',
                  style: theme.textTheme.titleLarge,
                ),
                const Spacer(),
                Switch(
                  value: _desktopLyricService.isVisible,
                  onChanged: (value) async {
                    await _desktopLyricService.toggle();
                    setState(() {});
                  },
                ),
              ],
            ),
            const Divider(),
            
            // 字体大小
            ListTile(
              leading: const Icon(Icons.format_size),
              title: const Text('字体大小'),
              subtitle: Slider(
                value: _fontSize.toDouble(),
                min: 16,
                max: 72,
                divisions: 28,
                label: _fontSize.toString(),
                onChanged: (value) {
                  setState(() {
                    _fontSize = value.toInt();
                  });
                  _desktopLyricService.setFontSize(_fontSize);
                },
              ),
              trailing: Text('$_fontSize'),
            ),

            // 文字颜色
            ListTile(
              leading: const Icon(Icons.color_lens),
              title: const Text('文字颜色'),
              trailing: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _textColor,
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onTap: () => _pickColor('text'),
            ),

            // 描边颜色
            ListTile(
              leading: const Icon(Icons.border_color),
              title: const Text('描边颜色'),
              trailing: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _strokeColor,
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onTap: () => _pickColor('stroke'),
            ),

            // 描边宽度
            ListTile(
              leading: const Icon(Icons.line_weight),
              title: const Text('描边宽度'),
              subtitle: Slider(
                value: _strokeWidth.toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                label: _strokeWidth.toString(),
                onChanged: (value) {
                  setState(() {
                    _strokeWidth = value.toInt();
                  });
                  _desktopLyricService.setStrokeWidth(_strokeWidth);
                },
              ),
              trailing: Text('$_strokeWidth'),
            ),

            // 可拖动
            SwitchListTile(
              secondary: const Icon(Icons.open_with),
              title: const Text('允许拖动'),
              subtitle: const Text('鼠标可以拖动歌词窗口'),
              value: _isDraggable,
              onChanged: (value) {
                setState(() {
                  _isDraggable = value;
                });
                _desktopLyricService.setDraggable(value);
              },
            ),

            // 鼠标穿透
            SwitchListTile(
              secondary: const Icon(Icons.touch_app),
              title: const Text('鼠标穿透'),
              subtitle: const Text('歌词窗口不响应鼠标事件'),
              value: _isMouseTransparent,
              onChanged: (value) {
                setState(() {
                  _isMouseTransparent = value;
                });
                _desktopLyricService.setMouseTransparent(value);
              },
            ),

            const SizedBox(height: 16),
            
            // 测试按钮
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  _desktopLyricService.setLyricText('这是测试歌词 - This is a test lyric');
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('测试歌词显示'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
