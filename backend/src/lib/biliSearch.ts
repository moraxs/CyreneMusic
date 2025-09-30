import { getWbiKeys, encWbi, readBiliCookie, ensureBuvid34InCookie } from './bilibili';
import { makeRequest } from './utils';

const HEADERS: Record<string, string> = {
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0',
  Referer: 'https://www.bilibili.com/',
};

export async function getBiliSearch(keyword: string) {
  if (!keyword) throw new Error('keyword 不能为空');
  await ensureBuvid34InCookie();
  const { imgKey, subKey } = await getWbiKeys();
  const signedParams = encWbi({ keyword }, imgKey, subKey);
  const { cookieString } = await readBiliCookie();
  if (!cookieString) throw new Error('无法加载或解析 Bilibili Cookie 文件');
  const apiUrl = 'https://api.bilibili.com/x/web-interface/wbi/search/all/v2';
  const headers = { ...HEADERS, Cookie: cookieString } as Record<string, string>;
  return await makeRequest({ url: apiUrl, params: signedParams, headers });
} 