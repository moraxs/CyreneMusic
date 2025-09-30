import axios from 'axios';
import crypto from 'crypto';
import CookieManager from './cookieManager';
import { ids as parseNeteaseId, size, music_level1, qq_ids as parseQQId, makeRequest } from './utils';
import { getQQSongDetails as getQQDetails } from './search';

const neteaseCookieManager = new CookieManager('cookie.txt');
const qqCookieManager = new CookieManager('qq_cookie.txt');
const kugouCookieManager = new CookieManager('kugou_cookie.txt');

const AES_KEY = Buffer.from('e82ckenh8dichen8');

function eapiEncrypt(urlPath: string, payload: any) {
  const text = JSON.stringify(payload);
  const message = `nobody${urlPath}use${text}md5forencrypt`;
  const digest = crypto.createHash('md5').update(message).digest('hex');
  const data = `${urlPath}-36cd479b6b5-${text}-36cd479b6b5-${digest}`;
  const cipher = crypto.createCipheriv('aes-128-ecb', AES_KEY, null);
  return cipher.update(data, 'utf-8', 'hex') + cipher.final('hex');
}

async function fetchNeteaseUrl(songId: string, level: string, cookies: string) {
  const url = 'https://interface3.music.163.com/eapi/song/enhance/player/url/v1';
  const urlPath = '/api/song/enhance/player/url/v1';
  const payload: any = { ids: JSON.stringify([songId]), level, encodeType: 'flac' };
  if (level === 'sky') payload.immerseType = 'c51';
  const params = eapiEncrypt(urlPath, payload);
  const response = await axios.post(url, new URLSearchParams({ params }).toString(), {
    headers: {
      Cookie: cookies,
      'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Safari/537.36 Chrome/91.0.4472.164 NeteaseMusicDesktop/2.10.2.200154',
    },
  });
  return response.data;
}

async function fetchNeteaseDetails(songId: string) {
  const url = 'https://interface3.music.163.com/api/v3/song/detail';
  const data = { c: JSON.stringify([{ id: songId }]) } as any;
  const response = await axios.post(url, new URLSearchParams(data).toString());
  return response.data;
}

async function fetchNeteaseLyric(songId: string, cookies: string) {
  const url = 'https://interface3.music.163.com/api/song/lyric';
  const data = { id: songId, lv: -1, tv: -1 } as any;
  const response = await axios.post(url, new URLSearchParams(data).toString(), { headers: { Cookie: cookies } });
  return response.data;
}

export async function getNeteaseSong(jsondata: string, level: string) {
  const cookies = await neteaseCookieManager.readCookie();
  const songId = parseNeteaseId(jsondata);
  const [urlData, detailData, lyricData] = await Promise.all([
    fetchNeteaseUrl(songId, level, cookies),
    fetchNeteaseDetails(songId),
    fetchNeteaseLyric(songId, cookies),
  ]);
  if (!urlData.data?.[0]?.url) throw new Error('信息获取不完整！');
  const songData = urlData.data[0];
  const songInfo = detailData.songs?.[0] || {};
  return {
    name: songInfo.name || '',
    pic: songInfo.al?.picUrl || '',
    ar_name: (songInfo.ar || []).map((a: any) => a.name).join('/'),
    al_name: songInfo.al?.name || '',
    level: music_level1(songData.level),
    size: size(songData.size),
    url: (songData.url || '').replace('http://', 'https://'),
    lyric: lyricData.lrc?.lyric || '',
    tlyric: lyricData.tlyric?.lyric || '',
  };
}

export async function getQQSong(songUrl: string) {
  const cookieText = await qqCookieManager.readCookie();
  const songmid = parseQQId(songUrl);
  let sid = 0;
  let mid = songmid;
  if (/^\d+$/.test(songmid)) {
    sid = parseInt(songmid, 10);
    mid = '';
  }
  const info = await getQQDetails(mid, sid, cookieText);
  if ((info as any).msg) throw new Error((info as any).msg);
  const fileTypes = ['flac', '320', '128'] as const;
  const results: Record<string, any> = {};
  const urlPromises = fileTypes.map((type) =>
    getQQMusicUrl((info as any).mid, type, cookieText).then((res) => ({ type, ...(res as any) }))
  );
  const urlResults = await Promise.all(urlPromises);
  urlResults.forEach((res) => {
    if ((res as any).url) results[(res as any).type] = { url: (res as any).url, bitrate: (res as any).bitrate };
  });
  const lyric = await getQQMusicLyric((info as any).id, cookieText);
  return { song: info, lyric: lyric, music_urls: results };
}

