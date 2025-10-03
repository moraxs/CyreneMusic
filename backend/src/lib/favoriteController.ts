import db from './database';

// 创建收藏表
db.exec(`
  CREATE TABLE IF NOT EXISTS favorites (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    track_id TEXT NOT NULL,
    name TEXT NOT NULL,
    artists TEXT NOT NULL,
    album TEXT NOT NULL,
    pic_url TEXT NOT NULL,
    source TEXT NOT NULL,
    added_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(user_id, track_id, source)
  )
`);

// 创建索引
db.exec(`
  CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites(user_id);
  CREATE INDEX IF NOT EXISTS idx_favorites_added_at ON favorites(added_at);
`);

// 收藏数据类型
export interface Favorite {
  id: number;
  user_id: number;
  track_id: string;
  name: string;
  artists: string;
  album: string;
  pic_url: string;
  source: string;
  added_at: string;
}

// 收藏数据库操作
export const FavoriteDB = {
  // 添加收藏
  add(userId: number, favorite: {
    trackId: string;
    name: string;
    artists: string;
    album: string;
    picUrl: string;
    source: string;
  }) {
    try {
      const stmt = db.query(`
        INSERT INTO favorites (user_id, track_id, name, artists, album, pic_url, source)
        VALUES ($userId, $trackId, $name, $artists, $album, $picUrl, $source)
      `);
      
      stmt.run({
        $userId: userId,
        $trackId: favorite.trackId,
        $name: favorite.name,
        $artists: favorite.artists,
        $album: favorite.album,
        $picUrl: favorite.picUrl,
        $source: favorite.source,
      });
      
      return true;
    } catch (error: any) {
      // 如果是唯一约束错误，说明已经收藏过了
      if (error.message.includes('UNIQUE')) {
        throw new Error('已经收藏过该歌曲');
      }
      throw error;
    }
  },

  // 获取用户的所有收藏
  getByUserId(userId: number): Favorite[] {
    const stmt = db.query(`
      SELECT * FROM favorites 
      WHERE user_id = $userId 
      ORDER BY added_at DESC
    `);
    return stmt.all({ $userId: userId }) as Favorite[];
  },

  // 删除收藏
  remove(userId: number, trackId: string, source: string) {
    const stmt = db.query(`
      DELETE FROM favorites 
      WHERE user_id = $userId AND track_id = $trackId AND source = $source
    `);
    const result = stmt.run({ $userId: userId, $trackId: trackId, $source: source });
    return result.changes > 0;
  },

  // 检查是否已收藏
  isFavorite(userId: number, trackId: string, source: string): boolean {
    const stmt = db.query(`
      SELECT COUNT(*) as count FROM favorites 
      WHERE user_id = $userId AND track_id = $trackId AND source = $source
    `);
    const result = stmt.get({ $userId: userId, $trackId: trackId, $source: source }) as { count: number };
    return result.count > 0;
  },

  // 获取用户收藏总数
  getCount(userId: number): number {
    const stmt = db.query(`
      SELECT COUNT(*) as count FROM favorites 
      WHERE user_id = $userId
    `);
    const result = stmt.get({ $userId: userId }) as { count: number };
    return result.count;
  },
};

// 添加收藏 API
export async function addFavorite(ctx: any) {
  const { body, set, headers } = ctx;
  
  // 验证 token
  const token = headers.authorization?.replace('Bearer ', '');
  if (!token) {
    set.status = 401;
    return { status: 401, message: '未授权' };
  }

  // 这里需要从 token 解析用户 ID（简化版本，实际应该使用 JWT）
  // 假设 token 格式为 "user_{userId}"
  const userId = parseInt(token.replace('user_', ''));
  
  if (!userId) {
    set.status = 401;
    return { status: 401, message: '无效的 token' };
  }

  try {
    FavoriteDB.add(userId, body);
    return { status: 200, message: '收藏成功' };
  } catch (error: any) {
    if (error.message === '已经收藏过该歌曲') {
      set.status = 400;
      return { status: 400, message: error.message };
    }
    set.status = 500;
    return { status: 500, message: `收藏失败: ${error.message}` };
  }
}

// 获取收藏列表 API
export async function getFavorites(ctx: any) {
  const { set, headers } = ctx;
  
  // 验证 token
  const token = headers.authorization?.replace('Bearer ', '');
  if (!token) {
    set.status = 401;
    return { status: 401, message: '未授权' };
  }

  const userId = parseInt(token.replace('user_', ''));
  
  if (!userId) {
    set.status = 401;
    return { status: 401, message: '无效的 token' };
  }

  try {
    const favorites = FavoriteDB.getByUserId(userId);
    
    // 转换为前端期望的格式
    const formattedFavorites = favorites.map(fav => ({
      trackId: fav.track_id,
      name: fav.name,
      artists: fav.artists,
      album: fav.album,
      picUrl: fav.pic_url,
      source: fav.source,
      addedAt: fav.added_at,
    }));
    
    return { status: 200, favorites: formattedFavorites };
  } catch (error: any) {
    set.status = 500;
    return { status: 500, message: `获取收藏列表失败: ${error.message}` };
  }
}

// 删除收藏 API
export async function removeFavorite(ctx: any) {
  const { set, headers, params } = ctx;
  const { trackId, source } = params;
  
  // 验证 token
  const token = headers.authorization?.replace('Bearer ', '');
  if (!token) {
    set.status = 401;
    return { status: 401, message: '未授权' };
  }

  const userId = parseInt(token.replace('user_', ''));
  
  if (!userId) {
    set.status = 401;
    return { status: 401, message: '无效的 token' };
  }

  try {
    const success = FavoriteDB.remove(userId, trackId, source);
    
    if (success) {
      return { status: 200, message: '取消收藏成功' };
    } else {
      set.status = 404;
      return { status: 404, message: '未找到该收藏' };
    }
  } catch (error: any) {
    set.status = 500;
    return { status: 500, message: `取消收藏失败: ${error.message}` };
  }
}

