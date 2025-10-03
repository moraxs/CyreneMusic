# Android 媒体通知实现文档

## 📱 概述

Cyrene Music 现已支持 Android 平台的系统状态栏媒体通知控件。当你播放音乐时，会在通知栏显示带有播放控制按钮的媒体卡片。

## ✨ 功能特性

### 媒体通知功能
- 📝 **实时信息显示**
  - 歌曲标题
  - 艺术家名称
  - 专辑名称
  - 专辑封面图片

- 🎮 **播放控制按钮**
  - ⏮️ 上一首
  - ▶️ 播放 / ⏸️ 暂停
  - ⏭️ 下一首
  - ⏹️ 停止播放

- 🔄 **实时状态同步**
  - 播放状态自动更新
  - 进度条实时显示
  - 歌曲切换自动刷新

## 🛠️ 技术实现

### 核心组件

#### 1. `AudioHandlerService`
- 文件：`lib/services/audio_handler_service.dart`
- 功能：继承自 `BaseAudioHandler`，处理 Android 媒体通知的所有交互
- 职责：
  - 监听 `PlayerService` 状态变化
  - 更新媒体信息到系统通知
  - 处理通知栏按钮点击事件

#### 2. `SystemMediaService`
- 文件：`lib/services/system_media_service.dart`
- 功能：统一管理 Windows 和 Android 平台的系统媒体控件
- 职责：
  - Windows: 使用 SMTC (System Media Transport Controls)
  - Android: 使用 audio_service
  - 自动检测平台并初始化相应的服务

### 依赖包

```yaml
dependencies:
  audio_service: ^0.18.18
```

### Android 配置

#### AndroidManifest.xml 权限
```xml
<!-- 媒体通知所需权限 -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.INTERNET"/>

<!-- Android 13+ 通知权限（运行时权限）-->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- Android 14+ (SDK 34) 媒体播放前台服务权限 -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
```

**权限说明**：
- `FOREGROUND_SERVICE`: 允许应用运行前台服务
- `WAKE_LOCK`: 防止设备休眠
- `INTERNET`: 加载专辑封面
- `POST_NOTIFICATIONS`: **Android 13+ 运行时权限**，需要用户授权
- `FOREGROUND_SERVICE_MEDIA_PLAYBACK`: Android 14+ 必需

#### 服务声明
```xml
<!-- audio_service 媒体通知服务 -->
<service
    android:name="com.ryanheise.audioservice.AudioService"
    android:foregroundServiceType="mediaPlayback"
    android:exported="true">
    <intent-filter>
        <action android:name="android.media.browse.MediaBrowserService"/>
    </intent-filter>
</service>

<!-- 媒体按钮接收器 -->
<receiver
    android:name="com.ryanheise.audioservice.MediaButtonReceiver"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.MEDIA_BUTTON"/>
    </intent-filter>
</receiver>
```

## 🔄 工作流程

### 初始化流程

1. **应用启动** (`main.dart`)
   ```dart
   // Android 平台请求通知权限（Android 13+）
   if (Platform.isAndroid) {
     await PermissionService().requestNotificationPermission();
   }
   
   // 初始化系统媒体服务
   await SystemMediaService().initialize();
   ```

2. **平台检测** (`SystemMediaService`)
   - 检测到 Android 平台
   - 调用 `_initializeAndroid()`

3. **创建 AudioHandler**
   ```dart
   _audioHandler = await AudioService.init(
     builder: () => CyreneAudioHandler(),
     config: AudioServiceConfig(
       androidNotificationChannelId: 'com.cyrene.music.channel.audio',
       androidNotificationChannelName: 'Cyrene Music',
       androidNotificationOngoing: false,  // 必须配合 androidStopForegroundOnPause
       androidStopForegroundOnPause: false, // 避免 Android 12+ 重启问题
     ),
   );
   ```

4. **监听播放器状态**
   - `AudioHandler` 自动监听 `PlayerService`
   - 状态变化时自动更新通知

### 播放流程

1. **用户播放歌曲**
   ```dart
   await PlayerService().playTrack(track);
   ```

2. **PlayerService 状态更新**
   - 设置 `currentTrack` 和 `currentSong`
   - 调用 `notifyListeners()`

3. **AudioHandler 接收通知**
   - `_onPlayerStateChanged()` 被触发
   - 提取歌曲信息

4. **更新媒体通知**
   ```dart
   // 更新媒体项
   mediaItem.add(MediaItem(...));
   
   // 更新播放状态
   playbackState.add(PlaybackState(...));
   ```

5. **系统显示通知**
   - Android 系统接收 MediaItem
   - 在通知栏显示媒体卡片

### 按钮交互流程

1. **用户点击通知栏按钮**（如"暂停"）

2. **系统调用 AudioHandler 回调**
   ```dart
   @override
   Future<void> pause() async {
     await PlayerService().pause();
   }
   ```

3. **PlayerService 执行操作**
   - 暂停音频播放
   - 更新状态为 `paused`
   - 调用 `notifyListeners()`

4. **AudioHandler 更新通知**
   - 接收状态变化
   - 将"暂停"按钮改为"播放"按钮

## 🧪 测试步骤

### 1. 编译运行
```bash
flutter run -d <android-device>
```

### 2. 播放音乐
- 打开应用
- 搜索并播放一首歌曲

