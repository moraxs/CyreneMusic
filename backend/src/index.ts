import { Elysia, t } from "elysia";
import { cors } from "@elysiajs/cors";
import { staticPlugin } from "@elysiajs/static";
import path from "path";
import fs from "fs";

// 直接复用 demo 目录下的现有业务逻辑（逐步替换为 src/lib 实现）
import { neteaseSearch, qqSearch, kugouSearch } from "./lib/search";
import { getToplists } from "./lib/neteaseApis";
import { getNeteaseSong, getQQSong, getKugouSong } from "./lib/song";
import { readBiliCookie, checkBiliCookieValidity } from "./lib/bilibili";
import { getBiliRanking } from "./lib/biliRanking";
import { getBiliPlayUrl, generateMpdFromBiliData, generateMpdFromPgcData } from "./lib/biliPlayurl";
import { getBiliDanmaku } from "./lib/biliDanmaku";
import { getBiliCid } from "./lib/biliCid";
import { getBiliSearch } from "./lib/biliSearch";
import { getBiliPgcPlayUrl } from "./lib/biliPgcPlayurl";
import { getBiliPgcSeason } from "./lib/biliPgcSeason";
import { getBiliComments } from "./lib/biliComments";
import { logger } from "./lib/logger";
import axios from "axios";
import { getConfig, compactLogString } from "./lib/utils";
import { handleDouyinQuery } from "./lib/douyin";
import {
  sendRegisterCode,
  register,
  login,
  sendResetCode,
  resetPassword
} from "./lib/authController";

const host = "0.0.0.0";
const port = 4055;

// 计算 demo 下 MPD 临时目录，与原逻辑一致
const __dirname_resolved = path.dirname(new URL(import.meta.url).pathname.substring(1));
const mpdDir = path.join(process.cwd(), "temp_mpd");
if (!fs.existsSync(mpdDir)) {
  fs.mkdirSync(mpdDir, { recursive: true });
}

