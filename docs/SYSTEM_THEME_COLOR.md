# 跟随系统主题色功能

## 📌 功能概述

Cyrene Music 现在支持**跟随系统主题色**功能，可以自动获取并应用系统级别的主题颜色，让应用与系统 UI 保持一致的视觉体验。

### 支持平台

| 平台 | 版本要求 | 功能说明 |
|------|---------|---------|
| **Android** | Android 12+ | 支持 Material You 动态颜色 |
| **Windows** | Windows 11 | 使用默认强调色（蓝色） |

---

## ✨ 功能特性

### 1. 自动跟随系统主题色

- ✅ **默认启用**：首次安装应用时，默认开启跟随系统主题色
- ✅ **实时更新**：系统主题色改变时自动更新（需要重启应用）
- ✅ **平滑过渡**：主题色切换时有动画过渡效果

### 2. Material You 支持 (Android 12+)

- 🎨 自动提取壁纸颜色
- 🎨 生成动态颜色方案
- 🎨 完美适配 Material Design 3

### 3. Windows 系统强调色

- 🎨 使用 Windows 11 默认蓝色
- 🎨 未来版本将支持读取真实系统强调色

### 4. 手动主题色选择

- 🎨 提供 10+ 种预设主题色
- 🎨 支持自定义颜色选择器
- 🎨 手动选择颜色时自动关闭跟随系统

---

## 🎯 使用方法

### 开启跟随系统主题色

1. 打开应用，进入 **设置页面**
2. 在 **外观** 分类中找到 **跟随系统主题色**
3. 打开开关即可启用

