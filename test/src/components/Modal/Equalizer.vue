<template>
  <n-flex class="equalizer" size="large" vertical>
    <n-alert :show-icon="false"> 实验性功能，请谨慎使用 </n-alert>
    <n-flex align="center" justify="space-between" :size="8">
      <n-flex wrap :size="8" class="eq-presets">
        <n-tag
          v-for="(preset, key) in presetList"
          :key="key"
          :type="currentPreset === key ? 'primary' : 'default'"
          :bordered="currentPreset === key"
          :disabled="!enabled"
          round
          @click="applyPreset(key as PresetKey)"
        >
          {{ preset.label }}
        </n-tag>
      </n-flex>
      <n-switch v-model:value="enabled" :round="false" :disabled="!isElectron" />
    </n-flex>

    <div class="eq-sliders">
      <div v-for="(freq, i) in freqLabels" :key="freq" class="eq-col">
        <div class="eq-freq">{{ freq }}</div>
        <n-slider
          v-model:value="bands[i]"
          :min="-12"
          :max="12"
          :step="0.1"
          :disabled="!enabled || !isElectron"
          vertical
          @update:value="onBandChange(i, $event)"
        />
        <div class="eq-value">{{ formatDb(bands[i]) }}</div>
      </div>
    </div>
  </n-flex>
</template>

<script setup lang="ts">
import { isElectron } from "@/utils/helper";
import { useStatusStore } from "@/stores";
import player from "@/utils/player";

const statusStore = useStatusStore();

type PresetKey = keyof typeof presetList;

// 10 段中心频率
const frequencies = [31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];

// 频率文本
const freqLabels = frequencies.map((f) => (f >= 1000 ? `${f / 1000}kHz` : `${f}Hz`));

// 预设（单位 dB），范围建议在 [-12, 12]
const presetList = {
  acoustic: { label: "原声", bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] },
  pop: { label: "流行", bands: [-1, -1, 0, 2, 4, 4, 2, 1, -1, 1] },
  dance: { label: "舞曲", bands: [4, 6, 7, 0, 2, 3, 5, 4, 3, 0] },
  rock: { label: "摇滚", bands: [5, 3, 3, 1, 0, -1, 0, 2, 3, 5] },
  classical: { label: "古典", bands: [5, 4, 3, 2, -1, -1, 0, 2, 3, 5] },
  jazz: { label: "爵士", bands: [3, 3, 2, 2, -1, -1, 0, 2, 2, 5] },
  vocal: { label: "人声", bands: [-2, -1, 0, 2, 4, 4, 2, 0, -1, -2] },
  bass: { label: "重低音", bands: [6, 6, 8, 2, 0, 0, 0, 0, 0, 0] },
  custom: { label: "自定义", bands: [] as number[] },
} as const;

const enabled = ref<boolean>(statusStore.eqEnabled);

// 当前预设
const currentPreset = ref<PresetKey>((statusStore.eqPreset as PresetKey) || "custom");

// 当前频段
const bands = ref<number[]>(
  statusStore.eqBands?.length === 10 ? [...statusStore.eqBands] : Array(10).fill(0),
);

/** 格式化 dB 文本 */
const formatDb = (v: number) => `${v >= 0 ? "+" : ""}${v}dB`;

/**
 * 应用预设
 */
const applyPreset = (key: PresetKey) => {
  if (!enabled.value) return;
  currentPreset.value = key;
  statusStore.setEqPreset(key);
  // 自定义不覆盖当前频段
  if (key !== "custom") {
    const arr = presetList[key].bands;
    bands.value = [...arr];
    statusStore.setEqBands(bands.value);
    if (enabled.value) player.updateEq({ bands: bands.value });
  }
};

/**
 * 根据当前开关状态应用/移除 EQ
 */
const applyEq = () => {
  if (!isElectron) return;
  statusStore.setEqEnabled(enabled.value);
  statusStore.setEqBands(bands.value);
  if (enabled.value) {
    player.enableEq({ bands: bands.value, frequencies });
  } else {
    player.disableEq();
  }
};

/**
 * 单段变更处理：实时更新 EQ
 */
const onBandChange = (index: number, value: number) => {
  bands.value[index] = value;
  statusStore.setEqBands(bands.value);
  // 任何手动拖动都切换为自定义
  if (currentPreset.value !== "custom") {
    currentPreset.value = "custom";
    statusStore.setEqPreset("custom");
  }
  if (enabled.value) player.updateEq({ bands: bands.value });
};

watch(enabled, () => applyEq());
</script>

<style scoped lang="scss">
.equalizer {
  .eq-sliders {
    display: grid;
    grid-template-columns: repeat(10, 1fr);
    gap: 12px;
    margin-top: 20px;
    .eq-col {
      display: flex;
      flex-direction: column;
      align-items: center;
      .eq-freq {
        height: 20px;
        font-size: 12px;
        opacity: 0.75;
        margin-bottom: 6px;
      }
      :deep(.n-slider) {
        height: 160px;
      }
      .eq-value {
        width: 46px;
        text-align: center;
        margin-top: 6px;
        font-size: 12px;
        opacity: 0.8;
        white-space: nowrap;
      }
    }
  }
}
</style>
