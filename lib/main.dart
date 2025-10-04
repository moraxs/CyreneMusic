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
import 'services/cache_service.dart';
import 'services/permission_service.dart';
import 'services/url_service.dart';
import 'services/version_service.dart';
import 'services/player_background_service.dart';
import 'services/persistent_storage_service.dart';
import 'services/listening_stats_service.dart';

// 条件导入 SMTC
import 'package:smtc_windows/smtc_windows.dart' if (dart.library.html) '';

// 条件导入 flutter_displaymode（仅 Android）
import 'package:flutter_displaymode/flutter_displaymode.dart' if (dart.library.html) '';

void main() async {
  // 初始化播放器服务
  WidgetsFlutterBinding.ensureInitialized();
  
  // 添加应用启动日志
  DeveloperModeService().addLog('🚀 应用启动');
  DeveloperModeService().addLog('📱 平台: ${Platform.operatingSystem}');
  
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
      
      // 设置窗口图标（任务栏图标）
      if (Platform.isWindows) {
        await windowManager.setIcon('assets/icons/tray_icon.ico');
      } else if (Platform.isMacOS || Platform.isLinux) {
        await windowManager.setIcon('assets/icons/tray_icon.png');
      }
      
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
  
  // 🔧 初始化 URL 服务（必须在其他网络服务之前）
  await UrlService().initialize();
  DeveloperModeService().addLog('🌐 URL 服务已初始化');
  
  // 初始化版本检查服务
  await VersionService().initialize();
  DeveloperModeService().addLog('📱 版本服务已初始化');
  
  // 初始化缓存服务
  await CacheService().initialize();
  DeveloperModeService().addLog('💾 缓存服务已初始化');
  
  // 初始化播放器背景服务
  await PlayerBackgroundService().initialize();
  DeveloperModeService().addLog('🎨 播放器背景服务已初始化');
  
  await PlayerService().initialize();
  DeveloperModeService().addLog('🎵 播放器服务已初始化');
  
  // Android 平台特定初始化
  if (Platform.isAndroid) {
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
    return Padding(
      padding: _isMaximized ? EdgeInsets.zero : const EdgeInsets.all(8.0),
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