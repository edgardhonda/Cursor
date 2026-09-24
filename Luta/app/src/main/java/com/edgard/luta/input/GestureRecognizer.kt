package com.edgard.luta.input

import android.view.MotionEvent
import com.edgard.luta.combat.CombatController
import com.edgard.luta.combat.GestureAction
import com.edgard.luta.math.CombatConfig
import kotlin.math.abs
import kotlin.math.hypot

/**
 * Tap = attack in place. Swipe = direction + travel.
 * Swipes fire as soon as the finger has moved enough — do not wait for ACTION_UP.
 */
class GestureRecognizer {
    private var tracking: Boolean = false
    private var pointerId: Int = -1
    private var startX: Float = 0f
    private var startY: Float = 0f
    private var startT: Long = 0L
    private var lastX: Float = 0f
    private var lastY: Float = 0f
    private var firedSwipe: Boolean = false

    var lastLabel: String = "—"
    var fingerDown: Boolean = false
    var fingerX: Float = 0f
    var fingerY: Float = 0f

    fun process(samples: Array<TouchSample>, n: Int, combat: CombatController) {
        for (i in 0 until n) {
            val s = samples[i]
            when (s.action) {
                MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> {
                    if (!tracking) begin(s)
                }
                MotionEvent.ACTION_MOVE -> {
                    if (tracking && s.pointerId == pointerId) move(s, combat)
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP, MotionEvent.ACTION_CANCEL -> {
                    if (tracking && s.pointerId == pointerId) {
                        end(s, combat, cancelled = s.action == MotionEvent.ACTION_CANCEL)
                    }
                }
            }
        }
    }

    private fun begin(s: TouchSample) {
        tracking = true
        firedSwipe = false
        pointerId = s.pointerId
        startX = s.x
        startY = s.y
        startT = s.tNanos
        lastX = s.x
        lastY = s.y
        fingerDown = true
        fingerX = s.x
        fingerY = s.y
        lastLabel = "HOLD"
    }

    private fun move(s: TouchSample, combat: CombatController) {
        lastX = s.x
        lastY = s.y
        fingerX = s.x
        fingerY = s.y
        if (firedSwipe) return
        val dx = s.x - startX
        val dy = s.y - startY
        if (hypot(dx, dy) >= CombatConfig.SWIPE_PX) {
            val action = classify(dx, dy)
            combat.enqueue(action)
            lastLabel = action.name
            firedSwipe = true
        }
    }

    private fun end(s: TouchSample, combat: CombatController, cancelled: Boolean) {
        fingerX = s.x
        fingerY = s.y
        if (!cancelled && !firedSwipe) {
            val dx = s.x - startX
            val dy = s.y - startY
            val dist = hypot(dx, dy)
            val dur = ((s.tNanos - startT).coerceAtLeast(1L)) / 1_000_000_000f
            if (dist < CombatConfig.TAP_MAX_PX && dur <= CombatConfig.TAP_MAX_S) {
                combat.enqueue(GestureAction.TAP)
                lastLabel = "TAP"
            } else if (dist >= CombatConfig.SWIPE_PX * 0.65f) {
                val action = classify(dx, dy)
                combat.enqueue(action)
                lastLabel = action.name
            }
        }
        tracking = false
        fingerDown = false
        pointerId = -1
        firedSwipe = false
    }

    fun cancel() {
        tracking = false
        fingerDown = false
        pointerId = -1
        firedSwipe = false
        lastLabel = "—"
    }

    private fun classify(dx: Float, dy: Float): GestureAction {
        val ax = abs(dx)
        val ay = abs(dy)
        val diag = CombatConfig.DIAGONAL_RATIO
        return when {
            ay < ax * diag -> if (dx >= 0f) GestureAction.SWIPE_RIGHT else GestureAction.SWIPE_LEFT
            ax < ay * diag -> if (dy < 0f) GestureAction.SWIPE_UP else GestureAction.SWIPE_DOWN
            dy < 0f && dx >= 0f -> GestureAction.SWIPE_UP_RIGHT
            dy < 0f && dx < 0f -> GestureAction.SWIPE_UP_LEFT
            dy >= 0f && dx >= 0f -> GestureAction.SWIPE_DOWN_RIGHT
            else -> GestureAction.SWIPE_DOWN_LEFT
        }
    }
}
