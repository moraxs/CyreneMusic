import 'package:flutter/material.dart';
import '../utils/theme_manager.dart';
import '../services/url_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/layout_preference_service.dart';
import '../services/cache_service.dart';
import '../services/download_service.dart';
import '../services/audio_quality_service.dart';
import '../services/player_background_service.dart';
import 'settings_page/user_card.dart';
import 'settings_page/third_party_accounts.dart';
import 'settings_page/appearance_settings.dart';
import 'settings_page/lyric_settings.dart';
import 'settings_page/playback_settings.dart';
import 'settings_page/network_settings.dart';
import 'settings_page/storage_settings.dart';
import 'settings_page/about_settings.dart';

/// 设置页面
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    print('⚙️ [SettingsPage] 初始化设置页面...');
    
    // 监听主题变化
    ThemeManager().addListener(_onThemeChanged);
    // 监听 URL 服务变化
    UrlService().addListener(_onUrlServiceChanged);
    // 监听认证状态变化
    AuthService().addListener(_onAuthChanged);
    // 监听位置信息变化
    LocationService().addListener(_onLocationChanged);
    // 监听布局偏好变化
    LayoutPreferenceService().addListener(_onLayoutPreferenceChanged);
    // 监听缓存服务变化
    CacheService().addListener(_onCacheChanged);
    // 监听下载服务变化
    DownloadService().addListener(_onDownloadChanged);
    // 监听音质服务变化
    AudioQualityService().addListener(_onAudioQualityChanged);
    // 监听播放器背景服务变化
    PlayerBackgroundService().addListener(_onPlayerBackgroundChanged);
    
    // 如果已登录，获取 IP 归属地
    final isLoggedIn = AuthService().isLoggedIn;
    print('⚙️ [SettingsPage] 当前登录状态: $isLoggedIn');
    
    if (isLoggedIn) {
      print('⚙️ [SettingsPage] 用户已登录，开始获取IP归属地...');
      LocationService().fetchLocation();
    } else {
      print('⚙️ [SettingsPage] 用户未登录，跳过获取IP归属地');
    }
  }

  @override
  void dispose() {
    ThemeManager().removeListener(_onThemeChanged);
    UrlService().removeListener(_onUrlServiceChanged);
    AuthService().removeListener(_onAuthChanged);
    LocationService().removeListener(_onLocationChanged);
    LayoutPreferenceService().removeListener(_onLayoutPreferenceChanged);
    CacheService().removeListener(_onCacheChanged);
    DownloadService().removeListener(_onDownloadChanged);
    AudioQualityService().removeListener(_onAudioQualityChanged);
    PlayerBackgroundService().removeListener(_onPlayerBackgroundChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onUrlServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onAuthChanged() {
    if (mounted) {
      setState(() {});
      // 登录状态变化时获取/清除位置信息
      if (AuthService().isLoggedIn) {
        print('👤 [SettingsPage] 用户已登录，开始获取IP归属地...');
        LocationService().fetchLocation();
      } else {
        print('👤 [SettingsPage] 用户已退出，清除IP归属地...');
        LocationService().clearLocation();
      }
    }
  }

  void _onLocationChanged() {
    print('🌍 [SettingsPage] 位置信息已更新，刷新UI...');
    if (mounted) {
      setState(() {});
    }
  }

  void _onLayoutPreferenceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onCacheChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onDownloadChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onAudioQualityChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onPlayerBackgroundChanged() {
    if (mounted) {
      setState(() {});
    }
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // 顶部标题
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: colorScheme.surface,
            title: Text(
              '设置',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // 设置内容
          SliverPadding(
            padding: const EdgeInsets.all(24.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 用户卡片
                const UserCard(),
                const SizedBox(height: 24),
                
                // 第三方账号管理（仅登录时显示）
                const ThirdPartyAccounts(),
                const SizedBox(height: 24),
                
                // 外观设置
                const AppearanceSettings(),
                const SizedBox(height: 24),
                
                // 歌词设置（仅 Windows 和 Android 平台显示）
                const LyricSettings(),
                  const SizedBox(height: 24),
                
                // 播放设置
                const PlaybackSettings(),
                const SizedBox(height: 24),
                
                // 网络设置
                const NetworkSettings(),
                const SizedBox(height: 24),
                
                // 存储设置
                const StorageSettings(),
                const SizedBox(height: 24),
                
                // 关于
                const AboutSettings(),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}