import axios from 'axios';
import qrcode from 'qrcode-terminal';
import fs from 'fs/promises';
import path from 'path';
import http from 'http';
import https from 'https';
import crypto from 'crypto';
import { logger } from './logger';

const httpAgent = new http.Agent({ keepAlive: true });
const httpsAgent = new https.Agent({ keepAlive: true });

const BILI_COOKIE_FILE = path.resolve(process.cwd(), 'cookie', 'bili_cookie.json');
const HEADERS: Record<string, string> = {
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0',
  Referer: 'https://passport.bilibili.com/',
};

const mixinKeyEncTab = [
  46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52,
];

function getMixinKey(orig: string) {
  let tempStr = '';
  mixinKeyEncTab.forEach((i) => {
    tempStr += orig[i];
  });
  return tempStr.slice(0, 32);
}

export async function getWbiKeys(): Promise<{ imgKey: string; subKey: string }> {
  const navUrl = 'https://api.bilibili.com/x/web-interface/nav';
  const headers = { ...HEADERS, Referer: 'https://www.bilibili.com/' } as Record<string, string>;
  const response = await axios.get(navUrl, { headers, httpAgent, httpsAgent });
  const jsonContent = response.data;
  const imgUrl = jsonContent?.data?.wbi_img?.img_url;
  const subUrl = jsonContent?.data?.wbi_img?.sub_url;
  if (!imgUrl || !subUrl) throw new Error('Failed to get WBI keys from nav API');
  const imgKey = imgUrl.substring(imgUrl.lastIndexOf('/') + 1, imgUrl.lastIndexOf('.'));
  const subKey = subUrl.substring(subUrl.lastIndexOf('/') + 1, subUrl.lastIndexOf('.'));
  return { imgKey, subKey };
}

