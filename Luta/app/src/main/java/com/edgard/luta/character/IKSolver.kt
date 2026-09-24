package com.edgard.luta.character

import kotlin.math.acos
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt
import com.edgard.luta.math.Mathx

object IKSolver {
    /**
     * Analytic two-bone IK. Writes mid (elbow/knee) and end (hand/foot) in world space.
     * [bend] selects the side of the joint (+1 or -1). Y-down canvas: +angle is clockwise.
     */
    fun solveTwoBone(
        originX: Float,
        originY: Float,
        len1: Float,
        len2: Float,
        targetX: Float,
        targetY: Float,
        bend: Float,
        mid: Joint,
        end: Joint,
    ) {
        var dx = targetX - originX
        var dy = targetY - originY
        var dist = sqrt(dx * dx + dy * dy)
        if (dist < 1e-4f) {
            dx = 1f
            dy = 0f
            dist = 1e-4f
        }
        val maxReach = len1 + len2
        val minReach = kotlin.math.abs(len1 - len2) + 0.35f
        val clamped = Mathx.clamp(dist, minReach, maxReach)
        val s = clamped / dist
        val cx = originX + dx * s
        val cy = originY + dy * s
        val d = clamped
        val cosA = Mathx.clamp((len1 * len1 + d * d - len2 * len2) / (2f * len1 * d), -1f, 1f)
        val atOrigin = acos(cosA.toDouble()).toFloat()
        val base = atan2(cy - originY, cx - originX)
        val a1 = base + bend * atOrigin
        mid.worldX = originX + cos(a1) * len1
        mid.worldY = originY + sin(a1) * len1
        end.worldX = cx
        end.worldY = cy
    }
}
