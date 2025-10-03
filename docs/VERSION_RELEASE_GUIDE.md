# 版本发布指南

## 📋 发布新版本的完整步骤

每次发布新版本时，需要更新以下 3 个地方的版本号：

### 1️⃣ 更新前端版本（Flutter）

#### 文件 1：`lib/services/version_service.dart`

```dart
/// ⚠️⚠️⚠️ 应用当前版本（硬编码）⚠️⚠️⚠️
/// 发布新版本时 **必须** 手动更新此值！
static const String kAppVersion = '1.0.0';  // ← 修改这里
```

**修改示例**：
```dart
// 从 1.0.0 更新到 1.0.1
static const String kAppVersion = '1.0.1';

// 从 1.0.1 更新到 1.1.0
static const String kAppVersion = '1.1.0';

// 从 1.1.0 更新到 2.0.0
static const String kAppVersion = '2.0.0';
```

#### 文件 2：`pubspec.yaml`

```yaml
# 版本格式：major.minor.patch+buildNumber
version: 1.0.0+1  # ← 修改这里
```

**修改示例**：
```yaml
# 从 1.0.0+1 更新到 1.0.1+2
version: 1.0.1+2

# 从 1.0.1+2 更新到 1.1.0+3
version: 1.1.0+3

# 从 1.1.0+3 更新到 2.0.0+4
version: 2.0.0+4
```

**版本号说明**：
- **major（主版本号）**：重大功能更新或不兼容的 API 变更
- **minor（次版本号）**：向下兼容的功能性新增
- **patch（补丁版本号）**：向下兼容的问题修正
- **buildNumber（构建号）**：每次发布递增

### 2️⃣ 更新后端版本（Backend）

#### 文件：`backend/src/index.ts`

找到版本信息 API：

```typescript
// 版本信息
.get("/version/latest", () => {
  const versionInfo = {
    version: "1.0.2",  // ← 修改这里（最新版本）
    changelog: "- 支持安卓平台 \n - 修复了一些bug",  // ← 修改这里（更新日志）
    force_update: false,  // ← 修改这里（是否强制更新）
    download_url: "https://github.com/Chuxin-Neko/chuxinneko_music/releases/latest",  // ← 修改这里（下载链接）
  };
  return { status: 200, data: versionInfo };
})
```

**修改示例**：
```typescript
// 示例 1：普通更新（1.0.2 → 1.0.3）
const versionInfo = {
  version: "1.0.3",
  changelog: "- 优化性能\n- 修复已知问题",
  force_update: false,
  download_url: "https://github.com/YourName/YourRepo/releases/tag/v1.0.3",
};

// 示例 2：功能更新（1.0.3 → 1.1.0）
const versionInfo = {
  version: "1.1.0",
  changelog: "- 新增歌单功能\n- 支持高刷新率\n- 优化 UI 设计",
  force_update: false,
  download_url: "https://github.com/YourName/YourRepo/releases/tag/v1.1.0",
};

// 示例 3：强制更新（1.1.0 → 2.0.0）
const versionInfo = {
  version: "2.0.0",
  changelog: "- 重大架构升级\n- 修复安全问题\n- 不兼容旧版本数据",
  force_update: true,  // ← 强制更新
  download_url: "https://github.com/YourName/YourRepo/releases/tag/v2.0.0",
};
```

### 3️⃣ 重启后端服务

修改后端代码后，需要重启服务：

```bash
# 进入后端目录
cd backend

# 重启服务（使用 bun）
bun run src/index.ts
```

---

## 🎯 完整发布流程示例

假设要从 **1.0.0** 发布到 **1.0.1**：

### Step 1：更新前端代码

**`lib/services/version_service.dart`**：
```dart
static const String kAppVersion = '1.0.1';  // 1.0.0 → 1.0.1
```

**`pubspec.yaml`**：
```yaml
version: 1.0.1+2  # 1.0.0+1 → 1.0.1+2
```

### Step 2：更新后端代码

**`backend/src/index.ts`**：
```typescript
.get("/version/latest", () => {
  const versionInfo = {
    version: "1.0.1",  // 1.0.0 → 1.0.1
    changelog: "- 修复歌词同步问题\n- 优化播放性能\n- 支持高刷新率",
    force_update: false,
    download_url: "https://github.com/YourName/YourRepo/releases/tag/v1.0.1",
  };
  return { status: 200, data: versionInfo };
})
```

### Step 3：构建应用

```bash
# Android
flutter build apk --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release
```

### Step 4：创建 GitHub Release

1. 打包构建产物
2. 在 GitHub 创建新的 Release
3. 上传构建文件
4. 标签命名：`v1.0.1`
5. Release 标题：`Cyrene Music v1.0.1`
6. 描述中写入更新日志

### Step 5：重启后端服务

```bash
cd backend
bun run src/index.ts
```

### Step 6：测试更新检查

1. 打开应用
2. 进入首页
3. 等待 2 秒
4. 应该弹出更新提示对话框
5. 点击"立即更新"应该打开下载链接

---

## 📊 版本号规范

### 语义化版本控制（SemVer）

遵循格式：`MAJOR.MINOR.PATCH`

| 版本类型 | 何时递增 | 示例 |
|---------|---------|------|
| **MAJOR（主版本）** | 不兼容的 API 修改 | 1.0.0 → 2.0.0 |
| **MINOR（次版本）** | 向下兼容的功能性新增 | 1.0.0 → 1.1.0 |
| **PATCH（补丁版本）** | 向下兼容的问题修正 | 1.0.0 → 1.0.1 |

