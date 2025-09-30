# 🧪 邮件服务修复验证指南

## ✅ 修复内容

已修复以下问题：
1. ❌ **旧问题**: 邮件配置错误（端口80与SSL冲突）
2. ❌ **旧问题**: 缺少配置导致解构赋值失败
3. ✅ **新方案**: 所有配置集中在 `config.json` 中管理
4. ✅ **已配置**: 阿里云企业邮箱，支持真实邮件发送

---

## 📋 当前配置

### config.json
```json
{
  "bili_proxy": {
    "enabled": true,
    "url": "http://47.104.188.206:4056"
  },
  "log_level": "DEV",
  "EMAIL": {
    "host": "smtp.qiye.aliyun.com",
    "port": 465,
    "secure": true,
    "auth": {
      "user": "noreply@cialloo.site",
      "pass": "Qwaszx1233"
    },
    "tls": {
      "rejectUnauthorized": false
    }
  }
}
```

**工作模式**: 生产模式（真实邮件发送）

---

## 🚀 快速测试步骤

### 1️⃣ 重启后端服务

```bash
cd backend
bun run dev
```

### 2️⃣ 查看启动日志

你应该看到类似的输出：
```
Server running at http://0.0.0.0:4055
[INFO ] - [Config] Loaded config.json successfully.
[INFO ] - [Config] Log level: DEV
  === User Authentication ===
  - POST /auth/register/send-code (Send Register Code)
  - POST /auth/register (Register)
  - POST /auth/login (Login)
  - POST /auth/reset-password/send-code (Send Reset Code)
  - POST /auth/reset-password (Reset Password)
```

### 3️⃣ 测试发送验证码

**使用 curl 测试：**

```bash
curl -X POST http://127.0.0.1:4055/auth/register/send-code \
  -H "Content-Type: application/json" \
  -d '{
    "email": "your-test-email@example.com",
    "username": "testuser123"
  }'
```

⚠️ **重要**: 请使用真实的邮箱地址进行测试！

### 4️⃣ 验证结果

#### ✅ 成功的响应（HTTP 200）

```json
{
  "code": 200,
  "message": "验证码已发送到您的邮箱，请查收",
  "data": {
    "email": "your-test-email@example.com",
    "expiresIn": 600
  }
}
```

#### ✅ 后端日志输出

```
2025-10-01 00:30:00 [INFO ] - [Auth] 注册验证码已发送到 your-test-email@example.com
```

#### ✅ 检查邮箱

1. 打开你的测试邮箱
2. 查找来自 `Cyrene Music <noreply@cialloo.site>` 的邮件
3. 主题：**欢迎注册 Cyrene Music - 验证您的邮箱**
4. 邮件中会显示 6 位数字验证码

---

## 📝 完整注册流程测试

### 步骤 1: 发送验证码
```bash
curl -X POST http://127.0.0.1:4055/auth/register/send-code \
  -H "Content-Type: application/json" \
  -d '{
    "email": "your-email@example.com",
    "username": "testuser123"
  }'
```

### 步骤 2: 检查邮箱，获取验证码
- 打开邮箱，查找验证码（例如：`123456`）
- 验证码有效期：10 分钟

### 步骤 3: 完成注册
```bash
curl -X POST http://127.0.0.1:4055/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "your-email@example.com",
    "username": "testuser123",
    "password": "SecurePassword123!",
    "code": "123456"
  }'
```

**成功响应：**
```json
{
  "code": 200,
  "message": "注册成功",
  "data": {
    "id": 1,
    "email": "your-email@example.com",
    "username": "testuser123",
    "createdAt": "2025-10-01T00:30:00.000Z"
  }
}
```

### 步骤 4: 登录测试
```bash
curl -X POST http://127.0.0.1:4055/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "account": "testuser123",
    "password": "SecurePassword123!"
  }'
```

**成功响应：**
```json
{
  "code": 200,
  "message": "登录成功",
  "data": {
    "id": 1,
    "email": "your-email@example.com",
    "username": "testuser123",
    "isVerified": true,
    "lastLogin": "2025-10-01T00:35:00.000Z"
  }
}
```

---

## 🔄 测试密码重置功能

### 步骤 1: 发送重置密码验证码
```bash
curl -X POST http://127.0.0.1:4055/auth/reset-password/send-code \
  -H "Content-Type: application/json" \
  -d '{
    "email": "your-email@example.com"
  }'
```

### 步骤 2: 检查邮箱获取验证码
- 主题：**Cyrene Music - 重置密码验证码**
- 获取 6 位数字验证码

### 步骤 3: 重置密码
```bash
curl -X POST http://127.0.0.1:4055/auth/reset-password \
  -H "Content-Type: application/json" \
  -d '{
    "email": "your-email@example.com",
    "code": "654321",
    "newPassword": "NewSecurePassword123!"
  }'
```

### 步骤 4: 使用新密码登录
```bash
curl -X POST http://127.0.0.1:4055/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "account": "your-email@example.com",
    "password": "NewSecurePassword123!"
  }'
```

---

## ❌ 可能的错误及解决方案

### 错误 1: `该邮箱已被注册`
**原因**: 该邮箱已经注册过了  
**解决**: 
- 更换邮箱地址
- 或删除数据库重新测试：
  ```bash
  rm backend/data/users.db
  ```

### 错误 2: `验证码无效或已过期`
**原因**: 
- 验证码输入错误（检查是否有空格）
- 验证码已过期（10分钟有效期）
- 验证码已被使用（每个验证码只能用一次）

**解决**: 重新发送验证码

