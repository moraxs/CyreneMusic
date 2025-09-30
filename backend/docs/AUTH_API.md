# 用户认证 API 文档

## 📋 概述

本文档描述了 Cyrene Music 的用户认证 API，包括注册、登录和密码重置功能。

## 🔐 API 端点

### 1. 发送注册验证码

**端点**: `POST /auth/register/send-code`

**描述**: 向用户邮箱发送注册验证码

**请求体**:
```json
{
  "email": "user@example.com",
  "username": "myusername"
}
```

**字段说明**:
- `email` (string, 必填): 用户邮箱，必须是有效的邮箱格式
- `username` (string, 必填): 用户名，4-20个字符，仅包含字母、数字和下划线

**成功响应** (200):
```json
{
  "code": 200,
  "message": "验证码已发送到您的邮箱，请查收",
  "data": {
    "email": "user@example.com",
    "expiresIn": 600
  }
}
```

**错误响应**:

- **400 Bad Request** - 邮箱格式不正确
```json
{
  "code": 400,
  "message": "邮箱格式不正确"
}
```

- **400 Bad Request** - 用户名格式不正确
```json
{
  "code": 400,
  "message": "用户名格式不正确（4-20个字符，仅字母数字下划线）"
}
```

- **400 Bad Request** - 邮箱已被注册
```json
{
  "code": 400,
  "message": "该邮箱已被注册"
}
```

- **400 Bad Request** - 用户名已被使用
```json
{
  "code": 400,
  "message": "该用户名已被使用"
}
```

---

### 2. 用户注册

**端点**: `POST /auth/register`

**描述**: 使用邮箱验证码完成用户注册

**请求体**:
```json
{
  "email": "user@example.com",
  "username": "myusername",
  "password": "mypassword123",
  "code": "123456"
}
```

**字段说明**:
- `email` (string, 必填): 用户邮箱
- `username` (string, 必填): 用户名
- `password` (string, 必填): 密码，至少8个字符
- `code` (string, 必填): 6位邮箱验证码

**成功响应** (200):
```json
{
  "code": 200,
  "message": "注册成功",
  "data": {
    "id": 1,
    "email": "user@example.com",
    "username": "myusername",
    "createdAt": "2024-01-01T00:00:00.000Z"
  }
}
```

**错误响应**:

- **400 Bad Request** - 验证码无效或已过期
```json
{
  "code": 400,
  "message": "验证码无效或已过期"
}
```

- **400 Bad Request** - 密码强度不足
```json
{
  "code": 400,
  "message": "密码长度至少为8个字符"
}
```

---

### 3. 用户登录

**端点**: `POST /auth/login`

**描述**: 使用邮箱/用户名和密码登录

**请求体**:
```json
{
  "account": "user@example.com",
  "password": "mypassword123"
}
```

**字段说明**:
- `account` (string, 必填): 邮箱或用户名
- `password` (string, 必填): 密码

**成功响应** (200):
```json
{
  "code": 200,
  "message": "登录成功",
  "data": {
    "id": 1,
    "email": "user@example.com",
    "username": "myusername",
    "isVerified": true,
    "lastLogin": "2024-01-01T00:00:00.000Z"
  }
}
```

**错误响应**:

- **401 Unauthorized** - 账号或密码错误
```json
{
  "code": 401,
  "message": "账号或密码错误"
}
```

---

### 4. 发送重置密码验证码

**端点**: `POST /auth/reset-password/send-code`

**描述**: 向用户邮箱发送密码重置验证码

**请求体**:
```json
{
  "email": "user@example.com"
}
```

**字段说明**:
- `email` (string, 必填): 用户邮箱

**成功响应** (200):
```json
{
  "code": 200,
  "message": "验证码已发送到您的邮箱，请查收",
  "data": {
    "email": "user@example.com",
    "expiresIn": 600
  }
}
```

**注意**: 为了安全考虑，即使邮箱不存在也会返回成功响应，以防止邮箱枚举攻击。

---

### 5. 重置密码

**端点**: `POST /auth/reset-password`

**描述**: 使用验证码重置密码

**请求体**:
```json
{
  "email": "user@example.com",
  "code": "123456",
  "newPassword": "newpassword123"
}
```

