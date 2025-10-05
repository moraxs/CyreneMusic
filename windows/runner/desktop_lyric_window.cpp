#include "desktop_lyric_window.h"
#include <dwmapi.h>
#include <gdiplus.h>
#include <algorithm>

#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "gdiplus.lib")

namespace {
const wchar_t kWindowClassName[] = L"DESKTOP_LYRIC_WINDOW";
const int kDefaultFontSize = 32;
const DWORD kDefaultTextColor = 0xFFFFFFFF;  // White
const DWORD kDefaultStrokeColor = 0xFF000000;  // Black
const int kDefaultStrokeWidth = 2;
const int kWindowWidth = 800;
const int kWindowHeight = 100;

// GDI+ initialization
ULONG_PTR gdiplusToken = 0;

void InitGdiPlus() {
  if (gdiplusToken == 0) {
    Gdiplus::GdiplusStartupInput gdiplusStartupInput;
    Gdiplus::GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, nullptr);
  }
}

void ShutdownGdiPlus() {
  if (gdiplusToken != 0) {
    Gdiplus::GdiplusShutdown(gdiplusToken);
    gdiplusToken = 0;
  }
}

}  // namespace

DesktopLyricWindow::DesktopLyricWindow()
    : hwnd_(nullptr),
      lyric_text_(L""),
      font_size_(kDefaultFontSize),
      text_color_(kDefaultTextColor),
      stroke_color_(kDefaultStrokeColor),
      stroke_width_(kDefaultStrokeWidth),
      is_draggable_(true),
      is_dragging_(false),
      font_(nullptr) {
  InitGdiPlus();
}

DesktopLyricWindow::~DesktopLyricWindow() {
  Destroy();
  ShutdownGdiPlus();
}

bool DesktopLyricWindow::Create() {
  if (hwnd_ != nullptr) {
    return true;  // Window already exists
  }

  // Register window class
  WNDCLASSEX wc = {};
  wc.cbSize = sizeof(WNDCLASSEX);
  wc.style = CS_HREDRAW | CS_VREDRAW;
  wc.lpfnWndProc = WndProc;
  wc.hInstance = GetModuleHandle(nullptr);
  wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
  wc.lpszClassName = kWindowClassName;
  
  if (!RegisterClassEx(&wc) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
    return false;
  }

  // Get screen size
  int screen_width = GetSystemMetrics(SM_CXSCREEN);
  int screen_height = GetSystemMetrics(SM_CYSCREEN);
  
  // Default position: center bottom
  int x = (screen_width - kWindowWidth) / 2;
  int y = screen_height - kWindowHeight - 100;

  // Create layered window
  hwnd_ = CreateWindowEx(
      WS_EX_LAYERED | WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
      kWindowClassName,
      L"Desktop Lyric",
      WS_POPUP,
      x, y, kWindowWidth, kWindowHeight,
      nullptr,
      nullptr,
      GetModuleHandle(nullptr),
      this);

  if (hwnd_ == nullptr) {
    return false;
  }

  // Save this pointer
  SetWindowLongPtr(hwnd_, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));

  // Create font
  font_ = CreateFont(
      font_size_, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
      DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
      ANTIALIASED_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
      L"Microsoft YaHei");

  return true;
}

void DesktopLyricWindow::Destroy() {
  if (hwnd_ != nullptr) {
    DestroyWindow(hwnd_);
    hwnd_ = nullptr;
  }
  
  if (font_ != nullptr) {
    DeleteObject(font_);
    font_ = nullptr;
  }
}

void DesktopLyricWindow::Show() {
  if (hwnd_ != nullptr) {
    UpdateWindow();
    ShowWindow(hwnd_, SW_SHOWNOACTIVATE);
  }
}

void DesktopLyricWindow::Hide() {
  if (hwnd_ != nullptr) {
    ShowWindow(hwnd_, SW_HIDE);
  }
}

bool DesktopLyricWindow::IsVisible() const {
  return hwnd_ != nullptr && IsWindowVisible(hwnd_);
}

void DesktopLyricWindow::SetLyricText(const std::wstring& text) {
  lyric_text_ = text;
  if (IsVisible()) {
    UpdateWindow();
  }
}

