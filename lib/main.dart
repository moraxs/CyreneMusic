import 'dart:io';
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'layouts/main_layout.dart';
import 'utils/theme_manager.dart';
import 'services/player_service.dart';
import 'services/system_media_service.dart';

// 条件导入 SMTC
import 'package:smtc_windows/smtc_windows.dart' if (dart.library.html) '';

void main() async {
  // 初始化播放器服务
  WidgetsFlutterBinding.ensureInitialized();
  
  // Windows 平台初始化 SMTC
  if (Platform.isWindows) {
    await SMTCWindows.initialize();
  }
  
  PlayerService().initialize();
  
  // 初始化系统媒体控件
  await SystemMediaService().initialize();
  
  runApp(const MyApp());
  
  // Windows 平台初始化窗口设置
  if (Platform.isWindows) {
    doWhenWindowReady(() {
      const initialSize = Size(1200, 800);
      // 设置更小的最小尺寸，以支持移动模式（400x850）
      const minSize = Size(360, 640);
      
      appWindow.minSize = minSize;
      appWindow.size = initialSize;
      appWindow.alignment = Alignment.center;
      appWindow.title = 'Cyrene Music';
      appWindow.show();
    });
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeManager(),
      builder: (context, _) {
        return MaterialApp(
          title: 'Cyrene Music',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
        // 使用 Material Design 3
        useMaterial3: true,
        // 字体
        fontFamily: 'Microsoft YaHei',
        colorScheme: ColorScheme.fromSeed(
          seedColor: ThemeManager().seedColor,
          brightness: Brightness.light,
        ),
        // 卡片主题
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          color: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        // 导航栏主题
        navigationRailTheme: NavigationRailThemeData(
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        // 字体
        fontFamily: 'Microsoft YaHei',
        colorScheme: ColorScheme.fromSeed(
          seedColor: ThemeManager().seedColor,
          brightness: Brightness.dark,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          color: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        navigationRailTheme: const NavigationRailThemeData(
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      themeMode: ThemeManager().themeMode,
      home: const MainLayout(),
        );
      },
    );
  }
}