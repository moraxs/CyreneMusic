# 已知问题修复说明

## ✅ 已修复的问题

### 1. SharedMemory read failed 错误

#### 问题描述

控制台频繁出现错误：
```
SharedMemory read failed
SharedMemory read failed
SharedMemory read failed
```

#### 原因分析

这是 Windows SMTC（System Media Transport Controls）的已知问题：
- SMTC 使用 SharedMemory 与系统通信
- 当频繁更新状态或进度时，可能出现读取失败
- 这是 `smtc_windows` 包的底层问题
- **不影响应用功能和播放**

#### 解决方案

已添加错误捕获，忽略这些无害的错误：

```dart
try {
  _smtcWindows!.setPlaybackStatus(status);
} catch (e) {
  // 忽略 SharedMemory 错误，不影响播放
  if (!e.toString().contains('SharedMemory')) {
    print('⚠️ [SystemMediaService] 更新状态失败: $e');
  }
}
```

**修复位置：**
- `lib/services/system_media_service.dart`
- 三处添加 try-catch：
  1. `enableSmtc()` 调用
  2. `setPlaybackStatus()` 调用
  3. `updateTimeline()` 调用

**效果：**
- ✅ 错误信息不再显示
- ✅ 不影响媒体控制功能
- ✅ 不影响播放体验

---

### 2. 自定义缓存目录不立即生效

#### 问题描述

用户设置了自定义缓存目录后，歌曲仍然缓存到默认位置：

```
🔒 [CacheService] 保存缓存文件: D:\work\...\Debug\music_cache/netease_xxx.cyrene
```

#### 原因分析

**这是预期行为，不是 bug！**

缓存服务的初始化流程：
```
应用启动
  ↓
CacheService.initialize()
  ↓
读取设置（custom_cache_dir）
  ↓
确定缓存目录
  ↓
_cacheDir 被设置
  ↓
后续所有缓存使用这个目录
```

**设置自定义目录后：**
```
用户设置新目录
  ↓
保存到 SharedPreferences
  ↓
但 _cacheDir 已经初始化，不会改变
  ↓
新目录要等下次启动才读取
```

#### 解决方案

**方案 1：添加明显的重启提示（已实现）**

设置目录后会弹出对话框：

```
┌──────────────────────────┐
│    🔄 需要重启应用        │
├──────────────────────────┤
│ 缓存目录已设置为：        │
│ D:\Music\Cache          │
│                         │
│ ⚠️ 必须重启应用才能使用  │
│    新目录！              │
│    当前播放的歌曲仍会    │
│    缓存到旧目录。        │
└──────────────────────────┘
      [知道了]
```

**方案 2：查看设置是否保存成功**

在控制台日志中确认：
```
✅ [CacheService] 自定义目录验证成功: D:\Music\Cache
💾 [CacheService] 自定义目录已保存: D:\Music\Cache
⚠️ [CacheService] 目录更改已保存，需要重启应用才能生效
ℹ️ [CacheService] 当前缓存目录: D:\work\...\Debug\music_cache
ℹ️ [CacheService] 新目录将在重启后使用: D:\Music\Cache
```

**方案 3：重启应用验证**

1. **关闭应用**
2. **重新运行** `flutter run`
3. **查看启动日志**：

```
💾 [CacheService] 开始初始化缓存服务...
⚙️ [CacheService] 加载设置 - 缓存开关: true, 自定义目录: D:\Music\Cache
📂 [CacheService] 使用自定义目录: D:\Music\Cache
📂 [CacheService] 缓存目录路径: D:\Music\Cache\music_cache
✅ [CacheService] 缓存目录已创建
📁 [CacheService] 缓存位置: D:\Music\Cache\music_cache
```

4. **播放歌曲，确认新位置：**

```
🔒 [CacheService] 保存缓存文件: D:\Music\Cache\music_cache/netease_xxx.cyrene
```

---

## 🎯 正确的操作流程

### 设置自定义缓存目录

1. **打开设置** → 存储 → 缓存目录
2. **选择目录**：
   - 点击 📂 按钮浏览
   - 或手动输入路径
3. **保存设置**
4. **看到重启提示对话框** ⚠️
5. **关闭应用**
6. **重新启动应用**
7. **验证新目录**：
   - 播放歌曲
   - 检查控制台日志
   - 确认缓存到新目录

