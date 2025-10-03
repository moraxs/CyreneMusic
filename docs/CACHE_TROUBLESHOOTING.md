# 缓存功能故障排除指南

## 🔍 检查缓存是否正常工作

### 步骤 1：查看启动日志

运行应用后，在控制台（或开发者模式日志）中查找以下日志：

```
💾 [CacheService] 开始初始化缓存服务...
📂 [CacheService] 应用文档目录: C:\Users\{用户名}\Documents
📂 [CacheService] 缓存目录路径: C:\Users\{用户名}\Documents\music_cache
📁 [CacheService] 缓存目录不存在，创建中...
✅ [CacheService] 缓存目录已创建: C:\Users\{用户名}\Documents\music_cache
✅ [CacheService] 缓存目录可写
📑 [CacheService] 加载缓存索引: 0 条记录
✅ [CacheService] 缓存服务初始化完成！
📊 [CacheService] 已缓存歌曲数: 0
📁 [CacheService] 缓存位置: C:\Users\{用户名}\Documents\music_cache
```

**关键信息：**
- 记下 `缓存目录路径` - 这是缓存文件的实际位置
- 确认看到 `✅ 缓存服务初始化完成！`

### 步骤 2：验证缓存目录

1. 打开文件资源管理器
2. 导航到日志中显示的缓存目录
3. 应该能看到空文件夹或已缓存的文件

**Windows 默认路径：**
```
{应用运行目录}\music_cache\

示例（开发环境）：
D:\work\cyrene_music\build\windows\x64\runner\Release\music_cache\

示例（发布版本）：
C:\Program Files\Cyrene Music\music_cache\
```

**提示：** Windows 平台缓存在应用运行目录，方便查找和管理！

### 步骤 3：测试缓存功能

1. 播放任意一首歌曲
2. 在控制台查找以下日志：

**首次播放（缓存）：**
```
🎵 [PlayerService] 开始播放: 歌曲名 - 艺术家
🌐 [PlayerService] 从网络获取歌曲
✅ [PlayerService] 开始播放: http://...
💾 [PlayerService] 开始后台缓存: 歌曲名
💾 [CacheService] 开始缓存: 歌曲名 (网易云音乐)
📥 [CacheService] 下载完成: 5242880 bytes
🔒 [CacheService] 加密并保存缓存文件: ...
✅ [CacheService] 缓存完成: 歌曲名
```

3. 检查缓存目录，应该看到新文件：
   - `netease_{歌曲ID}.cyrene`
   - `cache_index.cyrene` （加密的索引文件）

4. 再次播放同一首歌，应该看到：

**使用缓存：**
```
🎵 [PlayerService] 开始播放: 歌曲名 - 艺术家
💾 [PlayerService] 使用缓存播放
✅ [CacheService] 解密缓存文件: /tmp/temp_...
✅ [PlayerService] 从缓存播放: /tmp/temp_...
```

### 步骤 4：查看缓存统计

1. 打开「设置」页面
2. 找到「存储」部分
3. 查看「缓存管理」
   - 如果初始化成功，应该显示：`已缓存 X 首歌曲`
   - 如果显示 `初始化中...`，说明初始化失败

---

## ❌ 常见问题

### 问题 1：一直显示"初始化中..."

**可能原因：**
- CacheService 初始化失败
- path_provider 获取路径失败

**解决方法：**

1. 检查控制台日志，查找 `❌ [CacheService] 初始化失败` 错误
2. 查看错误堆栈，定位具体问题
3. 确保应用有文档目录的读写权限

**手动验证权限：**
```powershell
# Windows PowerShell
cd $env:USERPROFILE\Documents
mkdir music_cache_test
echo "test" > music_cache_test\test.txt
del music_cache_test\test.txt
rmdir music_cache_test
```

如果以上命令失败，说明文档目录权限有问题。

### 问题 2：找不到缓存目录

**可能原因：**
- 日志中的路径与实际路径不同
- 缓存目录创建失败

