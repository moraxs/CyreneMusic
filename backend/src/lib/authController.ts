import { Context } from 'elysia';
import { UserDB, VerificationCodeDB } from './database';
import { 
  sendRegisterVerificationEmail, 
  sendResetPasswordEmail, 
  generateVerificationCode 
} from './emailService';
import { logger } from './logger';
import { validateQQEmail, getQQAvatarUrl } from './qqAvatar';

// 发送注册验证码
export async function sendRegisterCode(ctx: Context) {
  const { email, username } = ctx.body as { email: string; username: string };

  // 验证输入
  if (!email || !username) {
    ctx.set.status = 400;
    return { code: 400, message: '邮箱和用户名不能为空' };
  }

  // 验证 QQ 邮箱格式
  const emailValidation = validateQQEmail(email);
  if (!emailValidation.valid) {
    ctx.set.status = 400;
    return { code: 400, message: emailValidation.message };
  }

  // 验证用户名格式（4-20个字符，字母数字下划线）
  const usernameRegex = /^[a-zA-Z0-9_]{4,20}$/;
  if (!usernameRegex.test(username)) {
    ctx.set.status = 400;
    return { code: 400, message: '用户名格式不正确（4-20个字符，仅字母数字下划线）' };
  }

  try {
    // 检查邮箱是否已注册
    const existingUser = UserDB.findByEmail(email);
    if (existingUser) {
      ctx.set.status = 400;
      return { code: 400, message: '该邮箱已被注册' };
    }

    // 检查用户名是否已被使用
    const existingUsername = UserDB.findByUsername(username);
    if (existingUsername) {
      ctx.set.status = 400;
      return { code: 400, message: '该用户名已被使用' };
    }

    // 生成验证码
    const code = generateVerificationCode();

    // 保存验证码到数据库
    VerificationCodeDB.create(email, code, 'register', 10);

    // 发送邮件
    await sendRegisterVerificationEmail(email, code, username);

    logger.info(`[Auth] 注册验证码已发送到 ${email}`);

    return {
      code: 200,
      message: '验证码已发送到您的邮箱，请查收',
      data: {
        email,
        expiresIn: 600 // 10分钟
      }
    };
  } catch (error: any) {
    logger.error(`[Auth] 发送注册验证码失败: ${error.message}`);
    ctx.set.status = 500;
    return { code: 500, message: '发送验证码失败，请稍后重试' };
  }
}

// 用户注册
export async function register(ctx: Context) {
  const { email, username, password, code } = ctx.body as {
    email: string;
    username: string;
    password: string;
    code: string;
  };

  // 验证输入
  if (!email || !username || !password || !code) {
    ctx.set.status = 400;
    return { code: 400, message: '所有字段都不能为空' };
  }

  // 验证密码强度（至少8个字符）
  if (password.length < 8) {
    ctx.set.status = 400;
    return { code: 400, message: '密码长度至少为8个字符' };
  }

  try {
    // 验证验证码
    const verificationCode = VerificationCodeDB.findValid(email, code, 'register');
    if (!verificationCode) {
      ctx.set.status = 400;
      return { code: 400, message: '验证码无效或已过期' };
    }

    // 标记验证码已使用
    VerificationCodeDB.markUsed(verificationCode.id);

    // 创建用户
    const user = UserDB.create(email, username, password);
    if (!user) {
      ctx.set.status = 500;
      return { code: 500, message: '创建用户失败' };
    }

    // 标记邮箱已验证
    UserDB.markEmailVerified(user.id);

    logger.info(`[Auth] 新用户注册成功: ${username} (${email})`);

    return {
      code: 200,
      message: '注册成功',
      data: {
        id: user.id,
        email: user.email,
        username: user.username,
        createdAt: user.created_at
      }
    };
  } catch (error: any) {
    logger.error(`[Auth] 用户注册失败: ${error.message}`);
    ctx.set.status = 500;
    return { code: 500, message: '注册失败，请稍后重试' };
  }
}

