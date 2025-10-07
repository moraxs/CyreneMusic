#include "smtc_plugin.h"

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>

#include <iostream>
#include <sstream>

// Windows Runtime
#include <winrt/Windows.Foundation.Collections.h>

using namespace winrt;
using namespace winrt::Windows::Foundation;
using namespace winrt::Windows::Media;
using namespace winrt::Windows::Storage::Streams;

namespace cyrene_music {

// 单例实例
static SmtcPlugin* g_smtc_plugin = nullptr;

// 注册插件
void SmtcPlugin::RegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {
  // 从C API转换为C++ API
  auto registrar_cpp = flutter::PluginRegistrarManager::GetInstance()
                           ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);
  
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar_cpp->messenger(), "com.cyrene.music/smtc",
      &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<SmtcPlugin>();
  g_smtc_plugin = plugin.get();
  
  // 保存channel指针到plugin中
  plugin->channel_ = std::move(channel);

  plugin->channel_->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  // 不要释放plugin，保持其生命周期
  plugin.release();
}

SmtcPlugin::SmtcPlugin() {
  std::cout << "[SMTC] 插件已创建" << std::endl;
}

SmtcPlugin::~SmtcPlugin() {
  if (enabled_ && smtc_) {
    try {
      smtc_.ButtonPressed(button_pressed_token_);
      smtc_.IsEnabled(false);
    } catch (...) {
      // 忽略清理错误
    }
  }
  
  // 清理 MediaPlayer
  if (media_player_) {
    try {
      media_player_.Close();
      media_player_ = nullptr;
    } catch (...) {
      // 忽略清理错误
    }
  }
  
  std::cout << "[SMTC] 插件已销毁" << std::endl;
}

// 处理Method Channel调用
void SmtcPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  const std::string& method_name = method_call.method_name();
  
  try {
    if (method_name == "initialize") {
      Initialize();
      result->Success(flutter::EncodableValue(true));
    } 
    else if (method_name == "enable") {
      EnableSmtc();
      result->Success(flutter::EncodableValue(true));
    } 
    else if (method_name == "disable") {
      DisableSmtc();
      result->Success(flutter::EncodableValue(true));
    } 
    else if (method_name == "updateMetadata") {
      const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
      if (arguments) {
        UpdateMetadata(*arguments);
        result->Success(flutter::EncodableValue(true));
      } else {
        result->Error("INVALID_ARGUMENT", "Expected map argument");
      }
    } 
    else if (method_name == "updatePlaybackStatus") {
      const auto* status = std::get_if<std::string>(method_call.arguments());
      if (status) {
        UpdatePlaybackStatus(*status);
        result->Success(flutter::EncodableValue(true));
      } else {
        result->Error("INVALID_ARGUMENT", "Expected string argument");
      }
    } 
    else if (method_name == "updateTimeline") {
      const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
      if (arguments) {
        UpdateTimeline(*arguments);
        result->Success(flutter::EncodableValue(true));
      } else {
        result->Error("INVALID_ARGUMENT", "Expected map argument");
      }
    } 
    else {
      result->NotImplemented();
    }
  } catch (const std::exception& e) {
    std::string error_message = "SMTC Error: ";
    error_message += e.what();
    result->Error("SMTC_ERROR", error_message);
  } catch (...) {
    result->Error("SMTC_ERROR", "Unknown error occurred");
  }
}

