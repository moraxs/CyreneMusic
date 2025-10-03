# 网易云音乐歌单和专辑解析 API 文档

## 概述

本文档描述了从 Python 版本移植到 Bun 版本的网易云音乐歌单和专辑解析功能。

## 功能特性

- ✅ 歌单详情解析
- ✅ 专辑详情解析
- ✅ 支持限制返回歌曲数量
- ✅ 批量获取歌曲信息（自动分批，每批最多100首）
- ✅ 完整的错误处理

## API 接口

### 1. 获取歌单详情

**接口地址**: `GET /playlist`

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| id | string | 是 | 歌单ID |
| limit | number | 否 | 限制返回歌曲数量，不填则返回全部 |

**请求示例**:
```bash
# 获取完整歌单
GET http://localhost:4055/playlist?id=123456789

# 限制返回前50首歌曲
GET http://localhost:4055/playlist?id=123456789&limit=50
```

**响应示例**:
```json
{
  "status": 200,
  "success": true,
  "data": {
    "playlist": {
      "id": 123456789,
      "name": "歌单名称",
      "coverImgUrl": "https://...",
      "creator": "创建者昵称",
      "trackCount": 100,
      "description": "歌单描述",
      "tags": ["流行", "华语"],
      "playCount": 1000000,
      "createTime": 1609459200000,
      "updateTime": 1640995200000,
      "tracks": [
        {
          "id": 123456,
          "name": "歌曲名称",
          "artists": "艺术家1/艺术家2",
          "album": "专辑名称",
          "picUrl": "https://...",
          "duration": 240000
        }
      ]
    }
  }
}
```

### 2. 获取专辑详情

**接口地址**: `GET /album`

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| id | string | 是 | 专辑ID |

**请求示例**:
```bash
GET http://localhost:4055/album?id=123456789
```

**响应示例**:
```json
{
  "status": 200,
  "success": true,
  "data": {
    "album": {
      "id": 123456789,
      "name": "专辑名称",
      "coverImgUrl": "https://...",
      "artist": "艺术家名称",
      "publishTime": 1609459200000,
      "description": "专辑描述",
      "company": "唱片公司",
      "size": 12,
      "songs": [
        {
          "id": 123456,
          "name": "歌曲名称",
          "artists": "艺术家名称",
          "album": "专辑名称",
          "picUrl": "https://...",
          "duration": 240000
        }
      ]
    }
  }
}
```

## 错误响应

当请求失败时，会返回以下格式的错误响应：

```json
{
  "status": 400/500,
  "success": false,
  "msg": "错误描述信息"
}
```

**常见错误**:

| 状态码 | 说明 |
|--------|------|
| 400 | 缺少必填参数（如未提供ID） |
| 500 | 服务器内部错误或网易云API调用失败 |

## 实现细节

### 与 Python 版本的对比

| 特性 | Python 版本 | Bun 版本 |
|------|-------------|----------|
| 歌单解析 | ✅ | ✅ |
| 专辑解析 | ✅ | ✅ |
| 批量获取 | ✅ (100首/批) | ✅ (100首/批) |
| 错误处理 | ✅ | ✅ |
| Cookie管理 | 文件读取 | 统一CookieManager |

### 技术实现

1. **歌单解析流程**:
   - 调用网易云 API 获取歌单基本信息
   - 提取所有歌曲ID
   - 分批（每批100首）获取歌曲详细信息
   - 合并并返回完整数据

2. **专辑解析流程**:
   - 调用网易云 API 获取专辑信息
   - 直接返回包含所有歌曲的详细信息

3. **Cookie处理**:
   - 使用统一的 CookieManager 管理网易云 Cookie
   - 自动从配置文件读取认证信息

## 使用示例

### JavaScript/TypeScript

```typescript
// 获取歌单详情
const response = await fetch('http://localhost:4055/playlist?id=123456789');
const data = await response.json();
console.log(data.data.playlist);

// 获取专辑详情
const albumResponse = await fetch('http://localhost:4055/album?id=987654321');
const albumData = await albumResponse.json();
console.log(albumData.data.album);
```

### cURL

```bash
# 获取歌单
curl "http://localhost:4055/playlist?id=123456789"

# 获取专辑
curl "http://localhost:4055/album?id=987654321"

# 限制歌单返回数量
curl "http://localhost:4055/playlist?id=123456789&limit=20"
```

## 注意事项

1. **Cookie要求**: 需要有效的网易云音乐 Cookie 才能访问高品质资源
2. **批量限制**: 歌单解析会自动分批处理，避免单次请求数据量过大
3. **网络超时**: 大型歌单（1000+首）可能需要较长时间处理
4. **速率限制**: 建议合理控制请求频率，避免被网易云限流

## 常见问题

### Q: 如何获取歌单/专辑ID？

A: 从网易云音乐网页版URL中提取：
- 歌单: `https://music.163.com/playlist?id=123456789` -> ID是 `123456789`
- 专辑: `https://music.163.com/album?id=987654321` -> ID是 `987654321`

### Q: 为什么有些歌单返回不完整？

A: 可能原因：
1. 歌单中某些歌曲已下架
2. Cookie权限不足
3. 网络请求超时

### Q: 如何提高大型歌单的解析速度？

A: 
1. 使用 `limit` 参数只获取需要的部分
2. 确保网络连接稳定
3. 考虑客户端缓存策略

## 更新日志

### v1.0.0 (2025-01-03)
- ✅ 从 Python 版本移植歌单解析功能
- ✅ 从 Python 版本移植专辑解析功能
- ✅ 支持分批获取歌曲信息
- ✅ 完善错误处理机制
- ✅ 添加详细的API文档