// 用户登录
export async function login(ctx: Context) {
  const { account, password } = ctx.body as { account: string; password: string };

  // 验证输入
  if (!account || !password) {
    ctx.set.status = 400;
    return { code: 400, message: '账号和密码不能为空' };
  }

  try {
    // 尝试通过邮箱或用户名查找用户
    let user = UserDB.findByEmail(account);
    if (!user) {
      user = UserDB.findByUsername(account);
    }

    if (!user) {
      ctx.set.status = 401;
      return { code: 401, message: '账号或密码错误' };
    }

    // 验证密码
    const isPasswordValid = UserDB.verifyPassword(user, password);
    if (!isPasswordValid) {
      ctx.set.status = 401;
      return { code: 401, message: '账号或密码错误' };
    }

    // 获取并更新 QQ 头像
    const avatarUrl = getQQAvatarUrl(user.email);
    if (avatarUrl && avatarUrl !== user.avatar_url) {
      UserDB.updateAvatar(user.id, avatarUrl);
      user.avatar_url = avatarUrl;
    }

    // 更新最后登录时间
    UserDB.updateLastLogin(user.id);

    logger.info(`[Auth] 用户登录成功: ${user.username}`);

    return {
      code: 200,
      message: '登录成功',
      data: {
        id: user.id,
        email: user.email,
        username: user.username,
        isVerified: user.is_verified === 1,
        lastLogin: user.last_login,
        avatarUrl: user.avatar_url
      }
    };
  } catch (error: any) {
    logger.error(`[Auth] 用户登录失败: ${error.message}`);
    ctx.set.status = 500;
    return { code: 500, message: '登录失败，请稍后重试' };
  }
}

// 发送重置密码验证码
export async function sendResetCode(ctx: Context) {
  const { email } = ctx.body as { email: string };

  // 验证输入
  if (!email) {
    ctx.set.status = 400;
    return { code: 400, message: '邮箱不能为空' };
  }

  try {
    // 检查用户是否存在
    const user = UserDB.findByEmail(email);
    if (!user) {
      // 为了安全，即使用户不存在也返回成功
      return {
        code: 200,
        message: '如果该邮箱已注册，验证码将发送到您的邮箱'
      };
    }

    // 生成验证码
    const code = generateVerificationCode();

    // 保存验证码到数据库
    VerificationCodeDB.create(email, code, 'reset_password', 10);

    // 发送邮件
    await sendResetPasswordEmail(email, code, user.username);

    logger.info(`[Auth] 密码重置验证码已发送到 ${email}`);

    return {
      code: 200,
      message: '验证码已发送到您的邮箱，请查收',
      data: {
        email,
        expiresIn: 600 // 10分钟
      }
    };
  } catch (error: any) {
    logger.error(`[Auth] 发送重置密码验证码失败: ${error.message}`);
    ctx.set.status = 500;
    return { code: 500, message: '发送验证码失败，请稍后重试' };
  }
}

// 重置密码
export async function resetPassword(ctx: Context) {
  const { email, code, newPassword } = ctx.body as {
    email: string;
    code: string;
    newPassword: string;
  };

  // 验证输入
  if (!email || !code || !newPassword) {
    ctx.set.status = 400;
    return { code: 400, message: '所有字段都不能为空' };
  }

  // 验证密码强度
  if (newPassword.length < 8) {
    ctx.set.status = 400;
    return { code: 400, message: '密码长度至少为8个字符' };
  }

  try {
    // 验证验证码
    const verificationCode = VerificationCodeDB.findValid(email, code, 'reset_password');
    if (!verificationCode) {
      ctx.set.status = 400;
      return { code: 400, message: '验证码无效或已过期' };
    }

    // 查找用户
    const user = UserDB.findByEmail(email);
    if (!user) {
      ctx.set.status = 404;
      return { code: 404, message: '用户不存在' };
    }

    // 标记验证码已使用
    VerificationCodeDB.markUsed(verificationCode.id);

    // 更新密码
    UserDB.updatePassword(user.id, newPassword);

    logger.info(`[Auth] 用户 ${user.username} 密码重置成功`);

    return {
      code: 200,
      message: '密码重置成功，请使用新密码登录'
    };
  } catch (error: any) {
    logger.error(`[Auth] 密码重置失败: ${error.message}`);
    ctx.set.status = 500;
    return { code: 500, message: '密码重置失败，请稍后重试' };
  }
}
