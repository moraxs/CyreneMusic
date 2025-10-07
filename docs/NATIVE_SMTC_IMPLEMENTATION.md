# Windows 原生 SMTC 实现

## 概述

本项目已将 Windows 系统媒体传输控制 (SMTC) 从 Dart 插件 `smtc_windows` 迁移到原生 C++ 实现，使用 Windows Runtime (WinRT) API。

## 架构

### 跨平台策略

- **Windows**: 使用原生 C++ 实现（WinRT API）
- **Android**: 使用 `audio_service` 包
- **其他平台**: 暂无系统媒体控制支持

### 文件结构

```
windows/runner/
├── smtc_plugin.h          # SMTC 插件头文件
├── smtc_plugin.cpp        # SMTC 插件实现
└── CMakeLists.txt         # 构建配置（已添加 windowsapp.lib）

lib/services/
├── native_smtc_service.dart      # Dart 侧 SMTC 服务
└── system_media_service.dart     # 统一的系统媒体服务
```

## 技术实现

### C++ 层

使用 Windows Runtime (C++/WinRT) 提供的系统 API：

```cpp
#include <winrt/Windows.Media.h>
#include <winrt/Windows.Media.Playback.h>
```

**核心技术：通过 MediaPlayer 访问 SMTC**

在非 UWP 应用中，不能直接调用 `SystemMediaTransportControls::GetForCurrentView()`，因为它需要有效的 UWP Window 句柄。解决方案是通过创建 `MediaPlayer` 对象来间接访问 SMTC：

```cpp
// 创建 MediaPlayer 实例
media_player_ = winrt::Windows::Media::Playback::MediaPlayer();

// 禁用 MediaPlayer 的自动命令管理器
media_player_.CommandManager().IsEnabled(false);

// 通过 MediaPlayer 获取 SMTC 控制器
smtc_ = media_player_.SystemMediaTransportControls();
```

这个方法利用了 `MediaPlayer` 内部通过 COM 组件创建 SMTC 的机制，绕过了 UWP 平台限制。

**参考资料：** [.NET App 与Windows系统媒体控制(SMTC)交互 - TwilightLemon](https://www.cnblogs.com/TwilightLemon/p/18279496)

**核心功能：**
1. 系统媒体控件初始化和配置
2. 元数据更新（标题、艺术家、专辑、封面）
3. 播放状态控制（播放/暂停/停止）
4. 时间线（进度）更新
5. 按钮事件监听和回调

### Dart 层

通过 Method Channel 与 C++ 层通信：

**Method Channel**: `com.cyrene.music/smtc`

**支持的方法：**
- `initialize()` - 初始化 SMTC
- `enable()` - 启用媒体控制
- `disable()` - 禁用媒体控制
- `updateMetadata(metadata)` - 更新歌曲元数据
- `updatePlaybackStatus(status)` - 更新播放状态
- `updateTimeline(timeline)` - 更新播放进度

**事件回调：**
- `onButtonPressed` - 用户按下媒体控制按钮时触发

## 优势

### 相比 Dart 插件的优点

1. ✅ **更深度的系统集成** - 直接使用 Windows Runtime API
2. ✅ **避免依赖问题** - 不依赖第三方 Dart 包
3. ✅ **更好的性能** - 原生 C++ 实现，无额外封装层
4. ✅ **更强的控制力** - 可以自定义任何细节
5. ✅ **跨平台兼容** - 其他平台使用不同方案，互不干扰

### 编译要求

- **Windows 10 SDK** (17134 或更高版本)
- **C++17** 支持
- **C++/WinRT** 支持（通过 `/await` 编译选项）

## 使用示例

### Dart 侧调用

```dart
// 初始化
final smtc = NativeSmtcService();
await smtc.initialize();

// 更新元数据
await smtc.updateMetadata(
  title: '歌曲名',
  artist: '艺术家',
  album: '专辑',
  thumbnail: 'https://example.com/cover.jpg',
);

// 更新播放状态
await smtc.updatePlaybackStatus(SmtcPlaybackStatus.playing);

// 监听按钮事件
smtc.buttonPressStream.listen((button) {
  switch (button) {
    case SmtcButton.play:
      // 处理播放
      break;
    case SmtcButton.pause:
      // 处理暂停
      break;
    // ...
  }
});
```

## 构建说明

### 首次构建

1. 确保已安装 Windows 10 SDK
2. 运行 `flutter clean`
3. 运行 `flutter pub get` 移除旧的 `smtc_windows` 依赖
4. 运行 `flutter build windows`

### 依赖项

**已移除：**
- `smtc_windows: ^1.0.0`

**保留：**
- `audio_service: ^0.18.12` (仅用于 Android)

## 调试

### C++ 日志

C++ 层通过 `std::cout` 输出日志，可以在 Flutter 运行时看到：

```
[SMTC] 插件已创建
[SMTC] ✅ 初始化成功
[SMTC] ✅ 元数据已更新
[SMTC] ▶️ 播放按钮
```

### Dart 日志

Dart 层通过 `print()` 输出日志：

```
✅ [NativeSmtc] 初始化成功
✅ [NativeSmtc] 元数据已更新: 歌曲名 - 艺术家
✅ [SystemMediaService] 状态改变: playing -> playing
```

## 已知问题

### 1. 应用来源显示问题

由于不是正统的 UWP 应用，Windows 可能无法正确显示应用来源信息。在系统媒体控制面板中，可能只显示 "cyrene_music.exe" 而不是应用的友好名称。

### 2. 无法点击跳转到应用

正统 UWP 应用的 SMTC 会话支持点击跳转到应用播放界面，但通过 MediaPlayer 方式创建的 SMTC 目前不支持此功能。

### 3. Windows 多媒体键盘支持

✅ 蓝牙耳机、外接键盘的媒体键可以正常工作，SMTC 会自动处理这些输入。

### 4. 封面图片加载

- 必须使用 HTTPS URL（HTTP 会加载失败）
- 支持的格式：JPG、PNG
- 建议尺寸：300x300 或更大
- 加载失败不会影响其他元数据显示

## 迁移指南

如果从旧的 `smtc_windows` 插件迁移：

1. ✅ 删除 `smtc_platform*.dart` 文件
2. ✅ 更新 `pubspec.yaml` 移除 `smtc_windows` 依赖
3. ✅ 更新 `system_media_service.dart` 使用新的 `NativeSmtcService`
4. ✅ 更新 `main.dart` 移除旧的 SMTC 初始化代码
5. ✅ 运行 `flutter pub get` 和 `flutter clean`

## 参考资料

- [Windows Runtime C++ API](https://docs.microsoft.com/en-us/uwp/api/windows.media.systemmediatransportcontrols)
- [System Media Transport Controls Overview](https://docs.microsoft.com/en-us/windows/uwp/audio-video-camera/system-media-transport-controls)
- [C++/WinRT Introduction](https://docs.microsoft.com/en-us/windows/uwp/cpp-and-winrt-apis/)

## 作者

实现日期：2025-10-07
版本：1.0.0

