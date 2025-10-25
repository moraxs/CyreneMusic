import { LyricLine, parseLrc, parseTTML, parseYrc, TTMLLyric } from "@applemusic-like-lyrics/lyric";
import type { LyricType } from "@/types/main";
import { useMusicStore, useSettingStore, useStatusStore } from "@/stores";
import { msToS } from "./time";

// 歌词排除内容
const getExcludeKeywords = () => {
  const settingStore = useSettingStore();
  // 如果未启用排除功能，返回空数组
  if (!settingStore.enableExcludeKeywords) return [];
  return settingStore.excludeKeywords;
};

// 恢复默认
export const resetSongLyric = () => {
  const musicStore = useMusicStore();
  const statusStore = useStatusStore();
  musicStore.songLyric = {
    lrcData: [],
    lrcAMData: [],
    yrcData: [],
    yrcAMData: [],
  };
  statusStore.usingTTMLLyric = false;
};

// 解析歌词数据
export const parsedLyricsData = (lyricData: any) => {
  const musicStore = useMusicStore();
  if (lyricData.code !== 200) {
    resetSongLyric();
    return;
  }
  let lrcData: LyricType[] = [];
  let yrcData: LyricType[] = [];
  // 处理后歌词
  let lrcParseData: LyricLine[] = [];
  let tlyricParseData: LyricLine[] = [];
  let romalrcParseData: LyricLine[] = [];
  let yrcParseData: LyricLine[] = [];
  let ytlrcParseData: LyricLine[] = [];
  let yromalrcParseData: LyricLine[] = [];
  // 普通歌词
  if (lyricData?.lrc?.lyric) {
    lrcParseData = parseLrc(lyricData.lrc.lyric);
    lrcData = parseLrcData(lrcParseData);
    // 其他翻译
    if (lyricData?.tlyric?.lyric) {
      tlyricParseData = parseLrc(lyricData.tlyric.lyric);
      lrcData = alignLyrics(lrcData, parseLrcData(tlyricParseData), "tran");
    }
    if (lyricData?.romalrc?.lyric) {
      romalrcParseData = parseLrc(lyricData.romalrc.lyric);
      lrcData = alignLyrics(lrcData, parseLrcData(romalrcParseData), "roma");
    }
  }
  // 逐字歌词
  if (lyricData?.yrc?.lyric) {
    yrcParseData = parseYrc(lyricData.yrc.lyric);
    yrcData = parseYrcData(yrcParseData);
    // 其他翻译
    if (lyricData?.ytlrc?.lyric) {
      ytlrcParseData = parseLrc(lyricData.ytlrc.lyric);
      yrcData = alignLyrics(yrcData, parseLrcData(ytlrcParseData), "tran");
    }
    if (lyricData?.yromalrc?.lyric) {
      yromalrcParseData = parseLrc(lyricData.yromalrc.lyric);
      yrcData = alignLyrics(yrcData, parseLrcData(yromalrcParseData), "roma");
    }
  }
  musicStore.songLyric = {
    lrcData,
    yrcData,
    lrcAMData: parseAMData(lrcParseData, tlyricParseData, romalrcParseData),
    yrcAMData: parseAMData(yrcParseData, ytlrcParseData, yromalrcParseData),
  };
};

// 解析普通歌词
export const parseLrcData = (lrcData: LyricLine[]): LyricType[] => {
  if (!lrcData) return [];
  // 数据处理
  const lrcList = lrcData
    .map((line) => {
      const words = line.words;
      const time = msToS(words[0].startTime);
      const content = words[0].word.trim();
      // 排除内容
      if (!content || getExcludeKeywords().some((keyword) => content.includes(keyword))) {
        return null;
      }
      return {
        time,
        content,
      };
    })
    .filter((line): line is LyricType => line !== null);
  // 筛选出非空数据并返回
  return lrcList;
};

