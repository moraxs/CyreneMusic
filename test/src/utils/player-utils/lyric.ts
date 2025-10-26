import { useMusicStore, useSettingStore, useStatusStore } from "@/stores";
import { parsedLyricsData, parseTTMLToAMLL, parseTTMLToYrc, resetSongLyric } from "../lyric";
import { songLyric, songLyricTTML } from "@/api/song";
import { parseTTML } from "@applemusic-like-lyrics/lyric";
import { LyricLine } from "@applemusic-like-lyrics/core";
import { LyricType } from "@/types/main";

/**
 * 获取歌词
 * @param id 歌曲id
 */
export const getLyricData = async (id: number) => {
  const musicStore = useMusicStore();
  const settingStore = useSettingStore();
  const statusStore = useStatusStore();

  if (!id) {
    statusStore.usingTTMLLyric = false;
    resetSongLyric();
    return;
  }

  try {
    // 检测本地歌词覆盖
    const getLyric = getLyricFun(settingStore.localLyricPath, id);
    const [lyricRes, ttmlContent] = await Promise.all([
      getLyric("lrc", songLyric),
      settingStore.enableTTMLLyric ? getLyric("ttml", songLyricTTML) : getLyric("ttml"),
    ]);
    parsedLyricsData(lyricRes);
    if (ttmlContent) {
      const parsedResult = parseTTML(ttmlContent);
      if (!parsedResult?.lines?.length) {
        statusStore.usingTTMLLyric = false;
        return;
      }
      const ttmlLyric = parseTTMLToAMLL(parsedResult);
      const ttmlYrcLyric = parseTTMLToYrc(parsedResult);
      console.log("TTML lyrics:", ttmlLyric, ttmlYrcLyric);
      // 合并数据
      const updates: Partial<{ yrcAMData: LyricLine[]; yrcData: LyricType[] }> = {};
      if (ttmlLyric?.length) {
        updates.yrcAMData = ttmlLyric;
        console.log("✅ TTML AMLL lyrics success");
      }
      if (ttmlYrcLyric?.length) {
        updates.yrcData = ttmlYrcLyric;
        console.log("✅ TTML Yrc lyrics success");
      }
      if (Object.keys(updates).length) {
        musicStore.songLyric = {
          ...musicStore.songLyric,
          ...updates,
        };
        statusStore.usingTTMLLyric = true;
      } else {
        statusStore.usingTTMLLyric = false;
      }
    } else {
      statusStore.usingTTMLLyric = false;
    }
  } catch (error) {
    console.error("❌ Error loading lyrics:", error);
    statusStore.usingTTMLLyric = false;
    resetSongLyric();
  }
};

/**
 * 获取歌词函数生成器
 * @param paths 本地歌词路径数组
 * @param id 歌曲ID
 * @returns 返回一个函数，该函数接受扩展名和在线获取函数作为参数
 */
const getLyricFun =
  (paths: string[], id: number) =>
  async (
    ext: string,
    getOnline?: (id: number) => Promise<string | null>,
  ): Promise<string | null> => {
    for (const path of paths) {
      const lyric = await window.electron.ipcRenderer.invoke("read-local-lyric", path, id, ext);
      if (lyric) return lyric;
    }
    return getOnline ? await getOnline(id) : null;
  };
