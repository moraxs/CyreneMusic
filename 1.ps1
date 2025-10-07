# 最终修复测试脚本 - 悬浮歌词插件
# 问题：AndroidManifest.xml 使用了错误的 Activity 名称

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  最终修复 - 悬浮歌词插件" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "🔍 问题诊断结果：" -ForegroundColor Yellow
Write-Host "   ❌ AndroidManifest.xml 中声明的是 AudioServiceActivity" -ForegroundColor Red
Write-Host "   ❌ 导致自定义 MainActivity 从未被实例化" -ForegroundColor Red
Write-Host "   ❌ 插件注册代码从未执行" -ForegroundColor Red
Write-Host ""

Write-Host "✅ 已修复：" -ForegroundColor Green
Write-Host "   ✅ AndroidManifest.xml 现在使用 .MainActivity" -ForegroundColor Green
Write-Host "   ✅ MainActivity 继承 AudioServiceActivity（支持媒体服务）" -ForegroundColor Green
Write-Host "   ✅ 插件会在 MainActivity.configureFlutterEngine() 中注册" -ForegroundColor Green
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查是否在正确的目录
if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "❌ 错误: 请在项目根目录运行此脚本" -ForegroundColor Red
    exit 1
}

Write-Host "📱 Step 1: 卸载旧版本应用..." -ForegroundColor Yellow
$uninstallResult = adb uninstall com.cyrene.music 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ 应用已卸载" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  应用未安装（可忽略）" -ForegroundColor DarkGray
}
Write-Host ""

Write-Host "🧹 Step 2: 清理构建缓存..." -ForegroundColor Yellow
flutter clean | Out-Null
Write-Host "   ✅ Flutter 缓存已清理" -ForegroundColor Green

Push-Location android
.\gradlew clean 2>&1 | Out-Null
Pop-Location
Write-Host "   ✅ Gradle 缓存已清理" -ForegroundColor Green
Write-Host ""

Write-Host "📦 Step 3: 重新获取依赖..." -ForegroundColor Yellow
flutter pub get | Out-Null
Write-Host "   ✅ 依赖已更新" -ForegroundColor Green
Write-Host ""

Write-Host "🔄 Step 4: 重启 ADB..." -ForegroundColor Yellow
adb kill-server 2>&1 | Out-Null
Start-Sleep -Seconds 1
adb start-server 2>&1 | Out-Null
Write-Host "   ✅ ADB 已重启" -ForegroundColor Green
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  准备工作完成！开始构建应用..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "🔨 构建并运行应用（这可能需要几分钟）..." -ForegroundColor Yellow
Write-Host ""

# 在后台启动 logcat 监控
$logcatJob = Start-Job -ScriptBlock {
    adb logcat -c
    adb logcat | Select-String -Pattern "MainActivity|FloatingLyric|flutter" | ForEach-Object {
        $line = $_.Line
        if ($line -match "MainActivity.*配置 Flutter Engine") {
            Write-Host "   🔧 MainActivity 开始初始化" -ForegroundColor Cyan
        } elseif ($line -match "MainActivity.*插件注册成功") {
            Write-Host "   ✅ 悬浮歌词插件注册成功！" -ForegroundColor Green
        } elseif ($line -match "AndroidFloatingLyric.*初始化成功") {
            Write-Host "   ✅ Flutter 服务初始化成功！" -ForegroundColor Green
        } elseif ($line -match "MissingPluginException") {
            Write-Host "   ❌ 插件异常：$line" -ForegroundColor Red
        }
    }
}

# 运行应用
Write-Host "正在启动应用..." -ForegroundColor Yellow
$flutterProcess = Start-Process -FilePath "flutter" -ArgumentList "run" -NoNewWindow -PassThru

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  监控关键日志（等待应用启动）..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 等待 30 秒让应用启动
Start-Sleep -Seconds 30

# 停止 logcat 监控
Stop-Job -Job $logcatJob
Remove-Job -Job $logcatJob

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  测试步骤" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "请在应用中执行以下操作：" -ForegroundColor Yellow
Write-Host ""
Write-Host "1️⃣  打开应用，查看是否有 MissingPluginException 错误" -ForegroundColor White
Write-Host "2️⃣  进入 设置 页面" -ForegroundColor White
Write-Host "3️⃣  找到 悬浮歌词 选项，点击开关" -ForegroundColor White
Write-Host "4️⃣  应该弹出权限对话框，点击 '去设置'" -ForegroundColor White
Write-Host "5️⃣  在系统设置中开启 '显示在其他应用上方' 权限" -ForegroundColor White
Write-Host "6️⃣  返回应用，悬浮歌词应该自动显示" -ForegroundColor White
Write-Host "7️⃣  播放音乐，测试歌词是否实时更新" -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "💡 如需查看实时日志，在新终端运行：" -ForegroundColor Yellow
Write-Host "   adb logcat | findstr /i ""MainActivity FloatingLyric""" -ForegroundColor Cyan
Write-Host ""
Write-Host "现在应该能看到日志输出了！" -ForegroundColor Green
Write-Host ""

