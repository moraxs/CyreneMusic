import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 自定义颜色选择器对话框
class CustomColorPickerDialog extends StatefulWidget {
  final Color currentColor;
  final ValueChanged<Color> onColorSelected;

  const CustomColorPickerDialog({
    super.key,
    required this.currentColor,
    required this.onColorSelected,
  });

  @override
  State<CustomColorPickerDialog> createState() => _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends State<CustomColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _value;
  
  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.currentColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
  }

  Color get _currentColor {
    return HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return AlertDialog(
      title: const Text('自定义颜色'),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: SizedBox(
        width: math.min(MediaQuery.of(context).size.width * 0.8, 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 颜色预览
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: _currentColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.2),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _currentColor.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '#${_currentColor.value.toRadixString(16).substring(2).toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 色相滑块
            _buildSlider(
              label: '色相',
              value: _hue,
              max: 360,
              onChanged: (value) => setState(() => _hue = value),
              gradient: LinearGradient(
                colors: [
                  for (int i = 0; i <= 360; i += 60)
                    HSVColor.fromAHSV(1.0, i.toDouble(), 1.0, 1.0).toColor(),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 饱和度滑块
            _buildSlider(
              label: '饱和度',
              value: _saturation,
              max: 1.0,
              onChanged: (value) => setState(() => _saturation = value),
              gradient: LinearGradient(
                colors: [
                  HSVColor.fromAHSV(1.0, _hue, 0.0, _value).toColor(),
                  HSVColor.fromAHSV(1.0, _hue, 1.0, _value).toColor(),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 亮度滑块
            _buildSlider(
              label: '亮度',
              value: _value,
              max: 1.0,
              onChanged: (value) => setState(() => _value = value),
              gradient: LinearGradient(
                colors: [
                  Colors.black,
                  HSVColor.fromAHSV(1.0, _hue, _saturation, 1.0).toColor(),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            widget.onColorSelected(_currentColor);
            Navigator.pop(context);
          },
          style: FilledButton.styleFrom(
            backgroundColor: _currentColor,
            foregroundColor: _currentColor.computeLuminance() > 0.5 
                ? Colors.black 
                : Colors.white,
          ),
          child: const Text('确定'),
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double max,
    required ValueChanged<double> onChanged,
    required Gradient gradient,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(
                max == 360 
                    ? '${value.round()}°' 
                    : '${(value * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: gradient,
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 32,
              trackShape: const RoundedRectSliderTrackShape(),
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 14,
                elevation: 4,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: 24,
              ),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withOpacity(0.2),
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
            ),
            child: Slider(
              value: value,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
