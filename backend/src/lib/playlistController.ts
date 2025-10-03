import db from './database';

// 创建歌单表
db.exec(`
  CREATE TABLE IF NOT EXISTS playlists (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    is_default INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  )
`);

// 创建歌单歌曲关联表
db.exec(`
  CREATE TABLE IF NOT EXISTS playlist_tracks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    playlist_id INTEGER NOT NULL,
    track_id TEXT NOT NULL,
    name TEXT NOT NULL,
    artists TEXT NOT NULL,
    album TEXT NOT NULL,
    pic_url TEXT NOT NULL,
    source TEXT NOT NULL,
    added_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,
    UNIQUE(playlist_id, track_id, source)
  )
`);

// 创建索引
db.exec(`
  CREATE INDEX IF NOT EXISTS idx_playlists_user_id ON playlists(user_id);
  CREATE INDEX IF NOT EXISTS idx_playlist_tracks_playlist_id ON playlist_tracks(playlist_id);
  CREATE INDEX IF NOT EXISTS idx_playlist_tracks_added_at ON playlist_tracks(added_at);
`);

// 歌单数据类型
export interface Playlist {
  id: number;
  user_id: number;
  name: string;
  is_default: number;
  created_at: string;
  updated_at: string;
  track_count?: number;
}

// 歌单歌曲数据类型
export interface PlaylistTrack {
  id: number;
  playlist_id: number;
  track_id: string;
  name: string;
  artists: string;
  album: string;
  pic_url: string;
  source: string;
  added_at: string;
}