### 示例

```
1.0.0  - 首次发布
1.0.1  - 修复 Bug
1.0.2  - 再次修复 Bug
1.1.0  - 新增功能
1.1.1  - 修复新功能的 Bug
2.0.0  - 重大更新，不兼容旧版
```

---

## ⚙️ 更新日志（Changelog）格式

### 推荐格式

```
- [新增] 功能描述
- [优化] 优化描述
- [修复] 问题描述
- [变更] 变更描述
```

### 示例

```typescript
changelog: 
  "- [新增] 支持歌单功能\n" +
  "- [新增] 高刷新率支持（90Hz/120Hz）\n" +
  "- [优化] 播放器性能提升 50%\n" +
  "- [修复] 歌词同步延迟问题\n" +
  "- [修复] Android 通知栏控制失效"
```

### 多语言示例

```typescript
// 中文
changelog: "- 新增歌单功能\n- 修复已知问题"

// 英文
changelog: "- Added playlist feature\n- Fixed known issues"
```

---

## 🔐 强制更新功能

### 何时使用强制更新

- ✅ 严重安全漏洞修复
- ✅ 不兼容的 API 变更
- ✅ 数据库结构重大变更
- ✅ 关键 Bug 修复

### 如何启用强制更新

```typescript
const versionInfo = {
  version: "2.0.0",
  changelog: "- 修复严重安全漏洞\n- 必须立即更新",
  force_update: true,  // ← 设置为 true
  download_url: "...",
};
```

### 强制更新的行为

- 对话框无法关闭（没有"稍后提醒"按钮）
- 显示警告提示
- 用户必须点击"立即更新"

---

## 📝 版本检查机制

### 检查时机

- ✅ 首次进入首页（延迟 2 秒）
- ✅ 每天最多检查一次（24 小时）

### 版本比较规则

```
1.0.0 vs 1.0.1  → 需要更新（补丁版本）
1.0.1 vs 1.1.0  → 需要更新（次版本）
1.1.0 vs 2.0.0  → 需要更新（主版本）
1.0.0 vs 1.0.0  → 已是最新版本
1.0.1 vs 1.0.0  → 已是最新版本（本地更新）
```

### 跳过检查的情况

```dart
// 检查是否已经检查过
final lastCheckTime = prefs.getInt('last_update_check_time') ?? 0;
final now = DateTime.now().millisecondsSinceEpoch;

// 每天最多检查一次（24 小时 = 86400000 毫秒）
if (now - lastCheckTime < 86400000) {
  print('🔍 [HomePage] 今天已检查过更新，跳过');
  return;
}
```

---

## 🛠️ 故障排查

### 问题 1：更新提示不显示

**检查清单**：
1. 后端是否已重启？
2. 后端版本号是否大于前端？
3. 是否在 24 小时内已检查过？
4. 网络是否正常？

**解决方法**：
```bash
# 1. 检查后端日志
cd backend
bun run src/index.ts

# 2. 清除检查时间缓存（开发阶段）
# Android: 清除应用数据
# Windows: 删除 %APPDATA%/cyrene_music

# 3. 手动测试 API
curl http://127.0.0.1:4055/version/latest
```

### 问题 2：版本号显示为空

**原因**：`kAppVersion` 未设置或为空字符串

**解决方法**：
```dart
// 确保 kAppVersion 不为空
static const String kAppVersion = '1.0.0';  // ✅ 正确
static const String kAppVersion = '';      // ❌ 错误
```

### 问题 3：强制更新无法跳过

这是**正常行为**，强制更新设计为无法跳过。

如需取消强制更新：
```typescript
force_update: false,  // 改为 false
```

---

## 📚 相关文件

### 前端文件
- `lib/services/version_service.dart` - 版本检查服务
- `lib/models/version_info.dart` - 版本信息模型
- `lib/pages/home_page.dart` - 首页（检查更新入口）
- `pubspec.yaml` - 应用版本配置

### 后端文件
- `backend/src/index.ts` - 版本信息 API

### 文档文件
- `docs/VERSION_RELEASE_GUIDE.md` - 本文档

---

## ✅ 发布前检查清单

```
□ 更新 lib/services/version_service.dart 中的 kAppVersion
□ 更新 pubspec.yaml 中的 version
□ 更新 backend/src/index.ts 中的版本信息
□ 编写更新日志（changelog）
□ 更新下载链接（download_url）
□ 决定是否强制更新（force_update）
□ 构建应用（flutter build）
□ 测试更新检查功能
□ 创建 GitHub Release
□ 重启后端服务
□ 验证用户能正常下载更新
```

---

## 🎉 总结

**发布新版本的核心步骤**：
1. ✅ 前端：更新 `kAppVersion` 和 `pubspec.yaml`
2. ✅ 后端：更新 `/version/latest` API
3. ✅ 构建：打包应用
4. ✅ 发布：创建 GitHub Release
5. ✅ 部署：重启后端服务

**记住**：
- 三个版本号必须**保持一致**
- 构建号每次递增
- 更新日志要**清晰明确**
- 谨慎使用**强制更新**

---

**最后更新**：2025-10-03  
**维护者**：Cyrene Music Team

