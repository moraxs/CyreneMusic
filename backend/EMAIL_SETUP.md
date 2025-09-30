# 📧 邮件服务配置指南

## 🎯 配置方式：通过 config.json

所有邮件配置都在 `backend/config.json` 文件中管理，无需环境变量。

---

## ✅ 当前配置状态

已配置阿里云企业邮箱：
- **SMTP服务器**: `smtp.qiye.aliyun.com`
- **端口**: `465` (SSL)
- **发件人**: `noreply@cialloo.site`
- **状态**: ✅ 已启用，真实邮件发送

---

## 🔧 config.json 配置说明

### 完整配置示例

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

### 配置字段说明

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `EMAIL.host` | string | SMTP 服务器地址 | `smtp.qiye.aliyun.com` |
| `EMAIL.port` | number | SMTP 端口 | `465` (SSL) 或 `587` (TLS) |
| `EMAIL.secure` | boolean | 是否使用 SSL | `true` (465端口) 或 `false` (587端口) |
| `EMAIL.auth.user` | string | 发件邮箱地址 | `noreply@cialloo.site` |
| `EMAIL.auth.pass` | string | 邮箱密码/授权码 | `your-password` |
| `EMAIL.tls.rejectUnauthorized` | boolean | 是否验证证书 | `false` (开发环境) 或 `true` (生产环境) |

---

## 🔄 切换到开发模式

如果想要临时禁用真实邮件发送，在控制台输出验证码：

**方法 1: 移除 EMAIL 配置**
```json
{
  "bili_proxy": { ... },
  "log_level": "DEV"
  // 不包含 EMAIL 字段
}
```

**方法 2: 注释掉 EMAIL 字段**
```json
{
  "bili_proxy": { ... },
  "log_level": "DEV"
  // "EMAIL": { ... }  // 注释掉
}
```

重启服务后，验证码将输出到控制台：
```
[INFO ] - [DEV MODE] 注册验证码 - 邮箱: test@example.com, 用户名: testuser, 验证码: 123456
```

---

## 📮 常见邮箱服务器配置

### 阿里云企业邮箱（当前使用）
```json
"EMAIL": {
  "host": "smtp.qiye.aliyun.com",
  "port": 465,
  "secure": true,
  "auth": {
    "user": "your-email@yourdomain.com",
    "pass": "your-password"
  }
}
```

### Gmail
```json
"EMAIL": {
  "host": "smtp.gmail.com",
  "port": 587,
  "secure": false,
  "auth": {
    "user": "your-email@gmail.com",
    "pass": "your-app-password"
  }
}
```
⚠️ 需要开启"两步验证"并生成"应用专用密码"

### QQ 邮箱
```json
"EMAIL": {
  "host": "smtp.qq.com",
  "port": 587,
  "secure": false,
  "auth": {
    "user": "your-qq@qq.com",
    "pass": "your-authorization-code"
  }
}
```
⚠️ 需要在邮箱设置中开启 SMTP 服务，使用授权码而非 QQ 密码

### 163 邮箱
```json
"EMAIL": {
  "host": "smtp.163.com",
  "port": 465,
  "secure": true,
  "auth": {
    "user": "your-email@163.com",
    "pass": "your-authorization-code"
  }
}
```
⚠️ 需要开启 SMTP 服务并获取授权码

---

## 🧪 测试邮件发送

### 1. 重启后端服务
```bash
cd backend
bun run dev
```

### 2. 发送测试验证码
```bash
curl -X POST http://127.0.0.1:4055/auth/register/send-code \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "username": "testuser123"
  }'
```

### 3. 验证结果

**✅ 成功（真实邮件模式）：**
- HTTP 响应 200
- 邮件发送到目标邮箱
- 控制台日志：`[INFO] - [Auth] 注册验证码已发送到 test@example.com`

**✅ 成功（开发模式）：**
- HTTP 响应 200
- 控制台显示验证码：`[INFO] - [DEV MODE] 注册验证码 - ...验证码: 123456`

**❌ 失败：**
- HTTP 响应 500
- 检查 SMTP 配置是否正确
- 检查网络连接
- 查看详细错误日志

---

## 🐛 常见问题

### Q1: 邮件发送失败，报 "Connection timeout"
**A**: 
- 检查 SMTP 服务器地址和端口是否正确
- 确认服务器防火墙允许 SMTP 端口（465/587）
- 尝试切换端口（465 ↔ 587）并相应调整 `secure` 参数

### Q2: 报 "Invalid login" 或 "Authentication failed"
**A**: 
- 确认邮箱账号和密码正确
- QQ/163 邮箱需要使用授权码，不是登录密码
- Gmail 需要使用应用专用密码

### Q3: 报 "self signed certificate"
**A**: 
将 `tls.rejectUnauthorized` 设为 `false`：
```json
"tls": {
  "rejectUnauthorized": false
}
```

### Q4: 阿里云企业邮箱配置注意事项
**A**: 
- 端口使用 465，`secure: true`
- 确保企业邮箱账号已激活
- 检查邮箱管理后台是否限制了发信
- 使用完整邮箱地址作为 `user`

### Q5: 如何查看详细的邮件发送日志？
**A**: 
在 `config.json` 中设置 `"log_level": "DEV"`，可以看到详细的 HTTP 请求和响应日志。

---

## 🔒 安全建议

1. **不要将 `config.json` 提交到公开仓库**
   - 已在 `.gitignore` 中配置，但仍需注意
   - 如需分享，请移除 `EMAIL.auth.pass` 字段

2. **使用专用的邮箱账号**
   - 不要使用个人邮箱
   - 建议使用 `noreply@` 或 `no-reply@` 开头的邮箱

3. **定期更换密码**
   - 每 3-6 个月更换一次邮箱密码
   - 使用强密码（字母+数字+符号）

4. **监控发信量**
   - 设置合理的验证码有效期（当前 10 分钟）
   - 防止恶意用户频繁请求验证码

5. **生产环境建议**
   - 使用企业邮箱服务
   - 启用 SSL/TLS 加密
   - 设置 `rejectUnauthorized: true`

---

## 📊 配置优先级

系统按以下顺序读取配置：

1. ✅ `config.json` 中的 `EMAIL` 字段（推荐，当前使用）
2. ❌ 如果 `EMAIL` 字段不存在 → 启用开发模式（控制台输出验证码）

---

## 📚 相关文档

- [`QUICK_TEST.md`](./QUICK_TEST.md) - 快速测试指南
- [`docs/AUTH_API.md`](./docs/AUTH_API.md) - 认证 API 完整文档
- [Nodemailer 官方文档](https://nodemailer.com/)

---

## ✅ 快速检查清单

在启用真实邮件发送前，请确认：

- [ ] `config.json` 中已添加 `EMAIL` 配置
- [ ] SMTP 服务器地址和端口正确
- [ ] 邮箱账号和密码/授权码正确
- [ ] `secure` 参数与端口匹配（465→true, 587→false）
- [ ] 已测试发送验证码接口
- [ ] 目标邮箱收到了验证邮件
- [ ] 验证码格式正确（6位数字）

---

## 🎉 配置完成

配置完成后，你的应用将：
- ✅ 自动发送注册验证码到用户邮箱
- ✅ 自动发送密码重置验证码
- ✅ 使用精美的 HTML 邮件模板
- ✅ 10 分钟验证码有效期
- ✅ 防止验证码重复使用