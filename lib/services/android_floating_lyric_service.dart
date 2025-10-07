import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android 悬浮歌词服务
/// 
/// 提供 Android 系统级悬浮窗歌词功能，包括：
/// - 创建/销毁悬浮窗
/// - 显示/隐藏歌词
/// - 权限管理
/// - 自定义字体、颜色、透明度
/// - 拖动和位置记忆
class AndroidFloatingLyricService {
  static final AndroidFloatingLyricService _instance = AndroidFloatingLyricService._internal();
  factory AndroidFloatingLyricService() => _instance;
  AndroidFloatingLyricService._internal();

  static const MethodChannel _channel = MethodChannel('android_floating_lyric');

  // 配置项的SharedPreferences键
  static const String _keyEnabled = 'android_floating_lyric_enabled';
  static const String _keyFontSize = 'android_floating_lyric_font_size';
  static const String _keyTextColor = 'android_floating_lyric_text_color';
  static const String _keyStrokeColor = 'android_floating_lyric_stroke_color';
  static const String _keyStrokeWidth = 'android_floating_lyric_stroke_width';
  static const String _keyPositionX = 'android_floating_lyric_position_x';
  static const String _keyPositionY = 'android_floating_lyric_position_y';
  static const String _keyDraggable = 'android_floating_lyric_draggable';
  static const String _keyAlpha = 'android_floating_lyric_alpha';

  bool _isVisible = false;
  String _currentLyric = '';

  // 默认配置
  int _fontSize = 20;
  int _textColor = 0xFFFFFFFF; // 白色
  int _strokeColor = 0xFF000000; // 黑色
  int _strokeWidth = 2;
  bool _isDraggable = true;
  double _alpha = 1.0;

  /// 初始化服务（加载配置）
  Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 加载配置
      final enabled = prefs.getBool(_keyEnabled) ?? false;
      _fontSize = prefs.getInt(_keyFontSize) ?? 20;
      _textColor = prefs.getInt(_keyTextColor) ?? 0xFFFFFFFF;
      _strokeColor = prefs.getInt(_keyStrokeColor) ?? 0xFF000000;
      _strokeWidth = prefs.getInt(_keyStrokeWidth) ?? 2;
      _isDraggable = prefs.getBool(_keyDraggable) ?? true;
      _alpha = prefs.getDouble(_keyAlpha) ?? 1.0;

      // 应用配置
      await setFontSize(_fontSize, saveToPrefs: false);
      await setTextColor(_textColor, saveToPrefs: false);
      await setStrokeColor(_strokeColor, saveToPrefs: false);
      await setStrokeWidth(_strokeWidth, saveToPrefs: false);
      await setDraggable(_isDraggable, saveToPrefs: false);
      await setAlpha(_alpha, saveToPrefs: false);

      // 如果之前是启用状态，则显示悬浮窗
      if (enabled) {
        await show();
      }
      