**解决方法：**

1. 从控制台日志复制完整路径
2. 手动在文件管理器中粘贴路径
3. 如果提示路径不存在，检查日志中的创建状态

**检查日志：**
```
📁 [CacheService] 缓存目录不存在，创建中...
✅ [CacheService] 缓存目录已创建: {路径}
```

如果没有看到 `✅ 缓存目录已创建`，说明创建失败。

### 问题 3：缓存目录存在但为空

**可能原因：**
- 还没有播放过任何歌曲
- 缓存过程失败
- 歌曲已从缓存中删除

**解决方法：**

1. 播放一首歌曲
2. 等待几秒（缓存在后台进行）
3. 检查控制台是否有缓存完成日志
4. 刷新文件管理器

**验证缓存是否工作：**
- 检查 `cache_index.json` 文件是否存在
- 打开该文件，查看是否有缓存记录

### 问题 4：缓存文件无法打开

**这是正常的！**

缓存文件经过加密，**无法直接播放**。这是设计行为，用于：
- 防止直接使用缓存文件
- 版权保护
- 仅供应用内部使用

**验证加密：**
用文本编辑器打开 `.cache` 文件，应该看到乱码。

### 问题 5：应用重启后缓存消失

**可能原因：**
- 临时文件目录被清理
- 缓存索引丢失
- 缓存目录被删除

**检查：**

1. 确认缓存目录是否存在：
   ```
   C:\Users\{用户名}\Documents\music_cache\
   ```

2. 检查 `cache_index.json` 是否存在

3. 查看启动日志中的加载记录：
   ```
   📑 [CacheService] 加载缓存索引: X 条记录
   ```

---

## 🔧 手动测试

### 测试 1：验证目录创建

```dart
import 'package:path_provider/path_provider.dart';

void main() async {
  final appDir = await getApplicationDocumentsDirectory();
  print('应用文档目录: ${appDir.path}');
  
  final cacheDir = Directory('${appDir.path}/music_cache');
  print('缓存目录: ${cacheDir.path}');
  print('目录是否存在: ${await cacheDir.exists()}');
}
```

### 测试 2：验证文件写入

```dart
import 'dart:io';

void main() async {
  final testFile = File('C:/Users/{用户名}/Documents/music_cache/test.txt');
  await testFile.writeAsString('测试');
  print('写入成功: ${await testFile.exists()}');
  await testFile.delete();
}
```

---

## 📊 调试日志

### 启用详细日志

在开发者模式中查看完整日志：

1. 设置 → 版本号（点击5次）
2. 开发者模式 → 日志标签页
3. 播放歌曲并观察日志

### 关键日志标记

- `💾 [CacheService]` - 缓存服务日志
- `🎵 [PlayerService]` - 播放器日志
- `✅` - 成功操作
- `❌` - 失败操作
- `⚠️` - 警告信息

---

## 🆘 报告问题

如果以上方法都无法解决问题，请提供以下信息：

1. **操作系统和版本**
   ```
   Windows 10/11
   ```

2. **控制台日志**
   ```
   从应用启动到播放歌曲的完整日志
   ```

3. **缓存目录路径**
   ```
   从日志中复制的完整路径
   ```

4. **目录内容**
   ```
   缓存目录下的文件列表（截图或文件名列表）
   ```

5. **cache_index.json 内容**
   ```json
   如果文件存在，提供其内容
   ```

---

## ✅ 成功标志

缓存功能正常工作的标志：

1. ✅ 控制台显示 `✅ [CacheService] 缓存服务初始化完成！`
2. ✅ 缓存目录存在且可访问
3. ✅ 播放歌曲后出现 `.cache` 和 `.meta.json` 文件
4. ✅ 设置页面显示 `已缓存 X 首歌曲`
5. ✅ 再次播放时日志显示 `💾 使用缓存播放`
6. ✅ 缓存管理对话框显示正确的统计信息

---

**提示：** 如果仍有问题，请重启应用并仔细查看启动日志！

