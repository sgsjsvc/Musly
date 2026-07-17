package com.devid.musly

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.text.TextUtils
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

class FloatingWindowService : Service() {

    companion object {
        private const val TAG = "FloatingWindowService"
        private const val CHANNEL_ID = "musly_floating_window"
        private const val NOTIFICATION_ID = 7777

        // 用于给 MainActivity 检查悬浮窗是否已经在运行
        var isRunning = false
            private set
    }

    private lateinit var windowManager: WindowManager
    private var floatingView: LinearLayout? = null
    private var params: WindowManager.LayoutParams? = null
    private val handler = Handler(Looper.getMainLooper())

    private var tvTitle: TextView? = null
    private var tvArtist: TextView? = null
    private var btnPlayPause: ImageView? = null

    private var isPlaying = false
    private var isHiding = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        // 监听歌名变化并动态更新
        FloatingWindowBridge.onSongTitleChanged = { title ->
            tvTitle?.post {
                tvTitle?.text = title
                tvTitle?.isSelected = true
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 如果正在隐藏状态，忽略重启请求（防止竞态）
        if (isHiding) return START_NOT_STICKY

        // Start as foreground service first (prevents kill on Android 8+)
        startForegroundWithNotification()

        // Parse extras
        val title = intent?.getStringExtra("title") ?: ""
        val artist = intent?.getStringExtra("artist") ?: ""
        isPlaying = intent?.getBooleanExtra("isPlaying", false) ?: false

        if (floatingView == null) {
            showFloatingWindow()
        }
        updateSongInfo(title, artist, isPlaying)

        return START_NOT_STICKY
    }

    private fun startForegroundWithNotification() {
        createNotificationChannel()

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("Musly")
            .setContentText("悬浮窗控制中")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "悬浮窗服务",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "悬浮窗控制通知"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun showFloatingWindow() {
        if (floatingView != null) {
            Log.d(TAG, "Floating window already showing")
            return
        }

        val density = resources.displayMetrics.density

        // ── Root layout ──────────────────────────────────────────────
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setBackgroundColor(Color.parseColor("#E61C1C1E"))
            setPadding((12 * density).toInt(), (8 * density).toInt(),
                       (12 * density).toInt(), (8 * density).toInt())
            gravity = Gravity.CENTER_VERTICAL
        }

        // ── Drag handle ──────────────────────────────────────────────
        val dragHandle = TextView(this).apply {
            text = "☰"
            setTextColor(Color.parseColor("#99FFFFFF"))
            textSize = 16f
            setPadding((8 * density).toInt(), (8 * density).toInt(),
                       (8 * density).toInt(), (8 * density).toInt())
        }
        root.addView(dragHandle)

        // ── Song info (跑马灯歌名 + 艺术家) ──────────────────────────
        val infoLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((8 * density).toInt(), 0, (16 * density).toInt(), 0)
            layoutParams = LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f
            )
        }

        // 歌名 — 跑马灯滚动
        tvTitle = TextView(this).apply {
            text = FloatingWindowBridge.currentSongTitle
            setTextColor(Color.WHITE)
            textSize = 13f
            typeface = Typeface.DEFAULT_BOLD

            // 跑马灯滚动核心配置
            ellipsize = TextUtils.TruncateAt.MARQUEE
            isSingleLine = true
            marqueeRepeatLimit = -1
            isSelected = true
            isFocusable = true
            isFocusableInTouchMode = true
            setHorizontallyScrolling(true)
            isEnabled = true

            // 限制宽度以触发滚动（130dp）
            val widthInPx = (130 * density).toInt()
            layoutParams = LinearLayout.LayoutParams(
                widthInPx,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
        infoLayout.addView(tvTitle)

        // 艺术家
        tvArtist = TextView(this).apply {
            text = ""
            setTextColor(Color.parseColor("#99FFFFFF"))
            textSize = 11f
            maxLines = 1
            maxEms = 16
            isSingleLine = true
            ellipsize = TextUtils.TruncateAt.END
        }
        infoLayout.addView(tvArtist)

        root.addView(infoLayout)

        // ── Play / Pause button ──────────────────────────────────────
        val iconSize = (28 * density).toInt()
        val iconPadding = (6 * density).toInt()
        btnPlayPause = ImageView(this).apply {
            setImageResource(
                if (isPlaying) R.drawable.ic_floating_pause
                else R.drawable.ic_floating_play
            )
            setPadding(iconPadding, iconPadding, iconPadding, iconPadding)
            setOnClickListener {
                Log.d(TAG, "Play/Pause clicked")
                FloatingWindowBridge.onControlAction?.invoke("play_pause")
            }
            layoutParams = LinearLayout.LayoutParams(iconSize, iconSize)
        }
        root.addView(btnPlayPause)

        // ── Next button ──────────────────────────────────────────────
        val btnNext = ImageView(this).apply {
            setImageResource(R.drawable.ic_floating_next)
            setPadding(iconPadding, iconPadding, iconPadding, iconPadding)
            setOnClickListener {
                Log.d(TAG, "Next clicked")
                FloatingWindowBridge.onControlAction?.invoke("next")
            }
            layoutParams = LinearLayout.LayoutParams(iconSize, iconSize)
        }
        root.addView(btnNext)

        // ── WindowManager layout type ────────────────────────────────
        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        // ── Layout params ────────────────────────────────────────────
        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            x = 0
            y = 200
        }

        // ── Drag handling ────────────────────────────────────────────
        dragHandle.setOnTouchListener(object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0f
            private var initialTouchY = 0f

            override fun onTouch(v: View?, event: MotionEvent?): Boolean {
                if (event == null) return false
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = params?.x ?: 0
                        initialY = params?.y ?: 0
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        params?.x = initialX + (event.rawX - initialTouchX).toInt()
                        params?.y = initialY + (event.rawY - initialTouchY).toInt()
                        try {
                            windowManager.updateViewLayout(floatingView, params)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error updating layout during drag: $e")
                        }
                        return true
                    }
                }
                return false
            }
        })

        // ── Add to screen ────────────────────────────────────────────
        try {
            windowManager.addView(root, params)
            floatingView = root
            Log.d(TAG, "Floating window added to screen")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add floating window: $e")
            floatingView = null
        }
    }

    fun updateSongInfo(title: String, artist: String, playing: Boolean) {
        isPlaying = playing
        handler.post {
            tvTitle?.text = title
            tvTitle?.isSelected = true
            tvArtist?.text = artist
            btnPlayPause?.setImageResource(
                if (isPlaying) R.drawable.ic_floating_pause
                else R.drawable.ic_floating_play
            )
        }
    }

    fun hide() {
        isHiding = true
        handler.post {
            floatingView?.let {
                try {
                    windowManager.removeView(it)
                } catch (e: Exception) {
                    Log.e(TAG, "Error removing floating view: $e")
                }
            }
            floatingView = null
            params = null
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            Log.d(TAG, "Floating window removed")
        }
    }

    fun isShowing(): Boolean = floatingView != null

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        // 只清空与 Service 视图渲染相关的监听器
        // onControlAction 的生命周期由 Flutter 引擎（Plugin）管理，不在这里清空
        FloatingWindowBridge.onSongTitleChanged = null
        handler.post {
            floatingView?.let {
                try {
                    windowManager.removeView(it)
                } catch (e: Exception) {
                    Log.e(TAG, "Error removing floating view in onDestroy: $e")
                }
            }
            floatingView = null
            params = null
            // 清理 Handler 队列，防止内存泄漏
            handler.removeCallbacksAndMessages(null)
        }
    }
}
