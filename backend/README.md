# 多平台媒体 API 解析服务
基于 bun 和 elysiajs 的后端 API 服务

## ✨ 功能特性

- **多平台支持**: 一套 API 覆盖四个主流平台。
- **丰富的音乐数据**: 解析歌曲链接（多种音质）、歌词、专辑封面、歌手、专辑等信息。
- **Bilibili 支持**: 获取 B 站视频排行榜和WBI签名保护的播放链接。
- **模块化设计**: 代码结构清晰，易于维护和扩展。
- **自动登录**: 内置 Bilibili 二维码自动登录及 Cookie 有效性检查。
- **彩色日志**: 集成了分级、彩色的日志系统，便于调试。

## 🚀 快速开始

### 1. 环境要求
- [bun](https://bun.sh/) 

### 2. 安装依赖
克隆项目后，进入目录并执行以下命令：
```bash
cd OmniParse
bun install
```

### 3. 配置 Cookie
本项目需要有效的用户 Cookie 才能获取高品质内容（如无损音乐、VIP歌曲、B站高清视频流）。请在项目目录下创建一个名为 `cookie` 的文件夹，并按如下方式存放 Cookie 文件：

```
js/
├── cookie/
│   ├── cookie.txt         # 网易云音乐 Cookie
│   ├── qq_cookie.txt      # QQ音乐 Cookie
│   ├── kugou_cookie.txt   # 酷狗音乐 Cookie
│   └── bili_cookie.json   # Bilibili Cookie (可由程序自动生成)
└── ... (其他项目文件)
```

#### Cookie 获取方法
- **网易云音乐 (`cookie.txt`)**:
  1. 在浏览器中登录 [music.163.com](https://music.163.com)。
  2. 打开浏览器开发者工具（按 F12），切换到"网络"(Network)标签。
  3. 刷新页面，找到任意一个对 `music.163.com` 的请求。
  4. 在请求头(Request Headers)中找到 `Cookie` 项，复制其完整的字符串值，粘贴到 `cookie.txt` 文件中。**只需包含 `MUSIC_U` 字段即可获取大部分资源**。

- **QQ音乐 & 酷狗音乐 (`qq_cookie.txt`, `kugou_cookie.txt`)**:
  获取方法同上，分别登录 [y.qq.com](https://y.qq.com) 和 [www.kugou.com](https://www.kugou.com) 后，在开发者工具中找到并复制完整的 Cookie 值。

- **Bilibili (`bili_cookie.json`)**:
  **无需手动创建！** 程序启动时会自动检查此文件：
  - 如果文件不存在、内容不完整或 Cookie 已失效，程序会自动在控制台生成二维码。
  - 请使用 Bilibili 手机客户端扫描二维码登录。
  - 登录成功后，程序会自动创建并更新 `bili_cookie.json` 文件。

### 4. 启动服务
```bash
# 确保你当前在 js 目录下
bun run dev
```
服务默认启动在 `http://0.0.0.0:4055`。

---


## 已实现功能

### 网易云音乐
- ✅ 歌曲搜索
- ✅ 歌曲详情和直链获取（支持多音质）
- ✅ 排行榜获取（飙升榜、新歌榜、原创榜、热歌榜）
- ✅ **歌单详情解析**（NEW）
- ✅ **专辑详情解析**（NEW）

### QQ音乐 & 酷狗音乐
- ✅ 歌曲搜索
- ✅ 歌曲详情和直链获取

### Bilibili
- ✅ 视频排行榜获取
- ✅ 视频流获取（DASH格式MPD）
- ✅ 弹幕、搜索、评论
- ✅ 番剧（PGC）播放支持

### 抖音
- ✅ 分享链接解析
- ✅ 视频直链获取

### 用户系统
- ✅ 用户注册/登录
- ✅ 邮箱验证码
- ✅ 密码重置
- ✅ 收藏功能
- ✅ 管理员后台

## 📚 API 接口文档

### 网易云音乐

#### 获取歌曲详情
- **Endpoint**: `/song`
- **Method**: `POST`
- **Body**: `x-www-form-urlencoded`

**请求参数:**

| 参数  | 是否必须 | 说明                                         |
| :---- | :------- | :------------------------------------------- |
| `ids` / `url`| 是       | 歌曲 ID 或网易云音乐链接（二选一）           |
| `level`| 是       | 音质 (见下方音质说明)                        |
| `type` | 是       | 返回类型: `json` / `down` / `text`         |

**`type` 参数说明:**
- `json`: 返回包含歌曲信息的 JSON 对象 (默认)。
- `down`: 302 重定向到歌曲的直接下载链接。
- `text`: 返回格式化的 HTML 文本。

**`level` 音质参数说明:**
- `standard`, `exhigh`, `lossless`, `hires`, `jyeffect`, `sky`, `jymaster`

**返回示例 (`type=json`):**
```json
{
    "status": 200,
    "name": "杨过",
    "pic": "xxxxx",
    "ar_name": "Vinz-T",
    "al_name": "杨过",
    "level": "极高音质",
    "size": "5.85 MB",
    "url": "https://xxxxx",
    "lyric": "[00:00.00] 作曲 : Vinz-T\n[00:01.00] 作词 : Vinz-T\n[00:02.00] ",
    "tlyric": ""
}
```

#### 搜索歌曲
- **Endpoint**: `/search`
- **Method**: `POST`
- **Body**: `x-www-form-urlencoded`

**请求参数:**

| 参数       | 是否必须 | 说明         | 默认值 |
| :--------- | :------- | :----------- | :--- |
| `keywords` | 是       | 搜索关键词   |      |
| `limit`    | 否       | 返回结果数量 | `10` |

**返回示例:**
```json
{
    "status": 200,
    "result": [
        {
            "id": 12345,
            "name": "歌曲名",
            "artists": "歌手名",
            "album": "专辑名",
            "picUrl": "https://..."
        }
    ]
}
```

#### 获取排行榜
- **Endpoint**: `/toplists`
- **Method**: `GET`
- **返回示例**: 返回包含飙升、新歌、原创、热歌四个榜单的数组，每个榜单包含前20首歌。

#### 获取歌单详情 🆕
- **Endpoint**: `/playlist`
- **Method**: `GET`

**请求参数:**

| 参数 | 是否必须 | 说明 |
| :--- | :------- | :--- |
| `id` | 是 | 歌单ID |
| `limit` | 否 | 限制返回歌曲数量（不填返回全部） |

**返回示例:**
```json
{
  "status": 200,
  "success": true,
  "data": {
    "playlist": {
      "id": 19723756,
      "name": "飙升榜",
      "coverImgUrl": "https://...",
      "creator": "网易云音乐",
      "trackCount": 100,
      "description": "...",
      "tags": ["流行", "华语"],
      "playCount": 1000000,
      "tracks": [
        {
          "id": 123456,
          "name": "歌曲名",
          "artists": "艺术家",
          "album": "专辑名",
          "picUrl": "https://...",
          "duration": 240000
        }
      ]
    }
  }
}
```

#### 获取专辑详情 🆕
- **Endpoint**: `/album`
- **Method**: `GET`

**请求参数:**

| 参数 | 是否必须 | 说明 |
| :--- | :------- | :--- |
| `id` | 是 | 专辑ID |

**返回示例:**
```json
{
  "status": 200,
  "success": true,
  "data": {
    "album": {
      "id": 3406843,
      "name": "叶惠美",
      "coverImgUrl": "https://...",
      "artist": "周杰伦",
      "publishTime": 1057507200000,
      "description": "...",
      "songs": [
        {
          "id": 25643887,
          "name": "以父之名",
          "artists": "周杰伦",
          "album": "叶惠美",
          "picUrl": "https://...",
          "duration": 329029
        }
      ]
    }
  }
}
```

**详细文档**: 查看 [docs/PLAYLIST_API.md](docs/PLAYLIST_API.md)  
**快速测试**: 查看 [docs/PLAYLIST_QUICK_TEST.md](docs/PLAYLIST_QUICK_TEST.md)

### QQ 音乐

#### 获取歌曲详情
- **Endpoint**: `/qq/song`
- **Method**: `GET`

**请求参数:**

| 参数      | 是否必须 | 说明                               |
| :-------- | :------- | :--------------------------------- |
| `ids` / `url` | 是       | 歌曲 ID / songmid 或 QQ音乐链接 |

**返回示例:**
```json
{
    "status": 200,
    "song": {
        "name": "歌曲名",
        "album": "专辑名",
        "singer": "歌手名",
        "pic": "https://...",
        "mid": "003lghpv0jfFXG",
        "id": 108335323
    },
    "lyric": {
        "lyric": "[00:00.00]...",
        "tylyric": "[00:00.00]..."
    },
    "music_urls": {
        "flac": {
            "url": "https://...",
            "bitrate": "FLAC"
        }
    }
}
```

#### 搜索歌曲
- **Endpoint**: `/qq/search`
- **Method**: `GET`
- **参数和返回结构与网易云搜索类似。**

### 酷狗音乐

#### 获取歌曲详情
- **Endpoint**: `/kugou/song`
- **Method**: `GET`

**请求参数:**

| 参数         | 是否必须 | 说明                           |
| :----------- | :------- | :----------------------------- |
| `emixsongid` | 是       | 歌曲的 `EMixSongID` (可从搜索结果中获取) |

**返回示例:**
```json
{
    "status": 200,
    "song": {
        "name": "歌曲名",
        "singer": "歌手名",
        "album": "专辑名",
        "pic": "https://...",
        "lyric": "[00:00.00]...",
        "url": "https://...",
        "bitrate": 320000,
        "duration": 245
    }
}
```
#### 搜索歌曲
- **Endpoint**: `/kugou/search`
- **Method**: `GET`
- **参数和返回结构与网易云搜索类似。**

### Bilibili

#### 获取排行榜
- **Endpoint**: `/bili/ranking`
- **Method**: `GET`

**请求参数:**

| 参数 | 是否必须 | 说明                  | 默认值 |
| :--- | :------- | :-------------------- | :--- |
| `rid`| 否       | 分区 ID (0=全站)      | `0`  |
| `type`| 否      | 视频类型 (all/origin) | `all`|

**返回示例:** 
<details>
<summary>查看响应示例：</summary>

```json

{
  "code": 0,
  "message": "0",
  "ttl": 1,
  "data": {
    "note": "根据稿件内容质量、近期的数据综合展示，动态更新",
    "list": [
      {
        "aid": 114754345572509,
        "videos": 1,
        "tid": 243,
        "tname": "乐评盘点",
        "copyright": 1,
        "pic": "http://i0.hdslb.com/bfs/archive/7d0e9c8fb1a3e217149cbf7d61f4dd37d31b897c.jpg",
        "title": "我把蔡徐坤请来聊了聊新歌以及...丨HOPICO",
        "pubdate": 1751016600,
        "ctime": 1751013050,
        "desc": "",
        "state": 0,
        "duration": 1490,
        "mission_id": 4038652,
        "rights": {
          "bp": 0,
          "elec": 0,
          "download": 0,
          "movie": 0,
          "pay": 0,
          "hd5": 1,
          "no_reprint": 1,
          "autoplay": 1,
          "ugc_pay": 0,
          "is_cooperation": 0,
          "ugc_pay_preview": 0,
          "no_background": 0,
          "arc_pay": 0,
          "pay_free_watch": 0
        },
        "owner": {
          "mid": 261485584,
          "name": "HOPICO",
          "face": "https://i1.hdslb.com/bfs/face/b58d774d803664e838196cd5ce4bbfa3ca7bdfa0.jpg",
          "official_verify": {
            "type": 0,
            "desc": ""
          },
          "vip": {
            "type": 2,
            "status": 1,
            "theme_type": 0
          }
        },
        "stat": {
          "aid": 114754345572509,
          "view": 11604496,
          "danmaku": 449881,
          "reply": 49659,
          "favorite": 325977,
          "coin": 611294,
          "share": 206948,
          "now_rank": 0,
          "his_rank": 1,
          "like": 1027017,
          "dislike": 0,
          "vt": 0,
          "vv": 11604496,
          "fav_g": 28395,
          "like_g": 0,
          "attention": 0,
          "tag_name": ""
        },
        "dynamic": "蔡徐坤的「Deadman」发布之后，受到了许多朋友的好评。所以，这一期，我们把他本人请来聊了聊关于这首歌的故事以及....",
        "cid": 30723017777,
        "dimension": {
          "width": 3840,
          "height": 2160,
          "rotate": 0
        },
        "season_id": 7168,
        "short_link_v2": "https://b23.tv/BV17eKBzKEuZ",
        "first_frame": "http://i1.hdslb.com/bfs/storyff/n250627sa24wt45lljp68536w0l22ix0_firsti.jpg",
        "pub_location": "上海",
        "cover43": "http://i2.hdslb.com/bfs/archive/0a13fe022b05285c75a5e5ecc7935cb695f71b2b.jpg",
        "tidv2": 2026,
        "tnamev2": "乐评盘点",
        "pid_v2": 1003,
        "pid_name_v2": "音乐",
        "bvid": "BV17eKBzKEuZ",
        "score": 0,
        "enable_vt": 0,
        "pages": [
          {
            "cid": 30723017777,
            "page": 1,
            "part": "正片",
            "duration": 1490,
            "dimension": {
              "width": 3840,
              "height": 2160,
              "rotate": 0
            }
          }
        ],
        "subtitle": {
          "allow_submit": false,
          "list": []
        },
        "staff": [
          {
            "mid": 261485584,
            "title": "UP主",
            "name": "HOPICO",
            "face": "https://i1.hdslb.com/bfs/face/b58d774d803664e838196cd5ce4bbfa3ca7bdfa0.jpg"
          }
        ],
        "user_garb": {
          "url_image_ani_cut": ""
        },
        "honor_reply": {},
        "like_icon": "",
        "need_jump_bv": false
      }
    ],
    "config": {
      "show_desc": 1,
      "feed_control": {
        "pull_to_refresh": true,
        "infinity_load": true
      }
    },
    "page": {
      "page_num": 1,
      "page_size": 1,
      "total": 100
    }
  }
}
```
</details>

#### 获取视频播放链接
- **Endpoint**: `/bili/playurl`
- **Method**: `GET`

**请求参数:**

| 参数 | 是否必须 | 说明      |
| :--- | :------- | :-------- |
| `bvid`| 是      | 视频的 BV 号 |

**返回示例:** 


<details>
<summary>查看响应示例：</summary>

```json
{
    "code": 0,
    "message": "0",
    "ttl": 1,
    "data": {
        "from": "local",
        "result": "suee",
        "message": "",
        "quality": 64,
        "format": "flv720",
        "timelength": 1489237,
        "accept_format": "hdflv2,hdflv2,flv,flv720,flv480,mp4",
        "accept_description": [
            "超清 4K",
            "高清 1080P+",
            "高清 1080P",
            "高清 720P",
            "清晰 480P",
            "流畅 360P"
        ],
        "accept_quality": [
            120,
            112,
            80,
            64,
            32,
            16
        ],
        "video_codecid": 7,
        "seek_param": "start",
        "seek_type": "offset",
        "dash": {
            "duration": 1490,
            "minBufferTime": 1.5,
            "min_buffer_time": 1.5,
            "video": [
                {
                    "id": 120,
                    "baseUrl": "https://xy119x188x114x7xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-30120.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=4330466&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=abcc04&traceid=trAeYIDodDYYJb_0_e_N&uipk=5&uparams=e%2Ctrid%2Cmid%2Cdeadline%2Cog%2Cnbs%2Cplatform%2Coi%2Cgen%2Cos%2Cuipk&upsig=b4562e24c936205ff580a8725333efe7",
                    "base_url": "https://xy119x188x114x7xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-30120.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=4330466&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=abcc04&traceid=trAeYIDodDYYJb_0_e_N&uipk=5&uparams=e%2Ctrid%2Cmid%2Cdeadline%2Cog%2Cnbs%2Cplatform%2Coi%2Cgen%2Cos%2Cuipk&upsig=b4562e24c936205ff580a8725333efe7",
                    "backupUrl": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-30120.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&trid=00004dc861ba47c94c3eb602e316052a5acu&mid=514265060&deadline=1751284732&og=cos&nbs=1&platform=pc&oi=0x240882157219f9d1d19f37e6a4322c71&gen=playurlv3&os=mcdn&uipk=5&upsig=b4562e24c936205ff580a8725333efe7&uparams=e,trid,mid,deadline,og,nbs,platform,oi,gen,os,uipk&mcdnid=50032083&bvc=vod&nettype=0&bw=4330466&buvid=&build=0&dl=0&f=u_0_0&agrr=1&orderid=0,3",
                        "https://upos-sz-estgoss.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-30120.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&oi=0x240882157219f9d1d19f37e6a4322c71&trid=4dc861ba47c94c3eb602e316052a5acu&mid=514265060&deadline=1751284732&uipk=5&nbs=1&platform=pc&gen=playurlv3&os=upos&og=cos&upsig=ec7119899598de07004134293d62503a&uparams=e,oi,trid,mid,deadline,uipk,nbs,platform,gen,os,og&bvc=vod&nettype=0&bw=4330466&f=u_0_0&agrr=1&buvid=&build=0&dl=0&orderid=1,3"
                    ],
                    "backup_url": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-30120.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&trid=00004dc861ba47c94c3eb602e316052a5acu&mid=514265060&deadline=1751284732&og=cos&nbs=1&platform=pc&oi=0x240882157219f9d1d19f37e6a4322c71&gen=playurlv3&os=mcdn&uipk=5&upsig=b4562e24c936205ff580a8725333efe7&uparams=e,trid,mid,deadline,og,nbs,platform,oi,gen,os,uipk&mcdnid=50032083&bvc=vod&nettype=0&bw=4330466&buvid=&build=0&dl=0&f=u_0_0&agrr=1&orderid=0,3",
                        "https://upos-sz-estgoss.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-30120.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&oi=0x240882157219f9d1d19f37e6a4322c71&trid=4dc861ba47c94c3eb602e316052a5acu&mid=514265060&deadline=1751284732&uipk=5&nbs=1&platform=pc&gen=playurlv3&os=upos&og=cos&upsig=ec7119899598de07004134293d62503a&uparams=e,oi,trid,mid,deadline,uipk,nbs,platform,gen,os,og&bvc=vod&nettype=0&bw=4330466&f=u_0_0&agrr=1&buvid=&build=0&dl=0&orderid=1,3"
                    ],
                    "bandwidth": 4329860,
                    "mimeType": "video/mp4",
                    "mime_type": "video/mp4",
                    "codecs": "avc1.640033",
                    "width": 3840,
                    "height": 2160,
                    "frameRate": "30.000",
                    "frame_rate": "30.000",
                    "sar": "1:1",
                    "startWithSap": 1,
                    "start_with_sap": 1,
                    "SegmentBase": {
                        "Initialization": "0-940",
                        "indexRange": "941-4548"
                    },
                    "segment_base": {
                        "initialization": "0-940",
                        "index_range": "941-4548"
                    },
                    "codecid": 7
                },
                {
                    "id": 120,
                    "baseUrl": "https://xy119x188x114x5xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-30121.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=2146500&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=37367c&traceid=trgiASRmPlVRbF_0_e_N&uipk=5&uparams=e%2Cos%2Cnbs%2Coi%2Cgen%2Cmid%2Cdeadline%2Cog%2Cuipk%2Cplatform%2Ctrid&upsig=ea6746c69cc7a015d76a2460fc3fc02b",
                    "base_url": "https://xy119x188x114x5xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-30121.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=2146500&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=37367c&traceid=trgiASRmPlVRbF_0_e_N&uipk=5&uparams=e%2Cos%2Cnbs%2Coi%2Cgen%2Cmid%2Cdeadline%2Cog%2Cuipk%2Cplatform%2Ctrid&upsig=ea6746c69cc7a015d76a2460fc3fc02b",
                    "backupUrl": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-30121.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&os=mcdn&nbs=1&oi=0x240882157219f9d1d19f37e6a4322c71&gen=playurlv3&mid=514265060&deadline=1751284732&og=cos&uipk=5&platform=pc&trid=00004dc861ba47c94c3eb602e316052a5acu&upsig=ea6746c69cc7a015d76a2460fc3fc02b&uparams=e,os,nbs,oi,gen,mid,deadline,og,uipk,platform,trid&mcdnid=50032083&bvc=vod&nettype=0&bw=2146500&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=0,3",
                        "https://upos-sz-mirrorcoso1.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-30121.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&os=coso1bv&og=cos&platform=pc&oi=0x240882157219f9d1d19f37e6a4322c71&gen=playurlv3&trid=4dc861ba47c94c3eb602e316052a5acu&mid=514265060&deadline=1751284732&nbs=1&uipk=5&upsig=7209f7ecabcb6b4223cfad100d974bfc&uparams=e,os,og,platform,oi,gen,trid,mid,deadline,nbs,uipk&bvc=vod&nettype=0&bw=2146500&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=1,3"
                    ],
                    "backup_url": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-30121.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&os=mcdn&nbs=1&oi=0x240882157219f9d1d19f37e6a4322c71&gen=playurlv3&mid=514265060&deadline=1751284732&og=cos&uipk=5&platform=pc&trid=00004dc861ba47c94c3eb602e316052a5acu&upsig=ea6746c69cc7a015d76a2460fc3fc02b&uparams=e,os,nbs,oi,gen,mid,deadline,og,uipk,platform,trid&mcdnid=50032083&bvc=vod&nettype=0&bw=2146500&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=0,3",
                        "https://upos-sz-mirrorcoso1.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-30121.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&os=coso1bv&og=cos&platform=pc&oi=0x240882157219f9d1d19f37e6a4322c71&gen=playurlv3&trid=4dc861ba47c94c3eb602e316052a5acu&mid=514265060&deadline=1751284732&nbs=1&uipk=5&upsig=7209f7ecabcb6b4223cfad100d974bfc&uparams=e,os,og,platform,oi,gen,trid,mid,deadline,nbs,uipk&bvc=vod&nettype=0&bw=2146500&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=1,3"
                    ],
                    "bandwidth": 2146187,
                    "mimeType": "video/mp4",
                    "mime_type": "video/mp4",
                    "codecs": "hev1.1.6.L153.90",
                    "width": 3840,
                    "height": 2160,
                    "frameRate": "30.000",
                    "frame_rate": "30.000",
                    "sar": "N/A",
                    "startWithSap": 1,
                    "start_with_sap": 1,
                    "SegmentBase": {
                        "Initialization": "0-1092",
                        "indexRange": "1093-4700"
                    },
                    "segment_base": {
                        "initialization": "0-1092",
                        "index_range": "1093-4700"
                    },
                    "codecid": 12
                },
                {
                    "id": 112,
                    "baseUrl": "https://xy39x166x163x232xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-30112.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=1041399&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=bc32bc&traceid=tremLwBXWjmUBs_0_e_N&uipk=5&uparams=e%2Cgen%2Cog%2Coi%2Cdeadline%2Cuipk%2Cplatform%2Cos%2Ctrid%2Cmid%2Cnbs&upsig=eee033fda3965501022a46ff7262c482",
                    "base_url": "https://xy39x166x163x232xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-30112.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=1041399&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=bc32bc&traceid=tremLwBXWjmUBs_0_e_N&uipk=5&uparams=e%2Cgen%2Cog%2Coi%2Cdeadline%2Cuipk%2Cplatform%2Cos%2Ctrid%2Cmid%2Cnbs&upsig=eee033fda3965501022a46ff7262c482",
                    "backupUrl": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-30112.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&gen=playurlv3&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&deadline=1751284732&uipk=5&platform=pc&os=mcdn&trid=00004dc861ba47c94c3eb602e316052a5acu&mid=514265060&nbs=1&upsig=eee033fda3965501022a46ff7262c482&uparams=e,gen,og,oi,deadline,uipk,platform,os,trid,mid,nbs&mcdnid=50032083&bvc=vod&nettype=0&bw=1041399&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=0,3",
                        "https://upos-sz-estgoss.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-30112.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&deadline=1751284732&uipk=5&platform=pc&oi=0x240882157219f9d1d19f37e6a4322c71&trid=4dc861ba47c94c3eb602e316052a5acu&gen=playurlv3&os=upos&og=cos&nbs=1&mid=514265060&upsig=d467611fcab7e5f00370a65ebef0e3b9&uparams=e,deadline,uipk,platform,oi,trid,gen,os,og,nbs,mid&bvc=vod&nettype=0&bw=1041399&build=0&dl=0&f=u_0_0&agrr=1&buvid=&orderid=1,3"
                    ],
                    "backup_url": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-30112.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&gen=playurlv3&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&deadline=1751284732&uipk=5&platform=pc&os=mcdn&trid=00004dc861ba47c94c3eb602e316052a5acu&mid=514265060&nbs=1&upsig=eee033fda3965501022a46ff7262c482&uparams=e,gen,og,oi,deadline,uipk,platform,os,trid,mid,nbs&mcdnid=50032083&bvc=vod&nettype=0&bw=1041399&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=0,3",
                        "https://upos-sz-estgoss.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-30112.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&deadline=1751284732&uipk=5&platform=pc&oi=0x240882157219f9d1d19f37e6a4322c71&trid=4dc861ba47c94c3eb602e316052a5acu&gen=playurlv3&os=upos&og=cos&nbs=1&mid=514265060&upsig=d467611fcab7e5f00370a65ebef0e3b9&uparams=e,deadline,uipk,platform,oi,trid,gen,os,og,nbs,mid&bvc=vod&nettype=0&bw=1041399&build=0&dl=0&f=u_0_0&agrr=1&buvid=&orderid=1,3"
                    ],
                    "bandwidth": 1041235,
                    "mimeType": "video/mp4",
                    "mime_type": "video/mp4",
                    "codecs": "avc1.640032",
                    "width": 1920,
                    "height": 1080,
                    "frameRate": "30.000",
                    "frame_rate": "30.000",
                    "sar": "N/A",
                    "startWithSap": 1,
                    "start_with_sap": 1,
                    "SegmentBase": {
                        "Initialization": "0-928",
                        "indexRange": "929-4536"
                    },
                    "segment_base": {
                        "initialization": "0-928",
                        "index_range": "929-4536"
                    },
                    "codecid": 7
                },
                {
                    "id": 112,
                    "baseUrl": "https://xy183x247x185x68xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-30102.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=777279&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=hw&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=311f4f&traceid=traEVKvpBwtnUo_0_e_N&uipk=5&uparams=e%2Coi%2Cos%2Cmid%2Cuipk%2Cplatform%2Cgen%2Cog%2Cdeadline%2Cnbs%2Ctrid&upsig=45bc70fc247825fa8668af75fd751eb4",
                    "base_url": "https://xy183x247x185x68xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-30102.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=777279&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=hw&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=311f4f&traceid=traEVKvpBwtnUo_0_e_N&uipk=5&uparams=e%2Coi%2Cos%2Cmid%2Cuipk%2Cplatform%2Cgen%2Cog%2Cdeadline%2Cnbs%2Ctrid&upsig=45bc70fc247825fa8668af75fd751eb4",
                    "backupUrl": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-30102.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&oi=0x240882157219f9d1d19f37e6a4322c71&os=mcdn&mid=514265060&uipk=5&platform=pc&gen=playurlv3&og=hw&deadline=1751284732&nbs=1&trid=00004dc861ba47c94c3eb602e316052a5acu&upsig=45bc70fc247825fa8668af75fd751eb4&uparams=e,oi,os,mid,uipk,platform,gen,og,deadline,nbs,trid&mcdnid=50032083&bvc=vod&nettype=0&bw=777279&f=u_0_0&agrr=1&buvid=&build=0&dl=0&orderid=0,3",
                        "https://upos-sz-mirror08h.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-30102.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&trid=4dc861ba47c94c3eb602e316052a5acu&os=08hbv&mid=514265060&deadline=1751284732&nbs=1&uipk=5&platform=pc&oi=0x240882157219f9d1d19f37e6a4322c71&gen=playurlv3&og=hw&upsig=99e926ce1f90be340aec149a98a5c309&uparams=e,trid,os,mid,deadline,nbs,uipk,platform,oi,gen,og&bvc=vod&nettype=0&bw=777279&build=0&dl=0&f=u_0_0&agrr=1&buvid=&orderid=1,3"
                    ],
                    "backup_url": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-30102.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&oi=0x240882157219f9d1d19f37e6a4322c71&os=mcdn&mid=514265060&uipk=5&platform=pc&gen=playurlv3&og=hw&deadline=1751284732&nbs=1&trid=00004dc861ba47c94c3eb602e316052a5acu&upsig=45bc70fc247825fa8668af75fd751eb4&uparams=e,oi,os,mid,uipk,platform,gen,og,deadline,nbs,trid&mcdnid=50032083&bvc=vod&nettype=0&bw=777279&f=u_0_0&agrr=1&buvid=&build=0&dl=0&orderid=0,3",
                        "https://upos-sz-mirror08h.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-30102.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&trid=4dc861ba47c94c3eb602e316052a5acu&os=08hbv&mid=514265060&deadline=1751284732&nbs=1&uipk=5&platform=pc&oi=0x240882157219f9d1d19f37e6a4322c71&gen=playurlv3&og=hw&upsig=99e926ce1f90be340aec149a98a5c309&uparams=e,trid,os,mid,deadline,nbs,uipk,platform,oi,gen,og&bvc=vod&nettype=0&bw=777279&build=0&dl=0&f=u_0_0&agrr=1&buvid=&orderid=1,3"
                    ],
                    "bandwidth": 777150,
                    "mimeType": "video/mp4",
                    "mime_type": "video/mp4",
                    "codecs": "hev1.1.6.L150.90",
                    "width": 1920,
                    "height": 1080,
                    "frameRate": "30.000",
                    "frame_rate": "30.000",
                    "sar": "N/A",
                    "startWithSap": 1,
                    "start_with_sap": 1,
                    "SegmentBase": {
                        "Initialization": "0-1091",
                        "indexRange": "1092-4699"
                    },
                    "segment_base": {
                        "initialization": "0-1091",
                        "index_range": "1092-4699"
                    },
                    "codecid": 12
                },
                {
                    "id": 80,
                    "baseUrl": "https://xy60x211x204x90xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-100050.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=527626&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=7d76ca&traceid=trvivCuwMEoxul_0_e_N&uipk=5&uparams=e%2Cnbs%2Cgen%2Cplatform%2Coi%2Ctrid%2Cmid%2Cuipk%2Cdeadline%2Cos%2Cog&upsig=b5f88266c3323cb3c82b375312d520db",
                    "base_url": "https://xy60x211x204x90xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-100050.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=527626&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=7d76ca&traceid=trvivCuwMEoxul_0_e_N&uipk=5&uparams=e%2Cnbs%2Cgen%2Cplatform%2Coi%2Ctrid%2Cmid%2Cuipk%2Cdeadline%2Cos%2Cog&upsig=b5f88266c3323cb3c82b375312d520db",
                    "backupUrl": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-100050.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&nbs=1&gen=playurlv3&platform=pc&oi=0x240882157219f9d1d19f37e6a4322c71&trid=00004dc861ba47c94c3eb602e316052a5acu&mid=514265060&uipk=5&deadline=1751284732&os=mcdn&og=cos&upsig=b5f88266c3323cb3c82b375312d520db&uparams=e,nbs,gen,platform,oi,trid,mid,uipk,deadline,os,og&mcdnid=50032083&bvc=vod&nettype=0&bw=527626&buvid=&build=0&dl=0&f=u_0_0&agrr=1&orderid=0,3",
                        "https://upos-sz-estgoss.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-100050.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&uipk=5&platform=pc&gen=playurlv3&og=cos&mid=514265060&deadline=1751284732&nbs=1&oi=0x240882157219f9d1d19f37e6a4322c71&trid=4dc861ba47c94c3eb602e316052a5acu&os=upos&upsig=4a041127cb5729cc4522abcee71c1127&uparams=e,uipk,platform,gen,og,mid,deadline,nbs,oi,trid,os&bvc=vod&nettype=0&bw=527626&dl=0&f=u_0_0&agrr=1&buvid=&build=0&orderid=1,3"
                    ],
                    "backup_url": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-100050.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&nbs=1&gen=playurlv3&platform=pc&oi=0x240882157219f9d1d19f37e6a4322c71&trid=00004dc861ba47c94c3eb602e316052a5acu&mid=514265060&uipk=5&deadline=1751284732&os=mcdn&og=cos&upsig=b5f88266c3323cb3c82b375312d520db&uparams=e,nbs,gen,platform,oi,trid,mid,uipk,deadline,os,og&mcdnid=50032083&bvc=vod&nettype=0&bw=527626&buvid=&build=0&dl=0&f=u_0_0&agrr=1&orderid=0,3",
                        "https://upos-sz-estgoss.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-100050.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&uipk=5&platform=pc&gen=playurlv3&og=cos&mid=514265060&deadline=1751284732&nbs=1&oi=0x240882157219f9d1d19f37e6a4322c71&trid=4dc861ba47c94c3eb602e316052a5acu&os=upos&upsig=4a041127cb5729cc4522abcee71c1127&uparams=e,uipk,platform,gen,og,mid,deadline,nbs,oi,trid,os&bvc=vod&nettype=0&bw=527626&dl=0&f=u_0_0&agrr=1&buvid=&build=0&orderid=1,3"
                    ],
                    "bandwidth": 527531,
                    "mimeType": "video/mp4",
                    "mime_type": "video/mp4",
                    "codecs": "avc1.640032",
                    "width": 1920,
                    "height": 1080,
                    "frameRate": "30.000",
                    "frame_rate": "30.000",
                    "sar": "N/A",
                    "startWithSap": 1,
                    "start_with_sap": 1,
                    "SegmentBase": {
                        "Initialization": "0-928",
                        "indexRange": "929-4536"
                    },
                    "segment_base": {
                        "initialization": "0-928",
                        "index_range": "929-4536"
                    },
                    "codecid": 7
                },
                {
                    "id": 80,
                    "baseUrl": "https://xy60x211x204x79xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-30077.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=460894&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=hw&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=f16582&traceid=trZdzHWkyhZvfI_0_e_N&uipk=5&uparams=e%2Coi%2Cgen%2Cos%2Cog%2Ctrid%2Cuipk%2Cplatform%2Cmid%2Cdeadline%2Cnbs&upsig=d83d3dd3ef298a2f1f5fb16d37481580",
                    "base_url": "https://xy60x211x204x79xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-30077.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=460894&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=hw&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=f16582&traceid=trZdzHWkyhZvfI_0_e_N&uipk=5&uparams=e%2Coi%2Cgen%2Cos%2Cog%2Ctrid%2Cuipk%2Cplatform%2Cmid%2Cdeadline%2Cnbs&upsig=d83d3dd3ef298a2f1f5fb16d37481580",
                    "backupUrl": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-30077.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&oi=0x240882157219f9d1d19f37e6a4322c71&gen=playurlv3&os=mcdn&og=hw&trid=00004dc861ba47c94c3eb602e316052a5acu&uipk=5&platform=pc&mid=514265060&deadline=1751284732&nbs=1&upsig=d83d3dd3ef298a2f1f5fb16d37481580&uparams=e,oi,gen,os,og,trid,uipk,platform,mid,deadline,nbs&mcdnid=50032083&bvc=vod&nettype=0&bw=460894&dl=0&f=u_0_0&agrr=1&buvid=&build=0&orderid=0,3",
                        "https://upos-sz-mirror08h.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-30077.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&platform=pc&trid=4dc861ba47c94c3eb602e316052a5acu&os=08hbv&og=hw&gen=playurlv3&mid=514265060&deadline=1751284732&nbs=1&uipk=5&oi=0x240882157219f9d1d19f37e6a4322c71&upsig=2f206604299fb5255c6dca546f37997d&uparams=e,platform,trid,os,og,gen,mid,deadline,nbs,uipk,oi&bvc=vod&nettype=0&bw=460894&dl=0&f=u_0_0&agrr=1&buvid=&build=0&orderid=1,3"
                    ],
                    "backup_url": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-30077.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&oi=0x240882157219f9d1d19f37e6a4322c71&gen=playurlv3&os=mcdn&og=hw&trid=00004dc861ba47c94c3eb602e316052a5acu&uipk=5&platform=pc&mid=514265060&deadline=1751284732&nbs=1&upsig=d83d3dd3ef298a2f1f5fb16d37481580&uparams=e,oi,gen,os,og,trid,uipk,platform,mid,deadline,nbs&mcdnid=50032083&bvc=vod&nettype=0&bw=460894&dl=0&f=u_0_0&agrr=1&buvid=&build=0&orderid=0,3",
                        "https://upos-sz-mirror08h.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-30077.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&platform=pc&trid=4dc861ba47c94c3eb602e316052a5acu&os=08hbv&og=hw&gen=playurlv3&mid=514265060&deadline=1751284732&nbs=1&uipk=5&oi=0x240882157219f9d1d19f37e6a4322c71&upsig=2f206604299fb5255c6dca546f37997d&uparams=e,platform,trid,os,og,gen,mid,deadline,nbs,uipk,oi&bvc=vod&nettype=0&bw=460894&dl=0&f=u_0_0&agrr=1&buvid=&build=0&orderid=1,3"
                    ],
                    "bandwidth": 460807,
                    "mimeType": "video/mp4",
                    "mime_type": "video/mp4",
                    "codecs": "hev1.1.6.L150.90",
                    "width": 1920,
                    "height": 1080,
                    "frameRate": "30.000",
                    "frame_rate": "30.000",
                    "sar": "N/A",
                    "startWithSap": 1,
                    "start_with_sap": 1,
                    "SegmentBase": {
                        "Initialization": "0-1091",
                        "indexRange": "1092-4699"
                    },
                    "segment_base": {
                        "initialization": "0-1091",
                        "index_range": "1092-4699"
                    },
                    "codecid": 12
                },
                {
                    "id": 64,
                    "baseUrl": "https://xy60x211x204x72xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-100048.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=334547&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=fd7819&traceid=trjnIMDaEoThSl_0_e_N&uipk=5&uparams=e%2Cnbs%2Cplatform%2Cmid%2Cdeadline%2Cuipk%2Cgen%2Cos%2Cog%2Coi%2Ctrid&upsig=8676d104e0b811df82e4dc5577753aaf",
                    "base_url": "https://xy60x211x204x72xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-100048.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=334547&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=fd7819&traceid=trjnIMDaEoThSl_0_e_N&uipk=5&uparams=e%2Cnbs%2Cplatform%2Cmid%2Cdeadline%2Cuipk%2Cgen%2Cos%2Cog%2Coi%2Ctrid&upsig=8676d104e0b811df82e4dc5577753aaf",
                    "backupUrl": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-100048.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&nbs=1&platform=pc&mid=514265060&deadline=1751284732&uipk=5&gen=playurlv3&os=mcdn&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&trid=00004dc861ba47c94c3eb602e316052a5acu&upsig=8676d104e0b811df82e4dc5577753aaf&uparams=e,nbs,platform,mid,deadline,uipk,gen,os,og,oi,trid&mcdnid=50032083&bvc=vod&nettype=0&bw=334547&f=u_0_0&agrr=1&buvid=&build=0&dl=0&orderid=0,3",
                        "https://upos-sz-mirrorcoso1.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-100048.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&oi=0x240882157219f9d1d19f37e6a4322c71&trid=4dc861ba47c94c3eb602e316052a5acu&nbs=1&platform=pc&mid=514265060&deadline=1751284732&gen=playurlv3&os=coso1bv&og=cos&uipk=5&upsig=e303e764cee38fd0cfd04c1757abb39d&uparams=e,oi,trid,nbs,platform,mid,deadline,gen,os,og,uipk&bvc=vod&nettype=0&bw=334547&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=1,3"
                    ],
                    "backup_url": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-100048.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&nbs=1&platform=pc&mid=514265060&deadline=1751284732&uipk=5&gen=playurlv3&os=mcdn&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&trid=00004dc861ba47c94c3eb602e316052a5acu&upsig=8676d104e0b811df82e4dc5577753aaf&uparams=e,nbs,platform,mid,deadline,uipk,gen,os,og,oi,trid&mcdnid=50032083&bvc=vod&nettype=0&bw=334547&f=u_0_0&agrr=1&buvid=&build=0&dl=0&orderid=0,3",
                        "https://upos-sz-mirrorcoso1.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-100048.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&oi=0x240882157219f9d1d19f37e6a4322c71&trid=4dc861ba47c94c3eb602e316052a5acu&nbs=1&platform=pc&mid=514265060&deadline=1751284732&gen=playurlv3&os=coso1bv&og=cos&uipk=5&upsig=e303e764cee38fd0cfd04c1757abb39d&uparams=e,oi,trid,nbs,platform,mid,deadline,gen,os,og,uipk&bvc=vod&nettype=0&bw=334547&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=1,3"
                    ],
                    "bandwidth": 334478,
                    "mimeType": "video/mp4",
                    "mime_type": "video/mp4",
                    "codecs": "avc1.640028",
                    "width": 1280,
                    "height": 720,
                    "frameRate": "30.000",
                    "frame_rate": "30.000",
                    "sar": "N/A",
                    "startWithSap": 1,
                    "start_with_sap": 1,
                    "SegmentBase": {
                        "Initialization": "0-928",
                        "indexRange": "929-4536"
                    },
                    "segment_base": {
                        "initialization": "0-928",
                        "index_range": "929-4536"
                    },
                    "codecid": 7
                },
                {
                    "id": 64,
                    "baseUrl": "https://xy119x188x114x10xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-30066.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=242809&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=hw&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=3ee197&traceid=trDcbjnfznFHvK_0_e_N&uipk=5&uparams=e%2Cos%2Coi%2Ctrid%2Cdeadline%2Cnbs%2Cog%2Cuipk%2Cplatform%2Cmid%2Cgen&upsig=8422c8767d0da4a13474c5db14694fa7",
                    "base_url": "https://xy119x188x114x10xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-30066.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=242809&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=hw&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=3ee197&traceid=trDcbjnfznFHvK_0_e_N&uipk=5&uparams=e%2Cos%2Coi%2Ctrid%2Cdeadline%2Cnbs%2Cog%2Cuipk%2Cplatform%2Cmid%2Cgen&upsig=8422c8767d0da4a13474c5db14694fa7",
                    "backupUrl": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-30066.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&os=mcdn&oi=0x240882157219f9d1d19f37e6a4322c71&trid=00004dc861ba47c94c3eb602e316052a5acu&deadline=1751284732&nbs=1&og=hw&uipk=5&platform=pc&mid=514265060&gen=playurlv3&upsig=8422c8767d0da4a13474c5db14694fa7&uparams=e,os,oi,trid,deadline,nbs,og,uipk,platform,mid,gen&mcdnid=50032083&bvc=vod&nettype=0&bw=242809&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=0,3",
                        "https://upos-sz-mirror08h.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-30066.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&uipk=5&platform=pc&gen=playurlv3&os=08hbv&og=hw&deadline=1751284732&nbs=1&oi=0x240882157219f9d1d19f37e6a4322c71&trid=4dc861ba47c94c3eb602e316052a5acu&mid=514265060&upsig=ae1895a782c026583fc29a5d8e602b1c&uparams=e,uipk,platform,gen,os,og,deadline,nbs,oi,trid,mid&bvc=vod&nettype=0&bw=242809&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=1,3"
                    ],
                    "backup_url": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-30066.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&os=mcdn&oi=0x240882157219f9d1d19f37e6a4322c71&trid=00004dc861ba47c94c3eb602e316052a5acu&deadline=1751284732&nbs=1&og=hw&uipk=5&platform=pc&mid=514265060&gen=playurlv3&upsig=8422c8767d0da4a13474c5db14694fa7&uparams=e,os,oi,trid,deadline,nbs,og,uipk,platform,mid,gen&mcdnid=50032083&bvc=vod&nettype=0&bw=242809&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=0,3",
                        "https://upos-sz-mirror08h.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-30066.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&uipk=5&platform=pc&gen=playurlv3&os=08hbv&og=hw&deadline=1751284732&nbs=1&oi=0x240882157219f9d1d19f37e6a4322c71&trid=4dc861ba47c94c3eb602e316052a5acu&mid=514265060&upsig=ae1895a782c026583fc29a5d8e602b1c&uparams=e,uipk,platform,gen,os,og,deadline,nbs,oi,trid,mid&bvc=vod&nettype=0&bw=242809&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=1,3"
                    ],
                    "bandwidth": 242751,
                    "mimeType": "video/mp4",
                    "mime_type": "video/mp4",
                    "codecs": "hev1.1.6.L120.90",
                    "width": 1280,
                    "height": 720,
                    "frameRate": "30.000",
                    "frame_rate": "30.000",
                    "sar": "N/A",
                    "startWithSap": 1,
                    "start_with_sap": 1,
                    "SegmentBase": {
                        "Initialization": "0-1090",
                        "indexRange": "1091-4698"
                    },
                    "segment_base": {
                        "initialization": "0-1090",
                        "index_range": "1091-4698"
                    },
                    "codecid": 12
                },
                {
                    "id": 32,
                    "baseUrl": "https://xy183x247x185x29xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-100047.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=179207&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=hw&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=dd49e8&traceid=trwBKlFwdBAqMo_0_e_N&uipk=5&uparams=e%2Cdeadline%2Cuipk%2Cplatform%2Coi%2Ctrid%2Cmid%2Cnbs%2Cgen%2Cos%2Cog&upsig=b1c1c6d3ab95940e427a29f433e42b09",
                    "base_url": "https://xy183x247x185x29xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-100047.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=179207&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=hw&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=dd49e8&traceid=trwBKlFwdBAqMo_0_e_N&uipk=5&uparams=e%2Cdeadline%2Cuipk%2Cplatform%2Coi%2Ctrid%2Cmid%2Cnbs%2Cgen%2Cos%2Cog&upsig=b1c1c6d3ab95940e427a29f433e42b09",
                    "backupUrl": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-100047.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&deadline=1751284732&uipk=5&platform=pc&oi=0x240882157219f9d1d19f37e6a4322c71&trid=00004dc861ba47c94c3eb602e316052a5acu&mid=514265060&nbs=1&gen=playurlv3&os=mcdn&og=hw&upsig=b1c1c6d3ab95940e427a29f433e42b09&uparams=e,deadline,uipk,platform,oi,trid,mid,nbs,gen,os,og&mcdnid=50032083&bvc=vod&nettype=0&bw=179207&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=0,3",
                        "https://upos-sz-mirror08h.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-100047.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&os=08hbv&og=hw&nbs=1&oi=0x240882157219f9d1d19f37e6a4322c71&trid=4dc861ba47c94c3eb602e316052a5acu&mid=514265060&gen=playurlv3&deadline=1751284732&uipk=5&platform=pc&upsig=553e27cbf909015a9aad585487921d0e&uparams=e,os,og,nbs,oi,trid,mid,gen,deadline,uipk,platform&bvc=vod&nettype=0&bw=179207&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=1,3"
                    ],
                    "backup_url": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-100047.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&deadline=1751284732&uipk=5&platform=pc&oi=0x240882157219f9d1d19f37e6a4322c71&trid=00004dc861ba47c94c3eb602e316052a5acu&mid=514265060&nbs=1&gen=playurlv3&os=mcdn&og=hw&upsig=b1c1c6d3ab95940e427a29f433e42b09&uparams=e,deadline,uipk,platform,oi,trid,mid,nbs,gen,os,og&mcdnid=50032083&bvc=vod&nettype=0&bw=179207&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=0,3",
                        "https://upos-sz-mirror08h.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-100047.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&os=08hbv&og=hw&nbs=1&oi=0x240882157219f9d1d19f37e6a4322c71&trid=4dc861ba47c94c3eb602e316052a5acu&mid=514265060&gen=playurlv3&deadline=1751284732&uipk=5&platform=pc&upsig=553e27cbf909015a9aad585487921d0e&uparams=e,os,og,nbs,oi,trid,mid,gen,deadline,uipk,platform&bvc=vod&nettype=0&bw=179207&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=1,3"
                    ],
                    "bandwidth": 179158,
                    "mimeType": "video/mp4",
                    "mime_type": "video/mp4",
                    "codecs": "avc1.64001F",
                    "width": 852,
                    "height": 480,
                    "frameRate": "30.000",
                    "frame_rate": "30.000",
                    "sar": "N/A",
                    "startWithSap": 1,
                    "start_with_sap": 1,
                    "SegmentBase": {
                        "Initialization": "0-927",
                        "indexRange": "928-4535"
                    },
                    "segment_base": {
                        "initialization": "0-927",
                        "index_range": "928-4535"
                    },
                    "codecid": 7
                },
                {
                    "id": 32,
                    "baseUrl": "https://xy59x47x5x244xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-30033.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=143788&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=a136d9&traceid=trFTuDOJmruLnz_0_e_N&uipk=5&uparams=e%2Cog%2Cuipk%2Cplatform%2Cmid%2Cgen%2Cos%2Coi%2Ctrid%2Cdeadline%2Cnbs&upsig=2ff2e93dcf79ba92a9fc1b74ffc2b168",
                    "base_url": "https://xy59x47x5x244xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-30033.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=143788&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=a136d9&traceid=trFTuDOJmruLnz_0_e_N&uipk=5&uparams=e%2Cog%2Cuipk%2Cplatform%2Cmid%2Cgen%2Cos%2Coi%2Ctrid%2Cdeadline%2Cnbs&upsig=2ff2e93dcf79ba92a9fc1b74ffc2b168",
                    "backupUrl": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-30033.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&og=cos&uipk=5&platform=pc&mid=514265060&gen=playurlv3&os=mcdn&oi=0x240882157219f9d1d19f37e6a4322c71&trid=00004dc861ba47c94c3eb602e316052a5acu&deadline=1751284732&nbs=1&upsig=2ff2e93dcf79ba92a9fc1b74ffc2b168&uparams=e,og,uipk,platform,mid,gen,os,oi,trid,deadline,nbs&mcdnid=50032083&bvc=vod&nettype=0&bw=143788&buvid=&build=0&dl=0&f=u_0_0&agrr=1&orderid=0,3",
                        "https://upos-sz-estgoss.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-30033.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&platform=pc&oi=0x240882157219f9d1d19f37e6a4322c71&gen=playurlv3&os=upos&og=cos&deadline=1751284732&uipk=5&trid=4dc861ba47c94c3eb602e316052a5acu&mid=514265060&nbs=1&upsig=11adeae31ca700bb6ec62e74fb63a770&uparams=e,platform,oi,gen,os,og,deadline,uipk,trid,mid,nbs&bvc=vod&nettype=0&bw=143788&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=1,3"
                    ],
                    "backup_url": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-30033.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&og=cos&uipk=5&platform=pc&mid=514265060&gen=playurlv3&os=mcdn&oi=0x240882157219f9d1d19f37e6a4322c71&trid=00004dc861ba47c94c3eb602e316052a5acu&deadline=1751284732&nbs=1&upsig=2ff2e93dcf79ba92a9fc1b74ffc2b168&uparams=e,og,uipk,platform,mid,gen,os,oi,trid,deadline,nbs&mcdnid=50032083&bvc=vod&nettype=0&bw=143788&buvid=&build=0&dl=0&f=u_0_0&agrr=1&orderid=0,3",
                        "https://upos-sz-estgoss.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-30033.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&platform=pc&oi=0x240882157219f9d1d19f37e6a4322c71&gen=playurlv3&os=upos&og=cos&deadline=1751284732&uipk=5&trid=4dc861ba47c94c3eb602e316052a5acu&mid=514265060&nbs=1&upsig=11adeae31ca700bb6ec62e74fb63a770&uparams=e,platform,oi,gen,os,og,deadline,uipk,trid,mid,nbs&bvc=vod&nettype=0&bw=143788&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=1,3"
                    ],
                    "bandwidth": 143743,
                    "mimeType": "video/mp4",
                    "mime_type": "video/mp4",
                    "codecs": "hev1.1.6.L120.90",
                    "width": 852,
                    "height": 480,
                    "frameRate": "30.000",
                    "frame_rate": "30.000",
                    "sar": "N/A",
                    "startWithSap": 1,
                    "start_with_sap": 1,
                    "SegmentBase": {
                        "Initialization": "0-1091",
                        "indexRange": "1092-4699"
                    },
                    "segment_base": {
                        "initialization": "0-1091",
                        "index_range": "1092-4699"
                    },
                    "codecid": 12
                },
                {
                    "id": 16,
                    "baseUrl": "https://xy183x247x185x23xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-100046.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=107868&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=18ebef&traceid=trTRvVHWSFdIto_0_e_N&uipk=5&uparams=e%2Cog%2Coi%2Cdeadline%2Cos%2Cnbs%2Cuipk%2Cgen%2Cplatform%2Ctrid%2Cmid&upsig=b7fc1482892308a51bcaa1641cb9fc18",
                    "base_url": "https://xy183x247x185x23xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-100046.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=107868&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=18ebef&traceid=trTRvVHWSFdIto_0_e_N&uipk=5&uparams=e%2Cog%2Coi%2Cdeadline%2Cos%2Cnbs%2Cuipk%2Cgen%2Cplatform%2Ctrid%2Cmid&upsig=b7fc1482892308a51bcaa1641cb9fc18",
                    "backupUrl": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-100046.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&deadline=1751284732&os=mcdn&nbs=1&uipk=5&gen=playurlv3&platform=pc&trid=00004dc861ba47c94c3eb602e316052a5acu&mid=514265060&upsig=b7fc1482892308a51bcaa1641cb9fc18&uparams=e,og,oi,deadline,os,nbs,uipk,gen,platform,trid,mid&mcdnid=50032083&bvc=vod&nettype=0&bw=107868&buvid=&build=0&dl=0&f=u_0_0&agrr=1&orderid=0,3",
                        "https://upos-sz-mirrorcoso1.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-100046.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&oi=0x240882157219f9d1d19f37e6a4322c71&trid=4dc861ba47c94c3eb602e316052a5acu&gen=playurlv3&og=cos&deadline=1751284732&nbs=1&uipk=5&platform=pc&mid=514265060&os=coso1bv&upsig=967c481e83259ad0739931e5aa0aad6d&uparams=e,oi,trid,gen,og,deadline,nbs,uipk,platform,mid,os&bvc=vod&nettype=0&bw=107868&f=u_0_0&agrr=1&buvid=&build=0&dl=0&orderid=1,3"
                    ],
                    "backup_url": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-100046.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&deadline=1751284732&os=mcdn&nbs=1&uipk=5&gen=playurlv3&platform=pc&trid=00004dc861ba47c94c3eb602e316052a5acu&mid=514265060&upsig=b7fc1482892308a51bcaa1641cb9fc18&uparams=e,og,oi,deadline,os,nbs,uipk,gen,platform,trid,mid&mcdnid=50032083&bvc=vod&nettype=0&bw=107868&buvid=&build=0&dl=0&f=u_0_0&agrr=1&orderid=0,3",
                        "https://upos-sz-mirrorcoso1.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-100046.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&oi=0x240882157219f9d1d19f37e6a4322c71&trid=4dc861ba47c94c3eb602e316052a5acu&gen=playurlv3&og=cos&deadline=1751284732&nbs=1&uipk=5&platform=pc&mid=514265060&os=coso1bv&upsig=967c481e83259ad0739931e5aa0aad6d&uparams=e,oi,trid,gen,og,deadline,nbs,uipk,platform,mid,os&bvc=vod&nettype=0&bw=107868&f=u_0_0&agrr=1&buvid=&build=0&dl=0&orderid=1,3"
                    ],
                    "bandwidth": 107829,
                    "mimeType": "video/mp4",
                    "mime_type": "video/mp4",
                    "codecs": "avc1.64001E",
                    "width": 640,
                    "height": 360,
                    "frameRate": "30.000",
                    "frame_rate": "30.000",
                    "sar": "N/A",
                    "startWithSap": 1,
                    "start_with_sap": 1,
                    "SegmentBase": {
                        "Initialization": "0-935",
                        "indexRange": "936-4543"
                    },
                    "segment_base": {
                        "initialization": "0-935",
                        "index_range": "936-4543"
                    },
                    "codecid": 7
                },
                {
                    "id": 16,
                    "baseUrl": "https://xy183x247x185x23xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-30011.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=100337&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=3394ee&traceid=trCHIYfLoKSsMh_0_e_N&uipk=5&uparams=e%2Cdeadline%2Coi%2Cgen%2Cog%2Cmid%2Cos%2Cnbs%2Cuipk%2Cplatform%2Ctrid&upsig=3618f6219e1994a014015e7efd5c1957",
                    "base_url": "https://xy183x247x185x23xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-30011.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=100337&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=3394ee&traceid=trCHIYfLoKSsMh_0_e_N&uipk=5&uparams=e%2Cdeadline%2Coi%2Cgen%2Cog%2Cmid%2Cos%2Cnbs%2Cuipk%2Cplatform%2Ctrid&upsig=3618f6219e1994a014015e7efd5c1957",
                    "backupUrl": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-30011.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&deadline=1751284732&oi=0x240882157219f9d1d19f37e6a4322c71&gen=playurlv3&og=cos&mid=514265060&os=mcdn&nbs=1&uipk=5&platform=pc&trid=00004dc861ba47c94c3eb602e316052a5acu&upsig=3618f6219e1994a014015e7efd5c1957&uparams=e,deadline,oi,gen,og,mid,os,nbs,uipk,platform,trid&mcdnid=50032083&bvc=vod&nettype=0&bw=100337&build=0&dl=0&f=u_0_0&agrr=1&buvid=&orderid=0,3",
                        "https://upos-sz-mirrorcoso1.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-30011.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&mid=514265060&platform=pc&oi=0x240882157219f9d1d19f37e6a4322c71&og=cos&trid=4dc861ba47c94c3eb602e316052a5acu&nbs=1&uipk=5&gen=playurlv3&os=coso1bv&deadline=1751284732&upsig=5f3e1dd2680e3aab0b22b058c40c0ff5&uparams=e,mid,platform,oi,og,trid,nbs,uipk,gen,os,deadline&bvc=vod&nettype=0&bw=100337&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=1,3"
                    ],
                    "backup_url": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-30011.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&deadline=1751284732&oi=0x240882157219f9d1d19f37e6a4322c71&gen=playurlv3&og=cos&mid=514265060&os=mcdn&nbs=1&uipk=5&platform=pc&trid=00004dc861ba47c94c3eb602e316052a5acu&upsig=3618f6219e1994a014015e7efd5c1957&uparams=e,deadline,oi,gen,og,mid,os,nbs,uipk,platform,trid&mcdnid=50032083&bvc=vod&nettype=0&bw=100337&build=0&dl=0&f=u_0_0&agrr=1&buvid=&orderid=0,3",
                        "https://upos-sz-mirrorcoso1.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-30011.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&mid=514265060&platform=pc&oi=0x240882157219f9d1d19f37e6a4322c71&og=cos&trid=4dc861ba47c94c3eb602e316052a5acu&nbs=1&uipk=5&gen=playurlv3&os=coso1bv&deadline=1751284732&upsig=5f3e1dd2680e3aab0b22b058c40c0ff5&uparams=e,mid,platform,oi,og,trid,nbs,uipk,gen,os,deadline&bvc=vod&nettype=0&bw=100337&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=1,3"
                    ],
                    "bandwidth": 100298,
                    "mimeType": "video/mp4",
                    "mime_type": "video/mp4",
                    "codecs": "hev1.1.6.L120.90",
                    "width": 640,
                    "height": 360,
                    "frameRate": "30.000",
                    "frame_rate": "30.000",
                    "sar": "N/A",
                    "startWithSap": 1,
                    "start_with_sap": 1,
                    "SegmentBase": {
                        "Initialization": "0-1091",
                        "indexRange": "1092-4699"
                    },
                    "segment_base": {
                        "initialization": "0-1091",
                        "index_range": "1092-4699"
                    },
                    "codecid": 12
                }
            ],
            "audio": [
                {
                    "id": 30232,
                    "baseUrl": "https://xy61x179x15x146xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-30232.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=94237&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=96dc42&traceid=trMqkaBqSwfSuC_0_e_N&uipk=5&uparams=e%2Cdeadline%2Cnbs%2Cuipk%2Cplatform%2Cgen%2Cog%2Ctrid%2Coi%2Cos%2Cmid&upsig=a6986498597b2b2bc20c59941fde9fe8",
                    "base_url": "https://xy61x179x15x146xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-30232.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=94237&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=cos&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=96dc42&traceid=trMqkaBqSwfSuC_0_e_N&uipk=5&uparams=e%2Cdeadline%2Cnbs%2Cuipk%2Cplatform%2Cgen%2Cog%2Ctrid%2Coi%2Cos%2Cmid&upsig=a6986498597b2b2bc20c59941fde9fe8",
                    "backupUrl": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-30232.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&deadline=1751284732&nbs=1&uipk=5&platform=pc&gen=playurlv3&og=cos&trid=00004dc861ba47c94c3eb602e316052a5acu&oi=0x240882157219f9d1d19f37e6a4322c71&os=mcdn&mid=514265060&upsig=a6986498597b2b2bc20c59941fde9fe8&uparams=e,deadline,nbs,uipk,platform,gen,og,trid,oi,os,mid&mcdnid=50032083&bvc=vod&nettype=0&bw=94237&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=0,3",
                        "https://upos-sz-estgoss.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-30232.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&platform=pc&oi=0x240882157219f9d1d19f37e6a4322c71&trid=4dc861ba47c94c3eb602e316052a5acu&mid=514265060&gen=playurlv3&os=upos&deadline=1751284732&uipk=5&nbs=1&og=cos&upsig=5feb5a47c7c2c6ee6e00049b57ea8bd2&uparams=e,platform,oi,trid,mid,gen,os,deadline,uipk,nbs,og&bvc=vod&nettype=0&bw=94237&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=1,3"
                    ],
                    "backup_url": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-30232.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&deadline=1751284732&nbs=1&uipk=5&platform=pc&gen=playurlv3&og=cos&trid=00004dc861ba47c94c3eb602e316052a5acu&oi=0x240882157219f9d1d19f37e6a4322c71&os=mcdn&mid=514265060&upsig=a6986498597b2b2bc20c59941fde9fe8&uparams=e,deadline,nbs,uipk,platform,gen,og,trid,oi,os,mid&mcdnid=50032083&bvc=vod&nettype=0&bw=94237&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=0,3",
                        "https://upos-sz-estgoss.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-30232.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&platform=pc&oi=0x240882157219f9d1d19f37e6a4322c71&trid=4dc861ba47c94c3eb602e316052a5acu&mid=514265060&gen=playurlv3&os=upos&deadline=1751284732&uipk=5&nbs=1&og=cos&upsig=5feb5a47c7c2c6ee6e00049b57ea8bd2&uparams=e,platform,oi,trid,mid,gen,os,deadline,uipk,nbs,og&bvc=vod&nettype=0&bw=94237&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=1,3"
                    ],
                    "bandwidth": 94199,
                    "mimeType": "audio/mp4",
                    "mime_type": "audio/mp4",
                    "codecs": "mp4a.40.2",
                    "width": 0,
                    "height": 0,
                    "frameRate": "",
                    "frame_rate": "",
                    "sar": "",
                    "startWithSap": 0,
                    "start_with_sap": 0,
                    "SegmentBase": {
                        "Initialization": "0-817",
                        "indexRange": "818-4425"
                    },
                    "segment_base": {
                        "initialization": "0-817",
                        "index_range": "818-4425"
                    },
                    "codecid": 0
                },
                {
                    "id": 30280,
                    "baseUrl": "https://xy119x188x114x5xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-30280.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=176144&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=hw&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=15ffa1&traceid=trgwXDyLIxwXov_0_e_N&uipk=5&uparams=e%2Ctrid%2Cmid%2Cnbs%2Cgen%2Cos%2Cog%2Cuipk%2Cplatform%2Coi%2Cdeadline&upsig=08b5d92fb257bb0d2ba66523ec737bf5",
                    "base_url": "https://xy119x188x114x5xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-30280.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=176144&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=hw&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=15ffa1&traceid=trgwXDyLIxwXov_0_e_N&uipk=5&uparams=e%2Ctrid%2Cmid%2Cnbs%2Cgen%2Cos%2Cog%2Cuipk%2Cplatform%2Coi%2Cdeadline&upsig=08b5d92fb257bb0d2ba66523ec737bf5",
                    "backupUrl": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-30280.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&trid=00004dc861ba47c94c3eb602e316052a5acu&mid=514265060&nbs=1&gen=playurlv3&os=mcdn&og=hw&uipk=5&platform=pc&oi=0x240882157219f9d1d19f37e6a4322c71&deadline=1751284732&upsig=08b5d92fb257bb0d2ba66523ec737bf5&uparams=e,trid,mid,nbs,gen,os,og,uipk,platform,oi,deadline&mcdnid=50032083&bvc=vod&nettype=0&bw=176144&buvid=&build=0&dl=0&f=u_0_0&agrr=1&orderid=0,3",
                        "https://upos-sz-mirror08h.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-30280.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&oi=0x240882157219f9d1d19f37e6a4322c71&deadline=1751284732&nbs=1&gen=playurlv3&os=08hbv&og=hw&trid=4dc861ba47c94c3eb602e316052a5acu&mid=514265060&uipk=5&platform=pc&upsig=0498acd71ab3b588ba82fc1370d53a74&uparams=e,oi,deadline,nbs,gen,os,og,trid,mid,uipk,platform&bvc=vod&nettype=0&bw=176144&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=1,3"
                    ],
                    "backup_url": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-30280.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&trid=00004dc861ba47c94c3eb602e316052a5acu&mid=514265060&nbs=1&gen=playurlv3&os=mcdn&og=hw&uipk=5&platform=pc&oi=0x240882157219f9d1d19f37e6a4322c71&deadline=1751284732&upsig=08b5d92fb257bb0d2ba66523ec737bf5&uparams=e,trid,mid,nbs,gen,os,og,uipk,platform,oi,deadline&mcdnid=50032083&bvc=vod&nettype=0&bw=176144&buvid=&build=0&dl=0&f=u_0_0&agrr=1&orderid=0,3",
                        "https://upos-sz-mirror08h.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-30280.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&oi=0x240882157219f9d1d19f37e6a4322c71&deadline=1751284732&nbs=1&gen=playurlv3&os=08hbv&og=hw&trid=4dc861ba47c94c3eb602e316052a5acu&mid=514265060&uipk=5&platform=pc&upsig=0498acd71ab3b588ba82fc1370d53a74&uparams=e,oi,deadline,nbs,gen,os,og,trid,mid,uipk,platform&bvc=vod&nettype=0&bw=176144&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=1,3"
                    ],
                    "bandwidth": 176092,
                    "mimeType": "audio/mp4",
                    "mime_type": "audio/mp4",
                    "codecs": "mp4a.40.2",
                    "width": 0,
                    "height": 0,
                    "frameRate": "",
                    "frame_rate": "",
                    "sar": "",
                    "startWithSap": 0,
                    "start_with_sap": 0,
                    "SegmentBase": {
                        "Initialization": "0-817",
                        "indexRange": "818-4425"
                    },
                    "segment_base": {
                        "initialization": "0-817",
                        "index_range": "818-4425"
                    },
                    "codecid": 0
                },
                {
                    "id": 30216,
                    "baseUrl": "https://xy120x237x27x67xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-30216.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=41275&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=hw&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=d33437&traceid=trJhArQRlXPeCf_0_e_N&uipk=5&uparams=e%2Cmid%2Cdeadline%2Coi%2Ctrid%2Cgen%2Cos%2Cog%2Cnbs%2Cuipk%2Cplatform&upsig=85636b50a0a40d122a5758a40f63aa35",
                    "base_url": "https://xy120x237x27x67xy.mcdn.bilivideo.cn:8082/v1/resource/30723017777-1-30216.m4s?agrr=1&build=0&buvid=&bvc=vod&bw=41275&deadline=1751284732&dl=0&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M%3D&f=u_0_0&gen=playurlv3&mcdnid=50032083&mid=514265060&nbs=1&nettype=0&og=hw&oi=0x240882157219f9d1d19f37e6a4322c71&orderid=0%2C3&os=mcdn&platform=pc&sign=d33437&traceid=trJhArQRlXPeCf_0_e_N&uipk=5&uparams=e%2Cmid%2Cdeadline%2Coi%2Ctrid%2Cgen%2Cos%2Cog%2Cnbs%2Cuipk%2Cplatform&upsig=85636b50a0a40d122a5758a40f63aa35",
                    "backupUrl": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-30216.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&mid=514265060&deadline=1751284732&oi=0x240882157219f9d1d19f37e6a4322c71&trid=00004dc861ba47c94c3eb602e316052a5acu&gen=playurlv3&os=mcdn&og=hw&nbs=1&uipk=5&platform=pc&upsig=85636b50a0a40d122a5758a40f63aa35&uparams=e,mid,deadline,oi,trid,gen,os,og,nbs,uipk,platform&mcdnid=50032083&bvc=vod&nettype=0&bw=41275&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=0,3",
                        "https://upos-sz-mirrorbd.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-30216.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&gen=playurlv3&deadline=1751284732&uipk=5&platform=pc&mid=514265060&os=bdbv&og=hw&nbs=1&oi=0x240882157219f9d1d19f37e6a4322c71&trid=4dc861ba47c94c3eb602e316052a5acu&upsig=16e1e17b1647a66459574f5b1ea07480&uparams=e,gen,deadline,uipk,platform,mid,os,og,nbs,oi,trid&bvc=vod&nettype=0&bw=41275&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=1,3"
                    ],
                    "backup_url": [
                        "https://xy223x84x44x108xy2409y8738y1600y4ayycxy.mcdn.bilivideo.cn:4483/upgcxcode/77/77/30723017777/30723017777-1-30216.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&mid=514265060&deadline=1751284732&oi=0x240882157219f9d1d19f37e6a4322c71&trid=00004dc861ba47c94c3eb602e316052a5acu&gen=playurlv3&os=mcdn&og=hw&nbs=1&uipk=5&platform=pc&upsig=85636b50a0a40d122a5758a40f63aa35&uparams=e,mid,deadline,oi,trid,gen,os,og,nbs,uipk,platform&mcdnid=50032083&bvc=vod&nettype=0&bw=41275&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=0,3",
                        "https://upos-sz-mirrorbd.bilivideo.com/upgcxcode/77/77/30723017777/30723017777-1-30216.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&gen=playurlv3&deadline=1751284732&uipk=5&platform=pc&mid=514265060&os=bdbv&og=hw&nbs=1&oi=0x240882157219f9d1d19f37e6a4322c71&trid=4dc861ba47c94c3eb602e316052a5acu&upsig=16e1e17b1647a66459574f5b1ea07480&uparams=e,gen,deadline,uipk,platform,mid,os,og,nbs,oi,trid&bvc=vod&nettype=0&bw=41275&agrr=1&buvid=&build=0&dl=0&f=u_0_0&orderid=1,3"
                    ],
                    "bandwidth": 41245,
                    "mimeType": "audio/mp4",
                    "mime_type": "audio/mp4",
                    "codecs": "mp4a.40.5",
                    "width": 0,
                    "height": 0,
                    "frameRate": "",
                    "frame_rate": "",
                    "sar": "",
                    "startWithSap": 0,
                    "start_with_sap": 0,
                    "SegmentBase": {
                        "Initialization": "0-827",
                        "indexRange": "828-4435"
                    },
                    "segment_base": {
                        "initialization": "0-827",
                        "index_range": "828-4435"
                    },
                    "codecid": 0
                }
            ],
            "dolby": {
                "type": 0,
                "audio": null
            },
            "flac": null
        },
        "support_formats": [
            {
                "quality": 120,
                "format": "hdflv2",
                "new_description": "4K 超高清",
                "display_desc": "4K",
                "superscript": "",
                "codecs": [
                    "avc1.640033",
                    "hev1.1.6.L153.90"
                ]
            },
            {
                "quality": 112,
                "format": "hdflv2",
                "new_description": "1080P 高码率",
                "display_desc": "1080P",
                "superscript": "高码率",
                "codecs": [
                    "avc1.640032",
                    "hev1.1.6.L150.90"
                ]
            },
            {
                "quality": 80,
                "format": "flv",
                "new_description": "1080P 高清",
                "display_desc": "1080P",
                "superscript": "",
                "codecs": [
                    "avc1.640032",
                    "hev1.1.6.L150.90"
                ]
            },
            {
                "quality": 64,
                "format": "flv720",
                "new_description": "720P 准高清",
                "display_desc": "720P",
                "superscript": "",
                "codecs": [
                    "avc1.640028",
                    "hev1.1.6.L120.90"
                ]
            },
            {
                "quality": 32,
                "format": "flv480",
                "new_description": "480P 标清",
                "display_desc": "480P",
                "superscript": "",
                "codecs": [
                    "avc1.64001F",
                    "hev1.1.6.L120.90"
                ]
            },
            {
                "quality": 16,
                "format": "mp4",
                "new_description": "360P 流畅",
                "display_desc": "360P",
                "superscript": "",
                "codecs": [
                    "avc1.64001E",
                    "hev1.1.6.L120.90"
                ]
            }
        ],
        "high_format": null,
        "last_play_time": 171000,
        "last_play_cid": 30723017777,
        "view_info": null,
        "play_conf": {
            "is_new_description": false
        }
    }
}
```

</details>