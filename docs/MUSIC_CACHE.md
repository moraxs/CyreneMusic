# 音乐缓存功能说明

## 📝 功能概述

Cyrene Music 现已支持**智能音乐缓存系统**，用户播放过的歌曲会自动加密缓存到本地，下次播放时直接使用缓存，无需重复下载。

## ✨ 功能特点

- 🔒 **加密存储** - 使用异或加密，缓存文件无法直接播放
- 🎵 **多平台支持** - 支持网易云、QQ音乐、酷狗音乐
- 🎯 **智能缓存** - 自动识别歌曲来源和音质
- 📊 **统计管理** - 完整的缓存统计和管理功能
- 🚀 **无缝体验** - 自动在后台缓存，不影响播放
- 💾 **空间优化** - 可随时清除缓存释放空间

## 🎯 工作流程

### 首次播放
```
用户点击播放
    ↓
检查缓存（未缓存）
    ↓
从网络获取音乐
    ↓
开始播放 ✅
    ↓
后台自动缓存（不阻塞播放）
    ↓
缓存完成 💾
```

### 再次播放
```
用户点击播放
    ↓
检查缓存（已缓存）
    ↓
解密缓存文件
    ↓
立即播放 ⚡（无需下载）
```

## 🔐 加密机制

### 为什么要加密？

- ❌ **防止直接播放** - 缓存文件无法通过普通播放器打开
- ✅ **版权保护** - 不是下载，仅用于应用内缓存加速
- 🔒 **数据安全** - 简单的异或加密，防止文件被滥用

### 加密方式

使用**异或加密**（XOR Cipher）：
- 加密密钥：`CyreneMusicCacheKey2025`
- 对称加密：加密和解密使用同一方法
- 轻量快速：不影响播放性能

## 📁 缓存存储

### 存储位置

> **提示：** 启动应用后，在控制台日志中查找 `📁 [CacheService] 缓存位置:` 可以看到实际路径！

**Windows:**
```
{应用运行目录}\music_cache\

示例：
D:\work\cyrene_music\build\windows\x64\runner\Release\music_cache\
```

**Android:**
```
/data/user/0/com.example.cyrene_music/app_flutter/music_cache/
```

**macOS:**
```
~/Library/Application Support/com.example.cyrene_music/music_cache/
```

**Linux:**
```
~/.local/share/cyrene_music/music_cache/
```

**重要说明：**
- **Windows 平台**：缓存在应用运行目录下，方便管理和备份
- **其他平台**：缓存在系统应用数据目录

**如何查找实际路径：**
1. 运行应用
2. 查看控制台或开发者模式日志
3. 搜索 `[CacheService] 缓存位置`
4. 复制路径到文件管理器

### 文件结构

```
music_cache/
├── cache_index.cyrene        # 缓存索引文件（加密）
├── netease_123456.cyrene     # 网易云歌曲（加密，含元数据）
├── qq_789012.cyrene          # QQ音乐歌曲（加密，含元数据）
└── kugou_345678.cyrene       # 酷狗音乐歌曲（加密，含元数据）
```

**重要特性：**
- ✅ 所有文件都使用 `.cyrene` 扩展名
- ✅ 索引文件也经过加密
- ✅ 一首歌只有一个 `.cyrene` 文件
- ✅ 元数据和音频数据合并存储
- ✅ 文件经过加密，无法直接播放

### .cyrene 文件格式

```
┌─────────────────────────────────────┐
│ [4 字节] 元数据长度（大端序）        │
├─────────────────────────────────────┤
│ [N 字节] 元数据 JSON                 │
│ {songId, name, source, quality...}   │
├─────────────────────────────────────┤
│ [剩余字节] 加密的音频数据             │
│ (XOR 加密，无法直接播放)             │
└─────────────────────────────────────┘
```

### 缓存键格式

```
{来源}_{歌曲ID}

示例：
- netease_1234567.cyrene
- qq_123456789.cyrene
- kugou_abcd1234.cyrene
```

