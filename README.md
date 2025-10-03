# Cyrene Music 🎵

一个功能完善的跨平台音乐播放器，使用 Flutter 开发。

## ✨ 主要功能

- 🎵 **多平台音乐源** - 支持 网易云、QQ音乐、酷狗音乐等
- 🎨 **Material Design 3** - 现代化的用户界面
- 👤 **用户认证系统** - 注册、登录、找回密码
- 📍 **IP归属地追踪** - 自动记录用户最后登录位置
- 👑 **管理员后台** - 用户管理、数据统计、可视化面板
- 💾 **智能缓存系统** - 加密缓存歌曲，加速播放体验
- 🔒 **数据持久化** - 自动保存所有用户设置
- 🖥️ **平台自适应布局** - 桌面端和移动端优化
- 🎧 **系统媒体控制集成** - 支持 Windows SMTC
- 🌐 **自定义后端** - 支持切换官方源和自定义源

## 📱 支持平台

- ✅ Windows
- ✅ Android  
- ✅ iOS
- ✅ macOS
- ✅ Linux
- ✅ Web

## 🆕 最新更新 (v1.3.2)

### 智能音乐缓存系统
- 💾 自动缓存播放过的歌曲
- 🔒 加密存储，防止直接播放（.cyrene 格式）
- 🔧 **缓存开关** - 可随时开启/关闭缓存功能
- 📁 **自定义目录** - 自由选择缓存存储位置
- 🎵 支持多平台、多音质
- 📊 完整的缓存统计和管理
- 详细文档：[MUSIC_CACHE.md](docs/MUSIC_CACHE.md) | [CACHE_SETTINGS.md](docs/CACHE_SETTINGS.md)

### 管理员后台系统
- 🔐 密码验证保护（默认密码：morax2237）
- 👥 用户列表查看和管理
- 📊 丰富的统计数据可视化
- 🗑️ 用户删除功能
- 详细文档：[ADMIN_PANEL.md](docs/ADMIN_PANEL.md)

### IP 归属地追踪功能
- 用户登录时自动获取 IP 归属地
- 后端记录用户最后一次登录的 IP 和位置
- 支持安全审计和用户分析
- 详细文档：[IP_LOCATION_TRACKING.md](docs/IP_LOCATION_TRACKING.md)

## 📚 文档

- [智能音乐缓存](docs/MUSIC_CACHE.md) 🆕
  - [缓存设置](docs/CACHE_SETTINGS.md) - 开关和目录配置
  - [文件格式](docs/CYRENE_FILE_FORMAT.md) - .cyrene 格式规范
  - [故障排除](docs/CACHE_TROUBLESHOOTING.md) - 问题解决
- [管理员后台系统](docs/ADMIN_PANEL.md)
- [IP归属地追踪](docs/IP_LOCATION_TRACKING.md)
- [数据持久化指南](DATA_PERSISTENCE_GUIDE.md)
- [平台布局说明](PLATFORM_LAYOUT.md)
- [后端 API 文档](backend/README.md)

## 🚀 快速开始

### 前端运行

```bash
# 安装依赖
flutter pub get

# 运行应用
flutter run

# 构建 Windows 版本
flutter build windows

# 构建 Android APK
flutter build apk
```

### 后端运行

```bash
cd backend

# 安装依赖
bun install

# 启动服务器
bun run src/index.ts
```

## 🛠️ 技术栈

**前端：**
- Flutter 3.x
- Material Design 3
- Provider (状态管理)
- shared_preferences (本地存储)
- crypto (缓存加密)

**后端：**
- Bun + TypeScript
- Elysia (Web框架)
- SQLite (数据库)
- bcrypt (密码加密)

## 📞 技术支持

如有问题，请查看项目文档或提交 Issue。

---

**版本**: 1.3.3  
**最后更新**: 2025-10-02  
**管理员密码**: morax2237  
**新功能**: 智能音乐缓存系统 🎵  
**最新改进**: 可视化目录选择器 + 歌词缓存
