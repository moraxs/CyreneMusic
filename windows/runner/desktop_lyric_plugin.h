#ifndef RUNNER_DESKTOP_LYRIC_PLUGIN_H_
#define RUNNER_DESKTOP_LYRIC_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <memory>

#include "desktop_lyric_window.h"

// Desktop lyric plugin for Flutter
class DesktopLyricPlugin {
 public:
  static void RegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar);

  DesktopLyricPlugin();
  virtual ~DesktopLyricPlugin();

 private:
  // Handle method calls from Dart
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<DesktopLyricWindow> lyric_window_;
};

#endif  // RUNNER_DESKTOP_LYRIC_PLUGIN_H_
