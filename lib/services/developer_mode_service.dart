import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 开发者模式服务
class DeveloperModeService extends ChangeNotifier {
  static final DeveloperModeService _instance = DeveloperModeService._internal();
  factory DeveloperModeService() => _instance;
  
  DeveloperModeService._internal() {
    _loadDeveloperMode();
  }

  bool _isDeveloperMode = false;
  bool get isDeveloperMode => _isDeveloperMode;

  int _settingsClickCount = 0;
  DateTime? _lastClickTime;

  /// 记录日志
  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  /// 处理设置按钮点击
  void onSettingsClicked() {
    final now = DateTime.now();
    
    // 如果距离上次点击超过2秒，重置计数
    if (_lastClickTime != null && now.difference(_lastClickTime!).inSeconds > 2) {
      _settingsClickCount = 0;
    }
    
    _lastClickTime = now;
    _settingsClickCount++;
    
    print('🔧 [DeveloperMode] 设置按钮点击次数: $_settingsClickCount');
    
    // 连续点击5次进入开发者模式
    if (_settingsClickCount >= 5 && !_isDeveloperMode) {
      _enableDeveloperMode();
      _settingsClickCount = 0;
    }
  }

  /// 启用开发者模式
  void _enableDeveloperMode() {
    _isDeveloperMode = true;
    _saveDeveloperMode();
    addLog('🚀 开发者模式已启用');
    notifyListeners();
    print('🚀 [DeveloperMode] 开发者模式已启用');
  }

  /// 禁用开发者模式
  void disableDeveloperMode() {
    _isDeveloperMode = false;
    _saveDeveloperMode();
    addLog('🔒 开发者模式已禁用');
    notifyListeners();
    print('🔒 [DeveloperMode] 开发者模式已禁用');
  }

  /// 添加日志
  void addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logEntry = '[$timestamp] $message';
    _logs.add(logEntry);
    
    // 限制日志数量，最多保留1000条
    if (_logs.length > 1000) {
      _logs.removeAt(0);
    }
    
    notifyListeners();
  }

  /// 清除所有日志
  void clearLogs() {
    _logs.clear();
    addLog('🗑️ 日志已清除');
    notifyListeners();
  }

  /// 加载开发者模式状态
  Future<void> _loadDeveloperMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDeveloperMode = prefs.getBool('developer_mode') ?? false;
      if (_isDeveloperMode) {
        print('🔧 [DeveloperMode] 从本地加载: 已启用');
        addLog('🔄 开发者模式状态已恢复');
      }
      notifyListeners();
    } catch (e) {
      print('❌ [DeveloperMode] 加载失败: $e');
    }
  }

  /// 保存开发者模式状态
  Future<void> _saveDeveloperMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('developer_mode', _isDeveloperMode);
      print('💾 [DeveloperMode] 状态已保存: $_isDeveloperMode');
    } catch (e) {
      print('❌ [DeveloperMode] 保存失败: $e');
    }
  }
}

