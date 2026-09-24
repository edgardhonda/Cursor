package com.edgard.tunel.gen

import com.edgard.tunel.model.GameMap
import com.edgard.tunel.model.MapColor
import com.edgard.tunel.model.MapNode
import com.edgard.tunel.model.NodeType

class ValidationResult(
    val ok: Boolean,
    val errors: List<String>,
)

object MapValidator {
    fun validate(map: GameMap): ValidationResult {
        val errors = ArrayList<String>()
        val starts = map.nodes.filter { it.type == NodeType.START }
        val treasures = map.nodes.filter { it.type == NodeType.TREASURE }
        val threats = map.nodes.filter { it.type == NodeType.THREAT }
        if (starts.size != 1) errors += "precisa de exatamente um START"
        if (treasures.size != 1) errors += "precisa de exatamente um TREASURE"
        if (threats.isEmpty()) errors += "precisa de pelo menos um THREAT"

        for (n in map.nodes) {
            if (n.isTerminal() && n.outgoing.isNotEmpty()) {
                errors += "terminal ${n.id} tem saída"
            }
            if (n.type == NodeType.START && n.outgoing.isEmpty()) {
                errors += "START sem túnel"
            }
            if (n.type == NodeType.NORMAL && n.outgoing.isEmpty()) {
                errors += "NORMAL ${n.id} sem saída"
            }
        }

        for (t in map.tunnels) {
            if (t.from !in map.nodes.indices || t.to !in map.nodes.indices) {
                errors += "túnel ${t.id} sem destino válido"
            }
        }

        for (n in map.nodes) {
            val colors = map.incidentTunnels(n.id).map { it.color }
            if (colors.size != colors.toSet().size) {
                errors += "cores duplicadas na sala ${n.id}"
            }
        }

        val pathCount = countSimplePaths(map, map.startId, map.treasureId, BooleanArray(map.nodes.size))
        if (pathCount == 0) errors += "TREASURE inacessível"
        if (pathCount > 1) errors += "mais de um caminho até a coroa"

        val reachable = BooleanArray(map.nodes.size)
        dfsReach(map, map.startId, reachable)
        for (n in map.nodes) {
            if (!reachable[n.id]) errors += "nó isolado ${n.id}"
            if (n.outgoing.isEmpty() && n.incoming.isEmpty()) errors += "nó ${n.id} sem túneis"
            if (n.outgoing.isEmpty() && n.type != NodeType.TREASURE && n.type != NodeType.THREAT) {
                errors += "folha ${n.id} não é terminal"
            }
        }

        return ValidationResult(errors.isEmpty(), errors)
    }

    private fun countSimplePaths(map: GameMap, id: Int, goal: Int, seen: BooleanArray): Int {
        if (seen[id]) return 0
        if (id == goal) return 1
        seen[id] = true
        var total = 0
        for (tid in map.nodes[id].outgoing) {
            total += countSimplePaths(map, map.tunnels[tid].to, goal, seen)
        }
        seen[id] = false
        return total
    }

    private fun dfsReach(map: GameMap, id: Int, seen: BooleanArray) {
        if (seen[id]) return
        seen[id] = true
        for (tid in map.nodes[id].outgoing) dfsReach(map, map.tunnels[tid].to, seen)
    }
}

fun usedColors(node: MapNode, tunnels: List<com.edgard.tunel.model.MapTunnel>): Set<MapColor> {
    val ids = node.outgoing + node.incoming
    return ids.map { tunnels[it].color }.toSet()
}
