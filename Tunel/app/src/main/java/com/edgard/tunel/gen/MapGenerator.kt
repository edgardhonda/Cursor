package com.edgard.tunel.gen

import com.edgard.tunel.model.Difficulty
import com.edgard.tunel.model.GameMap
import com.edgard.tunel.model.MapColor
import com.edgard.tunel.model.MapNode
import com.edgard.tunel.model.MapTunnel
import com.edgard.tunel.model.NodeType
import com.edgard.tunel.model.ThreatType
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin
import kotlin.random.Random

object MapGenerator {
    const val ROOM_RADIUS = 4.8f
    const val ROOM_SPACING = 20.5f

    fun generate(seed: Long, difficulty: Difficulty): GameMap {
        return try {
            for (attempt in 0 until 40) {
                val rng = Random(seed + attempt * 997L)
                val map = build(rng, seed, difficulty)
                if (MapValidator.validate(map).ok) return map
            }
            fallback(seed, difficulty)
        } catch (_: Exception) {
            fallback(seed, difficulty)
        }
    }

    private fun build(rng: Random, seed: Long, d: Difficulty): GameMap {
        val nodes = ArrayList<MapNode>()
        val tunnels = ArrayList<MapTunnel>()

        fun addNode(type: NodeType, threat: ThreatType? = null): MapNode {
            val n = MapNode(nodes.size, type, threat)
            nodes += n
            return n
        }

        fun pickColor(from: MapNode, to: MapNode): MapColor {
            val used = usedColors(from, tunnels) + usedColors(to, tunnels)
            val free = MapColor.entries.filter { it !in used }
            return if (free.isEmpty()) MapColor.entries[rng.nextInt(MapColor.entries.size)]
            else free[rng.nextInt(free.size)]
        }

        fun connect(from: MapNode, to: MapNode) {
            val color = pickColor(from, to)
            val t = MapTunnel(tunnels.size, from.id, to.id, color)
            tunnels += t
            from.outgoing += t.id
            to.incoming += t.id
        }

        val start = addNode(NodeType.START)
        val pathLen = rng.nextInt(d.pathMin, d.pathMax + 1)
        val main = ArrayList<MapNode>()
        main += start
        var cur = start
        repeat(pathLen - 1) {
            val n = addNode(NodeType.NORMAL)
            connect(cur, n)
            main += n
            cur = n
        }
        val treasure = addNode(NodeType.TREASURE)
        connect(cur, treasure)

        var extra = rng.nextInt(d.extraBranches.first, d.extraBranches.last + 1)
        val branchable = ArrayList(main)
        while (extra > 0 && nodes.size < d.maxNodes && branchable.isNotEmpty()) {
            val parent = branchable[rng.nextInt(branchable.size)]
            val degree = parent.outgoing.size
            if (degree >= d.maxOut) {
                branchable.remove(parent)
                continue
            }
            val depth = rng.nextInt(d.branchDepth.first, d.branchDepth.last + 1)
            var walk = parent
            repeat(depth) {
                if (nodes.size >= d.maxNodes - 1) return@repeat
                val n = addNode(NodeType.NORMAL)
                connect(walk, n)
                if (d.level >= 2 && rng.nextFloat() < 0.28f) branchable += n
                walk = n
            }
            val threat = addNode(NodeType.THREAT, ThreatType.entries[rng.nextInt(3)])
            connect(walk, threat)
            extra--
        }

        val rooms = nodes.filter { it.type == NodeType.START || it.type == NodeType.NORMAL }
        for (n in rooms) {
            while (n.outgoing.size < d.minOut && nodes.size < d.maxNodes) {
                val threat = addNode(NodeType.THREAT, ThreatType.entries[rng.nextInt(3)])
                connect(n, threat)
            }
        }

        layout(nodes, tunnels)
        return GameMap(seed, d, nodes, tunnels, start.id, treasure.id)
    }

    private fun layout(nodes: List<MapNode>, tunnels: List<MapTunnel>) {
        val start = nodes.first { it.type == NodeType.START }
        start.x = 0f
        start.z = 0f
        val placed = BooleanArray(nodes.size)
        placed[start.id] = true

        fun place(node: MapNode, incomingAngle: Float) {
            val kids = node.outgoing.map { tunnels[it].to }
            val n = kids.size
            if (n == 0) return
            val cone = when (n) {
                1 -> 0f
                2 -> 0.95f
                3 -> 1.25f
                else -> 1.45f
            }
            val forward = incomingAngle
            for (i in kids.indices) {
                val child = nodes[kids[i]]
                if (placed[child.id]) continue
                val t = if (n == 1) 0f else (i - (n - 1) / 2f)
                val step = if (n == 1) 0f else cone / (n - 1)
                val ang = forward + t * step
                child.x = node.x + sin(ang) * ROOM_SPACING
                child.z = node.z + cos(ang) * ROOM_SPACING
                placed[child.id] = true
                place(child, ang)
            }
        }
        place(start, 0f)

        repeat(18) {
            for (i in nodes.indices) {
                for (j in i + 1 until nodes.size) {
                    val a = nodes[i]
                    val b = nodes[j]
                    val dx = b.x - a.x
                    val dz = b.z - a.z
                    val dist = hypot(dx, dz)
                    val minD = ROOM_SPACING * 0.82f
                    if (dist < minD && dist > 0.01f) {
                        val push = (minD - dist) * 0.5f
                        val nx = dx / dist
                        val nz = dz / dist
                        a.x -= nx * push
                        a.z -= nz * push
                        b.x += nx * push
                        b.z += nz * push
                    }
                }
            }
        }
    }

    private fun fallback(seed: Long, d: Difficulty): GameMap {
        val rng = Random(seed)
        val start = MapNode(0, NodeType.START)
        val a = MapNode(1, NodeType.NORMAL)
        val treasure = MapNode(2, NodeType.TREASURE)
        val threat = MapNode(3, NodeType.THREAT, ThreatType.MONSTER)
        val t0 = MapTunnel(0, 0, 1, MapColor.RED)
        val t1 = MapTunnel(1, 1, 2, MapColor.BLUE)
        val t2 = MapTunnel(2, 0, 3, MapColor.GREEN)
        start.outgoing += 0
        start.outgoing += 2
        a.incoming += 0
        a.outgoing += 1
        treasure.incoming += 1
        threat.incoming += 2
        start.x = 0f
        start.z = 0f
        a.x = 0f
        a.z = ROOM_SPACING
        treasure.x = 0f
        treasure.z = ROOM_SPACING * 2
        threat.x = ROOM_SPACING
        threat.z = 0f
        return GameMap(seed, d, listOf(start, a, treasure, threat), listOf(t0, t1, t2), 0, 2).also {
            rng.nextInt()
        }
    }
}