// 解析逐字歌词
export const parseYrcData = (yrcData: LyricLine[]): LyricType[] => {
  if (!yrcData) return [];
  // 数据处理
  const yrcList = yrcData
    .map((line) => {
      const words = line.words;
      const time = msToS(words[0].startTime);
      const endTime = msToS(words[words.length - 1].endTime);
      const contents = words.map((word) => {
        return {
          time: msToS(word.startTime),
          endTime: msToS(word.endTime),
          duration: msToS(word.endTime - word.startTime),
          content: word.word.trim(),
          endsWithSpace: word.word.endsWith(" "),
        };
      });
      // 完整歌词
      const contentStr = contents
        .map((word) => word.content + (word.endsWithSpace ? " " : ""))
        .join("");
      // 排除内容
      if (!contentStr || getExcludeKeywords().some((keyword) => contentStr.includes(keyword))) {
        return null;
      }
      return {
        time,
        endTime,
        content: contentStr,
        contents,
      };
    })
    .filter((line): line is LyricType => line !== null);
  return yrcList;
};

// 歌词内容对齐
export const alignLyrics = (
  lyrics: LyricType[],
  otherLyrics: LyricType[],
  key: "tran" | "roma",
): LyricType[] => {
  const lyricsData = lyrics;
  if (lyricsData.length && otherLyrics.length) {
    lyricsData.forEach((v: LyricType) => {
      otherLyrics.forEach((x: LyricType) => {
        if (v.time === x.time || Math.abs(v.time - x.time) < 0.6) {
          v[key] = x.content;
        }
      });
    });
  }
  return lyricsData;
};
export const alignAMLyrics = (
  lyrics: LyricLine[],
  otherLyrics: LyricLine[],
  key: "translatedLyric" | "romanLyric",
): LyricLine[] => {
  const lyricsData = lyrics;
  if (lyricsData.length && otherLyrics.length) {
    lyricsData.forEach((v: LyricLine) => {
      otherLyrics.forEach((x: LyricLine) => {
        if (v.startTime === x.startTime || Math.abs(v.startTime - x.startTime) < 0.6) {
          v[key] = x.words.map((word) => word.word).join("");
        }
      });
    });
  }
  return lyricsData;
};

// 处理本地歌词
export const parseLocalLyric = (lyric: string, format: "lrc" | "ttml") => {
  const statusStore = useStatusStore();

  if (!lyric) {
    resetSongLyric();
    return;
  }
  switch (format) {
    case "lrc":
      parseLocalLyricLrc(lyric);
      statusStore.usingTTMLLyric = false;
      break;
    case "ttml":
      parseLocalLyricAM(lyric);
      statusStore.usingTTMLLyric = true;
      break;
  }
};

/**
 * 解析本地LRC歌词
 * @param lyric LRC格式的歌词内容
 */
const parseLocalLyricLrc = (lyric: string) => {
  const musicStore = useMusicStore();
  // 解析
  const lrc: LyricLine[] = parseLrc(lyric);
  const lrcData: LyricType[] = parseLrcData(lrc);
  // 处理结果
  const lrcDataParsed: LyricType[] = [];
  // 翻译提取
  for (let i = 0; i < lrcData.length; i++) {
    // 当前歌词
    const lrcItem = lrcData[i];
    // 是否具有翻译
    const existingObj = lrcDataParsed.find((v) => v.time === lrcItem.time);
    if (existingObj) {
      existingObj.tran = lrcItem.content;
    } else {
      lrcDataParsed.push(lrcItem);
    }
  }
  // 更新歌词
  musicStore.songLyric = {
    lrcData: lrcDataParsed,
    lrcAMData: lrcDataParsed.map((line, index, lines) => ({
      words: [{ startTime: line.time, endTime: 0, word: line.content }],
      startTime: line.time * 1000,
      endTime: lines[index + 1]?.time * 1000,
      translatedLyric: line.tran ?? "",
      romanLyric: line.roma ?? "",
      isBG: false,
      isDuet: false,
    })),
    yrcData: [],
    yrcAMData: [],
  };
};

/**
 * 解析本地AM歌词
 * @param lyric AM格式的歌词内容
 */
