import axios from 'axios';
import { decodeDmSegMobileReply } from '../proto/dmAdapter';
import { getWbiKeys, encWbi, readBiliCookie } from './bilibili';
import { logger } from './logger';
import http from 'http';
import https from 'https';

const httpAgent = new http.Agent({ keepAlive: true });
const httpsAgent = new https.Agent({ keepAlive: true });

const HEADERS: Record<string, string> = {
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0',
  Referer: 'https://www.bilibili.com/',
};

logger.info('[Bilibili Danmaku] Using statically compiled protobuf definitions.');

export async function getBiliDanmaku(oid: number, segment_index = 1) {
  const { imgKey, subKey } = await getWbiKeys();
  const params = { type: 1, oid, segment_index } as any;
  const signedParams = encWbi(params, imgKey, subKey);
  const { cookieString } = await readBiliCookie();
  const danmakuApiUrl = 'https://api.bilibili.com/x/v2/dm/wbi/web/seg.so';
  const response = await axios.get(danmakuApiUrl, { params: signedParams, headers: { ...HEADERS, Cookie: cookieString || '' }, responseType: 'arraybuffer', httpAgent, httpsAgent });
  const object = decodeDmSegMobileReply(response.data);
  return object;
} 