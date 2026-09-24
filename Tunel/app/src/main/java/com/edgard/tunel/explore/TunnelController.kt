package com.edgard.tunel.explore

import com.edgard.tunel.math.Vec3
import com.edgard.tunel.math.hypot2
import kotlin.math.atan2

class TunnelController {
    private val points = ArrayList<Vec3>()
    private val lengths = ArrayList<Float>()
    private var total = 1f
    private var traveled = 0f
    var active: Boolean = false
        private set
    var destNode: Int = -1
        private set
    var tunnelId: Int = -1
        private set

    fun start(path: List<Vec3>, dest: Int, tunnel: Int) {
        points.clear()
        for (p in path) points += Vec3(p.x, p.y, p.z)
        lengths.clear()
        total = 0f
        for (i in 1 until points.size) {
            val d = hypot2(points[i].x - points[i - 1].x, points[i].z - points[i - 1].z)
            lengths += d
            total += d
        }
        traveled = 0f
        destNode = dest
        tunnelId = tunnel
        active = true
    }

    fun update(dt: Float, player: PlayerController): Boolean {
        if (!active) return false
        traveled += 7.4f * dt
        if (traveled >= total) {
            val last = points.last()
            val prev = points[points.size - 2]
            player.place(last.x, last.z, atan2(last.x - prev.x, last.z - prev.z))
            player.walkPhase += dt * 10f
            active = false
            return true
        }
        var remain = traveled
        var i = 0
        while (i < lengths.size && remain > lengths[i]) {
            remain -= lengths[i]
            i++
        }
        val a = points[i]
        val b = points[(i + 1).coerceAtMost(points.lastIndex)]
        val seg = lengths.getOrElse(i) { 1f }.coerceAtLeast(0.01f)
        val t = remain / seg
        player.x = a.x + (b.x - a.x) * t
        player.z = a.z + (b.z - a.z) * t
        player.yaw = atan2(b.x - a.x, b.z - a.z)
        player.walkPhase += dt * 10f
        player.y = kotlin.math.abs(kotlin.math.sin(player.walkPhase)) * 0.05f
        player.moving = true
        return false
    }
}
