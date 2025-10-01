# 数据模型说明

## 📦 模型列表

### 1. Track（歌曲模型）

表示单个歌曲的数据结构。

**字段：**
- `id` (int) - 歌曲 ID
- `name` (String) - 歌曲名称
- `artists` (String) - 艺术家
- `album` (String) - 专辑名称
- `picUrl` (String) - 封面图片 URL
- `source` (MusicSource) - 音乐来源

**方法：**
- `fromJson()` - 从 JSON 创建对象
- `toJson()` - 转换为 JSON
- `getSourceName()` - 获取音乐来源中文名称
- `getSourceIcon()` - 获取音乐来源图标

### 2. Toplist（榜单模型）

表示音乐榜单的数据结构。

**字段：**
- `id` (int) - 榜单 ID
- `name` (String) - 榜单名称
- `nameEn` (String) - 榜单英文名称
- `coverImgUrl` (String) - 封面图片 URL
- `creator` (String) - 创建者
- `trackCount` (int) - 歌曲总数
- `description` (String) - 榜单描述
- `tracks` (List<Track>) - 歌曲列表
- `source` (MusicSource) - 音乐来源

**方法：**
- `fromJson()` - 从 JSON 创建对象
- `toJson()` - 转换为 JSON

### 3. MusicSource（音乐平台枚举）

表示音乐来源平台。

**值：**
- `netease` - 网易云音乐
- `qq` - QQ音乐
- `kugou` - 酷狗音乐

## 🎯 使用示例

```dart
// 从 JSON 创建 Track
final track = Track.fromJson(jsonData, source: MusicSource.netease);

// 获取音乐来源信息
print(track.getSourceName()); // 输出：网易云音乐
print(track.getSourceIcon());  // 输出：🎵

// 从 JSON 创建 Toplist
final toplist = Toplist.fromJson(jsonData, source: MusicSource.netease);

// 访问榜单中的歌曲
for (var track in toplist.tracks) {
  print('${track.name} - ${track.artists}');
}
```

## 📝 注意事项

1. **音乐来源标识**：所有数据模型都包含 `source` 字段，用于区分不同平台的数据
2. **JSON 序列化**：支持与后端 API 的数据交互
3. **扩展性**：可以轻松添加新的音乐平台支持

