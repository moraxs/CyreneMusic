import 'dart:io';
import 'package:flutter/material.dart';
import '../../widgets/desktop_lyric_settings.dart';
import '../../widgets/android_floating_lyric_settings.dart';

/// 歌词设置组件
class LyricSettings extends StatelessWidget {
  const LyricSettings({super.key});

  @override
  Widget build(BuildContext context) {
    // 根据平台显示对应的歌词设置
    if (Platform.isWindows) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, '桌面歌词'),
          const DesktopLyricSettings(),
        ],
      );
    } else if (Platform.isAndroid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, '悬浮歌词'),
          const AndroidFloatingLyricSettings(),
        ],
      );
    }
    
    // 其他平台不显示歌词设置
    return const SizedBox.shrink();
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
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
}