### 3. 检查通知栏
下拉通知栏，应该能看到：
- ✅ 歌曲标题和艺术家
- ✅ 专辑封面图片
- ✅ 播放控制按钮（上一首、暂停、下一首）
- ✅ 进度条

### 4. 测试按钮功能
- 点击"暂停"→ 音乐暂停，按钮变为"播放"
- 点击"播放"→ 音乐继续，按钮变为"暂停"
- 点击"下一首"→ 播放队列中的下一首歌
- 点击"上一首"→ 播放队列中的上一首歌

### 5. 测试后台播放
- 按 Home 键返回桌面
- 通知栏媒体控件仍然可用
- 可以在后台控制播放

## 📊 日志输出

### 初始化日志
```
✅ [SystemMediaService] Android audio_service 初始化成功
```

### 播放日志
```
🎵 [AudioHandler] 更新媒体信息: 歌曲名 - 艺术家
⏸️ [AudioHandler] 暂停按钮被点击
▶️ [AudioHandler] 播放按钮被点击
⏭️ [AudioHandler] 下一首按钮被点击
⏮️ [AudioHandler] 上一首按钮被点击
```

## 🔧 故障排除

### 问题 1: 通知不显示

**可能原因**:
- 未授予通知权限（Android 13+）
- AndroidManifest.xml 配置错误
- 缺少必要的权限声明

**解决方案**:

**方法 1：检查权限授予情况**
1. 打开设备设置 → 应用 → Cyrene Music → 通知
2. 确保"允许通知"已开启
3. 如果权限被拒绝，在应用中会自动弹出权限请求对话框

**方法 2：手动授予权限**
```bash
# 通过 adb 授予通知权限（Android 13+）
adb shell pm grant com.cyrene.music android.permission.POST_NOTIFICATIONS
```

**方法 3：检查 AndroidManifest.xml**
确认包含以下权限：
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
```

**方法 4：查看日志**
```bash
adb logcat | grep -i "PermissionService\|AudioHandler"
```
查看是否有权限相关的错误信息

### 问题 2: 按钮无响应

**可能原因**:
- AudioHandler 未正确初始化
- 回调方法未实现

**解决方案**:
1. 检查日志是否有初始化错误
2. 确认 `CyreneAudioHandler` 实现了所有回调
3. 重启应用

### 问题 3: 封面图片不显示

**可能原因**:
- 图片 URL 无效
- 网络权限未授予

**解决方案**:
1. 确认 `INTERNET` 权限已添加
2. 检查图片 URL 是否有效
3. 使用 HTTPS 协议的图片链接

### 问题 4: AudioServiceConfig 断言失败

**错误信息**:
```
This assertion failed with message: The androidNotificationOngoing will make no effect with androidStopForegroundOnPause set to false
```

**原因**:
- `androidNotificationOngoing` 和 `androidStopForegroundOnPause` 配置冲突
- 根据 [audio_service 文档](https://pub.dev/documentation/audio_service/latest/)，这两个参数必须满足：
  - 如果 `androidStopForegroundOnPause = false`，则 `androidNotificationOngoing` 必须也为 `false`
  - 如果 `androidNotificationOngoing = true`，则 `androidStopForegroundOnPause` 必须也为 `true`

**解决方案**:
使用正确的配置组合：
```dart
config: const AudioServiceConfig(
  androidNotificationOngoing: false,      // ✅ 正确
  androidStopForegroundOnPause: false,    // ✅ 正确
),
```

或者：
```dart
config: const AudioServiceConfig(
  androidNotificationOngoing: true,       // ✅ 正确
  androidStopForegroundOnPause: true,     // ✅ 正确（默认行为）
),
```

**推荐配置**（避免 Android 12+ 重启问题）：
```dart
androidNotificationOngoing: false,
androidStopForegroundOnPause: false,
```

## 🎯 最佳实践

1. **始终提供完整的媒体信息**
   - 标题、艺术家、专辑都应该提供
   - 使用高质量的封面图片

2. **及时更新状态**
   - 播放状态变化时立即更新
   - 避免通知信息与实际状态不一致

3. **处理所有按钮事件**
   - 实现所有必要的控制按钮回调
   - 提供友好的用户体验

4. **资源管理**
   - 应用关闭时正确清理 AudioHandler
   - 避免内存泄漏

## 📝 版本历史

- **v1.3.3** (2025-10-03)
  - ✅ 首次实现 Android 媒体通知功能
  - ✅ 支持播放控制（播放/暂停/上一首/下一首）
  - ✅ 实时显示歌曲信息和封面
  - ✅ 后台播放支持

## 🔍 调试指南

如果通知栏没有显示播放器控件，请查看：
- **[Android 媒体通知调试指南](ANDROID_NOTIFICATION_DEBUG.md)** - 详细的问题诊断和解决方案

## 🔗 相关链接

- [audio_service 官方文档](https://pub.dev/packages/audio_service)
- [Android MediaSession 指南](https://developer.android.com/guide/topics/media-apps/audio-app/building-a-mediasession)
- [Flutter 音频播放最佳实践](https://flutter.dev/docs/cookbook/plugins/play-video)
- [调试指南](ANDROID_NOTIFICATION_DEBUG.md) - 问题排查步骤

---

**实现日期**: 2025-10-03  
**实现版本**: v1.3.3  
**平台支持**: Android  
**状态**: ✅ 已完成并测试

