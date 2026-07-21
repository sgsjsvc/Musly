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
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.GestureDetector
import android.animation.ValueAnimator
import android.animation.ArgbEvaluator
import androidx.core.graphics.ColorUtils
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.TextView
import androidx.cardview.widget.CardView
import coil.load
import android.graphics.drawable.BitmapDrawable
import androidx.palette.graphics.Palette
import kotlin.math.abs

class FloatingWindowService : Service() {

    companion object {
        private const val TAG = "FloatingWindowService"
        private const val CHANNEL_ID = "musly_floating_window"
        private const val NOTIFICATION_ID = 7777
        var isRunning = false
            private set
    }

    private lateinit var windowManager: WindowManager
    private var floatingView: View? = null
    private var params: WindowManager.LayoutParams? = null

    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    private var isMoved = false
    private var isPlaying = false

    private var tvTitle: SeamlessMarqueeTextView? = null
    private var tvLyrics: SeamlessMarqueeTextView? = null
    private var ivArtwork: ImageView? = null
    private var ivPlayPause: ImageView? = null
    private var floatingCard: View? = null
    
    // Dynamic Island views
    private var contentContainer: View? = null
    private var dynamicIslandContainer: View? = null
    private var tvDynamicIslandTitle: SeamlessMarqueeTextView? = null
    private var textContainer: View? = null

    private var currentTextColor: Int = Color.parseColor("#E6000000")

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        FloatingWindowBridge.service = this
        initGestureDetector()
        FloatingWindowBridge.onArtworkChanged = { url ->
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                loadArtwork(url)
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForegroundWithNotification()
        val title = intent?.getStringExtra("title") ?: ""
        val artist = intent?.getStringExtra("artist") ?: ""
        isPlaying = intent?.getBooleanExtra("isPlaying", false) ?: false

        if (floatingView == null) {
            showFloatingWindow()
        }
        updateSongInfo(title, artist, isPlaying)
        loadArtwork(FloatingWindowBridge.currentArtworkUrl)
        return START_NOT_STICKY
    }

