import { Context } from 'elysia';
import { UserDB } from './database';
import { logger } from './logger';
import { getConfig } from './utils';

// 管理员会话存储（内存中，重启后失效）
const adminSessions = new Map<string, { createdAt: number; expiresAt: number }>();

// 生成随机会话令牌
function generateSessionToken(): string {
  return Array.from({ length: 32 }, () => 
    Math.floor(Math.random() * 16).toString(16)
  ).join('');
}

// 清理过期会话
function cleanExpiredSessions() {
  const now = Date.now();
  for (const [token, session] of adminSessions.entries()) {
    if (session.expiresAt < now) {
      adminSessions.delete(token);
    }
  }
}

// 定期清理过期会话（每10分钟）
setInterval(cleanExpiredSessions, 10 * 60 * 1000);

// 管理员登录验证
export async function adminLogin(ctx: Context) {
  const { password } = ctx.body as { password: string };

  // 验证输入
  if (!password) {
    ctx.set.status = 400;
    return { code: 400, message: '密码不能为空' };
  }

  try {
    // 获取配置中的管理员密码
    const config = await getConfig();
    const adminPassword = config?.admin?.password || 'morax2237';
    const sessionDuration = (config?.admin?.session_duration || 3600) * 1000; // 转换为毫秒

    // 验证密码
    if (password !== adminPassword) {
      logger.warn('[Admin] 管理员登录失败：密码错误');
      ctx.set.status = 401;
      return { code: 401, message: '密码错误' };
    }

    // 生成会话令牌
    const token = generateSessionToken();
    const now = Date.now();
    adminSessions.set(token, {
      createdAt: now,
      expiresAt: now + sessionDuration,
    });

    logger.info('[Admin] 管理员登录成功');

    return {
      code: 200,
      message: '登录成功',
      data: {
        token,
        expiresIn: sessionDuration / 1000, // 秒
      },
    };
  } catch (error: any) {
    logger.error(`[Admin] 管理员登录失败: ${error.message}`);
    ctx.set.status = 500;
    return { code: 500, message: '登录失败，请稍后重试' };
  }
}

// 验证管理员令牌
export function verifyAdminToken(token: string): boolean {
  if (!token) return false;

  const session = adminSessions.get(token);
  if (!session) return false;

  // 检查是否过期
  if (session.expiresAt < Date.now()) {
    adminSessions.delete(token);
    return false;
  }

  return true;
}

// 中间件：验证管理员权限
export function requireAdmin(ctx: Context): boolean {
  const token = (ctx.headers as any).authorization?.replace('Bearer ', '');
  
  if (!verifyAdminToken(token)) {
    ctx.set.status = 401;
    return false;
  }

  return true;
}

// 获取所有用户列表
export async function getAllUsers(ctx: Context) {
  // 验证管理员权限
  if (!requireAdmin(ctx)) {
    return { code: 401, message: '需要管理员权限' };
  }

  try {
    const db = (await import('./database')).default;
    
    // 查询所有用户（不包含密码）
    const users = db.query(`
      SELECT 
        id, 
        email, 
        username, 
        avatar_url,
        created_at, 
        updated_at, 
        is_verified, 
        verified_at, 
        last_login,
        last_ip,
        last_ip_location,
        last_ip_updated_at
      FROM users 
      ORDER BY created_at DESC
    `).all();

    logger.info(`[Admin] 查询所有用户：共 ${users.length} 个用户`);

    return {
      code: 200,
      message: '查询成功',
      data: {
        users,
        total: users.length,
      },
    };
  } catch (error: any) {
    logger.error(`[Admin] 查询用户列表失败: ${error.message}`);
    ctx.set.status = 500;
    return { code: 500, message: '查询失败，请稍后重试' };
  }
}

