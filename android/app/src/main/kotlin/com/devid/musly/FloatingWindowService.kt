package com.devid.musly

import android.animation.AnimatorSet
import android.animation.ObjectAnimator
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
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.view.GestureDetector
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.OvershootInterpolator
import android.widget.ImageView
import android.widget.ProgressBar
import android.widget.TextSwitcher
import android.widget.TextView
import androidx.cardview.widget.CardView
import androidx.palette.graphics.Palette
import coil.load
import coil.transform.CircleCropTransformation
import android.graphics.drawable.BitmapDrawable

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
    private val handler = Handler(Looper.getMainLooper())

    private var tvTitle: TextView? = null
    private var tvArtist: TextSwitcher? = null
    private var btnPlayPause: ImageView? = null
    private var btnPrev: ImageView? = null
    private var btnNext: ImageView? = null
    private var btnClose: ImageView? = null
    private var ivArtwork: ImageView? = null
    private var progressBar: ProgressBar? = null
    private var cardRoot: CardView? = null
    private var songInfoContainer: View? = null
    
    private var isPlaying = false
    private var currentArtist = ""
    private var currentLyrics = ""
    private var screenWidth = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        screenWidth = resources.displayMetrics.widthPixels

        FloatingWindowBridge.onSongTitleChanged = { title ->
            tvTitle?.post {
                tvTitle?.text = title
                tvTitle?.isSelected = true
            }
        }
        FloatingWindowBridge.onLyricsChanged = { lyrics ->
            currentLyrics = lyrics
            handler.post {
                tvArtist?.setText(if (lyrics.isBlank()) currentArtist else lyrics)
            }
        }
        FloatingWindowBridge.onProgressChanged = { pos, dur ->
            handler.post {
                if (dur > 0) {
                    progressBar?.max = dur.toInt()
                    progressBar?.progress = pos.toInt()
                }
            }
        }
        FloatingWindowBridge.onArtworkChanged = { url ->
            handler.post { loadArtwork(url) }
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
        FloatingWindowBridge.onProgressChanged?.invoke(
            FloatingWindowBridge.currentPosition, 
            FloatingWindowBridge.currentDuration
        )
        return START_NOT_STICKY
    }

    private fun startForegroundWithNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "悬浮窗服务", NotificationManager.IMPORTANCE_LOW)
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
            .setContentText("悬浮窗运行中")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
        startForeground(NOTIFICATION_ID, notification)
    }

    private fun showFloatingWindow() {
        val layoutInflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
        floatingView = layoutInflater.inflate(R.layout.floating_window_layout, null)
        
        cardRoot = floatingView?.findViewById(R.id.floating_card)
        tvTitle = floatingView?.findViewById(R.id.floating_title)
        tvTitle?.isSelected = true
        tvArtist = floatingView?.findViewById(R.id.floating_artist)
        btnPlayPause = floatingView?.findViewById(R.id.floating_play_pause)
        btnPrev = floatingView?.findViewById(R.id.floating_prev)
        btnNext = floatingView?.findViewById(R.id.floating_next)
        btnClose = floatingView?.findViewById(R.id.floating_close)
        ivArtwork = floatingView?.findViewById(R.id.floating_artwork)
        progressBar = floatingView?.findViewById(R.id.floating_progress)
        songInfoContainer = floatingView?.findViewById(R.id.song_info_container)

        // TextSwitcher config
        tvArtist?.setFactory {
            TextView(this).apply {
                setTextColor(Color.parseColor("#99FFFFFF"))
                textSize = 12f
                maxLines = 1
                isSingleLine = true
                ellipsize = android.text.TextUtils.TruncateAt.END
            }
        }
        tvArtist?.inAnimation = android.view.animation.AnimationUtils.loadAnimation(this, android.R.anim.fade_in).apply { duration = 300 }
        tvArtist?.outAnimation = android.view.animation.AnimationUtils.loadAnimation(this, android.R.anim.fade_out).apply { duration = 300 }

        btnPlayPause?.setOnClickListener { triggerControlAction("play_pause") }
        btnPrev?.setOnClickListener { triggerControlAction("previous") }
        btnNext?.setOnClickListener { triggerControlAction("next") }
        btnClose?.setOnClickListener { 
            triggerControlAction("close")
            hide() 
        }

        setupTouchListener()

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 50
            y = 200
        }

        try {
            windowManager.addView(floatingView, params)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add view: $e")
        }
    }

    private fun setupTouchListener() {
        val gestureDetector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
            override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
                // Wake up app
                val intent = Intent(this@FloatingWindowService, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                }
                startActivity(intent)
                return true
            }
            override fun onDoubleTap(e: MotionEvent): Boolean {
                triggerControlAction("like")
                bounceAnimation()
                return true
            }
        })

        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var isDragging = false
        var isMiniMode = false

        floatingView?.setOnTouchListener { v, event ->
            gestureDetector.onTouchEvent(event)
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params?.x ?: 0
                    initialY = params?.y ?: 0
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isDragging = false
                    if (isMiniMode) {
                        isMiniMode = false
                        restoreFromMini()
                    }
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - initialTouchX
                    val dy = event.rawY - initialTouchY
                    if (Math.abs(dx) > 10 || Math.abs(dy) > 10) isDragging = true
                    if (isDragging) {
                        params?.x = initialX + dx.toInt()
                        params?.y = initialY + dy.toInt()
                        windowManager.updateViewLayout(floatingView, params)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (isDragging) {
                        // Edge snapping
                        val x = params?.x ?: 0
                        if (x < screenWidth / 4) {
                            snapToEdgeAndMinimize(true)
                            isMiniMode = true
                        } else if (x > screenWidth * 3 / 4) {
                            snapToEdgeAndMinimize(false)
                            isMiniMode = true
                        }
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun snapToEdgeAndMinimize(left: Boolean) {
        val targetX = if (left) -50 else screenWidth
        params?.x = targetX
        windowManager.updateViewLayout(floatingView, params)
        
        // Hide info, keep only artwork
        songInfoContainer?.visibility = View.GONE
        btnPlayPause?.visibility = View.GONE
        btnPrev?.visibility = View.GONE
        btnNext?.visibility = View.GONE
        btnClose?.visibility = View.GONE
        progressBar?.visibility = View.GONE
    }

    private fun restoreFromMini() {
        songInfoContainer?.visibility = View.VISIBLE
        btnPlayPause?.visibility = View.VISIBLE
        btnPrev?.visibility = View.VISIBLE
        btnNext?.visibility = View.VISIBLE
        btnClose?.visibility = View.VISIBLE
        progressBar?.visibility = View.VISIBLE
        
        val x = params?.x ?: 0
        if (x < 0) params?.x = 0
        if (x > screenWidth - (floatingView?.width ?: 0)) {
            params?.x = screenWidth - (floatingView?.width ?: 0)
        }
        windowManager.updateViewLayout(floatingView, params)
    }

    private fun bounceAnimation() {
        val scaleX = ObjectAnimator.ofFloat(floatingView, "scaleX", 1f, 1.1f, 1f)
        val scaleY = ObjectAnimator.ofFloat(floatingView, "scaleY", 1f, 1.1f, 1f)
        AnimatorSet().apply {
            playTogether(scaleX, scaleY)
            duration = 300
            interpolator = OvershootInterpolator()
            start()
        }
    }

    private fun loadArtwork(url: String) {
        if (url.isBlank()) {
            ivArtwork?.setImageResource(android.R.drawable.ic_media_play)
            cardRoot?.setCardBackgroundColor(Color.parseColor("#D6222226"))
            return
        }
        ivArtwork?.load(url) {
            transformations(CircleCropTransformation())
            allowHardware(false)
            target { result ->
                ivArtwork?.setImageDrawable(result)
                if (result is BitmapDrawable) {
                    Palette.from(result.bitmap).generate { palette: Palette? ->
                        val vibrant = palette?.getVibrantColor(Color.parseColor("#D6222226")) ?: Color.parseColor("#D6222226")
                        // Apply semi-transparency (alpha 0xD6)
                        val color = (vibrant and 0x00FFFFFF) or -0x2a000000
                        cardRoot?.setCardBackgroundColor(color)
                    }
                }
            }
        }
    }

    fun updateSongInfo(title: String, artist: String, playing: Boolean) {
        isPlaying = playing
        currentArtist = artist
        currentLyrics = ""
        handler.post {
            tvTitle?.text = title
            tvTitle?.isSelected = true
            tvArtist?.setText(artist)
            btnPlayPause?.setImageResource(if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play)
        }
    }

    fun hide() {
        handler.post {
            floatingView?.let { windowManager.removeView(it) }
            floatingView = null
            params = null
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        FloatingWindowBridge.onSongTitleChanged = null
        FloatingWindowBridge.onLyricsChanged = null
        FloatingWindowBridge.onArtworkChanged = null
        FloatingWindowBridge.onProgressChanged = null
        handler.post {
            floatingView?.let { windowManager.removeView(it) }
            floatingView = null
            params = null
            handler.removeCallbacksAndMessages(null)
        }
    }

    private fun triggerControlAction(action: String) {
        FloatingWindowBridge.onControlAction?.invoke(action) ?: run {
            startActivity(Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                putExtra("pending_action", action)
            })
        }
    }
}
