package com.edgard.tunel.model

enum class NodeType {
    START,
    NORMAL,
    TREASURE,
    THREAT,
}

enum class ThreatType {
    MONSTER,
    SPIDER,
    SKULL,
    SNAKE,
    SCORPION,
    GHOST,
}

enum class MapColor(
    val rgb: Int,
    val label: String,
    val contrast: Int,
) {
    RED(0xFF3B30, "VERMELHO", 0),
    YELLOW(0xFFE033, "AMARELO", 0),
    CYAN(0x00E5FF, "CIANO", 0),
    PURPLE(0xC44DFF, "ROXO", 0),
    ORANGE(0xFF9100, "LARANJA", 1),
    GREEN(0x00C853, "VERDE", 1),
    BLUE(0x2962FF, "AZUL", 1),
    PINK(0xFF3DCC, "ROSA", 1);

    val r: Float get() = ((rgb shr 16) and 0xFF) / 255f
    val g: Float get() = ((rgb shr 8) and 0xFF) / 255f
    val b: Float get() = (rgb and 0xFF) / 255f

    val hue: Float
        get() {
            val max = maxOf(r, g, b)
            val min = minOf(r, g, b)
            val d = max - min
            if (d < 1e-5f) return 0f
            val sector = when (max) {
                r -> ((g - b) / d) % 6f
                g -> ((b - r) / d) + 2f
                else -> ((r - g) / d) + 4f
            }
            val deg = sector * 60f
            return if (deg < 0f) deg + 360f else deg
        }

    fun hueDistance(other: MapColor): Float {
        val d = kotlin.math.abs(hue - other.hue)
        return kotlin.math.min(d, 360f - d)
    }

    companion object {
        fun contrastGroup(group: Int): List<MapColor> = entries.filter { it.contrast == group }
    }
}

enum class Difficulty(
    val level: Int,
    val pathMin: Int,
    val pathMax: Int,
    val minOut: Int,
    val maxOut: Int,
    val extraBranches: IntRange,
    val branchDepth: IntRange,
    val maxNodes: Int,
) {
    LEVEL_1(1, 3, 4, 2, 3, 2..3, 0..1, 14),
    LEVEL_2(2, 5, 6, 2, 4, 4..6, 0..2, 22),
    LEVEL_3(3, 7, 8, 3, 4, 6..9, 1..2, 32);

    companion object {
        fun fromLevel(level: Int): Difficulty =
            entries.firstOrNull { it.level == level } ?: LEVEL_1
    }
}
