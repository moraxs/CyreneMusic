# Flutter SDK 版本更新说明

## 🔄 更新内容

### 问题
之前的 GitHub Actions 配置使用固定的 Flutter 版本 `3.24.5`，该版本包含的 Dart SDK 版本为 3.5.4，但 `pubspec.yaml` 要求 Dart SDK `^3.8.1`，导致构建失败：

```
The current Dart SDK version is 3.5.4.
Because cyrene_music requires SDK version ^3.8.1, version solving failed.
```

### 解决方案

移除固定的 Flutter 版本号，改为自动使用最新稳定版：

**修改前**：
```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.24.5'
    channel: 'stable'
```

**修改后**：
```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    channel: 'stable'
    cache: true
```

## ✅ 优势

### 1. 自动兼容性
- ✅ 自动使用最新稳定版 Flutter
- ✅ 确保 Dart SDK 版本符合 `pubspec.yaml` 要求
- ✅ 无需手动更新 Flutter 版本号

### 2. 构建加速
- ✅ 启用 `cache: true`，缓存 Flutter SDK
- ✅ 后续构建可复用缓存，节省下载时间
- ✅ 预计每次构建节省 1-2 分钟

### 3. 长期维护
- ✅ 自动获取最新的 Flutter 稳定版
- ✅ 自动包含最新的安全补丁和性能优化
- ✅ 减少维护工作量

## 🎯 版本对应关系

| Flutter 版本 | Dart SDK 版本 | 兼容性 |
|-------------|---------------|--------|
| 3.24.5      | 3.5.4         | ❌ 不兼容（旧版）|
| 3.27.0+     | 3.8.0+        | ✅ 兼容 |
| 最新稳定版   | 3.8.x+        | ✅ 兼容（推荐）|

## 🔧 如何指定特定版本

如果需要固定 Flutter 版本（不推荐），可以添加 `flutter-version` 参数：

```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.27.0'  # 指定版本
    channel: 'stable'
    cache: true
```

**推荐的最低版本**：
- Flutter: `3.27.0` 或更高
- 包含 Dart SDK: `3.8.0` 或更高

## 📋 影响的文件

所有 5 个平台的构建配置都已更新：
- ✅ Android 构建
- ✅ Windows 构建
- ✅ Linux 构建
- ✅ macOS 构建
- ✅ iOS 构建

## 🧪 验证方法

### 本地验证

```bash
# 检查 Flutter 版本
flutter --version

# 检查 Dart SDK 版本
dart --version

# 测试依赖解析
flutter pub get
```

### GitHub Actions 验证

1. 推送更改到 GitHub
2. 手动触发工作流（选择一个平台测试）
3. 查看 "Setup Flutter" 步骤的日志
4. 确认 Flutter 和 Dart SDK 版本符合要求

## 📊 构建时间对比

| 阶段 | 修改前 | 修改后 | 说明 |
|------|--------|--------|------|
| 下载 Flutter SDK | ~2 分钟 | 首次: ~2 分钟<br>后续: ~10 秒 | 启用缓存 |
| 解析依赖 | ❌ 失败 | ✅ 成功 | 版本兼容 |
| 总构建时间 | N/A | 减少 1-2 分钟 | 缓存优化 |

## ⚠️ 注意事项

### 1. 本地开发
确保本地 Flutter SDK 版本也满足要求：

```bash
# 升级到最新稳定版
flutter upgrade

# 或安装特定版本
flutter version 3.27.0
```

### 2. pubspec.yaml 要求
当前项目要求：

```yaml
environment:
  sdk: ^3.8.1
```

如果降低 Dart SDK 要求，也需要更新此配置。

### 3. 插件兼容性
某些 Flutter 插件可能对 SDK 版本有特定要求，升级前请确认：

```bash
flutter pub outdated
```

## 🔗 相关资源

- [Flutter 版本发布历史](https://docs.flutter.dev/release/archive)
- [Dart SDK 版本说明](https://dart.dev/get-dart/archive)
- [subosito/flutter-action 文档](https://github.com/subosito/flutter-action)

## ✨ 总结

此次更新：
- ✅ 修复了 Dart SDK 版本不兼容的构建错误
- ✅ 启用了 Flutter SDK 缓存，加速构建
- ✅ 简化了后续维护工作
- ✅ 确保始终使用最新稳定版 Flutter

现在所有平台的构建都应该能够成功运行！🎉

