package com.devid.musly

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val TAG = "MainActivity"
    }

    private var floatingChannel: MethodChannel? = null
    private var autoExitHandler: Handler? = null

    // 5 秒后自动退回后台的任务
    private val autoExitRunnable = Runnable {
        Log.d(TAG, "Auto-exit: moving task to background")
        moveTaskToBack(true)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine.plugins.add(AndroidAutoPlugin)
        flutterEngine.plugins.add(AndroidSystemPlugin)
        flutterEngine.plugins.add(BluetoothAvrcpPlugin)
        flutterEngine.plugins.add(SamsungIntegrationPlugin)

        LyricsPlugin.registerWith(flutterEngine)
        PitchPlugin.registerWith(flutterEngine)
        DolbyAtmosPlugin.registerWith(flutterEngine, this)

        floatingChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.musly/floating_window"
        )
        FloatingWindowPlugin.registerWith(applicationContext, floatingChannel!!)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 检查悬浮窗是否未运行（代表是第一次启动 App 或 Service 被杀）
        if (!FloatingWindowService.isRunning) {
            // 读取用户设置，判断悬浮窗是否已启用
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val enabled = prefs.getBoolean("flutter.floating_window_enabled", false)

            if (enabled) {
                Log.d(TAG, "Floating window enabled, starting service and auto-exit in 5s")
                startFloatingWindowService()

                // 5 秒后自动退至后台
                autoExitHandler = Handler(Looper.getMainLooper())
                autoExitHandler?.postDelayed(autoExitRunnable, 5000)
            } else {
                Log.d(TAG, "Floating window not enabled, normal launch")
            }
        } else {
            Log.d(TAG, "Floating window already running, normal launch")
        }
    }

    private fun startFloatingWindowService() {
        val intent = Intent(this, FloatingWindowService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    override fun onDestroy() {
        // 及时移除定时器，防止内存泄漏
        autoExitHandler?.removeCallbacks(autoExitRunnable)
        autoExitHandler = null

        floatingChannel?.setMethodCallHandler(null)
        FloatingWindowPlugin.getInstance()?.dispose()
        floatingChannel = null
        super.onDestroy()
    }
}
