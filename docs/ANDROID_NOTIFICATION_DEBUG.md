# Android 媒体通知调试指南

## 🔍 问题诊断步骤

如果即使授予了通知权限，通知栏仍然没有显示播放器控件，请按照以下步骤进行诊断。

### 步骤 1: 查看应用日志

```bash
# 连接 Android 设备后执行
adb logcat | grep -E "AudioHandler|SystemMediaService|PermissionService"
```

### 预期看到的日志输出

#### 1. 应用启动时

```
✅ [PermissionService] 通知权限已授予
📱 [SystemMediaService] 开始初始化 Android audio_service...
🎵 [AudioHandler] 开始初始化...
✅ [AudioHandler] 初始播放状态已设置
✅ [AudioHandler] 初始化完成
✅ [SystemMediaService] Android audio_service 初始化成功
   AudioHandler 类型: CyreneAudioHandler
   通知渠道 ID: com.cyrene.music.channel.audio
```

**✅ 如果看到以上日志，说明服务初始化成功**

#### 2. 播放歌曲时

```
🔔 [AudioHandler] 播放器状态变化
   状态: loading
   歌曲: 歌曲名称
🎮 [AudioHandler] 更新播放状态:
   播放中: false
   处理状态: loading
   位置: 0s / 0s
   控制按钮: 4 个
✅ [AudioHandler] 播放状态已更新到通知
📝 [AudioHandler] 更新媒体信息:
   标题: 歌曲名称
   艺术家: 艺术家名称
   专辑: 专辑名称
   封面: 有
✅ [AudioHandler] 媒体信息已更新到通知
```

**✅ 如果看到以上日志，说明状态更新正常**

### 步骤 2: 检查权限

```bash
# 检查通知权限
adb shell dumpsys notification | grep "com.cyrene.music"

# 手动授予权限（如果被拒绝）
adb shell pm grant com.cyrene.music android.permission.POST_NOTIFICATIONS
```

### 步骤 3: 检查通知渠道

```bash
# 查看通知渠道配置
adb shell dumpsys notification | grep -A 10 "com.cyrene.music.channel.audio"
```

应该看到类似输出：
```
Channel{
  id=com.cyrene.music.channel.audio
  name=Cyrene Music
  importance=DEFAULT
  ...
}
```

### 步骤 4: 强制显示通知

通过 adb 测试通知系统：

```bash
# 发送测试通知
adb shell am start-foreground-service \
  -n com.cyrene.music/.MainActivity \
  -a android.media.browse.MediaBrowserService
```

## 🐛 常见问题排查

### 问题 1: 日志中没有 AudioHandler 初始化信息

**症状**:
```
✅ [PermissionService] 通知权限已授予
✅ [SystemMediaService] 系统媒体控件初始化完成
```
但没有看到 `AudioHandler` 相关日志。

**原因**: AudioService.init() 可能失败了

**解决方案**:
1. 检查 AndroidManifest.xml 配置是否正确
2. 重新安装应用（彻底卸载后重装）
3. 查看完整日志：`adb logcat`

### 问题 2: 初始化成功但播放时无日志

**症状**:
```
✅ [AudioHandler] 初始化完成
```
但播放歌曲时没有 `🔔 [AudioHandler] 播放器状态变化` 日志。

**原因**: AudioHandler 没有监听到 PlayerService 的状态变化

**解决方案**:
1. 确认 PlayerService 是否调用了 `notifyListeners()`
2. 检查是否有异常阻止了监听器执行

### 问题 3: 状态更新日志正常但通知不显示

**症状**: 所有日志都正常，但通知栏仍无显示

**可能原因**:
1. Android 系统杀掉了前台服务
2. 通知被系统屏蔽
3. 设备的省电模式限制了通知

**解决方案**:

#### 方案 A: 关闭省电优化
```bash
# 检查省电优化状态
adb shell dumpsys deviceidle whitelist | grep cyrene

# 禁用省电优化（需要用户手动操作）
```
在设置 → 应用 → Cyrene Music → 电池 → 不限制

#### 方案 B: 检查通知显示设置
设置 → 应用 → Cyrene Music → 通知 → 确保：
- 允许通知：开启
- 媒体播放：开启（如果有此选项）
- 锁屏显示：开启

#### 方案 C: 重启设备
有时候 Android 系统的通知服务需要重启才能正常工作

### 问题 4: 通知一闪而过

**症状**: 通知短暂出现后立即消失

**原因**: `androidStopForegroundOnPause` 配置问题

**解决方案**:
确认配置为：
```dart
androidStopForegroundOnPause: false,
```

## 🧪 完整测试流程

### 1. 清理环境
```bash
# 卸载应用
adb uninstall com.cyrene.music

# 清理日志缓冲区
adb logcat -c
```

### 2. 重新安装并启动
```bash
# 安装应用
flutter install

# 实时查看日志
adb logcat | grep -E "AudioHandler|SystemMediaService|PermissionService"
```

### 3. 测试步骤

1. **启动应用**
   - 预期：看到初始化日志
   - 预期：自动请求通知权限

2. **授予权限**
   - 点击"允许"
   - 预期：看到权限授予日志

3. **播放歌曲**
   - 搜索并播放一首歌
   - 预期：看到状态更新日志
   - 预期：通知栏显示媒体控件

4. **测试控制按钮**
   - 点击通知栏的暂停按钮
   - 预期：歌曲暂停
   - 预期：看到 `⏸️ [AudioHandler] 暂停按钮被点击` 日志

5. **锁屏测试**
   - 锁定屏幕
   - 预期：锁屏界面显示媒体控件
   - 预期：可以控制播放

## 📊 日志分析工具

### 过滤关键日志
```bash
# 只看错误
adb logcat | grep -E "❌|Error|Exception"

# 只看 AudioHandler
adb logcat | grep "AudioHandler"

# 保存日志到文件
adb logcat > cyrene_music_debug.log
```

### 查看系统服务状态
```bash
# 查看 MediaSession
adb shell dumpsys media_session

# 查看活动的通知
adb shell dumpsys notification --noredact
```

## 🔧 高级调试

### 启用详细日志
在应用代码中临时添加更多日志：

```dart
// 在 AudioHandler 中添加
@override
Future<void> play() async {
  print('🎵 [AudioHandler] play() 被调用');
  print('   当前状态: ${playbackState.value.playing}');
  await PlayerService().resume();
  print('✅ [AudioHandler] play() 完成');
}
```

### 使用 Android Studio Profiler

1. 打开 Android Studio
2. 连接设备
3. View → Tool Windows → Profiler
4. 选择 Cyrene Music 进程
5. 查看 CPU 和内存使用情况

### 检查 Service 是否运行
```bash
# 查看运行中的服务
adb shell dumpsys activity services | grep cyrene

# 应该看到 AudioService 在运行
```

## 📞 获取帮助

如果以上步骤都无法解决问题，请提供以下信息：

1. **设备信息**
   ```bash
   adb shell getprop ro.build.version.release  # Android 版本
   adb shell getprop ro.product.model          # 设备型号
   ```

2. **完整日志**
   ```bash
   adb logcat > full_debug.log
   # 然后上传 full_debug.log
   ```

3. **权限状态**
   ```bash
   adb shell dumpsys package com.cyrene.music | grep permission
   ```

4. **通知渠道配置**
   ```bash
   adb shell dumpsys notification | grep -A 20 "com.cyrene.music"
   ```

---

**文档版本**: 1.0  
**最后更新**: 2025-10-03  
**适用版本**: Cyrene Music v1.3.3+

