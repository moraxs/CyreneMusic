#include "system_color_helper.h"
#include <iostream>

// Get system accent color
uint32_t SystemColorHelper::GetSystemAccentColor() {
  DWORD colorValue = 0;
  
  // Try to read system accent color from registry
  // Path: HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\DWM
  // Key: ColorizationColor
  if (ReadRegistryDWORD(
      HKEY_CURRENT_USER,
      L"SOFTWARE\\Microsoft\\Windows\\DWM",
      L"ColorizationColor",
      &colorValue)) {
    
    // ColorizationColor is in ARGB format (0xAARRGGBB)
    std::cout << "[SystemColor] Successfully read system accent color: 0x" 
              << std::hex << colorValue << std::dec << std::endl;
    
    return colorValue;
  }
  
  // If failed to read, return default Windows 11 blue
  std::cout << "[SystemColor] Failed to read accent color, using default" << std::endl;
  return 0xFF0078D4;  // Windows 11 default blue (ARGB)
}

// Read DWORD value from registry
bool SystemColorHelper::ReadRegistryDWORD(HKEY hKey, const wchar_t* subKey,
                                         const wchar_t* valueName, DWORD* result) {
  HKEY hOpenKey;
  LONG status = RegOpenKeyExW(hKey, subKey, 0, KEY_READ, &hOpenKey);
  
  if (status != ERROR_SUCCESS) {
    std::cout << "[SystemColor] Failed to open registry key: " << status << std::endl;
    return false;
  }
  
  DWORD dataSize = sizeof(DWORD);
  DWORD dataType;
  status = RegQueryValueExW(hOpenKey, valueName, nullptr, &dataType,
                           reinterpret_cast<LPBYTE>(result), &dataSize);
  
  RegCloseKey(hOpenKey);
  
  if (status != ERROR_SUCCESS || dataType != REG_DWORD) {
    std::cout << "[SystemColor] Failed to read registry value: " << status << std::endl;
    return false;
  }
  
  return true;
}

