package com.edgard.tunel.explore

import com.edgard.tunel.gen.MapGenerator
import com.edgard.tunel.math.hypot2
import com.edgard.tunel.model.GameMap
import com.edgard.tunel.render.Portal
import com.edgard.tunel.render.WorldData
import kotlin.math.cos
import kotlin.math.sin

class PlayerController {
    var x: Float = 0f
    var y: Float = 0f
    var z: Float = 0f
    var yaw: Float = 0f
    var walkPhase: Float = 0f
    var moving: Boolean = false
    var ignoreTunnel: Int = -1
    var ignoreT: Float = 0f

    fun place(nx: Float, nz: Float, nyaw: Float) {
        x = nx
        z = nz
        y = 0f
        yaw = nyaw
        moving = false
    }

    fun updateRoom(dt: Float, input: GameInput, map: GameMap, nodeId: Int, world: WorldData): Portal? {
        yaw += input.consumeLook() * 0.0075f
        if (ignoreT > 0f) ignoreT -= dt
        val fx = sin(yaw)
        val fz = cos(yaw)
        val rx = cos(yaw)
        val rz = -sin(yaw)
        val jx = input.joyX
        val jy = input.joyY
        val mx = fx * jy + rx * jx
        val mz = fz * jy + rz * jx
        val mag = hypot2(mx, mz)
        moving = mag > 0.12f
        if (moving) {
            val s = 4.6f * dt / mag.coerceAtLeast(0.12f) * mag.coerceAtMost(1f)
            x += mx * s
            z += mz * s
            walkPhase += dt * 9.5f * mag.coerceAtMost(1f)
        } else {
            walkPhase *= 0.92f
        }
        y = if (moving) kotlin.math.abs(sin(walkPhase)) * 0.05f else 0f

        val room = world.rooms.first { it.id == nodeId }
        val dx = x - room.x
        val dz = z - room.z
        val dist = hypot2(dx, dz)
        val maxR = MapGenerator.ROOM_RADIUS - 0.75f
        val portal = nearestPortal(world, nodeId, 1.45f)
        if (portal != null && (ignoreT <= 0f || portal.tunnelId != ignoreTunnel)) {
            val toward = (portal.x - x) * mx + (portal.z - z) * mz
            if (toward > 0f || dist > maxR) return portal
        }
        if (dist > maxR && dist > 0.001f) {
            x = room.x + dx / dist * maxR
            z = room.z + dz / dist * maxR
        }
        return null
    }

    fun nearestPortal(world: WorldData, nodeId: Int, maxDist: Float): Portal? {
        var best: Portal? = null
        var bestD = maxDist
        for (p in world.portals) {
            if (p.nodeId != nodeId) continue
            val d = hypot2(p.x - x, p.z - z)
            if (d < bestD) {
                bestD = d
                best = p
            }
        }
        return best
    }

    fun pickPortal(world: WorldData, nodeId: Int, wx: Float, wz: Float): Portal? {
        var best: Portal? = null
        var bestD = 3.4f
        for (p in world.portals) {
            if (p.nodeId != nodeId) continue
            val d = hypot2(p.x - wx, p.z - wz)
            if (d < bestD) {
                bestD = d
                best = p
            }
        }
        return best
    }
}
