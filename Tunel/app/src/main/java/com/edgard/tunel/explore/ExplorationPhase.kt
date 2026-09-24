package com.edgard.tunel.explore

import com.edgard.tunel.audio.GameAudio
import com.edgard.tunel.math.Vec3
import com.edgard.tunel.math.hypot2
import com.edgard.tunel.model.GameMap
import com.edgard.tunel.model.MapColor
import com.edgard.tunel.model.NodeType
import com.edgard.tunel.model.ThreatType
import com.edgard.tunel.render.Portal
import com.edgard.tunel.render.WorldData
import kotlin.math.atan2
import kotlin.math.PI

enum class ExploreMode {
    ROOM,
    TRAVEL,
    REVEAL,
}

class ExplorationPhase(
    val map: GameMap,
    val world: WorldData,
    private val audio: GameAudio,
    private val onWin: () -> Unit,
    private val onLose: () -> Unit,
) {
    val player = PlayerController()
    val tunnel = TunnelController()
    val camera = CameraController()
    val threat = ThreatController()
    val treasure = TreasureController()
    var mode: ExploreMode = ExploreMode.ROOM
        private set
    var currentNode: Int = map.startId
        private set
    var tunnelColor: MapColor = MapColor.BLUE
        private set
    private var finished = false
    private var revealT = 0f
    private var lastStepBeat = -1

    fun start() {
        val s = map.node(map.startId)
        player.place(s.x, s.z, 0f)
        if (s.outgoing.isNotEmpty()) {
            val t = map.tunnel(s.outgoing[0])
            val o = map.node(t.to)
            player.yaw = atan2(o.x - s.x, o.z - s.z)
        }
        currentNode = map.startId
        mode = ExploreMode.ROOM
        finished = false
        revealT = 0f
        threat.reset()
        treasure.reset()
        camera.snap(player)
    }

    fun update(dt: Float, input: GameInput) {
        val clamped = dt.coerceAtMost(0.05f)
        when (mode) {
            ExploreMode.ROOM -> {
                val entered = player.updateRoom(clamped, input, map, currentNode, world)
                if (entered != null) beginTravel(entered)
                else {
                    val tap = input.consumeTap()
                    if (tap != null) {
                        val ndcX = (tap.first / input.viewW) * 2f - 1f
                        val ndcY = 1f - (tap.second / input.viewH) * 2f
                        val ground = camera.unproject(ndcX, ndcY)
                        if (ground != null) {
                            val p = player.pickPortal(world, currentNode, ground.first, ground.second)
                            if (p != null) beginTravel(p)
                        }
                    }
                }
            }
            ExploreMode.TRAVEL -> {
                input.consumeLook()
                input.consumeTap()
                if (tunnel.update(clamped, player)) arrive()
            }
            ExploreMode.REVEAL -> {
                input.consumeLook()
                input.consumeTap()
                revealT += clamped
                treasure.update(clamped)
                threat.update(clamped)
                if (!finished && revealT > 1.65f) {
                    finished = true
                    val n = map.node(currentNode)
                    if (n.type == NodeType.TREASURE) onWin() else onLose()
                }
            }
        }
        camera.tight = mode == ExploreMode.TRAVEL
        camera.update(clamped, player)
        if (player.moving || mode == ExploreMode.TRAVEL) {
            val beat = (player.walkPhase / PI).toInt()
            if (beat != lastStepBeat) {
                lastStepBeat = beat
                audio.step(mode == ExploreMode.TRAVEL)
            }
        }
    }

    private fun beginTravel(portal: Portal) {
        val dest = map.otherEnd(map.tunnel(portal.tunnelId), currentNode)
        val far = world.portals.first { it.nodeId == dest && it.tunnelId == portal.tunnelId }
        val room = world.rooms.first { it.id == dest }
        val dx = room.x - far.x
        val dz = room.z - far.z
        val len = hypot2(dx, dz).coerceAtLeast(0.01f)
        val inset = if (map.node(dest).isTerminal()) 2.35f else 1.85f
        val stopX = far.x + dx / len * inset
        val stopZ = far.z + dz / len * inset
        tunnel.start(
            listOf(
                Vec3(player.x, 0f, player.z),
                Vec3(portal.x, 0f, portal.z),
                Vec3(far.x, 0f, far.z),
                Vec3(stopX, 0f, stopZ),
            ),
            dest,
            portal.tunnelId,
        )
        tunnelColor = portal.color
        mode = ExploreMode.TRAVEL
        audio.tunnel()
    }

    private fun arrive() {
        currentNode = tunnel.destNode
        player.ignoreTunnel = tunnel.tunnelId
        player.ignoreT = 0.55f
        val n = map.node(currentNode)
        when (n.type) {
            NodeType.TREASURE -> {
                treasure.reveal(n.x, n.z)
                mode = ExploreMode.REVEAL
                revealT = 0f
                audio.treasure()
            }
            NodeType.THREAT -> {
                threat.reveal(n.threat ?: ThreatType.MONSTER, n.x, n.z)
                mode = ExploreMode.REVEAL
                revealT = 0f
                audio.threat(n.threat ?: ThreatType.MONSTER)
            }
            else -> {
                mode = ExploreMode.ROOM
                audio.room()
            }
        }
    }
}
