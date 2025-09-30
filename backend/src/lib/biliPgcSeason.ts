import { makeRequest } from './utils';

const HEADERS: Record<string, string> = {
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0',
  Referer: 'https://www.bilibili.com/',
};

export async function getBiliPgcSeason(ep_id?: string, season_id?: string) {
  if (!ep_id && !season_id) throw new Error('ep_id or season_id is required');
  const params = ep_id ? { ep_id } : { season_id };
  const apiUrl = 'https://api.bilibili.com/pgc/view/web/season';
  return await makeRequest({ url: apiUrl, params, headers: HEADERS });
} 