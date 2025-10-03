# 窗口控制优化

## 🎯 优化内容

### 1. 全屏播放器添加窗口控制按钮
- ✅ 右上角添加最小化、最大化、关闭按钮
- ✅ 与主窗口逻辑保持一致
- ✅ 支持鼠标悬停效果

### 2. 移除主窗口边框阴影
- ✅ 删除 `boxShadow` 效果
- ✅ 界面更简洁

### 3. 最大化时无圆角
- ✅ 主窗口：最大化时无圆角和边距
- ✅ 播放器：最大化时无圆角
- ✅ 动态检测窗口状态

## 🎨 界面效果

### 全屏播放器顶部栏

#### 正常状态
```
┌─────────────────────────────────────────┐
│ ↓ 返回              [－] [□] [×]        │
└─────────────────────────────────────────┘
```

#### 最大化状态
```
┌─────────────────────────────────────────┐
│ ↓ 返回              [－] [⧉] [×]        │
└─────────────────────────────────────────┘
```

### 窗口圆角

#### 正常状态
```
┌──────────────┐
│              │ ← 有圆角 (12px)
│   主窗口     │   有边距 (8px)
│              │
└──────────────┘
```

#### 最大化状态
```
┌──────────────┐
│              │ ← 无圆角
│   主窗口     │   无边距
│              │
└──────────────┘
```

## 🔧 技术实现

### 1. 播放器页面添加窗口控制

#### 状态监听
```dart
class _PlayerPageState extends State<PlayerPage> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximizedState();
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }
}
```

#### 窗口控制按钮
```dart
Widget _buildWindowButtons() {
  return Row(
    children: [
      _buildWindowButton(
        icon: Icons.remove,
        onPressed: () => appWindow.minimize(),
        tooltip: '最小化',
      ),
      _buildWindowButton(
        icon: _isMaximized ? Icons.fullscreen_exit : Icons.crop_square,
        onPressed: () => appWindow.maximizeOrRestore(),
        tooltip: _isMaximized ? '还原' : '最大化',
      ),
      _buildWindowButton(
        icon: Icons.close,
        onPressed: () => windowManager.close(),
        tooltip: '关闭',
        isClose: true,
      ),
    ],
  );
}
```

#### 单个按钮
```dart
Widget _buildWindowButton({
  required IconData icon,
  required VoidCallback onPressed,
  required String tooltip,
  bool isClose = false,
}) {
  return InkWell(
    onTap: onPressed,
    hoverColor: isClose ? Colors.red : Colors.white.withOpacity(0.1),
    child: Container(
      width: 48,
      height: 56,
      child: Icon(icon, size: 18, color: Colors.white),
    ),
  );
}
```

### 2. 动态圆角

#### 播放器页面
```dart
ClipRRect(
  borderRadius: _isMaximized 
      ? BorderRadius.zero      // 最大化：无圆角
      : BorderRadius.circular(16),  // 正常：16px 圆角
  child: ...
)
```

#### 主窗口
```dart
Padding(
  padding: _isMaximized ? EdgeInsets.zero : const EdgeInsets.all(8.0),
  child: Container(
    decoration: BoxDecoration(
      borderRadius: _isMaximized ? BorderRadius.zero : BorderRadius.circular(12),
      // 移除 boxShadow
    ),
    child: ClipRRect(
      borderRadius: _isMaximized ? BorderRadius.zero : BorderRadius.circular(12),
      child: child,
    ),
  ),
)
```

### 3. 移除阴影效果

**之前：**
```dart
decoration: BoxDecoration(
  borderRadius: BorderRadius.circular(12),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 30,
      spreadRadius: 0,
      offset: const Offset(0, 10),
    ),
  ],
)
```

**现在：**
```dart
decoration: BoxDecoration(
  borderRadius: _isMaximized ? BorderRadius.zero : BorderRadius.circular(12),
  // 移除阴影效果
)
```

## 🎮 按钮功能

| 按钮 | 图标 | 功能 | 悬停颜色 |
|------|------|------|---------|
| 最小化 | ➖ | `appWindow.minimize()` | 半透明白色 |
| 最大化 | ☐ | `appWindow.maximizeOrRestore()` | 半透明白色 |
| 还原 | ⧉ | `appWindow.maximizeOrRestore()` | 半透明白色 |
| 关闭 | ✕ | `windowManager.close()` | 红色 |

## 📊 窗口状态转换

```
正常窗口状态
    ↓
点击最大化按钮
    ↓
onWindowMaximize() 触发
    ↓
setState(() => _isMaximized = true)
    ↓
重新构建
    ├─ 边距：8px → 0px
    ├─ 圆角：12px → 0px
    └─ 按钮图标：□ → ⧉
    ↓
窗口填满屏幕
```

## 🎨 视觉效果

### 主窗口

#### 优化前
- 有阴影效果（黑色，30px 模糊）
- 固定圆角（12px）

#### 优化后
- ✅ 无阴影（简洁）
- ✅ 动态圆角（最大化时无圆角）
- ✅ 动态边距（最大化时无边距）

### 全屏播放器

#### 优化前
- 左上角：返回按钮
- 右上角：无
- 固定圆角

#### 优化后
- ✅ 左上角：返回按钮
- ✅ 右上角：最小化、最大化、关闭按钮
- ✅ 动态圆角（最大化时无圆角）

## 🧪 测试步骤

### 测试 1：主窗口
1. 启动应用
2. 观察：应该无阴影效果
3. 点击最大化按钮
4. 观察：边框圆角消失，窗口填满屏幕
5. 点击还原按钮
6. 观察：恢复圆角和边距

### 测试 2：播放器窗口
1. 打开全屏播放器
2. 观察：右上角有三个控制按钮
3. 点击最小化：窗口最小化
4. 恢复窗口，点击最大化
5. 观察：播放器圆角消失，按钮图标变为还原
6. 点击还原：恢复圆角
7. 点击关闭：窗口关闭（最小化到托盘）

### 测试 3：按钮交互
1. 鼠标悬停在最小化按钮
   - 预期：显示半透明白色背景
2. 鼠标悬停在最大化按钮
   - 预期：显示半透明白色背景
3. 鼠标悬停在关闭按钮
   - 预期：显示红色背景

## 📝 代码改动

### 修改的文件
1. **lib/pages/player_page.dart**
   - ✅ 添加 `WindowListener` mixin
   - ✅ 添加 `_isMaximized` 状态
   - ✅ 添加窗口状态监听
   - ✅ 添加窗口控制按钮组件
   - ✅ 动态调整圆角

2. **lib/main.dart**
   - ✅ `_WindowsRoundedContainer` 改为 StatefulWidget
   - ✅ 添加 `WindowListener` mixin
   - ✅ 添加最大化状态监听
   - ✅ 移除 `boxShadow`
   - ✅ 动态调整边距和圆角

## 🎉 优化效果

### 视觉效果
- ✨ **更简洁**：无阴影，界面更清爽
- 🎯 **更统一**：主窗口和播放器按钮一致
- 🖥️ **更专业**：符合 Windows 设计规范

### 功能完善
- ✅ 播放器支持完整的窗口控制
- ✅ 最大化时自动调整显示
- ✅ 用户体验更好

### 性能提升
- ⚡ 移除阴影渲染（减少 GPU 负担）
- 💾 减少内存占用

---

**版本**: v3.7  
**日期**: 2025-10-03  
**状态**: ✅ 已完成  
**改进**: 窗口控制完善 + 无阴影 + 动态圆角

