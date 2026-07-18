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
import org.json.JSONArray

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val TAG = "MainActivity"
    }

    private var floatingChannel: MethodChannel? = null
    private var autoExitHandler: Handler? = null
    private var shouldAutoExit = false
    private var pendingAction: String? = null

    // 5 秒后自动退回后台的任务
    private val autoExitRunnable = Runnable {
        Log.d(TAG, "Auto-exit: moving task to background")
        moveTaskToBack(true)
    }

    private fun handleIntent(intent: Intent?) {
        val action = intent?.getStringExtra("pending_action")
        if (action != null) {
            Log.d(TAG, "Received pending control action from intent: $action")
            pendingAction = action
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)

        // 如果引擎已经就绪，立即分发
        val action = pendingAction
        if (action != null) {
            val callback = FloatingWindowBridge.onControlAction
            if (callback != null) {
                Log.d(TAG, "Forwarding pending action $action to active engine immediately")
                callback.invoke(action)
                pendingAction = null
                moveTaskToBack(true)
            }
        }
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

        FloatingWindowPlugin.onEngineReady = {
            runOnUiThread {
                // 如果有待处理的动作，分发至就绪的引擎
                val action = pendingAction
                if (action != null) {
                    val callback = FloatingWindowBridge.onControlAction
                    if (callback != null) {
                        Log.d(TAG, "Forwarding pending action $action to newly ready engine")
                        callback.invoke(action)
                        pendingAction = null
                    }
                }

                if (shouldAutoExit) {
                    Log.d(TAG, "Flutter engine reported ready! Moving MainActivity to background now.")
                    autoExitHandler?.removeCallbacks(autoExitRunnable)
                    moveTaskToBack(true)
                    shouldAutoExit = false
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)

        // 检查悬浮窗是否未运行（代表是第一次启动 App 或 Service 被杀）
        if (!FloatingWindowService.isRunning) {
            // 读取用户设置，判断悬浮窗是否已启用
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val enabled = prefs.getBoolean("flutter.floating_window_enabled", false)

            if (enabled) {
                shouldAutoExit = true
                // 从 SharedPreferences 中直接解析上次播放的歌名与歌手
                var lastTitle = "未知歌曲"
                var lastArtist = "未知歌手"
                val queueJson = prefs.getString("flutter.persistent_queue", null)
                val indexVal = prefs.all["flutter.persistent_queue_index"]
                val queueIndex = when (indexVal) {
                    is Long -> indexVal.toInt()
                    is Int -> indexVal
                    else -> 0
                }

                if (!queueJson.isNullOrEmpty()) {
                    try {
                        val jsonArray = JSONArray(queueJson)
                        if (queueIndex in 0 until jsonArray.length()) {
                            val songObj = jsonArray.getJSONObject(queueIndex)
                            lastTitle = songObj.optString("title", "未知歌曲")
                            lastArtist = songObj.optString("artist", "未知歌手")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to parse persistent queue: $e")
                    }
                }

                Log.d(TAG, "Floating window enabled, starting service (title=$lastTitle, artist=$lastArtist) and waiting for Flutter engine ready to auto-exit")
                startFloatingWindowService(lastTitle, lastArtist)

                // 启动一个 5 秒的后备从动定时器，防止 Flutter 引擎由于某种原因未能成功通知 ready 导致卡在界面
                autoExitHandler = Handler(Looper.getMainLooper())
                autoExitHandler?.postDelayed(autoExitRunnable, 5000)
            } else {
                Log.d(TAG, "Floating window not enabled, normal launch")
            }
        } else {
            Log.d(TAG, "Floating window already running, normal launch")
        }
    }

    private fun startFloatingWindowService(title: String, artist: String) {
        val intent = Intent(this, FloatingWindowService::class.java).apply {
            putExtra("title", title)
            putExtra("artist", artist)
            putExtra("isPlaying", false)
        }
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

        FloatingWindowPlugin.onEngineReady = null
        floatingChannel?.setMethodCallHandler(null)
        FloatingWindowPlugin.getInstance()?.dispose()
        floatingChannel = null
        super.onDestroy()
    }
}
