# GitHub Actions 多平台构建修复

## 问题描述

在使用 GitHub Actions 进行多平台构建时遇到的问题和解决方案。

## 修复内容

### 1. Linux 平台：GStreamer 依赖缺失

**错误信息：**
```
CMake Error: The following required packages were not found:
 - gstreamer-1.0
```

**原因：** `audioplayers_linux` 插件依赖 GStreamer 多媒体框架。

**解决方案：** 在 Linux 构建步骤中添加 GStreamer 相关依赖包。

```yaml
- name: Install Linux dependencies
  run: |
    sudo apt-get update
    sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev \
      libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev gstreamer1.0-plugins-good \
      gstreamer1.0-plugins-bad gstreamer1.0-libav \
      libayatana-appindicator3-dev
```

**安装的包说明：**
- `libgstreamer1.0-dev` - GStreamer 核心开发库
- `libgstreamer-plugins-base1.0-dev` - GStreamer 基础插件开发库
- `gstreamer1.0-plugins-good` - 良好质量的插件（LGPL）
- `gstreamer1.0-plugins-bad` - 实验性插件
- `gstreamer1.0-libav` - FFmpeg/Libav 插件（用于音频解码）
- `libayatana-appindicator3-dev` - Ayatana 系统托盘指示器库（用于 tray_manager）

### 2. Linux 平台：系统托盘指示器依赖缺失

**错误信息：**
```
CMake Error: The `tray_manager` package requires ayatana-appindicator3-0.1 or appindicator3-0.1.
```

**原因：** `tray_manager` 插件需要系统托盘指示器库来显示托盘图标和菜单。

**解决方案：** 安装 Ayatana AppIndicator 开发库。

```bash
sudo apt-get install -y libayatana-appindicator3-dev
```

**说明：**
- `libayatana-appindicator3-dev` 是 Ubuntu 推荐的现代系统托盘指示器库
- 如果您使用较旧的系统，可以安装 `libappindicator3-dev` 作为替代

### 3. 移除不必要的依赖处理步骤

**背景：** 原本需要在非 Windows 平台移除 `smtc_windows` 依赖。

**现状：** 我们已经完全移除了 `smtc_windows` 包依赖，改用原生 C++ 实现，所以不再需要这些步骤。

**移除的步骤：**
```yaml
# ❌ 不再需要
- name: Remove Windows-only dependencies
  run: |
    sed -i '/smtc_windows:/d' pubspec.yaml  # Linux/Android
    # 或
    sed -i '' '/smtc_windows:/d' pubspec.yaml  # macOS/iOS
```

## 当前各平台依赖概览

### Android
```yaml
- Java 17 (Zulu)
- Flutter Stable
```

### Windows
```yaml
- Flutter Stable
- Windows SDK (自带)
- Visual Studio Build Tools (GitHub Actions 预装)
```

### Linux
```yaml
- Flutter Stable
- GTK 3 开发库
- GStreamer 1.0 及插件（音频播放）
- Ayatana AppIndicator 3（系统托盘）
- CMake, Ninja, Clang
```

### macOS
```yaml
- Flutter Stable
- Xcode (GitHub Actions 预装)
```

### iOS
```yaml
- Flutter Stable
- Xcode (GitHub Actions 预装)
- 注意：构建为未签名的 IPA
```

## 完整的构建流程

### 触发条件

1. **推送标签** - 当推送 `v*` 标签时自动构建所有平台
2. **手动触发** - 在 GitHub Actions 页面手动触发，可选择构建的平台

### 产物说明

| 平台 | 产物文件 | 说明 |
|------|----------|------|
| Android | `app-armeabi-v7a-release.apk`<br>`app-arm64-v8a-release.apk`<br>`app-x86_64-release.apk` | 按架构分包的 APK |
| Windows | `cyrene_music-windows-x64.zip` | 包含所有运行时文件的压缩包 |
| Linux | `cyrene_music-linux-x64.tar.gz` | Linux bundle 的 tar.gz 包 |
| macOS | `cyrene_music-macos.dmg` | macOS 磁盘镜像安装包 |
| iOS | `cyrene_music-ios-unsigned.ipa` | 未签名的 iOS 应用包 |

## 测试方法

### 本地测试 GitHub Actions

使用 [act](https://github.com/nektos/act) 在本地运行 GitHub Actions：

```bash
# 安装 act
winget install nektos.act  # Windows
# 或
brew install act  # macOS

# 测试 Linux 构建
act -j build-linux

# 测试所有构建
act push
```

### 手动触发构建

1. 进入 GitHub 仓库的 Actions 页面
2. 选择 "Multi-Platform Build" workflow
3. 点击 "Run workflow"
4. 选择要构建的平台
5. 点击 "Run workflow" 按钮

## 常见问题

### Q: 为什么 Linux 需要这么多 GStreamer 插件？

A: `audioplayers` 使用 GStreamer 作为音频后端，需要：
- **plugins-good**: 基础音频格式支持（MP3, OGG 等）
- **plugins-bad**: 一些实验性但常用的格式
- **libav**: FFmpeg 支持，处理更多音频格式

### Q: Windows 为什么不需要额外依赖？

A: Windows 使用 `audioplayers_windows` 后端，它基于 Windows Media Foundation (WMF)，这是 Windows 系统自带的。

### Q: macOS/iOS 构建为什么不需要特殊音频库？

A: 它们使用 AVFoundation 框架，这是 Apple 平台的原生多媒体框架。

### Q: 为什么 Linux 需要 Ayatana AppIndicator？

A: `tray_manager` 插件使用系统托盘指示器来显示托盘图标和菜单。Linux 桌面环境（如 GNOME、KDE）通过 AppIndicator 协议提供系统托盘支持。Ayatana 是 Ubuntu 维护的现代实现版本。

### Q: 构建失败怎么办？

1. 检查 Flutter 版本是否为 Stable
2. 查看详细的错误日志
3. 确认所有依赖包都已正确安装
4. 尝试清理缓存后重新构建：
   ```yaml
   - name: Clean Flutter cache
     run: flutter clean
   ```

## 性能优化

### 缓存策略

当前配置使用了 Flutter Action 的内置缓存：
```yaml
- uses: subosito/flutter-action@v2
  with:
    cache: true  # 自动缓存 Flutter SDK 和 pub cache
```

### 构建时间参考

在 GitHub Actions 上的大致构建时间：

- Android: ~5-8 分钟
- Windows: ~10-15 分钟
- Linux: ~8-12 分钟
- macOS: ~12-18 分钟
- iOS: ~10-15 分钟

**总计：** 约 45-70 分钟（并行构建）

## 相关文档

- [GitHub Actions 官方文档](https://docs.github.com/en/actions)
- [Flutter CI/CD 最佳实践](https://docs.flutter.dev/deployment/cd)
- [GStreamer 文档](https://gstreamer.freedesktop.org/documentation/)

---

**最后更新：** 2025-10-07  
**状态：** ✅ 所有平台构建正常

