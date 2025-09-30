import nodemailer from 'nodemailer';
import { getConfig } from './utils';
import { logger } from './logger';

// 创建邮件传输器
let transporter: nodemailer.Transporter | null = null;

// 检查是否为开发模式（开发模式下直接在控制台输出验证码）
// 如果 config.json 中没有配置 EMAIL 字段，则启用开发模式
async function checkDevelopmentMode(): Promise<boolean> {
  const config = await getConfig();
  return !config.EMAIL || !config.EMAIL.host;
}

let isDevelopment: boolean | null = null;

async function getTransporter() {
  if (transporter) return transporter;

  const config = await getConfig();
  
  // 从 config.json 读取邮件配置
  if (!config.EMAIL || !config.EMAIL.host) {
    throw new Error('邮件配置未设置，请在 config.json 中配置 EMAIL 字段');
  }

  transporter = nodemailer.createTransport(config.EMAIL);

  return transporter;
}

// 生成验证码（6位数字）
export function generateVerificationCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// 发送注册验证码邮件
export async function sendRegisterVerificationEmail(email: string, code: string, username: string) {
  // 检查是否为开发模式（延迟检查，避免启动时的异步问题）
  if (isDevelopment === null) {
    isDevelopment = await checkDevelopmentMode();
  }

  // 开发模式：直接在控制台输出验证码
  if (isDevelopment) {
    logger.info(`[DEV MODE] 注册验证码 - 邮箱: ${email}, 用户名: ${username}, 验证码: ${code}`);
    logger.warn(`[DEV MODE] 邮件未实际发送 - 验证码将在 10 分钟后过期`);
    return { accepted: [email], messageId: 'dev-mode' };
  }

  // 生产模式：实际发送邮件
  const transport = await getTransporter();
  const config = await getConfig();
  
  const mailOptions = {
    from: `"Cyrene Music" <${config.EMAIL.auth.user}>`,
    to: email,
    subject: '欢迎注册 Cyrene Music - 验证您的邮箱',
    html: getRegisterEmailTemplate(code, username),
  };

  return await transport.sendMail(mailOptions);
}

// 发送密码重置验证码邮件
export async function sendResetPasswordEmail(email: string, code: string, username: string) {
  // 检查是否为开发模式
  if (isDevelopment === null) {
    isDevelopment = await checkDevelopmentMode();
  }

  // 开发模式：直接在控制台输出验证码
  if (isDevelopment) {
    logger.info(`[DEV MODE] 重置密码验证码 - 邮箱: ${email}, 用户名: ${username}, 验证码: ${code}`);
    logger.warn(`[DEV MODE] 邮件未实际发送 - 验证码将在 10 分钟后过期`);
    return { accepted: [email], messageId: 'dev-mode' };
  }

  // 生产模式：实际发送邮件
  const transport = await getTransporter();
  const config = await getConfig();
  
  const mailOptions = {
    from: `"Cyrene Music" <${config.EMAIL.auth.user}>`,
    to: email,
    subject: 'Cyrene Music - 重置密码验证码',
    html: getResetPasswordEmailTemplate(code, username),
  };

  return await transport.sendMail(mailOptions);
}

// 注册邮件 HTML 模板
function getRegisterEmailTemplate(code: string, username: string): string {
  return `
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>验证您的邮箱</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Microsoft YaHei', sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      padding: 40px 20px;
    }
    .container {
      max-width: 600px;
      margin: 0 auto;
      background: white;
      border-radius: 16px;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
      overflow: hidden;
    }
    .header {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      padding: 40px 30px;
      text-align: center;
      color: white;
    }
    .logo {
      font-size: 36px;
      margin-bottom: 10px;
    }
    .header h1 {
      font-size: 28px;
      font-weight: 600;
      margin: 0;
    }
    .content {
      padding: 40px 30px;
    }
    .greeting {
      font-size: 20px;
      color: #333;
      margin-bottom: 20px;
    }
    .message {
      font-size: 16px;
      color: #666;
      line-height: 1.6;
      margin-bottom: 30px;
    }
    .code-container {
      background: linear-gradient(135deg, #f5f7fa 0%, #e4e8f0 100%);
      border-radius: 12px;
      padding: 30px;
      text-align: center;
      margin: 30px 0;
    }
    .code-label {
      font-size: 14px;
      color: #666;
      margin-bottom: 10px;
    }
    .code {
      font-size: 42px;
      font-weight: bold;
      color: #667eea;
      letter-spacing: 8px;
      font-family: 'Courier New', monospace;
    }
    .expiry {
      font-size: 14px;
      color: #999;
      margin-top: 15px;
    }
    .warning {
      background: #fff3cd;
      border-left: 4px solid #ffc107;
      padding: 15px;
      border-radius: 6px;
      margin: 20px 0;
    }
    .warning p {
      font-size: 14px;
      color: #856404;
      margin: 0;
    }
    .footer {
      background: #f8f9fa;
      padding: 30px;
      text-align: center;
      border-top: 1px solid #e9ecef;
    }
    .footer p {
      font-size: 14px;
      color: #6c757d;
      margin: 5px 0;
    }
    .footer a {
      color: #667eea;
      text-decoration: none;
    }
    .divider {
      height: 1px;
      background: linear-gradient(to right, transparent, #ddd, transparent);
      margin: 30px 0;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="logo">🎵</div>
      <h1>Cyrene Music</h1>
    </div>
    
    <div class="content">
      <div class="greeting">你好，${username}！</div>
      
      <div class="message">
        <p>感谢您注册 Cyrene Music！</p>
        <p>为了确保您的账户安全，请使用以下验证码完成注册：</p>
      </div>
      
      <div class="code-container">
        <div class="code-label">您的验证码</div>
        <div class="code">${code}</div>
        <div class="expiry">⏰ 验证码将在 10 分钟后过期</div>
      </div>
      
      <div class="warning">
        <p><strong>⚠️ 安全提示：</strong> 请勿将此验证码分享给任何人。Cyrene Music 的工作人员不会向您索要验证码。</p>
      </div>
      
      <div class="divider"></div>
      
      <div class="message">
        <p>如果您没有注册 Cyrene Music 账户，请忽略此邮件。</p>
      </div>
    </div>
    
    <div class="footer">
      <p><strong>Cyrene Music</strong></p>
      <p>您的跨平台音乐与视频播放器</p>
      <p style="margin-top: 15px;">
        <a href="#">帮助中心</a> · 
        <a href="#">服务条款</a> · 
        <a href="#">隐私政策</a>
      </p>
      <p style="margin-top: 15px; font-size: 12px;">
        © 2024 Cyrene Music. All rights reserved.
      </p>
    </div>
  </div>
</body>
</html>
  `;
}

