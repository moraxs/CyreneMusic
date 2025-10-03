# 酷狗音乐播放功能实现

## 🎯 实现目标

实现酷狗音乐的完整播放功能，包括搜索、获取歌曲详情、流式播放。

## 📊 API 规范

### 搜索 API（已实现）
- **URL**: `/kugou/search`
- **方法**: GET
- **参数**: `keywords` - 搜索关键词
- **返回字段**:
  - `emixsongid` - 歌曲唯一标识（String 类型）
  - `name` - 歌曲名称
  - `singer` - 歌手
  - `album` - 专辑
  - `pic` - 封面图片

### 歌曲详情 API（本次实现）
- **URL**: `/kugou/song`
- **方法**: GET
- **参数**: `emixsongid` - 歌曲ID
- **返回示例**:
```json
{
    "status": 200,
    "song": {
        "name": "若我不曾见过太阳",
        "singer": "知更鸟、HOYO-MiX、Chevy",
        "album": "崩坏星穹铁道-空气蛹 INSIDE",
        "pic": "https://imge.kugou.com/...",
        "lyric": "[00:00.10]知更鸟、HOYO-MiX、Chevy - 若我不曾见过太阳\r\n...",
        "url": "https://webfs.kugou.com/...",
        "bitrate": 128,
        "duration": 145
    }
}
```

## 🔧 技术实现

### 1. MusicService 修改

#### 请求参数修正
```dart
// 之前（错误）
url = '$baseUrl/kugou/song?ids=$songId';

// 现在（正确）
url = '$baseUrl/kugou/song?emixsongid=$songId';
```

#### 返回格式解析
```dart
if (source == MusicSource.kugou) {
  final song = data['song'] as Map<String, dynamic>?;
  
  // 处理 bitrate（可能是 int 或 String）
  final bitrateValue = song['bitrate'];
  final bitrate = bitrateValue != null ? '${bitrateValue}kbps' : '未知';
  
  songDetail = SongDetail(
    id: songId,                          // emixsongid
    name: song['name'] ?? '',            // 歌曲名
    pic: song['pic'] ?? '',              // 封面图
    arName: song['singer'] ?? '',        // 歌手
    alName: song['album'] ?? '',         // 专辑
    level: bitrate,                      // 音质（128kbps）
    size: song['duration']?.toString() ?? '0',  // 时长
    url: song['url'] ?? '',              // 播放链接
    lyric: song['lyric'] ?? '',          // 歌词
    tlyric: '',                          // 酷狗无翻译歌词
    source: source,
  );
}
```

### 2. 字段映射说明

| 酷狗 API 字段 | SongDetail 字段 | 说明 |
|--------------|----------------|------|
| name | name | 歌曲名称 |
| singer | arName | 歌手（艺术家名称） |
| album | alName | 专辑名称 |
| pic | pic | 封面图片 URL |
| url | url | 播放链接 |
| bitrate | level | 音质等级 |
| duration | size | 时长（秒），复用 size 字段 |
| lyric | lyric | 歌词（LRC 格式） |
| - | tlyric | 翻译歌词（酷狗不提供，设为空） |

### 3. 本地代理支持（已实现）

在 `ProxyService` 中已添加酷狗音乐支持：
```dart
if (platform == 'kugou') {
  headers['referer'] = 'https://www.kugou.com';
}
```

### 4. 播放流程

```
用户点击播放
    ↓
MusicService.fetchSongDetail(emixsongid, source: MusicSource.kugou)
    ↓
GET /kugou/song?emixsongid=xxx
    ↓
解析返回 JSON，构造 SongDetail
    ↓
PlayerService 使用本地代理播放
    ↓
ProxyService 转发请求（添加 referer: https://www.kugou.com）
    ↓
流式播放音频
```

## 📝 歌词格式处理

### 酷狗歌词格式
```
[00:00.10]知更鸟、HOYO-MiX、Chevy - 若我不曾见过太阳\r\n
[00:01.06]作词 Lyricist：Ruby Qu\r\n
[00:16.64]In candlelight\r\n
[00:20.82]As time unwinds\r\n
```

**特点**：
- 标准 LRC 格式
- 使用 `\r\n` 换行符
- 时间戳格式：`[mm:ss.xx]`
- 无翻译歌词

## 🎨 用户体验

### 搜索结果显示
- 显示酷狗音乐图标 🎼
- 所有平台歌曲都可以点击播放
- 加载提示：`正在加载: xxx (酷狗音乐)`