// 初始化SMTC
void SmtcPlugin::Initialize() {
  if (initialized_) {
    std::cout << "[SMTC] 已经初始化，跳过" << std::endl;
    return;
  }

  try {
    // 创建 MediaPlayer 实例（桌面应用需要通过它来访问 SMTC）
    // 参考: https://www.cnblogs.com/TwilightLemon/p/18279496
    std::cout << "[SMTC] 正在创建 MediaPlayer 实例..." << std::endl;
    media_player_ = winrt::Windows::Media::Playback::MediaPlayer();
    
    // 禁用 MediaPlayer 的自动命令管理器
    media_player_.CommandManager().IsEnabled(false);
    
    // 通过 MediaPlayer 获取 SMTC 控制器
    // MediaPlayer 内部通过 COM 组件创建 SMTC，绕过了 UWP Window 句柄限制
    std::cout << "[SMTC] 正在获取 SMTC 控制器..." << std::endl;
    smtc_ = media_player_.SystemMediaTransportControls();
    updater_ = smtc_.DisplayUpdater();

    // 设置应用信息
    updater_.Type(MediaPlaybackType::Music);
    
    // 设置应用媒体ID（与main.cpp中的AppUserModelID保持一致）
    updater_.AppMediaId(L"CyreneMusic.MusicPlayer.Desktop.1");
    
    // 尝试设置应用显示名称（虽然可能不会生效，但值得一试）
    try {
      updater_.MusicProperties().Title(L"Cyrene Music");
      updater_.MusicProperties().Artist(L"");
      updater_.Update();
      std::cout << "[SMTC] 已设置默认应用信息" << std::endl;
    } catch (...) {
      // 忽略错误
    }
    
    // 启用媒体控件按钮
    smtc_.IsPlayEnabled(true);
    smtc_.IsPauseEnabled(true);
    smtc_.IsStopEnabled(true);
    smtc_.IsNextEnabled(true);
    smtc_.IsPreviousEnabled(true);
    
    // 禁用快进/快退（音乐播放器通常不需要）
    smtc_.IsFastForwardEnabled(false);
    smtc_.IsRewindEnabled(false);

    // 注册按钮事件
    button_pressed_token_ = smtc_.ButtonPressed(
        [this](SystemMediaTransportControls const& sender,
               SystemMediaTransportControlsButtonPressedEventArgs const& args) {
          OnButtonPressed(sender, args);
        });

    initialized_ = true;
    std::cout << "[SMTC] ✅ 初始化成功（通过 MediaPlayer 访问 SMTC）" << std::endl;
  } catch (const winrt::hresult_error& e) {
    std::wcerr << L"[SMTC] ❌ 初始化失败: " << e.message().c_str() << std::endl;
    std::wcout << L"[SMTC] HRESULT: 0x" << std::hex << e.code() << std::dec << std::endl;
    throw;
  } catch (const std::exception& e) {
    std::cerr << "[SMTC] ❌ 标准异常: " << e.what() << std::endl;
    throw;
  } catch (...) {
    std::cerr << "[SMTC] ❌ 未知异常" << std::endl;
    throw;
  }
}

// 启用SMTC
void SmtcPlugin::EnableSmtc() {
  if (!initialized_) {
    Initialize();
  }

  try {
    smtc_.IsEnabled(true);
    enabled_ = true;
    std::cout << "[SMTC] ✅ 已启用" << std::endl;
  } catch (const winrt::hresult_error& e) {
    std::wcerr << L"[SMTC] ❌ 启用失败: " << e.message().c_str() << std::endl;
  }
}

// 禁用SMTC
void SmtcPlugin::DisableSmtc() {
  if (!initialized_) return;

  try {
    smtc_.IsEnabled(false);
    enabled_ = false;
    std::cout << "[SMTC] ⏹️ 已禁用" << std::endl;
  } catch (const winrt::hresult_error& e) {
    std::wcerr << L"[SMTC] ❌ 禁用失败: " << e.message().c_str() << std::endl;
  }
}

// 更新元数据
void SmtcPlugin::UpdateMetadata(const flutter::EncodableMap& metadata) {
  if (!initialized_) {
    std::cout << "[SMTC] ⚠️ 未初始化，无法更新元数据" << std::endl;
    return;
  }

  try {
    auto music_properties = updater_.MusicProperties();

    // 获取标题
    auto title_it = metadata.find(flutter::EncodableValue("title"));
    if (title_it != metadata.end()) {
      const auto* title = std::get_if<std::string>(&title_it->second);
      if (title && !title->empty()) {
        music_properties.Title(winrt::to_hstring(*title));
      }
    }

    // 获取艺术家
    auto artist_it = metadata.find(flutter::EncodableValue("artist"));
    if (artist_it != metadata.end()) {
      const auto* artist = std::get_if<std::string>(&artist_it->second);
      if (artist && !artist->empty()) {
        music_properties.Artist(winrt::to_hstring(*artist));
      }
    }

    // 获取专辑
    auto album_it = metadata.find(flutter::EncodableValue("album"));
    if (album_it != metadata.end()) {
      const auto* album = std::get_if<std::string>(&album_it->second);
      if (album && !album->empty()) {
        music_properties.AlbumTitle(winrt::to_hstring(*album));
      }
    }

    // 获取封面URL
    auto thumbnail_it = metadata.find(flutter::EncodableValue("thumbnail"));
    if (thumbnail_it != metadata.end()) {
      const auto* thumbnail = std::get_if<std::string>(&thumbnail_it->second);
      if (thumbnail && !thumbnail->empty()) {
        try {
          // 从URL加载缩略图
          Uri thumbnail_uri{winrt::to_hstring(*thumbnail)};
          updater_.Thumbnail(
              RandomAccessStreamReference::CreateFromUri(thumbnail_uri));
        } catch (...) {
          std::cout << "[SMTC] ⚠️ 加载封面失败" << std::endl;
        }
      }
    }

    // 应用更新
    updater_.Update();
    std::cout << "[SMTC] ✅ 元数据已更新" << std::endl;
  } catch (const winrt::hresult_error& e) {
    std::wcerr << L"[SMTC] ❌ 更新元数据失败: " << e.message().c_str() << std::endl;
  }
}

