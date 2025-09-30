# 平台自适应布局说明

## 📱 不同平台的布局差异

### 🖥️ Windows / Linux / macOS（桌面端）

**布局特点：**
- ✅ 自定义标题栏（Windows）
- ✅ 侧边导航栏（NavigationRail）
- ✅ 可展开/收起的导航栏
- ✅ 底部用户按钮
- ✅ 更大的可视区域

**界面结构：**
```
┌─────────────────────────────────────┐
│  [🎵 Cyrene Music]    [_ ☐ ×]      │  ← 自定义标题栏
├───┬─────────────────────────────────┤
│ ☰ │                                 │
│ 🏠 │                                 │
│ ⚙️ │        内容区域                  │
│   │                                 │
│ 👤 │                                 │
└───┴─────────────────────────────────┘
  ↑                    ↑
侧边导航栏           主要内容
```

### 📱 Android / iOS（移动端）

**布局特点：**
- ✅ 底部导航栏（NavigationBar）
- ✅ 系统原生标题栏
- ✅ 浮动操作按钮（用户功能）
- ✅ 全屏内容显示
- ✅ 符合移动端使用习惯

**界面结构：**
```
┌─────────────────────────────────────┐
│                                     │
│                                     │
│          内容区域                    │
│          (全屏)                      │
│                                     │
│                               [👤]  │  ← 浮动按钮
├─────────────────────────────────────┤
│    🏠 首页          ⚙️ 设置          │  ← 底部导航栏
└─────────────────────────────────────┘
```

## 🎯 实现细节

### 平台检测
```dart
if (Platform.isAndroid) {
  return _buildMobileLayout(context);
} else {
  return _buildDesktopLayout(context);
}
```

### 导航组件对比

| 特性 | Windows (侧边栏) | Android (底部栏) |
|------|------------------|------------------|
| 组件 | NavigationRail | NavigationBar |
| 位置 | 左侧 | 底部 |
| 可展开 | ✅ 是 | ❌ 否 |
| 图标+文字 | ✅ 是 | ✅ 是 |
| 额外按钮 | 顶部菜单、底部用户 | 浮动按钮 |

## 🎨 Material Design 3 适配

两种布局都遵循 Material Design 3 规范：
- ✅ 使用 MD3 导航组件
- ✅ 动态颜色主题
- ✅ 平滑的切换动画
- ✅ 一致的视觉语言

## 🔄 未来扩展

可以轻松添加更多平台支持：
```dart
if (Platform.isAndroid || Platform.isIOS) {
  return _buildMobileLayout(context);
} else if (Platform.isWindows) {
  return _buildWindowsLayout(context);
} else if (Platform.isMacOS) {
  return _buildMacOSLayout(context);
} else {
  return _buildWebLayout(context);
}
```

## 📝 导航项配置

当前导航项：
1. 🏠 **首页** - 快速访问、推荐内容、最近播放
2. ⚙️ **设置** - 外观、播放、网络、关于

添加新导航项只需：
1. 在 `_pages` 列表添加新页面
2. 在两个布局方法中添加对应的导航项
3. 保持图标和标签一致
