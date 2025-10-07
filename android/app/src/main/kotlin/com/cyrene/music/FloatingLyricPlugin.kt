package com.cyrene.music

import android.content.Context
import android.content.Intent
import android.graphics.*
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.*
import android.widget.TextView
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONArray

/// Android 悬浮歌词插件
/// 提供系统级悬浮窗歌词显示功能
class FloatingLyricPlugin: FlutterPlugin, MethodCallHandler {
    companion object {
        private const val CHANNEL = "android_floating_lyric"
        private const val UPDATE_INTERVAL_MS = 200L // 歌词更新间隔（毫秒）
    }
    
    private var channel: MethodChannel? = null
    private var context: Context? = null
    
    // 悬浮窗服务相关
    private var windowManager: WindowManager? = null
    private var floatingView: TextView? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private var isFloatingWindowVisible = false
    
    // 配置参数
    private var fontSize = 20f
    private var textColor = Color.WHITE
    private var strokeColor = Color.BLACK
    private var strokeWidth = 2f
    private var isDraggable = true
    private var backgroundColor = Color.TRANSPARENT
    private var alpha = 1.0f
    
    // 🔥 后台歌词更新机制（关键修复）
    private val handler = Handler(Looper.getMainLooper())
    private var updateRunnable: Runnable? = null
    private var lyrics: List<LyricLine> = emptyList()
    private var currentPosition: Long = 0L  // 当前播放位置（毫秒，由Flutter层同步）
    private var isPlaying = false  // 是否正在播放
    private var currentLyricIndex = -1  // 当前显示的歌词索引（避免重复更新）
    
    /// 歌词行数据类
    data class LyricLine(
        val time: Long,      // 时间戳（毫秒）
        val text: String,    // 歌词文本
        val translation: String? = null  // 翻译
    )
    
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        hideFloatingWindow()
        context = null
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "checkPermission" -> {
                result.success(checkOverlayPermission())
            }
            "requestPermission" -> {
                requestOverlayPermission()
                result.success(true)
            }
            "showFloatingWindow" -> {
                val success = showFloatingWindow()
                result.success(success)
            }
            "hideFloatingWindow" -> {
                hideFloatingWindow()
                result.success(true)
            }
            "updateLyric" -> {
                val lyricText = call.argument<String>("text") ?: ""
                updateLyricText(lyricText)
                result.success(true)
            }
            // 🔥 新增：设置完整歌词数据（关键方法）
            "setLyrics" -> {
                val lyricsJson = call.argument<String>("lyrics") ?: "[]"
                setLyricsData(lyricsJson)
                result.success(true)
            }
            // 🔥 新增：更新播放位置（关键方法）
            "updatePosition" -> {
                val position = call.argument<Long>("position") ?: 0L
                updatePlaybackPosition(position)
                result.success(true)
            }
            // 🔥 新增：设置播放状态（关键方法）
            "setPlayingState" -> {
                val playing = call.argument<Boolean>("playing") ?: false
                setPlayingState(playing)
                result.success(true)
            }
            "setPosition" -> {
                val x = call.argument<Int>("x") ?: 0
                val y = call.argument<Int>("y") ?: 0
                setPosition(x, y)
                result.success(true)
            }
            "setFontSize" -> {
                val size = call.argument<Int>("size") ?: 20
                setFontSize(size.toFloat())
                result.success(true)
            }
            "setTextColor" -> {
                val color = call.argument<Long>("color") ?: 0xFFFFFFFF
                setTextColor(color.toInt())
                result.success(true)
            }
            "setStrokeColor" -> {
                val color = call.argument<Long>("color") ?: 0xFF000000
                setStrokeColor(color.toInt())
                result.success(true)
            }
            "setStrokeWidth" -> {
                val width = call.argument<Int>("width") ?: 2
                setStrokeWidth(width.toFloat())
                result.success(true)
            }
            "setDraggable" -> {
                val draggable = call.argument<Boolean>("draggable") ?: true
                setDraggable(draggable)
                result.success(true)
            }
            "setAlpha" -> {
                val alphaValue = call.argument<Double>("alpha") ?: 1.0
                setAlpha(alphaValue.toFloat())
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    /// 检查悬浮窗权限
    private fun checkOverlayPermission(): Boolean {
        val ctx = context ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(ctx)
        } else {
            true
        }
    }
    