![跟随系统主题色开关](https://via.placeholder.com/600x150?text=跟随系统主题色开关)

### 关闭跟随系统主题色

方式一：**手动关闭开关**
- 在设置中关闭 **跟随系统主题色** 开关
- 然后选择自定义主题色

方式二：**直接选择主题色**
- 点击 **主题色** 选项
- 选择任意预设颜色或自定义颜色
- 系统会自动关闭跟随功能

---

## 📱 Android 平台详细说明

### Material You 动态颜色

Android 12+ 引入了 Material You 设计系统，支持从壁纸中提取颜色生成动态主题。

#### 工作原理

```
用户壁纸
    ↓
系统提取主色调
    ↓
生成 CorePalette (色板)
    ↓
Cyrene Music 读取主色
    ↓
应用到应用主题
```

#### 兼容性

| Android 版本 | 支持情况 |
|-------------|---------|
| Android 12+ | ✅ 完全支持 Material You |
| Android 11及以下 | ⚠️ 不支持，使用默认颜色 |

#### 测试步骤

1. **Android 12+ 设备**上安装应用
2. 更换系统壁纸
3. 重启应用
4. 查看主题色是否更新

#### 示例效果

```
壁纸：蓝色海洋 → 应用主题色：蓝色
壁纸：绿色森林 → 应用主题色：绿色
壁纸：粉色樱花 → 应用主题色：粉色
```

---

## 🖥️ Windows 平台详细说明

### Windows 系统强调色

Windows 允许用户自定义系统强调色（Accent Color），应用可以读取并使用这个颜色。

#### 当前实现

✅ **已实现真实系统强调色读取**

通过平台通道（Platform Channel）读取 Windows 注册表中的系统强调色：

```dart
// Dart 层
const platform = MethodChannel('com.cyrene.music/system_color');
final int colorValue = await platform.invokeMethod('getSystemAccentColor');
final color = Color(colorValue);

// Windows C++ 层
uint32_t SystemColorHelper::GetSystemAccentColor() {
  DWORD colorValue;
  RegOpenKeyExW(HKEY_CURRENT_USER, 
                L"SOFTWARE\\Microsoft\\Windows\\DWM", ...);
  RegQueryValueExW(..., L"ColorizationColor", ...);
  return colorValue; // ARGB 格式
}
```

#### Windows 强调色位置

系统强调色存储在注册表中：
```
HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\DWM\ColorizationColor
```

#### 测试步骤

1. 打开 Windows **设置 > 个性化 > 颜色**
2. 选择一个强调色（例如：蓝灰色、绿色等）
3. 重启或重新打开 Cyrene Music
4. 查看应用主题色是否与系统强调色一致

#### 支持的 Windows 版本

| Windows 版本 | 支持情况 |
|-------------|---------|
| Windows 11 | ✅ 完全支持 |
| Windows 10 | ✅ 完全支持 |
| Windows 8/8.1 | ✅ 支持（使用 DWM 强调色） |
| Windows 7 | ⚠️ 部分支持（可能返回默认值） |

---

## 🔧 技术实现

### 架构设计

```
┌─────────────────────────────────────────┐
│         ThemeManager                     │
│  ┌────────────────────────────────┐    │
│  │  - followSystemColor (bool)     │    │
│  │  - seedColor (Color)            │    │
│  │  - systemColor (Color?)         │    │
│  └────────────┬───────────────────┘    │
│               │                          │
│               ↓                          │
│  ┌────────────────────────────────┐    │
│  │  SystemThemeColorService        │    │
│  │  ┌──────────────────────────┐  │    │
│  │  │  getSystemThemeColor()    │  │    │
│  │  └──────────┬───────────────┘  │    │
│  └─────────────┼───────────────────┘    │
│                │                          │
└────────────────┼─────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
    Android           Windows
   (Material You)   (Accent Color)
```

### 核心代码

#### 1. 系统主题色服务

```dart
// lib/services/system_theme_color_service.dart

class SystemThemeColorService {
  Future<Color?> getSystemThemeColor(BuildContext context) async {
    if (Platform.isAndroid) {
      return await _getAndroidDynamicColor(context);
    } else if (Platform.isWindows) {
      return await _getWindowsAccentColor();
    }
    return null;
  }

  Future<Color?> _getAndroidDynamicColor(BuildContext context) async {
    final corePalette = await DynamicColorPlugin.getCorePalette();
    if (corePalette != null) {
      return Color(corePalette.primary.get(40));
    }
    return null;
  }

  Future<Color?> _getWindowsAccentColor() async {
    return const Color(0xFF0078D4); // Windows 11 默认蓝色
  }
}
```

#### 2. 主题管理器

```dart
// lib/utils/theme_manager.dart

class ThemeManager extends ChangeNotifier {
  bool _followSystemColor = true; // 默认跟随系统
  Color _seedColor = Colors.deepPurple;
  Color? _systemColor;

  Future<void> fetchAndApplySystemColor(BuildContext context) async {
    if (!_followSystemColor) return;

    final systemColor = await SystemThemeColorService()
        .getSystemThemeColor(context);
    
    if (systemColor != null) {
      _systemColor = systemColor;
      _seedColor = systemColor;
      await _saveSeedColor();
      notifyListeners();
    }
  }

  void setSeedColor(Color color) {
    if (_seedColor != color) {
      _seedColor = color;
      _saveSeedColor();
      
      // 手动设置颜色时，自动关闭跟随系统
      if (_followSystemColor) {
        _followSystemColor = false;
        _saveFollowSystemColor();
      }
      
      notifyListeners();
    }
  }
}
```

#### 3. 设置页面

```dart
// lib/pages/settings_page.dart

_buildSwitchTile(
  title: '跟随系统主题色',
  subtitle: _getFollowSystemColorSubtitle(),
  icon: Icons.auto_awesome,
  value: ThemeManager().followSystemColor,
  onChanged: (value) async {
    await ThemeManager().setFollowSystemColor(value, context: context);
    setState(() {});
  },
),
```

---

## 📊 数据存储

### SharedPreferences 键名

| 键名 | 类型 | 说明 | 默认值 |
|------|------|------|--------|
| `follow_system_color` | bool | 是否跟随系统主题色 | `true` |
| `seed_color` | int | 当前主题色值 | `Colors.deepPurple.value` |
| `theme_mode` | int | 主题模式（亮色/暗色/系统） | `0` |

### 存储位置

| 平台 | 存储路径 |
|------|---------|
| **Windows** | `可执行文件目录/data/app_settings_backup.json` |
| **Android** | 应用私有目录 |

---

## 🎨 用户体验

### 默认行为

**首次安装**：
1. 应用启动
2. 自动检测平台
3. 如果是 Android 12+ 或 Windows 11
4. 尝试获取系统主题色
5. 应用到界面

**手动选择颜色后**：
1. 用户点击主题色选择器
2. 选择任意颜色
3. 系统自动关闭跟随功能
4. 提示用户：已切换到自定义主题色

### 视觉反馈

**跟随系统时**：
- 主题色选项显示为：`系统主题色 (当前跟随系统)`
- 主题色选择器显示锁图标 🔒
- 点击主题色选择器不会响应

**自定义颜色时**：
- 主题色选项显示：`深紫色` 或其他预设名称
- 主题色选择器正常可点击
- 可以自由选择颜色

---

## 🐛 已知限制

### Android

1. **Android 11及以下不支持**
   - Material You 是 Android 12 新增功能
   - 旧版本会使用默认颜色

2. **需要重启应用才能更新**
   - 更换壁纸后需要重启应用
   - 未来版本可能支持监听壁纸变化

### Windows

1. **当前使用默认颜色**
   - 尚未实现读取真实系统强调色
   - 所有用户看到相同的蓝色

2. **需要平台通道实现**
   - 需要 Windows 端的原生代码
   - 计划在未来版本中实现

---

## 🚀 未来计划

### 短期计划 (v1.1)

- [x] Windows 平台读取真实系统强调色 ✅ **已完成**
- [ ] Android 监听壁纸变化自动更新
- [ ] 添加主题色预览功能

### 中期计划 (v1.2)

- [ ] macOS 系统强调色支持
- [ ] Linux 桌面环境主题色适配
- [ ] 主题色历史记录

### 长期计划 (v2.0)

- [ ] 自定义色板生成
- [ ] 主题色分享功能
- [ ] 主题包导入/导出

---

## 💡 用户建议

### 如何获得最佳体验

1. **Android 用户**：
   - 使用 Android 12 或更高版本
   - 选择一张颜色鲜明的壁纸
   - 在系统设置中启用"主题颜色"功能

2. **Windows 用户**：
   - 如果喜欢默认蓝色，开启跟随系统即可
   - 如果想要其他颜色，手动选择预设颜色

3. **所有用户**：
   - 首次安装时体验跟随系统功能
   - 如不满意，随时可以手动选择颜色
   - 尝试不同的主题色找到最适合的

---

## 📚 相关资源

### 官方文档

- [Material You 设计规范](https://m3.material.io/styles/color/overview)
- [Android 动态颜色指南](https://developer.android.com/develop/ui/views/theming/dynamic-colors)
- [Windows 11 设计系统](https://learn.microsoft.com/en-us/windows/apps/design/)

### 依赖包

- [`dynamic_color`](https://pub.dev/packages/dynamic_color) - Material You 动态颜色支持
- [`shared_preferences`](https://pub.dev/packages/shared_preferences) - 本地数据存储

### 源代码

- `lib/services/system_theme_color_service.dart` - 系统主题色服务
- `lib/utils/theme_manager.dart` - 主题管理器
- `lib/pages/settings_page.dart` - 设置页面

---

## 📝 更新日志

### v1.0.3 (2025-10-04)

✨ **新增功能**
- 新增"跟随系统主题色"功能
- Android 12+ 支持 Material You 动态颜色
- Windows 支持系统强调色（从注册表读取真实颜色）
- 默认启用跟随系统主题色

🔧 **技术改进**
- 重构主题管理系统
- 添加系统主题色服务
- 实现 Windows 平台通道读取注册表
- 优化主题切换动画

🐛 **问题修复**
- 修复 Windows 平台使用硬编码默认颜色的问题
- 现在可以正确读取用户在"个性化"中设置的强调色

---

## 🙏 致谢

感谢以下开源项目的支持：
- Flutter Team - 提供优秀的跨平台框架
- Material Design Team - 提供 Material You 设计系统
- dynamic_color Package - 简化 Android 动态颜色实现

---

**享受个性化的主题体验！** 🎨✨