// 更新播放状态
void SmtcPlugin::UpdatePlaybackStatus(const std::string& status) {
  if (!initialized_) {
    std::cout << "[SMTC] ⚠️ 未初始化，无法更新状态" << std::endl;
    return;
  }

  try {
    MediaPlaybackStatus playback_status = MediaPlaybackStatus::Closed;

    if (status == "playing") {
      playback_status = MediaPlaybackStatus::Playing;
    } else if (status == "paused") {
      playback_status = MediaPlaybackStatus::Paused;
    } else if (status == "stopped") {
      playback_status = MediaPlaybackStatus::Stopped;
    } else if (status == "changing") {
      playback_status = MediaPlaybackStatus::Changing;
    }

    smtc_.PlaybackStatus(playback_status);
    std::cout << "[SMTC] ✅ 状态已更新: " << status << std::endl;
  } catch (const winrt::hresult_error& e) {
    std::wcerr << L"[SMTC] ❌ 更新状态失败: " << e.message().c_str() << std::endl;
  }
}

// 更新时间线（进度）
void SmtcPlugin::UpdateTimeline(const flutter::EncodableMap& timeline) {
  if (!initialized_) {
    std::cout << "[SMTC] ⚠️ 未初始化，无法更新时间线" << std::endl;
    return;
  }

  try {
    // 获取时间参数（毫秒）
    auto get_int64 = [&timeline](const char* key) -> int64_t {
      auto it = timeline.find(flutter::EncodableValue(key));
      if (it != timeline.end()) {
        const auto* value = std::get_if<int64_t>(&it->second);
        if (value) return *value;
        const auto* int_value = std::get_if<int32_t>(&it->second);
        if (int_value) return static_cast<int64_t>(*int_value);
      }
      return 0;
    };

    int64_t position_ms = get_int64("positionMs");
    int64_t duration_ms = get_int64("endTimeMs");

    // 创建时间线属性
    SystemMediaTransportControlsTimelineProperties timeline_props;
    timeline_props.StartTime(TimeSpan{0});
    timeline_props.Position(TimeSpan{position_ms * 10000});  // 毫秒转为100纳秒
    timeline_props.EndTime(TimeSpan{duration_ms * 10000});
    timeline_props.MinSeekTime(TimeSpan{0});
    timeline_props.MaxSeekTime(TimeSpan{duration_ms * 10000});

    smtc_.UpdateTimelineProperties(timeline_props);
    
    std::cout << "[SMTC] ✅ 时间线已更新: " 
              << position_ms << "ms / " << duration_ms << "ms" << std::endl;
  } catch (const winrt::hresult_error& e) {
    std::wcerr << L"[SMTC] ❌ 更新时间线失败: " << e.message().c_str() << std::endl;
  }
}

// 按钮按下事件处理
void SmtcPlugin::OnButtonPressed(
    SystemMediaTransportControls const& sender,
    SystemMediaTransportControlsButtonPressedEventArgs const& args) {
  
  std::string button_name;
  
  switch (args.Button()) {
    case SystemMediaTransportControlsButton::Play:
      button_name = "play";
      std::cout << "[SMTC] ▶️ 播放按钮" << std::endl;
      break;
    case SystemMediaTransportControlsButton::Pause:
      button_name = "pause";
      std::cout << "[SMTC] ⏸️ 暂停按钮" << std::endl;
      break;
    case SystemMediaTransportControlsButton::Stop:
      button_name = "stop";
      std::cout << "[SMTC] ⏹️ 停止按钮" << std::endl;
      break;
    case SystemMediaTransportControlsButton::Next:
      button_name = "next";
      std::cout << "[SMTC] ⏭️ 下一曲按钮" << std::endl;
      break;
    case SystemMediaTransportControlsButton::Previous:
      button_name = "previous";
      std::cout << "[SMTC] ⏮️ 上一曲按钮" << std::endl;
      break;
    case SystemMediaTransportControlsButton::FastForward:
      button_name = "fastForward";
      break;
    case SystemMediaTransportControlsButton::Rewind:
      button_name = "rewind";
      break;
    default:
      return;
  }

  // 通过Method Channel通知Dart侧
  if (channel_) {
    flutter::EncodableMap args_map;
    args_map[flutter::EncodableValue("button")] = flutter::EncodableValue(button_name);
    channel_->InvokeMethod(
        "onButtonPressed",
        std::make_unique<flutter::EncodableValue>(args_map));
  }
}

}  // namespace cyrene_music

