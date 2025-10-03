# 更新忽略功能说明

## 📋 功能概述

用户可以选择"稍后提醒"来忽略某个版本的更新，之后只有当有更新的版本时才会再次提示。

### 核心逻辑

```
用户当前版本: 1.0.0
后端最新版本: 1.0.2

第1次进入首页:
  → 弹出更新提示 (1.0.0 → 1.0.2)
  → 用户点击"稍后提醒"
  → 保存忽略版本: 1.0.2

第2次进入首页:
  → 检测到最新版本: 1.0.2
  → 检查忽略版本: 1.0.2
  → 1.0.2 == 1.0.2 (相同版本)
  → ❌ 不提示

后端发布新版本: 1.0.3

第3次进入首页:
  → 检测到最新版本: 1.0.3
  → 检查忽略版本: 1.0.2
  → 1.0.3 > 1.0.2 (有更新)
  → ✅ 弹出更新提示 (1.0.0 → 1.0.3)
```

---

## 🎯 用户体验流程

### 场景 1：普通更新（非强制）

#### 第一次看到更新
```
1. 用户打开应用，进入首页
2. 延迟 2 秒后，弹出更新对话框
   ┌─────────────────────────────┐
   │ 🔄 发现新版本               │
   │                             │
   │ 最新版本: 1.0.2             │
   │ 当前版本: 1.0.0             │
   │                             │
   │ 更新内容：                  │
   │ - 支持安卓平台              │
   │ - 修复了一些bug             │
   │                             │
   │ [稍后提醒]  [立即更新]     │
   └─────────────────────────────┘
```

#### 用户点击"稍后提醒"
```
3. 点击"稍后提醒"按钮
4. 保存忽略版本: 1.0.2
5. 显示提示：
   "已忽略版本 1.0.2，有新版本时将再次提醒"
6. 对话框关闭
```

#### 之后的行为
```
情况 A：后端版本仍为 1.0.2
  → 用户每天打开应用
  → ❌ 不再弹出更新提示
  → ✅ 正常使用

情况 B：后端版本更新为 1.0.3
  → 用户打开应用
  → ✅ 弹出新版本更新提示
  → 显示：1.0.0 → 1.0.3
```

---

### 场景 2：强制更新

#### 强制更新行为
```
1. 后端设置: force_update: true
2. 用户打开应用
3. 弹出更新对话框（无法关闭）
   ┌─────────────────────────────┐
   │ 🔄 发现新版本               │
   │                             │
   │ 最新版本: 2.0.0             │
   │ 当前版本: 1.0.0             │
   │                             │
   │ 更新内容：                  │
   │ - 修复严重安全漏洞          │
   │                             │
   │ ┌─────────────────────────┐ │
   │ │⚠️ 此版本为强制更新      │ │
   │ │   请立即更新            │ │
   │ └─────────────────────────┘ │
   │                             │
   │         [立即更新]          │ ← 只有一个按钮
   └─────────────────────────────┘
```

**特点**：
- ❌ 没有"稍后提醒"按钮
- ❌ 无法点击外部关闭
- ❌ 不会保存到忽略列表
- ✅ 每次打开应用都会提示（直到用户更新）

---

## 🔧 技术实现

### 数据存储

使用 `SharedPreferences` 存储忽略的版本号：

```dart
// 键名
'ignored_update_version'

// 存储示例
SharedPreferences.setString('ignored_update_version', '1.0.2')

// 读取示例
final ignoredVersion = prefs.getString('ignored_update_version') ?? '';
```

### 核心方法

#### 1. shouldShowUpdateDialog
```dart
/// 检查是否应该提示更新
Future<bool> shouldShowUpdateDialog(VersionInfo versionInfo) async {
  // 强制更新：总是提示
  if (versionInfo.forceUpdate) {
    return true;
  }

  // 检查忽略版本
  final ignoredVersion = prefs.getString('ignored_update_version') ?? '';
  
  if (ignoredVersion.isNotEmpty) {
    // 比较版本号
    final comparison = _compareVersions(versionInfo.version, ignoredVersion);
    
    if (comparison <= 0) {
      // 最新版本 <= 忽略版本：不提示
      return false;
    } else {
      // 最新版本 > 忽略版本：提示
      return true;
    }
  }

  return true;
}
```

