# QQ音乐歌单导入修复说明

## 🐛 问题描述

从QQ音乐导入的歌单无法正常播放，播放时报错：

```
❌ [MusicService] 获取歌曲详情异常: type '_Map<String, dynamic>' is not a subtype of type 'String?' in type cast
❌ [PlayerService] 播放失败: 无法获取播放链接
```

## 🔍 问题原因

QQ音乐API返回的数据结构与网易云音乐不同：

### 网易云音乐返回格式（平铺结构）
```json
{
  "status": 200,
  "name": "歌曲名",
  "url": "https://...",
  "lyric": "[00:00.00]歌词内容",
  "tlyric": "翻译歌词"
}
```

### QQ音乐返回格式（嵌套结构）
```json
{
  "status": 200,
  "song": {
    "name": "歌曲名",
    "album": "专辑名",
    "singer": "歌手",
    "pic": "https://...",
    "mid": "004emxNb07GCdg",
    "id": 370900631
  },
  "lyric": {
    "lyric": "[00:00.00]歌词内容",
    "tylyric": "翻译歌词"
  },
  "music_urls": {
    "128": { "url": "...", "bitrate": "128kbps" },
    "320": { "url": "...", "bitrate": "320kbps" },
    "flac": { "url": "...", "bitrate": "FLAC" }
  }
}
```

**问题点**：调试代码在打印 `data['lyric']` 时，尝试将 QQ音乐的 Map 对象转换为 String，导致类型转换失败。

## ✅ 修复内容

修改了 `lib/services/music_service.dart` 文件中的调试输出逻辑：

### 修复前（第 280-308 行）
```dart
// 对所有音乐源使用相同的调试逻辑
print('   name: ${data['name']}');  // ❌ QQ音乐没有顶层 name 字段
print('   url: ${data['url']}');    // ❌ QQ音乐没有顶层 url 字段
final lyricContent = data['lyric'] as String?;  // ❌ QQ音乐返回 Map，不是 String
```

### 修复后
```dart
// 根据音乐源使用不同的调试逻辑
if (source == MusicSource.qq) {
  // QQ音乐格式处理
  final song = data['song'] as Map<String, dynamic>?;
  print('   name: ${song?['name']}');
  
  final lyricData = data['lyric'];
  if (lyricData is Map) {
    final lyricText = lyricData['lyric'];
    if (lyricText is String) {
      print('   lyric 长度: ${lyricText.length}');
    }
  }
} else {
  // 网易云/酷狗格式处理
  print('   name: ${data['name']}');
  print('   url: ${data['url']}');
  // ... 原有逻辑
}
```

## 🎯 已有的 QQ音乐处理逻辑

实际的数据解析逻辑（第 313-370 行）**已经正确处理了QQ音乐格式**，包括：

1. ✅ 正确解析嵌套的 `song` 对象
2. ✅ 正确解析 `lyric` Map 对象
3. ✅ 根据音质选择播放链接
4. ✅ 创建 SongDetail 对象

**所以问题只出在调试输出代码上**，实际的业务逻辑是正常的。

## 🧪 测试步骤

### 1. 启动后端服务
```bash
cd backend
bun run src/index.ts
```

### 2. 启动 Flutter 应用
```bash
flutter run -d windows  # 或 android
```

### 3. 导入 QQ音乐歌单

在应用中：
1. 点击 "导入歌单" 按钮
2. 选择 "🎶 QQ音乐" 平台
3. 输入测试歌单：
   - **歌单ID**: `8522515502`
   - **或完整URL**: `https://y.qq.com/n/ryqq/playlist/8522515502`
4. 点击 "下一步"
5. 选择目标歌单（或新建歌单）
6. 等待导入完成

### 4. 播放测试

1. 打开导入的歌单
2. 点击任意歌曲播放
3. 观察控制台输出，应该看到：
   ```
   🔍 [MusicService] 后端返回的数据 (qq):
      status: 200
      song 字段存在: true
      name: Illusory Apparitions 郁郁的形影
      lyric 字段存在: true
      lyric 类型: _Map<String, dynamic>
      lyric.lyric 类型: String
      lyric.lyric 长度: 1234
      music_urls 字段存在: true
   ✅ [MusicService] 成功获取歌曲详情: Illusory Apparitions 郁郁的形影
   ```

### 5. 验证功能

- ✅ 歌曲能正常播放
- ✅ 控制台无类型转换错误
- ✅ 歌词能正常显示
- ✅ 播放控制正常（暂停、下一首等）
- ✅ 系统媒体控制正常（通知栏、锁屏等）

## 📝 相关文件

- **修复文件**: `lib/services/music_service.dart`
- **导入对话框**: `lib/widgets/import_playlist_dialog.dart`
- **数据模型**: `lib/models/song_detail.dart`
- **后端API**: `backend/src/lib/qqApis.ts`

## 🔗 相关文档

- [QQ音乐歌单导入指南](./QQ_PLAYLIST_IMPORT_GUIDE.md)
- [QQ音乐排行榜API](./QQ_TOPLIST_API.md)
- [后端API文档](../backend/README.md)

## 🎉 修复状态

✅ **已修复** - 2025-01-07

QQ音乐歌单导入和播放功能现已正常工作。调试输出已适配不同音乐源的数据格式。