// 歌单数据库操作
export const PlaylistDB = {
  // 确保用户有默认歌单（我的收藏）
  ensureDefaultPlaylist(userId: number) {
    // 检查是否已有默认歌单
    const checkStmt = db.query(`
      SELECT COUNT(*) as count FROM playlists 
      WHERE user_id = $userId AND is_default = 1
    `);
    const result = checkStmt.get({ $userId: userId }) as { count: number };
    
    if (result.count === 0) {
      // 创建默认歌单
      const stmt = db.query(`
        INSERT INTO playlists (user_id, name, is_default)
        VALUES ($userId, $name, 1)
      `);
      stmt.run({ $userId: userId, $name: '我的收藏' });
    }
  },

  // 获取用户的所有歌单（包含歌曲数量）
  getByUserId(userId: number): Playlist[] {
    this.ensureDefaultPlaylist(userId);
    
    const stmt = db.query(`
      SELECT p.*, COUNT(pt.id) as track_count
      FROM playlists p
      LEFT JOIN playlist_tracks pt ON p.id = pt.playlist_id
      WHERE p.user_id = $userId
      GROUP BY p.id
      ORDER BY p.is_default DESC, p.created_at ASC
    `);
    return stmt.all({ $userId: userId }) as Playlist[];
  },

  // 创建歌单
  create(userId: number, name: string) {
    const stmt = db.query(`
      INSERT INTO playlists (user_id, name, is_default)
      VALUES ($userId, $name, 0)
    `);
    stmt.run({ $userId: userId, $name: name });
    
    const lastId = db.query('SELECT last_insert_rowid() as id').get() as { id: number };
    return this.findById(lastId.id);
  },

  // 通过 ID 查找歌单
  findById(playlistId: number): Playlist | null {
    const stmt = db.query('SELECT * FROM playlists WHERE id = $id');
    return stmt.get({ $id: playlistId }) as Playlist | null;
  },

  // 更新歌单
  update(playlistId: number, userId: number, name: string) {
    // 检查歌单是否属于该用户
    const playlist = this.findById(playlistId);
    if (!playlist || playlist.user_id !== userId) {
      return false;
    }
    
    // 不允许重命名默认歌单
    if (playlist.is_default === 1) {
      throw new Error('不能重命名默认歌单');
    }
    
    const stmt = db.query(`
      UPDATE playlists 
      SET name = $name, updated_at = CURRENT_TIMESTAMP
      WHERE id = $id AND user_id = $userId
    `);
    const result = stmt.run({ $id: playlistId, $userId: userId, $name: name });
    return result.changes > 0;
  },

  // 删除歌单
  delete(playlistId: number, userId: number) {
    // 检查歌单是否属于该用户
    const playlist = this.findById(playlistId);
    if (!playlist || playlist.user_id !== userId) {
      return false;
    }
    
    // 不允许删除默认歌单
    if (playlist.is_default === 1) {
      throw new Error('不能删除默认歌单');
    }
    
    const stmt = db.query(`
      DELETE FROM playlists 
      WHERE id = $id AND user_id = $userId AND is_default = 0
    `);
    const result = stmt.run({ $id: playlistId, $userId: userId });
    return result.changes > 0;
  },

  // 添加歌曲到歌单
  addTrack(playlistId: number, userId: number, track: {
    trackId: string;
    name: string;
    artists: string;
    album: string;
    picUrl: string;
    source: string;
  }) {
    // 检查歌单是否属于该用户
    const playlist = this.findById(playlistId);
    if (!playlist || playlist.user_id !== userId) {
      throw new Error('歌单不存在或无权限');
    }
    
    try {
      const stmt = db.query(`
        INSERT INTO playlist_tracks (playlist_id, track_id, name, artists, album, pic_url, source)
        VALUES ($playlistId, $trackId, $name, $artists, $album, $picUrl, $source)
      `);
      
      stmt.run({
        $playlistId: playlistId,
        $trackId: track.trackId,
        $name: track.name,
        $artists: track.artists,
        $album: track.album,
        $picUrl: track.picUrl,
        $source: track.source,
      });
      
      return true;
    } catch (error: any) {
      if (error.message.includes('UNIQUE')) {
        throw new Error('该歌曲已在歌单中');
      }
      throw error;
    }
  },

  // 获取歌单中的所有歌曲
  getTracks(playlistId: number, userId: number): PlaylistTrack[] {
    // 检查歌单是否属于该用户
    const playlist = this.findById(playlistId);
    if (!playlist || playlist.user_id !== userId) {
      return [];
    }
    
    const stmt = db.query(`
      SELECT * FROM playlist_tracks 
      WHERE playlist_id = $playlistId 
      ORDER BY added_at DESC
    `);
    return stmt.all({ $playlistId: playlistId }) as PlaylistTrack[];
  },

  // 从歌单删除歌曲
  removeTrack(playlistId: number, userId: number, trackId: string, source: string) {
    // 检查歌单是否属于该用户
    const playlist = this.findById(playlistId);
    if (!playlist || playlist.user_id !== userId) {
      return false;
    }
    
    const stmt = db.query(`
      DELETE FROM playlist_tracks 
      WHERE playlist_id = $playlistId AND track_id = $trackId AND source = $source
    `);
    const result = stmt.run({ $playlistId: playlistId, $trackId: trackId, $source: source });
    return result.changes > 0;
  },

  // 批量删除歌曲
  removeTracks(playlistId: number, userId: number, tracks: Array<{trackId: string, source: string}>) {
    // 检查歌单是否属于该用户
    const playlist = this.findById(playlistId);
    if (!playlist || playlist.user_id !== userId) {
      return 0;
    }
    
    let totalDeleted = 0;
    
    // 使用事务确保原子性
    const transaction = db.transaction(() => {
      for (const track of tracks) {
        const stmt = db.query(`
          DELETE FROM playlist_tracks 
          WHERE playlist_id = $playlistId AND track_id = $trackId AND source = $source
        `);
        const result = stmt.run({ 
          $playlistId: playlistId, 
          $trackId: track.trackId, 
          $source: track.source 
        });
        totalDeleted += result.changes;
      }
    });
    
    transaction();
    return totalDeleted;
  },
};

// 验证用户身份的辅助函数
function getUserIdFromToken(token: string | undefined): number | null {
  if (!token) return null;
  const userId = parseInt(token.replace('Bearer ', '').replace('user_', ''));
  return isNaN(userId) ? null : userId;
}

