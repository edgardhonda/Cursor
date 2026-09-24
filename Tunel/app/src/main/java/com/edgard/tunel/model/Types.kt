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
}

enum class MapColor(
    val rgb: Int,
    val label: String,
) {
    RED(0xE53935, "VERMELHO"),
    BLUE(0x1E88E5, "AZUL"),
    GREEN(0x43A047, "VERDE"),
    YELLOW(0xFDD835, "AMARELO"),
    PURPLE(0x8E24AA, "ROXO"),
    ORANGE(0xFB8C00, "LARANJA"),
    CYAN(0x00ACC1, "CIANO"),
    PINK(0xEC407A, "ROSA");

    val r: Float get() = ((rgb shr 16) and 0xFF) / 255f
    val g: Float get() = ((rgb shr 8) and 0xFF) / 255f
    val b: Float get() = (rgb and 0xFF) / 255f
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