    private fun startForegroundWithNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Floating Window", NotificationManager.IMPORTANCE_LOW)
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
        }
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
            .setContentText("Running")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun showFloatingWindow() {
        val layoutInflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
        floatingView = layoutInflater.inflate(R.layout.floating_window_layout, null)
        
        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }

        var flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS

        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutFlag,
            flags,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            x = 0
            y = 0 // Fixed at top
        }

        floatingCard = floatingView?.findViewById(R.id.floating_card)
        tvTitle = floatingView?.findViewById(R.id.floating_title)
        tvLyrics = floatingView?.findViewById(R.id.floating_lyrics)
        ivArtwork = floatingView?.findViewById(R.id.floating_artwork)
        ivPlayPause = floatingView?.findViewById(R.id.floating_play_pause)
        
        contentContainer = floatingView?.findViewById(R.id.content_container)
        dynamicIslandContainer = floatingView?.findViewById(R.id.dynamic_island_container)
        tvDynamicIslandTitle = floatingView?.findViewById(R.id.dynamic_island_title)
        textContainer = floatingView?.findViewById(R.id.text_container)

        setupTouchListener()

        try {
            windowManager.addView(floatingView, params)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add view: $e")
        }
    }
    
    private lateinit var gestureDetector: GestureDetector

    private fun isViewClicked(view: View?, event: MotionEvent): Boolean {
        if (view == null || view.visibility != View.VISIBLE) return false
        val location = IntArray(2)
        view.getLocationOnScreen(location)
        val rect = android.graphics.Rect(
            location[0], location[1],
            location[0] + view.width, location[1] + view.height
        )
        return rect.contains(event.rawX.toInt(), event.rawY.toInt())
    }

    private fun initGestureDetector() {
        gestureDetector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
            override fun onDoubleTap(e: MotionEvent): Boolean {
                triggerLikeAnimation()
                FloatingWindowBridge.onControlAction?.invoke("like")
                return true
            }
            
            override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
                if (isViewClicked(floatingView?.findViewById(R.id.floating_play_pause), e)) {
                    FloatingWindowBridge.onControlAction?.invoke("play_pause")
                } else if (isViewClicked(floatingView?.findViewById(R.id.floating_prev), e)) {
                    FloatingWindowBridge.onControlAction?.invoke("previous")
                } else if (isViewClicked(floatingView?.findViewById(R.id.floating_next), e)) {
                    FloatingWindowBridge.onControlAction?.invoke("next")
                } else if (isViewClicked(textContainer, e) && contentContainer?.visibility == View.VISIBLE) {
                    switchMode(true)
                } else if (isViewClicked(dynamicIslandContainer, e) && dynamicIslandContainer?.visibility == View.VISIBLE) {
                    switchMode(false)
                } else {
                    FloatingWindowBridge.onControlAction?.invoke("wake") ?: run {
                        startActivity(Intent(this@FloatingWindowService, MainActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            putExtra("pending_action", "wake")
                        })
                    }
                }
                return true
            }
        })
    }

    private fun setupTouchListener() {
        floatingView?.setOnTouchListener { v, event ->
            gestureDetector.onTouchEvent(event)
            true
        }
    }

    private fun switchMode(toDynamicIsland: Boolean) {
        floatingCard?.animate()?.cancel()
        floatingCard?.animate()
            ?.scaleX(0f)
            ?.scaleY(0f)
            ?.alpha(0f)
            ?.setDuration(150)
            ?.withEndAction {
                if (toDynamicIsland) {
                    contentContainer?.visibility = View.GONE
                    dynamicIslandContainer?.visibility = View.VISIBLE
                } else {
                    dynamicIslandContainer?.visibility = View.GONE
                    contentContainer?.visibility = View.VISIBLE
                }
                floatingCard?.animate()
                    ?.scaleX(1f)
                    ?.scaleY(1f)
                    ?.alpha(1f)
                    ?.setDuration(300)
                    ?.setInterpolator(android.view.animation.OvershootInterpolator())
                    ?.start()
            }
            ?.start()
    }
    
    private fun triggerLikeAnimation() {
        val heart = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_media_play) // Fake heart
            setColorFilter(Color.RED)
        }
        val layoutParams = WindowManager.LayoutParams().apply {
            width = 200
            height = 200
            format = PixelFormat.TRANSLUCENT
            flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
        }
        windowManager.addView(heart, layoutParams)
        
        heart.animate().scaleX(2f).scaleY(2f).alpha(0f).setDuration(500).withEndAction {
            windowManager.removeView(heart)
        }.start()
    }

    private fun loadArtwork(url: String?) {
        if (url.isNullOrEmpty()) return
        
        val loadable: Any = if (url.startsWith("http") || url.startsWith("content://") || url.startsWith("file://")) {
            url
        } else {
            java.io.File(url)
        }
        
        ivArtwork?.load(loadable) {
            crossfade(true)
            listener(
                onSuccess = { _, result ->
                    ivArtwork?.setImageDrawable(result.drawable)
                },
                onError = { _, _ ->
                    ivArtwork?.setImageResource(android.R.drawable.ic_media_play)
                }
            )
        }
    }

    fun updateSongInfo(title: String, artist: String, playing: Boolean) {
        val displayText = if (artist.isNotEmpty()) "$title  -  $artist" else title
        if (tvTitle?.text.toString() != displayText) {
            tvTitle?.text = displayText
            tvLyrics?.text = "无歌词"
        }
        if (tvDynamicIslandTitle?.text.toString() != displayText) {
            tvDynamicIslandTitle?.text = displayText
        }
        if (playing) {
            tvTitle?.startMarquee()
            tvLyrics?.startMarquee()
            tvDynamicIslandTitle?.startMarquee()
        } else {
            tvTitle?.stopMarquee()
            tvLyrics?.stopMarquee()
            tvDynamicIslandTitle?.stopMarquee()
        }
        isPlaying = playing
        ivPlayPause?.setImageResource(if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play)
    }
    
    fun updateLyrics(lyric: String) {
        val newLyric = lyric.ifEmpty { "无歌词" }
        if (tvLyrics?.text.toString() != newLyric) {
            tvLyrics?.text = newLyric
        }
        if (isPlaying) {
            tvLyrics?.startMarquee()
        } else {
            tvLyrics?.stopMarquee()
        }
    }

    fun updateProgress(position: Int, duration: Int) {
        // No progress bar in new design
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        floatingView?.let { windowManager.removeView(it) }
        FloatingWindowBridge.service = null
    }
}