// ==================== API 控制器 ====================

// 获取用户的所有歌单
export async function getPlaylists(ctx: any) {
  const { set, headers } = ctx;
  
  const userId = getUserIdFromToken(headers.authorization);
  if (!userId) {
    set.status = 401;
    return { status: 401, message: '未授权' };
  }

  try {
    const playlists = PlaylistDB.getByUserId(userId);
    
    // 转换为前端期望的格式
    const formattedPlaylists = playlists.map(playlist => ({
      id: playlist.id,
      name: playlist.name,
      isDefault: playlist.is_default === 1,
      trackCount: playlist.track_count || 0,
      createdAt: playlist.created_at,
      updatedAt: playlist.updated_at,
    }));
    
    return { status: 200, playlists: formattedPlaylists };
  } catch (error: any) {
    set.status = 500;
    return { status: 500, message: `获取歌单列表失败: ${error.message}` };
  }
}

// 创建新歌单
export async function createPlaylist(ctx: any) {
  const { body, set, headers } = ctx;
  
  const userId = getUserIdFromToken(headers.authorization);
  if (!userId) {
    set.status = 401;
    return { status: 401, message: '未授权' };
  }

  const { name } = body;
  if (!name || name.trim() === '') {
    set.status = 400;
    return { status: 400, message: '歌单名称不能为空' };
  }

  try {
    const playlist = PlaylistDB.create(userId, name.trim());
    return { 
      status: 200, 
      message: '创建成功',
      playlist: {
        id: playlist!.id,
        name: playlist!.name,
        isDefault: false,
        trackCount: 0,
        createdAt: playlist!.created_at,
        updatedAt: playlist!.updated_at,
      }
    };
  } catch (error: any) {
    set.status = 500;
    return { status: 500, message: `创建歌单失败: ${error.message}` };
  }
}

// 更新歌单（重命名）
export async function updatePlaylist(ctx: any) {
  const { body, set, headers, params } = ctx;
  const { playlistId } = params;
  
  const userId = getUserIdFromToken(headers.authorization);
  if (!userId) {
    set.status = 401;
    return { status: 401, message: '未授权' };
  }

  const { name } = body;
  if (!name || name.trim() === '') {
    set.status = 400;
    return { status: 400, message: '歌单名称不能为空' };
  }

  try {
    const success = PlaylistDB.update(parseInt(playlistId), userId, name.trim());
    if (success) {
      return { status: 200, message: '更新成功' };
    } else {
      set.status = 404;
      return { status: 404, message: '歌单不存在或无权限' };
    }
  } catch (error: any) {
    if (error.message === '不能重命名默认歌单') {
      set.status = 400;
      return { status: 400, message: error.message };
    }
    set.status = 500;
    return { status: 500, message: `更新歌单失败: ${error.message}` };
  }
}

// 删除歌单
export async function deletePlaylist(ctx: any) {
  const { set, headers, params } = ctx;
  const { playlistId } = params;
  
  const userId = getUserIdFromToken(headers.authorization);
  if (!userId) {
    set.status = 401;
    return { status: 401, message: '未授权' };
  }

  try {
    const success = PlaylistDB.delete(parseInt(playlistId), userId);
    if (success) {
      return { status: 200, message: '删除成功' };
    } else {
      set.status = 404;
      return { status: 404, message: '歌单不存在或无权限' };
    }
  } catch (error: any) {
    if (error.message === '不能删除默认歌单') {
      set.status = 400;
      return { status: 400, message: error.message };
    }
    set.status = 500;
    return { status: 500, message: `删除歌单失败: ${error.message}` };
  }
}