void DesktopLyricWindow::SetPosition(int x, int y) {
  if (hwnd_ != nullptr) {
    SetWindowPos(hwnd_, HWND_TOPMOST, x, y, 0, 0, 
                 SWP_NOSIZE | SWP_NOACTIVATE);
  }
}

void DesktopLyricWindow::GetPosition(int* x, int* y) {
  if (hwnd_ != nullptr) {
    RECT rect;
    GetWindowRect(hwnd_, &rect);
    *x = rect.left;
    *y = rect.top;
  }
}

void DesktopLyricWindow::SetFontSize(int size) {
  font_size_ = size;
  
  // Recreate font
  if (font_ != nullptr) {
    DeleteObject(font_);
  }
  
  font_ = CreateFont(
      font_size_, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
      DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
      ANTIALIASED_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
      L"Microsoft YaHei");
  
  if (IsVisible()) {
    UpdateWindow();
  }
}

void DesktopLyricWindow::SetTextColor(DWORD color) {
  text_color_ = color;
  if (IsVisible()) {
    UpdateWindow();
  }
}

void DesktopLyricWindow::SetStrokeColor(DWORD color) {
  stroke_color_ = color;
  if (IsVisible()) {
    UpdateWindow();
  }
}

void DesktopLyricWindow::SetStrokeWidth(int width) {
  stroke_width_ = width;
  if (IsVisible()) {
    UpdateWindow();
  }
}

void DesktopLyricWindow::SetDraggable(bool draggable) {
  is_draggable_ = draggable;
}

void DesktopLyricWindow::SetMouseTransparent(bool transparent) {
  if (hwnd_ == nullptr) return;
  
  LONG exStyle = GetWindowLong(hwnd_, GWL_EXSTYLE);
  if (transparent) {
    exStyle |= WS_EX_TRANSPARENT;
  } else {
    exStyle &= ~WS_EX_TRANSPARENT;
  }
  SetWindowLong(hwnd_, GWL_EXSTYLE, exStyle);
}

void DesktopLyricWindow::UpdateWindow() {
  if (hwnd_ == nullptr) return;

  // Create memory DC
  HDC hdc_screen = GetDC(nullptr);
  HDC hdc_mem = CreateCompatibleDC(hdc_screen);
  
  // Create 32-bit bitmap
  BITMAPINFO bmi = {};
  bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bmi.bmiHeader.biWidth = kWindowWidth;
  bmi.bmiHeader.biHeight = -kWindowHeight;  // Negative means top-down
  bmi.bmiHeader.biPlanes = 1;
  bmi.bmiHeader.biBitCount = 32;
  bmi.bmiHeader.biCompression = BI_RGB;
  
  void* bits = nullptr;
  HBITMAP hbm = CreateDIBSection(hdc_mem, &bmi, DIB_RGB_COLORS, &bits, nullptr, 0);
  HBITMAP hbm_old = (HBITMAP)SelectObject(hdc_mem, hbm);
  
  // Draw lyric
  DrawLyric(hdc_mem, kWindowWidth, kWindowHeight);
  
  // Update layered window
  POINT pt_src = {0, 0};
  SIZE size = {kWindowWidth, kWindowHeight};
  BLENDFUNCTION blend = {AC_SRC_OVER, 0, 255, AC_SRC_ALPHA};
  
  UpdateLayeredWindow(hwnd_, hdc_screen, nullptr, &size, hdc_mem, &pt_src,
                      0, &blend, ULW_ALPHA);
  
  // Cleanup
  SelectObject(hdc_mem, hbm_old);
  DeleteObject(hbm);
  DeleteDC(hdc_mem);
  ReleaseDC(nullptr, hdc_screen);
}

