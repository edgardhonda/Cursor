package com.edgard.tunel.math

import kotlin.math.sqrt

class Vec3(var x: Float = 0f, var y: Float = 0f, var z: Float = 0f) {
    fun set(nx: Float, ny: Float, nz: Float): Vec3 {
        x = nx
        y = ny
        z = nz
        return this
    }

    fun set(o: Vec3): Vec3 = set(o.x, o.y, o.z)

    fun add(o: Vec3): Vec3 {
        x += o.x
        y += o.y
        z += o.z
        return this
    }

    fun scale(s: Float): Vec3 {
        x *= s
        y *= s
        z *= s
        return this
    }

    fun length(): Float = sqrt(x * x + y * y + z * z)

    fun normalize(): Vec3 {
        val l = length()
        if (l > 1e-5f) {
            x /= l
            y /= l
            z /= l
        }
        return this
    }

    companion object {
        fun lerp(a: Vec3, b: Vec3, t: Float, out: Vec3): Vec3 {
            val u = t.coerceIn(0f, 1f)
            return out.set(
                a.x + (b.x - a.x) * u,
                a.y + (b.y - a.y) * u,
                a.z + (b.z - a.z) * u,
            )
        }
    }
}

fun hypot2(dx: Float, dz: Float): Float = sqrt(dx * dx + dz * dz)

fun angleDiff(a: Float, b: Float): Float {
    var d = a - b
    while (d > Math.PI) d -= (Math.PI * 2).toFloat()
    while (d < -Math.PI) d += (Math.PI * 2).toFloat()
    return d
}
