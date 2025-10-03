# 歌单/专辑解析功能快速测试指南

## 前置准备

1. **确保服务已启动**
   ```bash
   cd backend
   bun run dev
   ```
   服务将在 `http://localhost:4055` 启动

2. **确认Cookie配置**
   确保 `backend/cookie/cookie.txt` 文件包含有效的网易云 Cookie

## 快速测试

### 方法一：使用浏览器

直接在浏览器中访问以下URL：

#### 测试歌单解析
```
http://localhost:4055/playlist?id=19723756
```
这是网易云飙升榜，应该返回20首热门歌曲

#### 测试专辑解析
```
http://localhost:4055/album?id=3406843
```
这是周杰伦的《叶惠美》专辑

### 方法二：使用 cURL

```bash
# 测试歌单（完整）
curl "http://localhost:4055/playlist?id=19723756"

# 测试歌单（限制前10首）
curl "http://localhost:4055/playlist?id=19723756&limit=10"

# 测试专辑
curl "http://localhost:4055/album?id=3406843"
```

### 方法三：使用 Postman / Insomnia

1. 创建新的 GET 请求
2. 输入URL: `http://localhost:4055/playlist`
3. 添加查询参数:
   - `id`: `19723756`
   - `limit`: `10` (可选)
4. 发送请求

## 推荐测试歌单/专辑

### 热门歌单

| 名称 | ID | 说明 |
|------|----|----- |
| 飙升榜 | 19723756 | 网易云官方榜单 |
| 新歌榜 | 3779629 | 最新歌曲 |
| 热歌榜 | 3778678 | 热门歌曲 |
| 原创榜 | 2884035 | 原创音乐 |
| 云音乐欧美新歌榜 | 2809577409 | 欧美新歌 |
| 云音乐说唱榜 | 991319590 | 说唱音乐 |

### 热门专辑

| 艺人 | 专辑 | ID |
|------|------|----|
| 周杰伦 | 叶惠美 | 3406843 |
| 周杰伦 | 范特西 | 3406841 |
| 周杰伦 | Jay | 3406838 |
| 林俊杰 | 江南 | 3407024 |
| 薛之谦 | 意外 | 3094396 |

## 预期响应

### 歌单成功响应示例

```json
{
  "status": 200,
  "success": true,
  "data": {
    "playlist": {
      "id": 19723756,
      "name": "飙升榜",
      "coverImgUrl": "https://...",
      "creator": "网易云音乐",
      "trackCount": 100,
      "description": "...",
      "tracks": [
        {
          "id": 1234567,
          "name": "歌曲名",
          "artists": "艺术家",
          "album": "专辑名",
          "picUrl": "https://...",
          "duration": 240000
        }
      ]
    }
  }
}
```

### 专辑成功响应示例

```json
{
  "status": 200,
  "success": true,
  "data": {
    "album": {
      "id": 3406843,
      "name": "叶惠美",
      "coverImgUrl": "https://...",
      "artist": "周杰伦",
      "publishTime": 1057507200000,
      "description": "...",
      "songs": [
        {
          "id": 25643887,
          "name": "以父之名",
          "artists": "周杰伦",
          "album": "叶惠美",
          "picUrl": "https://...",
          "duration": 329029
        }
      ]
    }
  }
}
```

## 常见问题排查

### 1. 返回400错误

**错误信息**: `必须提供歌单ID参数` 或 `必须提供专辑ID参数`

**解决方案**: 确保URL中包含 `id` 参数
```bash
# 错误 ❌
curl "http://localhost:4055/playlist"

# 正确 ✅
curl "http://localhost:4055/playlist?id=19723756"
```

### 2. 返回500错误

**可能原因**:
- Cookie失效或格式错误
- 网易云API请求失败
- 歌单/专辑ID不存在或已被删除

**解决方案**:
1. 检查 `backend/cookie/cookie.txt` 文件
2. 确认Cookie包含 `MUSIC_U` 字段
3. 尝试使用已知存在的ID进行测试

### 3. 歌单tracks为空数组

**可能原因**:
- 歌单中的歌曲已全部下架
- Cookie权限不足
- 分批请求失败

**解决方案**:
1. 尝试其他歌单ID
2. 检查服务端日志查看详细错误
3. 更新Cookie

### 4. 响应时间过长

**可能原因**:
- 歌单歌曲数量过多（1000+首）
- 网络连接不稳定

**解决方案**:
1. 使用 `limit` 参数限制返回数量
2. 检查网络连接
3. 考虑添加客户端超时设置

## 日志查看

查看服务端日志以获取详细信息：

```bash
# 开发模式下，日志会直接输出到控制台
# 查看详细日志，确保 config.json 中 log_level 设置为 "DEV"
```

## 进一步测试

### 集成到 Flutter 应用

如果你想在 Flutter 应用中测试：

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> testPlaylist() async {
  final response = await http.get(
    Uri.parse('http://localhost:4055/playlist?id=19723756&limit=10'),
  );
  
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    print('歌单名称: ${data['data']['playlist']['name']}');
    print('歌曲数量: ${data['data']['playlist']['tracks'].length}');
  } else {
    print('请求失败: ${response.statusCode}');
  }
}
```

## 性能基准

### 参考数据（本地测试）

| 场景 | 歌曲数量 | 响应时间 |
|------|----------|----------|
| 小型歌单 | 20首 | ~200ms |
| 中型歌单 | 100首 | ~800ms |
| 大型歌单 | 500首 | ~3-5s |
| 专辑 | 12首 | ~150ms |

*注：实际性能取决于网络状况和服务器配置*

## 反馈与支持

如遇到问题，请提供以下信息：
1. 完整的请求URL
2. 返回的错误信息
3. 服务端日志输出
4. 使用的歌单/专辑ID

祝测试顺利！🎵

