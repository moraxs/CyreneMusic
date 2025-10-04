# GitHub Actions 自动构建说明

本项目使用 GitHub Actions 自动构建多平台版本。

## 🚀 使用方法

### 方式 1: 通过标签触发 (推荐)

创建并推送一个版本标签即可自动构建所有平台：

```bash
# 创建标签
git tag v1.0.4

# 推送标签
git push origin v1.0.4
```

构建完成后会自动创建 GitHub Release，包含所有平台的安装包。

### 方式 2: 手动触发

1. 前往 GitHub 仓库的 Actions 页面
2. 选择 "Multi-Platform Build" 工作流
3. 点击 "Run workflow" 按钮
4. 选择要构建的平台（默认全部勾选）：
   - ✅ **构建 Android** - 构建 Android APK
   - ✅ **构建 Windows** - 构建 Windows 版本
   - ✅ **构建 Linux** - 构建 Linux 版本
   - ✅ **构建 macOS** - 构建 macOS 版本
   - ✅ **构建 iOS** - 构建 iOS 版本
5. 选择分支并点击运行

**特性**：
- 默认会构建所有平台
- 可以取消勾选不需要的平台以节省时间
- 只构建勾选的平台，节省 GitHub Actions 配额
- 手动触发不会自动创建 Release，但会生成构建产物（Artifacts）供下载

## 📦 构建产物

每次构建会生成以下产物：

### Android
- `app-armeabi-v7a-release.apk` - 32位 ARM 设备
- `app-arm64-v8a-release.apk` - 64位 ARM 设备（推荐）
- `app-x86_64-release.apk` - x86_64 设备（模拟器）

### Windows
- `cyrene_music-windows-x64.zip` - Windows 64位版本
  - 解压后直接运行 `cyrene_music.exe`

### Linux
- `cyrene_music-linux-x64.tar.gz` - Linux 64位版本
  - 解压后运行 `bundle/cyrene_music`
  - 需要系统安装 GTK 3.0: `sudo apt-get install libgtk-3-0`

### macOS
- `cyrene_music-macos.dmg` - macOS 磁盘映像
  - 双击打开，拖拽到应用程序文件夹

### iOS
- `cyrene_music-ios-unsigned.ipa` - iOS 未签名版本
  - ⚠️ 需要使用 Xcode 重新签名才能安装

## 🔧 平台特定说明

### Windows 平台
Windows 版本包含 `smtc_windows` 插件，支持系统媒体传输控制（SMTC），可以在：
- Windows 通知中心控制播放
- 键盘媒体键控制
- 蓝牙耳机控制

### Android 平台
Android 版本使用 `audio_service` 插件，支持：
- 通知栏媒体控制
- 锁屏媒体控制
- 蓝牙设备控制

### Linux/macOS 平台
这些平台不支持 `smtc_windows` 插件，但会使用 `tray_manager` 提供系统托盘控制。

## 🐛 常见问题

### Q: iOS 构建失败怎么办？
A: iOS 需要在 macOS 环境下使用 Xcode 进行签名。GitHub Actions 生成的是未签名版本，需要：
1. 下载 `.ipa` 文件
2. 使用 Xcode 重新签名
3. 或者配置 GitHub Secrets 添加签名证书

### Q: 如何添加签名证书？
A: 在 GitHub 仓库设置中添加以下 Secrets：
- `IOS_CERTIFICATE_BASE64` - iOS 开发证书（Base64 编码）
- `IOS_PROVISION_PROFILE_BASE64` - 配置文件（Base64 编码）
- `KEYCHAIN_PASSWORD` - 临时钥匙串密码
- `MACOS_CERTIFICATE_BASE64` - macOS 开发证书（Base64 编码）

### Q: 构建时间多长？
A: 通常情况下：
- Android: 5-8 分钟
- Windows: 3-5 分钟
- Linux: 4-6 分钟
- macOS: 5-8 分钟
- iOS: 5-8 分钟

总计约 20-30 分钟完成所有平台构建。

### Q: 可以只构建某一个平台吗？
A: 可以！使用手动触发方式，在 Actions 页面只勾选需要构建的平台即可。

## 📝 自定义配置

如果需要修改构建配置，编辑 `.github/workflows/build.yml` 文件：

- 修改 Flutter 版本: 更改 `flutter-version` 参数
- 修改构建参数: 在 `flutter build` 命令后添加参数
- 修改触发条件: 更改 `on` 部分的配置

## 🔗 相关链接

- [Flutter 桌面支持文档](https://docs.flutter.dev/desktop)
- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [Flutter 构建指南](https://docs.flutter.dev/deployment)