async function getQQMusicUrl(songmid: string, fileType: 'flac' | '320' | '128', cookieText: string) {
  const fileConfig: Record<string, { s: string; e: string; bitrate: string }> = {
    '128': { s: 'M500', e: '.mp3', bitrate: '128kbps' },
    '320': { s: 'M800', e: '.mp3', bitrate: '320kbps' },
    flac: { s: 'F000', e: '.flac', bitrate: 'FLAC' },
  };
  const fileInfo = fileConfig[fileType];
  if (!fileInfo) return null;
  const cookies = CookieManager.parseCookie(cookieText);
  const uin = (cookies as any).uin || (cookies as any).euin || '0';
  const file = `${fileInfo.s}${songmid}${songmid}${fileInfo.e}`;
  const reqData = {
    req_1: {
      module: 'vkey.GetVkeyServer',
      method: 'CgiGetVkey',
      param: { filename: [file], guid: '10000', songmid: [songmid], songtype: [0], uin: uin, loginflag: 1, platform: '20' },
    },
    comm: { uin, format: 'json', ct: 24, cv: 0 },
  } as any;
  const data = await makeRequest({ url: 'https://u.y.qq.com/cgi-bin/musicu.fcg', method: 'post', data: reqData, headers: { Cookie: cookieText } });
  const purl = data.req_1?.data?.midurlinfo?.[0]?.purl;
  if (!purl) return null;
  const url = (data.req_1.data.sip?.[1] || data.req_1.data.sip?.[0] || '') + purl;
  return { url: url.replace('http://', 'https://'), bitrate: fileInfo.bitrate };
}

async function getQQMusicLyric(songid: number, cookieText: string) {
  const payload = {
    'music.musichallSong.PlayLyricInfo.GetPlayLyricInfo': {
      module: 'music.musichallSong.PlayLyricInfo',
      method: 'GetPlayLyricInfo',
      param: { songID: songid, trans: 1, roma: 1 },
    },
  } as any;
  const responseData = await makeRequest({ url: 'https://u.y.qq.com/cgi-bin/musicu.fcg', method: 'post', data: payload, headers: { Cookie: cookieText } });
  const data = responseData['music.musichallSong.PlayLyricInfo.GetPlayLyricInfo']?.data;
  return {
    lyric: data?.lyric ? Buffer.from(data.lyric, 'base64').toString('utf-8') : '',
    tylyric: data?.trans ? Buffer.from(data.trans, 'base64').toString('utf-8') : '',
  };
}

export async function getKugouSong(emixsongid: string) {
  const cookieText = await kugouCookieManager.readCookie();
  const cookies = CookieManager.parseCookie(cookieText);
  const mid = (cookies as any).mid || (cookies as any).kg_mid;
  const dfid = (cookies as any).kg_dfid || (cookies as any).dfid;
  const userid = (cookies as any).KugooID;
  const token = (cookies as any).token || (cookies as any).t;
  if (!mid || !dfid || !userid || !token) throw new Error('Cookie不完整，缺少mid, dfid, KugooID或token');
  const clienttime = Date.now();
  const salt = 'NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt';
  const params: any = { srcappid: '2919', clientver: '20000', clienttime, mid, uuid: mid, dfid, appid: '1014', platid: '4', encode_album_audio_id: emixsongid, token, userid };
  const sortedKeys = Object.keys(params).sort();
  const signatureRaw = salt + sortedKeys.map((k) => `${k}=${params[k]}`).join('') + salt;
  params.signature = crypto.createHash('md5').update(signatureRaw).digest('hex');
  const response = await axios.get('https://wwwapi.kugou.com/play/songinfo', { params, headers: { Cookie: cookieText } });
  const data = response.data;
  if (data.status !== 1 || !data.data) throw new Error(`获取歌曲链接失败: ${JSON.stringify(data)}`);
  const songData = data.data;
  return {
    name: songData.song_name,
    singer: songData.author_name,
    album: songData.album_name,
    pic: (songData.img || '').replace('http://', 'https://'),
    lyric: songData.lyrics,
    url: songData.play_url,
    bitrate: songData.bitrate,
    duration: songData.timelength ? Math.floor(songData.timelength / 1000) : 0,
  };
} 