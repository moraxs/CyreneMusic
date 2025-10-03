# Android 通知图标自定义指南

## 📱 当前配置

目前使用 **audio_service 的默认通知图标**，避免黑色方块问题。

## 🎨 如果要自定义通知图标

### 重要要求

Android 通知图标必须满足：

1. ✅ **单色图标**（纯白色，透明背景）
2. ✅ **PNG 格式**
3. ✅ **多个尺寸** (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi)
4. ✅ **放在 drawable 目录**（不是 mipmap）

### 为什么彩色图标会显示为黑色方块？

Android 5.0+ 的通知图标要求：
- 只使用 alpha 通道（透明度）
- 系统会自动将图标染成系统主题色
- 如果使用彩色图标，系统会将所有非透明像素显示为黑色

## 🛠️ 创建自定义图标步骤

### 方法 1: 在线生成（推荐）

使用 [Android Asset Studio](https://romannurik.github.io/AndroidAssetStudio/icons-notification.html):

1. 访问网站
2. 上传你的 logo
3. 调整 padding 和大小
4. 点击 "Download .zip"
5. 解压后将文件复制到项目

### 方法 2: 手动创建

#### 步骤 1: 准备图标文件

创建以下目录和文件：

```
android/app/src/main/res/
├── drawable-mdpi/
│   └── ic_notification.png       (24x24 dp)
├── drawable-hdpi/
│   └── ic_notification.png       (36x36 dp)
├── drawable-xhdpi/
│   └── ic_notification.png       (48x48 dp)
├── drawable-xxhdpi/
│   └── ic_notification.png       (72x72 dp)
└── drawable-xxxhdpi/
    └── ic_notification.png       (96x96 dp)
```

**图标规格**：
- 纯白色前景 (#FFFFFF)
- 透明背景
- 简洁设计（不要太复杂）
- 推荐使用音符或播放器相关符号

#### 步骤 2: 修改代码

在 `lib/services/system_media_service.dart` 中：

```dart
config: const AudioServiceConfig(
  androidNotificationChannelId: 'com.cyrene.music.channel.audio',
  androidNotificationChannelName: 'Cyrene Music',
  androidNotificationOngoing: false,
  androidNotificationIcon: 'drawable/ic_notification',  // 添加这一行
  androidShowNotificationBadge: true,
  androidStopForegroundOnPause: false,
),
```

#### 步骤 3: 重新编译

```bash
flutter clean
flutter run
```

## 📐 图标尺寸对照表

| 密度 | 文件夹 | 尺寸 (px) |
|------|--------|-----------|
| mdpi | drawable-mdpi | 24x24 |
| hdpi | drawable-hdpi | 36x36 |
| xhdpi | drawable-xhdpi | 48x48 |
| xxhdpi | drawable-xxhdpi | 72x72 |
| xxxhdpi | drawable-xxxhdpi | 96x96 |

## 🎨 设计建议

### 推荐的图标样式

**音乐播放器常用图标**：
- 🎵 音符
- 🎧 耳机
- ▶️ 播放按钮
- 📻 收音机
- 🎸 乐器

### 设计规范

1. **简洁明了**
   - 不要过于复杂
   - 确保在小尺寸下清晰可见

2. **高对比度**
   - 使用纯白色 (#FFFFFF)
   - 透明背景
   - 不要使用灰色或半透明

3. **留白充足**
   - 图标周围留有适当边距
   - 不要填满整个画布

## 🧪 测试图标

### 使用 Android Asset Studio 预览

1. 生成图标后
2. 查看预览图
3. 确认在各种背景下都清晰可见

### 在设备上测试

```bash
# 安装应用
flutter run

# 播放音乐，查看通知
# 检查图标是否显示正确
```

### 测试不同主题

- 浅色主题
- 深色主题
- 系统默认主题

## ❌ 常见错误

### 错误 1: 使用彩色图标
```
❌ 使用 mipmap/ic_launcher (彩色应用图标)
✅ 使用 drawable/ic_notification (单色通知图标)
```

### 错误 2: 文件位置错误
```
❌ android/app/src/main/res/mipmap-*/ic_notification.png
✅ android/app/src/main/res/drawable-*/ic_notification.png
```

### 错误 3: 图标太复杂
```
❌ 详细的 logo 图案
✅ 简单的音符或播放符号
```

## 📚 参考资源

- [Android Notification Icon Guidelines](https://developer.android.com/guide/topics/ui/notifiers/notifications#templates)
- [Material Design - Product Icons](https://material.io/design/iconography/product-icons.html)
- [Android Asset Studio](https://romannurik.github.io/AndroidAssetStudio/)

## 🔄 回到默认图标

如果自定义图标有问题，可以恢复默认：

```dart
config: const AudioServiceConfig(
  // ... 其他配置
  // 不设置 androidNotificationIcon，使用默认图标
),
```

---

**注意**: 当前项目使用默认图标以避免黑色方块问题。如需自定义，请按照本指南操作。

