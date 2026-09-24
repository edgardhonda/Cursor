package com.edgard.luta.camera

class CameraController {
    var x: Float = 0f
    var y: Float = 0f
    var viewW: Float = 1f
    var viewH: Float = 1f

    fun resize(w: Float, h: Float) {
        viewW = w
        viewH = h
    }

    fun update(targetX: Float, worldW: Float, dt: Float, frozen: Boolean) {
        x = 0f
        y = 0f
    }

    fun snap(targetX: Float, worldW: Float) {
        x = 0f
        y = 0f
    }
}