void DesktopLyricWindow::DrawLyric(HDC hdc, int width, int height) {
  // Use GDI+ to draw text (better anti-aliasing and stroke)
  Gdiplus::Graphics graphics(hdc);
  graphics.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
  graphics.SetTextRenderingHint(Gdiplus::TextRenderingHintAntiAlias);
  
  // Clear background (transparent)
  graphics.Clear(Gdiplus::Color(0, 0, 0, 0));
  
  if (lyric_text_.empty()) {
    return;
  }
  
  // Create font
  Gdiplus::FontFamily fontFamily(L"Microsoft YaHei");
  Gdiplus::Font font(&fontFamily, static_cast<Gdiplus::REAL>(font_size_), 
                     Gdiplus::FontStyleBold, Gdiplus::UnitPixel);
  
  // Measure text size
  Gdiplus::RectF layoutRect(0, 0, static_cast<Gdiplus::REAL>(width), 
                             static_cast<Gdiplus::REAL>(height));
  Gdiplus::RectF boundRect;
  Gdiplus::StringFormat format;
  format.SetAlignment(Gdiplus::StringAlignmentCenter);
  format.SetLineAlignment(Gdiplus::StringAlignmentCenter);
  
  graphics.MeasureString(lyric_text_.c_str(), -1, &font, layoutRect, &format, &boundRect);
  
  // Draw stroke (multiple draws to simulate stroke effect)
  if (stroke_width_ > 0) {
    Gdiplus::GraphicsPath path;
    Gdiplus::FontFamily fontFamilyPath(L"Microsoft YaHei");
    path.AddString(lyric_text_.c_str(), -1, &fontFamilyPath, 
                   Gdiplus::FontStyleBold, static_cast<Gdiplus::REAL>(font_size_),
                   layoutRect, &format);
    
    Gdiplus::Pen stroke_pen(Gdiplus::Color(
        (stroke_color_ >> 24) & 0xFF,  // A
        (stroke_color_ >> 16) & 0xFF,  // R
        (stroke_color_ >> 8) & 0xFF,   // G
        stroke_color_ & 0xFF           // B
    ), static_cast<Gdiplus::REAL>(stroke_width_));
    
    stroke_pen.SetLineJoin(Gdiplus::LineJoinRound);
    graphics.DrawPath(&stroke_pen, &path);
    
    // Fill text
    Gdiplus::SolidBrush text_brush(Gdiplus::Color(
        (text_color_ >> 24) & 0xFF,  // A
        (text_color_ >> 16) & 0xFF,  // R
        (text_color_ >> 8) & 0xFF,   // G
        text_color_ & 0xFF           // B
    ));
    graphics.FillPath(&text_brush, &path);
  } else {
    // No stroke, draw text directly
    Gdiplus::SolidBrush text_brush(Gdiplus::Color(
        (text_color_ >> 24) & 0xFF,
        (text_color_ >> 16) & 0xFF,
        (text_color_ >> 8) & 0xFF,
        text_color_ & 0xFF
    ));
    graphics.DrawString(lyric_text_.c_str(), -1, &font, layoutRect, &format, &text_brush);
  }
}

LRESULT CALLBACK DesktopLyricWindow::WndProc(HWND hwnd, UINT message,
                                              WPARAM wparam, LPARAM lparam) {
  DesktopLyricWindow* window = 
      reinterpret_cast<DesktopLyricWindow*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
  
  if (window == nullptr) {
    return DefWindowProc(hwnd, message, wparam, lparam);
  }
  
  switch (message) {
    case WM_LBUTTONDOWN: {
      if (window->is_draggable_) {
        window->is_dragging_ = true;
        window->drag_point_.x = LOWORD(lparam);
        window->drag_point_.y = HIWORD(lparam);
        SetCapture(hwnd);
      }
      return 0;
    }
    
    case WM_LBUTTONUP: {
      if (window->is_dragging_) {
        window->is_dragging_ = false;
        ReleaseCapture();
      }
      return 0;
    }
    
    case WM_MOUSEMOVE: {
      if (window->is_dragging_) {
        RECT rect;
        GetWindowRect(hwnd, &rect);
        
        int mouse_x = LOWORD(lparam);
        int mouse_y = HIWORD(lparam);
        
        int new_x = rect.left + (mouse_x - window->drag_point_.x);
        int new_y = rect.top + (mouse_y - window->drag_point_.y);
        
        SetWindowPos(hwnd, HWND_TOPMOST, new_x, new_y, 0, 0,
                     SWP_NOSIZE | SWP_NOACTIVATE);
      }
      return 0;
    }
    
    case WM_DESTROY: {
      PostQuitMessage(0);
      return 0;
    }
  }
  
  return DefWindowProc(hwnd, message, wparam, lparam);
}
