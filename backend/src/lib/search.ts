import axios from 'axios';
import crypto from 'crypto';
import CookieManager from './cookieManager';
import { logger } from './logger';

const neteaseCookieManager = new CookieManager('cookie.txt');
const qqCookieManager = new CookieManager('qq_cookie.txt');
const kugouCookieManager = new CookieManager('kugou_cookie.txt');

export async function neteaseSearch(keywords: string, limit = 10) {
  const cookieText = await neteaseCookieManager.readCookie();
  const url = 'https://music.163.com/api/cloudsearch/pc';
  const data = new URLSearchParams({ s: keywords, type: '1', limit: String(limit) }).toString();

  const headers = {
    'User-Agent': 'Mozilla/5.0',
    Referer: 'https://music.163.com/',
    'Content-Type': 'application/x-www-form-urlencoded',
    Cookie: cookieText,
  } as Record<string, string>;

  try {
    const response = await axios.post(url, data, { headers });
    const result = response.data;

    if (result.code !== 200 || !result.result || !result.result.songs) {
      throw new Error('Invalid response from Netease API');
    }

    const songs = result.result.songs.map((item: any) => ({
      id: item.id,
      name: item.name,
      artists: item.ar.map((artist: any) => artist.name).join('/'),
      album: item.al.name,
      picUrl: item.al.picUrl.replace('http://', 'https://'),
    }));

    return { status: 200, result: songs };
  } catch (error: any) {
    logger.error('Netease search error:', error);
    return { status: 500, msg: `搜索异常: ${error.message}` };
  }
}

export async function getQQSongDetails(mid: string, sid: number, cookieText: string) {
  const url = 'https://c.y.qq.com/v8/fcg-bin/fcg_play_single_song.fcg';
  const params: Record<string, any> = sid !== 0 ? { songid: sid } : { songmid: mid };
  params.platform = 'yqq';
  params.format = 'json';

  const headers = {
    'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3',
    Cookie: cookieText,
  } as Record<string, string>;

  try {
    const response = await axios.post(url, new URLSearchParams(params).toString(), { headers });
    const data = response.data;

    if (data.code !== 0 || !data.data || data.data.length === 0) {
      return { msg: '信息获取错误/歌曲不存在' };
    }

    const songInfo = data.data[0];
    const albumInfo = songInfo.album || {};
    const singers = songInfo.singer || [];
    const singerNames = singers.map((s: any) => s.name || 'Unknown').join(', ');
    const albumMid = albumInfo.mid;
    const imgUrl = albumMid
      ? `https://y.qq.com/music/photo_new/T002R800x800M000${albumMid}.jpg?max_age=2592000`.replace('http://', 'https://')
      : 'https://axidiqolol53.objectstorage.ap-seoul-1.oci.customer-oci.com/n/axidiqolol53/b/lusic/o/resources/cover.jpg';

    return {
      name: songInfo.name || 'Unknown',
      album: albumInfo.name || 'Unknown',
      singer: singerNames,
      pic: imgUrl,
      mid: songInfo.mid || mid,
      id: songInfo.id || sid,
    };
  } catch (error: any) {
    logger.error(`Error fetching QQ song details for mid=${mid}, sid=${sid}:`, error);
    return { msg: `获取歌曲详情失败: ${error.message}` };
  }
}

export async function qqSearch(keyword: string, limit = 20) {
  const cookieText = await qqCookieManager.readCookie();
  const url = 'https://c.y.qq.com/soso/fcgi-bin/client_search_cp';
  const params = {
    w: keyword,
    p: 1,
    n: limit,
    format: 'json',
    inCharset: 'utf-8',
    outCharset: 'utf-8',
    notice: 0,
    platform: 'yqq',
    needNewCode: 0,
    g_tk: 5381,
    cr: 1,
    aggr: 1,
    t: 0,
    flag_qc: 0,
  } as Record<string, any>;

  const headers = {
    Accept: '*/*',
    Referer: 'https://y.qq.com/portal/search.html',
    'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
    Host: 'c.y.qq.com',
  } as Record<string, string>;

  try {
    const response = await axios.get(url, { params, headers });
    let responseText: any = response.data;
    if (typeof responseText === 'string' && responseText.startsWith('callback(')) {
      responseText = JSON.parse(responseText.substring(9, responseText.length - 1));
    }

    const data = responseText;
    const songs: any[] = [];
    if (data.code === 0 && data.data?.song?.list) {
      const songList = data.data.song.list;
      for (const songInfo of songList) {
        const sid = songInfo.songid || 0;
        const mid = songInfo.songmid || '';
        if (mid) {
          const detailedInfo = await getQQSongDetails(mid, sid, cookieText);
          if (!(detailedInfo as any).msg) songs.push(detailedInfo);
        }
      }
    }
    return { status: 200, result: songs };
  } catch (error: any) {
    logger.error('QQ search error:', error);
    return { status: 500, msg: `搜索异常: ${error.message}` };
  }
}

export async function kugouSearch(keyword: string, limit = 20) {
  const cookieText = await kugouCookieManager.readCookie();
  const cookies = CookieManager.parseCookie(cookieText);
  const mid = (cookies as any).mid || (cookies as any).kg_mid;
  const dfid = (cookies as any).kg_dfid || (cookies as any).dfid;
  const userid = (cookies as any).KugooID;
  const token = (cookies as any).token || (cookies as any).t;

  const clienttime = Date.now();
  const salt = 'NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt';
  const params: Record<string, any> = {
    appid: '1014',
    clienttime: clienttime,
    clientver: '1000',
    dfid: dfid,
    iscorrection: '1',
    isfuzzy: '0',
    keyword: keyword,
    mid: mid,
    page: 1,
    pagesize: limit,
    platform: 'WebFilter',
    privilege_filter: '0',
    srcappid: '2919',
    token: token,
    userid: userid,
    uuid: mid,
  };

  const sortedKeys = Object.keys(params).sort();
  const signatureRaw = salt + sortedKeys.map((k) => `${k}=${params[k]}`).join('') + salt;
  const signature = crypto.createHash('md5').update(signatureRaw).digest('hex');
  (params as any).signature = signature;

  const url = 'https://complexsearch.kugou.com/v2/search/song';
  try {
    const response = await axios.get(url, { params });
    const data = response.data;
    const songs: any[] = [];

    if (data.status === 1 && data.data) {
      const songList = data.data.lists || [];
      for (const songInfo of songList) {
        const albumCover = (songInfo.Image || '').replace('{size}', '400').replace('http://', 'https://');
        songs.push({
          name: songInfo.SongName,
          hash: songInfo.FileHash,
          album: songInfo.AlbumName,
          singer: songInfo.SingerName,
          duration: songInfo.Duration,
          album_id: songInfo.AlbumID,
          emixsongid: songInfo.EMixSongID,
          pic: albumCover,
        });
      }
    }
    return { status: 200, result: songs };
  } catch (error: any) {
    logger.error('Kugou search error:', error);
    const errorMsg = error.response ? JSON.stringify(error.response.data) : error.message;
    return { status: 500, msg: `搜索异常: ${errorMsg}` };
  }
} 