### 播放体验
- 使用本地代理，流式播放
- 1-2 秒内开始播放
- 支持进度条拖动
- 显示歌词（如果有）
- 自动后台缓存

### 系统集成
- Windows 系统媒体控件（SMTC）正确显示
- 系统托盘菜单正确更新
- 支持暂停/播放/停止控制

## 🧪 测试场景

### 测试步骤
1. 搜索酷狗音乐歌曲
2. 点击播放按钮
3. 观察控制台日志
4. 检查播放器界面
5. 验证系统媒体控件

### 预期日志
```
🎵 [MusicService] 获取歌曲详情: xxx (kugou), 音质: 极高音质
🌐 [Network] GET http://localhost:3000/kugou/song?emixsongid=xxx
📥 [Network] 状态码: 200
✅ [MusicService] 成功获取歌曲详情: 若我不曾见过太阳
   🎵 艺术家: 知更鸟、HOYO-MiX、Chevy
   💿 专辑: 崩坏星穹铁道-空气蛹 INSIDE
   🎼 音质: 128kbps
   📦 大小: 145
   🔗 URL: 已获取
🎶 [PlayerService] 使用本地代理播放 酷狗音乐
🔗 [ProxyService] 生成代理 URL: http://localhost:8888/proxy?url=...&platform=kugou
🌐 [ProxyService] 代理请求: https://webfs.kugou.com/...
✅ [ProxyService] 开始流式传输音频数据
✅ [PlayerService] 通过代理开始流式播放
```

### 验证清单
- ✅ 歌曲正常播放
- ✅ 封面图片显示
- ✅ 歌词显示（如果有）
- ✅ 进度条可拖动
- ✅ 系统媒体控件工作
- ✅ 托盘菜单更新
- ✅ 后台缓存正常

## ⚠️ 注意事项

### 1. ID 类型
酷狗音乐的 `emixsongid` 是 **String 类型**，需要注意：
- 不能直接转换为 int
- 使用 `hashCode` 进行比较
- 传递给 API 时使用原值

### 2. 歌词换行符
酷狗歌词使用 `\r\n` 换行符：
```dart
// 显示时可能需要处理
final displayLyric = song.lyric.replaceAll('\r\n', '\n');
```

### 3. 无翻译歌词
酷狗音乐不提供翻译歌词：
```dart
tlyric: '',  // 设为空字符串
```

### 4. Duration vs Size
复用 `size` 字段存储时长（秒）：
```dart
size: song['duration']?.toString() ?? '0'  // 145 秒
```

## 🔄 与其他平台对比

| 特性 | 网易云音乐 | QQ音乐 | 酷狗音乐 |
|------|-----------|--------|---------|
| ID 类型 | int | String | String |
| 参数名 | ids | ids | emixsongid |
| 音质选择 | ✅ 多种 | ✅ flac/320/128 | ❌ 单一 |
| 翻译歌词 | ✅ 有 | ✅ 有 | ❌ 无 |
| 防盗链 | ❌ 无 | ✅ referer | ✅ referer |
| 播放方式 | 直接流式 | 本地代理 | 本地代理 |
| 文件大小 | ✅ 返回 | ❌ 不返回 | ✅ duration |

## 🎯 完成状态

### ✅ 已实现功能
- [x] 搜索酷狗音乐
- [x] 获取歌曲详情
- [x] 本地代理播放
- [x] 防盗链处理（referer）
- [x] 歌词显示
- [x] 系统媒体控件集成
- [x] 托盘菜单更新
- [x] 后台缓存

### 🎨 支持的平台
- ✅ 网易云音乐（完全支持）
- ✅ QQ音乐（完全支持）
- ✅ 酷狗音乐（完全支持）✨

## 📚 相关文档

- **[PROXY_OPTIMIZATION.md](PROXY_OPTIMIZATION.md)** - 本地代理实现
- **[BUGFIX_DYNAMIC_ID_TYPE.md](BUGFIX_DYNAMIC_ID_TYPE.md)** - ID 类型兼容性修复

## 🎉 总结

酷狗音乐播放功能现已完全实现！用户可以：
1. 搜索酷狗音乐的任意歌曲
2. 一键播放，1-2 秒内开始
3. 查看歌词和封面
4. 使用系统媒体控件
5. 自动后台缓存

**三大音乐平台全部打通！** 🎵🎶🎼

---

**实现版本**: v2.2  
**实现日期**: 2025-10-03  
**状态**: ✅ 已完成并测试  
**新增**: 酷狗音乐完整播放支持

