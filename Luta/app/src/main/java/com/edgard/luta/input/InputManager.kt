package com.edgard.luta.input

import android.view.MotionEvent

class TouchSample {
    var action: Int = MotionEvent.ACTION_CANCEL
    var x: Float = 0f
    var y: Float = 0f
    var tNanos: Long = 0L
    var pointerId: Int = 0

    fun set(action: Int, x: Float, y: Float, tNanos: Long, pointerId: Int) {
        this.action = action
        this.x = x
        this.y = y
        this.tNanos = tNanos
        this.pointerId = pointerId
    }
}

/**
 * Copies touch samples off the UI thread into a ring buffer.
 * ACTION_MOVE must not run gesture math or IK.
 */
class InputManager {
    private val lock = Any()
    private val buffer = Array(64) { TouchSample() }
    private var write = 0
    private var read = 0

    fun offer(event: MotionEvent): Boolean {
        val action = event.actionMasked
        if (action != MotionEvent.ACTION_DOWN &&
            action != MotionEvent.ACTION_POINTER_DOWN &&
            action != MotionEvent.ACTION_MOVE &&
            action != MotionEvent.ACTION_UP &&
            action != MotionEvent.ACTION_POINTER_UP &&
            action != MotionEvent.ACTION_CANCEL
        ) {
            return false
        }
        val t = event.eventTime * 1_000_000L
        synchronized(lock) {
            if (action == MotionEvent.ACTION_MOVE) {
                val pointers = event.pointerCount
                for (p in 0 until pointers) {
                    val id = event.getPointerId(p)
                    val hist = event.historySize
                    for (h in 0 until hist) {
                        pushLocked(
                            MotionEvent.ACTION_MOVE,
                            event.getHistoricalX(p, h),
                            event.getHistoricalY(p, h),
                            event.getHistoricalEventTime(h) * 1_000_000L,
                            id,
                        )
                    }
                    pushLocked(action, event.getX(p), event.getY(p), t, id)
                }
            } else {
                val idx = event.actionIndex
                pushLocked(action, event.getX(idx), event.getY(idx), t, event.getPointerId(idx))
            }
        }
        return true
    }

    private fun pushLocked(action: Int, x: Float, y: Float, t: Long, id: Int) {
        buffer[write].set(action, x, y, t, id)
        write = (write + 1) and 63
        if (write == read) {
            read = (read + 1) and 63
        }
    }

    fun drain(dst: Array<TouchSample>): Int {
        var n = 0
        synchronized(lock) {
            while (read != write && n < dst.size) {
                val src = buffer[read]
                dst[n].set(src.action, src.x, src.y, src.tNanos, src.pointerId)
                read = (read + 1) and 63
                n++
            }
        }
        return n
    }
}
