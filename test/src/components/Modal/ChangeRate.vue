<template>
  <n-flex align="center" size="large" vertical>
    <n-flex align="center" justify="center">
      <n-tag
        v-for="(item, index) in [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2]"
        :type="statusStore.playRate === item ? 'primary' : 'default'"
        :bordered="statusStore.playRate === item"
        :key="index"
        size="large"
        round
        @click="player.setRate(item)"
      >
        {{ item }}x
      </n-tag>
    </n-flex>
    <n-text :depth="3"> 当前播放速度： {{ statusStore.playRate }}x </n-text>
    <n-slider
      v-model:value="statusStore.playRate"
      :step="0.1"
      :min="0.2"
      :max="2"
      :tooltip="false"
      :marks="{
        0.2: '0.2x',
        1: '1x',
        2: '2x',
      }"
      @update:value="(value) => player.setRate(value)"
    />
  </n-flex>
</template>

<script setup lang="ts">
import { useStatusStore } from "@/stores";
import player from "@/utils/player";

const statusStore = useStatusStore();
</script>