export function encWbi(params: Record<string, any>, imgKey: string, subKey: string): Record<string, any> {
  const mixinKey = getMixinKey(imgKey + subKey);
  const currTime = Math.round(Date.now() / 1000);
  const newParams = { ...params, wts: currTime } as Record<string, any>;
  const sortedParams = Object.keys(newParams)
    .sort()
    .reduce((obj: Record<string, any>, key) => {
      obj[key] = newParams[key];
      return obj;
    }, {} as Record<string, any>);
  const query = new URLSearchParams();
  for (const key in sortedParams) {
    const value = String(sortedParams[key]).replace(/[!'()*]/g, '');
    query.append(key, value);
  }
  const queryString = query.toString();
  const w_rid = crypto.createHash('md5').update(queryString + mixinKey).digest('hex');
  return { ...sortedParams, w_rid };
}

function stripBom(text: string): string {
  if (!text) return text;
  // Remove UTF-8 BOM if present
  if (text.charCodeAt(0) === 0xfeff) return text.slice(1);
  return text;
}

function tryParseBiliCookie(text: string): Record<string, string> | null {
  const clean = stripBom(String(text)).trim();
  if (!clean) return null;
  // First try JSON
  try {
    const obj = JSON.parse(clean);
    if (obj && typeof obj === 'object') return obj as Record<string, string>;
  } catch {}
  // Fallback: parse "key=value; key2=value2" or line-separated
  const cookieObject: Record<string, string> = {};
  const segments = clean.includes(';') ? clean.split(';') : clean.split(/\r?\n/);
  for (const segment of segments) {
    const match = segment.match(/^\s*([^=]+)=(.*)\s*$/);
    if (match) cookieObject[match[1].trim()] = match[2].trim();
  }
  return Object.keys(cookieObject).length ? cookieObject : null;
}

export async function readBiliCookie(): Promise<{ cookieObj: any | null; cookieString: string | null }> {
  try {
    const text = await fs.readFile(BILI_COOKIE_FILE, 'utf-8');
    const cookieObj = tryParseBiliCookie(text);
    if (!cookieObj || !cookieObj.SESSDATA || !cookieObj.bili_jct)
      throw new Error('Cookie is incomplete or cannot be parsed');
    const cookieString = Object.entries(cookieObj)
      .map(([k, v]) => `${k}=${v as string}`)
      .join('; ');
    return { cookieObj, cookieString };
  } catch (e) {
    return { cookieObj: null, cookieString: null };
  }
}

async function generateQrCode() {
  const url = 'https://passport.bilibili.com/x/passport-login/web/qrcode/generate';
  const response = await axios.get(url, { headers: HEADERS, httpAgent, httpsAgent });
  if (response.data?.code === 0) return response.data.data;
  logger.error(`[Bilibili Login] API返回错误: ${response.data?.message}`);
  return null;
}

async function pollQrCodeStatus(qrcode_key: string) {
  const url = 'https://passport.bilibili.com/x/passport-login/web/qrcode/poll';
  const params = { qrcode_key } as any;
  const startTime = Date.now();
  while (Date.now() - startTime < 180000) {
    const response = await axios.get(url, { params, headers: HEADERS, httpAgent, httpsAgent });
    const data = response.data;
    if (data?.code === 0) {
      const loginStatus = data.data || {};
      const code = loginStatus.code;
      if (code === 0) {
        process.stdout.write('\n[Bilibili Login] [成功] 登录成功！\n');
        return response.headers['set-cookie'];
      } else if (code === 86038) {
        process.stdout.write('\n[Bilibili Login] [失败] 二维码已失效。\n');
        return null;
      } else if (code === 86090) {
        process.stdout.write('\r[Bilibili Login] [信息] 二维码已扫描，请在手机上确认...');
      } else if (code === 86101) {
        process.stdout.write('\r[Bilibili Login] [信息] 等待扫码...');
      } else {
        process.stdout.write(`\n[Bilibili Login] [信息] 未知状态: ${loginStatus.message}\n`);
      }
    } else {
      logger.error(`\n[Bilibili Login] 轮询API返回错误: ${data?.message}`);
      return null;
    }
    await new Promise((r) => setTimeout(r, 2000));
  }
  process.stdout.write('\n[Bilibili Login] [失败] 登录超时。\n');
  return null;
}

async function updateBiliCookie(cookiesHeader: string[] | null) {
  if (!cookiesHeader) return;
  const cookieDict: Record<string, string> = {};
  cookiesHeader.forEach((cookieStr) => {
    const parts = cookieStr.split(';')[0].split('=');
    if (parts.length === 2) {
      const key = parts[0].trim();
      const value = parts[1].trim();
      if (["SESSDATA", "bili_jct", "DedeUserID", "DedeUserID__ckMd5", "sid"].includes(key)) {
        cookieDict[key] = value;
      }
    }
  });
  try {
    const { buvid3, buvid4 } = await getBuvid34();
    cookieDict.buvid3 = buvid3;
    cookieDict.buvid4 = buvid4;
  } catch (e) {
    logger.warn('[Bilibili] 获取 buvid3/4 失败，已跳过写入。');
  }
  try {
    await fs.mkdir(path.dirname(BILI_COOKIE_FILE), { recursive: true });
    await fs.writeFile(BILI_COOKIE_FILE, JSON.stringify(cookieDict, null, 2), 'utf-8');
    logger.info(`[Bilibili Login] Cookie已成功更新到 '${BILI_COOKIE_FILE}'。`);
  } catch (e: any) {
    logger.error(`[Bilibili Login] 写入Cookie文件失败: ${e.message}`);
  }
}

async function biliQrLogin() {
  logger.info('='.repeat(25));
  logger.info('[Bilibili Login] 正在启动Bilibili扫码登录...');
  const qrData = await generateQrCode();
  if (!qrData) return;
  logger.info('[Bilibili Login] 请使用Bilibili手机客户端扫描下方二维码登录：');
  qrcode.generate(qrData.url, { small: true });
  const cookiesHeader = await pollQrCodeStatus(qrData.qrcode_key);
  if (cookiesHeader) await updateBiliCookie(cookiesHeader as any);
  logger.info('='.repeat(25));
}

export async function checkBiliCookieValidity() {
  logger.info('[Bilibili] 正在检查Cookie有效性...');
  let loginNeeded = false;
  let biliCookies: any = {};
  try {
    const cookieData = await fs.readFile(BILI_COOKIE_FILE, 'utf-8');
    const parsed = tryParseBiliCookie(cookieData);
    if (!parsed) {
      logger.warn(`[Bilibili] 无法解析 Cookie 文件内容: ${BILI_COOKIE_FILE}。将启动扫码登录。`);
      loginNeeded = true;
    } else {
      biliCookies = parsed;
      if (!biliCookies.SESSDATA || !biliCookies.bili_jct || !biliCookies.DedeUserID) {
        logger.warn('[Bilibili] Cookie文件不完整。将启动扫码登录。');
        loginNeeded = true;
        biliCookies = {};
      }
    }
  } catch (error: any) {
    if (error.code === 'ENOENT' || error instanceof SyntaxError) {
      logger.warn(`[Bilibili] 未找到或无法解析 'bili_cookie.json' 文件: ${BILI_COOKIE_FILE}。将启动扫码登录。`);
      loginNeeded = true;
    } else {
      logger.error(`[Bilibili] 读取cookie文件时发生错误 (${BILI_COOKIE_FILE}): ${error.message}`);
    }
    biliCookies = {};
  }
  if (!loginNeeded) {
    const csrf = biliCookies.bili_jct || '';
    const checkUrl = `https://passport.bilibili.com/x/passport-login/web/cookie/info`;
    const cookieString = Object.entries(biliCookies)
      .map(([k, v]) => `${k}=${v as string}`)
      .join('; ');
    try {
      const response = await axios.get(checkUrl, { params: { csrf }, headers: { ...HEADERS, Cookie: cookieString }, httpAgent, httpsAgent });
      const data = response.data;
      if (data?.code === 0 && data.data?.refresh === false) {
        logger.info('[Bilibili] Cookie有效，状态正常。');
      } else if (data?.code === 0 && data.data?.refresh === true) {
        logger.warn('[Bilibili] Cookie有效，但B站建议刷新。将启动扫码登录。');
        loginNeeded = true;
      } else if (data?.code === -101) {
        logger.raw('='.repeat(60));
        logger.error('[Bilibili] [严重警告] Cookie已失效！将启动扫码登录。');
        logger.warn('       B站相关功能（如获取高清视频流）将无法正常使用。');
        logger.warn('       请扫描下方的二维码重新登录。');
        logger.raw('='.repeat(60));
        loginNeeded = true;
      } else {
        logger.warn(`[Bilibili] Cookie检查返回未知状态: code=${data?.code}, message=${data?.message}`);
      }
    } catch (e: any) {
      logger.error(`[Bilibili] 检查Cookie时发生网络错误: ${e.message}`);
    }
  }
  if (loginNeeded) biliQrLogin();
  else ensureBuvid34InCookie();
}

export async function getBuvid34(): Promise<{ buvid3: string; buvid4: string }> {
  const url = 'https://api.bilibili.com/x/frontend/finger/spi';
  const response = await axios.get(url, { headers: HEADERS, httpAgent, httpsAgent });
  const resp = response.data;
  if (resp?.code === 0 && resp?.data?.b_3 && resp?.data?.b_4) {
    return { buvid3: resp.data.b_3, buvid4: resp.data.b_4 };
  }
  throw new Error(`Unexpected response: ${JSON.stringify(resp)}`);
}

export async function ensureBuvid34InCookie() {
  try {
    const data = await fs.readFile(BILI_COOKIE_FILE, 'utf-8');
    const cookieObjRaw = tryParseBiliCookie(data) || {} as Record<string, any>;
    if (cookieObjRaw.buvid3 && cookieObjRaw.buvid4) return;
    const { buvid3, buvid4 } = await getBuvid34();
    const cookieObj: Record<string, any> = { ...cookieObjRaw, buvid3, buvid4 };
    await fs.mkdir(path.dirname(BILI_COOKIE_FILE), { recursive: true });
    await fs.writeFile(BILI_COOKIE_FILE, JSON.stringify(cookieObj, null, 2), 'utf-8');
    logger.info('[Bilibili] 已补充写入 buvid3/4。');
  } catch (e: any) {
    logger.warn('[Bilibili] 补充 buvid3/4 失败:', e.message);
  }
} 