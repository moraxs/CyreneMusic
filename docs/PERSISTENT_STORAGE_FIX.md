# Windows 平台数据持久化修复方案

## 问题描述

在 Windows 平台下，应用数据（已登录的账号、偏好设置等）会在一段时间后丢失，恢复成默认设置。

### 原因分析

1. **SharedPreferences 在 Windows 上的不稳定性**
   - Windows 平台的 `shared_preferences` 插件使用本地文件存储
   - 文件可能因为权限问题、系统清理或其他原因被删除
   - 数据写入可能不及时，应用崩溃时数据丢失

2. **缺少备份机制**
   - 原有实现仅依赖单一存储方式
   - 没有数据恢复机制

## 解决方案

### 1. 持久化存储服务 (`PersistentStorageService`)

创建了一个新的持久化存储服务，采用**双重存储策略**：

#### 存储策略

```
┌─────────────────────────────────────────┐
│    应用数据存储（双重保障）              │
│                                          │
│  ┌────────────────────────────────┐     │
│  │  SharedPreferences             │     │
│  │  (内存 + 文件/注册表)          │     │
│  └────────────┬───────────────────┘     │
│               │                          │
│               │ 自动同步                 │
│               │                          │
│  ┌────────────▼───────────────────┐     │
│  │  备份文件                       │     │
│  │  app_settings_backup.json      │     │
│  │  (Windows: exe同目录/data/)    │     │
│  └────────────────────────────────┘     │
│                                          │
└─────────────────────────────────────────┘
```

#### 工作机制

1. **初始化时**：
   - 加载 SharedPreferences
   - 检查备份文件
   - 如果检测到数据丢失，自动从备份恢复

2. **写入时**：
   - 先写入 SharedPreferences
   - 同步更新备份文件
   - 确保数据双重保存

3. **读取时**：
   - 优先从 SharedPreferences 读取
   - 如果数据不存在且备份中有，自动恢复

### 2. 备份文件位置

| 平台 | 备份路径 |
|------|---------|
| **Windows** | `可执行文件目录/data/app_settings_backup.json` |
| **Android** | 应用文档目录 |
| **其他** | 应用支持目录 |

**Windows 示例**：
```
D:\work\cyrene_music\build\windows\x64\runner\Debug\
├── cyrene_music.exe
├── data\
│   └── app_settings_backup.json  ← 备份文件
└── music_cache\                  ← 音乐缓存
```

### 3. 使用方法

#### 初始化（已在 `main.dart` 中完成）

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 必须最先初始化
  await PersistentStorageService().initialize();
  
  // 其他初始化...
}
```

#### 在服务中使用（推荐方式）

**方式 A：直接使用持久化服务**（推荐）

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'persistent_storage_service.dart';

class MyService extends ChangeNotifier {
  // 加载设置
  Future<void> _loadSettings() async {
    try {
      final storage = PersistentStorageService();
      
      // 读取数据
      final value = storage.getString('my_key');
      final count = storage.getInt('my_count') ?? 0;
      final enabled = storage.getBool('my_enabled') ?? false;
      
      print('✅ 从本地加载设置');
    } catch (e) {
      print('❌ 加载设置失败: $e');
    }
  }

  // 保存设置
  Future<void> _saveSettings() async {
    try {
      final storage = PersistentStorageService();
      
      // 写入数据（自动备份）
      await storage.setString('my_key', 'value');
      await storage.setInt('my_count', 100);
      await storage.setBool('my_enabled', true);
      
      print('💾 设置已保存并备份');
    } catch (e) {
      print('❌ 保存设置失败: $e');
    }
  }
}
```

**方式 B：使用原始 SharedPreferences（向后兼容）**

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'persistent_storage_service.dart';

class MyService extends ChangeNotifier {
  Future<void> _saveSettings() async {
    try {
      // 使用传统方式
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('my_key', 'value');
      
      // 手动触发备份
      await PersistentStorageService().forceBackup();
      
      print('💾 设置已保存');
    } catch (e) {
      print('❌ 保存设置失败: $e');
    }
  }
}
```

### 4. 迁移现有服务（可选）

如果想要获得最佳的数据持久化保障，建议迁移现有服务：

**原代码**：
```dart
Future<void> _saveUserToStorage(User user) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', jsonEncode(user.toJson()));
    print('💾 用户信息已保存到本地');
  } catch (e) {
    print('❌ 保存用户信息失败: $e');
  }
}
```

**新代码**：
```dart
Future<void> _saveUserToStorage(User user) async {
  try {
    final storage = PersistentStorageService();
    await storage.setString('current_user', jsonEncode(user.toJson()));
    print('💾 用户信息已保存到本地（并已备份）');
  } catch (e) {
    print('❌ 保存用户信息失败: $e');
  }
}