const parseLocalLyricAM = (lyric: string) => {
  const musicStore = useMusicStore();
  const ttml = parseTTML(lyric);
  const yrcAMData = parseTTMLToAMLL(ttml);
  const yrcData = parseTTMLToYrc(ttml);
  musicStore.songLyric = {
    lrcData: yrcData,
    lrcAMData: yrcAMData,
    yrcAMData,
    yrcData,
  };
};

// 处理 AM 歌词
const parseAMData = (lrcData: LyricLine[], tranData?: LyricLine[], romaData?: LyricLine[]) => {
  let lyricData = lrcData
    .map((line, index, lines) => {
      // 获取歌词文本内容
      const content = line.words
        .map((word) => word.word)
        .join("")
        .trim();
      // 排除包含关键词的内容
      if (!content || getExcludeKeywords().some((keyword) => content.includes(keyword))) {
        return null;
      }
      return {
        words: line.words,
        startTime: line.words[0]?.startTime ?? 0,
        endTime:
          lines[index + 1]?.words?.[0]?.startTime ??
          line.words?.[line.words.length - 1]?.endTime ??
          Infinity,
        translatedLyric: "",
        romanLyric: "",
        isBG: line.isBG ?? false,
        isDuet: line.isDuet ?? false,
      };
    })
    .filter((line): line is NonNullable<typeof line> => line !== null);
  if (tranData) {
    lyricData = alignAMLyrics(lyricData, tranData, "translatedLyric");
  }
  if (romaData) {
    lyricData = alignAMLyrics(lyricData, romaData, "romanLyric");
  }
  return lyricData;
};

/**
 * 从TTML格式解析歌词并转换为AMLL格式
 * @param ttmlContent TTML格式的歌词内容
 * @returns AMLL格式的歌词行数组
 */
export const parseTTMLToAMLL = (ttmlContent: TTMLLyric): LyricLine[] => {
  if (!ttmlContent) return [];

  try {
    const validLines = ttmlContent.lines
      .filter((line) => line && typeof line === "object" && Array.isArray(line.words))
      .map((line) => {
        const words = line.words
          .filter((word) => word && typeof word === "object")
          .map((word) => ({
            word: String(word.word || " "),
            startTime: Number(word.startTime) || 0,
            endTime: Number(word.endTime) || 0,
          }));

        if (!words.length) return null;

        // 获取歌词文本内容
        const content = words
          .map((word) => word.word)
          .join("")
          .trim();
        // 排除包含关键词的内容
        if (!content || getExcludeKeywords().some((keyword) => content.includes(keyword))) {
          return null;
        }

        const startTime = words[0].startTime;
        const endTime = words[words.length - 1].endTime;

        return {
          words,
          startTime,
          endTime,
          translatedLyric: String(line.translatedLyric || ""),
          romanLyric: String(line.romanLyric || ""),
          isBG: Boolean(line.isBG),
          isDuet: Boolean(line.isDuet),
        };
      })
      .filter((line): line is LyricLine => line !== null);

    return validLines;
  } catch (error) {
    console.error("TTML parsing error:", error);
    return [];
  }
};

/**
 * 从TTML格式解析歌词并转换为默认Yrc格式
 * @param ttmlContent TTML格式的歌词内容
 * @returns 默认Yrc格式的歌词行数组
 */
export const parseTTMLToYrc = (ttmlContent: TTMLLyric): LyricType[] => {
  if (!ttmlContent) return [];

  try {
    // 数据处理
    const yrcList = ttmlContent.lines
      .map((line) => {
        const words = line.words;
        const time = msToS(words[0].startTime);
        const endTime = msToS(words[words.length - 1].endTime);
        const contents = words.map((word) => {
          return {
            time: msToS(word.startTime),
            endTime: msToS(word.endTime),
            duration: msToS(word.endTime - word.startTime),
            content: word.word.trim(),
            endsWithSpace: word.word.endsWith(" "),
          };
        });
        // 完整歌词
        const contentStr = contents
          .map((word) => word.content + (word.endsWithSpace ? " " : ""))
          .join("");
        // 排除内容
        if (!contentStr || getExcludeKeywords().some((keyword) => contentStr.includes(keyword))) {
          return null;
        }
        return {
          time,
          endTime,
          content: contentStr,
          contents,
          tran: line.translatedLyric || "",
          roma: line.romanLyric || "",
          isBG: line.isBG,
          isDuet: line.isDuet,
        };
      })
      .filter((line) => line !== null);
    return yrcList;
  } catch (error) {
    console.error("TTML parsing to yrc error:", error);
    return [];
  }
};

