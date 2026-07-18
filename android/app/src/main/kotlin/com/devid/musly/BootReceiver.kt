package com.devid.musly

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONArray

/**
 * Listens for BOOT_COMPLETED and starts the FloatingWindowService
 * if the user has enabled the auto-start feature.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.LOCKED_BOOT_COMPLETED") {
            return
        }

        Log.d(TAG, "Received boot completed broadcast")

        // Check if user enabled auto-start AND floating window feature
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val autoStartEnabled = prefs.getBoolean("flutter.boot_auto_start", false)
        val floatingWindowEnabled = prefs.getBoolean("flutter.floating_window_enabled", false)

        if (!autoStartEnabled || !floatingWindowEnabled) {
            Log.d(TAG, "Auto-start or Floating window disabled, skipping (autoStart=$autoStartEnabled, floating=$floatingWindowEnabled)")
            return
        }

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
                Log.e(TAG, "Failed to parse persistent queue on boot: $e")
            }
        }

        Log.d(TAG, "Auto-start enabled, starting FloatingWindowService directly (title=$lastTitle, artist=$lastArtist)")

        val serviceIntent = Intent(context, FloatingWindowService::class.java).apply {
            putExtra("title", lastTitle)
            putExtra("artist", lastArtist)
            putExtra("isPlaying", false)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start service on boot: $e")
        }
    }
}
