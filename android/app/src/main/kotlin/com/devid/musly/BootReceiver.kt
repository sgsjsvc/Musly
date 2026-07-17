package com.devid.musly

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

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

        Log.d(TAG, "Auto-start enabled, starting FloatingWindowService")

        val serviceIntent = Intent(context, FloatingWindowService::class.java)
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
