# Cyrene Music 🎵

一个功能完善的跨平台音乐播放器，使用 Flutter 开发。


## 📱 支持平台

- ✅ Windows
- ✅ Android
- ✅ Linux
- ✅ macOS
- ✅ iOS

## 🚀 快速开始

### 下载预编译版本

前往 [Releases](https://github.com/your-repo/releases) 页面下载对应平台的安装包。

### 本地开发运行

```bash
# 安装依赖
flutter pub get

# 运行应用（自动选择连接的设备）
flutter run

# 指定平台运行
flutter run -d windows
flutter run -d linux
flutter run -d macos
flutter run -d android
```

### 手动构建

```bash
# Windows
flutter build windows --release

# Linux
flutter build linux --release

# macOS
flutter build macos --release

# Android APK
flutter build apk --release --split-per-abi

# iOS (需要 macOS)
flutter build ios --release
```

### 自动构建（GitHub Actions）

推送版本标签即可自动构建所有平台：

```bash
git tag v1.0.4
git push origin v1.0.4
```

详细说明请查看 [GitHub Actions 构建指南](docs/GITHUB_ACTIONS_BUILD.md)。

### 后端运行

```bash
cd backend

# 安装依赖
bun install

# 启动服务器
bun run src/index.ts
```
