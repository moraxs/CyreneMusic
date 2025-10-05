import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 桌面歌词服务（仅Windows平台）
/// 
/// 提供系统级桌面歌词功能，包括：
/// - 创建/销毁桌面歌词窗口
/// - 显示/隐藏歌词
/// - 自定义字体、颜色、描边
/// - 拖动和鼠标穿透设置
class DesktopLyricService {
  static final DesktopLyricService _instance = DesktopLyricService._internal();
  factory DesktopLyricService() => _instance;
  DesktopLyricService._internal();

  static const MethodChannel _channel = MethodChannel('desktop_lyric');

  // 配置项的SharedPreferences键
  static const String _keyEnabled = 'desktop_lyric_enabled';
  static const String _keyFontSize = 'desktop_lyric_font_size';
  static const String _keyTextColor = 'desktop_lyric_text_color';
  static const String _keyStrokeColor = 'desktop_lyric_stroke_color';
  static const String _keyStrokeWidth = 'desktop_lyric_stroke_width';
  static const String _keyPositionX = 'desktop_lyric_position_x';
  static const String _keyPositionY = 'desktop_lyric_position_y';
  static const String _keyDraggable = 'desktop_lyric_draggable';
  static const String _keyMouseTransparent = 'desktop_lyric_mouse_transparent';

  bool _isCreated = false;
  bool _isVisible = false;
  String _currentLyric = '';

  // 默认配置
  int _fontSize = 32;
  int _textColor = 0xFFFFFFFF; // 白色
  int _strokeColor = 0xFF000000; // 黑色
  int _strokeWidth = 2;
  bool _isDraggable = true;
  bool _isMouseTransparent = false;