### 错误 3: `用户名格式不正确`
**原因**: 用户名不符合要求  
**要求**: 4-20个字符，仅字母、数字、下划线  
**示例**: ✅ `user123`, `test_user` | ❌ `us`, `user@123`, `用户名`

### 错误 4: `密码长度至少为8个字符`
**原因**: 密码太短  
**解决**: 使用至少 8 个字符的密码，建议包含字母、数字、符号

### 错误 5: 邮件发送失败
**可能原因**:
- SMTP 服务器连接失败
- 邮箱账号或密码错误
- 网络防火墙阻止 465 端口

**排查步骤**:
1. 检查 `config.json` 中的 `EMAIL` 配置
2. 确认 SMTP 服务器地址和端口正确
3. 测试网络连接：
   ```bash
   telnet smtp.qiye.aliyun.com 465
   ```
4. 查看后端详细错误日志

---

## 🔄 切换到开发模式（可选）

如果你想临时禁用真实邮件发送，只在控制台输出验证码：

### 方法：移除 EMAIL 配置

编辑 `backend/config.json`：
```json
{
  "bili_proxy": {
    "enabled": true,
    "url": "http://47.104.188.206:4056"
  },
  "log_level": "DEV"
  // 移除或注释掉 EMAIL 字段
}
```

重启服务后，验证码会输出到控制台：
```
[INFO ] - [DEV MODE] 注册验证码 - 邮箱: test@example.com, 用户名: testuser123, 验证码: 123456
[WARN ] - [DEV MODE] 邮件未实际发送 - 验证码将在 10 分钟后过期
```

---

## 🎯 预期行为对比

### ❌ 修复前（错误状态）
```
2025-10-01 00:05:01 [ERROR] - [Auth] 发送注册验证码失败: Right side of assignment cannot be destructured
```

### ✅ 修复后（生产模式）
```
2025-10-01 00:30:00 [INFO ] - [Auth] 注册验证码已发送到 your-email@example.com
```

**邮箱收到精美的 HTML 邮件：**
- 🎵 Cyrene Music 品牌 Logo
- 6 位数字验证码（大字体显示）
- 10 分钟倒计时提示
- 安全提示信息

---

## 🔍 故障排查

### 检查 1: 确认服务正常运行
```bash
curl http://127.0.0.1:4055/
```
应该返回: `OK`

### 检查 2: 查看配置是否加载
```bash
cat backend/config.json | grep EMAIL
```
确认 `EMAIL` 字段存在且配置正确

### 检查 3: 测试 SMTP 连接
```bash
# Windows (PowerShell)
Test-NetConnection smtp.qiye.aliyun.com -Port 465

# Linux/macOS
telnet smtp.qiye.aliyun.com 465
# 或
nc -zv smtp.qiye.aliyun.com 465
```

### 检查 4: 查看数据库
```bash
# 查看用户表
sqlite3 backend/data/users.db "SELECT * FROM users;"

# 查看最近的验证码记录
sqlite3 backend/data/users.db "SELECT * FROM verification_codes ORDER BY created_at DESC LIMIT 5;"

# 查看特定邮箱的验证码
sqlite3 backend/data/users.db "SELECT * FROM verification_codes WHERE email='your-email@example.com' ORDER BY created_at DESC;"
```

### 检查 5: 查看详细日志
确保 `config.json` 中 `log_level` 设置为 `"DEV"`，可以看到完整的请求和响应数据。

---

## 📧 邮件内容预览

### 注册验证邮件
```
主题: 欢迎注册 Cyrene Music - 验证您的邮箱
发件人: Cyrene Music <noreply@cialloo.site>

你好，testuser123！

感谢您注册 Cyrene Music！
为了确保您的账户安全，请使用以下验证码完成注册：

┌─────────────────┐
│  您的验证码      │
│    123456       │
│ ⏰ 10分钟后过期  │
└─────────────────┘

⚠️ 安全提示：请勿将此验证码分享给任何人。
```

### 密码重置邮件
```
主题: Cyrene Music - 重置密码验证码
发件人: Cyrene Music <noreply@cialloo.site>

你好，testuser123！

我们收到了您重置密码的请求。
请使用以下验证码来重置您的密码：

┌─────────────────┐
│   验证码        │
│    654321       │
│ ⏰ 10分钟后过期  │
└─────────────────┘

⚠️ 重要安全提示：
• 请勿将此验证码分享给任何人
• 如果您没有请求重置密码，请立即联系我们
```

---

## 📞 需要帮助？

如果测试失败，请提供以下信息：
1. 完整的错误日志（包括时间戳）
2. 请求的 JSON 数据
3. 后端控制台输出
4. `backend/config.json` 内容（移除密码）
5. 网络环境信息（是否有防火墙/代理）

---

## 🎉 测试成功标志

确认以下所有项目都成功：

- [x] ✅ 服务启动无错误
- [x] ✅ 发送验证码接口返回 200
- [x] ✅ 后端日志显示"验证码已发送"
- [x] ✅ 目标邮箱收到验证邮件
- [x] ✅ 邮件格式美观，验证码清晰
- [x] ✅ 验证码可用于注册
- [x] ✅ 注册成功
- [x] ✅ 登录成功
- [x] ✅ 密码重置功能正常

---

## 📚 相关文档

- [`EMAIL_SETUP.md`](./EMAIL_SETUP.md) - 详细的邮件配置指南
- [`docs/AUTH_API.md`](./docs/AUTH_API.md) - 认证 API 完整文档
- [`config.json`](./config.json) - 配置文件示例