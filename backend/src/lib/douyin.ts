import axios from "axios";
import fs from "fs";
import path from "path";
import smCrypto from "sm-crypto";
const sm3Hash: any = (smCrypto as any).sm3;

// Minimal helpers and constants mirroring Python implementation
const DEBUG = false;
export const DEFAULT_USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36";

const DEFAULT_COOKIE_JSON = path.resolve(process.cwd(), "cookie/douyin_cookie.json");

// ====================== Utilities ======================
function dprint(...args: any[]) {
  if (DEBUG) console.log("[DEBUG]", ...args);
}

const URL_REGEX = /https?:\/\/[^\s]+/gi;
const ID_PATTERNS: RegExp[] = [
  /\/video\/(\d{19})/g,
  /\/note\/(\d{19})/g,
  /\/slides\/(\d{19})/g,
  /iesdouyin\.com\/share\/(?:video|note|slides)\/(\d{19})\//g,
  /[?&]modal_id=(\d{19})(?:&|$)/g,
];

export function extractUrls(text: string): string[] {
  return text.match(URL_REGEX) || [];
}

export function extractAwemeIds(text: string): string[] {
  const found = new Set<string>();
  for (const p of ID_PATTERNS) {
    for (const m of text.matchAll(p)) {
      const id = m[1];
      if (id) found.add(id);
    }
  }
  return Array.from(found).sort();
}

export function parseCookieStrToDict(cookieStr: string): Record<string, string> {
  const result: Record<string, string> = {};
  for (const raw of cookieStr.split(";")) {
    const part = raw.trim();
    if (!part || !part.includes("=")) continue;
    const [k, v] = part.split("=", 1 + 1);
    const key = (k || "").trim();
    const val = (v || "").trim();
    if (key) result[key] = val;
  }
  return result;
}

export function buildCookieStringFromDict(d: Record<string, string>): string {
  const parts: string[] = [];
  for (const [k, v] of Object.entries(d)) {
    if (!k) continue;
    parts.push(`${k}=${v}`);
  }
  return parts.join("; ");
}

export function loadCookieJsonDict(filePath: string): Record<string, string> {
  try {
    if (!fs.existsSync(filePath)) return {};
    const text = fs.readFileSync(filePath, "utf-8");
    const data = JSON.parse(text);
    const result: Record<string, string> = {};
    if (data && typeof data === "object") {
      for (const [k, v] of Object.entries<any>(data)) {
        if (!k) continue;
        if (v === null || v === undefined) continue;
        result[k] = String(v);
      }
    }
    return result;
  } catch {
    return {};
  }
}

export function loadDefaultCookieString(): string {
  const dict: Record<string, string> = {};
  Object.assign(dict, loadCookieJsonDict(DEFAULT_COOKIE_JSON));
  const envCookie = process.env.DOUK_COOKIE || "";
  if (envCookie) Object.assign(dict, parseCookieStrToDict(envCookie));
  return buildCookieStringFromDict(dict);
}

// Axios helpers
async function resolveFinalUrl(url: string): Promise<string> {
  try {
    const r = await axios.head(url, { maxRedirects: 5, validateStatus: () => true });
    if (r.request?.res?.responseUrl) return r.request.res.responseUrl;
    if (r.headers?.location) return r.headers.location;
  } catch {}
  try {
    const r = await axios.get(url, { maxRedirects: 5, validateStatus: () => true });
    if (r.request?.res?.responseUrl) return r.request.res.responseUrl;
  } catch {}
  return url;
}

function encodeParamsLikePython(params: Record<string, any>): string {
  // Python: urlencode(params, quote_via=quote) => %20 for spaces, no '+'.
  // No sorting; keep insertion order.
  const pairs: string[] = [];
  for (const [k, v] of Object.entries(params)) {
    const key = encodeURIComponent(k);
    const value = encodeURIComponent(String(v));
    pairs.push(`${key}=${value}`);
  }
  return pairs.join("&");
}

