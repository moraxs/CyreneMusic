<template>
  <div
    :style="{
      '--lrc-size': settingStore.lyricFontSize + 'px',
      '--lrc-tran-size': settingStore.lyricTranFontSize + 'px',
      '--lrc-roma-size': settingStore.lyricRomaFontSize + 'px',
      '--lrc-bold': settingStore.lyricFontBold ? 'bold' : 'normal',
      '--ja-font-family':
        settingStore.japaneseLyricFont !== 'follow' ? settingStore.japaneseLyricFont : '',
      'font-family': settingStore.LyricFont !== 'follow' ? settingStore.LyricFont : '',
      cursor: statusStore.playerMetaShow ? 'auto' : 'none',
    }"
    :class="[
      'lyric',
      settingStore.playerType,
      settingStore.lyricsPosition,
      { pure: statusStore.pureLyricMode },
    ]"
    @mouseenter="lrcMouseStatus = settingStore.lrcMousePause ? true : false"
    @mouseleave="lrcAllLeave"
  >
    <Transition name="fade" mode="out-in">
      <div
        :key="musicStore.songLyric.lrcData?.[0]?.content"
        class="lyric-content"
        @after-enter="lyricsScroll(statusStore.lyricIndex)"
        @after-leave="lyricsScroll(statusStore.lyricIndex)"
      >
        <n-scrollbar ref="lyricScroll" class="lyric-scroll" tabindex="-1">
          <!-- 逐字歌词 -->
          <template v-if="settingStore.showYrc && musicStore.isHasYrc">
            <div id="lrc-placeholder" class="placeholder">
              <!-- 倒计时 -->
              <CountDown
                :start="0"
                :duration="musicStore.songLyric.yrcData[0].time || 0"
                :seek="playSeek"
                :playing="statusStore.playStatus"
              />
            </div>
            <div
              v-for="(item, index) in musicStore.songLyric.yrcData"
              :key="index"
              :id="`lrc-${index}`"
              :class="[
                'lrc-line',
                'is-yrc',
                {
                  // on: statusStore.lyricIndex === index,
                  // 当播放时间大于等于当前歌词的开始时间
                  on:
                    (playSeek >= item.time && playSeek < item.endTime) ||
                    statusStore.lyricIndex === index,
                  'is-bg': item.isBG,
                  'is-duet': item.isDuet,
                },
              ]"
              :style="{
                filter: settingStore.lyricsBlur
                  ? `blur(${Math.min(Math.abs(statusStore.lyricIndex - index) * 1.8, 10)}px)`
                  : 'blur(0)',
              }"
              @click="jumpSeek(item.time)"
            >
              <!-- 歌词 -->
              <div class="content">
                <div
                  v-for="(text, textIndex) in item.contents"
                  :key="textIndex"
                  :class="{
                    'content-text': true,
                    'content-long': text.duration >= 1.5 && playSeek <= text.endTime,
                    'end-with-space': text.endsWithSpace,
                  }"
                >
                  <span class="word" :lang="getLyricLanguage(text.content)">
                    {{ text.content }}
                  </span>
                  <span
                    class="filler"
                    :style="getYrcStyle(text, index)"
                    :lang="getLyricLanguage(text.content)"
                  >
                    {{ text.content }}
                  </span>
                </div>
              </div>
              <!-- 翻译 -->
              <span v-if="item.tran && settingStore.showTran" class="tran" lang="en">
                {{ item.tran }}
              </span>
              <!-- 音译 -->
              <span v-if="item.roma && settingStore.showRoma" class="roma" lang="en">
                {{ item.roma }}
              </span>
              <!-- 间奏倒计时 -->
              <div
                v-if="
                  settingStore.countDownShow &&
                  item.time > 0 &&
                  musicStore.songLyric.yrcData[index + 1]?.time - item.endTime >= 10
                "
                class="count-down-content"
              >
                <CountDown
                  :start="item.endTime"
                  :duration="musicStore.songLyric.yrcData[index + 1]?.time - item.endTime || 0"
                  :seek="playSeek"
                  :playing="statusStore.playStatus"
                />
              </div>
            </div>
            <div class="placeholder" />
          </template>
          <!-- 普通歌词 -->
          <template v-else-if="musicStore.isHasLrc">
            <div id="lrc-placeholder" class="placeholder">
              <!-- 倒计时 -->
              <CountDown
                :start="0"
                :duration="musicStore.songLyric.lrcData[0].time || 0"
                :seek="playSeek"
                :playing="statusStore.playStatus"
              />
            </div>
            <div
              v-for="(item, index) in musicStore.songLyric.lrcData"
              :key="index"
              :id="`lrc-${index}`"
              :class="['lrc-line', 'is-lrc', { on: statusStore.lyricIndex === index }]"
              :style="{
                filter: settingStore.lyricsBlur
                  ? `blur(${Math.min(Math.abs(statusStore.lyricIndex - index) * 1.8, 10)}px)`
                  : 'blur(0)',
              }"
              @click="jumpSeek(item.time)"
            >
              <!-- 歌词 -->
              <span class="content" :lang="getLyricLanguage(item.content)">{{ item.content }}</span>
              <!-- 翻译 -->
              <span v-if="item.tran && settingStore.showTran" class="tran" lang="en">
                {{ item.tran }}
              </span>
              <!-- 音译 -->
              <span v-if="item.roma && settingStore.showRoma" class="roma" lang="en">
                {{ item.roma }}
              </span>
            </div>
            <div class="placeholder" />
          </template>
        </n-scrollbar>
      </div>
    </Transition>
    <!-- 歌词菜单组件 -->
    <LyricMenu />
  </div>
