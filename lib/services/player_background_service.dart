import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 播放器背景类型
enum PlayerBackgroundType {
  adaptive,  // 自适应（基于封面提取颜色）
  solidColor, // 纯色背景
  image,      // 图片背景
}

/// 播放器背景设置服务
class PlayerBackgroundService extends ChangeNotifier {
  static final PlayerBackgroundService _instance = PlayerBackgroundService._internal();
  factory PlayerBackgroundService() => _instance;
  PlayerBackgroundService._internal();

  // SharedPreferences 键名
  static const String _keyBackgroundType = 'player_background_type';
  static const String _keySolidColor = 'player_background_solid_color';
  static const String _keyImagePath = 'player_background_image_path';
  static const String _keyBlurAmount = 'player_background_blur_amount';

  // 当前设置
  PlayerBackgroundType _backgroundType = PlayerBackgroundType.adaptive;
  Color _solidColor = Colors.grey[900]!;
  String? _imagePath;
  double _blurAmount = 10.0; // 默认模糊程度（sigma值）

  // Getters
  PlayerBackgroundType get backgroundType => _backgroundType;
  Color get solidColor => _solidColor;
  String? get imagePath => _imagePath;
  double get blurAmount => _blurAmount;
  bool get isAdaptive => _backgroundType == PlayerBackgroundType.adaptive;
  bool get isSolidColor => _backgroundType == PlayerBackgroundType.solidColor;
  bool get isImage => _backgroundType == PlayerBackgroundType.image;

  /// 初始化服务
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 读取背景类型
    final typeIndex = prefs.getInt(_keyBackgroundType) ?? 0;
    _backgroundType = PlayerBackgroundType.values[typeIndex];
    
    // 读取纯色
    final colorValue = prefs.getInt(_keySolidColor);
    if (colorValue != null) {
      _solidColor = Color(colorValue);
    }
    
    // 读取图片路径
    _imagePath = prefs.getString(_keyImagePath);
    
    // 读取模糊程度
    _blurAmount = prefs.getDouble(_keyBlurAmount) ?? 10.0;
    
    notifyListeners();
    print('🎨 [PlayerBackground] 已初始化: $_backgroundType, 模糊: $_blurAmount');
  }

  /// 设置背景类型
  Future<void> setBackgroundType(PlayerBackgroundType type) async {
    if (_backgroundType == type) return;
    
    _backgroundType = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBackgroundType, type.index);
    
    notifyListeners();
    print('🎨 [PlayerBackground] 背景类型已更改: $type');
  }

  /// 设置纯色背景
  Future<void> setSolidColor(Color color) async {
    if (_solidColor == color) return;
    
    _solidColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySolidColor, color.value);
    
    notifyListeners();
    print('🎨 [PlayerBackground] 纯色已更改: ${color.value.toRadixString(16)}');
  }

  /// 设置图片背景
  Future<void> setImageBackground(String imagePath) async {
    // 验证文件是否存在
    final file = File(imagePath);
    if (!await file.exists()) {
      print('❌ [PlayerBackground] 图片文件不存在: $imagePath');
      return;
    }
    
    _imagePath = imagePath;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyImagePath, imagePath);
    
    notifyListeners();
    print('🎨 [PlayerBackground] 图片背景已设置: $imagePath');
  }

  /// 设置模糊程度
  Future<void> setBlurAmount(double amount) async {
    if (_blurAmount == amount) return;
    
    _blurAmount = amount.clamp(0.0, 50.0); // 限制范围 0-50
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyBlurAmount, _blurAmount);
    
    notifyListeners();
    print('🎨 [PlayerBackground] 模糊程度已更改: $_blurAmount');
  }

  /// 清除图片背景
  Future<void> clearImageBackground() async {
    _imagePath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyImagePath);
    
    notifyListeners();
    print('🎨 [PlayerBackground] 图片背景已清除');
  }

  /// 获取背景类型的显示名称
  String getBackgroundTypeName() {
    switch (_backgroundType) {
      case PlayerBackgroundType.adaptive:
        return '自适应';
      case PlayerBackgroundType.solidColor:
        return '纯色背景';
      case PlayerBackgroundType.image:
        return '图片背景';
    }
  }

  /// 获取背景类型的描述
  String getBackgroundTypeDescription() {
    switch (_backgroundType) {
      case PlayerBackgroundType.adaptive:
        return '基于专辑封面提取颜色';
      case PlayerBackgroundType.solidColor:
        return '使用自定义纯色';
      case PlayerBackgroundType.image:
        return _imagePath != null ? '自定义图片' : '未设置图片';
    }
  }
}

