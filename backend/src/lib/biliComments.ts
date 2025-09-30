import { getWbiKeys, encWbi, readBiliCookie, ensureBuvid34InCookie } from './bilibili';
import { makeRequest } from './utils';

const HEADERS: Record<string, string> = {
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0',
  Referer: 'https://www.bilibili.com/',
};

export async function getBiliComments(type: number, oid: number, mode = 3, pagination_str = '') {
  if (!type || !oid) throw new Error('type 和 oid 不能为空');
  await ensureBuvid34InCookie();
  const { imgKey, subKey } = await getWbiKeys();
  const params: any = { type, oid, mode, plat: 1, web_location: 1315875 };
  if (pagination_str) params.pagination_str = pagination_str;
  const signedParams = encWbi(params, imgKey, subKey);
  const { cookieString } = await readBiliCookie();
  if (!cookieString) throw new Error('无法加载或解析 Bilibili Cookie 文件');
  const apiUrl = 'https://api.bilibili.com/x/v2/reply/wbi/main';
  const headers = { ...HEADERS, Cookie: cookieString } as Record<string, string>;
  return await makeRequest({ url: apiUrl, params: signedParams, headers });
} 