</template>

<script setup lang="ts">
import type { LyricContentType } from "@/types/main";
import { NScrollbar } from "naive-ui";
import { useMusicStore, useSettingStore, useStatusStore } from "@/stores";
import player from "@/utils/player";
import { getLyricLanguage } from "@/utils/lyric";
import LyricMenu from "./LyricMenu.vue";

const musicStore = useMusicStore();
const statusStore = useStatusStore();
const settingStore = useSettingStore();

const lrcMouseStatus = ref<boolean>(false);
const lyricScroll = ref<InstanceType<typeof NScrollbar> | null>(null);

// 实时播放进度
const playSeek = ref<number>(player.getSeek());

// 实时更新播放进度（按歌曲 id 应用偏移）
const { pause: pauseSeek, resume: resumeSeek } = useRafFn(() => {
  const songId = musicStore.playSong?.id as number | undefined;
  playSeek.value = player.getSeek() + statusStore.getSongOffset(songId);
});

// 鼠标移出歌词区域
const lrcAllLeave = () => {
  lrcMouseStatus.value = false;
  lyricsScroll(statusStore.lyricIndex);
};

// 歌词滚动
const lyricsScroll = (index: number) => {
  const lrcItemDom = document.getElementById(index >= 0 ? "lrc-" + index : "lrc-placeholder");
  if (lrcItemDom && (!lrcMouseStatus.value || statusStore.pureLyricMode)) {
    const container = lrcItemDom.parentElement;
    if (!container) return;
    // 调整滚动的距离
    const scrollDistance = lrcItemDom.offsetTop - container.offsetTop - 80;
    // 开始滚动
    if (settingStore.lyricsScrollPosition === "center") {
      lrcItemDom?.scrollIntoView({ behavior: "smooth", block: "center" });
    } else {
      lyricScroll.value?.scrollTo({ top: scrollDistance, behavior: "smooth" });
    }
  }
};

// 逐字歌词样式计算
const getYrcStyle = (wordData: LyricContentType, lyricIndex: number) => {
  if (settingStore.showYrcAnimation) {
    // 如果当前歌词索引与播放歌曲的歌词索引不匹配
    // if (statusStore.lyricIndex !== lyricIndex) {
    //   return {
    //     transitionDuration: `0ms, 0ms, 0.35s`,
    //     transitionDelay: `0ms`,
    //   };
    // }
    // 如果播放状态不是加载中，且当前单词的时间加上持续时间减去播放进度大于 0
    if (
      statusStore.playLoading === false &&
      wordData.time + wordData.duration - playSeek.value > 0
    ) {
      return {
        transitionDuration: `0s, 0s, 0.35s`,
        transitionDelay: `0ms`,
        WebkitMaskPositionX: `${
          100 - Math.max(((playSeek.value - wordData.time) / wordData.duration) * 100, 0)
        }%`,
      };
    }
    // 如果以上条件都不满足
    return {
      transitionDuration: `${wordData.duration}ms, ${wordData.duration * 0.8}ms, 0.35s`,
      transitionDelay: `${wordData.time - playSeek.value}ms, ${
        wordData.time - playSeek.value + wordData.duration * 0.5
      }ms, 0ms`,
    };
  } else {
    // 如果当前歌词索引与播放歌曲的歌词索引不匹配，或者播放状态不是加载中且当前单词的时间大于等于播放进度
    if (
      statusStore.lyricIndex !== lyricIndex ||
      (statusStore.playLoading === false && wordData.time >= playSeek.value)
    ) {
      return { opacity: 0 };
    }
    // 如果以上条件都不满足
    return { opacity: 1 };
  }
};

