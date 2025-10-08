# Linux 平台构建依赖清单

## 概述

在 Linux 平台上构建 Cyrene Music 需要安装多个系统依赖库。本文档详细列出了所有必需的依赖项及其用途。

## 完整依赖安装命令

### 一键安装（推荐）

```bash
sudo apt-get update
sudo apt-get install -y \
  clang \
  cmake \
  ninja-build \
  pkg-config \
  libgtk-3-dev \
  liblzma-dev \
  libstdc++-12-dev \
  libgstreamer1.0-dev \
  libgstreamer-plugins-base1.0-dev \
  gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad \
  gstreamer1.0-libav \
  libayatana-appindicator3-dev
```

## 依赖项详解

### 1. 构建工具

| 包名 | 用途 |
|------|------|
| `clang` | C/C++ 编译器 |
| `cmake` | 构建系统生成器 |
| `ninja-build` | 快速构建工具 |
| `pkg-config` | 包配置工具 |

### 2. GTK 依赖

| 包名 | 用途 |
|------|------|
| `libgtk-3-dev` | GTK 3 图形界面库（Flutter Linux 必需） |
| `liblzma-dev` | LZMA 压缩库 |
| `libstdc++-12-dev` | C++ 标准库开发文件 |

### 3. 音频播放依赖（GStreamer）

| 包名 | 用途 | 插件 |
|------|------|------|
| `libgstreamer1.0-dev` | GStreamer 核心开发库 | `audioplayers_linux` |
| `libgstreamer-plugins-base1.0-dev` | GStreamer 基础插件开发库 | `audioplayers_linux` |
| `gstreamer1.0-plugins-good` | 良好质量插件（MP3, OGG 等） | `audioplayers_linux` |
| `gstreamer1.0-plugins-bad` | 实验性插件 | `audioplayers_linux` |
| `gstreamer1.0-libav` | FFmpeg/Libav 支持（更多格式） | `audioplayers_linux` |

### 4. 系统托盘依赖

| 包名 | 用途 | 插件 |
|------|------|------|
| `libayatana-appindicator3-dev` | Ayatana 系统托盘指示器库 | `tray_manager` |

**备选方案：** 如果您使用较旧的 Linux 发行版，可以安装：
```bash
sudo apt-get install -y libappindicator3-dev
```

## 不同 Linux 发行版的安装方法

### Ubuntu / Debian

```bash
sudo apt-get update
sudo apt-get install -y [包列表...]
```

### Fedora / RHEL / CentOS

```bash
sudo dnf install -y \
  clang \
  cmake \
  ninja-build \
  pkg-config \
  gtk3-devel \
  xz-devel \
  libstdc++-devel \
  gstreamer1-devel \
  gstreamer1-plugins-base-devel \
  gstreamer1-plugins-good \
  gstreamer1-plugins-bad-free \
  gstreamer1-libav \
  libappindicator-gtk3-devel
```

### Arch Linux / Manjaro

```bash
sudo pacman -S \
  clang \
  cmake \
  ninja \
  pkgconf \
  gtk3 \
  xz \
  gcc-libs \
  gstreamer \
  gst-plugins-base \
  gst-plugins-good \
  gst-plugins-bad \
  gst-libav \
  libappindicator-gtk3
```

## 验证依赖安装

### 检查 GStreamer

```bash
gst-inspect-1.0 --version
gst-inspect-1.0 playbin
```

**预期输出：** 显示 GStreamer 版本和 playbin 插件信息。

### 检查 AppIndicator

```bash
pkg-config --modversion ayatana-appindicator3-0.1
# 或
pkg-config --modversion appindicator3-0.1
```

**预期输出：** 显示版本号（如 `0.5.92`）。

### 检查 GTK

```bash
pkg-config --modversion gtk+-3.0
```

**预期输出：** 显示 GTK 3 版本号（如 `3.24.33`）。

## 构建流程

安装所有依赖后，执行以下命令构建应用：

```bash
# 1. 克隆仓库
git clone https://github.com/your-username/cyrene_music.git
cd cyrene_music

# 2. 获取 Flutter 依赖
flutter pub get

# 3. 启用 Linux 桌面支持（如果未启用）
flutter config --enable-linux-desktop

# 4. 构建 Release 版本
flutter build linux --release

# 5. 运行应用
cd build/linux/x64/release/bundle
./cyrene_music
```

## 常见问题排查

### Q: 找不到 GStreamer

**错误：**
```
CMake Error: The following required packages were not found: gstreamer-1.0
```

**解决：**
```bash
sudo apt-get install -y libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
```

### Q: 找不到 AppIndicator

**错误：**
```
CMake Error: The `tray_manager` package requires ayatana-appindicator3-0.1
```

**解决：**
```bash
sudo apt-get install -y libayatana-appindicator3-dev
# 或（较旧系统）
sudo apt-get install -y libappindicator3-dev
```

### Q: GTK 版本不兼容

**错误：**
```
Package 'gtk+-3.0' requires 'glib-2.0 >= 2.57.2'
```

**解决：** 升级系统或使用更新的 Linux 发行版：
```bash
sudo apt-get update
sudo apt-get upgrade
```

### Q: 构建速度慢

**优化建议：**

1. 使用 Ninja 构建系统（已默认使用）
2. 启用并行构建：
   ```bash
   flutter build linux --release -j 8  # 8 个并行任务
   ```
3. 使用 ccache 加速编译：
   ```bash
   sudo apt-get install -y ccache
   export CC="ccache gcc"
   export CXX="ccache g++"
   ```

## 最小系统要求

| 项目 | 要求 |
|------|------|
| **Linux 发行版** | Ubuntu 20.04+, Debian 11+, Fedora 35+, Arch Linux |
| **内核版本** | Linux 5.4+ |
| **GTK 版本** | GTK 3.22+ |
| **GStreamer 版本** | GStreamer 1.14+ |
| **CMake 版本** | CMake 3.10+ |
| **编译器** | GCC 9+ 或 Clang 10+ |
| **内存** | 至少 4GB RAM（推荐 8GB+） |
| **磁盘空间** | 至少 2GB 可用空间 |

## 推荐的开发环境

```bash
# 完整的开发环境（包含调试工具）
sudo apt-get install -y \
  build-essential \
  gdb \
  valgrind \
  git \
  curl \
  unzip \
  [上述所有依赖...]
```

## Docker 构建（可选）

如果您希望在隔离环境中构建，可以使用 Docker：

```dockerfile
FROM ubuntu:22.04

# 安装依赖
RUN apt-get update && apt-get install -y \
    curl git unzip xz-utils zip libglu1-mesa \
    clang cmake ninja-build pkg-config \
    libgtk-3-dev liblzma-dev libstdc++-12-dev \
    libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-libav \
    libayatana-appindicator3-dev

# 安装 Flutter
RUN git clone https://github.com/flutter/flutter.git -b stable /flutter
ENV PATH="/flutter/bin:${PATH}"

WORKDIR /app
```

## 参考资料

- [Flutter Linux Desktop](https://docs.flutter.dev/platform-integration/linux/building)
- [GStreamer Documentation](https://gstreamer.freedesktop.org/documentation/)
- [Ayatana Indicators](https://github.com/AyatanaIndicators)
- [tray_manager Linux Requirements](https://github.com/leanflutter/tray_manager#linux-requirements)

---

**最后更新：** 2025-10-07  
**适用版本：** Flutter 3.24+  
**测试平台：** Ubuntu 22.04 LTS, Ubuntu 24.04 LTS

