<template>
  <div class="exclude">
    <n-alert :show-icon="false">请勿添加过多，以免影响歌词的正常显示</n-alert>
    <n-dynamic-tags v-model:value="settingStore.excludeKeywords" />
  </div>
</template>

<script setup lang="ts">
import { useSettingStore } from "@/stores";

const settingStore = useSettingStore();
</script>

<style lang="scss" scoped>
.exclude {
  .n-alert {
    margin-bottom: 20px;
  }
}
</style>
