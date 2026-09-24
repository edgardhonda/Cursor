package com.edgard.tunel.model

class MapNode(
    val id: Int,
    val type: NodeType,
    val threat: ThreatType? = null,
) {
    val outgoing = mutableListOf<Int>()
    val incoming = mutableListOf<Int>()
    var x: Float = 0f
    var z: Float = 0f

    fun isTerminal(): Boolean = type == NodeType.TREASURE || type == NodeType.THREAT
}

class MapTunnel(
    val id: Int,
    val from: Int,
    val to: Int,
    val color: MapColor,
)

class GameMap(
    val seed: Long,
    val difficulty: Difficulty,
    val nodes: List<MapNode>,
    val tunnels: List<MapTunnel>,
    val startId: Int,
    val treasureId: Int,
) {
    fun node(id: Int): MapNode = nodes[id]

    fun tunnel(id: Int): MapTunnel = tunnels[id]

    fun incidentTunnels(nodeId: Int): List<MapTunnel> {
        val n = nodes[nodeId]
        return (n.outgoing + n.incoming).map { tunnels[it] }
    }

    fun otherEnd(tunnel: MapTunnel, nodeId: Int): Int =
        if (tunnel.from == nodeId) tunnel.to else tunnel.from

    fun uniquePathToTreasure(): List<Int> {
        val path = ArrayList<Int>()
        fun dfs(id: Int, seen: BooleanArray): Boolean {
            if (seen[id]) return false
            seen[id] = true
            path.add(id)
            if (id == treasureId) return true
            for (tid in nodes[id].outgoing) {
                if (dfs(tunnels[tid].to, seen)) return true
            }
            path.removeAt(path.lastIndex)
            return false
        }
        dfs(startId, BooleanArray(nodes.size))
        return path
    }
}
