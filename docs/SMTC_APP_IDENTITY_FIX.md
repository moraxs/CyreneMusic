# Windows SMTC 应用标识修复

## 问题描述

在 Windows 系统媒体传输控制（SMTC）中，歌曲信息可以正常显示，但应用图标和应用名称显示为"未知应用"。

## 问题原因

Win32 应用程序需要显式设置 **AppUserModelID** 才能让 Windows 系统正确识别应用身份。如果不设置，Windows 会将应用识别为"未知应用"。

## 修复内容

### 1. 设置 AppUserModelID（`windows/runner/main.cpp`）

在应用启动时添加了 `SetCurrentProcessExplicitAppUserModelID` 调用：

```cpp
// 设置 AppUserModelID，确保 SMTC 可以正确识别应用
// 格式: 公司名.应用名.子产品.版本号
::SetCurrentProcessExplicitAppUserModelID(L"CyreneMusic.MusicPlayer.Desktop.1");
```

**添加的头文件：**
- `<shobjidl.h>` - Shell API（包含 AppUserModelID 函数）
- `<propkey.h>` - 属性键定义
- `<propvarutil.h>` - 属性值工具

### 2. 更新应用清单（`windows/runner/runner.exe.manifest`）

添加了应用程序身份信息：

```xml
<assemblyIdentity
  version="1.0.3.0"
  processorArchitecture="*"
  name="CyreneMusic.MusicPlayer"
  type="win32"/>
<description>Cyrene Music - Modern Music Player</description>
```

### 3. 更新资源文件（`windows/runner/Runner.rc`）

将应用显示名称从 `cyrene_music` 改为 `Cyrene Music`：

```rc
VALUE "ProductName", "Cyrene Music" "\0"
VALUE "FileDescription", "Cyrene Music - Modern Music Player" "\0"
VALUE "InternalName", "CyreneMusic" "\0"
```

### 4. 添加必要的链接库（`windows/runner/CMakeLists.txt`）

添加了 Shell 和属性系统库：

```cmake
target_link_libraries(${BINARY_NAME} PRIVATE "shell32.lib")
target_link_libraries(${BINARY_NAME} PRIVATE "propsys.lib")
```

## 测试步骤

### 1. 重新构建应用

```powershell
# 清理构建缓存
flutter clean

# 重新构建 Windows 应用
flutter build windows --release
```

### 2. 运行应用并测试 SMTC

1. 启动应用：`build\windows\x64\runner\Release\cyrene_music.exe`
2. 播放任意歌曲
3. 按下键盘上的媒体控制键（播放/暂停键），或者打开 Windows 通知中心
4. 查看 SMTC 控件，应该可以看到：
   - ✅ 应用名称显示为 **"Cyrene Music"**（而不是"未知应用"）
   - ✅ 应用图标正确显示
   - ✅ 歌曲信息正常显示

### 3. 验证效果

**修复前：**
- 应用名称：❌ 显示"未知应用"
- 应用图标：❌ 显示默认图标或空白

**修复后：**
- 应用名称：✅ 显示"Cyrene Music"
- 应用图标：✅ 显示应用图标（`resources/app_icon.ico`）

## 技术细节

### AppUserModelID 格式说明

格式：`公司名.产品名.子产品.版本`

本项目使用：`CyreneMusic.MusicPlayer.Desktop.1`

- `CyreneMusic` - 公司/开发者名称
- `MusicPlayer` - 产品名称
- `Desktop` - 子产品标识（桌面版）
- `1` - 主版本号

### 为什么需要这些修改？

1. **AppUserModelID**：Windows 用它来识别和分组应用窗口
2. **应用清单**：提供应用身份和兼容性信息
3. **资源文件**：定义应用的可显示名称和版本信息
4. **链接库**：
   - `shell32.lib` - 提供 `SetCurrentProcessExplicitAppUserModelID` 函数
   - `propsys.lib` - 提供属性系统支持（如果将来需要设置更多属性）

## 注意事项

1. ⚠️ **必须重新构建**：这些更改涉及 C++ 代码和资源文件，必须完全重新编译
2. ⚠️ **清理图标缓存**：如果图标仍不显示，可能需要清理 Windows 图标缓存：
   ```powershell
   # 删除图标缓存
   Remove-Item -Path "$env:LOCALAPPDATA\IconCache.db" -Force
   # 重启 Windows Explorer
   taskkill /f /im explorer.exe
   start explorer.exe
   ```
3. ⚠️ **打包安装程序**：如果使用 Inno Setup 打包，确保使用新构建的可执行文件

## 参考资料

- [Windows AppUserModelID 文档](https://learn.microsoft.com/en-us/windows/win32/shell/appids)
- [SystemMediaTransportControls 文档](https://learn.microsoft.com/en-us/uwp/api/windows.media.systemmediatransportcontrols)

## 修复日期

2025-10-05

## 相关问题

如果 SMTC 仍然不显示正确信息，请检查：
1. 是否使用了最新构建的可执行文件
2. 是否正确设置了应用图标资源
3. Windows 版本是否支持 SMTC（Windows 10+ 才支持）
