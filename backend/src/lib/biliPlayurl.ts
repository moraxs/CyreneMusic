import axios from 'axios';
import { getWbiKeys, encWbi, readBiliCookie } from './bilibili';
import http from 'http';
import https from 'https';

const httpAgent = new http.Agent({ keepAlive: true });
const httpsAgent = new https.Agent({ keepAlive: true });

const HEADERS: Record<string, string> = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0',
};

async function getCid(bvid: string) {
  const pagelistUrl = 'https://api.bilibili.com/x/player/pagelist';
  const response = await axios.get(pagelistUrl, { params: { bvid }, headers: HEADERS, httpAgent, httpsAgent });
  const pagelistData = response.data;
  if (pagelistData?.code !== 0 || !pagelistData?.data?.[0]?.cid) {
    throw new Error(`未能获取到有效的cid: ${JSON.stringify(pagelistData)}`);
  }
  return pagelistData.data[0].cid;
}

export async function getBiliPlayUrl(bvid: string) {
  const cid = await getCid(bvid);
  const { imgKey, subKey } = await getWbiKeys();
  const params = { bvid, cid, qn: 0, fnval: 80, fnver: 0, fourk: 1 } as any;
  const signedParams = encWbi(params, imgKey, subKey);
  const { cookieString } = await readBiliCookie();
  if (!cookieString) throw new Error('无法加载或解析Bilibili Cookie文件');
  const playApiUrl = 'https://api.bilibili.com/x/player/wbi/playurl';
  const headers = { ...HEADERS, Referer: `https://www.bilibili.com/video/${bvid}`, Cookie: cookieString } as Record<string, string>;
  const response = await axios.get(playApiUrl, { params: signedParams, headers, httpAgent, httpsAgent });
  return response.data;
}

function escapeXml(unsafe: string) {
  return unsafe.replace(/[<>&'\"]/g, function (c) {
    switch (c) {
      case '<':
        return '&lt;';
      case '>':
        return '&gt;';
      case '&':
        return '&amp;';
      case "'":
        return '&apos;';
      case '"':
        return '&quot;';
      default:
        return c;
    }
  });
}

const BILI_QUALITY_MAP = new Map<number, string>([
  [127, '8K 超高清'],
  [126, '杜比视界'],
  [125, 'HDR 真彩'],
  [120, '4K 超清'],
  [116, '1080P 60帧'],
  [112, '1080P 高码率'],
  [80, '1080P 高清'],
  [74, '720P 60帧'],
  [64, '720P 高清'],
  [48, '720P 高清 (FLV)'],
  [32, '480P 清晰'],
  [16, '360P 流畅'],
  [6, '240P 极速'],
]);

function buildMpd(duration: number, videoStreams: any[], audioStreams: any[], qualityMap: Map<number, string>) {
  const addedRepresentations = new Set<string>();
  const lines: string[] = [];
  lines.push('<?xml version="1.0" encoding="UTF-8"?>');
  lines.push(`<MPD
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns="urn:mpeg:dash:schema:mpd:2011"
    xsi:schemaLocation="urn:mpeg:dash:schema:mpd:2011 DASH-MPD.xsd"
    type="static"
    mediaPresentationDuration="PT${duration}S"
    minBufferTime="PT1.5S"
    profiles="urn:mpeg:dash:profile:isoff-on-demand:2011">`);
  lines.push(`    <Period duration="PT${duration}S">`);
  if (videoStreams && videoStreams.length > 0) {
    lines.push(`        <AdaptationSet contentType="video/mp4" segmentAlignment="true" bitstreamSwitching="true" mimeType="video/mp4">`);
    videoStreams.forEach((stream: any) => {
      if (!stream.id || addedRepresentations.has(`v-${stream.id}`)) return;
      addedRepresentations.add(`v-${stream.id}`);
      const title = qualityMap.get(stream.id) || `${stream.width}x${stream.height}`;
      lines.push(`            <Representation
                id="${stream.id}"
                title="${escapeXml(String(title))}"
                codecs="${stream.codecs}"
                width="${stream.width}"
                height="${stream.height}"
                frameRate="${stream.frameRate}"
                bandwidth="${stream.bandwidth}">
                <BaseURL>${escapeXml(stream.baseUrl)}</BaseURL>
                <SegmentBase indexRange="${stream.segment_base.index_range}">
                    <Initialization range="${stream.segment_base.initialization}"/>
                </SegmentBase>
            </Representation>`);
    });
    lines.push(`        </AdaptationSet>`);
  }
  if (audioStreams && audioStreams.length > 0) {
    lines.push(`        <AdaptationSet contentType="audio/mp4" segmentAlignment="true" bitstreamSwitching="true" mimeType="audio/mp4" lang="zh">`);
    audioStreams.forEach((stream: any) => {
      if (!stream.id || addedRepresentations.has(`a-${stream.id}`)) return;
      addedRepresentations.add(`a-${stream.id}`);
      lines.push(`            <Representation
                id="${stream.id}"
                codecs="${stream.codecs}"
                bandwidth="${stream.bandwidth}">
                <BaseURL>${escapeXml(stream.baseUrl)}</BaseURL>
                <SegmentBase indexRange="${stream.segment_base.index_range}">
                    <Initialization range="${stream.segment_base.initialization}"/>
                </SegmentBase>
            </Representation>`);
    });
    lines.push(`        </AdaptationSet>`);
  }
  lines.push(`    </Period>`);
  lines.push(`</MPD>`);
  return lines.join('\n');
}

export function generateMpdFromBiliData(data: any) {
  if (data?.code !== 0 || !data?.data?.dash) throw new Error('无效的Bilibili播放数据或非DASH格式，无法生成MPD');
  const dashData = data.data.dash;
  return buildMpd(dashData.duration, dashData.video, dashData.audio, BILI_QUALITY_MAP);
}

export function generateMpdFromPgcData(data: any) {
  if (data?.code !== 0 || !data?.result?.dash) throw new Error('无效的Bilibili PGC播放数据或非DASH格式，无法生成MPD');
  const pgcResult = data.result;
  const dashData = pgcResult.dash;
  const qualityMap = new Map<number, string>();
  if (pgcResult.support_formats) {
    pgcResult.support_formats.forEach((f: any) => {
      const description = f.new_description || f.display_desc || `${f.quality}P`;
      if (!qualityMap.has(f.quality)) qualityMap.set(f.quality, description);
    });
  }
  return buildMpd(dashData.duration, dashData.video, dashData.audio, qualityMap);
} 