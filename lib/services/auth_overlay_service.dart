import 'dart:async';
import 'package:flutter/foundation.dart';

/// 桌面端认证覆盖层服务：用于在内容区域内显示/隐藏登录二级页面
class AuthOverlayService extends ChangeNotifier {
  static final AuthOverlayService _instance = AuthOverlayService._internal();
  factory AuthOverlayService() => _instance;
  AuthOverlayService._internal();

  bool _visible = false;
  int _initialTab = 0;
  Completer<bool?>? _completer;

  bool get isVisible => _visible;
  int get initialTab => _initialTab;

  Future<bool?> show({int initialTab = 0}) {
    // 如果已有可见覆盖层，复用当前的 Future
    if (_visible && _completer != null) {
      return _completer!.future;
    }

    _visible = true;
    _initialTab = initialTab;
    _completer = Completer<bool?>();
    notifyListeners();
    return _completer!.future;
  }

  void hide([bool? result]) {
    _visible = false;
    notifyListeners();
    if (_completer != null && !(_completer!.isCompleted)) {
      _completer!.complete(result);
    }
    _completer = null;
  }
}