    /// 请求悬浮窗权限
    private fun requestOverlayPermission() {
        val ctx = context ?: return
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(ctx)) {
                try {
                    val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                        data = Uri.parse("package:${ctx.packageName}")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    ctx.startActivity(intent)
                } catch (e: Exception) {
                    // 如果无法直接跳转到应用的权限页面，跳转到通用悬浮窗权限页面
                    try {
                        val fallbackIntent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        ctx.startActivity(fallbackIntent)
                    } catch (ex: Exception) {
                        // 最后的备选方案：跳转到应用信息页面
                        val appDetailsIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:${ctx.packageName}")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        ctx.startActivity(appDetailsIntent)
                    }
                }
            }
        }
    }
    
    /// 显示悬浮窗
    private fun showFloatingWindow(): Boolean {
        val ctx = context ?: return false
        
        if (!checkOverlayPermission()) {
            return false
        }
        
        if (isFloatingWindowVisible) {
            return true
        }
        
        try {
            windowManager = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            
            // 创建悬浮视图
            floatingView = TextView(ctx).apply {
                text = "♪ 暂无歌词"
                textSize = fontSize
                setTextColor(textColor)
                gravity = Gravity.CENTER
                setShadowLayer(strokeWidth, 0f, 0f, strokeColor)
                setBackgroundColor(Color.TRANSPARENT)  // 完全透明背景
                alpha = this@FloatingLyricPlugin.alpha
                setPadding(16, 8, 16, 8)
                
                // 设置字体
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            }
            
            // 设置悬浮窗参数
            val windowType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            
            layoutParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                windowType,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or 
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                x = 100 // 默认位置
                y = 200
            }
            
            // 添加拖拽功能
            if (isDraggable) {
                setupDragListener()
            }
            
            // 添加到窗口管理器
            windowManager?.addView(floatingView, layoutParams)
            isFloatingWindowVisible = true
            
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }
    
    /// 隐藏悬浮窗
    private fun hideFloatingWindow() {
        try {
            // 停止后台更新
            stopLyricUpdateLoop()
            
            if (isFloatingWindowVisible && floatingView != null) {
                windowManager?.removeView(floatingView)
                isFloatingWindowVisible = false
                floatingView = null
                windowManager = null
                layoutParams = null
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    /// 更新歌词文本
    private fun updateLyricText(text: String) {
        floatingView?.let { view ->
            view.post {
                view.text = if (text.trim().isEmpty()) "♪" else text
            }
        }
    }
    
    /// 设置位置
    private fun setPosition(x: Int, y: Int) {
        layoutParams?.let { params ->
            params.x = x
            params.y = y
            floatingView?.let {
                try {
                    windowManager?.updateViewLayout(it, params)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }
    
    /// 设置字体大小
    private fun setFontSize(size: Float) {
        fontSize = size
        floatingView?.textSize = size
    }
    
    /// 设置文字颜色
    private fun setTextColor(color: Int) {
        textColor = color
        floatingView?.setTextColor(color)
    }
    
    /// 设置描边颜色
    private fun setStrokeColor(color: Int) {
        strokeColor = color
        floatingView?.setShadowLayer(strokeWidth, 0f, 0f, color)
    }
    
    /// 设置描边宽度
    private fun setStrokeWidth(width: Float) {
        strokeWidth = width
        floatingView?.setShadowLayer(width, 0f, 0f, strokeColor)
    }
    
    /// 设置是否可拖拽
    private fun setDraggable(draggable: Boolean) {
        isDraggable = draggable
        if (draggable && floatingView != null) {
            setupDragListener()
        } else {
            floatingView?.setOnTouchListener(null)
        }
    }
    
    /// 设置透明度
    private fun setAlpha(alphaValue: Float) {
        alpha = alphaValue.coerceIn(0f, 1f)
        floatingView?.alpha = alpha
    }
    
    /// 设置拖拽监听器
    private fun setupDragListener() {
        floatingView?.setOnTouchListener(object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0f
            private var initialTouchY = 0f
            
            override fun onTouch(v: View?, event: MotionEvent?): Boolean {
                when (event?.action) {
                    MotionEvent.ACTION_DOWN -> {
                        layoutParams?.let { params ->
                            initialX = params.x
                            initialY = params.y
                        }
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        layoutParams?.let { params ->
                            params.x = initialX + (event.rawX - initialTouchX).toInt()
                            params.y = initialY + (event.rawY - initialTouchY).toInt()
                            
                            try {
                                windowManager?.updateViewLayout(floatingView, params)
                            } catch (e: Exception) {
                                e.printStackTrace()
                            }
                        }
                        return true
                    }
                    MotionEvent.ACTION_UP -> {
                        // 可以在这里添加吸附边缘的逻辑
                        return true
                    }
                }
                return false
            }
        })
    }
    
    // ==================== 🔥 后台歌词更新机制（关键修复） ====================
    
    /// 设置歌词数据（从Flutter层接收JSON格式的歌词数组）
    private fun setLyricsData(lyricsJson: String) {
        try {
            val jsonArray = JSONArray(lyricsJson)
            val lyricsList = mutableListOf<LyricLine>()
            
            for (i in 0 until jsonArray.length()) {
                val item = jsonArray.getJSONObject(i)
                val time = item.getLong("time")
                val text = item.getString("text")
                val translation = if (item.has("translation")) item.getString("translation") else null
                
                lyricsList.add(LyricLine(time, text, translation))
            }
            
            lyrics = lyricsList.sortedBy { it.time }  // 按时间排序
            android.util.Log.d("FloatingLyric", "✅ 歌词数据已加载: ${lyrics.size} 行")
            
            // 🔥 修复：设置歌词时重置索引并显示占位符
            // 等待 Flutter 层同步播放位置后再显示正确歌词
            // 这样可以避免在切歌时短暂显示第一行或旧歌词的闪烁问题
            currentLyricIndex = -1
            updateLyricText("♪")
            
            // 启动后台更新循环
            if (isFloatingWindowVisible) {
                startLyricUpdateLoop()
            }
        } catch (e: Exception) {
            android.util.Log.e("FloatingLyric", "❌ 解析歌词数据失败: ${e.message}", e)
        }
    }
    
    /// 更新播放位置（从Flutter层定期接收）
    private fun updatePlaybackPosition(position: Long) {
        currentPosition = position
        // 🔥 收到新位置后立即更新歌词显示，确保同步
        if (isPlaying && isFloatingWindowVisible) {
            updateCurrentLyric()
        }
    }
    
    /// 设置播放状态
    private fun setPlayingState(playing: Boolean) {
        isPlaying = playing
        
        if (playing && isFloatingWindowVisible) {
            startLyricUpdateLoop()
        } else {
            stopLyricUpdateLoop()
        }
    }
    
    /// 启动后台歌词更新循环（在Android原生层运行，不依赖Flutter）
    private fun startLyricUpdateLoop() {
        // 如果已经在运行，先停止
        stopLyricUpdateLoop()
        
        updateRunnable = object : Runnable {
            override fun run() {
                try {
                    // 🔥 修复：不自动推进时间，完全依赖Flutter层同步的播放位置
                    // 原生层只负责根据当前位置查找并显示对应的歌词
                    if (isPlaying) {
                        updateCurrentLyric()
                    }
                    
                    // 继续下一次更新
                    if (isFloatingWindowVisible) {
                        handler.postDelayed(this, UPDATE_INTERVAL_MS)
                    }
                } catch (e: Exception) {
                    android.util.Log.e("FloatingLyric", "❌ 更新歌词失败: ${e.message}", e)
                }
            }
        }
        
        handler.post(updateRunnable!!)
        android.util.Log.d("FloatingLyric", "✅ 后台歌词更新循环已启动（依赖Flutter同步位置）")
    }
    
    /// 停止后台歌词更新循环
    private fun stopLyricUpdateLoop() {
        updateRunnable?.let {
            handler.removeCallbacks(it)
            updateRunnable = null
        }
        android.util.Log.d("FloatingLyric", "⏸️ 后台歌词更新循环已停止")
    }
    
    /// 根据当前播放位置更新显示的歌词
    private fun updateCurrentLyric() {
        if (lyrics.isEmpty()) {
            if (currentLyricIndex != -1) {
                updateLyricText("♪")
                currentLyricIndex = -1
            }
            return
        }
        
        // 查找当前应该显示的歌词行
        var newLineIndex = -1
        for (i in lyrics.indices) {
            if (lyrics[i].time <= currentPosition) {
                newLineIndex = i
            } else {
                break
            }
        }
        
        // 🔥 优化：只有当歌词行发生变化时才更新显示，避免频繁刷新
        if (newLineIndex != currentLyricIndex) {
            currentLyricIndex = newLineIndex
            
            if (newLineIndex >= 0 && newLineIndex < lyrics.size) {
                val currentLine = lyrics[newLineIndex]
                val displayText = if (currentLine.translation != null && currentLine.translation.isNotEmpty()) {
                    "${currentLine.text}\n${currentLine.translation}"
                } else {
                    currentLine.text
                }
                
                updateLyricText(displayText)
                android.util.Log.d("FloatingLyric", "📝 歌词已更新 [${newLineIndex + 1}/${lyrics.size}]: ${currentLine.text}")
            } else {
                // 还没开始或已结束
                updateLyricText("♪")
            }
        }
    }
}
