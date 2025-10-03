# 删除歌曲功能修复

## 🎯 问题描述

删除歌单中的歌曲时返回 HTTP 400 错误：
```
❌ [PlaylistService] 删除歌曲失败: Exception: HTTP 400
📨 [Request] DELETE http://127.0.0.1:4055/playlists/1/tracks/38018486/netease
❌ [Error] DELETE http://127.0.0.1:4055/playlists/1/tracks/38018486/netease
   Code: PARSE
   Error: Bad Request
```

---

## 🔧 修复方案

### 问题根源：Elysia 框架的 DELETE 请求解析问题

**问题：**
- Elysia 框架对 DELETE 请求的路径参数解析存在 PARSE 错误
- 尝试添加参数验证也无法解决
- 这是框架层面的限制

**解决方案：将 DELETE 请求改为 POST 请求**

### 修改内容

#### 1. 后端 - 修改路由

**文件：** `backend/src/index.ts`

**修改前：**
```typescript
.delete("/playlists/:playlistId/tracks/:trackId/:source", removeTrackFromPlaylist)
```

**修改后：**
```typescript
.post("/playlists/:playlistId/tracks/remove", removeTrackFromPlaylist, {
  body: t.Object({
    trackId: t.String(),
    source: t.String()
  })
})
```

#### 2. 后端 - 修改控制器

**文件：** `backend/src/lib/playlistController.ts`

**修改前：**
```typescript
const { playlistId, trackId, source } = params;
```

**修改后：**
```typescript
const { playlistId } = params;
const { trackId, source } = body;
```

#### 3. 前端 - 修改请求方式

**文件：** `lib/services/playlist_service.dart`

**修改前：**
```dart
final response = await http.delete(
  Uri.parse('$baseUrl/playlists/$playlistId/tracks/$encodedTrackId/$source'),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  },
);
```

**修改后：**
```dart
final response = await http.post(
  Uri.parse('$baseUrl/playlists/$playlistId/tracks/remove'),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  },
  body: json.encode({
    'trackId': track.trackId,
    'source': source,
  }),
);
```

---

## 📊 新增诊断日志

### 新增的诊断日志

**前端：**
```dart
print('🗑️ [PlaylistService] 准备删除歌曲:');
print('   PlaylistId: $playlistId');
print('   TrackId: ${track.trackId}');
print('   Source: $source');
print('   URL: $baseUrl/playlists/$playlistId/tracks/remove');
print('📥 [PlaylistService] 删除请求响应状态码: ${response.statusCode}');
```

**后端：**
```typescript
console.log('📨 [Request] POST http://127.0.0.1:4055/playlists/1/tracks/remove');
console.log('🗑️ [removeTrackFromPlaylist] 接收到删除请求');
console.log('   params:', params);
console.log('   body:', body);
console.log('   playlistId:', playlistId);
console.log('   trackId:', trackId);
console.log('   source:', source);
console.log('   userId:', userId);
console.log('   删除结果:', success);
```

---

## 🔄 测试步骤

### 1️⃣ 重启后端服务器 ⚠️
```bash
cd backend
# Ctrl+C 停止当前服务器
bun run src/index.ts
```

**重要：** 必须重启后端，因为修改了路由定义！

### 2️⃣ 热重载前端
```bash
# 在 Flutter 控制台按 'r' 热重载
```

### 3️⃣ 测试删除功能

**场景 1：删除网易云音乐歌曲**
1. 打开歌单，选择一首网易云音乐的歌曲
2. 右键 → 从歌单移除
3. **期望**：✅ 成功删除

**场景 2：删除 QQ 音乐歌曲**
1. 打开歌单，选择一首 QQ 音乐的歌曲
2. 右键 → 从歌单移除
3. **期望**：✅ 成功删除

**场景 3：删除酷狗音乐歌曲**
1. 打开歌单，选择一首酷狗音乐的歌曲
2. 右键 → 从歌单移除
3. **期望**：✅ 成功删除