// ====================== ABogus (ported) ======================
class ABogus {
  private static filter = /%([0-9A-F]{2})/g;
  private static argumentsArr = [0, 1, 14];
  private static uaKey = "\u0000\u0001\u000e";
  private static endString = "cus";
  private static regInit = [
    1937774191,
    1226093241,
    388252375,
    3666478592,
    2842636476,
    372324522,
    3817729613,
    2969243214,
  ];
  private static strMap: Record<string, string> = {
    s0: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=",
    s1: "Dkdpgh4ZKsQB80/Mfvw36XI1R25+WUAlEi7NLboqYTOPuzmFjJnryx9HVGcaStCe=",
    s2: "Dkdpgh4ZKsQB80/Mfvw36XI1R25-WUAlEi7NLboqYTOPuzmFjJnryx9HVGcaStCe=",
    s3: "ckdp1h4ZKsUB80/Mfvw36XIgR25+WQAlEi7NLboqYTOPuzmFjJnryx9HVGDaStCe",
    s4: "Dkdpgh2ZmsQB80/MfvV36XI1R45-WUAlEixNLwoqYTOPuzKFjJnry79HbGcaStCe",
  };

  private chunk: number[] = [];
  private size = 0;
  private regState: number[] = ABogus.regInit.slice();
  private uaCode: number[];
  private browser: string;
  private browserLen: number;
  private browserCode: number[];

  constructor(userAgent: string, platform: string | null = null) {
    this.uaCode = this.generateUaCode(userAgent);
    this.browser = ABogus.generateBrowserInfo(platform || "Win32");
    this.browserLen = this.browser.length;
    this.browserCode = ABogus.charCodeAt(this.browser);
  }

  private static randomList(a: number | null = null, b = 170, c = 85, d = 0, e = 0, f = 0, g = 0): number[] {
    const r = a ?? Math.random() * 10000;
    const v = [r, (r | 0) & 255, (r | 0) >> 8] as any as number[];
    let s = (v[1] & b) | d;
    v.push(s);
    s = (v[1] & c) | e;
    v.push(s);
    s = (v[2] & b) | f;
    v.push(s);
    s = (v[2] & c) | g;
    v.push(s);
    return v.slice(-4);
  }

  static fromCharCode(...args: number[]): string {
    return String.fromCharCode(...args);
  }

  static list_1(randomNum?: number | null, a = 170, b = 85, c = 45): number[] {
    return ABogus.randomList(randomNum ?? null, a, b, 1, 2, 5, c & a);
  }

  static list_2(randomNum?: number | null, a = 170, b = 85): number[] {
    return ABogus.randomList(randomNum ?? null, a, b, 1, 0, 0, 0);
  }

  static list_3(randomNum?: number | null, a = 170, b = 85): number[] {
    return ABogus.randomList(randomNum ?? null, a, b, 1, 0, 5, 0);
  }

  generateString1(r1?: number | null, r2?: number | null, r3?: number | null): string {
    return (
      ABogus.fromCharCode(...ABogus.list_1(r1)) +
      ABogus.fromCharCode(...ABogus.list_2(r2)) +
      ABogus.fromCharCode(...ABogus.list_3(r3))
    );
  }

  generateString2(urlParams: string, method = "GET", startTime = 0, endTime = 0): string {
    const a = this.generateString2List(urlParams, method, startTime, endTime);
    const e = ABogus.endCheckNum(a);
    a.push(...this.browserCode);
    a.push(e);
    return ABogus.rc4Encrypt(ABogus.fromCharCode(...a), "y");
  }

  private generateUaCode(userAgent: string): number[] {
    const u = ABogus.rc4Encrypt(userAgent, ABogus.uaKey);
    const u2 = ABogus.generateResult(u, "s3");
    return this.sum(u2);
  }

  private generateString2List(urlParams: string, method = "GET", startTime = 0, endTime = 0): number[] {
    const nowMs = Date.now();
    startTime = startTime || nowMs;
    endTime = endTime || startTime + Math.floor(4 + Math.random() * 5);
    const paramsArray = this.generateParamsCode(urlParams);
    const methodArray = this.generateMethodCode(method);
    return ABogus.list_4(
      (endTime >> 24) & 255,
      paramsArray[21],
      this.uaCode[23],
      (endTime >> 16) & 255,
      paramsArray[22],
      this.uaCode[24],
      (endTime >> 8) & 255,
      endTime & 255,
      (startTime >> 24) & 255,
      (startTime >> 16) & 255,
      (startTime >> 8) & 255,
      startTime & 255,
      methodArray[21],
      methodArray[22],
      Math.trunc(endTime / 256 / 256 / 256 / 256) >> 0,
      Math.trunc(startTime / 256 / 256 / 256 / 256) >> 0,
      this.browserLen,
    );
  }