// 检测语言
export const getLyricLanguage = (lyric: string): string => {
  // 判断日语 根据平假名和片假名
  if (/[\u3040-\u309f\u30a0-\u30ff]/.test(lyric)) return "ja";
  // 判断简体中文 根据中日韩统一表意文字基本区
  if (/[\u4e00-\u9fa5]/.test(lyric)) return "zh-CN";
  // 默认英语
  return "en";
};

/**
 * 计算歌词索引
 * - 普通歌词(LRC)：沿用当前按开始时间定位的算法
 * - 逐字歌词(YRC)：当播放时间位于某句 [time, endTime) 区间内时，索引为该句；
 *   若下一句开始时间落在上一句区间（对唱重叠），仍保持上一句索引，直到上一句结束。
 */
export const calculateLyricIndex = (
  currentTime: number,
): { index: number; lyrics: LyricType[] } => {
  const musicStore = useMusicStore();
  const statusStore = useStatusStore();
  const settingStore = useSettingStore();
  // 应用实时偏移（按歌曲 id 记忆） + 0.3s（解决对唱时歌词延迟问题）
  const songId = musicStore.playSong?.id as number | undefined;
  const playSeek = currentTime + statusStore.getSongOffset(songId) + 0.3;
  // 选择歌词类型
  const useYrc = !!(settingStore.showYrc && musicStore.songLyric.yrcData.length);
  const lyrics = useYrc ? musicStore.songLyric.yrcData : musicStore.songLyric.lrcData;
  // 无歌词时
  if (!lyrics || !lyrics.length) return { index: -1, lyrics: [] };

  // 普通歌词：保持原有计算方式
  if (!useYrc) {
    const idx = lyrics.findIndex((v) => (v?.time ?? 0) >= playSeek);
    const index = idx === -1 ? lyrics.length - 1 : idx - 1;
    return { index, lyrics };
  }

  // 逐字歌词（并发最多三句同时存在）：
  // - 计算在播放进度下处于激活区间的句子集合 activeIndices（[time, endTime)）
  // - 若激活数 >= 3，仅保留最后三句作为并发显示（允许三句同时有效）；否则保持最后两句
  // - 索引取该并发集合中较早的一句（保持“上一句”高亮）
  // - 若无激活句：首句之前返回 -1；否则回退到最近一句

  const firstStart = lyrics[0]?.time ?? 0;
  if (playSeek < firstStart) {
    return { index: -1, lyrics };
  }

  const activeIndices: number[] = [];
  for (let i = 0; i < lyrics.length; i++) {
    const start = lyrics[i]?.time ?? 0;
    const end = lyrics[i]?.endTime ?? Infinity;
    if (playSeek >= start && playSeek < end) {
      activeIndices.push(i);
    }
  }

  if (activeIndices.length === 0) {
    // 不在任何句子的区间里：退回到最近一句（按开始时间）
    const nextIdx = lyrics.findIndex((v) => (v?.time ?? 0) > playSeek);
    const index = nextIdx === -1 ? lyrics.length - 1 : nextIdx - 1;
    return { index, lyrics };
  }

  if (activeIndices.length === 1) {
    return { index: activeIndices[0], lyrics };
  }

  // 激活句 >= 2：如果达到三句或更多，限制为最后三句并发；否则保持最后两句
  const concurrent = activeIndices.length >= 3 ? activeIndices.slice(-3) : activeIndices.slice(-2);
  return { index: concurrent[0], lyrics };
};
