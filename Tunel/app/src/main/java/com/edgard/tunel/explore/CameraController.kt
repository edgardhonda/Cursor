package com.edgard.tunel.explore

import android.opengl.Matrix
import kotlin.math.cos
import kotlin.math.sin

class CameraController {
    var eyeX: Float = 0f
    var eyeY: Float = 2.4f
    var eyeZ: Float = -4f
    var targetX: Float = 0f
    var targetY: Float = 1.2f
    var targetZ: Float = 0f
    val view = FloatArray(16)
    val proj = FloatArray(16)
    val vp = FloatArray(16)
    val invVp = FloatArray(16)
    var aspect: Float = 1.6f

    fun setProjection(width: Int, height: Int) {
        aspect = width.toFloat() / height.coerceAtLeast(1).toFloat()
        Matrix.perspectiveM(proj, 0, 64f, aspect, 0.12f, 90f)
    }

    fun snap(player: PlayerController) {
        follow(player, 1f)
    }

    var tight: Boolean = false

    fun update(dt: Float, player: PlayerController) {
        follow(player, (1f - kotlin.math.exp(-dt * 8f)))
        Matrix.setLookAtM(view, 0, eyeX, eyeY, eyeZ, targetX, targetY, targetZ, 0f, 1f, 0f)
        Matrix.multiplyMM(vp, 0, proj, 0, view, 0)
        Matrix.invertM(invVp, 0, vp, 0)
    }

    fun unproject(nx: Float, ny: Float): Pair<Float, Float>? {
        val clip = floatArrayOf(nx, ny, 0f, 1f)
        val world = FloatArray(4)
        Matrix.multiplyMV(world, 0, invVp, 0, clip, 0)
        if (kotlin.math.abs(world[3]) < 1e-5f) return null
        val x0 = world[0] / world[3]
        val y0 = world[1] / world[3]
        val z0 = world[2] / world[3]
        clip[2] = 1f
        Matrix.multiplyMV(world, 0, invVp, 0, clip, 0)
        val x1 = world[0] / world[3]
        val y1 = world[1] / world[3]
        val z1 = world[2] / world[3]
        val dy = y1 - y0
        if (kotlin.math.abs(dy) < 1e-5f) return null
        val t = (0.05f - y0) / dy
        return (x0 + (x1 - x0) * t) to (z0 + (z1 - z0) * t)
    }

    private fun follow(player: PlayerController, k: Float) {
        val back = if (tight) 2.55f else 4.15f
        val dx = sin(player.yaw)
        val dz = cos(player.yaw)
        val tx = player.x - dx * back
        val ty = (if (tight) 1.9f else 2.35f) + player.y
        val tz = player.z - dz * back
        eyeX += (tx - eyeX) * k
        eyeY += (ty - eyeY) * k
        eyeZ += (tz - eyeZ) * k
        targetX = player.x + dx * 0.4f
        targetY = 1.15f + player.y
        targetZ = player.z + dz * 0.4f
    }
}
