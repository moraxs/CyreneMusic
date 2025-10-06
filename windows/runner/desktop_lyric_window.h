#ifndef RUNNER_DESKTOP_LYRIC_WINDOW_H_
#define RUNNER_DESKTOP_LYRIC_WINDOW_H_

#include <windows.h>
#include <string>
#include <memory>

// Desktop lyric window class
class DesktopLyricWindow {
 public:
  DesktopLyricWindow();
  ~DesktopLyricWindow();

  // Create desktop lyric window
  bool Create();
  
  // Destroy window
  void Destroy();
  
  // Show/Hide window
  void Show();
  void Hide();
  bool IsVisible() const;
  
  // Set lyric text
  void SetLyricText(const std::wstring& text);
  
  // Set window position
  void SetPosition(int x, int y);
  
  // Get window position
  void GetPosition(int* x, int* y);
  
  // Set font size
  void SetFontSize(int size);
  
  // Set text color (ARGB format)
  void SetTextColor(DWORD color);
  
  // Set stroke color (ARGB format)
  void SetStrokeColor(DWORD color);
  
  // Set stroke width
  void SetStrokeWidth(int width);
  
  // Set draggable
  void SetDraggable(bool draggable);
  
  // Set mouse transparent
  void SetMouseTransparent(bool transparent);
  
  // Get window handle
  HWND GetHandle() const { return hwnd_; }

 private:
  static LRESULT CALLBACK WndProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);
  
  // Update window display
  void UpdateWindow();
  
  // Draw lyric to memory DC
  void DrawLyric(HDC hdc, int width, int height);
  
  HWND hwnd_;
  std::wstring lyric_text_;
  int font_size_;
  DWORD text_color_;
  DWORD stroke_color_;
  int stroke_width_;
  bool is_draggable_;
  bool is_dragging_;
  POINT drag_point_;
  HFONT font_;
};

#endif  // RUNNER_DESKTOP_LYRIC_WINDOW_H_
