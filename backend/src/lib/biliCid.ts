import axios from 'axios';
import http from 'http';
import https from 'https';

const httpAgent = new http.Agent({ keepAlive: true });
const httpsAgent = new https.Agent({ keepAlive: true });

const HEADERS: Record<string, string> = {
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0',
  Referer: 'https://www.bilibili.com/',
};

export async function getBiliCid(bvid: string) {
  if (!bvid) throw new Error('BVID 不能为空');
  const pagelistUrl = 'https://api.bilibili.com/x/player/pagelist';
  const response = await axios.get(pagelistUrl, { params: { bvid }, headers: HEADERS, httpAgent, httpsAgent });
  const pagelistData = response.data;
  if (pagelistData?.code !== 0 || !pagelistData?.data?.[0]?.cid) {
    const errorMessage = pagelistData?.message || '未能获取到有效的cid';
    throw new Error(errorMessage);
  }
  return { code: 0, message: '0', cid: pagelistData.data[0].cid };
} 