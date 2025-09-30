# Cyrene Music 前端架构

## 项目结构

```
lib/
├── main.dart                  # 应用入口
├── layouts/                   # 布局组件
│   └── main_layout.dart      # 主布局（侧边导航栏）
├── pages/                     # 页面
│   ├── home_page.dart        # 首页
│   └── settings_page.dart    # 设置页
└── widgets/                   # 通用组件
    └── custom_title_bar.dart # 自定义标题栏（Windows）
```

## 特性

### ✨ Material Design 3
- 使用最新的 Material Design 3 设计规范
- 支持浅色/深色主题
- 现代化的卡片和按钮样式

### 🪟 自定义标题栏（Windows）
- 隐藏默认标题栏
- 自定义窗口控制按钮（最小化、最大化、关闭）
- 可拖动窗口区域

### 📱 侧边导航栏
- 可折叠/展开的导航栏
- 首页和设置页面快速切换
- 底部用户入口

### 🎨 响应式设计
- 适配 Windows 和 Android 平台
- 自适应布局

## 运行项目

### Windows
```bash
flutter run -d windows
```

### Android
```bash
flutter run -d android
```

## 待开发功能

- [ ] 音乐播放器核心功能
- [ ] 与后端 API 集成
- [ ] 搜索功能
- [ ] 播放列表管理
- [ ] 用户登录和账户管理
- [ ] 视频播放器
- [ ] 弹幕系统
- [ ] 主题切换
- [ ] 网络设置和测试