// 进度跳转
const jumpSeek = (time: number) => {
  if (!time) return;
  lrcMouseStatus.value = false;
  player.setSeek(time);
  player.play();
};

// 监听歌词滚动
watch(
  () => statusStore.lyricIndex,
  (val) => lyricsScroll(val),
);

onMounted(() => {
  // 恢复进度
  resumeSeek();
  nextTick().then(() => {
    lyricsScroll(statusStore.lyricIndex);
  });
});

onBeforeUnmount(() => {
  console.log("离开歌词");
  pauseSeek();
});
</script>

<style lang="scss" scoped>
.lyric {
  position: relative;
  width: 100%;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: flex-start;
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
  :deep(.n-scrollbar-rail) {
    display: none;
  }
  :deep(.n-scrollbar-content) {
    padding-left: 10px;
    padding-right: 80px;
    max-width: 100%; /* 新增：防止宽度溢出 */
    box-sizing: border-box; /* 新增：确保 padding 不影响宽度 */
  }
  .placeholder {
    width: 100%;
    &:first-child {
      height: 300px;
      display: flex;
      align-items: flex-end;
    }
    &:last-child {
      height: 0;
      padding-top: 100%;
    }
  }
  .lyric-content {
    width: 100%;
    height: 100%;
    box-sizing: border-box; /* 新增：确保宽度计算正确 */
  }
  .lrc-line {
    position: relative;
    display: flex;
    flex-direction: column;
    margin: 6px 0;
    padding: 10px 16px;
    transform: scale(0.86);
    transform-origin: left center;
    will-change: filter, opacity, transform;
    transition:
      filter 0.35s,
      opacity 0.35s,
      transform 0.5s cubic-bezier(0.25, 0.1, 0.25, 1);
    cursor: pointer;
    width: 100%;
    .content {
      display: block;
      font-size: var(--lrc-size);
      font-weight: var(--lrc-bold);
      width: 100%;
      overflow-wrap: anywhere; /* 支持超长单词换行 */
      word-break: break-word; /* 优先空格或连字符换行，超长单词强制换行 */
      white-space: normal; /* 新增：明确文本换行行为 */
      hyphens: auto; /* 英文自动连字符 */
      .content-text {
        position: relative;
        display: inline-block;
        overflow-wrap: anywhere; /* 新增：逐字歌词单词支持换行 */
        word-break: break-word; /* 新增：单词内换行 */
        white-space: normal; /* 新增：确保逐字歌词换行 */
        .word {
          opacity: 0.3;
          display: inline-block;
        }
        .filler {
          opacity: 0;
          position: absolute;
          left: 0;
          top: 0;
          transform: none;
          will-change: -webkit-mask-position-x, transform, opacity;
          mask-image: linear-gradient(
            to right,
            rgb(0, 0, 0) 45.4545454545%,
            rgba(0, 0, 0, 0) 54.5454545455%
          );
          mask-size: 220% 100%;
          mask-repeat: no-repeat;
          -webkit-mask-image: linear-gradient(
            to right,
            rgb(0, 0, 0) 45.4545454545%,
            rgba(0, 0, 0, 0) 54.5454545455%
          );
          -webkit-mask-size: 220% 100%;
          -webkit-mask-repeat: no-repeat;
          transition:
            opacity 0.3s,
            filter 0.5s,
            margin 0.3s,
            padding 0.3s !important;
        }
        &.end-with-space {
          margin-right: 12px;
          &:last-child {
            margin-right: 0;
          }
        }
        &.content-long {
          .filler {
            margin: -40px;
            padding: 40px;
            filter: drop-shadow(0px 0px 14px rgba(255, 255, 255, 0.6));
          }
        }
      }
      &:lang(ja) {
        font-family: var(--ja-font-family);
      }
    }
    .tran {
      margin-top: 8px;
      opacity: 0.6;
      font-size: var(--lrc-tran-size);
      transition: opacity 0.35s;
      width: 100%;
      overflow-wrap: anywhere; /* 支持超长单词换行 */
      word-break: break-word; /* 优先空格或连字符换行，超长单词强制换行 */
      white-space: normal; /* 新增：明确文本换行行为 */
      hyphens: auto; /* 英文自动连字符 */
    }
    .roma {
      margin-top: 4px;
      opacity: 0.5;
      font-size: var(--lrc-roma-size);
      transition: opacity 0.35s;
      width: 100%;
      overflow-wrap: anywhere; /* 支持超长单词换行 */
      word-break: break-word; /* 优先空格或连字符换行，超长单词强制换行 */
      white-space: normal; /* 新增：明确文本换行行为 */
      hyphens: auto; /* 英文自动连字符 */
    }
    .count-down-content {
      height: 50px;
      margin-top: 40px;
    }
    .count-down {
      transform-origin: left;
      justify-content: flex-end;
    }
    &.is-lrc {
      opacity: 0.3;
    }
    &.is-yrc {
      .content {
        display: flex;
        flex-wrap: wrap;
        width: 100%;
        overflow-wrap: anywhere; /* 逐字歌词支持超长单词换行 */
        word-break: break-word; /* 优先空格或连字符换行 */
        white-space: normal; /* 确保换行行为 */
      }
      .tran,
      .roma {
        opacity: 0.3;
      }
      &.is-bg {
        opacity: 0.4;
        transform: scale(0.7);
        padding: 0px 20px;
      }
      &.is-duet {
        transform-origin: right;
        .content,
        .tran,
        .roma {
          text-align: right;
          justify-content: flex-end;
        }
      }
    }
    &.on {
      opacity: 1 !important;
      transform: scale(1);
      .content-text {
        .filler {
          opacity: 1;
          -webkit-mask-position-x: 0%;
          transition-property: -webkit-mask-position-x, transform, opacity;
          transition-timing-function: linear, ease, ease;
        }
      }
      .tran,
      .roma {
        opacity: 0.6;
      }
      &.is-bg {
        opacity: 0.85 !important;
      }
    }
    &::before {
      content: "";
      display: block;
      position: absolute;
      left: 0px;
      top: 0;
      width: 100%;
      height: 100%;
      border-radius: 8px;
      background-color: rgba(var(--main-color), 0.14);
      opacity: 0;
      z-index: 0;
      transform: scale(1.05);
      transition:
        transform 0.35s ease,
        opacity 0.35s ease;
      pointer-events: none;
    }
    &:hover {
      opacity: 1;
      &::before {
        transform: scale(1);
        opacity: 1;
      }
    }
    &:active {
      &::before {
        transform: scale(0.95);
      }
    }
  }
  &.flex-end {
    span {
      text-align: right;
    }
    .placeholder {
      justify-content: flex-end;
    }
    .lrc-line {
      transform-origin: right;
      .content {
        text-align: right;
      }
      .count-down {
        transform-origin: right;
        justify-content: flex-end;
      }
    }
  }
  &.center,
  &.pure {
    span {
      text-align: center !important;
    }
    .placeholder {
      justify-content: center !important;
    }
    .lrc-line {
      transform-origin: center !important;
      .content {
        text-align: center !important;
        justify-content: center !important;
      }
      .count-down {
        transform-origin: center;
        justify-content: center;
      }
    }
  }
  &.pure {
    :deep(.n-scrollbar-content) {
      padding: 0 80px;
      max-width: 100%; /* 新增：防止宽度溢出 */
      box-sizing: border-box; /* 新增：确保 padding 不影响宽度 */
    }
    .lyric-content {
      .placeholder {
        &:first-child {
          height: 100px;
        }
      }
      .lrc-line {
        margin-bottom: -12px;
        transform: scale(0.76);
        &.on {
          transform: scale(0.9);
        }
      }
    }
  }
  &:hover {
    .lrc-line {
      filter: blur(0) !important;
    }
  }
}
</style>
