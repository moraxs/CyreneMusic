import type { SongType, PlayModeType } from "@/types/main";
import type { MessageReactive } from "naive-ui";
import { Howl, Howler } from "howler";
import { cloneDeep } from "lodash-es";
import { useMusicStore, useStatusStore, useDataStore, useSettingStore } from "@/stores";
import { resetSongLyric, parseLocalLyric, calculateLyricIndex } from "./lyric";
import { calculateProgress } from "./time";
import { isElectron, isDev, shuffleArray } from "./helper";
import { heartRateList } from "@/api/playlist";
import { formatSongsList } from "./format";
import { isLogin } from "./auth";
import { openUserLogin } from "./modal";
import { personalFm, personalFmToTrash } from "@/api/rec";
import {
  getCoverColor,
  getOnlineUrl,
  getPlayerInfo,
  getPlaySongData,
  getUnlockSongUrl,
} from "./player-utils/song";
import { getLyricData } from "./player-utils/lyric";
import audioContextManager from "@/utils/player-utils/context";
import blob from "./blob";

// 播放器核心
// Howler.js

/* *允许播放格式 */
const allowPlayFormat = ["mp3", "flac", "webm", "ogg", "wav"];

class Player {
  /** 播放器 */
  private player: Howl;
  /** 定时器 */
  private playerInterval: ReturnType<typeof setInterval> | undefined;
  /** 自动关闭定时器 */
  private autoCloseInterval: ReturnType<typeof setInterval> | undefined;
  /** 频谱数据 */
  private audioContext: AudioContext | null = null;
  private analyser: AnalyserNode | null = null;
  private dataArray: Uint8Array<ArrayBuffer> | null = null;
  /** 其他数据 */
  private testNumber: number = 0;
  private message: MessageReactive | null = null;
  /** 预载下一首歌曲播放地址缓存（仅存 URL，不创建 Howl） */
  private nextPrefetch: { id: number; url: string | null; ublock: boolean } | null = null;
  /** 并发控制：当前播放会话与初始化/切曲状态 */
  private playSessionId: number = 0;
  /** 是否正在切换歌曲 */
  private switching: boolean = false;
  constructor() {
    // 创建播放器实例
    this.player = new Howl({ src: [""], format: allowPlayFormat, autoplay: false });
    // 初始化媒体会话
    this.initMediaSession();
    // 挂载全局
    window.$player = this;
  }
  /**
   * 处理播放状态
   */
  private handlePlayStatus() {
    // const musicStore = useMusicStore();
    const statusStore = useStatusStore();
    const settingStore = useSettingStore();
    // 清理定时器
    clearInterval(this.playerInterval);
    // 更新播放状态
    this.playerInterval = setInterval(() => {
      if (!this.player.playing()) return;
      const currentTime = this.getSeek();
      const duration = this.player.duration();
      // 计算进度条距离
      const progress = calculateProgress(currentTime, duration);
      // 计算歌词索引（支持 LRC 与逐字 YRC，对唱重叠处理）
      const { index: lyricIndex, lyrics } = calculateLyricIndex(currentTime);
      // 更新状态
      statusStore.$patch({ currentTime, duration, progress, lyricIndex });
      // 客户端事件
      if (isElectron) {
        // 歌词变化
        window.electron.ipcRenderer.send("play-lyric-change", {
          index: lyricIndex,
          lyric: cloneDeep(lyrics),
        });
        // 进度条
        if (settingStore.showTaskbarProgress) {
          window.electron.ipcRenderer.send("set-bar", progress);
        }
      }
    }, 250);
  }
  /**
   * 预载下一首歌曲的播放地址（优先官方，失败则并发尝试解灰）
   * 仅缓存 URL，不实例化播放器
   */
  private async prefetchNextSongUrl() {
    try {
      const dataStore = useDataStore();
      const statusStore = useStatusStore();
      // const musicStore = useMusicStore();
      const settingStore = useSettingStore();

      // 无列表或私人FM模式直接跳过
      const playList = dataStore.playList;
      if (!playList?.length || statusStore.personalFmMode) {
        this.nextPrefetch = null;
        return;
      }

      // 计算下一首（循环到首）
      let nextIndex = statusStore.playIndex + 1;
      if (nextIndex >= playList.length) nextIndex = 0;
      const nextSong = playList[nextIndex];
      if (!nextSong) {
        this.nextPrefetch = null;
        return;
      }

      // 本地歌曲：直接缓存 file URL
      if (nextSong.path) {
        const songId = nextSong.type === "radio" ? nextSong.dj?.id : nextSong.id;
        this.nextPrefetch = {
          id: Number(songId || nextSong.id),
          url: `file://${nextSong.path}`,
          ublock: false,
        };
        return;
      }

      // 在线歌曲：优先官方，其次解灰
      const songId = nextSong.type === "radio" ? nextSong.dj?.id : nextSong.id;
      if (!songId) {
        this.nextPrefetch = null;
        return;
      }
      const canUnlock = isElectron && nextSong.type !== "radio" && settingStore.useSongUnlock;
      // 先请求官方地址
      const { url: officialUrl, isTrial } = await getOnlineUrl(songId);
      if (officialUrl && !isTrial) {
        // 官方可播放且非试听
        this.nextPrefetch = { id: songId, url: officialUrl, ublock: false };
      } else if (canUnlock) {
        // 官方失败或为试听时尝试解锁
        const unlockUrl = await getUnlockSongUrl(nextSong);
        if (unlockUrl) {
          this.nextPrefetch = { id: songId, url: unlockUrl, ublock: true };
        } else if (officialUrl) {
          // 解锁失败，若官方为试听且允许试听，保留官方试听地址
          this.nextPrefetch = { id: songId, url: officialUrl, ublock: false };
        } else {
          this.nextPrefetch = { id: songId, url: null, ublock: false };
        }
      } else {
        // 不可解锁，仅保留官方结果（可能为空）
        this.nextPrefetch = { id: songId, url: officialUrl, ublock: false };
      }
    } catch (error) {
      console.error("Error prefetching next song url:", error);
    }
  }
  /**
   * 创建播放器
   * @param src 播放地址
   * @param autoPlay 是否自动播放
   * @param seek 播放位置
   */
  private async createPlayer(
    src: string,
    autoPlay: boolean = true,
    seek: number = 0,
    sessionId?: number,
  ) {
    // 获取数据
    const dataStore = useDataStore();
    const musicStore = useMusicStore();
    const statusStore = useStatusStore();
    const settingStore = useSettingStore();
    // 播放信息
    const { id, path, type } = musicStore.playSong;
    // 清理播放器（移除事件，停止并卸载）
    try {
      this.player.off();
    } catch {
      /* empty */
    }
    Howler.stop();
    Howler.unload();
    // 创建播放器（禁用内置 autoplay，统一走手动 play）
    this.player = new Howl({
      src,
      format: allowPlayFormat,
      html5: true,
      autoplay: false,
      preload: "metadata",
      pool: 1,
      volume: statusStore.playVolume,
      rate: statusStore.playRate,
    });
    // 播放器事件（绑定当前会话）
    this.playerEvent({ seek, sessionId });
    // 播放设备
    if (!settingStore.showSpectrums) this.toggleOutputDevice();
    // 自动播放（仅一次性触发）
    if (autoPlay) await this.play();
    // 获取歌曲附加信息 - 非电台和本地
    if (type !== "radio" && !path) {
      getLyricData(id);
    } else resetSongLyric();
    // 定时获取状态
    if (!this.playerInterval) this.handlePlayStatus();
    // 新增播放历史
    if (type !== "radio") dataStore.setHistory(musicStore.playSong);
    // 获取歌曲封面主色
    if (!path) getCoverColor(musicStore.songCover);
    // 更新 MediaSession
    if (!path) this.updateMediaSession();
    // 开发模式
    if (isDev) window.player = this.player;
    // 异步预载下一首播放地址（不阻塞当前播放）
    void this.prefetchNextSongUrl();
  }
  /**
   * 播放器事件
   */
  private playerEvent(
    options: {
      // 恢复进度
      seek?: number;
      // 当前会话 id，用于忽略过期事件
      sessionId?: number;
    } = { seek: 0 },
  ) {
    // 获取数据
    const dataStore = useDataStore();
    const statusStore = useStatusStore();
    const settingStore = useSettingStore();
    const playSongData = getPlaySongData();
    // 获取配置
    const { seek } = options;
    const currentSessionId = options.sessionId ?? this.playSessionId;
    // 初次加载
    this.player.once("load", () => {
      if (currentSessionId !== this.playSessionId) return;
      // 允许跨域
      if (settingStore.showSpectrums) {
        const audioDom = this.getAudioDom();
        if (audioDom) audioDom.crossOrigin = "anonymous";
      }
      // 恢复均衡器：如持久化为开启，则在音频节点可用后立即构建 EQ 链
      if (isElectron && statusStore.eqEnabled) {
        try {
          this.enableEq({ bands: statusStore.eqBands });
        } catch {
          /* empty */
        }
      }
      // 恢复进度（仅在明确指定且大于0时才恢复，避免切换歌曲时意外恢复进度）
      if (seek && seek > 0) {
        const duration = this.player.duration();
        // 确保恢复的进度有效且距离歌曲结束大于2秒
        if (duration && seek < duration - 2) {
          this.setSeek(seek);
        }
      }
      // 更新状态
      statusStore.playLoading = false;
      // ipc
      if (isElectron) {
        window.electron.ipcRenderer.send("play-song-change", getPlayerInfo());
        window.electron.ipcRenderer.send(
          "like-status-change",
          dataStore.isLikeSong(playSongData?.id || 0),
        );
      }
    });
    // 播放
    this.player.on("play", () => {
      if (currentSessionId !== this.playSessionId) return;
      window.document.title = getPlayerInfo() || "SPlayer";
      // ipc
      if (isElectron) {
        window.electron.ipcRenderer.send("play-status-change", true);
        window.electron.ipcRenderer.send("play-song-change", getPlayerInfo());
      }
      console.log("▶️ song play:", playSongData);
    });
    // 暂停
    this.player.on("pause", () => {
      if (currentSessionId !== this.playSessionId) return;
      if (!isElectron) window.document.title = "SPlayer";
      // ipc
      if (isElectron) window.electron.ipcRenderer.send("play-status-change", false);
      console.log("⏸️ song pause:", playSongData);
    });
    // 结束
    this.player.on("end", () => {
      if (currentSessionId !== this.playSessionId) return;
      // statusStore.playStatus = false;
      console.log("⏹️ song end:", playSongData);

      // 检查是否需要在歌曲结束时执行自动关闭
      const statusStore = useStatusStore();
      if (
        statusStore.autoClose.enable &&
        statusStore.autoClose.waitSongEnd &&
        statusStore.autoClose.remainTime <= 0
      ) {
        // 执行自动关闭
        this.executeAutoClose();
        return;
      }

      this.nextOrPrev("next", true, true);
    });
    // 错误
    this.player.on("loaderror", (sourceid, err: unknown) => {
      if (currentSessionId !== this.playSessionId) return;
      const code = typeof err === "number" ? err : undefined;
      this.errorNext(code);
      console.error("❌ song error:", sourceid, playSongData, err);
    });
  }
  /**
   * 初始化 MediaSession
   */
  private initMediaSession() {
    if (!("mediaSession" in navigator)) return;
    navigator.mediaSession.setActionHandler("play", () => this.play());
    navigator.mediaSession.setActionHandler("pause", () => this.pause());
    navigator.mediaSession.setActionHandler("previoustrack", () => this.nextOrPrev("prev"));
    navigator.mediaSession.setActionHandler("nexttrack", () => this.nextOrPrev("next"));
    // 跳转进度
    navigator.mediaSession.setActionHandler("seekto", (event) => {
      if (event.seekTime) this.setSeek(event.seekTime);
    });
  }
  /**
   * 更新 MediaSession
   */
  private updateMediaSession() {
    if (!("mediaSession" in navigator)) return;
    const musicStore = useMusicStore();
    const settingStore = useSettingStore();
    // 获取播放数据
    const playSongData = getPlaySongData();
    if (!playSongData) return;
    // 播放状态
    const isRadio = playSongData.type === "radio";
    // 获取数据
    const metaData: MediaMetadataInit = {
      title: playSongData.name,
      artist: isRadio
        ? "播客电台"
        : // 非本地歌曲且歌手列表为数组
          Array.isArray(playSongData.artists)
          ? playSongData.artists.map((item) => item.name).join(" / ")
          : String(playSongData.artists),
      album: isRadio
        ? "播客电台"
        : // 是否为对象
          typeof playSongData.album === "object"
          ? playSongData.album.name
          : String(playSongData.album),
      artwork: settingStore.smtcOutputHighQualityCover
        ? [
            {
              src: musicStore.getSongCover("xl"),
              sizes: "1920x1920",
              type: "image/jpeg",
            },
          ]
        : [
            {
              src: musicStore.getSongCover("cover"),
              sizes: "512x512",
              type: "image/jpeg",
            },
            {
              src: musicStore.getSongCover("s"),
              sizes: "100x100",
              type: "image/jpeg",
            },
            {
              src: musicStore.getSongCover("m"),
              sizes: "300x300",
              type: "image/jpeg",
            },
            {
              src: musicStore.getSongCover("l"),
              sizes: "1024x1024",
              type: "image/jpeg",
            },
            {
              src: musicStore.getSongCover("xl"),
              sizes: "1920x1920",
              type: "image/jpeg",
            },
          ],
    };
    // 更新数据
    navigator.mediaSession.metadata = new window.MediaMetadata(metaData);
  }
  // 生成频谱数据
  private generateSpectrumData() {
    const statusStore = useStatusStore();
    if (!this.analyser || !this.dataArray) {
      this.initSpectrumData();
    }
    // 更新频谱数据
    const updateSpectrumData = () => {
      if (this.analyser && this.dataArray) {
        this.analyser.getByteFrequencyData(this.dataArray);
        // 保存数据
        statusStore.spectrumsData = Array.from(this.dataArray);
      }
      requestAnimationFrame(updateSpectrumData);
    };
    updateSpectrumData();
  }
  /**
   * 播放错误
   * 在播放错误时，播放下一首
   */
  private async errorNext(errCode?: number) {
    const dataStore = useDataStore();
    // 次数加一
    this.testNumber++;
    if (this.testNumber > 5) {
      this.testNumber = 0;
      this.resetStatus();
      window.$message.error("当前重试次数过多，请稍后再试");
      return;
    }
    // 错误 2 通常为网络地址过期
    if (errCode === 2) {
      // 重载播放器
      await this.initPlayer(true, this.getSeek());
      return;
    }
    // 播放下一曲
    if (dataStore.playList.length > 1) {
      await this.nextOrPrev("next");
    } else {
      window.$message.error("当前列表暂无可播放歌曲");
      this.cleanPlayList();
    }
  }
  /**
   * 获取 Audio Dom
   */
  private getAudioDom(): HTMLMediaElement | null {
    try {
      const sounds = (this.player as any)?._sounds;
      const node = sounds && sounds.length ? sounds[0]?._node : null;
      return node || null;
    } catch {
      return null;
    }
  }
  /**
   * 获取本地歌曲元信息
   * @param path 歌曲路径
   */
  private async parseLocalMusicInfo(path: string) {
    try {
      const musicStore = useMusicStore();
      // 获取封面数据
      const coverData = await window.electron.ipcRenderer.invoke("get-music-cover", path);
      if (coverData) {
        const { data, format } = coverData;
        const blobURL = blob.createBlobURL(data, format, path);
        if (blobURL) {
          musicStore.playSong.cover = blobURL;
        }
      } else {
        musicStore.playSong.cover = "/images/song.jpg?assest";
      }
      // 获取主色
      getCoverColor(musicStore.playSong.cover);
      // 获取歌词数据
      const { lyric, format } = await window.electron.ipcRenderer.invoke("get-music-lyric", path);
      parseLocalLyric(lyric, format);
      // 更新媒体会话
      this.updateMediaSession();
    } catch (error) {
      window.$message.error("获取本地歌曲元信息失败");
      console.error("Failed to parse local music info:", error);
    }
  }
  /**
   * 重置状态
   */
  resetStatus() {
    const statusStore = useStatusStore();
    const musicStore = useMusicStore();
    // 重置状态
    statusStore.$patch({
      currentTime: 0,
      duration: 0,
      progress: 0,
      lyricIndex: -1,
      playStatus: false,
      playLoading: false,
    });
    musicStore.$patch({
      playPlaylistId: 0,
      playSong: {},
    });
  }
  /**
   * 初始化播放器
   * 核心外部调用
   * @param autoPlay 是否自动播放
   * @param seek 播放位置
   */
  async initPlayer(autoPlay: boolean = true, seek: number = 0) {
    const dataStore = useDataStore();
    const musicStore = useMusicStore();
    const statusStore = useStatusStore();
    const settingStore = useSettingStore();
    const sessionId = ++this.playSessionId;
    try {
      // 获取播放数据
      const playSongData = getPlaySongData();
      if (!playSongData) return;
      const { id, dj, path, type } = playSongData;
      // 更改当前播放歌曲
      musicStore.playSong = playSongData;
      // 更改状态
      statusStore.playLoading = true;
      // 本地歌曲
      if (path) {
        await this.createPlayer(`file://${path}`, autoPlay, seek, sessionId);
        // 获取歌曲元信息
        await this.parseLocalMusicInfo(path);
      }
      // 在线歌曲
      else if (id && dataStore.playList.length) {
        const songId = type === "radio" ? dj?.id : id;
        if (!songId) throw new Error("Get song id error");
        // 优先使用预载的下一首 URL（若命中缓存）
        const cached = this.nextPrefetch;
        if (cached && cached.id === songId && cached.url) {
          statusStore.playUblock = cached.ublock;
          await this.createPlayer(cached.url, autoPlay, seek, sessionId);
        } else {
          // 官方地址失败或仅为试听时再尝试解锁（Electron 且非电台且开启解灰）
          const canUnlock = isElectron && type !== "radio" && settingStore.useSongUnlock;
          const { url: officialUrl, isTrial } = await getOnlineUrl(songId);
          if (officialUrl && !isTrial) {
            // 官方可播放且非试听
            statusStore.playUblock = false;
            await this.createPlayer(officialUrl, autoPlay, seek, sessionId);
          } else if (canUnlock) {
            // 官方失败或为试听时尝试解锁
            const unlockUrl = await getUnlockSongUrl(playSongData);
            if (unlockUrl) {
              statusStore.playUblock = true;
              console.log("🎼 Song unlock successfully:", unlockUrl);
              await this.createPlayer(unlockUrl, autoPlay, seek, sessionId);
            } else if (officialUrl) {
              // 解锁失败，若允许试听则播放试听
              if (isTrial && settingStore.playSongDemo) {
                window.$message.warning("当前歌曲仅可试听，请开通会员后重试");
                statusStore.playUblock = false;
                await this.createPlayer(officialUrl, autoPlay, seek, sessionId);
              } else {
                // 不允许试听
                statusStore.playUblock = false;
                if (statusStore.playIndex === dataStore.playList.length - 1) {
                  statusStore.$patch({ playStatus: false, playLoading: false });
                  window.$message.warning("当前列表歌曲无法播放，请更换歌曲");
                } else {
                  window.$message.error("该歌曲暂无音源，跳至下一首");
                  this.nextOrPrev("next");
                }
              }
            } else {
              // 无任何可用地址
              statusStore.playUblock = false;
              if (statusStore.playIndex === dataStore.playList.length - 1) {
                statusStore.$patch({ playStatus: false, playLoading: false });
                window.$message.warning("当前列表歌曲无法播放，请更换歌曲");
              } else {
                window.$message.error("该歌曲暂无音源，跳至下一首");
                this.nextOrPrev("next");
              }
            }
          } else {
            if (dataStore.playList.length === 1) {
              this.resetStatus();
              window.$message.warning("当前播放列表已无可播放歌曲，请更换");
              return;
            } else {
              window.$message.error("该歌曲无法播放，跳至下一首");
              this.nextOrPrev();
              return;
            }
          }
        }
      }
    } catch (error) {
      console.error("❌ 初始化音乐播放器出错：", error);
      window.$message.error("播放器遇到错误，请尝试软件热重载");
      // this.errorNext();
    } finally {
      this.switching = false;
    }
  }
  /**
   * 播放
   */
  async play() {
    const statusStore = useStatusStore();
    const settingStore = useSettingStore();
    // 已在播放
    if (this.player.playing()) {
      statusStore.playStatus = true;
      return;
    }
    this.player.play();
    // 淡入
    await new Promise<void>((resolve) => {
      this.player.once("play", () => {
        // 在淡入开始时立即设置播放状态
        statusStore.playStatus = true;
        this.player.fade(0, statusStore.playVolume, settingStore.getFadeTime);
        resolve();
      });
    });
  }
  /**
   * 暂停
   * @param changeStatus 是否更改播放状态
   */
  async pause(changeStatus: boolean = true) {
    const statusStore = useStatusStore();
    const settingStore = useSettingStore();

    // 播放器未加载完成
    if (this.player.state() !== "loaded") {
      return;
    }

    // 立即设置播放状态
    if (changeStatus) statusStore.playStatus = false;

    // 淡出
    await new Promise<void>((resolve) => {
      this.player.fade(statusStore.playVolume, 0, settingStore.getFadeTime);
      this.player.once("fade", () => {
        this.player.pause();
        resolve();
      });
    });
  }
  /**
   * 播放或暂停
   */
  async playOrPause() {
    const statusStore = useStatusStore();
    if (statusStore.playStatus) await this.pause();
    else await this.play();
  }
  /**
   * 下一首或上一首
   * @param type 切换类别 next 下一首 prev 上一首
   * @param play 是否立即播放
   * @param autoEnd 是否为歌曲自动播放结束
   */
  async nextOrPrev(type: "next" | "prev" = "next", play: boolean = true, autoEnd: boolean = false) {
    try {
      if (this.switching) return;
      this.switching = true;
      const statusStore = useStatusStore();
      const dataStore = useDataStore();
      const musicStore = useMusicStore();
      // 获取数据
      const { playList } = dataStore;
      const { playSong } = musicStore;
      const { playSongMode, playHeartbeatMode } = statusStore;
      // 列表长度
      const playListLength = playList.length;
      // 播放列表是否为空
      if (playListLength === 0) throw new Error("Play list is empty");
      // 若为私人FM
      if (statusStore.personalFmMode) {
        await this.initPersonalFM(true);
        return;
      }
      // 只有一首歌的特殊处理
      if (playListLength === 1) {
        statusStore.lyricIndex = -1;
        this.setSeek(0);
        await this.play();
        return;
      }
      // 单曲循环
      if (playSongMode === "repeat-once" && autoEnd && !playHeartbeatMode) {
        statusStore.lyricIndex = -1;
        this.setSeek(0);
        await this.play();
        return;
      }
      // 列表循环、单曲循环（手动切歌）、处于心动模式或随机模式
      if (
        playSongMode === "repeat" ||
        playSongMode === "repeat-once" ||
        playSongMode === "shuffle" ||
        playHeartbeatMode ||
        playSong.type === "radio"
      ) {
        statusStore.playIndex += type === "next" ? 1 : -1;
      } else {
        throw new Error("The play mode is not supported");
      }
      // 索引是否越界
      if (statusStore.playIndex < 0) {
        statusStore.playIndex = playListLength - 1;
      } else if (statusStore.playIndex >= playListLength) {
        statusStore.playIndex = 0;
      }
      // 重置播放进度和歌词索引（切换歌曲时必须重置）
      statusStore.lyricIndex = -1;
      statusStore.currentTime = 0;
      statusStore.progress = 0;
      // 暂停
      await this.pause(false);
      // 初始化播放器（不传入seek参数，确保从头开始播放）
      await this.initPlayer(play, 0);
    } catch (error) {
      console.error("Error in nextOrPrev:", error);
      throw error;
    } finally {
      this.switching = false;
    }
  }
  /**
   * 切换播放模式
   * @param mode 播放模式 repeat / repeat-once / shuffle
   */
  async togglePlayMode(mode: PlayModeType | false) {
    const statusStore = useStatusStore();
    const dataStore = useDataStore();
    const musicStore = useMusicStore();
    // 退出心动模式
    if (statusStore.playHeartbeatMode) this.toggleHeartMode(false);
    // 计算目标模式
    let targetMode: PlayModeType;
    if (mode) {
      targetMode = mode;
    } else {
      switch (statusStore.playSongMode) {
        case "repeat":
          targetMode = "repeat-once";
          break;
        case "shuffle":
          targetMode = "repeat";
          break;
        case "repeat-once":
          targetMode = "shuffle";
          break;
        default:
          targetMode = "repeat";
      }
    }
    // 进入随机模式：保存原顺序并打乱当前歌单
    if (targetMode === "shuffle" && statusStore.playSongMode !== "shuffle") {
      const currentList = dataStore.playList;
      if (currentList && currentList.length > 1) {
        const currentSongId = musicStore.playSong?.id;
        await dataStore.setOriginalPlayList(currentList);
        const shuffled = shuffleArray(currentList);
        await dataStore.setPlayList(shuffled);
        if (currentSongId) {
          const newIndex = shuffled.findIndex((s: any) => s?.id === currentSongId);
          if (newIndex !== -1) useStatusStore().playIndex = newIndex;
        }
      }
    }
    // 离开随机模式：恢复到原顺序
    if (
      statusStore.playSongMode === "shuffle" &&
      (targetMode === "repeat" || targetMode === "repeat-once")
    ) {
      const original = await dataStore.getOriginalPlayList();
      if (original && original.length) {
        const currentSongId = musicStore.playSong?.id;
        await dataStore.setPlayList(original);
        if (currentSongId) {
          const origIndex = original.findIndex((s: any) => s?.id === currentSongId);
          useStatusStore().playIndex = origIndex !== -1 ? origIndex : 0;
        } else {
          useStatusStore().playIndex = 0;
        }
        await dataStore.clearOriginalPlayList();
      }
    }
    // 应用模式
    statusStore.playSongMode = targetMode;
    this.playModeSyncIpc();
  }
  /**
   * 播放模式同步 ipc
   */
  playModeSyncIpc() {
    const statusStore = useStatusStore();
    if (isElectron) {
      window.electron.ipcRenderer.send("play-mode-change", statusStore.playSongMode);
    }
  }
  /**
   * 设置播放进度
   * @param time 播放进度
   */
  setSeek(time: number) {
    const statusStore = useStatusStore();
    this.player.seek(time);
    statusStore.currentTime = time;
  }
  /**
   * 获取播放进度
   * @returns 播放进度
   */
  getSeek(): number {
    return this.player.seek();
  }
  /**
   * 设置播放速率
   * @param rate 播放速率
   */
  setRate(rate: number) {
    const statusStore = useStatusStore();
    this.player.rate(rate);
    statusStore.playRate = rate;
  }
  /**
   * 设置播放音量
   * @param actions 音量
   */
  setVolume(actions: number | "up" | "down" | WheelEvent) {
    const statusStore = useStatusStore();
    const increment = 0.05;
    // 直接设置
    if (typeof actions === "number") {
      actions = Math.max(0, Math.min(actions, 1));
    }
    // 分类调节
    else if (actions === "up" || actions === "down") {
      statusStore.playVolume = Math.max(
        0,
        Math.min(statusStore.playVolume + (actions === "up" ? increment : -increment), 1),
      );
    }
    // 鼠标滚轮
    else {
      const deltaY = actions.deltaY;
      const volumeChange = deltaY > 0 ? -increment : increment;
      statusStore.playVolume = Math.max(0, Math.min(statusStore.playVolume + volumeChange, 1));
    }
    // 调整音量
    this.player.volume(statusStore.playVolume);
  }
  /**
   * 切换静音
   */
  toggleMute() {
    const statusStore = useStatusStore();
    // 是否静音
    const isMuted = statusStore.playVolume === 0;
    // 恢复音量
    if (isMuted) {
      statusStore.playVolume = statusStore.playVolumeMute;
    }
    // 保存当前音量并静音
    else {
      statusStore.playVolumeMute = this.player.volume();
      statusStore.playVolume = 0;
    }
    this.player.volume(statusStore.playVolume);
  }
  /**
   * 更新播放列表
   * @param data 播放列表
   * @param song 当前播放歌曲
   * @param pid 播放列表id
   * @param options 配置
   * @param options.showTip 是否显示提示
   * @param options.scrobble 是否打卡
   * @param options.play 是否直接播放
   */
  async updatePlayList(
    data: SongType[],
    song?: SongType,
    pid?: number,
    options: {
      showTip?: boolean;
      scrobble?: boolean;
      play?: boolean;
    } = {
      showTip: true,
      scrobble: true,
      play: true,
    },
  ) {
    if (!data || !data.length) return;
    const dataStore = useDataStore();
    const musicStore = useMusicStore();
    const statusStore = useStatusStore();
    // 获取配置
    const { showTip, play } = options;

    // 处理随机播放模式
    let processedData = cloneDeep(data);
    if (statusStore.playSongMode === "shuffle") {
      // 保存原始播放列表
      await dataStore.setOriginalPlayList(cloneDeep(data));
      // 随机排序
      processedData = shuffleArray(processedData);
    }

    // 更新列表
    await dataStore.setPlayList(processedData);
    // 关闭特殊模式
    if (statusStore.playHeartbeatMode) this.toggleHeartMode(false);
    if (statusStore.personalFmMode) statusStore.personalFmMode = false;
    // 是否直接播放
    if (song && typeof song === "object" && "id" in song) {
      // 是否为当前播放歌曲
      if (musicStore.playSong.id === song.id) {
        if (play) await this.play();
      } else {
        // 查找索引（在处理后的列表中查找）
        statusStore.playIndex = processedData.findIndex((item) => item.id === song.id);
        // 播放
        await this.pause(false);
        await this.initPlayer();
      }
    } else {
      statusStore.playIndex =
        statusStore.playSongMode === "shuffle"
          ? Math.floor(Math.random() * processedData.length)
          : 0;
      // 播放
      await this.pause(false);
      await this.initPlayer();
    }
    // 更改播放歌单
    musicStore.playPlaylistId = pid ?? 0;
    if (showTip) window.$message.success("已开始播放");
  }
  /**
   * 添加下一首歌曲
   * @param song 歌曲
   * @param play 是否立即播放
   */
  async addNextSong(song: SongType, play: boolean = false) {
    const dataStore = useDataStore();
    const musicStore = useMusicStore();
    const statusStore = useStatusStore();
    // 关闭特殊模式
    if (statusStore.personalFmMode) statusStore.personalFmMode = false;
    // 是否为当前播放歌曲
    if (musicStore.playSong.id === song.id) {
      this.play();
      window.$message.success("已开始播放");
      return;
    }
    // 尝试添加
    const songIndex = await dataStore.setNextPlaySong(song, statusStore.playIndex);
    // 播放歌曲
    if (songIndex < 0) return;
    if (play) this.togglePlayIndex(songIndex, true);
    else window.$message.success("已添加至下一首播放");
  }
  /**
   * 切换播放索引
   * @param index 播放索引
   * @param play 是否立即播放
   */
  async togglePlayIndex(index: number, play: boolean = false) {
    const dataStore = useDataStore();
    const statusStore = useStatusStore();
    // 获取数据
    const { playList } = dataStore;
    // 若超出播放列表
    if (index >= playList.length) return;
    // 相同
    if (!play && statusStore.playIndex === index) {
      this.play();
      return;
    }
    // 更改状态
    statusStore.playIndex = index;
    // 重置播放进度和歌词索引（切换歌曲时必须重置）
    statusStore.lyricIndex = -1;
    statusStore.currentTime = 0;
    statusStore.progress = 0;

    // 清理并播放（不传入seek参数，确保从头开始播放）
    await this.initPlayer(true, 0);
  }
  /**
   * 移除指定歌曲
   * @param index 歌曲索引
   */
  removeSongIndex(index: number) {
    const dataStore = useDataStore();
    const statusStore = useStatusStore();
    // 获取数据
    const { playList } = dataStore;
    // 若超出播放列表
    if (index >= playList.length) return;
    // 仅剩一首
    if (playList.length === 1) {
      this.cleanPlayList();
      return;
    }
    // 是否为当前播放歌曲
    const isCurrentPlay = statusStore.playIndex === index;
    // 深拷贝，防止影响原数据
    const newPlaylist = cloneDeep(playList);
    // 若将移除最后一首
    if (index === playList.length - 1) {
      statusStore.playIndex = 0;
    }
    // 若为当前播放之后
    else if (statusStore.playIndex > index) {
      statusStore.playIndex--;
    }
    // 移除指定歌曲
    newPlaylist.splice(index, 1);
    dataStore.setPlayList(newPlaylist);
    // 若为当前播放
    if (isCurrentPlay) {
      this.initPlayer(statusStore.playStatus);
    }
  }
  /**
   * 清空播放列表
   */
  async cleanPlayList() {
    const dataStore = useDataStore();
    const musicStore = useMusicStore();
    const statusStore = useStatusStore();
    // 停止播放
    Howler.unload();
    // 清空数据
    this.resetStatus();
    statusStore.$patch({
      playListShow: false,
      showFullPlayer: false,
      playHeartbeatMode: false,
      personalFmMode: false,
      playIndex: -1,
    });
    musicStore.resetMusicData();
    dataStore.setPlayList([]);
    window.$message.success("已清空播放列表");
  }
  /**
   * 切换输出设备
   * @param deviceId 输出设备
   */
  toggleOutputDevice(deviceId?: string) {
    try {
      const settingStore = useSettingStore();
      // 输出设备
      const devices = deviceId ?? settingStore.playDevice;
      if (!(this.player as any)?._sounds.length) return;
      // 获取音频元素
      const audioDom = this.getAudioDom();
      // 设置输出设备
      if (devices && audioDom?.setSinkId) {
        audioDom.setSinkId(devices);
      }
    } catch (error) {
      console.error("Failed to change audio output device:", error);
    }
  }
  /**
   * 初始化音频可视化
   */
  initSpectrumData() {
    try {
      if (this.audioContext || !isElectron) return;
      // 获取音频元素
      const audioDom = this.getAudioDom();
      if (!audioDom) return;
      // 通过统一管理器创建/获取基础图
      const nodes = audioContextManager.getOrCreateBasicGraph(audioDom);
      if (!nodes) return;
      // 记录节点
      this.audioContext = nodes.context;
      this.analyser = nodes.analyser;
      // 可视化保持与原有行为一致：连接到输出
      this.analyser.connect(this.audioContext.destination);
      // 配置数据缓冲
      const bufferLength = this.analyser.frequencyBinCount;
      this.dataArray = new Uint8Array(bufferLength);
      // 更新频谱数据
      this.generateSpectrumData();
      console.log("🎼 Initialize music spectrum successfully");
    } catch (error) {
      console.error("🎼 Initialize music spectrum failed:", error);
    }
  }