// 获取用户统计数据
export async function getUserStats(ctx: Context) {
  // 验证管理员权限
  if (!requireAdmin(ctx)) {
    return { code: 401, message: '需要管理员权限' };
  }

  try {
    const db = (await import('./database')).default;

    // 总用户数
    const totalUsers = db.query('SELECT COUNT(*) as count FROM users').get() as { count: number };

    // 已验证用户数
    const verifiedUsers = db.query('SELECT COUNT(*) as count FROM users WHERE is_verified = 1').get() as { count: number };

    // 今日注册用户数
    const todayUsers = db.query(`
      SELECT COUNT(*) as count 
      FROM users 
      WHERE DATE(created_at) = DATE('now')
    `).get() as { count: number };

    // 今日活跃用户数（今天登录过）
    const todayActiveUsers = db.query(`
      SELECT COUNT(*) as count 
      FROM users 
      WHERE DATE(last_login) = DATE('now')
    `).get() as { count: number };

    // 最近7天注册用户数
    const last7DaysUsers = db.query(`
      SELECT COUNT(*) as count 
      FROM users 
      WHERE created_at >= datetime('now', '-7 days')
    `).get() as { count: number };

    // 最近30天注册用户数
    const last30DaysUsers = db.query(`
      SELECT COUNT(*) as count 
      FROM users 
      WHERE created_at >= datetime('now', '-30 days')
    `).get() as { count: number };

    // IP归属地统计（前10）
    const topLocations = db.query(`
      SELECT 
        last_ip_location as location, 
        COUNT(*) as count
      FROM users 
      WHERE last_ip_location IS NOT NULL AND last_ip_location != ''
      GROUP BY last_ip_location
      ORDER BY count DESC
      LIMIT 10
    `).all() as Array<{ location: string; count: number }>;

    // 每日注册趋势（最近30天）
    const registrationTrend = db.query(`
      SELECT 
        DATE(created_at) as date,
        COUNT(*) as count
      FROM users
      WHERE created_at >= datetime('now', '-30 days')
      GROUP BY DATE(created_at)
      ORDER BY date ASC
    `).all() as Array<{ date: string; count: number }>;

    // 每日活跃趋势（最近30天）
    const activeTrend = db.query(`
      SELECT 
        DATE(last_login) as date,
        COUNT(*) as count
      FROM users
      WHERE last_login >= datetime('now', '-30 days')
      GROUP BY DATE(last_login)
      ORDER BY date ASC
    `).all() as Array<{ date: string; count: number }>;

    logger.info(`[Admin] 查询用户统计数据`);

    return {
      code: 200,
      message: '查询成功',
      data: {
        overview: {
          totalUsers: totalUsers.count,
          verifiedUsers: verifiedUsers.count,
          unverifiedUsers: totalUsers.count - verifiedUsers.count,
          todayUsers: todayUsers.count,
          todayActiveUsers: todayActiveUsers.count,
          last7DaysUsers: last7DaysUsers.count,
          last30DaysUsers: last30DaysUsers.count,
        },
        topLocations,
        registrationTrend,
        activeTrend,
      },
    };
  } catch (error: any) {
    logger.error(`[Admin] 查询统计数据失败: ${error.message}`);
    ctx.set.status = 500;
    return { code: 500, message: '查询失败，请稍后重试' };
  }
}

// 删除用户（危险操作）
export async function deleteUser(ctx: Context) {
  // 验证管理员权限
  if (!requireAdmin(ctx)) {
    return { code: 401, message: '需要管理员权限' };
  }

  const { userId } = ctx.body as { userId: number };

  // 验证输入
  if (!userId) {
    ctx.set.status = 400;
    return { code: 400, message: '用户ID不能为空' };
  }

  try {
    // 检查用户是否存在
    const user = UserDB.findById(userId);
    if (!user) {
      ctx.set.status = 404;
      return { code: 404, message: '用户不存在' };
    }

    const db = (await import('./database')).default;
    
    // 删除用户
    db.query('DELETE FROM users WHERE id = $id').run({ $id: userId });

    logger.warn(`[Admin] 删除用户: ${user.username} (ID: ${userId})`);

    return {
      code: 200,
      message: '用户已删除',
      data: {
        userId,
        username: user.username,
      },
    };
  } catch (error: any) {
    logger.error(`[Admin] 删除用户失败: ${error.message}`);
    ctx.set.status = 500;
    return { code: 500, message: '删除失败，请稍后重试' };
  }
}

// 管理员登出
export async function adminLogout(ctx: Context) {
  const token = (ctx.headers as any).authorization?.replace('Bearer ', '');

  if (token && adminSessions.has(token)) {
    adminSessions.delete(token);
    logger.info('[Admin] 管理员登出成功');
    return { code: 200, message: '登出成功' };
  }

  return { code: 200, message: '已登出' };
}

