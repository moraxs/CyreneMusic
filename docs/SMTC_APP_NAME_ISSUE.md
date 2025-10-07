# SMTC 应用名称显示问题说明

## 问题描述

在 Windows 媒体控制面板中，应用可能显示为"未知应用"或"cyrene_music.exe"，而不是友好的应用名称"Cyrene Music"。

## 技术原因

根据[技术博客分析](https://www.cnblogs.com/TwilightLemon/p/18279496)：

> Windows 虽然能确定是哪个 exe 调用的 SMTC，但由于没有提供合法的 UWP Window 句柄，系统拒绝直接显示 exe 的友好信息。

这是**非 UWP 应用通过 MediaPlayer 访问 SMTC 的固有限制**，无法完全绕过。

## 我们已做的优化

### 1. 设置 AppUserModelID
**文件：** `windows/runner/main.cpp`
```cpp
::SetCurrentProcessExplicitAppUserModelID(L"CyreneMusic.MusicPlayer.Desktop.1");
```

### 2. 设置 AppMediaId
**文件：** `windows/runner/smtc_plugin.cpp`
```cpp
updater_.AppMediaId(L"CyreneMusic.MusicPlayer.Desktop.1");
```

### 3. 配置应用元数据
**文件：** `windows/runner/Runner.rc`
```rc
VALUE "ProductName", "Cyrene Music"
VALUE "FileDescription", "Cyrene Music - Modern Music Player"
VALUE "CompanyName", "Cyrene Music"
```

### 4. 应用清单
**文件：** `windows/runner/runner.exe.manifest`
```xml
<assemblyIdentity name="CyreneMusic.MusicPlayer" />
<description>Cyrene Music - Modern Music Player</description>
```

## 实际效果

根据测试，可能出现以下几种显示情况：

1. ✅ **最佳情况**：显示"Cyrene Music"或"CyreneMusic.MusicPlayer"
2. ⚠️ **常见情况**：显示"cyrene_music.exe"（可执行文件名）
3. ⚠️ **部分情况**：显示"未知应用"

**注意：** 显示效果可能因 Windows 版本和系统配置而异。

## 功能影响

尽管应用名称显示不理想，但**所有 SMTC 核心功能完全正常**：

- ✅ 媒体信息显示（歌曲名、艺术家、专辑、封面）
- ✅ 播放控制（播放/暂停/上一曲/下一曲）
- ✅ 键盘快捷键支持
- ✅ 蓝牙耳机控制
- ✅ 进度显示

## 可能的改进方案（高级）

### 方案1：打包为 MSIX/AppX（推荐）

将应用打包成 MSIX 包，这样就能获得完整的 UWP 应用身份：

```powershell
# 需要 Windows SDK 和证书
flutter build windows --release
# 使用 MSIX Packaging Tool 打包
```

**优点：**
- ✅ 应用名称显示正确
- ✅ 可上架 Microsoft Store
- ✅ 自动更新支持
- ✅ 点击 SMTC 可跳转到应用

**缺点：**
- ⚠️ 需要数字签名证书
- ⚠️ 打包流程较复杂
- ⚠️ 应用体积增加

### 方案2：创建 UWP 包装器

创建一个轻量级 UWP 壳，内部启动 Flutter 应用。

**优点：**
- ✅ 获得完整 UWP 身份

**缺点：**
- ⚠️ 架构复杂
- ⚠️ 维护成本高

### 方案3：接受现状（当前方案）

保持当前实现，接受应用名称显示限制。

**优点：**
- ✅ 简单直接
- ✅ 所有功能正常
- ✅ 易于维护

**缺点：**
- ⚠️ 应用名称显示不理想

## 结论

**对于大多数用户来说，当前实现已经足够好**：

1. 媒体控制功能完全正常
2. 用户主要关注的是歌曲信息，而不是应用名称
3. 实现简单，维护成本低

如果**必须**有完美的应用名称显示，建议采用 MSIX 打包方案。

## 参考资料

- [.NET App 与Windows系统媒体控制(SMTC)交互 - TwilightLemon](https://www.cnblogs.com/TwilightLemon/p/18279496)
- [SystemMediaTransportControls - Microsoft Docs](https://docs.microsoft.com/en-us/uwp/api/windows.media.systemmediatransportcontrols)
- [MSIX Packaging](https://docs.microsoft.com/en-us/windows/msix/)

---

**最后更新：** 2025-10-07  
**状态：** 已知限制，建议接受或使用 MSIX 打包

