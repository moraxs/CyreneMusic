import 'dart:io';
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:window_manager/window_manager.dart';
import 'layouts/main_layout.dart';
import 'utils/theme_manager.dart';
import 'services/player_service.dart';
import 'services/system_media_service.dart';
import 'services/tray_service.dart';
import 'services/developer_mode_service.dart';

// 条件导入 SMTC
import 'package:smtc_windows/smtc_windows.dart' if (dart.library.html) '';

void main() async {
  // 初始化播放器服务
  WidgetsFlutterBinding.ensureInitialized();
  
  // 添加应用启动日志
  DeveloperModeService().addLog('🚀 应用启动');
  DeveloperModeService().addLog('📱 平台: ${Platform.operatingSystem}');
  
  // 初始化 window_manager（必须在 runApp 之前）
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(360, 640),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden, // 隐藏系统标题栏，使用自定义标题栏
      windowButtonVisibility: false,
    );
    
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setTitle('Cyrene Music');
      // 对于隐藏标题栏的窗口，确保以无边框模式运行，避免启动时不可见
      await windowManager.setAsFrameless();
      await windowManager.show();
      await windowManager.focus();
      // 设置关闭窗口时不退出应用（会触发 onWindowClose 回调）
      await windowManager.setPreventClose(true);
      print('✅ [Main] 窗口已显示，关闭按钮将最小化到托盘');
    });
  }
  
  // Windows 平台初始化 SMTC
  if (Platform.isWindows) {
    await SMTCWindows.initialize();
    DeveloperModeService().addLog('🎮 SMTC 已初始化');
  }
  
  PlayerService().initialize();
  DeveloperModeService().addLog('🎵 播放器服务已初始化');
  
  // 初始化系统媒体控件
  await SystemMediaService().initialize();
  DeveloperModeService().addLog('🎛️ 系统媒体服务已初始化');
  
  // 初始化系统托盘
  await TrayService().initialize();
  DeveloperModeService().addLog('📌 系统托盘已初始化');
  
  runApp(const MyApp());
  
  // Windows 平台初始化 bitsdojo_window 设置（与 window_manager 配合使用）
  if (Platform.isWindows) {
    doWhenWindowReady(() {
      const initialSize = Size(1200, 800);
      const minSize = Size(360, 640);
      
      appWindow.minSize = minSize;
      appWindow.size = initialSize;
      appWindow.alignment = Alignment.center;
      appWindow.title = 'Cyrene Music';
      // 备用保障：确保窗口在就绪后可见（与 window_manager 协同）
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
      home: Platform.isWindows
          ? _WindowsRoundedContainer(child: const MainLayout())
          : const MainLayout(),
        );
      },
    );
  }
}

/// Windows 圆角窗口容器
class _WindowsRoundedContainer extends StatelessWidget {
  final Widget child;
  
  const _WindowsRoundedContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // 添加外边距，使窗口内容与边缘有间隔
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 0,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: child,
        ),
      ),
    );
  }
}