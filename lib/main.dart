import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:cyrene_music/layouts/fluent_main_layout.dart';
import 'package:cyrene_music/layouts/main_layout.dart';
import 'package:cyrene_music/services/android_floating_lyric_service.dart';
import 'package:cyrene_music/services/auto_update_service.dart';
import 'package:cyrene_music/services/cache_service.dart';
import 'package:cyrene_music/services/developer_mode_service.dart';
import 'package:cyrene_music/services/desktop_lyric_service.dart';
import 'package:cyrene_music/services/listening_stats_service.dart';
import 'package:cyrene_music/services/lyric_style_service.dart';
import 'package:cyrene_music/services/lyric_font_service.dart';
import 'package:cyrene_music/services/persistent_storage_service.dart';
import 'package:cyrene_music/services/player_background_service.dart';
import 'package:cyrene_music/services/player_service.dart';
import 'package:cyrene_music/services/notification_service.dart';
import 'package:cyrene_music/services/playback_resume_service.dart';
import 'package:cyrene_music/services/permission_service.dart';
import 'package:cyrene_music/services/system_media_service.dart';
import 'package:cyrene_music/services/tray_service.dart';
import 'package:cyrene_music/services/url_service.dart';
import 'package:cyrene_music/services/version_service.dart';
import 'package:cyrene_music/services/singleton_service.dart';
import 'package:cyrene_music/utils/theme_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:media_kit/media_kit.dart';


// 条件导入 flutter_displaymode（仅 Android）
import 'package:flutter_displaymode/flutter_displaymode.dart' if (dart.library.html) '';