  private static regToArray(a: number[]): number[] {
    const o = new Array<number>(32).fill(0);
    for (let i = 0; i < 8; i++) {
      let c = a[i];
      o[4 * i + 3] = 255 & c;
      c >>>= 8;
      o[4 * i + 2] = 255 & c;
      c >>>= 8;
      o[4 * i + 1] = 255 & c;
      c >>>= 8;
      o[4 * i] = 255 & c;
    }
    return o;
  }

  private compress(a: number[]): void {
    const f = ABogus.generateF(a);
    const i = this.regState.slice();
    for (let o = 0; o < 64; o++) {
      let c = ABogus.de(i[0], 12) + i[4] + ABogus.de(ABogus.pe(o), o);
      c = c >>> 0;
      c = ABogus.de(c, 7);
      const s = (c ^ ABogus.de(i[0], 12)) >>> 0;

      let u = ABogus.he(o, i[0], i[1], i[2]);
      u = (u + i[3] + s + f[o + 68]) >>> 0;

      let b = ABogus.ve(o, i[4], i[5], i[6]);
      b = (b + i[7] + c + f[o]) >>> 0;

      i[3] = i[2];
      i[2] = ABogus.de(i[1], 9);
      i[1] = i[0];
      i[0] = u;

      i[7] = i[6];
      i[6] = ABogus.de(i[5], 19);
      i[5] = i[4];
      i[4] = (b ^ ABogus.de(b, 9) ^ ABogus.de(b, 17)) >>> 0;
    }
    for (let l = 0; l < 8; l++) {
      this.regState[l] = (this.regState[l] ^ i[l]) >>> 0;
    }
  }

  private static generateF(e: number[]): number[] {
    const r = new Array<number>(132).fill(0);
    for (let t = 0; t < 16; t++) {
      r[t] = ((e[4 * t] << 24) | (e[4 * t + 1] << 16) | (e[4 * t + 2] << 8) | e[4 * t + 3]) >>> 0;
    }
    for (let n = 16; n < 68; n++) {
      let a = r[n - 16] ^ r[n - 9] ^ ABogus.de(r[n - 3], 15);
      a = a ^ ABogus.de(a, 15) ^ ABogus.de(a, 23);
      r[n] = (a ^ ABogus.de(r[n - 13], 7) ^ r[n - 6]) >>> 0;
    }
    for (let n = 68; n < 132; n++) {
      r[n] = (r[n - 68] ^ r[n - 64]) >>> 0;
    }
    return r;
  }

  private static padArray(arr: number[], length = 60): number[] {
    while (arr.length < length) arr.push(0);
    return arr;
  }

  private fill(length = 60): void {
    const size = 8 * this.size;
    this.chunk.push(128);
    this.chunk = ABogus.padArray(this.chunk, length);
    for (let i = 0; i < 4; i++) {
      this.chunk.push((size >> (8 * (3 - i))) & 255);
    }
  }

  private static list_4(a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: number, j: number, k: number, m: number, n: number, o: number, p: number, q: number, r: number): number[] {
    return [
      44,
      a,
      0,
      0,
      0,
      0,
      24,
      b,
      n,
      0,
      c,
      d,
      0,
      0,
      0,
      1,
      0,
      239,
      e,
      o,
      f,
      g,
      0,
      0,
      0,
      0,
      h,
      0,
      0,
      14,
      i,
      j,
      0,
      k,
      m,
      3,
      p,
      1,
      q,
      1,
      r,
      0,
      0,
      0,
    ];
  }

  private static endCheckNum(a: number[]): number {
    let r = 0;
    for (const i of a) r ^= i;
    return r;
  }

  private static decodeString(urlString: string): string {
    return urlString.replace(ABogus.filter, (_m, g1: string) => String.fromCharCode(parseInt(g1, 16)));
  }