      print('✅ [AndroidFloatingLyric] Android 悬浮歌词服务初始化成功');
    } catch (e) {
      print('⚠️ [AndroidFloatingLyric] 初始化失败: $e');
    }
  }

  /// 检查悬浮窗权限
  Future<bool> checkPermission() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await _channel.invokeMethod('checkPermission');
      return result == true;
    } catch (e) {
      print('❌ [AndroidFloatingLyric] 检查权限失败: $e');
      return false;
    }
  }

  /// 请求悬浮窗权限（自动跳转到设置页面）
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await _channel.invokeMethod('requestPermission');
      return result == true;
    } catch (e) {
      print('❌ [AndroidFloatingLyric] 请求权限失败: $e');
      return false;
    }
  }

  /// 请求权限并等待用户授权
  Future<bool> requestPermissionWithDialog(context) async {
    if (!Platform.isAndroid) return false;
    
    // 先检查是否已有权限
    if (await checkPermission()) {
      return true;
    }
    
    // 显示权限说明对话框
    final shouldRequest = await _showPermissionDialog(context);
    if (!shouldRequest) {
      return false;
    }
    
    // 跳转到设置页面
    await requestPermission();
    
    // 等待用户操作并检查权限状态
    return await _waitForPermissionResult(context);
  }

  /// 显示权限说明对话框
  Future<bool> _showPermissionDialog(context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎵 悬浮歌词权限'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('悬浮歌词需要"显示在其他应用上方"的权限才能正常工作。'),
            SizedBox(height: 12),
            Text('授权后，您可以在使用其他应用时看到实时歌词显示。'),
            SizedBox(height: 8),
            Text('💡 点击"去设置"将跳转到权限设置页面'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor,
            ),
            child: const Text('去设置'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// 等待权限授权结果
  Future<bool> _waitForPermissionResult(context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PermissionWaitingDialog(),
    ) ?? false;
  }

  /// 显示悬浮歌词窗口
  Future<void> show() async {
    if (!Platform.isAndroid) return;

    // 检查权限
    final hasPermission = await checkPermission();
    if (!hasPermission) {
      print('⚠️ [AndroidFloatingLyric] 没有悬浮窗权限');
      return;
    }

    try {
      final result = await _channel.invokeMethod('showFloatingWindow');
      _isVisible = result == true;
      
      if (_isVisible) {
        // 设置当前歌词
        if (_currentLyric.isNotEmpty) {
          await setLyricText(_currentLyric);
        }
        
        // 保存启用状态
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyEnabled, true);
        
        print('✅ [AndroidFloatingLyric] 悬浮窗已显示');
      }
    } catch (e) {
      print('❌ [AndroidFloatingLyric] 显示悬浮窗失败: $e');
    }
  }

  /// 隐藏悬浮歌词窗口
  Future<void> hide() async {
    if (!Platform.isAndroid || !_isVisible) return;

    try {
      await _channel.invokeMethod('hideFloatingWindow');
      _isVisible = false;
      
      // 保存启用状态
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyEnabled, false);
      
      print('✅ [AndroidFloatingLyric] 悬浮窗已隐藏');
    } catch (e) {
      print('❌ [AndroidFloatingLyric] 隐藏悬浮窗失败: $e');
    }
  }

  /// 切换显示/隐藏
  Future<void> toggle() async {
    if (_isVisible) {
      await hide();
    } else {
      await show();
    }
  }

  /// 设置歌词文本（旧方法，兼容性保留）
  Future<void> setLyricText(String text) async {
    if (!Platform.isAndroid) return;
    
    _currentLyric = text;
    
    // 如果悬浮窗不可见，只保存文本，不实际设置
    if (!_isVisible) return;

    try {
      await _channel.invokeMethod('updateLyric', {'text': text});
    } catch (e) {
      print('❌ [AndroidFloatingLyric] 设置歌词失败: $e');
    }
  }

  /// 🔥 新增：设置完整歌词数据（关键方法）
  /// 
  /// 将完整的歌词数组发送到Android原生层，由原生层自行管理歌词更新
  /// 这样即使应用退到后台，歌词也能继续更新
  Future<void> setLyricsData(List<Map<String, dynamic>> lyrics) async {
    if (!Platform.isAndroid || !_isVisible) return;

    try {
      // 将歌词数组转换为JSON字符串
      final lyricsJson = lyrics.map((lyric) => {
        'time': lyric['time'] ?? 0,
        'text': lyric['text'] ?? '',
        'translation': lyric['translation'] ?? '',
      }).toList();

      final jsonString = jsonEncode(lyricsJson);

      await _channel.invokeMethod('setLyrics', {'lyrics': jsonString});
      print('✅ [AndroidFloatingLyric] 歌词数据已发送到原生层: ${lyrics.length} 行');
    } catch (e) {
      print('❌ [AndroidFloatingLyric] 设置歌词数据失败: $e');
    }
  }

  /// 🔥 新增：更新播放位置（关键方法）
  Future<void> updatePosition(Duration position) async {
    if (!Platform.isAndroid || !_isVisible) return;

    try {
      await _channel.invokeMethod('updatePosition', {
        'position': position.inMilliseconds,
      });
    } catch (e) {
      // 忽略错误，避免日志刷屏
    }
  }

  /// 🔥 新增：设置播放状态（关键方法）
  Future<void> setPlayingState(bool playing) async {
    if (!Platform.isAndroid || !_isVisible) return;

    try {
      await _channel.invokeMethod('setPlayingState', {
        'playing': playing,
      });
      print('✅ [AndroidFloatingLyric] 播放状态已更新: ${playing ? "播放中" : "已暂停"}');
    } catch (e) {
      print('❌ [AndroidFloatingLyric] 设置播放状态失败: $e');
    }
  }

  /// 设置窗口位置
  Future<void> setPosition(int x, int y) async {
    if (!Platform.isAndroid || !_isVisible) return;

    try {
      await _channel.invokeMethod('setPosition', {'x': x, 'y': y});
      
      // 保存位置
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyPositionX, x);
      await prefs.setInt(_keyPositionY, y);
    } catch (e) {
      print('❌ [AndroidFloatingLyric] 设置位置失败: $e');
    }
  }

  /// 设置字体大小
  Future<void> setFontSize(int size, {bool saveToPrefs = true}) async {
    if (!Platform.isAndroid) return;

    _fontSize = size;

    try {
      if (_isVisible) {
        await _channel.invokeMethod('setFontSize', {'size': size});
      }
      
      if (saveToPrefs) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_keyFontSize, size);
      }
    } catch (e) {
      print('❌ [AndroidFloatingLyric] 设置字体大小失败: $e');
    }
  }

  /// 设置文字颜色（ARGB格式）
  Future<void> setTextColor(int color, {bool saveToPrefs = true}) async {
    if (!Platform.isAndroid) return;

    _textColor = color;

    try {
      if (_isVisible) {
        await _channel.invokeMethod('setTextColor', {'color': color});
      }
      
      if (saveToPrefs) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_keyTextColor, color);
      }
    } catch (e) {
      print('❌ [AndroidFloatingLyric] 设置文字颜色失败: $e');
    }
  }

  /// 设置描边颜色（ARGB格式）
  Future<void> setStrokeColor(int color, {bool saveToPrefs = true}) async {
    if (!Platform.isAndroid) return;

    _strokeColor = color;

    try {
      if (_isVisible) {
        await _channel.invokeMethod('setStrokeColor', {'color': color});
      }
      
      if (saveToPrefs) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_keyStrokeColor, color);
      }
    } catch (e) {
      print('❌ [AndroidFloatingLyric] 设置描边颜色失败: $e');
    }
  }

  /// 设置描边宽度
  Future<void> setStrokeWidth(int width, {bool saveToPrefs = true}) async {
    if (!Platform.isAndroid) return;

    _strokeWidth = width;

    try {
      if (_isVisible) {
        await _channel.invokeMethod('setStrokeWidth', {'width': width});
      }
      
      if (saveToPrefs) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_keyStrokeWidth, width);
      }
    } catch (e) {
      print('❌ [AndroidFloatingLyric] 设置描边宽度失败: $e');
    }
  }

  /// 设置是否可拖动
  Future<void> setDraggable(bool draggable, {bool saveToPrefs = true}) async {
    if (!Platform.isAndroid) return;

    _isDraggable = draggable;

    try {
      if (_isVisible) {
        await _channel.invokeMethod('setDraggable', {'draggable': draggable});
      }
      
      if (saveToPrefs) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyDraggable, draggable);
      }
    } catch (e) {
      print('❌ [AndroidFloatingLyric] 设置拖动状态失败: $e');
    }
  }

  /// 设置透明度
  Future<void> setAlpha(double alpha, {bool saveToPrefs = true}) async {
    if (!Platform.isAndroid) return;

    _alpha = alpha.clamp(0.0, 1.0);

    try {
      if (_isVisible) {
        await _channel.invokeMethod('setAlpha', {'alpha': _alpha});
      }
      
      if (saveToPrefs) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_keyAlpha, _alpha);
      }
    } catch (e) {
      print('❌ [AndroidFloatingLyric] 设置透明度失败: $e');
    }
  }

  /// 检查是否可见
  bool get isVisible => _isVisible;

  /// 获取当前歌词
  String get currentLyric => _currentLyric;

  /// 获取当前配置
  Map<String, dynamic> get config => {
    'fontSize': _fontSize,
    'textColor': _textColor,
    'strokeColor': _strokeColor,
    'strokeWidth': _strokeWidth,
    'isDraggable': _isDraggable,
    'alpha': _alpha,
  };

  /// 销毁悬浮窗（应用退出时调用）
  Future<void> dispose() async {
    if (!Platform.isAndroid || !_isVisible) return;

    try {
      await hide();
      print('✅ [AndroidFloatingLyric] 悬浮歌词服务已销毁');
    } catch (e) {
      print('❌ [AndroidFloatingLyric] 销毁悬浮窗失败: $e');
    }
  }
}