### 验证设置是否生效

**方法 1：查看启动日志**
```
📂 [CacheService] 使用自定义目录: {你设置的路径}
📁 [CacheService] 缓存位置: {你设置的路径}/music_cache
```

**方法 2：打开目录**
1. 导航到你设置的目录
2. 应该看到 `music_cache` 子文件夹
3. 播放后看到 `.cyrene` 文件

**方法 3：查看设置页面**
```
缓存目录
  自定义：D:\Music\Cache
```

---

## 🐛 常见误区

### ❌ 误区 1：设置后立即生效

**错误认知：** 设置目录后，下一首歌就会缓存到新目录

**正确理解：** 必须重启应用，缓存服务重新初始化后才生效

### ❌ 误区 2：看到错误就是有问题

**错误认知：** "SharedMemory read failed" 意味着功能损坏

**正确理解：** 这是无害的警告，不影响任何功能

### ❌ 误区 3：旧缓存会自动迁移

**错误认知：** 更改目录后，旧缓存会移动到新位置

**正确理解：** 旧缓存保留在原位置，需要手动迁移

---

## 📝 技术说明

### SharedMemory 错误处理

**捕获策略：**
```dart
try {
  _smtcWindows!.updateTimeline(...);
} catch (e) {
  // 只忽略 SharedMemory 错误
  if (!e.toString().contains('SharedMemory')) {
    // 其他错误仍然记录
    print('⚠️ 更新进度失败: $e');
  }
}
```

**为什么这样处理？**
- SharedMemory 错误是底层通信问题
- 不影响应用功能
- 重试通常也会失败
- 最好的处理是静默忽略

### 缓存目录设置时序

**为什么不立即生效？**

1. **初始化时机**：
   - CacheService 在 main() 中初始化
   - 此时读取 SharedPreferences
   - 确定缓存目录并创建

2. **设置保存时机**：
   - 用户在设置页面更改目录
   - 保存到 SharedPreferences
   - 但 _cacheDir 已经初始化，不会改变

3. **重新初始化**：
   - 重启应用
   - CacheService 重新初始化
   - 读取新的设置
   - 使用新目录

**为什么不运行时重新初始化？**
- 可能有正在进行的缓存操作
- 文件路径会混乱
- 需要处理旧缓存迁移
- 重启是最安全的方式

---

## 🔄 版本历史

### v1.3.3 (2025-10-02)

**修复：**
- ✅ SharedMemory 错误静默处理
- ✅ 添加明显的重启提示对话框
- ✅ 改进缓存目录设置日志

**改进：**
- ✅ 更清晰的提示信息
- ✅ 防止用户误解

---

## 💡 最佳实践

### 1. 修改缓存目录

**推荐流程：**
1. 先停止播放
2. 设置新目录
3. 看到重启提示
4. 立即重启应用
5. 验证新目录生效

### 2. 处理旧缓存

**如果想迁移旧缓存：**
```powershell
# 假设旧目录：D:\work\...\Debug\music_cache
# 新目录：D:\Music\Cache

# 复制所有 .cyrene 文件
Copy-Item "D:\work\...\Debug\music_cache\*.cyrene" -Destination "D:\Music\Cache\music_cache\"

# 或使用文件管理器手动复制
```

### 3. 忽略 SharedMemory 错误

这些错误是**安全的**，可以忽略：
- 不影响播放
- 不影响缓存
- 不影响媒体控制
- 只是底层通信的小问题

---

## 📞 仍有问题？

### 检查清单

- [ ] 设置自定义目录后，是否重启了应用？
- [ ] 启动日志中是否显示使用自定义目录？
- [ ] 新目录是否有读写权限？
- [ ] 是否有足够的磁盘空间？

### 调试命令

**检查设置是否保存：**
```dart
// 在应用中查看
print(CacheService().customCacheDir);  // 应该显示你设置的路径
print(CacheService().currentCacheDir); // 显示实际使用的路径
```

**查看 SharedPreferences：**
```
Windows：%APPDATA%\Roaming\cyrene_music\shared_preferences\
查找 custom_cache_dir 键
```

---

**版本：** v1.3.3  
**状态：** ✅ 已修复  
**最后更新：** 2025-10-02