Future<void> _loadUserFromStorage() async {
  try {
    final storage = PersistentStorageService();
    final userJson = storage.getString('current_user');
    
    if (userJson != null && userJson.isNotEmpty) {
      final userData = jsonDecode(userJson);
      _currentUser = User.fromJson(userData);
      _isLoggedIn = true;
      print('👤 从本地存储加载用户: ${_currentUser?.username}');
      notifyListeners();
    }
  } catch (e) {
    print('❌ 加载用户信息失败: $e');
  }
}
```

### 5. 调试和诊断

#### 查看存储统计

```dart
final stats = PersistentStorageService().getBackupStats();
print('存储统计: $stats');

// 输出示例：
// {
//   'sharedPreferences_keys': 15,
//   'backup_keys': 15,
//   'backup_file_path': 'D:/work/cyrene_music/build/.../data/app_settings_backup.json',
//   'backup_file_exists': true
// }
```

#### 手动触发备份

```dart
await PersistentStorageService().forceBackup();
print('💾 强制备份完成');
```

#### 检查备份文件

Windows 平台可以直接查看备份文件：
```bash
# 进入可执行文件目录
cd build/windows/x64/runner/Debug/

# 查看备份文件
type data\app_settings_backup.json
```

### 6. 最佳实践

#### ✅ 推荐做法

1. **在应用启动时初始化持久化服务**
   ```dart
   await PersistentStorageService().initialize();
   ```

2. **使用持久化服务的封装方法**
   ```dart
   await storage.setString(key, value);  // 自动备份
   ```

3. **关键数据修改后立即保存**
   ```dart
   // 登录成功
   _currentUser = user;
   await _saveUserToStorage(user);  // 立即保存
   ```

4. **在应用退出前强制备份**（已在 `TrayService` 中实现）
   ```dart
   await PersistentStorageService().forceBackup();
   ```

#### ❌ 避免的做法

1. **不要频繁创建 SharedPreferences 实例**
   ```dart
   // ❌ 错误：每次都创建新实例
   final prefs1 = await SharedPreferences.getInstance();
   final prefs2 = await SharedPreferences.getInstance();
   
   // ✅ 正确：使用持久化服务的单例
   final storage = PersistentStorageService();
   ```

2. **不要忘记等待保存完成**
   ```dart
   // ❌ 错误：没有 await
   storage.setString('key', 'value');
   exit(0);  // 数据可能丢失
   
   // ✅ 正确：等待保存完成
   await storage.setString('key', 'value');
   exit(0);
   ```

### 7. 测试验证

#### 测试步骤

1. **正常保存测试**
   - 登录账号，修改设置
   - 关闭应用，再次打开
   - 验证数据是否保留

2. **数据丢失恢复测试**
   - 登录账号，修改设置
   - 找到备份文件位置（见上文）
   - 删除 SharedPreferences 数据（或重命名）
   - 重启应用
   - 验证数据是否从备份恢复

3. **备份文件验证**
   ```bash
   # Windows
   cd build/windows/x64/runner/Debug/
   type data\app_settings_backup.json
   
   # 应该能看到类似内容：
   # {
   #   "current_user": "{\"id\":1,\"email\":\"...\",\"username\":\"...\"}",
   #   "theme_mode": 0,
   #   "seed_color": 4280391411,
   #   "cache_enabled": true,
   #   ...
   # }
   ```

### 8. 技术细节

#### SharedPreferences 在 Windows 的实现

- **存储位置**：`%LOCALAPPDATA%\<package_name>\shared_preferences\`
- **文件格式**：JSON 文件
- **问题**：可能被系统清理或权限限制

#### 备份策略

- **双重保险**：SharedPreferences + JSON 文件
- **自动恢复**：启动时检测并恢复
- **即时备份**：每次写入都更新备份
- **容错机制**：备份失败不影响正常功能

### 9. 性能考虑

- **读取性能**：优先从内存读取（SharedPreferences），性能无损
- **写入性能**：每次写入会同步更新备份文件，轻微性能开销
- **备份文件大小**：通常 < 10 KB，可忽略

### 10. 常见问题

**Q: 会不会导致数据不一致？**
A: 不会。写入操作是原子的，先写 SharedPreferences，成功后再写备份。

**Q: 备份文件会被用户看到吗？**
A: 在 Windows 上，备份文件在 `data` 子目录下，普通用户不会注意到。

**Q: 需要手动删除旧备份吗？**
A: 不需要，备份文件会自动更新，始终保持最新状态。

**Q: Android 平台也会受益吗？**
A: 是的，所有平台都使用相同的备份机制。

## 总结

通过实现 `PersistentStorageService`，应用现在具备：

✅ **双重存储保障**：SharedPreferences + 备份文件  
✅ **自动数据恢复**：启动时检测并恢复丢失的数据  
✅ **即时备份机制**：每次写入都自动备份  
✅ **跨平台支持**：Windows、Android 等所有平台  
✅ **向后兼容**：现有代码无需修改也能工作  

这样可以有效解决 Windows 平台下数据丢失的问题，确保用户的账号和设置长久保存。

