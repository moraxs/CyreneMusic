import axios from 'axios';
import { logger } from './logger';
import CookieManager from './cookieManager';

const neteaseCookieManager = new CookieManager('cookie.txt');

const LEADERBOARD_IDS: Record<string, { name: string; id: number }> = {
  soaring: { name: '飙升榜', id: 19723756 },
  new: { name: '新歌榜', id: 3779629 },
  original: { name: '原创榜', id: 2884035 },
  hot: { name: '热歌榜', id: 3778678 },
};

/**
 * 获取歌单详情
 * @param playlistId 歌单ID
 * @param cookieText Cookie字符串
 * @param limit 限制返回的歌曲数量，null表示返回全部
 * @returns 歌单详情信息
 */
export async function playlistDetail(playlistId: string, cookieText: string, limit: number | null = null) {
  const url = `https://music.163.com/api/v6/playlist/detail`;
  const headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Safari/537.36 Chrome/91.0.4472.164 NeteaseMusicDesktop/2.10.2.200154',
    Referer: 'https://music.163.com/',
    Cookie: cookieText,
    'Content-Type': 'application/x-www-form-urlencoded',
  } as Record<string, string>;
  
  const data = new URLSearchParams({ id: playlistId }).toString();
  const response = await axios.post(url, data, { headers });
  const result = response.data;
  
  if (result.code !== 200 || !result.playlist) {
    throw new Error(`获取歌单详情失败: ${result.message || '未知错误'}`);
  }
  
  const playlist = result.playlist;
  const info: any = {
    id: playlist.id,
    name: playlist.name,
    coverImgUrl: playlist.coverImgUrl,
    creator: playlist.creator?.nickname || '',
    trackCount: playlist.trackCount,
    description: playlist.description || '',
    tags: playlist.tags || [],
    playCount: playlist.playCount || 0,
    createTime: playlist.createTime || 0,
    updateTime: playlist.updateTime || 0,
    tracks: [],
  };
  
  // 获取所有trackIds
  let trackIds: number[] = playlist.trackIds.map((t: any) => t.id);
  if (limit !== null && limit > 0) {
    trackIds = trackIds.slice(0, limit);
  }
  
  // 分批获取歌曲详细信息（每次最多100首）
  const songDetailUrl = 'https://interface3.music.163.com/api/v3/song/detail';
  for (let i = 0; i < trackIds.length; i += 100) {
    const batchIds = trackIds.slice(i, i + 100);
    const songDataPayload = { c: JSON.stringify(batchIds.map((id) => ({ id: id, v: 0 }))) } as any;
    const songData = new URLSearchParams(songDataPayload).toString();
    
    try {
      const songResp = await axios.post(songDetailUrl, songData, { headers });
      const songResult = songResp.data;
      
      if (songResult.songs) {
        songResult.songs.forEach((song: any) => {
          info.tracks.push({
            id: song.id,
            name: song.name,
            artists: song.ar.map((artist: any) => artist.name).join('/'),
            album: song.al.name,
            picUrl: song.al.picUrl.replace('http://', 'https://'),
            duration: song.dt || 0,
          });
        });
      }
    } catch (error: any) {
      logger.error(`获取歌单歌曲详情失败 (批次 ${i / 100 + 1}): ${error.message}`);
    }
  }
  
  return info;
}

/**
 * 获取专辑详情
 * @param albumId 专辑ID
 * @param cookieText Cookie字符串
 * @returns 专辑详情信息
 */
export async function albumDetail(albumId: string, cookieText: string) {
  const url = `https://music.163.com/api/v1/album/${albumId}`;
  const headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Safari/537.36 Chrome/91.0.4472.164 NeteaseMusicDesktop/2.10.2.200154',
    Referer: 'https://music.163.com/',
    Cookie: cookieText,
  } as Record<string, string>;
  
  try {
    const response = await axios.get(url, { headers });
    const result = response.data;
    
    if (result.code !== 200) {
      throw new Error(`获取专辑详情失败: ${result.message || '未知错误'}`);
    }
    
    const album = result.album;
    const info: any = {
      id: album.id,
      name: album.name,
      coverImgUrl: album.picUrl || album.blurPicUrl || '',
      artist: album.artist?.name || album.artists?.[0]?.name || '',
      publishTime: album.publishTime || 0,
      description: album.description || '',
      company: album.company || '',
      size: album.size || 0,
      songs: [],
    };
    
    // 处理歌曲列表
    if (result.songs && Array.isArray(result.songs)) {
      result.songs.forEach((song: any) => {
        info.songs.push({
          id: song.id,
          name: song.name,
          artists: song.ar?.map((artist: any) => artist.name).join('/') || '',
          album: song.al?.name || album.name,
          picUrl: (song.al?.picUrl || album.picUrl || '').replace('http://', 'https://'),
          duration: song.dt || 0,
        });
      });
    }
    
    return info;
  } catch (error: any) {
    logger.error(`获取专辑详情失败: ${error.message}`);
    throw error;
  }
}

export async function getToplists(limit = 20) {
  const cookieText = await neteaseCookieManager.readCookie();
  const toplists: any[] = [];
  for (const [name_en, { id: list_id }] of Object.entries(LEADERBOARD_IDS)) {
    try {
      const playlistData = await playlistDetail(String(list_id), cookieText, limit);
      (playlistData as any).name_en = name_en;
      toplists.push(playlistData);
    } catch (error: any) {
      logger.error(`Failed to fetch toplist ${name_en} (ID: ${list_id}):`, error.message);
    }
  }
  return toplists;
} 