#ifndef RUNNER_SMTC_PLUGIN_H_
#define RUNNER_SMTC_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

// Windows Runtime headers (需要Windows 10 SDK)
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.h>
#include <winrt/Windows.Media.Playback.h>
#include <winrt/Windows.Storage.Streams.h>

namespace cyrene_music {

// SMTC (System Media Transport Controls) 插件
// 提供Windows原生媒体控件功能
class SmtcPlugin {
 public:
  static void RegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar);

  SmtcPlugin();
  virtual ~SmtcPlugin();

  // 禁用拷贝和赋值
  SmtcPlugin(const SmtcPlugin&) = delete;
  SmtcPlugin& operator=(const SmtcPlugin&) = delete;

 private:
  // 处理Method Channel调用
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // SMTC 功能方法
  void Initialize();
  void UpdateMetadata(const flutter::EncodableMap& metadata);
  void UpdatePlaybackStatus(const std::string& status);
  void UpdateTimeline(const flutter::EncodableMap& timeline);
  void EnableSmtc();
  void DisableSmtc();

  // 按钮事件处理
  void OnButtonPressed(
      winrt::Windows::Media::SystemMediaTransportControls const& sender,
      winrt::Windows::Media::SystemMediaTransportControlsButtonPressedEventArgs const& args);

  // Method Channel
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  
  // MediaPlayer 实例（用于桌面应用访问 SMTC）
  winrt::Windows::Media::Playback::MediaPlayer media_player_{nullptr};
  
  // SMTC 控制器
  winrt::Windows::Media::SystemMediaTransportControls smtc_{nullptr};
  winrt::Windows::Media::SystemMediaTransportControlsDisplayUpdater updater_{nullptr};
  
  // 事件令牌
  winrt::event_token button_pressed_token_;
  
  // 状态标志
  bool initialized_ = false;
  bool enabled_ = false;
};

}  // namespace cyrene_music

#endif  // RUNNER_SMTC_PLUGIN_H_

