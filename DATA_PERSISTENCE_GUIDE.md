# 数据持久化功能说明

## 📝 概述

已为 Cyrene Music 添加完整的数据持久化功能，使用 `shared_preferences` 包来保存用户设置和登录状态。现在应用重启后会自动恢复所有设置。

## ✅ 已实现的持久化功能

### 1. 用户认证状态 (AuthService)

**保存的数据**:
- ✅ 用户登录信息（用户名、邮箱、ID 等）
- ✅ 登录状态

**存储键名**:
- `current_user` - 用户信息 JSON 字符串

**行为**:
- 登录成功时自动保存用户信息
- 退出登录时自动清除用户信息
- 应用启动时自动恢复登录状态

### 2. 主题设置 (ThemeManager)

**保存的数据**:
- ✅ 主题模式（浅色/深色/跟随系统）
- ✅ 主题色（自定义颜色）

**存储键名**:
- `theme_mode` - 主题模式索引 (0=light, 1=dark, 2=system)
- `seed_color` - 主题色值 (int)

**行为**:
- 切换主题模式时自动保存
- 更改主题色时自动保存
- 应用启动时自动恢复主题设置

### 3. 后端源配置 (UrlService)

**保存的数据**:
- ✅ 后端源类型（官方源/自定义源）
- ✅ 自定义后端地址

**存储键名**:
- `backend_source_type` - 源类型索引 (0=official, 1=custom)
- `custom_base_url` - 自定义源地址字符串

**行为**:
- 切换后端源时自动保存
- 设置自定义地址时自动保存
- 应用启动时自动恢复后端配置

### 4. 布局偏好 (LayoutPreferenceService)

**保存的数据**:
- ✅ 布局模式（桌面模式/移动模式）- 仅 Windows 平台

**存储键名**:
- `layout_mode` - 布局模式索引 (0=desktop, 1=mobile)

**行为**:
- 切换布局模式时自动保存
- 应用启动时自动恢复布局设置
- 自动调整窗口大小

## 🔧 技术实现

### 使用的包
```yaml
shared_preferences: ^2.3.3
```

### 支持的平台
- ✅ Windows
- ✅ Android
- ✅ iOS
- ✅ macOS
- ✅ Linux
- ✅ Web

### 数据存储位置

**Windows**:
- `%APPDATA%\Roaming\cyrene_music\shared_preferences\`

**Android**:
- `SharedPreferences` (系统默认位置)

**iOS/macOS**:
- `NSUserDefaults`

**Linux**:
- `~/.local/share/cyrene_music/`

**Web**:
- `LocalStorage`

## 📊 存储的数据示例

```json
{
  "current_user": "{\"id\":1,\"email\":\"user@example.com\",\"username\":\"张三\",\"isVerified\":true}",
  "theme_mode": 1,
  "seed_color": 4288423856,
  "backend_source_type": 0,
  "custom_base_url": "",
  "layout_mode": 0
}
```

## 🎯 使用方式

### 作为用户

无需任何操作！所有设置都会**自动保存**和**自动恢复**：

1. **登录账号** → 下次启动自动登录
2. **切换主题** → 下次启动保持主题
3. **更改后端源** → 下次启动保持配置
4. **切换布局模式** → 下次启动保持布局

### 作为开发者

如果需要添加新的持久化数据：

```dart
// 1. 导入 shared_preferences
import 'package:shared_preferences/shared_preferences.dart';

// 2. 在服务的构造函数中加载数据
MyService._internal() {
  _loadSettings();
}

// 3. 实现加载方法
Future<void> _loadSettings() async {
  final prefs = await SharedPreferences.getInstance();
  _myValue = prefs.getString('my_key') ?? 'default';
  notifyListeners();
}

// 4. 实现保存方法
Future<void> _saveSettings() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('my_key', _myValue);
}

// 5. 在数据变化时调用保存
void setMyValue(String value) {
  _myValue = value;
  _saveSettings();
  notifyListeners();
}
```

## 🗑️ 清除数据

如果需要清除所有保存的数据：

### 方法1: 通过代码

```dart
final prefs = await SharedPreferences.getInstance();
await prefs.clear(); // 清除所有数据
```

### 方法2: 手动删除文件

**Windows**: 删除 `%APPDATA%\Roaming\cyrene_music\` 文件夹

**Android**: 在设置中清除应用数据

**Linux**: 删除 `~/.local/share/cyrene_music/` 文件夹

## 🐛 调试日志

应用会在控制台输出详细的持久化日志：

```
👤 [AuthService] 从本地存储加载用户: 张三
🎨 [ThemeManager] 从本地加载主题: dark, 主题色: 0xff9c27b0
🌐 [UrlService] 从本地加载配置: official, 自定义源: 
🖥️ [LayoutPreference] 从本地加载布局: desktop
💾 [AuthService] 用户信息已保存到本地
💾 [ThemeManager] 主题模式已保存: dark
💾 [UrlService] 源类型已保存: custom
💾 [LayoutPreference] 布局模式已保存: mobile
```

## ⚡ 性能优化

- ✅ 数据加载是异步的，不会阻塞 UI
- ✅ 只在数据变化时保存，避免不必要的 I/O
- ✅ 使用单例模式，避免重复初始化
- ✅ 所有服务在构造函数中自动加载数据

## 🔐 数据安全

**注意**: `shared_preferences` 以**明文**方式存储数据，不适合存储敏感信息（如密码、Token）。

当前存储的数据都是非敏感信息：
- ✅ 用户名、邮箱（公开信息）
- ✅ 主题设置（UI 偏好）
- ✅ 后端源地址（配置信息）

**如需存储敏感数据**，建议使用：
- `flutter_secure_storage` - 加密存储
- `hive` + 加密 - 本地数据库加密

## 📚 相关资源

- [shared_preferences 官方文档](https://pub.dev/packages/shared_preferences)
- [Flutter 数据持久化指南](https://docs.flutter.dev/cookbook/persistence)

## ✨ 更新日志

**2025-10-01**:
- ✅ 添加用户登录状态持久化
- ✅ 添加主题设置持久化
- ✅ 添加后端源配置持久化
- ✅ 添加布局偏好持久化
- ✅ 所有设置支持跨平台自动保存和恢复