  /**
   * 启用均衡器
   * @param options 配置
   * @param options.bands 各频段 dB 值（与 frequencies 对齐），直接写入 filter.gain
   * @param options.preamp 前级增益 dB，转换为线性增益写入 preGain.gain
   * @param options.q peaking 类型的 Q 值统一更新（shelf 不适用 Q）
   * @param options.frequencies 自定义中心频率
   */
  enableEq(options?: { bands?: number[]; preamp?: number; q?: number; frequencies?: number[] }) {
    if (!isElectron) return;
    const audioDom = this.getAudioDom();
    if (!audioDom) return;
    const nodes = audioContextManager.enableEq(audioDom, options);
    if (!nodes) return;
    // 连接到输出，确保声音从 WebAudio 输出
    try {
      nodes.analyser.connect(nodes.context.destination);
    } catch {
      /* empty */
    }
  }

  /**
   * 更新均衡器参数
   * @param options 配置
   * @param options.bands 各频段 dB 值（与 frequencies 对齐），直接写入 filter.gain
   * @param options.preamp 前级增益 dB，转换为线性增益写入 preGain.gain
   * @param options.q peaking 类型的 Q 值统一更新（shelf 不适用 Q）
   */
  updateEq(options: { bands?: number[]; preamp?: number; q?: number }) {
    if (!isElectron) return;
    const audioDom = this.getAudioDom();
    if (!audioDom) return;
    audioContextManager.updateEq(audioDom, options);
  }