**注意：** 同一首歌只会有一个缓存文件，更换音质播放时会覆盖之前的缓存。

## 📊 元数据说明

每个 `.cyrene` 文件内部包含嵌入的元数据（JSON格式）：

```json
{
  "songId": "1234567",
  "songName": "演员",
  "artists": "薛之谦",
  "source": "netease",
  "quality": "exhigh",
  "originalUrl": "http://...",
  "fileSize": 5242880,
  "cachedAt": "2025-10-02T15:30:00.000Z",
  "checksum": "a1b2c3d4e5f6..."
}
```

**字段说明：**
- `songId` - 歌曲ID
- `songName` - 歌曲名称
- `artists` - 艺术家
- `source` - 音乐来源（netease/qq/kugou）
- `quality` - 音质等级
- `originalUrl` - 原始下载链接
- `fileSize` - 文件大小（字节）
- `cachedAt` - 缓存时间
- `checksum` - MD5校验和

**存储方式：**
- 元数据嵌入到 `.cyrene` 文件头部
- 使用4字节记录元数据长度
- 元数据后紧跟加密的音频数据

## 🎵 支持的音质

- ✅ **standard** - 标准音质
- ✅ **exhigh** - 极高音质（默认）
- ✅ **lossless** - 无损音质
- ✅ **hires** - Hi-Res
- ✅ **jyeffect** - 高清环绕声
- ✅ **sky** - 沉浸环绕声
- ✅ **jymaster** - 超清母带

**注意：** 同一首歌只保留一个缓存（最新播放的音质），更换音质播放时会更新缓存。

## 🚀 使用方法

### 自动缓存

**完全自动，无需任何操作！**

1. 正常播放歌曲
2. 系统自动在后台缓存
3. 再次播放时自动使用缓存

### 查看缓存

1. 打开「设置」页面
2. 找到「存储」部分
3. 点击「缓存管理」
4. 查看详细统计：
   - 总文件数
   - 占用空间
   - 各平台缓存数量

### 清除缓存

**方法1：清除所有缓存**

1. 设置 → 存储 → 清除缓存
2. 确认清除
3. 所有缓存文件被删除

**方法2：通过缓存管理**

1. 设置 → 存储 → 缓存管理
2. 点击「清除缓存」按钮
3. 确认操作

## 📊 缓存统计

### 统计信息

缓存管理对话框显示：

```
总文件数：25 首
占用空间：128.5 MB

🎵 网易云音乐：15 首
🎶 QQ音乐：8 首
🎼 酷狗音乐：2 首
```

### 空间计算

- **B** - 小于 1KB
- **KB** - 1KB ~ 1MB
- **MB** - 1MB ~ 1GB
- **GB** - 1GB 以上

## ⚡ 性能优化

### 后台缓存

缓存过程完全在后台进行：
- ✅ 不阻塞播放
- ✅ 不影响用户体验
- ✅ 失败不影响正常播放

### 临时文件管理

解密后的临时文件：
- 📁 存储在系统临时目录
- 🧹 应用退出时自动清理
- 💾 不占用永久空间

### 缓存策略

- **检查顺序**：先检查缓存 → 再请求网络
- **缓存时机**：播放开始后立即后台缓存
- **重复处理**：已缓存的歌曲不重复缓存

## 🔍 技术细节

### CacheService API

**初始化：**
```dart
await CacheService().initialize();
```

**检查缓存：**
```dart
bool isCached = CacheService().isCached(track, quality);
```

**获取缓存：**
```dart
String? filePath = await CacheService().getCachedFilePath(track, quality);
```

**缓存歌曲：**
```dart
bool success = await CacheService().cacheSong(track, songDetail, quality);
```

**获取统计：**
```dart
CacheStats stats = await CacheService().getCacheStats();
```

**清除缓存：**
```dart
await CacheService().clearAllCache();
```

**清理临时文件：**
```dart
await CacheService().cleanTempFiles();
```

### 加密算法

