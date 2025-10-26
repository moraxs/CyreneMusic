import { songUrl, unlockSongUrl } from "@/api/song";
import { useDataStore, useMusicStore, useSettingStore, useStatusStore } from "@/stores";
import type { SongType } from "@/types/main";
import { isElectron } from "../helper";
import { getCoverColorData } from "../color";

/**
 * 获取当前播放歌曲
 * @returns 当前播放歌曲
 */
export const getPlaySongData = (): SongType | null => {
  const dataStore = useDataStore();
  const musicStore = useMusicStore();
  const statusStore = useStatusStore();
  // 若为私人FM
  if (statusStore.personalFmMode) {
    return musicStore.personalFMSong;
  }
  // 播放列表
  const playlist = dataStore.playList;
  if (!playlist.length) return null;
  return playlist[statusStore.playIndex];
};

/**
 * 获取播放信息
 * @param song 歌曲
 * @param sep 分隔符
 * @returns 播放信息
 */
export const getPlayerInfo = (song?: SongType, sep: string = "/"): string | null => {
  const playSongData = song || getPlaySongData();
  if (!playSongData) return null;
  // 标题
  const title = `${playSongData.name || "未知歌曲"}`;
  // 歌手
  const artist =
    playSongData.type === "radio"
      ? "播客电台"
      : Array.isArray(playSongData.artists)
        ? playSongData.artists.map((artists: { name: string }) => artists.name).join(sep)
        : String(playSongData?.artists || "未知歌手");
  return `${title} - ${artist}`;
};

/**
 * 获取在线播放链接
 * @param id 歌曲id
 * @returns { url, isTrial } 播放链接与是否为试听
 */
export const getOnlineUrl = async (
  id: number,
): Promise<{ url: string | null; isTrial: boolean }> => {
  const settingStore = useSettingStore();
  const res = await songUrl(id, settingStore.songLevel);
  console.log(`🌐 ${id} music data:`, res);
  const songData = res.data?.[0];
  // 是否有播放地址
  if (!songData || !songData?.url) return { url: null, isTrial: false };
  // 是否仅能试听
  const isTrial = songData?.freeTrialInfo !== null;
  // 返回歌曲地址
  // 客户端直接返回，网页端转 https, 并转换url以便解决音乐链接cors问题
  const normalizedUrl = isElectron
    ? songData.url
    : songData.url
        .replace(/^http:/, "https:")
        .replace(/m804\.music\.126\.net/g, "m801.music.126.net")
        .replace(/m704\.music\.126\.net/g, "m701.music.126.net");
  // 若为试听且未开启试听播放，则将 url 置为空，仅标记为试听
  const finalUrl = isTrial && !settingStore.playSongDemo ? null : normalizedUrl;
  console.log(`🎧 ${id} music url:`, finalUrl);
  return { url: finalUrl, isTrial };
};

/**
 * 获取解锁播放链接
 * @param songData 歌曲数据
 * @returns
 */
export const getUnlockSongUrl = async (songData: SongType): Promise<string | null> => {
  try {
    const songId = songData.id;
    const artist = Array.isArray(songData.artists) ? songData.artists[0].name : songData.artists;
    const keyWord = songData.name + "-" + artist;
    if (!songId || !keyWord) return null;
    // 尝试解锁
    const results = await Promise.allSettled([
      unlockSongUrl(songId, keyWord, "netease"),
      unlockSongUrl(songId, keyWord, "kuwo"),
    ]);
    // 解析结果
    const [neteaseRes, kuwoRes] = results;
    if (
      neteaseRes.status === "fulfilled" &&
      neteaseRes.value.code === 200 &&
      neteaseRes.value.url
    ) {
      return neteaseRes.value.url;
    }
    if (kuwoRes.status === "fulfilled" && kuwoRes.value.code === 200 && kuwoRes.value.url) {
      return kuwoRes.value.url;
    }
    return null;
  } catch (error) {
    console.error("Error in getUnlockSongUrl", error);
    return null;
  }
};

/**
 * 获取歌曲封面颜色数据
 * @param coverUrl 歌曲封面地址
 */
export const getCoverColor = async (coverUrl: string) => {
  if (!coverUrl) return;
  const statusStore = useStatusStore();
  // 创建图像元素
  const image = new Image();
  image.crossOrigin = "Anonymous";
  image.src = coverUrl;
  // 图像加载完成
  image.onload = () => {
    // 获取图片数据
    const coverColorData = getCoverColorData(image);
    if (coverColorData) statusStore.songCoverTheme = coverColorData;
    // 移除元素
    image.remove();
  };
};