**字段说明**:
- `email` (string, 必填): 用户邮箱
- `code` (string, 必填): 6位验证码
- `newPassword` (string, 必填): 新密码，至少8个字符

**成功响应** (200):
```json
{
  "code": 200,
  "message": "密码重置成功，请使用新密码登录"
}
```

**错误响应**:

- **400 Bad Request** - 验证码无效或已过期
```json
{
  "code": 400,
  "message": "验证码无效或已过期"
}
```

- **404 Not Found** - 用户不存在
```json
{
  "code": 404,
  "message": "用户不存在"
}
```

---

## 🔒 安全特性

### 密码安全
- 使用 bcrypt 加密存储密码
- 密码最小长度：8个字符
- 建议密码包含大小写字母、数字和特殊字符

### 验证码安全
- 验证码有效期：10分钟
- 6位数字验证码
- 验证码使用后自动失效
- 定期清理过期验证码

### 邮箱安全
- 邮箱必须通过格式验证
- 注册后自动标记为已验证
- 防止重复注册

### 用户名规则
- 长度：4-20个字符
- 允许字符：字母（a-z, A-Z）、数字（0-9）、下划线（_）
- 用户名全局唯一

---

## 📧 邮件模板

### 注册验证码邮件
- **主题**: "欢迎注册 Cyrene Music - 验证您的邮箱"
- **内容**: 现代化的 HTML 模板，紫色渐变主题
- **包含**: 
  - 验证码（大号显示）
  - 有效期提醒
  - 安全提示

### 重置密码邮件
- **主题**: "Cyrene Music - 重置密码验证码"
- **内容**: 现代化的 HTML 模板，粉红色渐变主题
- **包含**:
  - 验证码（大号显示）
  - 有效期提醒
  - 安全警告

---

## 🗄️ 数据库结构

### users 表
```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE NOT NULL,
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  is_verified INTEGER DEFAULT 0,
  verified_at DATETIME,
  last_login DATETIME
);
```

### verification_codes 表
```sql
CREATE TABLE verification_codes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL,
  code TEXT NOT NULL,
  type TEXT NOT NULL,
  expires_at DATETIME NOT NULL,
  used INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

---

## 🧪 测试示例

### 使用 curl 测试

#### 1. 发送注册验证码
```bash
curl -X POST http://localhost:4055/auth/register/send-code \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "username": "testuser"
  }'
```

#### 2. 注册用户
```bash
curl -X POST http://localhost:4055/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "username": "testuser",
    "password": "password123",
    "code": "123456"
  }'
```

#### 3. 用户登录
```bash
curl -X POST http://localhost:4055/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "account": "testuser",
    "password": "password123"
  }'
```

#### 4. 发送重置密码验证码
```bash
curl -X POST http://localhost:4055/auth/reset-password/send-code \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com"
  }'
```

#### 5. 重置密码
```bash
curl -X POST http://localhost:4055/auth/reset-password \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "code": "123456",
    "newPassword": "newpassword123"
  }'
```

---

## 📝 注意事项

1. **邮件配置**: 确保在 `config.json` 中正确配置邮件服务器信息
2. **数据库文件**: SQLite 数据库文件保存在 `data/users.db`
3. **验证码清理**: 系统每小时自动清理过期的验证码
4. **密码加密**: 使用 bcrypt 进行密码哈希，salt rounds = 10
5. **错误处理**: 所有 API 都有完整的错误处理和验证

---

## 🔄 工作流程

### 注册流程
```
用户输入邮箱和用户名
    ↓
调用 /auth/register/send-code
    ↓
系统检查邮箱和用户名是否可用
    ↓
生成6位验证码
    ↓
发送验证邮件
    ↓
用户输入验证码和密码
    ↓
调用 /auth/register
    ↓
验证验证码
    ↓
创建用户账号
    ↓
标记邮箱已验证
```

### 登录流程
```
用户输入账号和密码
    ↓
调用 /auth/login
    ↓
查找用户（邮箱或用户名）
    ↓
验证密码
    ↓
更新最后登录时间
    ↓
返回用户信息
```

### 重置密码流程
```
用户输入邮箱
    ↓
调用 /auth/reset-password/send-code
    ↓
生成验证码
    ↓
发送验证邮件
    ↓
用户输入验证码和新密码
    ↓
调用 /auth/reset-password
    ↓
验证验证码
    ↓
更新密码
```
