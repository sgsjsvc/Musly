package com.devid.musly

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class FloatingWindowPlugin(
    private val context: Context,
    private val channel: MethodChannel
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "FloatingWindowPlugin"
        private var instance: FloatingWindowPlugin? = null

        fun registerWith(context: Context, channel: MethodChannel) {
            instance = FloatingWindowPlugin(context, channel)
        }

        fun getInstance(): FloatingWindowPlugin? = instance
    }

    init {
        channel.setMethodCallHandler(this)
        FloatingWindowBridge.onControlAction = { action ->
            try {
                channel.invokeMethod("onControlAction", action)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to invoke onControlAction: $e")
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkPermission" -> {
                val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    Settings.canDrawOverlays(context)
                } else {
                    true
                }
                result.success(hasPermission)
            }
            "requestPermission" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:${context.packageName}")
                    ).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                }
                result.success(null)
            }
            "show" -> {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)) {
                    val title = call.argument<String>("title") ?: ""
                    val artist = call.argument<String>("artist") ?: ""
                    val playing = call.argument<Boolean>("isPlaying") ?: false

                    val intent = Intent(context, FloatingWindowService::class.java).apply {
                        putExtra("title", title)
                        putExtra("artist", artist)
                        putExtra("isPlaying", playing)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(intent)
                    } else {
                        context.startService(intent)
                    }
                    result.success(true)
                } else {
                    result.success(false)
                }
            }
            "hide" -> {
                try {
                    val intent = Intent(context, FloatingWindowService::class.java)
                    context.stopService(intent)
                } catch (e: Exception) {
                    Log.e(TAG, "Error stopping FloatingWindowService: $e")
                }
                result.success(true)
            }
            "update" -> {
                val title = call.argument<String>("title") ?: ""
                val artist = call.argument<String>("artist") ?: ""
                val playing = call.argument<Boolean>("isPlaying") ?: false

                val intent = Intent(context, FloatingWindowService::class.java).apply {
                    putExtra("title", title)
                    putExtra("artist", artist)
                    putExtra("isPlaying", playing)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                result.success(true)
            }
            "updateSongTitle" -> {
                val title = call.argument<String>("title") ?: "未知歌曲"
                FloatingWindowBridge.currentSongTitle = title
                result.success(null)
            }
            "updateLyrics" -> {
                val lyrics = call.argument<String>("lyrics") ?: ""
                FloatingWindowBridge.currentLyrics = lyrics
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        FloatingWindowBridge.onControlAction = null
        FloatingWindowBridge.onSongTitleChanged = null
        channel.setMethodCallHandler(null)
        instance = null
    }
}