  private static de(e: number, r: number): number {
    r %= 32;
    return ((e << r) | (e >>> (32 - r))) >>> 0;
  }

  private static pe(e: number): number {
    return e >= 0 && e < 16 ? 2043430169 : 2055708042;
  }

  private static he(e: number, r: number, t: number, n: number): number {
    if (e >= 0 && e < 16) return (r ^ t ^ n) >>> 0;
    if (e >= 16 && e < 64) return ((r & t) | (r & n) | (t & n)) >>> 0;
    throw new Error("range");
  }

  private static ve(e: number, r: number, t: number, n: number): number {
    if (e >= 0 && e < 16) return (r ^ t ^ n) >>> 0;
    if (e >= 16 && e < 64) return ((r & t) | (~r & n)) >>> 0;
    throw new Error("range");
  }

  private static splitArray(arr: number[], chunkSize = 64): number[][] {
    const chunks: number[][] = [];
    for (let i = 0; i < arr.length; i += chunkSize) chunks.push(arr.slice(i, i + chunkSize));
    return chunks;
  }

  private static charCodeAt(s: string): number[] {
    const out: number[] = [];
    for (let i = 0; i < s.length; i++) out.push(s.charCodeAt(i));
    return out;
  }

  private write(e: string | number[]): void {
    this.size = typeof e === "string" ? e.length : e.length;
    if (typeof e === "string") {
      e = ABogus.decodeString(e);
      e = ABogus.charCodeAt(e);
    }
    if (e.length <= 64) {
      this.chunk = e;
    } else {
      const chunks = ABogus.splitArray(e, 64);
      for (const c of chunks.slice(0, -1)) this.compress(c);
      this.chunk = chunks[chunks.length - 1];
    }
  }

  private reset(): void {
    this.chunk = [];
    this.size = 0;
    this.regState = ABogus.regInit.slice();
  }

  private sum(e: string, length = 60): number[] {
    this.reset();
    this.write(e);
    this.fill(length);
    this.compress(this.chunk);
    return ABogus.regToArray(this.regState);
  }

  private static generateResultUnit(n: number, s: string): string {
    let r = "";
    for (let i = 18, j = 0; i >= 0; i -= 6, j++) {
      const mask = [16515072, 258048, 4032, 63][j];
      r += ABogus.strMap[s][(n & mask) >> i];
    }
    return r;
  }

  private static generateResultEnd(s: string, e = "s4"): string {
    let r = "";
    const b = s.charCodeAt(120) << 16;
    r += ABogus.strMap[e][(b & 16515072) >> 18];
    r += ABogus.strMap[e][(b & 258048) >> 12];
    r += "==";
    return r;
  }

  private static generateResult(s: string, e = "s4"): string {
    const r: string[] = [];
    for (let i = 0; i < s.length; i += 3) {
      let n: number;
      if (i + 2 < s.length) n = (s.charCodeAt(i) << 16) | (s.charCodeAt(i + 1) << 8) | s.charCodeAt(i + 2);
      else if (i + 1 < s.length) n = (s.charCodeAt(i) << 16) | (s.charCodeAt(i + 1) << 8);
      else n = s.charCodeAt(i) << 16;
      for (let j = 18; j >= 0; j -= 6) {
        const k = [0xfc0000, 0x03f000, 0x0fc0, 0x3f][(18 - j) / 6];
        if (j === 6 && i + 1 >= s.length) break;
        if (j === 0 && i + 2 >= s.length) break;
        r.push(ABogus.strMap[e][(n & k) >> j]);
      }
    }
    r.push("=".repeat((4 - (r.length % 4)) % 4));
    return r.join("");
  }

  private generateMethodCode(method = "GET"): number[] {
    return this.sm3ToArray(this.sm3ToArray(method + ABogus.endString));
  }

  private generateParamsCode(params: string): number[] {
    return this.sm3ToArray(this.sm3ToArray(params + ABogus.endString));
  }