  /// 初始化服务（加载配置）
  Future<void> initialize() async {
    if (!Platform.isWindows) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 加载配置
      final enabled = prefs.getBool(_keyEnabled) ?? false;
      _fontSize = prefs.getInt(_keyFontSize) ?? 32;
      _textColor = prefs.getInt(_keyTextColor) ?? 0xFFFFFFFF;
      _strokeColor = prefs.getInt(_keyStrokeColor) ?? 0xFF000000;
      _strokeWidth = prefs.getInt(_keyStrokeWidth) ?? 2;
      _isDraggable = prefs.getBool(_keyDraggable) ?? true;
      _isMouseTransparent = prefs.getBool(_keyMouseTransparent) ?? false;

      // 延迟创建窗口，确保不阻塞主窗口启动
      Future.delayed(Duration(milliseconds: 500), () async {
        try {
          // 创建窗口
          await _createWindow();

          // 应用配置
          await setFontSize(_fontSize, saveToPrefs: false);
          await setTextColor(_textColor, saveToPrefs: false);
          await setStrokeColor(_strokeColor, saveToPrefs: false);
          await setStrokeWidth(_strokeWidth, saveToPrefs: false);
          await setDraggable(_isDraggable, saveToPrefs: false);
          await setMouseTransparent(_isMouseTransparent, saveToPrefs: false);

          // 恢复位置
          final x = prefs.getInt(_keyPositionX);
          final y = prefs.getInt(_keyPositionY);
          if (x != null && y != null) {
            await setPosition(x, y);
          }

          // 如果之前是启用状态，则显示窗口
          if (enabled) {
            await show();
          }
          
          print('✅ [DesktopLyric] 桌面歌词服务初始化成功');
        } catch (e) {
          print('⚠️ [DesktopLyric] 延迟初始化失败: $e');
        }
      });
    } catch (e) {
      print('⚠️ [DesktopLyric] 初始化失败: $e');
    }
  }

  /// 创建桌面歌词窗口
  Future<bool> _createWindow() async {
    if (!Platform.isWindows || _isCreated) return true;

    try {
      final result = await _channel.invokeMethod('create');
      _isCreated = result == true;
      return _isCreated;
    } catch (e) {
      print('❌ [DesktopLyric] 创建窗口失败: $e');
      return false;
    }
  }

  /// 显示桌面歌词
  Future<void> show() async {
    if (!Platform.isWindows) return;
    
    // 如果窗口还未创建，先创建
    if (!_isCreated) {
      await _createWindow();
      if (!_isCreated) {
        print('❌ [DesktopLyric] 窗口创建失败，无法显示');
        return;
      }
    }

    try {
      await _channel.invokeMethod('show');
      _isVisible = true;
      
      // 保存启用状态
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyEnabled, true);
    } catch (e) {
      print('❌ [DesktopLyric] 显示窗口失败: $e');
    }
  }

  /// 隐藏桌面歌词
  Future<void> hide() async {
    if (!Platform.isWindows || !_isCreated) return;

    try {
      await _channel.invokeMethod('hide');
      _isVisible = false;
      
      // 保存启用状态
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyEnabled, false);
    } catch (e) {
      print('❌ [DesktopLyric] 隐藏窗口失败: $e');
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

  /// 设置歌词文本
  Future<void> setLyricText(String text) async {
    if (!Platform.isWindows) return;
    
    _currentLyric = text;
    
    // 如果窗口未创建，只保存文本，不实际设置
    if (!_isCreated) return;

    try {
      await _channel.invokeMethod('setLyricText', {'text': text});
    } catch (e) {
      print('❌ [DesktopLyric] 设置歌词失败: $e');
    }
  }

  /// 设置窗口位置
  Future<void> setPosition(int x, int y) async {
    if (!Platform.isWindows || !_isCreated) return;

    try {
      await _channel.invokeMethod('setPosition', {'x': x, 'y': y});
      
      // 保存位置
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyPositionX, x);
      await prefs.setInt(_keyPositionY, y);
    } catch (e) {
      print('❌ [DesktopLyric] 设置位置失败: $e');
    }
  }

  /// 获取窗口位置
  Future<Map<String, int>?> getPosition() async {
    if (!Platform.isWindows || !_isCreated) return null;

    try {
      final result = await _channel.invokeMethod('getPosition');
      return {
        'x': result['x'] as int,
        'y': result['y'] as int,
      };
    } catch (e) {
      print('❌ [DesktopLyric] 获取位置失败: $e');
      return null;
    }
  }

  /// 设置字体大小
  Future<void> setFontSize(int size, {bool saveToPrefs = true}) async {
    if (!Platform.isWindows || !_isCreated) return;

    _fontSize = size;

    try {
      await _channel.invokeMethod('setFontSize', {'size': size});
      
      if (saveToPrefs) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_keyFontSize, size);
      }
    } catch (e) {
      print('❌ [DesktopLyric] 设置字体大小失败: $e');
    }
  }

  /// 设置文字颜色（ARGB格式）
  Future<void> setTextColor(int color, {bool saveToPrefs = true}) async {
    if (!Platform.isWindows || !_isCreated) return;

    _textColor = color;

    try {
      await _channel.invokeMethod('setTextColor', {'color': color});
      
      if (saveToPrefs) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_keyTextColor, color);
      }
    } catch (e) {
      print('❌ [DesktopLyric] 设置文字颜色失败: $e');
    }
  }

  /// 设置描边颜色（ARGB格式）
  Future<void> setStrokeColor(int color, {bool saveToPrefs = true}) async {
    if (!Platform.isWindows || !_isCreated) return;

    _strokeColor = color;

    try {
      await _channel.invokeMethod('setStrokeColor', {'color': color});
      
      if (saveToPrefs) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_keyStrokeColor, color);
      }
    } catch (e) {
      print('❌ [DesktopLyric] 设置描边颜色失败: $e');
    }
  }

  /// 设置描边宽度
  Future<void> setStrokeWidth(int width, {bool saveToPrefs = true}) async {
    if (!Platform.isWindows || !_isCreated) return;

    _strokeWidth = width;

    try {
      await _channel.invokeMethod('setStrokeWidth', {'width': width});
      
      if (saveToPrefs) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_keyStrokeWidth, width);
      }
    } catch (e) {
      print('❌ [DesktopLyric] 设置描边宽度失败: $e');
    }
  }

  /// 设置是否可拖动
  Future<void> setDraggable(bool draggable, {bool saveToPrefs = true}) async {
    if (!Platform.isWindows || !_isCreated) return;

    _isDraggable = draggable;

    try {
      await _channel.invokeMethod('setDraggable', {'draggable': draggable});
      
      if (saveToPrefs) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyDraggable, draggable);
      }
    } catch (e) {
      print('❌ [DesktopLyric] 设置拖动状态失败: $e');
    }
  }

  /// 设置鼠标穿透
  Future<void> setMouseTransparent(bool transparent, {bool saveToPrefs = true}) async {
    if (!Platform.isWindows || !_isCreated) return;

    _isMouseTransparent = transparent;

    try {
      await _channel.invokeMethod('setMouseTransparent', {'transparent': transparent});
      
      if (saveToPrefs) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyMouseTransparent, transparent);
      }
    } catch (e) {
      print('❌ [DesktopLyric] 设置鼠标穿透失败: $e');
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
    'isMouseTransparent': _isMouseTransparent,
  };

  /// 销毁窗口（应用退出时调用）
  Future<void> dispose() async {
    if (!Platform.isWindows || !_isCreated) return;

    try {
      // 保存当前位置
      final position = await getPosition();
      if (position != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_keyPositionX, position['x']!);
        await prefs.setInt(_keyPositionY, position['y']!);
      }

      await _channel.invokeMethod('destroy');
      _isCreated = false;
      _isVisible = false;
    } catch (e) {
      print('❌ [DesktopLyric] 销毁窗口失败: $e');
    }
  }
}
