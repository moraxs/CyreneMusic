#ifndef RUNNER_SYSTEM_COLOR_HELPER_H_
#define RUNNER_SYSTEM_COLOR_HELPER_H_

#include <windows.h>
#include <cstdint>

// Helper class to get Windows system accent color
class SystemColorHelper {
 public:
  // Get system accent color (ARGB format)
  static uint32_t GetSystemAccentColor();
  
 private:
  // Read DWORD value from registry
  static bool ReadRegistryDWORD(HKEY hKey, const wchar_t* subKey, 
                                const wchar_t* valueName, DWORD* result);
};

#endif  // RUNNER_SYSTEM_COLOR_HELPER_H_