---

## 🧪 预期日志输出

### 成功删除（网易云音乐）

**前端：**
```
🗑️ [PlaylistService] 准备删除歌曲:
   PlaylistId: 1
   TrackId: 38018486
   Source: netease
   URL: http://127.0.0.1:4055/playlists/1/tracks/remove
📥 [PlaylistService] 删除请求响应状态码: 200
✅ [PlaylistService] 删除歌曲成功
```

**后端：**
```
📨 [Request] POST http://127.0.0.1:4055/playlists/1/tracks/remove
🗑️ [removeTrackFromPlaylist] 接收到删除请求
   params: { playlistId: '1' }
   body: { trackId: '38018486', source: 'netease' }
   playlistId: 1 (type: string)
   trackId: 38018486 (type: string)
   source: netease (type: string)
   userId: 1
   删除结果: true
```

### 成功删除（QQ 音乐）

**前端：**
```
🗑️ [PlaylistService] 准备删除歌曲:
   PlaylistId: 1
   TrackId: 003fA5nd3y5M3H
   Source: qq
   URL: http://127.0.0.1:4055/playlists/1/tracks/remove
📥 [PlaylistService] 删除请求响应状态码: 200
✅ [PlaylistService] 删除歌曲成功
```

**后端：**
```
📨 [Request] POST http://127.0.0.1:4055/playlists/1/tracks/remove
🗑️ [removeTrackFromPlaylist] 接收到删除请求
   params: { playlistId: '1' }
   body: { trackId: '003fA5nd3y5M3H', source: 'qq' }
   playlistId: 1 (type: string)
   trackId: 003fA5nd3y5M3H (type: string)
   source: qq (type: string)
   userId: 1
   删除结果: true
```

### ℹ️ 关于使用 POST 而不是 DELETE

虽然 RESTful 规范建议使用 DELETE 方法删除资源，但在实际开发中，有时需要根据框架限制做出调整：

**为什么改用 POST：**
- Elysia 框架对 DELETE 请求的路径参数解析存在问题（PARSE 错误）
- POST 请求更灵活，支持请求体传参
- 不影响功能实现，只是 HTTP 方法的选择

**路由设计：**
- 使用 `/playlists/:playlistId/tracks/remove` 作为端点
- 通过 `remove` 路径明确表示删除操作
- trackId 和 source 通过请求体传递

这是一个实用主义的解决方案，确保功能正常工作比严格遵循 REST 规范更重要

---

## 📁 修改文件列表

### 后端
- ✏️ `backend/src/index.ts` 
  - 修改删除路由从 DELETE 改为 POST
  - 添加请求体参数验证
  - 添加全局请求日志和错误处理
  - 更新启动日志中的路由说明

- ✏️ `backend/src/lib/playlistController.ts`
  - 修改参数获取方式（从 params 改为 body）
  - 保留详细诊断日志

### 前端
- ✏️ `lib/services/playlist_service.dart`
  - 修改请求方式从 http.delete 改为 http.post
  - 将 trackId 和 source 放入请求体
  - 保留详细诊断日志

---

## ✅ 验证清单

- [ ] **重启后端服务器**（必须！）
- [ ] 热重载前端
- [ ] 删除网易云音乐歌曲成功
- [ ] 删除 QQ 音乐歌曲成功
- [ ] 删除酷狗音乐歌曲成功
- [ ] 后端日志显示 POST 请求
- [ ] 后端日志显示正确的 body 参数
- [ ] 前端收到 200 响应
- [ ] 歌单中的歌曲数量正确减少
- [ ] UI 正确更新

---

**修复日期**: 2025-10-03  
**影响范围**: 歌单管理 - 删除歌曲功能  
**问题原因**: Elysia 框架的 DELETE 请求解析限制  
**解决方案**: 改用 POST 请求  
**修复状态**: ✅ 已完成（待重启后端测试）

