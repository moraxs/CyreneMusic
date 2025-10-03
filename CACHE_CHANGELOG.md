# 缓存功能更新日志

## v1.3.0 - 2025-10-02

### ✨ 新功能

#### 统一缓存文件格式

- ✅ 一首歌只有一个缓存文件
- ✅ 使用专有扩展名 `.cyrene`
- ✅ 元数据和音频数据合并存储
- ✅ 二进制格式，更高效

#### 文件格式改进

**之前：**
```
netease_123456_exhigh.cache      # 加密音频
netease_123456_exhigh.meta.json  # 元数据
```

**现在：**
```
netease_123456.cyrene            # 合并文件（元数据 + 加密音频）
```

#### 优势

- 📁 **文件管理更简单** - 一首歌一个文件
- 🔒 **格式更统一** - 专有扩展名 `.cyrene`
- 🚀 **性能更好** - 减少文件操作次数
- 💾 **避免重复** - 同一首歌不会有多个缓存

### 🔧 技术改进

1. **缓存键简化**
   - 之前：`{来源}_{歌曲ID}_{音质}`
   - 现在：`{来源}_{歌曲ID}`
   - 好处：同一首歌只有一个缓存

2. **文件格式设计**
   ```
   [4字节: 元数据长度] [元数据JSON] [加密音频]
   ```
   - 使用大端序存储长度
   - 元数据 UTF-8 编码
   - 音频数据 XOR 加密

3. **API 简化**
   ```dart
   // 之前
   isCached(track, quality)
   getCachedFilePath(track, quality)
   
   // 现在
   isCached(track)
   getCachedFilePath(track)
   ```

### 📊 影响范围

**修改的文件：**
- ✅ `lib/services/cache_service.dart` - 核心缓存逻辑
- ✅ `lib/services/player_service.dart` - 播放器集成
- ✅ `lib/pages/settings_page.dart` - 缓存管理界面
- ✅ `lib/main.dart` - 初始化顺序
- ✅ `pubspec.yaml` - 添加 crypto 依赖

**新增的文件：**
- ✅ `docs/MUSIC_CACHE.md` - 功能文档
- ✅ `docs/CACHE_TROUBLESHOOTING.md` - 故障排除
- ✅ `docs/CYRENE_FILE_FORMAT.md` - 文件格式规范
- ✅ `CACHE_TEST.md` - 测试指南
- ✅ `CACHE_CHANGELOG.md` - 更新日志

### ⚠️ 迁移说明

如果你之前使用了旧版本的缓存（`.cache` 文件），请：

1. **清除旧缓存**
   - 打开设置 → 存储 → 清除缓存
   - 或手动删除旧的 `.cache` 和 `.meta.json` 文件

2. **重新缓存**
   - 新格式会自动生成 `.cyrene` 文件
   - 旧缓存不会自动转换

### 🐛 已修复的问题

1. ✅ 修复了初始化异步问题
2. ✅ 添加了详细的调试日志
3. ✅ 改进了目录验证逻辑
4. ✅ 统一了文件格式

---

## 📚 相关文档

- [MUSIC_CACHE.md](docs/MUSIC_CACHE.md) - 完整功能说明
- [CYRENE_FILE_FORMAT.md](docs/CYRENE_FILE_FORMAT.md) - 文件格式规范
- [CACHE_TROUBLESHOOTING.md](docs/CACHE_TROUBLESHOOTING.md) - 故障排除
- [CACHE_TEST.md](CACHE_TEST.md) - 快速测试

---

**版本：** v1.3.0  
**日期：** 2025-10-02  
**状态：** 稳定发布