#### 2. ignoreCurrentVersion
```dart
/// 忽略当前版本
Future<void> ignoreCurrentVersion(String version) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('ignored_update_version', version);
  print('🔕 已忽略版本: $version');
}
```

#### 3. clearIgnoredVersion
```dart
/// 清除忽略的版本（用于测试）
Future<void> clearIgnoredVersion() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('ignored_update_version');
  print('✅ 已清除忽略的版本');
}
```

---

## 📊 版本比较逻辑

### 比较规则

```dart
_compareVersions(v1, v2)
  > 0  表示 v1 > v2
  = 0  表示 v1 == v2
  < 0  表示 v1 < v2
```

### 示例

| 最新版本 | 忽略版本 | 比较结果 | 是否提示 |
|---------|---------|---------|---------|
| 1.0.2 | 1.0.2 | 0 (相等) | ❌ 不提示 |
| 1.0.1 | 1.0.2 | -1 (小于) | ❌ 不提示 |
| 1.0.3 | 1.0.2 | 1 (大于) | ✅ 提示 |
| 1.1.0 | 1.0.2 | 1 (大于) | ✅ 提示 |
| 2.0.0 | 1.0.2 | 1 (大于) | ✅ 提示 |

---

## 🧪 测试场景

### 测试 1：忽略功能基本测试

#### 步骤
1. 设置后端版本为 `1.0.2`
2. 设置前端版本为 `1.0.0`
3. 清除忽略缓存：
   ```dart
   await VersionService().clearIgnoredVersion();
   ```
4. 打开应用
5. **预期**：弹出更新对话框 ✅
6. 点击"稍后提醒"
7. **预期**：显示"已忽略版本 1.0.2" ✅
8. 重启应用
9. **预期**：不再弹出对话框 ❌

#### 验证日志
```
第1次打开:
✅ [VersionService] 发现新版本！
(用户点击"稍后提醒")
🔕 [VersionService] 已忽略版本: 1.0.2

第2次打开:
🔕 [VersionService] 用户已忽略版本 1.0.2，当前版本 1.0.2 不更新
🔕 [HomePage] 用户已忽略此版本，不再提示
```

---

### 测试 2：有更新的版本

#### 步骤
1. 保持前端版本 `1.0.0`
2. 保持忽略版本 `1.0.2`
3. **修改后端版本为 `1.0.3`**
4. 重启应用，进入首页
5. **预期**：弹出更新对话框（1.0.3）✅

#### 验证日志
```
✅ [VersionService] 发现新版本 1.0.3，大于已忽略版本 1.0.2
(弹出对话框)
```

---

### 测试 3：强制更新不受影响

#### 步骤
1. 保持忽略版本 `1.0.2`
2. 后端设置：
   ```typescript
   version: "1.0.2",
   force_update: true,  // ← 强制更新
   ```
3. 打开应用
4. **预期**：弹出强制更新对话框 ✅
5. **预期**：没有"稍后提醒"按钮 ✅

#### 验证日志
```
✅ [VersionService] 强制更新，忽略已保存的版本
(弹出强制更新对话框)
```

---

### 测试 4：清除忽略版本

#### 步骤
1. 用户已忽略版本 `1.0.2`
2. 在开发者模式或设置中提供清除功能：
   ```dart
   await VersionService().clearIgnoredVersion();
   ```
3. 重启应用，进入首页
4. **预期**：再次弹出 1.0.2 的更新对话框 ✅

---

## 🔍 日志说明

### 忽略版本相关日志

```dart
// 忽略版本时
🔕 [VersionService] 已忽略版本: 1.0.2

// 检测到已忽略（相同版本）
🔕 [VersionService] 用户已忽略版本 1.0.2，当前版本 1.0.2 不更新
🔕 [HomePage] 用户已忽略此版本，不再提示

// 检测到新版本（大于忽略版本）
✅ [VersionService] 发现新版本 1.0.3，大于已忽略版本 1.0.2

// 清除忽略版本
✅ [VersionService] 已清除忽略的版本

// 错误日志
❌ [VersionService] 保存忽略版本失败: ...
❌ [VersionService] 检查忽略版本失败: ...
```

