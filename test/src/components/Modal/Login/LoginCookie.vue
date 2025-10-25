<template>
  <div class="login-cookie">
    <n-alert :bordered="false" title="如何获取 Cookie">
      <template #icon>
        <SvgIcon name="Help" />
      </template>
      可在官方的
      <n-a href="https://music.163.com/" target="_blank">网页端</n-a>
      或点击下方的自动获取，只需要 Cookie 中的 <code>MUSIC_U</code> 字段即可，例如：
      <code>MUSIC_U=00C7...;</code><br />请注意：必须以 <code>;</code> 结束
    </n-alert>
    <n-input
      v-model:value="cookie"
      :autosize="{ minRows: 3, maxRows: 6 }"
      type="textarea"
      placeholder="请输入 Cookie"
    />
    <n-flex class="menu">
      <n-button v-if="isElectron" type="primary" @click="openWeb">自动获取</n-button>
      <n-button type="primary" @click="login">登录</n-button>
    </n-flex>
  </div>
</template>

<script setup lang="ts">
import type { LoginType } from "@/types/main";
import { isElectron } from "@/utils/helper";

const emit = defineEmits<{
  close: [];
  saveLogin: [any, LoginType];
}>();

const cookie = ref<string>();

// 开启窗口
const openWeb = () => {
  window.$dialog.info({
    title: "使用前告知",
    content:
      "请知悉，该功能仍旧无法确保账号的安全性！请自行决定是否使用！如遇打开窗口后页面出现白屏或者无法点击等情况，请关闭后重试",
    positiveText: "我已了解",
    negativeText: "取消",
    onPositiveClick: () => window.electron.ipcRenderer.send("open-login-web"),
  });
};

// Cookie 登录
const login = async () => {
  if (!cookie.value) {
    window.$message.warning("请输入 Cookie");
    return;
  }
  cookie.value = cookie.value.trim();
  console.log(cookie.value.endsWith(";"));

  // 是否为有效 Cookie
  if (!cookie.value.includes("MUSIC_U") || !cookie.value.endsWith(";")) {
    window.$message.warning("请输入有效的 Cookie");
    return;
  }
  // 写入 Cookie
  try {
    window.$message.success("登录成功");
    // 保存登录信息
    emit(
      "saveLogin",
      {
        code: 200,
        cookie: cookie.value,
      },
      "cookie",
    );
    emit("close");
  } catch (error) {
    window.$message.error("登录失败，请重试");
    console.error("Cookie 登录出错：", error);
  }
};

onMounted(() => {
  if (isElectron) {
    window.electron.ipcRenderer.on("send-cookies", (_, value) => {
      if (!value) return;
      cookie.value = value;
      login();
    });
  }
});
</script>

<style lang="scss" scoped>
.login-cookie {
  .n-input,
  .n-button {
    width: 100%;
    margin-top: 20px;
  }
  code {
    font-size: 12px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    background-color: var(--n-border-color);
    padding: 4px 6px;
    border-radius: 8px;
    margin: 4px 0;
    font-family: auto;
  }
  .menu {
    margin-top: 20px;
    .n-button {
      width: auto;
      flex: 1;
      margin: 0;
    }
  }
}
</style>
