package com.edgard.tunel.explore

import com.edgard.tunel.model.ThreatType

class ThreatController {
    var revealed: Boolean = false
    var type: ThreatType = ThreatType.MONSTER
    var time: Float = 0f
    var x: Float = 0f
    var z: Float = 0f

    fun reset() {
        revealed = false
        time = 0f
    }

    fun reveal(kind: ThreatType, nx: Float, nz: Float) {
        revealed = true
        type = kind
        time = 0f
        x = nx
        z = nz
    }

    fun update(dt: Float) {
        if (revealed) time += dt
    }

    fun height(): Float {
        val rest = when (type) {
            ThreatType.SPIDER -> 0.15f
            ThreatType.SKULL -> 0.4f
            ThreatType.GHOST -> 0.7f
            else -> 0f
        }
        val falling = 2.8f - time * 4.2f
        if (falling > rest) return falling
        return if (type == ThreatType.SKULL) rest + kotlin.math.sin(time * 8f) * 0.08f else rest
    }

    fun scale(): Float = when (type) {
        ThreatType.SKULL -> (time * 2.2f).coerceAtMost(1f)
        ThreatType.GHOST -> (0.25f + time * 1.3f).coerceAtMost(1f)
        else -> (0.4f + time * 1.6f).coerceAtMost(1f)
    }

    fun shake(): Float = when (type) {
        ThreatType.MONSTER -> if (time > 0.45f) kotlin.math.sin(time * 28f) * 0.08f else 0f
        ThreatType.SNAKE -> kotlin.math.sin(time * 10f) * 0.1f
        else -> 0f
    }
}

class TreasureController {
    var revealed: Boolean = false
    var time: Float = 0f
    var x: Float = 0f
    var z: Float = 0f

    fun reset() {
        revealed = false
        time = 0f
    }

    fun reveal(nx: Float, nz: Float) {
        revealed = true
        time = 0f
        x = nx
        z = nz
    }

    fun update(dt: Float) {
        if (revealed) time += dt
    }

    fun yaw(): Float = time * 1.35f
    fun lift(): Float = 1.05f + kotlin.math.sin(time * 3.2f) * 0.12f + (time * 0.15f).coerceAtMost(0.25f)
    fun scale(): Float = (0.55f + time * 1.1f).coerceAtMost(1.15f)
}
