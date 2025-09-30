import { readBiliCookie } from './bilibili';
import { makeRequest } from './utils';

const HEADERS: Record<string, string> = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0',
};

export async function getBiliPgcPlayUrl(ep_id?: string, cid?: string) {
  if (!ep_id && !cid) throw new Error('ep_id或cid必须提供一个');
  const { cookieString } = await readBiliCookie();
  if (!cookieString) throw new Error('无法加载或解析Bilibili Cookie文件');
  const params = { ep_id, cid, qn: 0, fnval: 16, fnver: 0, fourk: 1 } as any;
  const playApiUrl = 'https://api.bilibili.com/pgc/player/web/playurl';
  const headers = { ...HEADERS, Referer: 'https://www.bilibili.com/', Cookie: cookieString } as Record<string, string>;
  return await makeRequest({ url: playApiUrl, params, headers });
} 