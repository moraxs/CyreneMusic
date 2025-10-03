# 缓存功能更新 v1.3.1

## 🎯 本次更新内容

### 1. Windows 平台缓存位置调整

**之前：**
```
C:\Users\{用户名}\Documents\music_cache\
```

**现在：**
```
{应用运行目录}\music_cache\

开发环境示例：
D:\work\cyrene_music\build\windows\x64\runner\Release\music_cache\

发布版本示例：
C:\Program Files\Cyrene Music\music_cache\
```

**优势：**
- ✅ **便于查找** - 缓存和应用在同一目录
- ✅ **便于备份** - 直接备份整个应用目录
- ✅ **便于移植** - 复制应用目录即可迁移缓存
- ✅ **便于管理** - 不污染用户文档目录

### 2. 索引文件加密

**之前：**
```
cache_index.json （明文）
```

**现在：**
```
cache_index.cyrene （加密）
```

**改进：**
- ✅ **统一格式** - 所有文件都使用 `.cyrene` 扩展名
- ✅ **安全保护** - 索引文件也经过加密
- ✅ **防止篡改** - 无法直接编辑索引文件

---

## 📁 新的文件结构

### Windows 开发环境

```
D:\work\cyrene_music\build\windows\x64\runner\Release\
├── cyrene_music.exe
├── music_cache\                      ⬅️ 缓存目录
│   ├── cache_index.cyrene            ⬅️ 加密的索引
│   ├── netease_123456.cyrene         ⬅️ 歌曲缓存
│   ├── qq_789012.cyrene
│   └── kugou_345678.cyrene
└── data\...
```

### 其他平台

其他平台（Android、macOS、Linux）继续使用应用数据目录。

---

## 🔒 加密详情

### 缓存索引加密

**cache_index.cyrene 格式：**
```
[加密的 JSON 数据]
```

**加密方式：**
- 使用 XOR 异或加密
- 密钥：`CyreneMusicCacheKey2025`
- 对称加密（加密 = 解密）

**内容示例（解密后）：**
```json
{
  "netease_123456": {
    "songId": "123456",
    "songName": "演员",
    "artists": "薛之谦",
    "source": "netease",
    "quality": "exhigh",
    ...
  },
  "qq_789012": {
    ...
  }
}
```

---

## 🚀 如何验证

### 1. 运行应用

```bash
flutter run
```

### 2. 查看日志中的路径

**开发环境日志示例：**
```
📂 [CacheService] 运行目录: D:\work\cyrene_music\build\windows\x64\runner\Release
📂 [CacheService] 缓存目录路径: D:\work\cyrene_music\build\windows\x64\runner\Release\music_cache
✅ [CacheService] 缓存目录已创建
📁 [CacheService] 缓存位置: D:\work\cyrene_music\build\windows\x64\runner\Release\music_cache
```

### 3. 导航到缓存目录

**快捷方式：**
1. 复制日志中的路径
2. 按 `Win + R`
3. 粘贴路径
4. 回车

**或手动：**
1. 打开项目目录：`D:\work\cyrene_music`
2. 进入：`build\windows\x64\runner\Release\`
3. 查找：`music_cache` 文件夹

### 4. 播放并验证

1. 播放任意歌曲
2. 等待缓存完成
3. 刷新缓存目录
4. 应该看到：
   - `cache_index.cyrene` ✅ 加密的索引
   - `netease_XXXXX.cyrene` ✅ 歌曲缓存

**尝试用文本编辑器打开：**
- 所有文件都应该显示为乱码（加密生效）

---

## 📊 技术细节

### 代码改动

**lib/services/cache_service.dart:**

1. **缓存目录获取：**
```dart
if (Platform.isWindows) {
  // Windows: 使用当前运行目录
  final executablePath = Platform.resolvedExecutable;
  final executableDir = path.dirname(executablePath);
  _cacheDir = Directory(path.join(executableDir, 'music_cache'));
} else {
  // 其他平台: 使用应用文档目录
  final appDir = await getApplicationDocumentsDirectory();
  _cacheDir = Directory('${appDir.path}/music_cache');
}
```

2. **索引文件加密：**
```dart
// 保存
final jsonBytes = utf8.encode(jsonEncode(indexData));
final encryptedData = _encryptData(jsonBytes);
await File('cache_index.cyrene').writeAsBytes(encryptedData);

// 读取
final encryptedData = await File('cache_index.cyrene').readAsBytes();
final decryptedData = _decryptData(encryptedData);
final indexJson = utf8.decode(decryptedData);
```

---

## ⚠️ 迁移指南

### 如果你有旧缓存

**方法 1：清除旧缓存**
1. 打开设置 → 存储 → 清除缓存
2. 重新播放歌曲，生成新格式缓存

**方法 2：手动迁移（不推荐）**
1. 删除旧的 `C:\Users\{用户名}\Documents\music_cache\`
2. 新缓存会自动在运行目录生成

### 版本兼容性

- **v1.3.0** → **v1.3.1**：不兼容，需要清除旧缓存
- 索引文件从 `.json` 改为 `.cyrene`
- 缓存目录位置变更（仅 Windows）

---

## 📚 更新的文档

- ✅ `docs/MUSIC_CACHE.md` - 更新缓存位置说明
- ✅ `docs/CACHE_TROUBLESHOOTING.md` - 更新路径示例
- ✅ `docs/CYRENE_FILE_FORMAT.md` - 添加索引文件说明
- ✅ `CACHE_TEST.md` - 更新测试命令

---

## 🎉 改进总结

### 优势

1. **Windows 用户体验提升**
   - 缓存文件与应用在同一位置
   - 更容易找到和管理
   - 卸载应用时缓存也会被删除

2. **安全性增强**
   - 索引文件也加密了
   - 所有 `.cyrene` 文件都无法直接查看
   - 防止用户手动修改索引

3. **格式统一**
   - 所有文件都是 `.cyrene` 扩展名
   - 清晰的文件类型标识
   - 专业的格式设计

### 文件清单

**缓存目录下的文件：**
```
music_cache/
├── cache_index.cyrene        ← 加密的索引文件
├── netease_123456.cyrene     ← 歌曲缓存（含元数据 + 音频）
├── qq_789012.cyrene
└── kugou_345678.cyrene
```

**所有文件都：**
- ✅ 使用 `.cyrene` 扩展名
- ✅ 经过 XOR 加密
- ✅ 无法直接打开或播放

---

## ✅ 测试清单

运行应用后，验证以下内容：

- [ ] 控制台显示 `📂 [CacheService] 运行目录: ...`
- [ ] 能在运行目录找到 `music_cache` 文件夹
- [ ] 播放歌曲后生成 `.cyrene` 文件
- [ ] `cache_index.cyrene` 文件存在
- [ ] 用文本编辑器打开 `.cyrene` 文件显示乱码
- [ ] 设置页面显示正确的缓存数量
- [ ] 再次播放使用缓存

---

**版本：** v1.3.1  
**日期：** 2025-10-02  
**状态：** ✅ 已完成

**关键改进：**
- 🔐 索引文件加密
- 📁 Windows 缓存位置优化

