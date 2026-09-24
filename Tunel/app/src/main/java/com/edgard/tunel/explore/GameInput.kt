package com.edgard.tunel.explore

class GameInput {
    @Volatile var joyX: Float = 0f
    @Volatile var joyY: Float = 0f
    @Volatile var lookDx: Float = 0f
    @Volatile var lookDy: Float = 0f
    @Volatile var tapX: Float = -1f
    @Volatile var tapY: Float = -1f
    @Volatile var viewW: Int = 1
    @Volatile var viewH: Int = 1

    @Synchronized
    fun addLook(dx: Float, dy: Float) {
        lookDx += dx
        lookDy += dy
    }

    @Synchronized
    fun consumeLook(): Float {
        val x = lookDx
        lookDx = 0f
        lookDy = 0f
        return x
    }

    @Synchronized
    fun consumeTap(): Pair<Float, Float>? {
        if (tapX < 0f) return null
        val p = tapX to tapY
        tapX = -1f
        tapY = -1f
        return p
    }
}