  /**
   * 禁用均衡器并恢复直出（保持频谱可用）
   */
  disableEq() {
    if (!isElectron) return;
    const audioDom = this.getAudioDom();
    if (!audioDom) return;
    audioContextManager.disableEq(audioDom);
    // 恢复 analyser 输出
    const nodes = audioContextManager.getOrCreateBasicGraph(audioDom);
    if (nodes) {
      try {
        nodes.analyser.connect(nodes.context.destination);
      } catch {
        /* empty */
      }
    }
  }
  /**
   * 切换桌面歌词
   */
  toggleDesktopLyric() {
    const statusStore = useStatusStore();
    const show = !statusStore.showDesktopLyric;
    statusStore.showDesktopLyric = show;
    window.electron.ipcRenderer.send("change-desktop-lyric", show);
    window.$message.success(`${show ? "已开启" : "已关闭"}桌面歌词`);
  }
  /**
   * 切换心动模式
   * @param open 是否开启
   */
  async toggleHeartMode(open: boolean = true) {
    try {
      const dataStore = useDataStore();
      const musicStore = useMusicStore();
      const statusStore = useStatusStore();
      if (!open && statusStore.playHeartbeatMode) {
        statusStore.playHeartbeatMode = false;
        window.$message.success("已退出心动模式");
        return;
      }
      if (isLogin() !== 1) {
        if (isLogin() === 0) {
          openUserLogin(true);
        } else {
          window.$message.warning("该登录模式暂不支持该操作");
        }
        return;
      }
      if (statusStore.playHeartbeatMode) {
        window.$message.warning("已处于心动模式");
        this.play();
        return;
      }
      this.message?.destroy();
      this.message = window.$message.loading("心动模式开启中", { duration: 0 });
      // 获取所需数据
      const playSongData = getPlaySongData();
      const likeSongsList: any = await dataStore.getUserLikePlaylist();
      // if (!playSongData || !likeSongsList) {
      //   throw new Error("获取播放数据或喜欢列表失败");
      // }
      const pid =
        musicStore.playPlaylistId && musicStore.playPlaylistId !== 0
          ? musicStore.playPlaylistId
          : likeSongsList?.detail?.id;
      // 开启心动模式
      const result = await heartRateList(playSongData?.id || 0, pid);
      if (result.code === 200) {
        this.message?.destroy();
        const heartRatelists = formatSongsList(result.data);
        // 更新播放列表
        await this.updatePlayList(heartRatelists, heartRatelists[0]);
        // 更改模式
        statusStore.playHeartbeatMode = true;
      } else {
        this.message?.destroy();
        window.$message.error(result.message || "心动模式开启出错，请重试");
      }
    } catch (error) {
      console.error("Failed to toggle heart mode:", error);
      this.message?.destroy();
      window.$message.error("心动模式开启出错，请重试");
    } finally {
      this.message?.destroy();
    }
  }
  /**
   * 初始化私人FM
   * @param playNext 是否播放下一首
   */
  async initPersonalFM(playNext: boolean = false) {
    const musicStore = useMusicStore();
    const statusStore = useStatusStore();
    try {
      // 获取并重置
      const getPersonalFmData = async () => {
        const result = await personalFm();
        const songData = formatSongsList(result.data);
        console.log(`🌐 personal FM:`, songData);
        musicStore.personalFM.list = songData;
        musicStore.personalFM.playIndex = 0;
      };
      // 若为空
      if (musicStore.personalFM.list.length === 0) await getPersonalFmData();
      // 若需播放下一首
      if (playNext) {
        statusStore.personalFmMode = true;
        // 更改索引
        if (musicStore.personalFM.playIndex < musicStore.personalFM.list.length - 1) {
          musicStore.personalFM.playIndex++;
        } else {
          await getPersonalFmData();
        }
        // 清理并播放
        this.resetStatus();
        await this.initPlayer();
      }
    } catch (error) {
      console.error("Failed to initialize personal FM:", error);
    }
  }
  /**
   * 私人FM - 垃圾桶
   * @param id 歌曲id
   */
  async personalFMTrash(id: number) {
    try {
      const statusStore = useStatusStore();
      if (!isLogin()) {
        openUserLogin(true);
        return;
      }
      // 更改模式
      statusStore.personalFmMode = true;
      statusStore.playHeartbeatMode = false;
      // 加入回收站
      const result = await personalFmToTrash(id);
      if (result.code === 200) {
        window.$message.success("已移至垃圾桶");
        this.nextOrPrev("next");
      }
    } catch (error) {
      console.error("Error adding to trash:", error);
      window.$message.error("移至垃圾桶失败，请重试");
    }
  }
  /**
   * 开始定时关闭
   * @param time 关闭时间（分钟）
   * @param remainTime 剩余时间（秒）
   */
  startAutoCloseTimer(time: number, remainTime: number) {
    const statusStore = useStatusStore();
    if (!time || !remainTime) return;
    // 如已有定时器在运行，先停止以防叠加
    if (this.autoCloseInterval) {
      clearInterval(this.autoCloseInterval);
      this.autoCloseInterval = undefined;
    }
    // 重置剩余时间
    Object.assign(statusStore.autoClose, {
      enable: true,
      time,
      remainTime,
    });
    // 开始减少剩余时间
    this.autoCloseInterval = setInterval(() => {
      if (statusStore.autoClose.remainTime <= 0) {
        clearInterval(this.autoCloseInterval);
        this.autoCloseInterval = undefined;
        if (!statusStore.autoClose.waitSongEnd) {
          this.executeAutoClose();
        }
        return;
      }
      statusStore.autoClose.remainTime--;
    }, 1000);
  }
  /**
   * 执行自动关闭操作
   */
  private executeAutoClose() {
    console.log("🔄 执行自动关闭");
    // 暂停播放
    this.pause();
    // 重置状态
    const { autoClose } = useStatusStore();
    autoClose.enable = false;
    autoClose.remainTime = autoClose.time * 60;
  }
}

export default new Player();
