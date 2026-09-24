package com.edgard.tunel.render

import com.edgard.tunel.gen.MapGenerator
import com.edgard.tunel.math.angleDiff
import com.edgard.tunel.math.hypot2
import com.edgard.tunel.model.GameMap
import com.edgard.tunel.model.MapColor
import com.edgard.tunel.model.NodeType
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin

class Portal(
    val nodeId: Int,
    val tunnelId: Int,
    val x: Float,
    val z: Float,
    val yaw: Float,
    val color: MapColor,
)

class RoomSpace(
    val id: Int,
    val x: Float,
    val z: Float,
    val radius: Float,
)

class WorldData(
    val mesh: Mesh,
    val portals: List<Portal>,
    val rooms: List<RoomSpace>,
)

object WorldBuilder {
    private const val WALL_H = 3.55f
    private const val TUNNEL_W = 2.35f
    private const val TUNNEL_H = 3.15f

    fun build(map: GameMap): WorldData {
        val b = MeshBuilder()
        val portals = ArrayList<Portal>()
        val rooms = ArrayList<RoomSpace>()
        val r = MapGenerator.ROOM_RADIUS

        for (n in map.nodes) {
            rooms += RoomSpace(n.id, n.x, n.z, r)
            val floor = when (n.type) {
                NodeType.START -> floatArrayOf(0.22f, 0.32f, 0.28f)
                NodeType.TREASURE -> floatArrayOf(0.32f, 0.27f, 0.14f)
                NodeType.THREAT -> floatArrayOf(0.22f, 0.12f, 0.14f)
                else -> floatArrayOf(0.16f, 0.18f, 0.22f)
            }
            b.addDisk(n.x, 0f, n.z, r, 20, floor[0], floor[1], floor[2], 1f)
            b.addDisk(n.x, WALL_H, n.z, r * 1.02f, 20, 0.07f, 0.08f, 0.1f, -1f)

            val doors = ArrayList<Float>()
            for (t in map.incidentTunnels(n.id)) {
                val other = map.node(map.otherEnd(t, n.id))
                val dx = other.x - n.x
                val dz = other.z - n.z
                val len = hypot2(dx, dz).coerceAtLeast(0.01f)
                val ux = dx / len
                val uz = dz / len
                val px = n.x + ux * r
                val pz = n.z + uz * r
                val yaw = atan2(ux, uz)
                doors += yaw
                portals += Portal(n.id, t.id, px, pz, yaw, t.color)
                val cr = t.color.r
                val cg = t.color.g
                val cb = t.color.b
                val side = 1.15f
                val ox = cos(yaw) * side
                val oz = -sin(yaw) * side
                b.addBox(px + ox, WALL_H * 0.5f, pz + oz, 0.28f, WALL_H, 0.28f, yaw, cr, cg, cb)
                b.addBox(px - ox, WALL_H * 0.5f, pz - oz, 0.28f, WALL_H, 0.28f, yaw, cr, cg, cb)
                b.addBox(px, WALL_H - 0.12f, pz, TUNNEL_W + 0.2f, 0.24f, 0.28f, yaw, cr, cg, cb)
                b.addBox(px + ux * 0.35f, 0.07f, pz + uz * 0.35f, TUNNEL_W, 0.14f, 0.8f, yaw, cr * 0.85f, cg * 0.85f, cb * 0.85f)
            }

            val segs = 20
            for (i in 0 until segs) {
                val a = (i + 0.5f) / segs * (Math.PI * 2).toFloat()
                var blocked = false
                for (d in doors) {
                    if (kotlin.math.abs(angleDiff(a, d)) < 0.38f) {
                        blocked = true
                        break
                    }
                }
                if (blocked) continue
                val wx = n.x + sin(a) * r
                val wz = n.z + cos(a) * r
                b.addBox(wx, WALL_H * 0.5f, wz, 0.42f, WALL_H, (2f * Math.PI.toFloat() * r / segs) + 0.12f, a, 0.2f, 0.22f, 0.26f)
            }
        }

        val seen = HashSet<Int>()
        for (t in map.tunnels) {
            if (!seen.add(t.id)) continue
            val a = map.node(t.from)
            val bNode = map.node(t.to)
            val dx = bNode.x - a.x
            val dz = bNode.z - a.z
            val len = hypot2(dx, dz)
            val ux = dx / len
            val uz = dz / len
            val ax = a.x + ux * r
            val az = a.z + uz * r
            val bx = bNode.x - ux * r
            val bz = bNode.z - uz * r
            val mx = (ax + bx) * 0.5f
            val mz = (az + bz) * 0.5f
            val yaw = atan2(ux, uz)
            val dist = hypot2(bx - ax, bz - az).coerceAtLeast(0.4f)
            val cr = t.color.r
            val cg = t.color.g
            val cb = t.color.b
            b.addBox(mx, 0.08f, mz, TUNNEL_W, 0.16f, dist, yaw, cr, cg, cb)
            val side = TUNNEL_W * 0.5f + 0.12f
            val px = cos(yaw) * side
            val pz = -sin(yaw) * side
            b.addBox(mx + px, TUNNEL_H * 0.5f, mz + pz, 0.22f, TUNNEL_H, dist, yaw, cr * 0.75f, cg * 0.75f, cb * 0.75f)
            b.addBox(mx - px, TUNNEL_H * 0.5f, mz - pz, 0.22f, TUNNEL_H, dist, yaw, cr * 0.75f, cg * 0.75f, cb * 0.75f)
            b.addBox(mx, TUNNEL_H - 0.08f, mz, TUNNEL_W + 0.2f, 0.16f, dist, yaw, cr * 0.4f, cg * 0.4f, cb * 0.4f)
        }

        return WorldData(b.build(), portals, rooms)
    }
}