  private sm3ToArray(data: string | number[]): number[] {
    // Ensure hashing over raw bytes just like Python's gmssl.sm3_hash(bytes_to_list(...))
    const msgBytes: number[] = typeof data === "string" ? Array.from(Buffer.from(data, "utf8")) : (data as number[]);
    const hex: string = sm3Hash(msgBytes);
    const out: number[] = [];
    for (let i = 0; i < hex.length; i += 2) out.push(parseInt(hex.slice(i, i + 2), 16));
    return out;
  }

  private static generateBrowserInfo(platform = "Win32"): string {
    const randint = (min: number, max: number) => Math.floor(Math.random() * (max - min + 1)) + min;
    const innerWidth = randint(1280, 1920);
    const innerHeight = randint(720, 1080);
    const outerWidth = randint(innerWidth, 1920);
    const outerHeight = randint(innerHeight, 1080);
    const screenX = 0;
    const screenY = Math.random() < 0.5 ? 0 : 30;
    const valueList = [
      innerWidth,
      innerHeight,
      outerWidth,
      outerHeight,
      screenX,
      screenY,
      0,
      0,
      outerWidth,
      outerHeight,
      outerWidth,
      outerHeight,
      innerWidth,
      innerHeight,
      24,
      24,
      platform,
    ];
    return valueList.join("|");
  }

  private static rc4Encrypt(plaintext: string, key: string): string {
    const s: number[] = new Array(256);
    for (let i = 0; i < 256; i++) s[i] = i;
    let j = 0;
    for (let i = 0; i < 256; i++) {
      j = (j + s[i] + key.charCodeAt(i % key.length)) % 256;
      const tmp = s[i];
      s[i] = s[j];
      s[j] = tmp;
    }
    let i = 0;
    j = 0;
    const cipher: string[] = [];
    for (let k = 0; k < plaintext.length; k++) {
      i = (i + 1) % 256;
      j = (j + s[i]) % 256;
      const tmp = s[i];
      s[i] = s[j];
      s[j] = tmp;
      const t = (s[i] + s[j]) % 256;
      cipher.push(String.fromCharCode(s[t] ^ plaintext.charCodeAt(k)));
    }
    return cipher.join("");
  }

  getValue(
    urlParams: Record<string, any> | string,
    method = "GET",
    startTime = 0,
    endTime = 0,
    r1?: number | null,
    r2?: number | null,
    r3?: number | null,
  ): string {
    const string1 = this.generateString1(r1, r2, r3);
    const paramsStr = typeof urlParams === "string" ? urlParams : encodeParamsLikePython(urlParams);
    const string2 = this.generateString2(paramsStr, method, startTime, endTime);
    const s = string1 + string2;
    return ABogus.generateResult(s, "s4");
  }
}

// ====================== Douyin API logic ======================
export function buildAwemeDetailParams(awemeId: string, msToken?: string | null): Record<string, any> {
  return {
    device_platform: "webapp",
    aid: "6383",
    channel: "channel_pc_web",
    update_version_code: "170400",
    pc_client_type: "1",
    pc_libra_divert: "Windows",
    version_code: "190500",
    version_name: "19.5.0",
    cookie_enabled: "true",
    screen_width: "1536",
    screen_height: "864",
    browser_language: "zh-SG",
    browser_platform: "Win32",
    browser_name: "Chrome",
    browser_version: "136.0.0.0",
    browser_online: "true",
    engine_name: "Blink",
    engine_version: "136.0.0.0",
    os_name: "Windows",
    os_version: "10",
    cpu_core_num: "16",
    device_memory: "8",
    platform: "PC",
    downlink: "10",
    effective_type: "4g",
    round_trip_time: "200",
    uifid: "",
    msToken: msToken || "",
    aweme_id: awemeId,
  };
}

function pickBestVideoUrl(detail: any): string | null {
  const d = detail?.video || {};
  const list = d.bit_rate || d.bitrateInfo || [];
  let best: { url?: string } | null = null;
  let bestBr = -1;
  for (const item of list) {
    const br = item?.bit_rate || item?.bitrate || 0;
    const play = item?.play_addr || {};
    const urlList = play?.url_list || [];
    if (urlList && urlList[0]) {
      if (br && br > bestBr) {
        bestBr = br;
        best = { url: urlList[0] };
      }
    }
  }
  if (!best) {
    const play = d?.play_addr || {};
    const urlList = play?.url_list || [];
    if (urlList && urlList[0]) best = { url: urlList[0] };
  }
  return best?.url || null;
}