```dart
Uint8List _encryptData(Uint8List data) {
  final keyBytes = utf8.encode(_encryptionKey);
  final encrypted = Uint8List(data.length);

  for (int i = 0; i < data.length; i++) {
    encrypted[i] = data[i] ^ keyBytes[i % keyBytes.length];
  }

  return encrypted;
}
```

## 🐛 常见问题

### Q: .cyrene 文件可以直接播放吗？

**A:** 不可以。`.cyrene` 文件是专有格式，包含加密的音频数据和元数据，只能通过 Cyrene Music 应用解密播放。

### Q: 缓存会占用多少空间？

**A:** 取决于播放的歌曲数量和音质：
- 标准音质：约 3-5 MB/首
- 极高音质：约 5-10 MB/首
- 无损音质：约 20-40 MB/首

### Q: 如何删除单个缓存？

**A:** 当前版本仅支持清除所有缓存。单个删除功能将在未来版本添加。

### Q: 缓存失败会怎样？

**A:** 缓存失败不影响播放，下次播放时会重新尝试缓存。

### Q: 更换设备后缓存还在吗？

**A:** 缓存存储在本地，更换设备后需要重新缓存。

### Q: 卸载应用后缓存会删除吗？

**A:** 是的，卸载应用会删除所有缓存文件。

## 📝 日志示例

### 首次播放（缓存）

```
🎵 [PlayerService] 开始播放: 演员 - 薛之谦
🌐 [PlayerService] 从网络获取歌曲
✅ [PlayerService] 开始播放: http://...
💾 [PlayerService] 开始后台缓存: 演员
💾 [CacheService] 开始缓存: 演员 (网易云音乐)
📥 [CacheService] 下载完成: 5242880 bytes
🔒 [CacheService] 加密并保存缓存文件: ...
✅ [CacheService] 缓存完成: 演员
✅ [PlayerService] 缓存完成: 演员
```

### 再次播放（使用缓存）

```
🎵 [PlayerService] 开始播放: 演员 - 薛之谦
💾 [PlayerService] 使用缓存播放
✅ [CacheService] 解密缓存文件: /tmp/temp_...
✅ [PlayerService] 从缓存播放: /tmp/temp_...
```

### 清除缓存

```
🗑️ [CacheService] 清除所有缓存...
✅ [CacheService] 缓存已清除
```

## 🎯 未来计划

可能添加的功能：

1. **单曲缓存删除** - 选择性删除某首歌的缓存
2. **缓存大小限制** - 设置最大缓存空间
3. **自动清理** - 清理长时间未播放的缓存
4. **缓存优先级** - 收藏的歌曲优先缓存
5. **导出/导入** - 缓存数据备份和迁移
6. **离线模式** - 仅播放已缓存的歌曲
7. **批量缓存** - 一键缓存整个歌单

## 📚 相关文件

**前端：**
- `lib/services/cache_service.dart` - 缓存服务
- `lib/services/player_service.dart` - 播放器集成
- `lib/pages/settings_page.dart` - 缓存管理界面

**依赖：**
- `crypto: ^3.0.3` - MD5校验和加密
- `path_provider` - 获取应用目录
- `http` - 下载音频文件

## ⚠️ 注意事项

1. **版权声明**
   - 缓存功能仅用于提升用户体验
   - 缓存文件已加密，无法直接播放
   - 请尊重音乐版权，支持正版音乐

2. **存储空间**
   - 定期检查缓存占用空间
   - 空间不足时及时清理缓存
   - 推荐保留至少 1GB 空闲空间

3. **隐私安全**
   - 缓存文件仅存储在本地
   - 不会上传到服务器
   - 卸载应用会自动删除

## ✅ 版本历史

**v1.3.0** (2025-10-02)
- ✅ 实现音乐缓存功能
- ✅ 加密存储保护
- ✅ 缓存统计和管理
- ✅ 多平台支持
- ✅ 自动后台缓存

---

**提示：** 缓存功能完全自动，无需任何配置，享受更快的播放体验！🚀