/// 权限等待对话框
class _PermissionWaitingDialog extends StatefulWidget {
  @override
  State<_PermissionWaitingDialog> createState() => _PermissionWaitingDialogState();
}

class _PermissionWaitingDialogState extends State<_PermissionWaitingDialog> {
  Timer? _timer;
  int _countdown = 30; // 30秒超时

  @override
  void initState() {
    super.initState();
    _startCheckingPermission();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 开始检查权限状态
  void _startCheckingPermission() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _countdown--;
      
      if (_countdown <= 0) {
        // 超时
        _timer?.cancel();
        if (mounted) {
          Navigator.pop(context, false);
        }
        return;
      }

      // 检查权限状态
      final hasPermission = await AndroidFloatingLyricService().checkPermission();
      if (hasPermission) {
        _timer?.cancel();
        if (mounted) {
          Navigator.pop(context, true);
        }
        return;
      }

      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // 禁止返回
      child: AlertDialog(
        title: const Text('⏳ 等待权限授权'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('请在设置页面中找到 "Cyrene Music"'),
            const SizedBox(height: 8),
            Text('开启 "显示在其他应用上方" 权限'),
            const SizedBox(height: 16),
            Text('将在 $_countdown 秒后自动关闭', 
                 style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _timer?.cancel();
              Navigator.pop(context, false);
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              // 手动检查权限
              final hasPermission = await AndroidFloatingLyricService().checkPermission();
              if (hasPermission) {
                _timer?.cancel();
                Navigator.pop(context, true);
              }
            },
            child: const Text('我已授权'),
          ),
        ],
      ),
    );
  }
}
