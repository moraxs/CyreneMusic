# Windows 平台持久化存储测试脚本
# 用于验证数据是否能正确保存和恢复

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "持久化存储测试脚本" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# 1. 检查应用是否已构建
$exePath = "build\windows\x64\runner\Debug\cyrene_music.exe"
if (-not (Test-Path $exePath)) {
    Write-Host "❌ 应用未构建，请先运行: flutter build windows" -ForegroundColor Red
    exit 1
}

Write-Host "✅ 找到应用: $exePath" -ForegroundColor Green
Write-Host ""

# 2. 检查备份文件路径
$backupDir = "build\windows\x64\runner\Debug\data"
$backupFile = "$backupDir\app_settings_backup.json"

Write-Host "📂 备份文件路径: $backupFile" -ForegroundColor Yellow
Write-Host ""

# 3. 检查备份文件是否存在
if (Test-Path $backupFile) {
    Write-Host "✅ 备份文件已存在" -ForegroundColor Green
    Write-Host ""
    Write-Host "📄 备份文件内容预览:" -ForegroundColor Cyan
    Write-Host "--------------------" -ForegroundColor Gray
    Get-Content $backupFile | Select-Object -First 20
    Write-Host "--------------------" -ForegroundColor Gray
    Write-Host ""
    
    # 显示文件信息
    $fileInfo = Get-Item $backupFile
    Write-Host "📊 文件信息:" -ForegroundColor Cyan
    Write-Host "   大小: $($fileInfo.Length) 字节" -ForegroundColor White
    Write-Host "   创建时间: $($fileInfo.CreationTime)" -ForegroundColor White
    Write-Host "   修改时间: $($fileInfo.LastWriteTime)" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "⚠️ 备份文件不存在（这是正常的，如果这是第一次运行）" -ForegroundColor Yellow
    Write-Host ""
}

# 4. 提供测试选项
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "测试选项" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. 运行应用（正常启动）" -ForegroundColor White
Write-Host "2. 查看备份文件（JSON）" -ForegroundColor White
Write-Host "3. 删除备份文件（测试恢复）" -ForegroundColor White
Write-Host "4. 清理所有数据（完全重置）" -ForegroundColor White
Write-Host "5. 退出测试" -ForegroundColor White
Write-Host ""

$choice = Read-Host "请选择测试项 (1-5)"

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Host "🚀 启动应用..." -ForegroundColor Green
        Write-Host "💡 提示：登录账号并修改设置后，退出应用，然后重新运行此脚本检查备份" -ForegroundColor Yellow
        Write-Host ""
        Start-Process $exePath
    }
    
    "2" {
        if (Test-Path $backupFile) {
            Write-Host ""
            Write-Host "📄 备份文件完整内容:" -ForegroundColor Cyan
            Write-Host "==================" -ForegroundColor Gray
            $content = Get-Content $backupFile -Raw
            $json = $content | ConvertFrom-Json
            $json | ConvertTo-Json -Depth 10 | Write-Host
            Write-Host "==================" -ForegroundColor Gray
            Write-Host ""
            Write-Host "📊 存储的键:" -ForegroundColor Cyan
            $json.PSObject.Properties.Name | ForEach-Object {
                Write-Host "   - $_" -ForegroundColor White
            }
        } else {
            Write-Host ""
            Write-Host "❌ 备份文件不存在" -ForegroundColor Red
        }
    }
    
    "3" {
        if (Test-Path $backupFile) {
            Write-Host ""
            Write-Host "⚠️ 即将删除备份文件（用于测试恢复功能）" -ForegroundColor Yellow
            $confirm = Read-Host "确认删除? (y/N)"
            if ($confirm -eq "y" -or $confirm -eq "Y") {
                Remove-Item $backupFile -Force
                Write-Host "✅ 备份文件已删除" -ForegroundColor Green
                Write-Host "💡 现在运行应用，应该能看到数据仍然存在（从 SharedPreferences 恢复）" -ForegroundColor Cyan
            } else {
                Write-Host "❌ 取消删除" -ForegroundColor Red
            }
        } else {
            Write-Host ""
            Write-Host "❌ 备份文件不存在" -ForegroundColor Red
        }
    }
    
    "4" {
        Write-Host ""
        Write-Host "⚠️ 即将清理所有数据（备份文件 + SharedPreferences）" -ForegroundColor Yellow
        Write-Host "   这将导致应用恢复到初始状态！" -ForegroundColor Red
        $confirm = Read-Host "确认清理? (y/N)"
        if ($confirm -eq "y" -or $confirm -eq "Y") {
            # 删除备份文件
            if (Test-Path $backupDir) {
                Remove-Item $backupDir -Recurse -Force
                Write-Host "✅ 备份目录已删除" -ForegroundColor Green
            }
            
            # 删除 SharedPreferences（Windows 路径）
            $appData = $env:LOCALAPPDATA
            $prefsPath = "$appData\cyrene_music\shared_preferences"
            if (Test-Path $prefsPath) {
                Remove-Item $prefsPath -Recurse -Force
                Write-Host "✅ SharedPreferences 已删除" -ForegroundColor Green
            }
            
            Write-Host "💡 现在运行应用，所有设置应该恢复默认值" -ForegroundColor Cyan
        } else {
            Write-Host "❌ 取消清理" -ForegroundColor Red
        }
    }
    
    "5" {
        Write-Host ""
        Write-Host "👋 退出测试" -ForegroundColor Cyan
        exit 0
    }
    
    default {
        Write-Host ""
        Write-Host "❌ 无效选项" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "测试完成" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

