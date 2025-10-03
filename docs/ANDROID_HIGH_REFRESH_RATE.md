# Android 高刷新率优化

## 📱 功能概述

使用 [flutter_displaymode](https://pub.dev/packages/flutter_displaymode) 插件在 Android 平台启用高刷新率，提升应用流畅度。

### 适用设备

✅ **支持的设备**：
- 支持 90Hz、120Hz、144Hz 等高刷新率的 Android 设备
- 例如：OnePlus 7 Pro/8 Pro、Samsung Galaxy S20+、小米、OPPO 等

❌ **不支持的设备**：
- LTPO 面板设备（已自动适配高刷新率）
- iOS 设备（ProMotion 已内置支持）
- 低端设备（仅支持 60Hz）

## 🚀 实现方式

### 1. 依赖添加

**`pubspec.yaml`**：
```yaml
dependencies:
  # High refresh rate support for Android
  flutter_displaymode: ^0.7.0
```

### 2. 平台检测与初始化

**`lib/main.dart`**：
```dart
// 条件导入（仅 Android）
import 'package:flutter_displaymode/flutter_displaymode.dart' if (dart.library.html) '';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ... 其他初始化 ...
  
  // Android 平台启用高刷新率
  if (Platform.isAndroid) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
      final activeMode = await FlutterDisplayMode.active;
      print('🎨 已启用高刷新率: ${activeMode.refreshRate.toStringAsFixed(0)}Hz');
    } catch (e) {
      print('⚠️ 设置高刷新率失败: $e');
    }
  }
  
  runApp(const MyApp());
}
```

### 3. 工作原理

```
应用启动
  ↓
检测平台（Platform.isAndroid）
  ↓
调用 FlutterDisplayMode.setHighRefreshRate()
  ↓
系统选择最高刷新率（保持当前分辨率）
  ↓
应用以高刷新率运行 ✅
```

**示例**：
```dart
// 设备支持的模式
#0 0x0 @0Hz        // 自动模式
#1 1080x2340 @60Hz
#2 1080x2340 @90Hz  ← 自动选择此模式
#3 1440x3120 @90Hz
#4 1440x3120 @60Hz

// 调用后
当前模式：1080x2340 @90Hz ✅
```

## 📊 效果对比

### 视觉流畅度

| 刷新率 | 帧时间 | 流畅度 | 用户体验 |
|--------|--------|--------|----------|
| 60Hz | ~16.7ms | 基准 | 一般 |
| 90Hz | ~11.1ms | +50% | 流畅 ✅ |
| 120Hz | ~8.3ms | +100% | 非常流畅 ✅✅ |

### 应用场景

**最明显的改进**：
- ✅ 滚动歌曲列表
- ✅ 滑动切换页面
- ✅ 歌词滚动
- ✅ 专辑封面动画
- ✅ 播放器页面过渡

**不明显的场景**：
- ❌ 静态内容展示
- ❌ 视频播放（由视频帧率决定）
- ❌ 纯文字阅读

## 🔧 技术细节

### API 使用

#### 1. 获取支持的模式

```dart
final modes = await FlutterDisplayMode.supported;
modes.forEach(print);

// 输出示例（OnePlus 8 Pro）：
// #0 0x0 @0Hz        // 自动模式
// #1 1080x2376 @60Hz
// #2 1440x3168 @120Hz
// #3 1440x3168 @60Hz
// #4 1080x2376 @120Hz
```

#### 2. 获取当前激活的模式

```dart
final activeMode = await FlutterDisplayMode.active;
print('当前: ${activeMode.width}x${activeMode.height} @${activeMode.refreshRate}Hz');
```

#### 3. 设置首选模式

```dart
// 方式 1: 使用辅助函数（推荐）
await FlutterDisplayMode.setHighRefreshRate();  // 最高刷新率
await FlutterDisplayMode.setLowRefreshRate();   // 最低刷新率（省电）

// 方式 2: 手动设置
final modes = await FlutterDisplayMode.supported;
await FlutterDisplayMode.setPreferredMode(modes[2]);  // 设置特定模式
```

#### 4. 获取首选模式

```dart
final preferredMode = await FlutterDisplayMode.preferred;
print('首选: ${preferredMode.refreshRate}Hz');
```

### 异常处理

```dart
try {
  await FlutterDisplayMode.setHighRefreshRate();
} on PlatformException catch (e) {
  if (e.code == 'noAPI') {
    // Android 6.0 (Marshmallow) 以下不支持
    print('设备不支持刷新率 API');
  } else if (e.code == 'noActivity') {
    // 应用在后台，无法设置
    print('应用不在前台');
  }
}
```

### 系统行为

**重要提示**：
- 🔄 设置的是**首选模式**，系统可能根据内部启发式算法不切换
- 🔄 最终使用的模式可能与首选模式不同
- ⏱️ 设置是**每会话**的，重启应用需要重新设置

**验证实际模式**：
```dart
// 设置后验证
await FlutterDisplayMode.setHighRefreshRate();
final active = await FlutterDisplayMode.active;
final preferred = await FlutterDisplayMode.preferred;

if (active.refreshRate == preferred.refreshRate) {
  print('✅ 系统已应用高刷新率');
} else {
  print('⚠️ 系统未应用（可能由电池策略决定）');
}
```

## ⚡ 性能影响

### 电池消耗

| 刷新率 | 相对功耗 | 续航影响 |
|--------|----------|----------|
| 60Hz | 基准 (100%) | 0% |
| 90Hz | +10-15% | -10-15% |
| 120Hz | +20-30% | -20-30% |

**建议**：
- 用户可在设置中手动切换（未来功能）
- 充电时自动启用高刷新率
- 低电量时自动降低刷新率

### CPU/GPU 负载

```
60Hz  → 每秒最多 60 帧 → 基准负载
90Hz  → 每秒最多 90 帧 → +50% 负载
120Hz → 每秒最多 120 帧 → +100% 负载
```

**优化措施**：
- Flutter 框架会自动适配刷新率
- 只有实际变化时才重绘
- 静态内容不会增加负载

## 🎯 日志输出

### 成功启用

```
🚀 应用启动
📱 平台: android
🌐 URL 服务已初始化
💾 缓存服务已初始化
🎵 播放器服务已初始化
✅ 通知权限已授予
🎨 [DisplayMode] 已启用高刷新率: 90Hz  ← 成功
🎨 显示模式: 1080x2340 @90Hz
🎛️ 系统媒体服务已初始化
```

### 设备不支持

```
⚠️ [DisplayMode] 设置高刷新率失败: PlatformException(noAPI, ...)
⚠️ 高刷新率设置失败: PlatformException(noAPI, No API support)
```

### 应用在后台

```
⚠️ [DisplayMode] 设置高刷新率失败: PlatformException(noActivity, ...)
⚠️ 高刷新率设置失败: Activity is not available
```

## 📱 支持的设备示例

### 高端设备（120Hz+）

- **OnePlus**：8 Pro, 9 Pro, 10 Pro, 11
- **Samsung**：Galaxy S20+/Ultra, S21+/Ultra, S22+/Ultra, S23+/Ultra
- **小米**：Mi 10/11/12/13 系列
- **OPPO**：Find X2/X3/X5 系列
- **Realme**：GT 系列
- **ROG Phone**：3/5/6/7

### 中端设备（90Hz）

- **OnePlus**：7 Pro, Nord 系列
- **小米**：Redmi K30/K40 系列
- **Realme**：X50 系列
- **OPPO**：Reno 系列

### 不支持设备（60Hz）

- 2019 年之前的大部分设备
- 低端/入门级设备
- 部分老旧旗舰

## 🔍 调试验证

### 开发者选项验证

1. 打开 Android **开发者选项**
2. 启用 **显示刷新率**
3. 运行应用
4. 查看屏幕角落的刷新率指示器

**期望结果**：
```
应用启动前：60Hz
应用启动后：90Hz 或 120Hz ✅
```

### Logcat 验证

```bash
# 查看 DisplayMode 日志
adb logcat | grep "DisplayMode"

# 输出示例
I/flutter (12345): 🎨 [DisplayMode] 已启用高刷新率: 90Hz
```

### 代码验证

```dart
// 在应用中添加调试信息
class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _checkDisplayMode();
  }
  
  Future<void> _checkDisplayMode() async {
    if (Platform.isAndroid) {
      final active = await FlutterDisplayMode.active;
      final supported = await FlutterDisplayMode.supported;
      
      print('🎨 当前模式: ${active.refreshRate}Hz');
      print('🎨 支持的模式:');
      for (final mode in supported) {
        print('  ${mode.width}x${mode.height} @${mode.refreshRate}Hz');
      }
    }
  }
}
```

## 🚧 已知限制

### 1. 系统限制

- ⚠️ Android 6.0 (Marshmallow) 以下不支持
- ⚠️ 某些设备制造商可能锁定刷新率
- ⚠️ 省电模式下系统可能强制降低刷新率

### 2. 应用限制

- ⚠️ 设置是每会话的（重启应用需重新设置）
- ⚠️ 应用在后台时无法设置
- ⚠️ 系统可能根据电量、温度等因素覆盖设置

### 3. Flutter 限制

- ⚠️ 需要 Flutter 框架支持高刷新率渲染
- ⚠️ 部分动画需要适配高刷新率
- ⚠️ 复杂 UI 可能无法达到满帧

## 🎛️ 未来优化方向

### 1. 用户可配置

```dart
// 添加设置选项
设置 → 显示 → 刷新率
  ○ 自动（跟随系统）
  ○ 60Hz（省电）
  ● 90Hz（平衡）
  ○ 120Hz（流畅）
```

### 2. 智能切换

```dart
// 根据场景自动调整
if (batteryLevel < 20%) {
  FlutterDisplayMode.setLowRefreshRate();  // 省电
} else if (isCharging) {
  FlutterDisplayMode.setHighRefreshRate(); // 流畅
}
```

### 3. 性能监控

```dart
// 监控帧率
final fps = await FlutterDisplayMode.active.refreshRate;
if (actualFPS < fps * 0.8) {
  // 降低刷新率以保持流畅
  FlutterDisplayMode.setLowRefreshRate();
}
```

## 📝 相关资源

### 官方文档
- [flutter_displaymode - pub.dev](https://pub.dev/packages/flutter_displaymode)
- [Flutter Issue #35162](https://github.com/flutter/flutter/issues/35162)

### 测试设备
- 建议在多款设备上测试
- 包括 60Hz、90Hz、120Hz 设备
- 验证电池影响

### 性能分析
- 使用 Flutter DevTools 监控帧率
- 使用 Android Profiler 监控电量

## ✅ 总结

### 优势
✅ 显著提升视觉流畅度  
✅ 改善用户体验  
✅ 简单易用的 API  
✅ 仅在 Android 平台启用（不影响其他平台）

### 劣势
❌ 增加电池消耗（10-30%）  
❌ 不是所有设备都支持  
❌ 需要每次启动时设置

### 建议
- ✅ 保持当前实现（默认启用高刷新率）
- 🔜 未来添加用户设置选项
- 🔜 根据电量智能切换

---

**实施日期**：2025-10-03  
**相关文件**：  
- `lib/main.dart`  
- `pubspec.yaml`  

**状态**：✅ 已实施并测试

