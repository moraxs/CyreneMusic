# 缓存功能快速测试

## 🚀 运行应用并测试

### 1. 启动应用

```bash
flutter run
```

### 2. 查看启动日志

在控制台中查找这些关键日志：

```
💾 [CacheService] 开始初始化缓存服务...
📂 [CacheService] 应用文档目录: {路径}
📂 [CacheService] 缓存目录路径: {路径}
✅ [CacheService] 缓存目录已创建: {路径}
✅ [CacheService] 缓存目录可写
✅ [CacheService] 缓存服务初始化完成！
📁 [CacheService] 缓存位置: {实际路径}
```

**⚠️ 重点：** 复制 `📁 [CacheService] 缓存位置:` 后面的路径！

### 3. 打开缓存目录

**方法 1 - 从日志复制路径：**
1. 复制日志中的缓存路径
2. 按 `Win + R`
3. 粘贴路径
4. 回车

**方法 2 - 打开运行目录：**
1. 打开文件资源管理器
2. 导航到应用运行目录
   - 开发环境：`项目目录\build\windows\x64\runner\Release\`
   - 发布版本：应用安装目录
3. 查找 `music_cache` 文件夹

### 4. 播放测试

1. 在应用中播放任意歌曲
2. 等待 5-10 秒（缓存需要下载时间）
3. 刷新缓存目录
4. 应该能看到新文件：
   - `cache_index.cyrene` （加密的索引文件）
   - `netease_XXXXX.cyrene` （歌曲缓存文件）

### 5. 验证缓存使用

1. 再次播放同一首歌
2. 查看日志，应该显示：
   ```
   💾 [PlayerService] 使用缓存播放
   ```
3. 播放应该几乎瞬间开始（无需下载）

### 6. 查看缓存统计

1. 打开「设置」
2. 滚动到「存储」部分
3. 点击「缓存管理」
4. 应该显示：
   - 总文件数：X 首
   - 占用空间：XX MB
   - 各平台歌曲数量

---

## 📝 预期结果

### 成功标志 ✅

- [x] 控制台显示缓存服务初始化完成
- [x] 能在文件管理器中找到 `music_cache` 目录
- [x] 播放歌曲后出现 `.cache` 文件
- [x] 设置页面显示 `已缓存 X 首歌曲`
- [x] 再次播放使用缓存（几乎瞬间开始）

### 失败标志 ❌

- [ ] 日志显示 `❌ [CacheService] 初始化失败`
- [ ] 找不到 `music_cache` 目录
- [ ] 播放后没有生成缓存文件
- [ ] 设置页面一直显示 `初始化中...`
- [ ] 再次播放仍然从网络下载

---

## 🐛 调试命令

### Windows PowerShell

**查找缓存目录：**
```powershell
# 进入应用运行目录（开发环境示例）
cd D:\work\cyrene_music\build\windows\x64\runner\Release

# 检查 music_cache 是否存在
Test-Path ".\music_cache"

# 列出缓存文件
Get-ChildItem ".\music_cache"

# 列出所有 .cyrene 文件
Get-ChildItem ".\music_cache\*.cyrene"
```

**查看文件大小：**
```powershell
# 计算缓存目录占用空间
Get-ChildItem ".\music_cache" -File | 
  Measure-Object -Property Length -Sum | 
  Select-Object @{Name="Size(MB)"; Expression={[math]::Round($_.Sum / 1MB, 2)}}

# 统计文件数量
Get-ChildItem ".\music_cache\*.cyrene" | Measure-Object | Select-Object Count
```

**注意：** 所有 `.cyrene` 文件（包括 cache_index.cyrene）都已加密，无法直接用文本编辑器查看。

---

## 🎯 快速验证清单

运行应用后，依次检查：

- [ ] 控制台有 `💾 [CacheService] 开始初始化缓存服务...` 日志
- [ ] 控制台有 `✅ [CacheService] 缓存服务初始化完成！` 日志
- [ ] 从日志中复制缓存目录路径
- [ ] 在文件管理器中能找到该目录
- [ ] 播放一首歌曲
- [ ] 等待 10 秒
- [ ] 刷新缓存目录，看到新文件
- [ ] 设置 → 缓存管理 显示正确数量
- [ ] 再次播放同一首歌，使用缓存

**全部完成 = 缓存功能正常！🎉**

---

## 📞 获取帮助

如果遇到问题：

1. 查看 [CACHE_TROUBLESHOOTING.md](CACHE_TROUBLESHOOTING.md)
2. 检查控制台日志中的错误信息
3. 验证文档目录的读写权限
4. 确保应用有足够的存储空间

---

**最后更新：** 2025-10-02  
**版本：** v1.3.0

