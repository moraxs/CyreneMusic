<template>
  <Transition>
    <div
      :key="amLyricsData?.[0]?.startTime"
      :class="['lyric-am', { pure: statusStore.pureLyricMode }]"
    >
      <LyricPlayer
        ref="lyricPlayerRef"
        :lyricLines="amLyricsData"
        :currentTime="playSeek"
        :playing="statusStore.playStatus"
        :enableSpring="settingStore.useAMSpring"
        :enableScale="settingStore.useAMSpring"
        :alignPosition="settingStore.lyricsScrollPosition === 'center' ? 0.5 : 0.2"
        :enableBlur="settingStore.lyricsBlur"
        :style="{
          '--amll-lyric-view-color': mainColor,
          '--amll-lyric-player-font-size': settingStore.lyricFontSize + 'px',
          '--ja-font-family':
            settingStore.japaneseLyricFont !== 'follow' ? settingStore.japaneseLyricFont : '',
          'font-weight': settingStore.lyricFontBold ? 'bold' : 'normal',
          'font-family': settingStore.LyricFont !== 'follow' ? settingStore.LyricFont : '',
        }"
        class="am-lyric"
        @line-click="jumpSeek"
      />
      <!-- 歌词菜单组件 -->
      <LyricMenu />
    </div>
  </Transition>
</template>

<script setup lang="ts">
import { LyricPlayer } from "@applemusic-like-lyrics/vue";
import { LyricLine } from "@applemusic-like-lyrics/core";
import { useMusicStore, useSettingStore, useStatusStore } from "@/stores";
import { msToS } from "@/utils/time";
import { getLyricLanguage } from "@/utils/lyric";
import player from "@/utils/player";
import { watch } from "vue";
import LyricMenu from "./LyricMenu.vue";

const musicStore = useMusicStore();
const statusStore = useStatusStore();
const settingStore = useSettingStore();

const lyricPlayerRef = ref<any | null>(null);

// 实时播放进度
const playSeek = ref<number>(player.getSeek());

// 实时更新播放进度
const { pause: pauseSeek, resume: resumeSeek } = useRafFn(() => {
  const seekInSeconds = player.getSeek();
  playSeek.value = Math.floor(seekInSeconds * 1000);
});

// 歌词主色
const mainColor = computed(() => {
  if (!statusStore.mainColor) return "rgb(239, 239, 239)";
  return `rgb(${statusStore.mainColor})`;
});

// 检查是否为纯音乐歌词
const isPureInstrumental = (lyrics: LyricLine[]): boolean => {
  if (!lyrics || lyrics.length === 0) return false;
  const instrumentalKeywords = ["纯音乐", "instrumental", "请欣赏"];

  if (lyrics.length === 1) {
    const content = lyrics[0].words?.[0]?.word || "";
    return instrumentalKeywords.some((keyword) =>
      content.toLowerCase().includes(keyword.toLowerCase()),
    );
  }

  if (lyrics.length <= 3) {
    const allContent = lyrics.map((line) => line.words?.[0]?.word || "").join("");
    return instrumentalKeywords.some((keyword) =>
      allContent.toLowerCase().includes(keyword.toLowerCase()),
    );
  }
  return false;
};

// 当前歌词
const amLyricsData = computed<LyricLine[]>(() => {
  const { songLyric } = musicStore;
  if (!songLyric) return [];

  // 优先使用逐字歌词(YRC/TTML)
  const useYrc = songLyric.yrcAMData?.length && settingStore.showYrc;
  const lyrics = useYrc ? songLyric.yrcAMData : songLyric.lrcAMData;

  // 简单检查歌词有效性
  if (!Array.isArray(lyrics) || lyrics.length === 0) return [];

  // 检查是否为纯音乐
  if (isPureInstrumental(lyrics)) return [];

  return lyrics;
});

// 进度跳转
const jumpSeek = (line: any) => {
  if (!line?.line?.lyricLine?.startTime) return;
  const time = msToS(line.line.lyricLine.startTime);
  player.setSeek(time);
  player.play();
};

// 处理歌词语言
const processLyricLanguage = () => {
  const lyricLinesEl = lyricPlayerRef.value?.lyricPlayer?.lyricLinesEl ?? [];
  // 遍历歌词行
  for (let e of lyricLinesEl) {
    // 获取歌词行内容 (合并逐字歌词为一句)
    const content = e.lyricLine.words.map((word: any) => word.word).join("");
    // 获取歌词语言
    const lang = getLyricLanguage(content);
    // 为主歌词设置 lang 属性 (firstChild 获取主歌词 不为翻译和音译设置属性)
    e.element.firstChild.setAttribute("lang", lang);
  }
};

// 切换歌曲时处理歌词语言
watch(amLyricsData, () => {
  nextTick(() => processLyricLanguage());
});

onMounted(() => {
  // 恢复进度
  resumeSeek();
  // 处理歌词语言
  nextTick(() => processLyricLanguage());
});

onBeforeUnmount(() => {
  pauseSeek();
});
</script>

<style lang="scss" scoped>
.lyric-am {
  position: relative;
  width: 100%;
  height: 100%;
  overflow: hidden;
  filter: drop-shadow(0px 4px 6px rgba(0, 0, 0, 0.2));
  mask: linear-gradient(
    180deg,
    hsla(0, 0%, 100%, 0) 0,
    hsla(0, 0%, 100%, 0.6) 5%,
    #fff 10%,
    #fff 75%,
    hsla(0, 0%, 100%, 0.6) 85%,
    hsla(0, 0%, 100%, 0)
  );

  :deep(.am-lyric) {
    width: 100%;
    height: 100%;
    position: absolute;
    left: 0;
    top: 0;
    padding-left: 10px;
    padding-right: 80px;
    // margin-left: -2rem;
  }

  &.pure {
    text-align: center;

    :deep(.am-lyric) {
      margin: 0;
      padding: 0 80px;

      div {
        transform-origin: center;
      }
    }
  }

  :lang(ja) {
    font-family: var(--ja-font-family);
  }
}
</style>
