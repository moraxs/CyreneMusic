import 'dart:io';
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

/// 自定义标题栏组件 - 仅用于 Windows 平台
class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    // 只在 Windows 平台显示自定义标题栏
    if (!Platform.isWindows) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    
    return WindowTitleBarBox(
      child: Container(
        height: 48, // 增加标题栏高度
        decoration: BoxDecoration(
          color: colorScheme.surface,
        ),
        child: Row(
          children: [
            Expanded(
              child: MoveWindow(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.music_note,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Cyrene Music',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 窗口控制按钮
            _WindowButtons(),
          ],
        ),
      ),
    );
  }
}

/// 窗口控制按钮（最小化、最大化、关闭）
class _WindowButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Row(
      children: [
        _WindowButton(
          icon: Icons.remove,
          onPressed: () => appWindow.minimize(),
          colorScheme: colorScheme,
        ),
        _WindowButton(
          icon: Icons.crop_square,
          onPressed: () => appWindow.maximizeOrRestore(),
          colorScheme: colorScheme,
        ),
        _WindowButton(
          icon: Icons.close,
          onPressed: () => appWindow.close(),
          colorScheme: colorScheme,
          isClose: true,
        ),
      ],
    );
  }
}

/// 单个窗口按钮
class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    required this.colorScheme,
    this.isClose = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 48,
          height: 48, // 匹配标题栏高度
          decoration: BoxDecoration(
            color: isHovered
                ? (widget.isClose
                    ? Colors.red
                    : widget.colorScheme.surfaceContainerHighest)
                : Colors.transparent,
          ),
          child: Center(
            child: Icon(
              widget.icon,
              size: 18, // 稍微增大图标
              color: isHovered && widget.isClose
                  ? Colors.white
                  : widget.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
