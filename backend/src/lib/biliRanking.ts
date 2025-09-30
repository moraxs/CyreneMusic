import axios from 'axios';
import { getWbiKeys, encWbi, readBiliCookie } from './bilibili';
import http from 'http';
import https from 'https';

const httpAgent = new http.Agent({ keepAlive: true });
const httpsAgent = new https.Agent({ keepAlive: true });

const HEADERS: Record<string, string> = {
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0',
  Referer: 'https://www.bilibili.com/',
};

export async function getBiliRanking(rid = '0', type = 'all') {
  const { imgKey, subKey } = await getWbiKeys();
  const params = { rid, type } as Record<string, any>;
  const signedParams = encWbi(params, imgKey, subKey);
  const { cookieString } = await readBiliCookie();
  if (!cookieString) throw new Error('无法加载或解析Bilibili Cookie文件');
  const biliApiUrl = 'https://api.bilibili.com/x/web-interface/ranking/v2';
  const response = await axios.get(biliApiUrl, { params: signedParams, headers: { ...HEADERS, Cookie: cookieString }, httpAgent, httpsAgent });
  const data = response.data;
  if (data?.data?.list) {
    data.data.list.forEach((item: any) => {
      if (item.pic && typeof item.pic === 'string') item.pic = item.pic.replace(/^http:/, 'https:');
    });
  }
  return data;
} 