---

## 🛠️ 调试技巧

### 1. 查看当前忽略的版本

```dart
final prefs = await SharedPreferences.getInstance();
final ignoredVersion = prefs.getString('ignored_update_version');
print('当前忽略版本: $ignoredVersion');
```

### 2. 手动设置忽略版本

```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString('ignored_update_version', '1.0.2');
```

### 3. 清除忽略版本（测试用）

```dart
await VersionService().clearIgnoredVersion();
// 或
final prefs = await SharedPreferences.getInstance();
await prefs.remove('ignored_update_version');
```

### 4. 完全重置（清除所有更新相关缓存）

```dart
final prefs = await SharedPreferences.getInstance();
await prefs.remove('ignored_update_version');
```

---

## ⚙️ 配置选项

### 检查时机

当前设置为 **每次进入首页都检查更新**：

```dart
// lib/pages/home_page.dart
void initState() {
  super.initState();
  // ... 其他初始化 ...
  
  // 🔍 每次进入首页时检查更新
  _checkForUpdateOnce();
}
```

**不会重复提示的原因**：
- 用户点击"稍后提醒"后，会保存忽略版本
- 只有当后端发布更新的版本时才再次提示
- 强制更新不受此限制，每次都会提示

### 延迟时间

当前设置为 **延迟 2 秒检查**：

```dart
await Future.delayed(const Duration(seconds: 2));
```

**修改为立即检查**：
```dart
await Future.delayed(const Duration(milliseconds: 100));
```

**修改为 5 秒**：
```dart
await Future.delayed(const Duration(seconds: 5));
```

---

## 📋 用户设置界面（未来功能）

### 可选的设置项

```dart
// 在设置页面添加
ListTile(
  title: Text('更新检查'),
  subtitle: Text('管理应用更新设置'),
  onTap: () => _showUpdateSettings(),
)

// 更新设置对话框
_showUpdateSettings() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('更新设置'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: Text('自动检查更新'),
            value: true,
            onChanged: (value) {},
          ),
          ListTile(
            title: Text('清除忽略的版本'),
            trailing: Icon(Icons.delete),
            onTap: () async {
              await VersionService().clearIgnoredVersion();
              // 显示成功提示
            },
          ),
          ListTile(
            title: Text('立即检查更新'),
            trailing: Icon(Icons.refresh),
            onTap: () async {
              // 手动触发检查
              final versionInfo = await VersionService().checkForUpdate();
              // 显示结果
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('关闭'),
        ),
      ],
    ),
  );
}
```

---

## ✅ 总结

### 核心特性

1. **智能忽略**：用户忽略某版本后，只有更新版本才提示 ✅
2. **强制更新**：强制更新不受忽略逻辑影响 ✅
3. **持久化**：忽略记录保存在本地，重启应用有效 ✅
4. **用户友好**：提示用户已忽略版本，明确告知下次提醒条件 ✅

### 版本提示规则

| 条件 | 行为 |
|------|------|
| 首次发现更新 | ✅ 提示 |
| 用户点击"稍后提醒" | 🔕 保存忽略版本 |
| 再次检测到相同版本 | ❌ 不提示 |
| 检测到更新的版本 | ✅ 提示新版本 |
| 强制更新 | ✅ 总是提示 |

### 存储的数据

```
ignored_update_version  → 用户忽略的版本号 (如 "1.0.2")
```

**说明**：
- 每次进入首页都会检查更新
- 不需要存储检查时间
- 只通过忽略版本来控制是否提示

---

**最后更新**：2025-10-03  
**相关文档**：  
- [VERSION_RELEASE_GUIDE.md](./VERSION_RELEASE_GUIDE.md)  
- [AUTO_UPDATE_TEST.md](./AUTO_UPDATE_TEST.md)

