package com.cyrene.music

import android.util.Log
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AudioServiceActivity() {
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.d("MainActivity", "🔧 开始配置 Flutter Engine")
        
        try {
            // 注册悬浮歌词插件
            val plugin = FloatingLyricPlugin()
            flutterEngine.plugins.add(plugin)
            Log.d("MainActivity", "✅ 悬浮歌词插件注册成功: ${plugin::class.java.simpleName}")
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ 悬浮歌词插件注册失败: ${e.message}", e)
        }
    }
}

