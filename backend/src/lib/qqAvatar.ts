import { logger } from './logger';

/**
 * 从 QQ 邮箱中提取 QQ 号
 * @param email - QQ 邮箱地址（如：123456@qq.com）
 * @returns QQ 号，如果不是 QQ 邮箱则返回 null
 */
export function extractQQNumber(email: string): string | null {
  // 检查是否是 QQ 邮箱
  if (!email.toLowerCase().endsWith('@qq.com')) {
    return null;
  }

  // 提取 @ 前面的部分
  const qqNumber = email.split('@')[0];

  // 验证是否为纯数字
  if (!/^\d+$/.test(qqNumber)) {
    return null;
  }

  return qqNumber;
}

/**
 * 验证是否为 QQ 邮箱
 * @param email - 邮箱地址
 * @returns 是否为有效的 QQ 邮箱
 */
export function isQQEmail(email: string): boolean {
  const qqNumber = extractQQNumber(email);
  return qqNumber !== null;
}

/**
 * 获取 QQ 头像 URL
 * @param email - QQ 邮箱地址
 * @param size - 头像大小（1=40x40, 2=40x40, 3=100x100, 4=140x140, 5=640x640, 40=40x40, 100=100x100）
 * @returns QQ 头像 URL，如果不是 QQ 邮箱则返回默认头像
 */
export function getQQAvatarUrl(email: string, size: number = 100): string {
  const qqNumber = extractQQNumber(email);

  if (!qqNumber) {
    logger.warn(`[QQ Avatar] 非 QQ 邮箱: ${email}，返回默认头像`);
    return getDefaultAvatarUrl();
  }

  // QQ 头像 API
  // 参考：https://q1.qlogo.cn/g?b=qq&nk=QQ号&s=大小
  const avatarUrl = `https://q1.qlogo.cn/g?b=qq&nk=${qqNumber}&s=${size}`;
  
  logger.info(`[QQ Avatar] 获取头像 - QQ号: ${qqNumber}, URL: ${avatarUrl}`);
  
  return avatarUrl;
}

/**
 * 获取多种尺寸的 QQ 头像 URL
 * @param email - QQ 邮箱地址
 * @returns 包含不同尺寸头像 URL 的对象
 */
export function getQQAvatarUrls(email: string) {
  const qqNumber = extractQQNumber(email);

  if (!qqNumber) {
    const defaultUrl = getDefaultAvatarUrl();
    return {
      small: defaultUrl,    // 40x40
      medium: defaultUrl,   // 100x100
      large: defaultUrl,    // 140x140
      xlarge: defaultUrl,   // 640x640
    };
  }

  return {
    small: `https://q1.qlogo.cn/g?b=qq&nk=${qqNumber}&s=40`,     // 40x40
    medium: `https://q1.qlogo.cn/g?b=qq&nk=${qqNumber}&s=100`,   // 100x100
    large: `https://q1.qlogo.cn/g?b=qq&nk=${qqNumber}&s=140`,    // 140x140
    xlarge: `https://q1.qlogo.cn/g?b=qq&nk=${qqNumber}&s=640`,   // 640x640
  };
}

/**
 * 获取默认头像 URL（当不是 QQ 邮箱时）
 * @returns 默认头像 URL
 */
export function getDefaultAvatarUrl(): string {
  // 使用 UI Avatars 生成默认头像（基于用户名首字母）
  // 或者使用 Gravatar 的默认头像
  return 'https://ui-avatars.com/api/?name=User&size=100&background=667eea&color=fff';
}

/**
 * 验证 QQ 邮箱格式（用于注册时的额外验证）
 * @param email - 邮箱地址
 * @returns 验证结果对象
 */
export function validateQQEmail(email: string): { valid: boolean; message?: string } {
  // 基本邮箱格式验证
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    return { valid: false, message: '邮箱格式不正确' };
  }

  // 检查是否为 QQ 邮箱
  if (!email.toLowerCase().endsWith('@qq.com')) {
    return { valid: false, message: '目前仅支持 QQ 邮箱注册（格式：QQ号@qq.com）' };
  }

  // 提取 QQ 号并验证
  const qqNumber = extractQQNumber(email);
  if (!qqNumber) {
    return { valid: false, message: 'QQ 邮箱格式不正确，应为纯数字@qq.com' };
  }

  // QQ 号长度验证（通常为 5-11 位）
  if (qqNumber.length < 5 || qqNumber.length > 11) {
    return { valid: false, message: 'QQ 号长度不正确（应为 5-11 位）' };
  }

  return { valid: true };
}

export default {
  extractQQNumber,
  isQQEmail,
  getQQAvatarUrl,
  getQQAvatarUrls,
  getDefaultAvatarUrl,
  validateQQEmail,
};
