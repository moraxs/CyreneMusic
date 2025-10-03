# 播放器功能说明

## 🎵 功能概览

### 1. 音乐播放
- ✅ 支持网易云音乐/QQ音乐/酷狗音乐
- ✅ 自动获取歌曲播放链接
- ✅ 支持多种音质选择（标准/极高/无损/Hi-Res等）
- ✅ 播放/暂停/停止/跳转控制

### 2. 全屏播放器
- ✅ 美观的全屏播放界面
- ✅ 实时滚动歌词显示
- ✅ 支持翻译歌词显示
- ✅ 模糊封面背景效果
- ✅ 进度条拖动控制
- ✅ 播放时间显示

### 3. 迷你播放器
- ✅ 底部常驻播放控制栏
- ✅ 显示当前播放歌曲信息
- ✅ 点击可打开全屏播放器
- ✅ 快捷播放控制按钮

### 4. 系统媒体控件集成
- ✅ Windows SMTC 集成
- ✅ 显示在 Windows 控制中心
- ✅ 支持系统媒体键控制
- ✅ 显示歌曲封面和元数据
- 🔧 Android audio_service（预留接口）

## 📝 技术实现

### 核心服务

#### PlayerService (`lib/services/player_service.dart`)
音乐播放核心服务，基于 `audioplayers` 包实现。

**主要功能：**
- `playTrack(Track track)` - 播放指定歌曲
- `pause()` - 暂停播放
- `resume()` - 继续播放
- `stop()` - 停止播放
- `seek(Duration position)` - 跳转到指定位置
- `togglePlayPause()` - 切换播放/暂停状态

**状态管理：**
- 使用 `ChangeNotifier` 实现状态通知
- 实时更新播放进度和状态
- 自动处理播放完成事件

#### SystemMediaService (`lib/services/system_media_service.dart`)
系统媒体控件集成服务，支持 Windows 和 Android 平台。

**Windows SMTC 功能：**
- 在 Windows 控制中心显示播放控制
- 支持系统媒体键（播放/暂停/停止）
- 显示歌曲元数据和封面
- 实时同步播放状态和进度

**关键修复（根据官方文档）：**
1. 必须在 `main()` 中调用 `await SMTCWindows.initialize()`
2. 创建 SMTCWindows 实例时必须提供完整的 `metadata` 和 `timeline`
3. 使用正确的枚举值：`PlaybackStatus.playing`（小写）

### 歌词解析

#### LyricParser (`lib/utils/lyric_parser.dart`)
支持多种音乐平台的 LRC 格式歌词解析。

**平台支持：**
- `parseNeteaseLyric()` - 网易云音乐歌词
- `parseQQLyric()` - QQ音乐歌词
- `parseKugouLyric()` - 酷狗音乐歌词

**功能：**
- 解析时间戳和歌词文本
- 支持翻译歌词匹配
- 自动排序和索引
- 实时定位当前歌词行

### UI 组件

#### PlayerPage (`lib/pages/player_page.dart`)
全屏播放器页面。

**特色功能：**
- 🎨 毛玻璃背景效果
- 📜 实时滚动歌词
- 🌐 翻译歌词显示
- ⚡ 流畅的动画效果
- 🎚️ 可拖动的进度条

#### MiniPlayer (`lib/widgets/mini_player.dart`)
底部迷你播放器。

**功能：**
- 常驻显示当前播放状态
- 快捷播放控制
- 点击跳转到全屏播放器
- 自动隐藏（无播放时）

## 🚀 使用方法

### 播放歌曲

```dart
// 从 Track 对象播放
final track = Track(
  id: 2749798468,
  name: "真相是真",
  artists: "黄星/邱鼎杰",
  album: "真相是真",
  picUrl: "https://...",
  source: MusicSource.netease,
);

await PlayerService().playTrack(track);
```

### 控制播放

```dart
// 暂停
await PlayerService().pause();

// 继续播放
await PlayerService().resume();

// 停止
await PlayerService().stop();

// 跳转
await PlayerService().seek(Duration(seconds: 30));

// 切换播放/暂停
await PlayerService().togglePlayPause();
```

### 监听播放状态

```dart
PlayerService().addListener(() {
  final state = PlayerService().state;
  final position = PlayerService().position;
  final duration = PlayerService().duration;
  
  print('State: $state, Position: $position, Duration: $duration');
});
```

### 打开全屏播放器

```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const PlayerPage(),
  ),
);
```

## 🔧 依赖包

```yaml
dependencies:
  audioplayers: ^6.0.0          # 音频播放
  smtc_windows: ^1.0.0           # Windows 系统媒体控件
  audio_service: ^0.18.12        # Android 系统媒体服务
```

## 📚 参考文档

- [audioplayers](https://pub.dev/packages/audioplayers)
- [smtc_windows](https://pub.dev/documentation/smtc_windows/latest/)
- [audio_service](https://pub.dev/packages/audio_service)

## ⚠️ 注意事项

### Windows 平台
1. 确保已安装 Rust（smtc_windows 需要）
2. 必须在 `main()` 中初始化：
   ```dart
   await SMTCWindows.initialize();
   ```
3. SMTC 只在应用运行时显示

### Android 平台
- audio_service 集成尚未完全实现
- 需要额外配置后台服务权限
- 预留了接口，待后续完善

### 歌词显示
- 目前仅支持 LRC 格式歌词
- 不同平台的歌词格式可能略有差异
- 已针对网易云、QQ音乐、酷狗音乐做了适配

## 🎯 后续计划

- [ ] 实现上一曲/下一曲功能
- [ ] 添加播放列表管理
- [ ] 实现歌词拖动定位
- [ ] 完善 Android audio_service 集成
- [ ] 添加音效均衡器
- [ ] 支持本地音乐播放
- [ ] 添加收藏/喜欢功能

