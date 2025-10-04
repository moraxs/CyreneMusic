/// SMTC 真实实现（IO 平台：Windows/Linux/macOS/Android/iOS）
/// 当 smtc_windows 依赖存在时，直接导出
/// 当 smtc_windows 不存在时，使用桩实现

// 尝试导入真实实现，如果失败则使用桩实现
export 'package:smtc_windows/smtc_windows.dart';