void main() async {
  // 初始化播放器服务
  WidgetsFlutterBinding.ensureInitialized();
  
  // 添加应用启动日志
  DeveloperModeService().addLog('🚀 应用启动');
  DeveloperModeService().addLog('📱 平台: ${Platform.operatingSystem}');
  
  // 🔒 确保只有一个进程运行
  final isSingleton = await SingletonService().initialize();
  if (!isSingleton) {
    DeveloperModeService().addLog('⚠️ 已有进程在运行，当前进程将退出');
    print('⚠️ [Singleton] 已有进程在运行，当前进程将退出');
    exit(0);
  }
  
  // iOS 平台：设置首选竖屏方向（解决初次启动横屏问题）
  if (Platform.isIOS) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
  
  // 初始化 media_kit（仅在桌面平台，用于视频背景）
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    MediaKit.ensureInitialized();
  }
  
  // 🔧 初始化持久化存储服务（必须最先初始化，其他服务依赖它）
  await PersistentStorageService().initialize();
  DeveloperModeService().addLog('💾 持久化存储服务已初始化');
  
  // 显示备份统计信息（用于调试）
  final storageStats = PersistentStorageService().getBackupStats();
  DeveloperModeService().addLog('📊 存储统计: ${storageStats['sharedPreferences_keys']} 个键');
  DeveloperModeService().addLog('📂 备份路径: ${storageStats['backup_file_path']}');
  
  // 初始化 window_manager（必须在 runApp 之前）
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    // 初始化窗口材质库（Windows）
    if (Platform.isWindows) {
      try {
        await Window.initialize();
      } catch (_) {}
    }
    
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1320, 880),
      minimumSize: Size(360, 640),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden, // 隐藏系统标题栏，使用自定义标题栏
      windowButtonVisibility: false,
    );
    
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setTitle('Cyrene Music');
      
      // 设置窗口图标（任务栏图标）
      if (Platform.isWindows) {
        await windowManager.setIcon('assets/icons/tray_icon.ico');
      } else if (Platform.isMacOS || Platform.isLinux) {
        await windowManager.setIcon('assets/icons/tray_icon.png');
      }
      
      await windowManager.show();
      await windowManager.focus();
      // 设置关闭窗口时不退出应用（会触发 onWindowClose 回调）
      await windowManager.setPreventClose(true);
      print('✅ [Main] 窗口已显示，关闭按钮将最小化到托盘');
    });
  }
  
  // 🔧 初始化 URL 服务（必须在其他网络服务之前）
  await UrlService().initialize();
  DeveloperModeService().addLog('🌐 URL 服务已初始化');
  
  // 初始化版本检查服务
  await VersionService().initialize();
  DeveloperModeService().addLog('📱 版本服务已初始化');

  // 初始化自动更新服务
  await AutoUpdateService().initialize();
  DeveloperModeService().addLog('🔄 自动更新服务已初始化');
  
  // 初始化缓存服务
  await CacheService().initialize();
  DeveloperModeService().addLog('💾 缓存服务已初始化');
  
  // 初始化播放器背景服务
  await PlayerBackgroundService().initialize();
  DeveloperModeService().addLog('🎨 播放器背景服务已初始化');
  
  await PlayerService().initialize();
  DeveloperModeService().addLog('🎵 播放器服务已初始化');
  
  // 初始化歌词样式服务
  await LyricStyleService().initialize();
  DeveloperModeService().addLog('🎤 歌词样式服务已初始化');
  
  // 初始化歌词字体服务
  await LyricFontService().initialize();
  DeveloperModeService().addLog('🔤 歌词字体服务已初始化');
  
  // Android 平台特定初始化
  if (Platform.isAndroid) {
    // 启用边到边模式（让内容延伸到状态栏和导航栏下方）
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
    DeveloperModeService().addLog('📱 已启用边到边模式');
    
    // 请求通知权限（Android 13+）
    final hasPermission = await PermissionService().requestNotificationPermission();
    if (hasPermission) {
      DeveloperModeService().addLog('✅ 通知权限已授予');
    } else {
      DeveloperModeService().addLog('⚠️ 通知权限未授予，媒体通知可能无法显示');
    }
    
    // 启用高刷新率（如果设备支持）
    try {
      await FlutterDisplayMode.setHighRefreshRate();
      final activeMode = await FlutterDisplayMode.active;
      DeveloperModeService().addLog('🎨 显示模式: ${activeMode.width}x${activeMode.height} @${activeMode.refreshRate.toStringAsFixed(0)}Hz');
      print('🎨 [DisplayMode] 已启用高刷新率: ${activeMode.refreshRate.toStringAsFixed(0)}Hz');
    } catch (e) {
      DeveloperModeService().addLog('⚠️ 高刷新率设置失败: $e');
      print('⚠️ [DisplayMode] 设置高刷新率失败: $e');
    }
  }
  
  // 初始化系统媒体控件
  await SystemMediaService().initialize();
  DeveloperModeService().addLog('🎛️ 系统媒体服务已初始化');
  
  // 初始化系统托盘
  await TrayService().initialize();
  DeveloperModeService().addLog('📌 系统托盘已初始化');
  
  // 初始化听歌统计服务
  ListeningStatsService().initialize();
  DeveloperModeService().addLog('📊 听歌统计服务已初始化');
  
  // 初始化通知服务
  await NotificationService().initialize();
  
  // 初始化桌面歌词服务（仅Windows）
  if (Platform.isWindows) {
    await DesktopLyricService().initialize();
    DeveloperModeService().addLog('🎤 桌面歌词服务已初始化');
  }
  
  // 初始化Android悬浮歌词服务（仅Android）
  if (Platform.isAndroid) {
    await AndroidFloatingLyricService().initialize();
    DeveloperModeService().addLog('📱 Android悬浮歌词服务已初始化');
  }
  
  // 检查并显示恢复播放通知（延迟2秒，等待UI完全加载）
  print('⏰ [Main] 将在2秒后检查播放恢复状态...');
  DeveloperModeService().addLog('⏰ 将在2秒后检查播放恢复状态...');
  
  Future.delayed(const Duration(seconds: 2), () {
    print('🔄 [Main] 开始检查播放恢复状态...');
    DeveloperModeService().addLog('🔄 开始检查播放恢复状态...');
    
    PlaybackResumeService().checkAndShowResumeNotification().then((_) {
      print('✅ [Main] 播放恢复检查完成');
      DeveloperModeService().addLog('✅ 播放恢复检查完成');
    }).catchError((e) {
      print('❌ [Main] 播放恢复检查失败: $e');
      DeveloperModeService().addLog('❌ 播放恢复检查失败: $e');
    });
  });
  
  runApp(const MyApp());
  
  // Windows 平台初始化 bitsdojo_window 设置（与 window_manager 配合使用）
  if (Platform.isWindows) {
    doWhenWindowReady(() {
      const initialSize = Size(1320, 880);
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
    final themeManager = ThemeManager();

    return AnimatedBuilder(
      animation: themeManager,
      builder: (context, _) {
        final lightTheme = themeManager.buildThemeData(Brightness.light);
        final darkTheme = themeManager.buildThemeData(Brightness.dark);

        final useFluentLayout = Platform.isWindows && themeManager.isFluentFramework;
        final useCupertinoLayout = (Platform.isIOS || Platform.isAndroid) && themeManager.isCupertinoFramework;

        if (useFluentLayout) {
          return fluent.FluentApp(
            title: 'Cyrene Music',
            debugShowCheckedModeBanner: false,
            theme: themeManager.buildFluentThemeData(Brightness.light),
            darkTheme: themeManager.buildFluentThemeData(Brightness.dark),
            themeMode: _mapMaterialThemeMode(themeManager.themeMode),
            scrollBehavior: const _FluentScrollBehavior(),
            home: const FluentMainLayout(),
          );
        }

        // 移动端 Cupertino 风格
        if (useCupertinoLayout) {
          final cupertinoTheme = themeManager.buildCupertinoThemeData(
            themeManager.themeMode == ThemeMode.dark 
                ? Brightness.dark 
                : (themeManager.themeMode == ThemeMode.system 
                    ? WidgetsBinding.instance.platformDispatcher.platformBrightness 
                    : Brightness.light),
          );
          
          // 使用 MaterialApp 包裹 CupertinoTheme 以保持 Navigator 等功能
          return MaterialApp(
            title: 'Cyrene Music',
            debugShowCheckedModeBanner: false,
            theme: lightTheme.copyWith(
              cupertinoOverrideTheme: themeManager.buildCupertinoThemeData(Brightness.light),
            ),
            darkTheme: darkTheme.copyWith(
              cupertinoOverrideTheme: themeManager.buildCupertinoThemeData(Brightness.dark),
            ),
            themeMode: themeManager.themeMode,
            builder: (context, child) {
              return CupertinoTheme(
                data: cupertinoTheme,
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const MainLayout(),
          );
        }

        return MaterialApp(
          title: 'Cyrene Music',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeManager.themeMode,
      home: Platform.isWindows
          ? _WindowsRoundedContainer(child: const MainLayout())
          : const MainLayout(),
        );
      },
    );
  }
}

fluent.ThemeMode _mapMaterialThemeMode(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return fluent.ThemeMode.light;
    case ThemeMode.dark:
      return fluent.ThemeMode.dark;
    case ThemeMode.system:
      return fluent.ThemeMode.system;
  }
}
class _FluentScrollBehavior extends MaterialScrollBehavior {
  const _FluentScrollBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

/// Windows 圆角窗口容器
class _WindowsRoundedContainer extends StatefulWidget {
  final Widget child;
  
  const _WindowsRoundedContainer({required this.child});

  @override
  State<_WindowsRoundedContainer> createState() => _WindowsRoundedContainerState();
}

class _WindowsRoundedContainerState extends State<_WindowsRoundedContainer> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximizedState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _checkMaximizedState() async {
    final isMaximized = await windowManager.isMaximized();
    if (mounted) {
      setState(() {
        _isMaximized = isMaximized;
      });
    }
  }

  @override
  void onWindowMaximize() {
    setState(() {
      _isMaximized = true;
    });
  }

  @override
  void onWindowUnmaximize() {
    setState(() {
      _isMaximized = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // 最大化时无边距和圆角，正常时有边距和圆角
    return Container(
      padding: _isMaximized ? EdgeInsets.zero : const EdgeInsets.all(8.0),
      color: Theme.of(context).colorScheme.background,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: _isMaximized ? BorderRadius.zero : BorderRadius.circular(12),
          // 移除阴影效果
        ),
        child: ClipRRect(
          borderRadius: _isMaximized ? BorderRadius.zero : BorderRadius.circular(12),
          child: widget.child,
        ),
      ),
    );
  }
}