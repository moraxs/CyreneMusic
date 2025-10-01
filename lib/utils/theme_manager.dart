import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 预设主题色方案
class ThemeColorScheme {
  final String name;
  final Color color;
  final IconData icon;

  const ThemeColorScheme({
    required this.name,
    required this.color,
    required this.icon,
  });
}

/// 预设的主题色列表
class ThemeColors {
  static const List<ThemeColorScheme> presets = [
    ThemeColorScheme(name: '深紫色', color: Colors.deepPurple, icon: Icons.palette),
    ThemeColorScheme(name: '蓝色', color: Colors.blue, icon: Icons.water_drop),
    ThemeColorScheme(name: '青色', color: Colors.cyan, icon: Icons.waves),
    ThemeColorScheme(name: '绿色', color: Colors.green, icon: Icons.eco),
    ThemeColorScheme(name: '橙色', color: Colors.orange, icon: Icons.wb_sunny),
    ThemeColorScheme(name: '粉色', color: Colors.pink, icon: Icons.favorite),
    ThemeColorScheme(name: '红色', color: Colors.red, icon: Icons.local_fire_department),
    ThemeColorScheme(name: '靛蓝色', color: Colors.indigo, icon: Icons.nights_stay),
    ThemeColorScheme(name: '青柠色', color: Colors.lime, icon: Icons.energy_savings_leaf),
    ThemeColorScheme(name: '琥珀色', color: Colors.amber, icon: Icons.light_mode),
  ];
}

/// 主题管理器 - 使用单例模式管理应用主题
class ThemeManager extends ChangeNotifier {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal() {
    _loadSettings();
  }

  ThemeMode _themeMode = ThemeMode.light;
  Color _seedColor = Colors.deepPurple;

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// 从本地存储加载主题设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 加载主题模式
      final themeModeIndex = prefs.getInt('theme_mode') ?? 0;
      _themeMode = ThemeMode.values[themeModeIndex];
      
      // 加载主题色
      final colorValue = prefs.getInt('seed_color') ?? Colors.deepPurple.value;
      _seedColor = Color(colorValue);
      
      print('🎨 [ThemeManager] 从本地加载主题: ${_themeMode.name}, 主题色: 0x${_seedColor.value.toRadixString(16)}');
      notifyListeners();
    } catch (e) {
      print('❌ [ThemeManager] 加载主题设置失败: $e');
    }
  }

  /// 保存主题模式到本地
  Future<void> _saveThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_mode', _themeMode.index);
      print('💾 [ThemeManager] 主题模式已保存: ${_themeMode.name}');
    } catch (e) {
      print('❌ [ThemeManager] 保存主题模式失败: $e');
    }
  }

  /// 保存主题色到本地
  Future<void> _saveSeedColor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('seed_color', _seedColor.value);
      print('💾 [ThemeManager] 主题色已保存: 0x${_seedColor.value.toRadixString(16)}');
    } catch (e) {
      print('❌ [ThemeManager] 保存主题色失败: $e');
    }
  }

  /// 切换主题模式
  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      _saveThemeMode();
      notifyListeners();
    }
  }

  /// 切换深色模式开关
  void toggleDarkMode(bool isDark) {
    setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  /// 跟随系统主题
  void setSystemMode() {
    setThemeMode(ThemeMode.system);
  }

  /// 设置主题色
  void setSeedColor(Color color) {
    if (_seedColor != color) {
      _seedColor = color;
      _saveSeedColor();
      notifyListeners();
    }
  }

  /// 获取当前主题色在预设列表中的索引
  int getCurrentColorIndex() {
    for (int i = 0; i < ThemeColors.presets.length; i++) {
      if (ThemeColors.presets[i].color.value == _seedColor.value) {
        return i;
      }
    }
    return 0; // 默认返回第一个
  }
}
