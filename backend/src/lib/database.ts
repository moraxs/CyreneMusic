import { Database } from 'bun:sqlite';
import path from 'path';
import bcrypt from 'bcryptjs';
import fs from 'fs';

// 数据库文件路径
const dbPath = path.join(process.cwd(), 'data', 'users.db');

// 确保 data 目录存在
const dataDir = path.dirname(dbPath);
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}

// 初始化数据库
const db = new Database(dbPath, { create: true });

// 创建用户表
db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE NOT NULL,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    avatar_url TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    is_verified INTEGER DEFAULT 0,
    verified_at DATETIME,
    last_login DATETIME
  )
`);

// 为已存在的数据库添加 avatar_url 字段（如果不存在）
try {
  db.exec(`ALTER TABLE users ADD COLUMN avatar_url TEXT`);
} catch (e) {
  // 字段已存在，忽略错误
}

// 添加 IP 归属地相关字段（如果不存在）
try {
  db.exec(`ALTER TABLE users ADD COLUMN last_ip TEXT`);
} catch (e) {
  // 字段已存在，忽略错误
}

try {
  db.exec(`ALTER TABLE users ADD COLUMN last_ip_location TEXT`);
} catch (e) {
  // 字段已存在，忽略错误
}

try {
  db.exec(`ALTER TABLE users ADD COLUMN last_ip_updated_at DATETIME`);
} catch (e) {
  // 字段已存在，忽略错误
}

// 创建验证码表
db.exec(`
  CREATE TABLE IF NOT EXISTS verification_codes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL,
    code TEXT NOT NULL,
    type TEXT NOT NULL,
    expires_at DATETIME NOT NULL,
    used INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )
`);

// 创建索引
db.exec(`
  CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
  CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
  CREATE INDEX IF NOT EXISTS idx_verification_codes_email ON verification_codes(email);
  CREATE INDEX IF NOT EXISTS idx_verification_codes_expires ON verification_codes(expires_at);
`);

// 用户数据类型
export interface User {
  id: number;
  email: string;
  username: string;
  password_hash: string;
  avatar_url: string | null;
  created_at: string;
  updated_at: string;
  is_verified: number;
  verified_at: string | null;
  last_login: string | null;
  last_ip: string | null;
  last_ip_location: string | null;
  last_ip_updated_at: string | null;
}

// 验证码类型
export interface VerificationCode {
  id: number;
  email: string;
  code: string;
  type: 'register' | 'reset_password';
  expires_at: string;
  used: number;
  created_at: string;
}

// 用户数据库操作
export const UserDB = {
  // 创建用户
  create(email: string, username: string, password: string) {
    const passwordHash = bcrypt.hashSync(password, 10);
    const stmt = db.query(`
      INSERT INTO users (email, username, password_hash)
      VALUES ($email, $username, $passwordHash)
    `);
    stmt.run({ $email: email, $username: username, $passwordHash: passwordHash });
    const lastId = db.query('SELECT last_insert_rowid() as id').get() as { id: number };
    return this.findById(lastId.id);
  },

  // 通过 ID 查找用户
  findById(id: number): User | null {
    const stmt = db.query('SELECT * FROM users WHERE id = $id');
    return stmt.get({ $id: id }) as User | null;
  },

  // 通过邮箱查找用户
  findByEmail(email: string): User | null {
    const stmt = db.query('SELECT * FROM users WHERE email = $email');
    return stmt.get({ $email: email }) as User | null;
  },

  // 通过用户名查找用户
  findByUsername(username: string): User | null {
    const stmt = db.query('SELECT * FROM users WHERE username = $username');
    return stmt.get({ $username: username }) as User | null;
  },

  // 验证密码
  verifyPassword(user: User, password: string): boolean {
    return bcrypt.compareSync(password, user.password_hash);
  },

  // 更新密码
  updatePassword(userId: number, newPassword: string) {
    const passwordHash = bcrypt.hashSync(newPassword, 10);
    const stmt = db.query(`
      UPDATE users 
      SET password_hash = $passwordHash, updated_at = CURRENT_TIMESTAMP 
      WHERE id = $userId
    `);
    stmt.run({ $passwordHash: passwordHash, $userId: userId });
  },

  // 标记邮箱已验证
  markEmailVerified(userId: number) {
    const stmt = db.query(`
      UPDATE users 
      SET is_verified = 1, verified_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP 
      WHERE id = $userId
    `);
    stmt.run({ $userId: userId });
  },

  // 更新最后登录时间
  updateLastLogin(userId: number) {
    const stmt = db.query(`
      UPDATE users 
      SET last_login = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP 
      WHERE id = $userId
    `);
    stmt.run({ $userId: userId });
  },

  // 更新用户头像
  updateAvatar(userId: number, avatarUrl: string) {
    const stmt = db.query(`
      UPDATE users 
      SET avatar_url = $avatarUrl, updated_at = CURRENT_TIMESTAMP 
      WHERE id = $userId
    `);
    stmt.run({ $avatarUrl: avatarUrl, $userId: userId });
  },

  // 更新用户 IP 归属地
  updateIPLocation(userId: number, ip: string, location: string) {
    const stmt = db.query(`
      UPDATE users 
      SET last_ip = $ip, 
          last_ip_location = $location, 
          last_ip_updated_at = CURRENT_TIMESTAMP,
          updated_at = CURRENT_TIMESTAMP 
      WHERE id = $userId
    `);
    stmt.run({ $ip: ip, $location: location, $userId: userId });
  },
};

// 验证码数据库操作
export const VerificationCodeDB = {
  // 创建验证码
  create(email: string, code: string, type: 'register' | 'reset_password', expiresInMinutes: number = 10) {
    const expiresAt = new Date(Date.now() + expiresInMinutes * 60 * 1000).toISOString();
    const stmt = db.query(`
      INSERT INTO verification_codes (email, code, type, expires_at)
      VALUES ($email, $code, $type, $expiresAt)
    `);
    stmt.run({ $email: email, $code: code, $type: type, $expiresAt: expiresAt });
  },

  // 查找有效的验证码
  findValid(email: string, code: string, type: 'register' | 'reset_password'): VerificationCode | null {
    const stmt = db.query(`
      SELECT * FROM verification_codes 
      WHERE email = $email AND code = $code AND type = $type 
        AND used = 0 AND expires_at > datetime('now')
      ORDER BY created_at DESC
      LIMIT 1
    `);
    return stmt.get({ $email: email, $code: code, $type: type }) as VerificationCode | null;
  },

  // 标记验证码已使用
  markUsed(id: number) {
    const stmt = db.query('UPDATE verification_codes SET used = 1 WHERE id = $id');
    stmt.run({ $id: id });
  },

  // 清理过期验证码
  cleanExpired() {
    const stmt = db.query(`
      DELETE FROM verification_codes 
      WHERE expires_at < datetime('now')
    `);
    stmt.run();
  },
};

// 定期清理过期验证码（每小时）
setInterval(() => {
  VerificationCodeDB.cleanExpired();
}, 60 * 60 * 1000);

export default db;
