# 自动更新功能测试指南

## 🧪 快速测试步骤

### 测试场景 1：有新版本可用

#### 准备工作
1. **设置前端版本**（`lib/services/version_service.dart`）：
   ```dart
   static const String kAppVersion = '1.0.0';  // 设置为旧版本
   ```

2. **设置后端版本**（`backend/src/index.ts`）：
   ```typescript
   version: "1.0.2",  // 设置为新版本
   ```

3. **清除检查缓存**：
   - Android：设置 → 应用 → Cyrene Music → 清除数据
   - Windows：删除 `%APPDATA%\cyrene_music`

#### 测试步骤
1. 启动后端服务：
   ```bash
   cd backend
   bun run src/index.ts
   ```

2. 运行应用：
   ```bash
   flutter run
   ```

3. 等待进入首页

4. **预期结果**：
   - 延迟 2 秒后弹出更新对话框 ✅
   - 显示版本号：`1.0.0 → 1.0.2` ✅
   - 显示更新内容 ✅
   - 有"稍后提醒"和"立即更新"按钮 ✅

#### 验证日志
```
I/flutter: 🔍 [HomePage] 开始检查更新...
I/flutter: 🔍 [VersionService] 请求URL: http://127.0.0.1:4055/version/latest
I/flutter: 🔍 [VersionService] 响应状态码: 200
I/flutter: ✅ [VersionService] 最新版本: 1.0.2
I/flutter: ✅ [VersionService] 当前版本: 1.0.0
I/flutter: 🆕 [VersionService] 发现新版本！
```

---

### 测试场景 2：已是最新版本

#### 准备工作
1. **设置前端版本**：
   ```dart
   static const String kAppVersion = '1.0.2';  // 与后端相同
   ```

2. **后端版本保持不变**：
   ```typescript
   version: "1.0.2",
   ```

#### 测试步骤
1. 重启应用
2. 等待 2 秒

#### 预期结果
- **不弹出**更新对话框 ✅
- 日志显示"已是最新版本" ✅

#### 验证日志
```
I/flutter: ✅ [VersionService] 最新版本: 1.0.2
I/flutter: ✅ [VersionService] 当前版本: 1.0.2
I/flutter: ✅ [VersionService] 已是最新版本
```

---

### 测试场景 3：强制更新

#### 准备工作
1. **后端设置强制更新**：
   ```typescript
   const versionInfo = {
     version: "2.0.0",
     changelog: "- 修复严重安全漏洞\n- 必须立即更新",
     force_update: true,  // ← 启用强制更新
     download_url: "...",
   };
   ```

2. **前端版本**：
   ```dart
   static const String kAppVersion = '1.0.0';
   ```

#### 测试步骤
1. 重启后端和应用
2. 进入首页

#### 预期结果
- 弹出更新对话框 ✅
- **没有**"稍后提醒"按钮（只有"立即更新"）✅
- 显示强制更新警告提示 ✅
- 点击对话框外部**无法关闭** ✅
- 按 ESC 键**无法关闭** ✅

---

### 测试场景 4：24 小时内不重复检查

#### 准备工作
1. 完成一次更新检查（场景 1 或 2）

#### 测试步骤
1. 退出应用
2. 立即重新打开应用
3. 进入首页

#### 预期结果
- **不弹出**更新对话框 ✅
- 日志显示"今天已检查过更新" ✅

#### 验证日志
```
I/flutter: 🔍 [HomePage] 今天已检查过更新，跳过
```

#### 强制重新检查
如需立即重新检查，删除缓存：
```dart
// 临时代码（调试用）
final prefs = await SharedPreferences.getInstance();
await prefs.remove('last_update_check_time');
```

---

### 测试场景 5：网络错误

#### 准备工作
1. 停止后端服务
2. 或修改 URL 为错误地址

#### 测试步骤
1. 启动应用
2. 进入首页

#### 预期结果
- **不弹出**更新对话框 ✅
- 应用正常运行（不崩溃）✅
- 日志显示检查失败 ✅

#### 验证日志
```
I/flutter: 🔍 [HomePage] 开始检查更新...
I/flutter: ❌ [VersionService] 检查更新失败: ...
I/flutter: ❌ [HomePage] 检查更新失败: ...
```

---

### 测试场景 6：点击"立即更新"

#### 准备工作
1. 设置下载链接：
   ```typescript
   download_url: "https://github.com/user/repo/releases/latest",
   ```

2. 触发更新对话框（场景 1）

#### 测试步骤
1. 等待更新对话框弹出
2. 点击"立即更新"按钮

#### 预期结果
- 对话框关闭 ✅
- 打开系统默认浏览器 ✅
- 浏览器跳转到下载链接 ✅

---

### 测试场景 7：点击"稍后提醒"

#### 准备工作
1. 确保 `force_update: false`
2. 触发更新对话框

#### 测试步骤
1. 等待更新对话框弹出
2. 点击"稍后提醒"按钮

#### 预期结果
- 对话框关闭 ✅
- 应用正常使用 ✅
- 重启应用后（24 小时后）会再次提醒 ✅

---

## 🔍 调试技巧

### 1. 查看完整日志

**Android**：
```bash
adb logcat | findstr "VersionService HomePage"
```

