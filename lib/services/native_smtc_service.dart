import 'dart:async';
import 'package:flutter/services.dart';

/// 原生SMTC服务（Windows平台）
/// 通过C++层的Windows Runtime API实现系统媒体控件
class NativeSmtcService {
  static final NativeSmtcService _instance = NativeSmtcService._internal();
  factory NativeSmtcService() => _instance;
  NativeSmtcService._internal();

  static const MethodChannel _channel = MethodChannel('com.cyrene.music/smtc');
  
  // 按钮事件流控制器
  final StreamController<SmtcButton> _buttonController = 
      StreamController<SmtcButton>.broadcast();
  
  Stream<SmtcButton> get buttonPressStream => _buttonController.stream;
  
  bool _initialized = false;

  /// 初始化SMTC
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 设置Method Channel回调处理器
      _channel.setMethodCallHandler(_handleMethodCall);
      
      // 调用C++层初始化
      await _channel.invokeMethod('initialize');
      
      _initialized = true;
      print('✅ [NativeSmtc] 初始化成功');
    } catch (e) {
      print('❌ [NativeSmtc] 初始化失败: $e');
      rethrow;
    }
  }

  /// 启用SMTC
  Future<void> enable() async {
    try {
      await _channel.invokeMethod('enable');
      print('✅ [NativeSmtc] 已启用');
    } catch (e) {
      print('❌ [NativeSmtc] 启用失败: $e');
    }
  }

  /// 禁用SMTC
  Future<void> disable() async {
    try {
      await _channel.invokeMethod('disable');
      print('⏹️ [NativeSmtc] 已禁用');
    } catch (e) {
      print('❌ [NativeSmtc] 禁用失败: $e');
    }
  }

  /// 更新元数据
  Future<void> updateMetadata({
    required String title,
    required String artist,
    required String album,
    String? thumbnail,
  }) async {
    try {
      await _channel.invokeMethod('updateMetadata', {
        'title': title,
        'artist': artist,
        'album': album,
        'thumbnail': thumbnail ?? '',
      });
      print('✅ [NativeSmtc] 元数据已更新: $title - $artist');
    } catch (e) {
      print('❌ [NativeSmtc] 更新元数据失败: $e');
    }
  }

  /// 更新播放状态
  Future<void> updatePlaybackStatus(SmtcPlaybackStatus status) async {
    try {
      await _channel.invokeMethod('updatePlaybackStatus', status.value);
      print('✅ [NativeSmtc] 状态已更新: ${status.value}');
    } catch (e) {
      print('❌ [NativeSmtc] 更新状态失败: $e');
    }
  }

  /// 更新时间线（进度）
  Future<void> updateTimeline({
    required int startTimeMs,
    required int endTimeMs,
    required int positionMs,
    required int minSeekTimeMs,
    required int maxSeekTimeMs,
  }) async {
    try {
      await _channel.invokeMethod('updateTimeline', {
        'startTimeMs': startTimeMs,
        'endTimeMs': endTimeMs,
        'positionMs': positionMs,
        'minSeekTimeMs': minSeekTimeMs,
        'maxSeekTimeMs': maxSeekTimeMs,
      });
    } catch (e) {
      print('❌ [NativeSmtc] 更新时间线失败: $e');
    }
  }

  /// 处理C++层的回调
  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onButtonPressed') {
      final args = call.arguments as Map;
      final buttonName = args['button'] as String;
      
      final button = _parseButton(buttonName);
      if (button != null) {
        _buttonController.add(button);
      }
    }
  }

  /// 解析按钮名称
  SmtcButton? _parseButton(String buttonName) {
    switch (buttonName) {
      case 'play':
        return SmtcButton.play;
      case 'pause':
        return SmtcButton.pause;
      case 'stop':
        return SmtcButton.stop;
      case 'next':
        return SmtcButton.next;
      case 'previous':
        return SmtcButton.previous;
      case 'fastForward':
        return SmtcButton.fastForward;
      case 'rewind':
        return SmtcButton.rewind;
      default:
        return null;
    }
  }

  /// 释放资源
  void dispose() {
    _buttonController.close();
  }
}

/// SMTC按钮枚举
enum SmtcButton {
  play,
  pause,
  stop,
  next,
  previous,
  fastForward,
  rewind,
}

/// SMTC播放状态
enum SmtcPlaybackStatus {
  closed('closed'),
  changing('changing'),
  stopped('stopped'),
  playing('playing'),
  paused('paused');

  final String value;
  const SmtcPlaybackStatus(this.value);
}

