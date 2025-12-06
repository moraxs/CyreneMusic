import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:cyrene_music/services/developer_mode_service.dart';

/// 用于确保应用只有一个进程在运行
class SingletonService {
  static final SingletonService _instance = SingletonService._internal();
  factory SingletonService() => _instance;
  
  SingletonService._internal();
  
  File? _lockFile;
  RandomAccessFile? _lock;
  bool _isLocked = false;
  
  /// init single
  Future<bool> initialize() async {
    try {
      // 获取应用文档目录
      final directory = await getApplicationSupportDirectory();
      _lockFile = File('${directory.path}/cyrene_music.lock');
      
      DeveloperModeService().addLog('🔒 初始化单进程服务，锁文件路径: ${_lockFile?.path}');
      
      // 尝试打开锁文件
      _lock = await _lockFile!.open(mode: FileMode.write);
      
      // 尝试获取独占锁
      await _lock!.lock(FileLock.exclusive);
      
      _isLocked = true;
      DeveloperModeService().addLog('✅ 成功获取文件锁，当前是唯一进程');
      
      // 注册退出回调，确保锁被释放
      ProcessSignal.sigint.watch().listen((signal) {
        _releaseLock();
      });
      
      ProcessSignal.sigterm.watch().listen((signal) {
        _releaseLock();
      });
      
      return true;
    } catch (e) {
      // 如果获取锁失败，说明已有进程在运行
      DeveloperModeService().addLog('⚠️ 获取文件锁失败，已有进程在运行: $e');
      _releaseLock();
      return false;
    }
  }
  
  /// 释放锁
  void _releaseLock() {
    if (_isLocked && _lock != null) {
      try {
        _lock!.unlock();
        _lock!.close();
        _isLocked = false;
        DeveloperModeService().addLog('🔓 已释放文件锁');
      } catch (e) {
        DeveloperModeService().addLog('⚠️ 释放文件锁失败: $e');
      }
    }
  }
  
  /// 关闭服务
  void dispose() {
    _releaseLock();
  }
}