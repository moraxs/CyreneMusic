import 'package:flutter/material.dart';

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
  ThemeManager._internal();

  ThemeMode _themeMode = ThemeMode.light;
  Color _seedColor = Colors.deepPurple;

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// 切换主题模式
  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
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
