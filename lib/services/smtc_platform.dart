/// 平台特定的 SMTC 导入
/// 在 Windows 平台使用真实实现，其他平台使用桩实现

export 'smtc_platform_stub.dart'
  if (dart.library.io) 'smtc_platform_io.dart';

