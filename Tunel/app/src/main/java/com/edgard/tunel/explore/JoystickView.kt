package com.edgard.tunel.explore

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import kotlin.math.hypot
import kotlin.math.min

class JoystickView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {
    var input: GameInput? = null
    private val base = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x44FFFFFF }
    private val knob = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x99F4F0E6.toInt() }
    private var stickId = -1
    private var lookId = -1
    private var cx = 0f
    private var cy = 0f
    private var kx = 0f
    private var ky = 0f
    private var show = false
    private var lookLastX = 0f
    private var lookLastY = 0f
    private var lookMoved = false

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (!show) return
        val r = min(width, height) * 0.11f
        canvas.drawCircle(cx, cy, r, base)
        canvas.drawCircle(kx, ky, r * 0.38f, knob)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val inp = input ?: return false
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> {
                val i = event.actionIndex
                val id = event.getPointerId(i)
                val x = event.getX(i)
                val y = event.getY(i)
                if (x < width * 0.42f && stickId == -1) {
                    stickId = id
                    cx = x
                    cy = y
                    kx = x
                    ky = y
                    show = true
                    inp.joyX = 0f
                    inp.joyY = 0f
                } else if (lookId == -1) {
                    lookId = id
                    lookLastX = x
                    lookLastY = y
                    lookMoved = false
                }
            }
            MotionEvent.ACTION_MOVE -> {
                for (i in 0 until event.pointerCount) {
                    val id = event.getPointerId(i)
                    val x = event.getX(i)
                    val y = event.getY(i)
                    if (id == stickId) {
                        val r = min(width, height) * 0.11f
                        var dx = x - cx
                        var dy = y - cy
                        val m = hypot(dx, dy)
                        if (m > r) {
                            dx = dx / m * r
                            dy = dy / m * r
                        }
                        kx = cx + dx
                        ky = cy + dy
                        inp.joyX = (dx / r).coerceIn(-1f, 1f)
                        inp.joyY = (-dy / r).coerceIn(-1f, 1f)
                    } else if (id == lookId) {
                        val dx = x - lookLastX
                        val dy = y - lookLastY
                        if (hypot(dx, dy) > 4f) lookMoved = true
                        inp.addLook(dx, dy)
                        lookLastX = x
                        lookLastY = y
                    }
                }
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP, MotionEvent.ACTION_CANCEL -> {
                val id = event.getPointerId(event.actionIndex)
                if (id == stickId) {
                    if (hypot(kx - cx, ky - cy) < 22f) {
                        inp.tapX = event.getX(event.actionIndex)
                        inp.tapY = event.getY(event.actionIndex)
                    }
                    stickId = -1
                    show = false
                    inp.joyX = 0f
                    inp.joyY = 0f
                } else if (id == lookId) {
                    if (!lookMoved) {
                        inp.tapX = event.getX(event.actionIndex)
                        inp.tapY = event.getY(event.actionIndex)
                    }
                    lookId = -1
                }
                if (event.actionMasked == MotionEvent.ACTION_UP || event.actionMasked == MotionEvent.ACTION_CANCEL) {
                    stickId = -1
                    lookId = -1
                    show = false
                    inp.joyX = 0f
                    inp.joyY = 0f
                }
            }
        }
        invalidate()
        return true
    }
}