function extractImages(detail: any): string[] {
  const images = detail?.images || [];
  const out: string[] = [];
  for (const img of images) {
    const ulist = img?.url_list || [];
    if (ulist && ulist[0]) out.push(ulist[0]);
  }
  return out;
}

export async function fetchAwemeDetail(awemeId: string, cookie: string, useABogus = true, userAgent = DEFAULT_USER_AGENT): Promise<any | null> {
  const baseUrl = "https://www.douyin.com/aweme/v1/web/aweme/detail/";
  let msToken: string | null = null;
  const m = cookie.match(/(?:^|;\s*)msToken=([^;]+)/);
  if (m) msToken = m[1];
  const params = buildAwemeDetailParams(awemeId, msToken);
  const headers = {
    Referer: "https://www.douyin.com/?recommend=1",
    "User-Agent": userAgent,
    Cookie: cookie,
    Accept: "application/json, text/plain, */*",
    "Accept-Language": "zh-CN,zh;q=0.9",
  } as Record<string, string>;

  if (useABogus) {
    try {
      const a = new ABogus(userAgent);
      (params as any)["a_bogus"] = a.getValue(params, "GET");
    } catch (e: any) {
      dprint("a_bogus generation failed, trying without:", e?.message || e);
    }
  }

  try {
    let r = await axios.get(baseUrl, { params, headers, maxRedirects: 5 });
    if (r.status === 403 && (params as any)["a_bogus"]) {
      delete (params as any)["a_bogus"];
      r = await axios.get(baseUrl, { params, headers, maxRedirects: 5 });
    }
    if (r.status >= 200 && r.status < 300) return r.data;
    return null;
  } catch (e) {
    dprint("fetch aweme detail error:", e);
    return null;
  }
}

export function buildResultFromDetail(awemeId: string, detail: any) {
  const d = detail?.aweme_detail || detail || {};
  const desc = d?.desc || "";
  const author = d?.author?.unique_id || d?.author?.short_id || "";
  const result: any = {
    aweme_id: awemeId,
    desc,
    author,
    video: null,
    images: [] as string[],
    covers: { static: null as string | null, dynamic: null as string | null },
    music: null as any,
  };
  const vurl = pickBestVideoUrl(d);
  if (vurl) result.video = { url: vurl };
  const imgs = extractImages(d);
  if (imgs.length) result.images = imgs;
  const video = d?.video || {};
  const cover = (video?.origin_cover || video?.cover || {})?.url_list || [];
  if (cover && cover[0]) result.covers.static = cover[0];
  const dyn = (video?.dynamic_cover || video?.animated_cover || {})?.url_list || [];
  if (dyn && dyn[0]) result.covers.dynamic = dyn[0];
  const music = d?.music || {};
  const murl = (music?.play_url || {})?.url_list || [];
  if (murl && murl[0]) result.music = { url: murl[0] };
  return result;
}

export async function collectLinksFromText(text: string, cookie: string, proxy: string | null, useABogus: boolean, userAgent: string) {
  const urls = extractUrls(text);
  const idsInText = extractAwemeIds(text);

  const finalUrls = await Promise.all(urls.map((u) => resolveFinalUrl(u)));
  const allText = finalUrls.join("\n") + "\n" + text;
  const awemeIds = Array.from(new Set([...idsInText, ...extractAwemeIds(allText)])).sort();

  const results: any[] = [];
  for (const awemeId of awemeIds) {
    const detail = await fetchAwemeDetail(awemeId, cookie, useABogus, userAgent);
    if (!detail) continue;
    results.push(buildResultFromDetail(awemeId, detail));
  }

  return { input_urls: urls, final_urls: finalUrls, aweme_ids: awemeIds, results };
}

export async function handleDouyinQuery(urlText: string) {
  const cookie = loadDefaultCookieString();
  const data = await collectLinksFromText(urlText, cookie, null, true, DEFAULT_USER_AGENT);
  return {
    code: 0,
    message: "ok",
    count: (data.results || []).length,
    data,
  };
} 