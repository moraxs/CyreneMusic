#include "desktop_lyric_plugin.h"
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <map>
#include <memory>
#include <string>

namespace {

std::string WStringToString(const std::wstring& wstr) {
  if (wstr.empty()) return std::string();
  int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), 
                                        NULL, 0, NULL, NULL);
  std::string strTo(size_needed, 0);
  WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), 
                      &strTo[0], size_needed, NULL, NULL);
  return strTo;
}

std::wstring StringToWString(const std::string& str) {
  if (str.empty()) return std::wstring();
  int size_needed = MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), 
                                        NULL, 0);
  std::wstring wstrTo(size_needed, 0);
  MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), 
                      &wstrTo[0], size_needed);
  return wstrTo;
}

}  // namespace

// static
void DesktopLyricPlugin::RegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar_ref) {
  // Wrap registrar in PluginRegistrarWindows
  auto registrar = 
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar_ref);
      
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "desktop_lyric",
      &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<DesktopLyricPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  // Keep plugin and channel alive - store in static maps
  static std::map<FlutterDesktopPluginRegistrarRef, std::unique_ptr<DesktopLyricPlugin>> plugins;
  static std::map<FlutterDesktopPluginRegistrarRef, std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>> channels;
  
  plugins[registrar_ref] = std::move(plugin);
  channels[registrar_ref] = std::move(channel);
}

DesktopLyricPlugin::DesktopLyricPlugin()
    : lyric_window_(std::make_unique<DesktopLyricWindow>()) {
}

DesktopLyricPlugin::~DesktopLyricPlugin() {
}

void DesktopLyricPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto& method_name = method_call.method_name();

  if (method_name == "create") {
    // Create desktop lyric window
    bool success = lyric_window_->Create();
    result->Success(flutter::EncodableValue(success));
    
  } else if (method_name == "destroy") {
    // Destroy window
    lyric_window_->Destroy();
    result->Success(flutter::EncodableValue(true));
    
  } else if (method_name == "show") {
    // Show window
    lyric_window_->Show();
    result->Success(flutter::EncodableValue(true));
    
  } else if (method_name == "hide") {
    // Hide window
    lyric_window_->Hide();
    result->Success(flutter::EncodableValue(true));
    
  } else if (method_name == "isVisible") {
    // Check if window is visible
    bool visible = lyric_window_->IsVisible();
    result->Success(flutter::EncodableValue(visible));
    
  } else if (method_name == "setLyricText") {
    // Set lyric text
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      auto text_it = arguments->find(flutter::EncodableValue("text"));
      if (text_it != arguments->end()) {
        std::string text = std::get<std::string>(text_it->second);
        lyric_window_->SetLyricText(StringToWString(text));
        result->Success(flutter::EncodableValue(true));
        return;
      }
    }
    result->Error("INVALID_ARGUMENT", "Missing 'text' argument");
    
  } else if (method_name == "setPosition") {
    // Set window position
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      auto x_it = arguments->find(flutter::EncodableValue("x"));
      auto y_it = arguments->find(flutter::EncodableValue("y"));
      
      if (x_it != arguments->end() && y_it != arguments->end()) {
        int x = std::get<int>(x_it->second);
        int y = std::get<int>(y_it->second);
        lyric_window_->SetPosition(x, y);
        result->Success(flutter::EncodableValue(true));
        return;
      }
    }
    result->Error("INVALID_ARGUMENT", "Missing 'x' or 'y' argument");
    
  } else if (method_name == "getPosition") {
    // Get window position
    int x, y;
    lyric_window_->GetPosition(&x, &y);
    flutter::EncodableMap position;
    position[flutter::EncodableValue("x")] = flutter::EncodableValue(x);
    position[flutter::EncodableValue("y")] = flutter::EncodableValue(y);
    result->Success(flutter::EncodableValue(position));
    
  } else if (method_name == "setFontSize") {
    // Set font size
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      auto size_it = arguments->find(flutter::EncodableValue("size"));
      if (size_it != arguments->end()) {
        int size = std::get<int>(size_it->second);
        lyric_window_->SetFontSize(size);
        result->Success(flutter::EncodableValue(true));
        return;
      }
    }
    result->Error("INVALID_ARGUMENT", "Missing 'size' argument");
    
  } else if (method_name == "setTextColor") {
    // Set text color
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      auto color_it = arguments->find(flutter::EncodableValue("color"));
      if (color_it != arguments->end()) {
        int64_t color = std::get<int64_t>(color_it->second);
        lyric_window_->SetTextColor(static_cast<DWORD>(color));
        result->Success(flutter::EncodableValue(true));
        return;
      }
    }
    result->Error("INVALID_ARGUMENT", "Missing 'color' argument");
    
  } else if (method_name == "setStrokeColor") {
    // Set stroke color
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      auto color_it = arguments->find(flutter::EncodableValue("color"));
      if (color_it != arguments->end()) {
        int64_t color = std::get<int64_t>(color_it->second);
        lyric_window_->SetStrokeColor(static_cast<DWORD>(color));
        result->Success(flutter::EncodableValue(true));
        return;
      }
    }
    result->Error("INVALID_ARGUMENT", "Missing 'color' argument");
    
  } else if (method_name == "setStrokeWidth") {
    // Set stroke width
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      auto width_it = arguments->find(flutter::EncodableValue("width"));
      if (width_it != arguments->end()) {
        int width = std::get<int>(width_it->second);
        lyric_window_->SetStrokeWidth(width);
        result->Success(flutter::EncodableValue(true));
        return;
      }
    }
    result->Error("INVALID_ARGUMENT", "Missing 'width' argument");
    
  } else if (method_name == "setDraggable") {
    // Set draggable
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      auto draggable_it = arguments->find(flutter::EncodableValue("draggable"));
      if (draggable_it != arguments->end()) {
        bool draggable = std::get<bool>(draggable_it->second);
        lyric_window_->SetDraggable(draggable);
        result->Success(flutter::EncodableValue(true));
        return;
      }
    }
    result->Error("INVALID_ARGUMENT", "Missing 'draggable' argument");
    
  } else if (method_name == "setMouseTransparent") {
    // Set mouse transparent
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      auto transparent_it = arguments->find(flutter::EncodableValue("transparent"));
      if (transparent_it != arguments->end()) {
        bool transparent = std::get<bool>(transparent_it->second);
        lyric_window_->SetMouseTransparent(transparent);
        result->Success(flutter::EncodableValue(true));
        return;
      }
    }
    result->Error("INVALID_ARGUMENT", "Missing 'transparent' argument");
    
  } else {
    result->NotImplemented();
  }
}
