import 'package:flutter/foundation.dart';

/// 页面可见性通知器
class PageVisibilityNotifier extends ChangeNotifier {
  static final PageVisibilityNotifier _instance = PageVisibilityNotifier._internal();
  factory PageVisibilityNotifier() => _instance;
  PageVisibilityNotifier._internal();

  int _currentPageIndex = 0;
  int get currentPageIndex => _currentPageIndex;

  /// 设置当前页面索引
  void setCurrentPage(int index) {
    if (_currentPageIndex != index) {
      _currentPageIndex = index;
      notifyListeners();
    }
  }

  /// 是否是首页
  bool get isHomePage => _currentPageIndex == 0;
}

