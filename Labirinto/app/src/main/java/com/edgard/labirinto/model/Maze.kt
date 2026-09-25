package com.edgard.labirinto.model

enum class Dir(val dr: Int, val dc: Int) {
    N(-1, 0),
    E(0, 1),
    S(1, 0),
    W(0, -1);

    fun opposite(): Dir = when (this) {
        N -> S
        S -> N
        E -> W
        W -> E
    }
}

enum class CellKind {
    TREE,
    PATH,
    BLOCKED,
    ENTRANCE,
    EXIT,
}

enum class PathShape(val n: Boolean, val e: Boolean, val s: Boolean, val w: Boolean) {
    H(false, true, false, true),
    V(true, false, true, false),
    NE(true, true, false, false),
    NW(true, false, false, true),
    SE(false, true, true, false),
    SW(false, false, true, true),
    CROSS(true, true, true, true);

    fun has(dir: Dir): Boolean = when (dir) {
        Dir.N -> n
        Dir.E -> e
        Dir.S -> s
        Dir.W -> w
    }

    companion object {
        val TWO_LINK = listOf(H, V, NE, NW, SE, SW)

        fun of(cell: Cell): PathShape =
            TWO_LINK.firstOrNull { it.n == cell.n && it.e == cell.e && it.s == cell.s && it.w == cell.w }
                ?: CROSS

        fun optionsFor(came: Dir, correct: PathShape): List<PathShape> {
            val pool = (TWO_LINK.filter { it.has(came) } + CROSS).distinct()
            val rest = pool.filter { it != correct }.shuffled()
            return listOf(correct) + rest.take(2)
        }
    }
}

class Cell {
    var kind: CellKind = CellKind.TREE
    var n: Boolean = false
    var e: Boolean = false
    var s: Boolean = false
    var w: Boolean = false
    var stump: Boolean = false
    var treeSeed: Int = 0
    var gap: Boolean = false
    var revealed: Boolean = false

    fun isOpenGap(): Boolean = gap && !revealed

    fun setLink(dir: Dir, on: Boolean) {
        when (dir) {
            Dir.N -> n = on
            Dir.E -> e = on
            Dir.S -> s = on
            Dir.W -> w = on
        }
    }

    fun linked(dir: Dir): Boolean = when (dir) {
        Dir.N -> n
        Dir.E -> e
        Dir.S -> s
        Dir.W -> w
    }

    fun links(): List<Dir> = Dir.entries.filter { linked(it) }

    fun linkCount(): Int = links().size

    fun isWalkable(): Boolean = kind != CellKind.TREE
}

class Maze(
    val size: Int,
    val cells: Array<Array<Cell>>,
    val startR: Int,
    val startC: Int,
    val endR: Int,
    val endC: Int,
    val seed: Long,
    val route: List<Pair<Int, Int>>,
) {
    fun cell(r: Int, c: Int): Cell = cells[r][c]

    fun inBounds(r: Int, c: Int): Boolean = r in 0 until size && c in 0 until size

    fun neighbor(r: Int, c: Int, dir: Dir): Pair<Int, Int> = (r + dir.dr) to (c + dir.dc)

    fun resetGaps() {
        for (r in 0 until size) {
            for (c in 0 until size) {
                if (cells[r][c].gap) cells[r][c].revealed = false
            }
        }
    }
}