// 添加歌曲到歌单
export async function addTrackToPlaylist(ctx: any) {
  const { body, set, headers, params } = ctx;
  const { playlistId } = params;
  
  const userId = getUserIdFromToken(headers.authorization);
  if (!userId) {
    set.status = 401;
    return { status: 401, message: '未授权' };
  }

  try {
    PlaylistDB.addTrack(parseInt(playlistId), userId, body);
    return { status: 200, message: '添加成功' };
  } catch (error: any) {
    if (error.message === '该歌曲已在歌单中') {
      set.status = 400;
      return { status: 400, message: error.message };
    }
    if (error.message === '歌单不存在或无权限') {
      set.status = 404;
      return { status: 404, message: error.message };
    }
    set.status = 500;
    return { status: 500, message: `添加歌曲失败: ${error.message}` };
  }
}

// 获取歌单中的歌曲
export async function getPlaylistTracks(ctx: any) {
  const { set, headers, params } = ctx;
  const { playlistId } = params;
  
  const userId = getUserIdFromToken(headers.authorization);
  if (!userId) {
    set.status = 401;
    return { status: 401, message: '未授权' };
  }

  try {
    const tracks = PlaylistDB.getTracks(parseInt(playlistId), userId);
    
    // 转换为前端期望的格式
    const formattedTracks = tracks.map(track => ({
      trackId: track.track_id,
      name: track.name,
      artists: track.artists,
      album: track.album,
      picUrl: track.pic_url,
      source: track.source,
      addedAt: track.added_at,
    }));
    
    return { status: 200, tracks: formattedTracks };
  } catch (error: any) {
    set.status = 500;
    return { status: 500, message: `获取歌曲列表失败: ${error.message}` };
  }
}

// 从歌单删除歌曲
export async function removeTrackFromPlaylist(ctx: any) {
  const { set, headers, params, body } = ctx;
  const { playlistId } = params;
  const { trackId, source } = body;
  
  // 诊断日志
  console.log('🗑️ [removeTrackFromPlaylist] 接收到删除请求');
  console.log('   params:', params);
  console.log('   body:', body);
  console.log('   playlistId:', playlistId, '(type:', typeof playlistId, ')');
  console.log('   trackId:', trackId, '(type:', typeof trackId, ')');
  console.log('   source:', source, '(type:', typeof source, ')');
  console.log('   authorization:', headers.authorization);
  
  const userId = getUserIdFromToken(headers.authorization);
  console.log('   userId:', userId);
  
  if (!userId) {
    set.status = 401;
    return { status: 401, message: '未授权' };
  }

  try {
    const success = PlaylistDB.removeTrack(parseInt(playlistId), userId, trackId, source);
    console.log('   删除结果:', success);
    if (success) {
      return { status: 200, message: '删除成功' };
    } else {
      set.status = 404;
      return { status: 404, message: '歌曲不存在或无权限' };
    }
  } catch (error: any) {
    console.error('   删除错误:', error);
    set.status = 500;
    return { status: 500, message: `删除歌曲失败: ${error.message}` };
  }
}

// 批量删除歌曲
export async function removeTracksFromPlaylist(ctx: any) {
  const { set, headers, params, body } = ctx;
  const { playlistId } = params;
  const { tracks } = body;
  
  console.log('🗑️ [removeTracksFromPlaylist] 批量删除请求');
  console.log('   playlistId:', playlistId);
  console.log('   tracks count:', tracks?.length);
  
  const userId = getUserIdFromToken(headers.authorization);
  if (!userId) {
    set.status = 401;
    return { status: 401, message: '未授权' };
  }

  if (!Array.isArray(tracks) || tracks.length === 0) {
    set.status = 400;
    return { status: 400, message: '请提供要删除的歌曲列表' };
  }

  try {
    const deletedCount = PlaylistDB.removeTracks(parseInt(playlistId), userId, tracks);
    console.log('   删除结果:', deletedCount, '首歌曲');
    
    return { 
      status: 200, 
      message: `成功删除 ${deletedCount} 首歌曲`,
      deletedCount 
    };
  } catch (error: any) {
    console.error('   批量删除错误:', error);
    set.status = 500;
    return { status: 500, message: `批量删除失败: ${error.message}` };
  }
}

