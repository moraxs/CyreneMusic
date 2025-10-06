import 'dart:io';
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

/// 移动端播放器顶部应用栏组件
/// Windows 平台显示窗口控制按钮，移动平台显示返回按钮
class MobilePlayerAppBar extends StatelessWidget {
  final VoidCallback onBackPressed;

  const MobilePlayerAppBar({
    super.key,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Windows 平台：显示窗口控制按钮和拖动区域
    if (Platform.isWindows) {
      return Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
        ),
        child: Row(
          children: [
            // 左侧：返回按钮
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              iconSize: 24,
              onPressed: onBackPressed,
              tooltip: '返回',
            ),
            
            // 中间：可拖动区域
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (details) {
                  appWindow.startDragging();
                },
                child: const Center(
                  child: Text(
                    '正在播放',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            
            // 右侧：窗口控制按钮
            _buildWindowButton(
              icon: Icons.remove,
              tooltip: '最小化',
              onPressed: () => appWindow.minimize(),
            ),
            _buildWindowButton(
              icon: Icons.crop_square,
              tooltip: '最大化（已禁用）',
              onPressed: null, // 禁用最大化
              isDisabled: true,
            ),
            _buildWindowButton(
              icon: Icons.close,
              tooltip: '关闭',
              onPressed: () => appWindow.close(),
              isClose: true,
            ),
          ],
        ),
      );
    }
    
    // 移动平台：显示普通返回按钮
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            iconSize: 32,
            onPressed: onBackPressed,
          ),
          const Text(
            '正在播放',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // TODO: 显示更多选项
            },
          ),
        ],
      ),
    );
  }

  /// 构建窗口控制按钮（Windows 专用）
  Widget _buildWindowButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool isClose = false,
    bool isDisabled = false,
  }) {
    return SizedBox(
      width: 46,
      height: 40,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            hoverColor: isClose 
                ? Colors.red.withOpacity(0.8)
                : isDisabled
                    ? Colors.transparent
                    : Colors.white.withOpacity(0.1),
            child: Center(
              child: Icon(
                icon,
                size: 18,
                color: isDisabled 
                    ? Colors.white.withOpacity(0.3)
                    : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
