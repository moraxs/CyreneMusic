import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 播放模式枚举
enum PlaybackMode {
  /// 顺序播放
  sequential,
  /// 单曲循环
  repeatOne,
  /// 随机播放
  shuffle,
}

/// 播放模式服务
class PlaybackModeService extends ChangeNotifier {
  static final PlaybackModeService _instance = PlaybackModeService._internal();
  factory PlaybackModeService() => _instance;
  PlaybackModeService._internal() {
    _loadMode();
  }

  PlaybackMode _currentMode = PlaybackMode.sequential;
  PlaybackMode get currentMode => _currentMode;

  static const String _modeKey = 'playback_mode';

  /// 加载播放模式
  Future<void> _loadMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeIndex = prefs.getInt(_modeKey) ?? 0;
      _currentMode = PlaybackMode.values[modeIndex];
      print('🔄 [PlaybackModeService] 加载播放模式: ${_currentMode.name}');
    } catch (e) {
      print('❌ [PlaybackModeService] 加载播放模式失败: $e');
      _currentMode = PlaybackMode.sequential;
    }
  }

  /// 切换到下一个播放模式
  Future<void> toggleMode() async {
    final currentIndex = _currentMode.index;
    final nextIndex = (currentIndex + 1) % PlaybackMode.values.length;
    _currentMode = PlaybackMode.values[nextIndex];
    
    await _saveMode();
    notifyListeners();
    
    print('🔄 [PlaybackModeService] 切换播放模式: ${_currentMode.name}');
  }

  /// 设置播放模式
  Future<void> setMode(PlaybackMode mode) async {
    if (_currentMode == mode) return;
    
    _currentMode = mode;
    await _saveMode();
    notifyListeners();
    
    print('🔄 [PlaybackModeService] 设置播放模式: ${_currentMode.name}');
  }

  /// 保存播放模式
  Future<void> _saveMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_modeKey, _currentMode.index);
    } catch (e) {
      print('❌ [PlaybackModeService] 保存播放模式失败: $e');
    }
  }

  /// 获取播放模式图标
  String getModeIcon() {
    switch (_currentMode) {
      case PlaybackMode.sequential:
        return '🔁'; // 或使用 Icons.repeat
      case PlaybackMode.repeatOne:
        return '🔂'; // 或使用 Icons.repeat_one
      case PlaybackMode.shuffle:
        return '🔀'; // 或使用 Icons.shuffle
    }
  }

  /// 获取播放模式名称
  String getModeName() {
    switch (_currentMode) {
      case PlaybackMode.sequential:
        return '顺序播放';
      case PlaybackMode.repeatOne:
        return '单曲循环';
      case PlaybackMode.shuffle:
        return '随机播放';
    }
  }
}

