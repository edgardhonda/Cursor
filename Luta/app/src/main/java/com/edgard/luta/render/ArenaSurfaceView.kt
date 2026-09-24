package com.edgard.luta.render

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.view.MotionEvent
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import com.edgard.luta.audio.GameAudio
import com.edgard.luta.game.GameLoop
import com.edgard.luta.game.GameSpeed
import com.edgard.luta.game.GameWorld

class ArenaSurfaceView(context: Context) : SurfaceView(context), SurfaceHolder.Callback {
    private val audio = GameAudio(context)
    private val world = GameWorld(
        onHitFeel = { performHapticFeedback(android.view.HapticFeedbackConstants.KEYBOARD_TAP) },
        audio = audio,
    )
    private var loop: GameLoop? = null

    init {
        holder.addCallback(this)
        holder.setFormat(PixelFormat.OPAQUE)
        isFocusable = true
        isFocusableInTouchMode = true
        keepScreenOn = true
        val prefs = context.getSharedPreferences("luta", Context.MODE_PRIVATE)
        val ord = prefs.getInt("speed", GameSpeed.MEDIUM.ordinal)
        world.speed = GameSpeed.entries.getOrElse(ord.coerceIn(0, 2)) { GameSpeed.MEDIUM }
        world.onSpeedChanged = { next ->
            prefs.edit().putInt("speed", next.ordinal).apply()
        }
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        requestHighFrameRate(holder)
        val thread = GameLoop(holder, world)
        loop = thread
        thread.running = true
        thread.start()
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        requestHighFrameRate(holder)
        world.resize(width, height)
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        val thread = loop ?: return
        thread.running = false
        try {
            thread.join(400)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        loop = null
    }

    override fun onDetachedFromWindow() {
        audio.release()
        super.onDetachedFromWindow()
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            requestUnbufferedDispatch(event)
        }
        world.input.offer(event)
        return true
    }

    override fun onWindowVisibilityChanged(visibility: Int) {
        super.onWindowVisibilityChanged(visibility)
        if (visibility != View.VISIBLE) {
            world.pause()
        }
    }

    private fun requestHighFrameRate(holder: SurfaceHolder) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val surface = holder.surface
            if (surface.isValid) {
                surface.setFrameRate(
                    120f,
                    android.view.Surface.FRAME_RATE_COMPATIBILITY_DEFAULT,
                )
            }
        }
    }
}
