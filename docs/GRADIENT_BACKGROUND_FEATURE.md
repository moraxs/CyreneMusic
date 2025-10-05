# 播放器封面渐变背景功能 ✨

## 🎯 功能概述

在播放器的自适应背景模式下新增了一个**封面渐变效果**开关。开启后，播放器背景将展示专辑封面与主题色的渐变过渡效果，提供更沉浸式的视觉体验。

## 📱 平台差异

### Windows / macOS / Linux（桌面平台）
- **专辑封面位置**：左侧
- **渐变方向**：从左到右
- **效果描述**：
  - 封面等比例放大至占满播放器高度
  - 从左侧的完整封面开始
  - 向右逐渐过渡到提取的主题色
  - **整个播放器充满主题色氛围**

### Android / iOS（移动平台）
- **专辑封面位置**：顶部
- **渐变方向**：从上到下
- **效果描述**：
  - 封面等比例放大至占满屏幕宽度
  - 从顶部的完整封面开始
  - 向下逐渐过渡到提取的主题色
  - **整个播放器充满主题色氛围**

## 🎨 渐变细节

### Windows 平台渐变配置
```dart
LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [
    Colors.transparent,        // 0% - 左侧透明（显示封面）
    color.withOpacity(0.3),    // 40% - 淡淡的主题色
    color,                      // 100% - 完整主题色
  ],
  stops: const [0.0, 0.4, 1.0],
)
```

### Android 平台渐变配置
```dart
LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Colors.transparent,        // 0% - 顶部透明（显示封面）
    color.withOpacity(0.3),    // 40% - 淡淡的主题色
    color,                      // 100% - 完整主题色
  ],
  stops: const [0.0, 0.4, 1.0],
)
```

## 🔧 实现细节

### 1. 服务层 - `PlayerBackgroundService`

新增了渐变开关的持久化存储：

```dart
// 新增字段
bool _enableGradient = false;
static const String _keyEnableGradient = 'player_background_enable_gradient';

// 新增方法
Future<void> setEnableGradient(bool enabled)
bool get enableGradient
```

### 2. 播放器页面 - `player_page.dart`

**背景层实现**：
在 `_buildGradientBackground()` 方法中添加了条件判断：
- 如果 `enableGradient == true`：使用封面渐变背景
- 如果 `enableGradient == false`：使用原有的纯色渐变背景

**前景封面隐藏**：
在 `_buildLeftPanel()` 方法中，当开启渐变效果时，隐藏中间的正方形封面：

```dart
// 封面（开启渐变效果时不显示，因为封面已在背景中）
if (!backgroundService.enableGradient || 
    backgroundService.backgroundType != PlayerBackgroundType.adaptive)
  _buildCover(imageUrl),
```

### 3. 移动端播放器 - `mobile_player_page.dart`

**背景层实现**：
在 `_buildBackground()` 方法中添加了相同的条件判断，但使用垂直方向的渐变。

**前景封面隐藏**：
使用 `Builder` 包裹内容区域，动态判断是否显示封面：

```dart
final showCover = !backgroundService.enableGradient || 
                backgroundService.backgroundType != PlayerBackgroundType.adaptive;

if (showCover)
  _buildAlbumCover(song, track),
```

### 4. 设置页面 - `settings_page.dart`

在播放器背景设置对话框中，自适应背景选项下添加了渐变开关：

```dart
SwitchListTile(
  title: const Text('封面渐变效果'),
  subtitle: Text(平台相关的说明文字),
  value: backgroundService.enableGradient,
  onChanged: (value) async {
    await backgroundService.setEnableGradient(value);
  },
)
```

## 📂 修改文件列表

```
lib/
  services/
    ✏️ player_background_service.dart  - 添加渐变开关设置
  pages/
    ✏️ player_page.dart                 - Windows 平台背景实现
    ✏️ mobile_player_page.dart          - Android 平台背景实现
    ✏️ settings_page.dart               - 设置界面 UI

docs/
  📄 GRADIENT_BACKGROUND_FEATURE.md    - 本文档
```

## 🎮 使用方法

1. 打开应用的**设置页面**
2. 找到**播放器背景**设置项
3. 选择**自适应背景**（如果尚未选择）
4. 打开**封面渐变效果**开关
5. 返回并播放任意歌曲，进入全屏播放器查看效果

## 🌟 视觉效果

### 关闭渐变效果（原有样式）
- 纯色背景，从主题色到灰色的简单渐变
- 中间显示正方形专辑封面
- 干净简洁的视觉风格

### 开启渐变效果（新样式）
- ✨ **专辑封面作为背景**，占满整个播放器
- 🎨 封面与主题色完美融合的渐变效果
- 📱 前景不再显示重复的正方形封面
- 🌈 更沉浸式的音乐体验
- 🎵 每首歌曲都有独特的视觉呈现
- 💫 歌曲信息和歌词直接叠加在渐变背景上

## 🔄 动画效果

所有背景切换都包含 500ms 的平滑过渡动画：

```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 500),
  // ...
)
```

切歌时背景会自动平滑过渡到新歌曲的封面和主题色。

## 💡 技术亮点

1. **自适应布局**：桌面平台横向渐变，移动平台纵向渐变
2. **性能优化**：使用 `RepaintBoundary` 隔离重绘区域
3. **图片缓存**：利用 `CachedNetworkImage` 避免重复下载
4. **平滑过渡**：主题色和封面切换时的动画效果
5. **兼容性**：保持原有样式可用，新旧样式平滑切换

## 🎯 适用场景

### 适合开启渐变效果的情况：
- 喜欢沉浸式视觉体验
- 专辑封面质量较高
- 追求个性化的播放器界面

### 适合关闭渐变效果的情况：
- 喜欢简洁的界面
- 希望减少视觉干扰
- 性能较低的设备（虽然性能影响很小）

## 🔍 调试信息

服务初始化时会输出日志：

```
🎨 [PlayerBackground] 已初始化: PlayerBackgroundType.adaptive, 模糊: 10.0, 渐变: true
```

渐变开关切换时会输出：

```
🎨 [PlayerBackground] 渐变开关已更改: true
```

## ✨ 更新日志

### 2025-10-05 (v3)
- ✅ 优化渐变效果：移除主题色到灰色/黑色的额外渐变
- ✅ 背景现在只有**专辑封面 → 主题色**的纯粹渐变
- ✅ 视觉效果更加统一和沉浸，主题色占据更多空间

### 2025-10-05 (v2)
- ✅ 开启渐变效果时，自动隐藏前景中间的正方形封面
- ✅ 避免封面重复显示，界面更加简洁美观
- ✅ 歌曲信息和歌词直接显示在渐变背景上，视觉效果更统一

### 2025-10-05 (v1)
- ✅ 初始实现封面渐变背景功能
- ✅ 支持 Windows/macOS/Linux 横向渐变
- ✅ 支持 Android/iOS 纵向渐变
- ✅ 添加设置界面开关

---

**实现日期**: 2025-10-05  
**功能状态**: ✅ 已完成  
**兼容性**: Windows, macOS, Linux, Android, iOS  
**最后更新**: 2025-10-05 v3

