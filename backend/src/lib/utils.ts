import path from 'path';
import fs from 'fs/promises';
import axios from 'axios';
import http from 'http';
import https from 'https';
import { logger } from './logger';

export function ids(text: string): string {
  if (text.includes('163cn.tv')) {
    logger.warn("'163cn.tv' links require a redirect check which is not implemented in this version. Please use a direct music.163.com link or song ID.");
  }
  if (text.includes('music.163.com')) {
    const match = text.match(/id=([^&]+)/);
    if (match) return match[1];
  }
  return text;
}

export function size(value: number): string {
  if (value === 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  const i = Math.floor(Math.log(value) / Math.log(1024));
  return `${parseFloat((value / Math.pow(1024, i)).toFixed(2))} ${units[i]}`;
}

export function music_level1(value: string): string {
  const levels: Record<string, string> = {
    standard: '标准音质',
    exhigh: '极高音质',
    lossless: '无损音质',
    hires: 'Hires音质',
    sky: '沉浸环绕声',
    jyeffect: '高清环绕声',
    jymaster: '超清母带',
  };
  return levels[value] || '未知音质';
}

export function qq_ids(url: string): string {
  if (url.includes('c6.y.qq.com')) {
    logger.warn("'c6.y.qq.com' links require a redirect check which is not implemented in this version. Please use a direct y.qq.com link or song ID/MID.");
  }
  if (url.includes('y.qq.com')) {
    const detailMatch = url.match(/\/songDetail\/([^/]+)/);
    if (detailMatch) return detailMatch[1];
    const idMatch = url.match(/id=([^&]+)/);
    if (idMatch) return idMatch[1];
  }
  return url;
}

const httpAgent = new http.Agent({ keepAlive: true });
const httpsAgent = new https.Agent({ keepAlive: true });

let config: any = null;

export type CompactLogOptions = {
  maxDepth: number;
  maxStringLength: number;
  maxArrayItems: number;
  maxObjectKeys: number;
  maxTotalLength: number;
};

function truncateString(input: string, max: number): string {
  if (typeof input !== 'string') return String(input);
  if (input.length <= max) return input;
  return input.slice(0, Math.max(0, max - 3)) + '...';
}

function compactValue(value: any, depth: number, seen: WeakSet<object>, opt: CompactLogOptions): any {
  if (value === null || value === undefined) return value;
  const type = typeof value;
  if (type === 'string') return truncateString(value, opt.maxStringLength);
  if (type === 'number' || type === 'boolean' || type === 'bigint') return value;
  if (type === 'function') return '[Function]';
  if (type === 'symbol') return String(value);

  if (depth >= opt.maxDepth) {
    if (Array.isArray(value)) return `[Array(${value.length})]`;
    if (value instanceof Date) return value.toISOString();
    if (value instanceof Error) return `${value.name}: ${value.message}`;
    return '[Object]';
  }

  if (Array.isArray(value)) {
    const out: any[] = [];
    const limit = Math.min(value.length, opt.maxArrayItems);
    for (let i = 0; i < limit; i++) out.push(compactValue(value[i], depth + 1, seen, opt));
    if (value.length > limit) out.push('...');
    return out;
  }

  if (type === 'object') {
    if (seen.has(value)) return '[Circular]';
    seen.add(value);

    if (value instanceof Date) return value.toISOString();
    if (value instanceof Error) return { name: value.name, message: value.message, stack: truncateString(value.stack || '', opt.maxStringLength) };

    const keys = Object.keys(value);
    const out: Record<string, any> = {};
    const limit = Math.min(keys.length, opt.maxObjectKeys);
    for (let i = 0; i < limit; i++) {
      const k = keys[i];
      try {
        out[k] = compactValue((value as any)[k], depth + 1, seen, opt);
      } catch {
        out[k] = '[Unreadable]';
      }
    }
    // 超出部分用省略，不再额外标注
    return out;
  }

  try {
    return JSON.parse(JSON.stringify(value));
  } catch {
    return String(value);
  }
}

export function compactLogString(value: any, options?: Partial<CompactLogOptions>): string {
  const opt: CompactLogOptions = {
    maxDepth: options?.maxDepth ?? 2,
    maxStringLength: options?.maxStringLength ?? 200,
    maxArrayItems: options?.maxArrayItems ?? 10,
    maxObjectKeys: options?.maxObjectKeys ?? 20,
    maxTotalLength: options?.maxTotalLength ?? 2000,
  };
  const compacted = compactValue(value, 0, new WeakSet(), opt);
  let text: string;
  try {
    text = JSON.stringify(compacted);
  } catch {
    text = String(compacted);
  }
  if (text.length > opt.maxTotalLength) {
    return text.slice(0, Math.max(0, opt.maxTotalLength - 3)) + '...';
  }
  // 强制单行
  return text.replace(/\n|\r/g, '');
}

export async function getConfig(): Promise<any> {
  if (config) return config;
  try {
    // 仅从根目录读取 config.json，不再回退到 demo 目录
    const configPath = path.resolve(process.cwd(), 'config.json');
    await fs.access(configPath);
    const configData = await fs.readFile(configPath, 'utf-8');
    config = JSON.parse(configData);

    // 规范化 log_level
    const level = String(config?.log_level || 'INFO').toUpperCase();
    if (!['INFO', 'DEV'].includes(level)) {
      config.log_level = 'INFO';
    } else {
      config.log_level = level;
    }

    logger.info('[Config] Loaded config.json successfully.');
    if (config?.bili_proxy?.enabled) {
      logger.info(`[Config] Bilibili proxy is ENABLED. Proxy URL: ${config.bili_proxy.url}`);
    } else {
      logger.info('[Config] Bilibili proxy is DISABLED.');
    }
    logger.info(`[Config] Log level: ${config.log_level}`);
    return config;
  } catch (e: any) {
    logger.warn(`[Config] Could not read or parse config.json in project root, proxy will be disabled. Error: ${e.message}`);
    config = { bili_proxy: { enabled: false, url: '' }, log_level: 'INFO' };
    return config;
  }
}

export async function makeRequest(options: {
  url: string;
  method?: 'get' | 'post' | 'put' | 'patch' | 'delete';
  params?: Record<string, any>;
  data?: any;
  headers?: Record<string, string>;
}): Promise<any> {
  const { url, method = 'get', params, data, headers } = options;
  const appConfig = await getConfig();
  const isDevLog = String(appConfig?.log_level).toUpperCase() === 'DEV';

  if (appConfig?.bili_proxy?.enabled && appConfig?.bili_proxy?.url) {
    const proxyUrl = appConfig.bili_proxy.url as string;

    if (isDevLog) {
      logger.dev(`[Proxy Request] ${compactLogString({ target: url, proxyUrl, method, params, data, headers })}`);
    } else {
      logger.info(`[Proxy Request] Routing via ${proxyUrl} for target: ${url}`);
    }

    try {
      const response = await axios.post(proxyUrl, { targetUrl: url, method, params, data, headers }, { timeout: 15000 });
      if (isDevLog) {
        logger.dev(`[Proxy Response] ${compactLogString({ status: response.status, headers: response.headers, data: response.data })}`);
      }
      return response.data;
    } catch (e: any) {
      logger.error(`[Proxy Request] Proxy request to ${proxyUrl} failed: ${e.message}`);
      if (isDevLog && e?.response) {
        logger.dev(`[Proxy Error Response] ${compactLogString({ status: e.response.status, headers: e.response.headers, data: e.response.data })}`);
      }
      throw new Error(`Proxy failed: ${e.message}`);
    }
  } else {
    if (isDevLog) {
      logger.dev(`[Direct Request] ${compactLogString({ url, method, params, data, headers })}`);
    } else {
      logger.info(`[Direct Request] to: ${url}`);
    }
    const response = await axios({ url, method, params, data, headers, httpAgent, httpsAgent, timeout: 15000 });
    if (isDevLog) {
      logger.dev(`[Direct Response] ${compactLogString({ status: response.status, headers: response.headers, data: response.data })}`);
    }
    return response.data;
  }
} 