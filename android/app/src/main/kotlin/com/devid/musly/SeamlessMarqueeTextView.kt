package com.devid.musly

import android.content.Context
import android.graphics.Canvas
import android.util.AttributeSet
import android.widget.TextView

class SeamlessMarqueeTextView @JvmOverloads constructor(
    context: Context, attrs: AttributeSet? = null, defStyleAttr: Int = 0
) : TextView(context, attrs, defStyleAttr) {

    private var offset = 0f
    private val speed = 0.4f * resources.displayMetrics.density // pixels per frame
    private var isMarqueeRunning = false
    private val runnable = object : Runnable {
        override fun run() {
            if (isMarqueeRunning) {
                val textWidth = paint.measureText(text.toString())
                val space = 50f * resources.displayMetrics.density
                
                if (textWidth > width && width > 0) {
                    offset -= speed
                    if (-offset >= textWidth + space) {
                        offset = 0f
                    }
                    invalidate()
                } else {
                    offset = 0f
                }
                postDelayed(this, 16)
            }
        }
    }

    fun startMarquee() {
        if (!isMarqueeRunning) {
            isMarqueeRunning = true
            removeCallbacks(runnable)
            post(runnable)
        }
    }

    fun stopMarquee() {
        isMarqueeRunning = false
        removeCallbacks(runnable)
        offset = 0f
        invalidate()
    }

    override fun setText(text: CharSequence?, type: BufferType?) {
        val currentText = this.text?.toString() ?: ""
        val newText = text?.toString() ?: ""
        if (currentText != newText) {
            offset = 0f
        }
        super.setText(text, type)
    }

    override fun onDraw(canvas: Canvas) {
        val textWidth = paint.measureText(text.toString())
        val viewWidth = width.toFloat()
        
        if (textWidth <= viewWidth) {
            offset = 0f
            super.onDraw(canvas)
        } else {
            val textToDraw = text.toString()
            val y = baseline.toFloat()
            paint.color = currentTextColor
            
            // Draw first text
            canvas.drawText(textToDraw, offset, y, paint)
            
            // Draw second text for seamless loop
            val space = 50f * resources.displayMetrics.density
            val secondOffset = offset + textWidth + space
            if (secondOffset < viewWidth) {
                canvas.drawText(textToDraw, secondOffset, y, paint)
            }
        }
    }
}
