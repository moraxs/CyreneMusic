import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/player_background_service.dart';

/// 播放器背景设置对话框
class PlayerBackgroundDialog extends StatefulWidget {
  final VoidCallback onChanged;
  
  const PlayerBackgroundDialog({super.key, required this.onChanged});

  @override
  State<PlayerBackgroundDialog> createState() => _PlayerBackgroundDialogState();
}

class _PlayerBackgroundDialogState extends State<PlayerBackgroundDialog> {
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
            
            // 渐变开关（仅在自适应背景时显示）
            if (currentType == PlayerBackgroundType.adaptive) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: SwitchListTile(
                  title: const Text('封面渐变效果'),
                  subtitle: Text(
                    Platform.isWindows || Platform.isMacOS || Platform.isLinux
                        ? '专辑封面位于左侧，向右渐变到主题色'
                        : '专辑封面位于顶部，向下渐变到主题色',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  value: backgroundService.enableGradient,
                  onChanged: (value) async {
                    await backgroundService.setEnableGradient(value);
                    setState(() {});
                    widget.onChanged();
                  },
                  secondary: const Icon(Icons.gradient),
                  contentPadding: const EdgeInsets.only(left: 40, right: 16),
                ),
              ),
            ],
            
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
            enableAlpha: false,
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

