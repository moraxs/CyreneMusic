<template>
  <n-flex class="menu" justify="center" vertical>
    <div class="menu-icon" @click="changeOffset(-0.5)">
      <SvgIcon name="Replay5" />
    </div>
    <span class="time" @click="resetOffset()">
      {{ currentTimeOffsetValue }}
    </span>
    <div class="menu-icon" @click="changeOffset(0.5)">
      <SvgIcon name="Forward5" />
    </div>
    <div class="divider" />
    <div class="menu-icon" @click="openSetting('lyrics')">
      <SvgIcon name="Settings" />
    </div>
  </n-flex>
</template>

<script setup lang="ts">
import { useMusicStore, useStatusStore } from "@/stores";
import { openSetting } from "@/utils/modal";

const musicStore = useMusicStore();
const statusStore = useStatusStore();

/**
 * 当前歌曲 id
 */
const currentSongId = computed(() => musicStore.playSong?.id as number | undefined);

/**
 * 当前进度偏移值
 */
const currentTimeOffsetValue = computed(() => {
  const currentTimeOffset = statusStore.getSongOffset(currentSongId.value);
  return currentTimeOffset > 0 ? `+${currentTimeOffset}` : currentTimeOffset;
});

/**
 * 改变进度偏移
 * @param delta 偏移量
 */
const changeOffset = (delta: number) => {
  statusStore.incSongOffset(currentSongId.value, delta);
};

/**
 * 重置进度偏移
 */
const resetOffset = () => {
  statusStore.resetSongOffset(currentSongId.value);
};
</script>

<style lang="scss" scoped>
.menu {
  position: absolute;
  top: 0;
  right: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: space-between;
  height: 100%;
  width: 80px;
  padding: 20% 0;
  opacity: 0;
  transition: opacity 0.3s;
  .divider {
    height: 2px;
    width: 40px;
    background-color: rgba(var(--main-color), 0.12);
  }
  .time {
    width: 40px;
    margin: 8px 0;
    padding: 4px 0;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 12px;
    background-color: rgba(var(--main-color), 0.14);
    backdrop-filter: blur(10px);
    border-radius: 8px;
    border: 1px solid rgba(var(--main-color), 0.12);
    transition: background-color 0.3s;
    cursor: pointer;
    &::after {
      content: "s";
      margin-left: 2px;
    }
    &:hover {
      background-color: rgba(var(--main-color), 0.28);
    }
  }
  .menu-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 6px;
    border-radius: 8px;
    transition:
      background-color 0.3s,
      transform 0.3s;
    cursor: pointer;
    .n-icon {
      font-size: 30px;
      color: rgb(var(--main-color));
    }
    &:hover {
      transform: scale(1.1);
      background-color: rgba(var(--main-color), 0.14);
    }
    &:active {
      transform: scale(1);
    }
  }
}

.lyric,
.lyric-am {
  &:hover {
    .menu {
      opacity: 0.6;
    }
  }
}
</style>