const app = new Elysia()
  // CORS（保持对所有来源开放，与原开发阶段一致）
  .use(cors({ origin: true, credentials: true }))
  // 静态文件服务：/mpd 挂载到 demo/temp_mpd
  .use(staticPlugin({ assets: mpdDir, prefix: "/mpd" }))
  // DEV 模式：详细请求/响应日志（单条、折叠、省略号）
  .onBeforeHandle(async (ctx) => {
    const cfg = await getConfig();
    if (String(cfg?.log_level).toUpperCase() !== "DEV") return;
    const { request, headers, body, query, params, path } = ctx as any;
    logger.dev(
      `[HTTP Request] ${compactLogString({ method: request.method, url: request.url, path, headers, query, params, body })}`
    );
  })
  .onAfterHandle(async (ctx) => {
    const cfg = await getConfig();
    if (String(cfg?.log_level).toUpperCase() !== "DEV") return;
    const { request, response, set, path } = ctx as any;
    logger.dev(
      `[HTTP Response] ${compactLogString({ method: request.method, url: request.url, path, status: set?.status, headers: set?.headers, response })}`
    );
  })

  // 健康检查
  .get("/", () => "OK")

  // ================= Netease =================
  .post(
    "/search",
    async ({ body, set }) => {
      const { keywords, limit } = body as { keywords?: string; limit?: number | string };
      if (!keywords) {
        set.status = 400;
        return { error: "必须提供 keywords 参数" };
      }
      try {
        const result = await neteaseSearch(keywords, limit as any);
        set.status = (result as any).status;
        return result;
      } catch (e: any) {
        set.status = 500;
        return { status: 500, msg: `服务异常: ${e.message}` };
      }
    },
    {
      body: t.Object({ keywords: t.String(), limit: t.Optional(t.Union([t.Number(), t.String()])) }),
      parse: 'urlencoded'
    }
  )

  .post(
    "/song",
    async ({ body, set }) => {
      const { ids, url, level, type } = body as any;
      const jsondata = ids || url;
      if (!jsondata) {
        set.status = 400;
        return { error: "必须提供 ids 或 url 参数" };
      }
      if (!level) {
        set.status = 400;
        return { error: "level参数为空" };
      }
      if (!type) {
        set.status = 400;
        return { error: "type参数为空" };
      }
      try {
        const songDetails = await getNeteaseSong(jsondata, level);
        if (type === "down") {
          // 302 重定向
          set.status = 302 as any;
          set.headers = { Location: (songDetails as any).url } as any;
          return "";
        } else if (type === "text") {
          const textResponse = `歌曲名称：${(songDetails as any).name}<br>歌曲图片：${(songDetails as any).pic}<br>歌手：${(songDetails as any).ar_name}<br>歌曲专辑：${(songDetails as any).al_name}<br>歌曲音质：${(songDetails as any).level}<br>歌曲大小：${(songDetails as any).size}<br>音乐地址：${(songDetails as any).url}`;
          return textResponse;
        }
        return { status: 200, ...(songDetails as any) };
      } catch (e: any) {
        set.status = 500;
        return { status: 500, msg: `服务异常: ${e.message}` };
      }
    },
    {
      body: t.Object({
        ids: t.Optional(t.String()),
        url: t.Optional(t.String()),
        level: t.String(),
        type: t.String()
      })
    }
  )

  .get("/toplists", async ({ set }) => {
    try {
      const details = await getToplists(20);
      return { status: 200, toplists: details };
    } catch (e: any) {
      set.status = 500;
      return { status: 500, msg: `获取榜单异常: ${e.message}` };
    }
  })

  // ================= QQ =================
  .get("/qq/search", async ({ query, set }) => {
    const { keywords, limit } = query as any;
    if (!keywords) {
      set.status = 400;
      return { error: "keywords parameter is required" };
    }
    try {
      const result = await qqSearch(keywords, limit as any);
      set.status = (result as any).status;
      return result;
    } catch (e: any) {
      set.status = 500;
      return { status: 500, msg: `搜索异常: ${e.message}` };
    }
  })

  .get("/qq/song", async ({ query, set }) => {
    const songUrl = (query as any).url || (query as any).ids;
    if (!songUrl) {
      set.status = 400;
      return { error: "url or ids parameter is required" };
    }
    try {
      const result = await getQQSong(songUrl);
      return { status: 200, ...(result as any) };
    } catch (e: any) {
      set.status = 500;
      return { status: 500, msg: `服务异常: ${e.message}` };
    }
  })

  // ================= Kugou =================
  .get("/kugou/search", async ({ query, set }) => {
    const { keywords, limit } = query as any;
    if (!keywords) {
      set.status = 400;
      return { error: "keywords parameter is required" };
    }
    try {
      const result = await kugouSearch(keywords, limit as any);
      set.status = (result as any).status;
      return result;
    } catch (e: any) {
      set.status = 500;
      return { status: 500, msg: `搜索异常: ${e.message}` };
    }
  })

  .get("/kugou/song", async ({ query, set }) => {
    const { emixsongid } = query as any;
    if (!emixsongid) {
      set.status = 400;
      return { error: "emixsongid parameter is required" };
    }
    try {
      const result = await getKugouSong(emixsongid as string);
      return { status: 200, song: result };
    } catch (e: any) {
      set.status = 404;
      return { status: 404, msg: e.message };
    }
  })

  // ================= Bilibili =================
  .get("/bili/ranking", async ({ query, set }) => {
    const { rid, type } = query as any;
    try {
      const result = await getBiliRanking(rid as string, type as string);
      return result;
    } catch (e: any) {
      const message = e.response ? JSON.stringify(e.response.data) : e.message;
      set.status = 500;
      return { status: 500, msg: `请求Bilibili API时出错: ${message}` };
    }
  })

  .get("/bili/cid", async ({ query, set }) => {
    const { bvid } = query as any;
    if (!bvid) {
      set.status = 400;
      return { status: 400, msg: "必须提供bvid参数" };
    }
    try {
      const result = await getBiliCid(bvid as string);
      return result as any;
    } catch (e: any) {
      const message = e.response ? JSON.stringify(e.response.data) : e.message;
      set.status = 500;
      return { status: 500, msg: `请求Bilibili CID时出错: ${message}` };
    }
  })

  .get("/bili/playurl", async ({ query, request, set }) => {
    const { bvid, format } = query as any;
    if (!bvid) {
      set.status = 400;
      return { status: 400, msg: "必须提供bvid参数" };
    }
    try {
      const result = await getBiliPlayUrl(bvid as string);
      if (format === "mpd") {
        try {
          const mpd = generateMpdFromBiliData(result as any);
          const mpdPath = path.join(mpdDir, `${bvid}.mpd`);
          fs.writeFileSync(mpdPath, mpd);
          const serverUrl = `${new URL(request.url).protocol}//${(request.headers as any).get("host")}`;
          const fileUrl = `${serverUrl}/mpd/${bvid}.mpd`;
          return { code: 0, url: fileUrl };
        } catch (e: any) {
          set.status = 500;
          return { status: 500, msg: `生成MPD清单时出错: ${e.message}` };
        }
      }
      return result as any;
    } catch (e: any) {
      const message = e.response ? JSON.stringify(e.response.data) : e.message;
      set.status = 500;
      return { status: 500, msg: `请求Bilibili播放链接时出错: ${message}` };
    }
  })

  .get("/bili/pgc_season", async ({ query, set }) => {
    const { ep_id, season_id } = query as any;
    if (!ep_id && !season_id) {
      set.status = 400;
      return { status: 400, msg: "必须提供ep_id或season_id参数" };
    }
    try {
      const result = await getBiliPgcSeason(ep_id as string, season_id as string);
      return result as any;
    } catch (e: any) {
      const message = e.response ? JSON.stringify(e.response.data) : e.message;
      set.status = 500;
      return { status: 500, msg: `请求Bilibili番剧详情时出错: ${message}` };
    }
  })

  .get("/bili/pgc_playurl", async ({ query, request, set }) => {
    const { ep_id, cid, format } = query as any;
    if (!ep_id && !cid) {
      set.status = 400;
      return { status: 400, msg: "必须提供ep_id或cid参数" };
    }
    try {
      const result = await getBiliPgcPlayUrl(ep_id as string, cid as string);
      if (format === "mpd") {
        try {
          const mpd = generateMpdFromPgcData(result as any);
          const identifier = (ep_id as string) || (cid as string);
          const mpdPath = path.join(mpdDir, `pgc_${identifier}.mpd`);
          fs.writeFileSync(mpdPath, mpd);
          const serverUrl = `${new URL(request.url).protocol}//${(request.headers as any).get("host")}`;
          const fileUrl = `${serverUrl}/mpd/pgc_${identifier}.mpd`;
          return { code: 0, url: fileUrl };
        } catch (e: any) {
          set.status = 500;
          return { status: 500, msg: `为PGC内容生成MPD清单时出错: ${e.message}` };
        }
      }
      return result as any;
    } catch (e: any) {
      const message = e.response ? JSON.stringify(e.response.data) : e.message;
      set.status = 500;
      return { status: 500, msg: `请求Bilibili番剧播放链接时出错: ${message}` };
    }
  })

  .get("/bili/danmaku", async ({ query, set }) => {
    const { oid, segment_index } = query as any;
    if (!oid) {
      set.status = 400;
      return { status: 400, msg: "必须提供oid (视频cid)参数" };
    }
    if (!segment_index) {
      set.status = 400;
      return { status: 400, msg: "必须提供segment_index参数" };
    }
    try {
      const result = await getBiliDanmaku(oid as any, parseInt(segment_index as string));
      return { code: 0, message: "0", data: result } as any;
    } catch (e: any) {
      const message = e.response ? JSON.stringify(e.response.data) : e.message;
      set.status = 500;
      return { status: 500, msg: `请求Bilibili弹幕时出错: ${message}` };
    }
  })

  .get("/bili/search", async ({ query, set }) => {
    const { keyword } = query as any;
    if (!keyword) {
      set.status = 400;
      return { status: 400, msg: "必须提供keyword参数" };
    }
    try {
      const result = await getBiliSearch(keyword as string);
      return result as any;
    } catch (e: any) {
      const message = e.response ? JSON.stringify(e.response.data) : e.message;
      set.status = 500;
      return { status: 500, msg: `请求Bilibili搜索时出错: ${message}` };
    }
  })

  .get("/bili/comments", async ({ query, set }) => {
    const { type, oid, mode, pagination_str } = query as any;
    if (!type || !oid) {
      set.status = 400;
      return { status: 400, msg: "必须提供 type 和 oid 参数" };
    }
    try {
      const result = await getBiliComments(Number(type), Number(oid), Number(mode) || (undefined as any), pagination_str as string);
      return result as any;
    } catch (e: any) {
      const message = e.response ? JSON.stringify(e.response.data) : e.message;
      set.status = 500;
      return { status: 500, msg: `请求Bilibili评论时出错: ${message}` };
    }
  })

  .get("/bili/proxy", async ({ query, set, request }) => {
    const { url } = query as any;
    if (!url) {
      set.status = 400;
      return { message: "URL is required" };
    }
    try {
      const { cookieString } = await readBiliCookie();
      const range = (request.headers as any).get("range") || undefined;

      const response = await axios({
        method: "get",
        url: url as string,
        responseType: "stream" as any,
        headers: {
          Referer: "https://www.bilibili.com/",
          "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0",
          Range: range,
          Cookie: cookieString || "",
        },
      });

      set.status = response.status as any;
      set.headers = {
        "Content-Type": response.headers["content-type"],
        ...(response.headers["content-length"] ? { "Content-Length": response.headers["content-length"] } : {}),
        ...(response.headers["accept-ranges"] ? { "Accept-Ranges": response.headers["accept-ranges"] } : {}),
        ...(response.headers["content-range"] ? { "Content-Range": response.headers["content-range"] } : {}),
      } as any;

      return response.data as any;
    } catch (error: any) {
      logger.error(`[Proxy Error] for url ${url}: ${error.message}`);
      if (error.response) {
        set.status = error.response.status as any;
        return `Proxy failed with status: ${error.response.status}`;
      }
      set.status = 500;
      return "Proxy error";
    }
  })

  // Douyin: 解析分享链接/文本，抽取 aweme_id 并返回资源链接集合
  .get("/douyin", async ({ query, set }) => {
    const { url } = query as any;
    if (!url) {
      set.status = 400 as any;
      return { code: 400, message: "url 参数必填" } as any;
    }
    try {
      const result = await handleDouyinQuery(url as string);
      return result as any;
    } catch (e: any) {
      set.status = 500 as any;
      return { code: 500, message: `解析失败: ${e?.message || e}` } as any;
    }
  })

  // 版本信息
  .get("/version/latest", () => {
    const versionInfo = {
      version: "1.0.2",
      changelog: "- 支持安卓平台 \n - 修复了一些bug",
      force_update: false,
      download_url: "https://github.com/Chuxin-Neko/chuxinneko_music/releases/latest",
    };
    return { status: 200, data: versionInfo };
  })

  // ================= 用户认证 =================
  // 发送注册验证码
  .post("/auth/register/send-code", sendRegisterCode, {
    body: t.Object({
      email: t.String(),
      username: t.String()
    })
  })

  // 用户注册
  .post("/auth/register", register, {
    body: t.Object({
      email: t.String(),
      username: t.String(),
      password: t.String(),
      code: t.String()
    })
  })

  // 用户登录
  .post("/auth/login", login, {
    body: t.Object({
      account: t.String(),
      password: t.String()
    })
  })

  // 发送重置密码验证码
  .post("/auth/reset-password/send-code", sendResetCode, {
    body: t.Object({
      email: t.String()
    })
  })

  // 重置密码
  .post("/auth/reset-password", resetPassword, {
    body: t.Object({
      email: t.String(),
      code: t.String(),
      newPassword: t.String()
    })
  })

  .listen(port, ({ hostname, port }) => {
    console.log(`Server running at http://${host}:${port}`);
    logger.info("  - POST /search (Netease)");
    logger.info("  - POST /song (Netease)");
    logger.info("  - GET /toplists (Netease)");
    logger.info("  - GET /qq/search (QQ Music)");
    logger.info("  - GET /qq/song (QQ Music)");
    logger.info("  - GET /kugou/search (Kugou Music)");
    logger.info("  - GET /kugou/song (Kugou Music)");
    logger.info("  - GET /bili/ranking (Bilibili)");
    logger.info("  - GET /bili/cid (Bilibili)");
    logger.info("  - GET /bili/playurl (Bilibili)");
    logger.info("  - GET /bili/pgc_season (Bilibili)");
    logger.info("  - GET /bili/pgc_playurl (Bilibili)");
    logger.info("  - GET /bili/danmaku (Bilibili)");
    logger.info("  - GET /bili/search (Bilibili)");
    logger.info("  - GET /bili/comments (Bilibili)");
    logger.info("  - GET /bili/proxy (Bilibili)");
    logger.info("  - GET /douyin (Douyin)");
    logger.info("  - GET /version/latest (App Version)");
    logger.info("  - GET /mpd/:filename (MPD files)");
    logger.info("");
    logger.info("  === User Authentication ===");
    logger.info("  - POST /auth/register/send-code (Send Register Code)");
    logger.info("  - POST /auth/register (Register)");
    logger.info("  - POST /auth/login (Login)");
    logger.info("  - POST /auth/reset-password/send-code (Send Reset Code)");
    logger.info("  - POST /auth/reset-password (Reset Password)");
  });

// 启动时执行原有任务
checkBiliCookieValidity();
getConfig();
