# QQ音乐歌单导入功能使用指南

## 📋 功能概述

现在你可以从 **QQ音乐** 导入歌单到 Cyrene Music！导入的歌曲会自动标记为 QQ音乐来源，播放时会调用 QQ音乐相关 API。

## ✨ 主要特性

- ✅ 支持 QQ音乐歌单 URL 或 ID 导入
- ✅ 自动解析歌单信息（封面、创建者、歌曲列表）
- ✅ 导入的歌曲自动标记为 `MusicSource.qq`
- ✅ 播放时自动使用 QQ音乐 API 和本地代理
- ✅ 与网易云音乐导入统一的 UI 体验

## 🚀 使用方法

### 1. 获取 QQ音乐歌单 ID 或 URL

#### 方法 A：使用完整 URL
在 QQ音乐网页版或客户端找到歌单，复制链接：

**支持的 URL 格式：**
```
https://y.qq.com/n/ryqq/playlist/8522515502
https://y.qq.com/n/m/detail/taoge/index.html?id=8522515502
```

#### 方法 B：使用歌单 ID
从 URL 中提取数字 ID，例如：`8522515502`

### 2. 导入歌单

1. 打开 Cyrene Music
2. 进入 **歌单** 页面
3. 点击右上角 **导入** 按钮（或相应的导入入口）
4. 选择 **🎶 QQ音乐** 平台
5. 粘贴歌单 URL 或输入歌单 ID
6. 点击 **下一步**
7. 选择目标歌单（或新建歌单）
8. 等待导入完成

### 3. 播放 QQ音乐歌曲

导入的歌曲会自动标记为 QQ音乐来源（显示 🎶 图标），播放时：

- 自动调用 `/qq/song` API 获取播放链接
- 使用本地代理服务（`ProxyService`）边下载边播放
- 支持多种音质（FLAC、320kbps、128kbps）
- 与网易云音乐歌曲混合播放无缝切换

## 🔧 技术实现

### 后端 API

#### 1. 获取 QQ音乐歌单详情
```http
GET /qq/playlist?id={dissid}&limit={limit}
```

**参数：**
- `id`: 歌单ID（必填）
- `limit`: 返回歌曲数量限制（默认1000）

**返回格式：**
```json
{
  "status": 200,
  "success": true,
  "data": {
    "playlist": {
      "id": "8522515502",
      "name": "华语流行精选",
      "coverImgUrl": "https://...",
      "creator": "QQ音乐用户",
      "trackCount": 100,
      "description": "...",
      "tracks": [
        {
          "id": 123456,
          "songmid": "003lghpv0jfFXG",
          "name": "晴天",
          "artists": "周杰伦",
          "album": "叶惠美",
          "picUrl": "https://...",
          "duration": 269000
        }
      ]
    }
  }
}
```

### 前端实现

#### 1. 歌曲来源标记

导入时自动设置 `MusicSource.qq`：

```dart
Track(
  id: trackJson['songmid'],  // QQ音乐使用 songmid
  name: trackJson['name'],
  artists: trackJson['artists'],
  album: trackJson['album'],
  picUrl: trackJson['picUrl'],
  source: MusicSource.qq,  // 🔥 关键标记
);
```

#### 2. 播放流程

```dart
// PlayerService 检测到 source == MusicSource.qq
if (track.source == MusicSource.qq) {
  // 1. 调用 QQ音乐 API 获取歌曲详情
  final songDetail = await MusicService().fetchSongDetail(
    songId: track.id,
    source: MusicSource.qq,
  );
  
  // 2. 使用本地代理播放
  if (ProxyService().isRunning) {
    final proxyUrl = ProxyService().getProxyUrl(songDetail.url, 'qq');
    await _audioPlayer.play(ap.UrlSource(proxyUrl));
  }
}
```

## 📊 支持的功能

| 功能 | 网易云音乐 | QQ音乐 | 说明 |
|------|-----------|--------|------|
| 歌单导入 | ✅ | ✅ | 支持 URL 和 ID |
| 歌曲播放 | ✅ | ✅ | 自动识别来源 |
| 歌词显示 | ✅ | ✅ | 支持原文+翻译 |
| 多音质 | ✅ | ✅ | 自动降级处理 |
| 缓存 | ✅ | ✅ | 统一缓存机制 |
| 排行榜 | ✅ | ✅ | 独立接口 |

## 🎯 注意事项

### 1. Cookie 配置

QQ音乐需要有效的 Cookie 才能获取歌曲：

```bash
# 配置 QQ音乐 Cookie
cd backend/cookie
echo "你的QQ音乐Cookie" > qq_cookie.txt
```

获取 Cookie 方法：
1. 登录 [y.qq.com](https://y.qq.com)
2. 打开浏览器开发者工具（F12）
3. 切换到 Network 标签
4. 刷新页面，找到任意请求
5. 复制 Request Headers 中的 Cookie 值

### 2. 歌曲ID差异

- **网易云音乐**: 使用数字 `id` (int)
- **QQ音乐**: 使用字符串 `songmid` (String)

播放器自动处理两种ID格式。

### 3. 代理服务

QQ音乐和酷狗音乐的播放链接需要通过本地代理：

```dart
// ProxyService 自动在应用启动时初始化
// 端口: 54321
// 播放时自动使用代理
```

如果代理不可用，会自动降级为下载后播放。

## 🐛 常见问题

### Q1: 导入失败，提示"歌单不存在或无法访问"

**可能原因：**
- 歌单 ID 错误
- 歌单设置为私密
- Cookie 过期或无效

**解决方法：**
1. 检查歌单 ID 是否正确
2. 确认歌单是公开状态
3. 更新 `qq_cookie.txt`

### Q2: 导入的歌曲无法播放

**可能原因：**
- Cookie 无效
- 歌曲版权限制
- 网络问题

**解决方法：**
1. 更新 QQ音乐 Cookie
2. 尝试其他歌曲
3. 检查后端服务日志

### Q3: 歌曲来源显示不正确

**检查点：**
- 确认导入时选择了 🎶 QQ音乐平台
- 检查 Track 对象的 `source` 字段
- 查看数据库中的存储值

## 📈 后续改进

- [ ] 支持更多 QQ音乐 URL 格式
- [ ] 批量导入多个歌单
- [ ] 自动同步歌单更新
- [ ] 导入进度实时显示
- [ ] 支持导入用户收藏的歌曲

## 🔗 相关文档

- [后端 API 文档](../backend/README.md)
- [QQ音乐排行榜 API](QQ_TOPLIST_API.md)
- [播放器服务文档](PLAYER_FEATURES.md)

---

**开发完成时间**: 2025-01-07  
**版本**: 1.0.5+

如有问题，请查看日志或提交 Issue。







