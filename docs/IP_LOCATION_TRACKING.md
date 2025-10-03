# IP 归属地追踪功能说明

## 📝 功能概述

Cyrene Music 现已支持**自动记录用户最后一次登录的 IP 归属地**功能。每次用户登录成功后，系统会自动获取用户的 IP 地址和归属地信息，并将其保存到后端数据库中。

## ✨ 功能特点

- ✅ **自动化** - 用户登录后自动获取和上报，无需手动操作
- ✅ **非阻塞** - 异步执行，不影响登录流程
- ✅ **详细日志** - 完整的调试日志，便于追踪
- ✅ **错误容错** - IP 获取失败不影响正常登录
- ✅ **隐私友好** - 仅记录归属地信息，不存储敏感数据

## 🏗️ 技术实现

### 1️⃣ 后端部分

#### 数据库字段（users 表）

新增了以下字段：

| 字段名 | 类型 | 说明 |
|--------|------|------|
| `last_ip` | TEXT | 最后一次登录的 IP 地址 |
| `last_ip_location` | TEXT | IP 归属地（如：广东 深圳） |
| `last_ip_updated_at` | DATETIME | IP 更新时间 |

#### API 端点

**POST** `/auth/update-location`

**请求体：**
```json
{
  "userId": 1,
  "ip": "183.14.132.116",
  "location": "广东 深圳"
}
```

**响应示例：**
```json
{
  "code": 200,
  "message": "IP归属地更新成功",
  "data": {
    "userId": 1,
    "ip": "183.14.132.116",
    "location": "广东 深圳",
    "updatedAt": "2025-10-02T10:30:00.000Z"
  }
}
```

#### 数据库操作

```typescript
// 更新用户 IP 归属地
UserDB.updateIPLocation(userId: number, ip: string, location: string)
```

### 2️⃣ 前端部分

#### 服务方法

**AuthService.updateLocation()**

在 `lib/services/auth_service.dart` 中新增的方法：

```dart
/// 更新用户IP归属地
Future<Map<String, dynamic>> updateLocation() async {
  // 1. 检查用户是否已登录
  // 2. 获取IP归属地信息（调用 LocationService）
  // 3. 将数据发送到后端
  // 4. 返回结果
}
```

#### 集成位置

**登录页面** (`lib/pages/auth/login_page.dart`)

在用户登录成功后自动调用：

```dart
// 登录成功后，自动上报IP归属地（异步执行，不阻塞界面）
AuthService().updateLocation().then((locationResult) {
  if (locationResult['success']) {
    print('✅ IP归属地已更新: ${locationResult['data']['location']}');
  }
});
```

## 📊 数据流程

```
用户登录
   ↓
登录成功
   ↓
前端获取IP归属地
   ↓
https://drive-backend.cialloo.site/api/userip
   ↓
获取到: IP + 归属地信息
   ↓
发送到后端 POST /auth/update-location
   ↓
后端验证用户ID
   ↓
更新数据库 users 表
   ↓
返回成功响应
```

## 🔍 调试日志示例

### 前端日志

```
🌍 [AuthService] 开始获取IP归属地...
🌍 [LocationService] 开始获取IP归属地...
🌍 [LocationService] API URL: https://drive-backend.cialloo.site/api/userip
✅ [LocationService] 获取IP归属地完成！
🌍 [LocationService] IP: 183.14.132.116
🌍 [LocationService] 归属地: 广东 深圳
🌐 [Network] POST http://127.0.0.1:4055/auth/update-location
📤 [Network] 请求体: {"userId":1,"ip":"183.14.132.116","location":"广东 深圳"}
📥 [Network] 状态码: 200
✅ [AuthService] IP归属地更新成功: 广东 深圳
✅ [LoginPage] IP归属地已更新: 广东 深圳
```

### 后端日志

```
[Auth] 更新用户 张三 IP归属地: 广东 深圳 (183.14.132.116)
```

## 🎯 使用场景

1. **安全审计** - 追踪用户登录位置，发现异常登录
2. **用户分析** - 了解用户地理分布
3. **合规需求** - 满足某些地区的数据记录要求
4. **用户体验** - 可以在用户界面显示"上次登录地点"

## 🔐 隐私说明

- ✅ **仅记录归属地** - 不记录精确坐标
- ✅ **仅在登录时更新** - 不进行持续追踪
- ✅ **用户可见** - 用户可以查看自己的登录记录（需前端实现）
- ✅ **不对外暴露** - 归属地信息仅供内部使用

## 📝 数据示例

### 数据库记录示例

```sql
SELECT id, username, email, last_ip, last_ip_location, last_ip_updated_at 
FROM users 
WHERE id = 1;
```

| id | username | email | last_ip | last_ip_location | last_ip_updated_at |
|----|----------|-------|---------|-----------------|-------------------|
| 1 | 张三 | user@qq.com | 183.14.132.116 | 广东 深圳 | 2025-10-02 10:30:00 |

## 🚀 未来扩展

可以考虑的增强功能：

1. **登录历史** - 记录多次登录记录，而不仅仅是最后一次
2. **异常检测** - 检测来自不同国家/地区的登录，发送通知
3. **用户界面** - 在设置页面显示登录历史
4. **IP黑名单** - 支持封禁特定 IP 或地区
5. **登录地图** - 可视化展示用户登录位置分布

## 🐛 故障排除

### 问题1：IP归属地获取失败

**可能原因：**
- LocationService API 不可用
- 网络连接问题

**影响：**
- 不影响登录流程
- 数据库字段保持原值

**日志标识：**
```
❌ [AuthService] 获取IP归属地失败
⚠️ [LoginPage] IP归属地更新失败
```

### 问题2：后端更新失败

**可能原因：**
- 后端服务器不可用
- 用户ID不存在

**影响：**
- 不影响登录流程
- 数据库不更新

**日志标识：**
```
❌ [AuthService] IP归属地更新失败
```

### 问题3：数据库字段不存在

**可能原因：**
- 旧数据库未迁移

**解决方案：**
- 重启后端服务器，字段会自动创建
- 或手动执行 SQL：
  ```sql
  ALTER TABLE users ADD COLUMN last_ip TEXT;
  ALTER TABLE users ADD COLUMN last_ip_location TEXT;
  ALTER TABLE users ADD COLUMN last_ip_updated_at DATETIME;
  ```

## 📚 相关文件

### 后端

- `backend/src/lib/database.ts` - 数据库模型和操作
- `backend/src/lib/authController.ts` - 认证控制器
- `backend/src/index.ts` - API 路由定义

### 前端

- `lib/services/auth_service.dart` - 认证服务
- `lib/services/location_service.dart` - IP归属地服务
- `lib/pages/auth/login_page.dart` - 登录页面

## ✅ 版本信息

- **功能版本**: v1.1.0
- **添加日期**: 2025-10-02
- **兼容性**: 需要后端 v1.0.2+ 和前端 v1.0.0+

## 📞 技术支持

如有问题，请查看：
- 开发者模式日志（前端）
- 后端控制台日志
- 数据库 users 表记录

---

**注意**: 此功能完全自动化，用户无需进行任何操作。所有的 IP 归属地信息获取和上报都在后台静默进行。

