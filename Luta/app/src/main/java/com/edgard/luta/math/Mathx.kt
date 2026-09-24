package com.edgard.luta.math

import kotlin.math.exp
import kotlin.math.sqrt

object Mathx {
    fun clamp(v: Float, min: Float, max: Float): Float {
        return if (v < min) min else if (v > max) max else v
    }

    fun lerp(a: Float, b: Float, t: Float): Float = a + (b - a) * t

    fun smoothstep(t: Float): Float {
        val x = clamp(t, 0f, 1f)
        return x * x * (3f - 2f * x)
    }

    fun easeInCubic(t: Float): Float {
        val x = clamp(t, 0f, 1f)
        return x * x * x
    }

    fun easeOutCubic(t: Float): Float {
        val x = 1f - clamp(t, 0f, 1f)
        return 1f - x * x * x
    }

    fun easeInOutCubic(t: Float): Float {
        val x = clamp(t, 0f, 1f)
        return if (x < 0.5f) 4f * x * x * x else 1f - ((-2f * x + 2f).let { it * it * it } / 2f)
    }

    /** Fast start, snappy finish — used for punch acceleration. */
    fun easeInQuint(t: Float): Float {
        val x = clamp(t, 0f, 1f)
        return x * x * x * x * x
    }

    fun hypot(x: Float, y: Float): Float = sqrt(x * x + y * y)

    fun expSmoothing(dt: Float, tau: Float): Float {
        if (tau <= 1e-5f) return 1f
        return 1f - exp(-dt / tau)
    }

    fun spring(
        pos: Float,
        vel: Float,
        stiffness: Float,
        damping: Float,
        dt: Float,
        out: FloatArray,
    ) {
        val acc = -stiffness * pos - damping * vel
        val nVel = vel + acc * dt
        out[0] = pos + nVel * dt
        out[1] = nVel
    }
}