**Windows PowerShell**：
```powershell
flutter run 2>&1 | Select-String "VersionService|HomePage"
```

### 2. 手动触发检查

在首页代码中添加按钮：
```dart
FloatingActionButton(
  onPressed: () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_update_check_time');
    await VersionService().checkForUpdate();
    if (VersionService().hasUpdate) {
      _showUpdateDialog(VersionService().latestVersion!);
    }
  },
  child: Icon(Icons.update),
)
```

### 3. 模拟不同版本

快速修改版本进行测试：
```dart
// 测试新版本
static const String kAppVersion = '0.9.0';  // 低于后端

// 测试旧版本
static const String kAppVersion = '2.0.0';  // 高于后端

// 测试相同版本
static const String kAppVersion = '1.0.2';  // 等于后端
```

### 4. 检查 API 响应

使用 curl 或浏览器直接访问：
```bash
curl http://127.0.0.1:4055/version/latest

# 或在浏览器打开
http://127.0.0.1:4055/version/latest
```

**预期响应**：
```json
{
  "status": 200,
  "data": {
    "version": "1.0.2",
    "changelog": "- 支持安卓平台 \n - 修复了一些bug",
    "force_update": false,
    "download_url": "https://github.com/..."
  }
}
```

---

## 📊 版本比较测试

### 测试用例

| 当前版本 | 最新版本 | 预期结果 | 说明 |
|---------|---------|---------|------|
| 1.0.0 | 1.0.1 | 有更新 ✅ | 补丁更新 |
| 1.0.0 | 1.1.0 | 有更新 ✅ | 次版本更新 |
| 1.0.0 | 2.0.0 | 有更新 ✅ | 主版本更新 |
| 1.0.1 | 1.0.1 | 无更新 ✅ | 版本相同 |
| 1.0.2 | 1.0.1 | 无更新 ✅ | 本地更新 |
| 1.1.0 | 1.0.9 | 无更新 ✅ | 本地更新 |

### 验证代码

```dart
// 在 version_service.dart 中添加测试
void _testVersionComparison() {
  assert(_compareVersions('1.0.1', '1.0.0') > 0);  // 1.0.1 > 1.0.0
  assert(_compareVersions('1.1.0', '1.0.9') > 0);  // 1.1.0 > 1.0.9
  assert(_compareVersions('2.0.0', '1.9.9') > 0);  // 2.0.0 > 1.9.9
  assert(_compareVersions('1.0.0', '1.0.0') == 0); // 相等
  assert(_compareVersions('1.0.0', '1.0.1') < 0);  // 1.0.0 < 1.0.1
  print('✅ 所有版本比较测试通过');
}
```

---

## 🛠️ 常见问题

### Q1: 对话框没有弹出

**检查清单**：
- [ ] 后端是否正在运行？
- [ ] 后端版本号是否 > 前端版本号？
- [ ] 是否在 24 小时内已检查过？
- [ ] 查看日志是否有错误？

### Q2: 版本号显示为空

**解决方法**：
```dart
// 确认 kAppVersion 已设置
static const String kAppVersion = '1.0.0';
```

### Q3: 无法打开下载链接

**检查**：
- [ ] download_url 格式是否正确？
- [ ] 是否是有效的 HTTP/HTTPS 链接？
- [ ] 系统是否有默认浏览器？

### Q4: 强制更新可以关闭

**检查**：
```typescript
// 确认后端设置
force_update: true,  // 必须为 true
```

---

## ✅ 测试检查清单

发布前必须完成的测试：

```
基础功能：
□ 有新版本时弹出对话框
□ 无新版本时不弹出
□ 版本号正确显示
□ 更新日志正确显示

强制更新：
□ 强制更新时无法关闭对话框
□ 显示警告提示
□ 只有"立即更新"按钮

交互功能：
□ "稍后提醒"按钮功能正常
□ "立即更新"打开下载链接
□ 24 小时内不重复检查

异常处理：
□ 网络错误时不崩溃
□ 后端挂了不影响使用
□ 版本号解析错误不崩溃

跨平台：
□ Android 平台测试通过
□ Windows 平台测试通过
□ iOS 平台测试通过（如有）
```

---

## 📝 测试报告模板

```markdown
# 更新检查功能测试报告

**测试日期**：2025-10-03  
**测试人员**：XXX  
**测试版本**：1.0.0  

## 测试环境
- 操作系统：Android 14 / Windows 11
- Flutter 版本：3.x.x
- 后端版本：1.0.2

## 测试结果

| 测试场景 | 预期结果 | 实际结果 | 通过 |
|---------|---------|---------|------|
| 有新版本 | 弹出对话框 | ✅ | ✅ |
| 无新版本 | 不弹出 | ✅ | ✅ |
| 强制更新 | 无法关闭 | ✅ | ✅ |
| 重复检查 | 24h 内跳过 | ✅ | ✅ |
| 点击更新 | 打开链接 | ✅ | ✅ |
| 网络错误 | 不崩溃 | ✅ | ✅ |

## 发现的问题
无

## 测试结论
✅ 所有测试通过，功能正常
```

---

**最后更新**：2025-10-03  
**相关文档**：[VERSION_RELEASE_GUIDE.md](./VERSION_RELEASE_GUIDE.md)