// 重置密码邮件 HTML 模板
function getResetPasswordEmailTemplate(code: string, username: string): string {
  return `
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>重置密码</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Microsoft YaHei', sans-serif;
      background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
      padding: 40px 20px;
    }
    .container {
      max-width: 600px;
      margin: 0 auto;
      background: white;
      border-radius: 16px;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
      overflow: hidden;
    }
    .header {
      background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
      padding: 40px 30px;
      text-align: center;
      color: white;
    }
    .logo {
      font-size: 36px;
      margin-bottom: 10px;
    }
    .header h1 {
      font-size: 28px;
      font-weight: 600;
      margin: 0;
    }
    .content {
      padding: 40px 30px;
    }
    .greeting {
      font-size: 20px;
      color: #333;
      margin-bottom: 20px;
    }
    .message {
      font-size: 16px;
      color: #666;
      line-height: 1.6;
      margin-bottom: 30px;
    }
    .code-container {
      background: linear-gradient(135deg, #f5f7fa 0%, #e4e8f0 100%);
      border-radius: 12px;
      padding: 30px;
      text-align: center;
      margin: 30px 0;
    }
    .code-label {
      font-size: 14px;
      color: #666;
      margin-bottom: 10px;
    }
    .code {
      font-size: 42px;
      font-weight: bold;
      color: #f5576c;
      letter-spacing: 8px;
      font-family: 'Courier New', monospace;
    }
    .expiry {
      font-size: 14px;
      color: #999;
      margin-top: 15px;
    }
    .warning {
      background: #ffe6e6;
      border-left: 4px solid #dc3545;
      padding: 15px;
      border-radius: 6px;
      margin: 20px 0;
    }
    .warning p {
      font-size: 14px;
      color: #721c24;
      margin: 0;
    }
    .footer {
      background: #f8f9fa;
      padding: 30px;
      text-align: center;
      border-top: 1px solid #e9ecef;
    }
    .footer p {
      font-size: 14px;
      color: #6c757d;
      margin: 5px 0;
    }
    .footer a {
      color: #f5576c;
      text-decoration: none;
    }
    .divider {
      height: 1px;
      background: linear-gradient(to right, transparent, #ddd, transparent);
      margin: 30px 0;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="logo">🔒</div>
      <h1>重置密码</h1>
    </div>
    
    <div class="content">
      <div class="greeting">你好，${username}！</div>
      
      <div class="message">
        <p>我们收到了您重置密码的请求。</p>
        <p>请使用以下验证码来重置您的密码：</p>
      </div>
      
      <div class="code-container">
        <div class="code-label">验证码</div>
        <div class="code">${code}</div>
        <div class="expiry">⏰ 验证码将在 10 分钟后过期</div>
      </div>
      
      <div class="warning">
        <p><strong>⚠️ 重要安全提示：</strong></p>
        <p>• 请勿将此验证码分享给任何人</p>
        <p>• 如果您没有请求重置密码，请立即联系我们</p>
        <p>• Cyrene Music 的工作人员永远不会向您索要验证码</p>
      </div>
      
      <div class="divider"></div>
      
      <div class="message">
        <p>如果您没有请求重置密码，请忽略此邮件，您的密码将保持不变。</p>
      </div>
    </div>
    
    <div class="footer">
      <p><strong>Cyrene Music</strong></p>
      <p>您的跨平台音乐与视频播放器</p>
      <p style="margin-top: 15px;">
        <a href="#">帮助中心</a> · 
        <a href="#">服务条款</a> · 
        <a href="#">隐私政策</a>
      </p>
      <p style="margin-top: 15px; font-size: 12px;">
        © 2024 Cyrene Music. All rights reserved.
      </p>
    </div>
  </div>
</body>
</html>
  `;
}

export default { sendRegisterVerificationEmail, sendResetPasswordEmail, generateVerificationCode };
