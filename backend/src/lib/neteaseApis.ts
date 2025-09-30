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

async function playlistDetail(playlistId: string, cookieText: string, limit: number | null = null) {
  const url = `https://music.163.com/api/v6/playlist/detail`;
  const headers = {
    'User-Agent': 'Mozilla/5.0',
    Referer: 'https://music.163.com/',
    Cookie: cookieText,
    'Content-Type': 'application/x-www-form-urlencoded',
  } as Record<string, string>;
  const data = new URLSearchParams({ id: playlistId }).toString();
  const response = await axios.post(url, data, { headers });
  const result = response.data;
  if (result.code !== 200 || !result.playlist) throw new Error('Failed to fetch playlist details');
  const playlist = result.playlist;
  const info: any = {
    id: playlist.id,
    name: playlist.name,
    coverImgUrl: playlist.coverImgUrl,
    creator: playlist.creator?.nickname || '',
    trackCount: playlist.trackCount,
    description: playlist.description || '',
    tracks: [],
  };
  let trackIds: number[] = playlist.trackIds.map((t: any) => t.id);
  if (limit !== null) trackIds = trackIds.slice(0, limit);
  const songDetailUrl = 'https://interface3.music.163.com/api/v3/song/detail';
  for (let i = 0; i < trackIds.length; i += 100) {
    const batchIds = trackIds.slice(i, i + 100);
    const songDataPayload = { c: JSON.stringify(batchIds.map((id) => ({ id: id, v: 0 }))) } as any;
    const songData = new URLSearchParams(songDataPayload).toString();
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
        });
      });
    }
  }
  return info;
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