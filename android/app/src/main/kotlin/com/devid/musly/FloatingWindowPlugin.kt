package com.devid.musly

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
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
        var onEngineReady: (() -> Unit)? = null

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
            "engineReady" -> {
                Log.d(TAG, "Engine ready event received")
                onEngineReady?.invoke()
                result.success(null)
            }
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
            "checkBatteryOptimization" -> {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                val isIgnoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    pm.isIgnoringBatteryOptimizations(context.packageName)
                } else {
                    true
                }
                result.success(isIgnoring)
            }
            "requestIgnoreBatteryOptimization" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:${context.packageName}")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            context.startActivity(intent)
                            result.success(true)
                        } catch (ex: Exception) {
                            Log.e(TAG, "Failed to request ignore battery optimization: $ex")
                            result.success(false)
                        }
                    }
                } else {
                    result.success(true)
                }
            }
            "openAutoStartSettings" -> {
                val intents = mutableListOf<Intent>()

                // Xiaomi / MIUI / HyperOS
                intents.add(Intent().apply {
                    setClassName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
                })
                
                // Huawei
                intents.add(Intent().apply {
                    setClassName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")
                })
                intents.add(Intent().apply {
                    setClassName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.bootstart.BootStartActivity")
                })
                
                // Oppo
                intents.add(Intent().apply {
                    setClassName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")
                })
                intents.add(Intent().apply {
                    setClassName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity")
                })
                
                // Vivo
                intents.add(Intent().apply {
                    setClassName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager")
                })
                intents.add(Intent().apply {
                    setClassName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")
                })
                
                // Samsung
                intents.add(Intent().apply {
                    setClassName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity")
                })

                // Meizu
                intents.add(Intent().apply {
                    setClassName("com.meizu.safe", "com.meizu.safe.permission.SmartBGActivity")
                })

                // OnePlus
                intents.add(Intent().apply {
                    setClassName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity")
                })

                var opened = false
                for (intent in intents) {
                    try {
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(intent)
                        opened = true
                        break
                    } catch (e: Exception) {
                        // Try next intent
                    }
                }

                if (!opened) {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:${context.packageName}")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        opened = true
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to open details settings: $e")
                    }
                }
                result.success(opened)
            }
            "show" -> {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)) {
                    val title = call.argument<String>("title") ?: ""
                    val artist = call.argument<String>("artist") ?: ""
                    val playing = call.argument<Boolean>("isPlaying") ?: false
                    val artwork = call.argument<String>("artworkUrl") ?: ""
                    val position = call.argument<Number>("position")?.toLong() ?: 0L
                    val duration = call.argument<Number>("duration")?.toLong() ?: 0L

                    FloatingWindowBridge.currentArtworkUrl = artwork
                    FloatingWindowBridge.currentPosition = position
                    FloatingWindowBridge.currentDuration = duration
                    FloatingWindowBridge.onArtworkChanged?.invoke(artwork)
                    FloatingWindowBridge.onProgressChanged?.invoke(position, duration)

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
                    val artwork = call.argument<String>("artworkUrl") ?: ""
                    val position = call.argument<Number>("position")?.toLong() ?: 0L
                    val duration = call.argument<Number>("duration")?.toLong() ?: 0L

                    FloatingWindowBridge.currentArtworkUrl = artwork
                    FloatingWindowBridge.currentPosition = position
                    FloatingWindowBridge.currentDuration = duration
                    FloatingWindowBridge.onArtworkChanged?.invoke(artwork)
                    FloatingWindowBridge.onProgressChanged?.invoke(position, duration)

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
            "updateProgress" -> {
                val position = call.argument<Number>("position")?.toLong() ?: 0L
                val duration = call.argument<Number>("duration")?.toLong() ?: 0L
                FloatingWindowBridge.currentPosition = position
                FloatingWindowBridge.currentDuration = duration
                FloatingWindowBridge.onProgressChanged?.invoke(position, duration)
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
