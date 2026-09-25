package com.edgard.labirinto.gen

import com.edgard.labirinto.model.Cell
import com.edgard.labirinto.model.CellKind
import com.edgard.labirinto.model.Dir
import com.edgard.labirinto.model.Maze
import kotlin.math.abs
import kotlin.random.Random

object MazeGenerator {
    const val SIZE = 10

    fun generate(seed: Long): Maze {
        val base = seed xor 0x9E3779B97F4A7C15UL.toLong()
        for (attempt in 0 until 28) {
            val maze = build(Random(base + attempt * 911L), base + attempt) ?: continue
            if (valid(maze)) {
                plantGaps(maze, Random(base + attempt + 17L))
                return maze
            }
        }
        val maze = fallback(base)
        plantGaps(maze, Random(base + 17L))
        return maze
    }

    fun preview(seed: Long): Maze {
        val maze = fallback(seed)
        plantGaps(maze, Random(seed + 17L))
        return maze
    }

    private fun build(rng: Random, seed: Long): Maze? {
        val cells = Array(SIZE) {
            Array(SIZE) {
                Cell().also { cell ->
                    cell.treeSeed = rng.nextInt()
                    cell.stump = rng.nextFloat() < 0.08f
                }
            }
        }
        val (start, end) = pickEnds(rng)
        val main = carveMain(rng, start, end) ?: return null
        markPath(cells, main)
        cells[start.first][start.second].kind = CellKind.ENTRANCE
        cells[end.first][end.second].kind = CellKind.EXIT
        val route = ArrayList(main)

        val want = rng.nextInt(3, 6)
        var crosses = 0
        val origins = walkableCells(cells).filter {
            it != start && it != end && isStraight(cells[it.first][it.second])
        }.shuffled(rng)
        for (origin in origins) {
            if (crosses >= want) break
            if (addLoop(cells, origin, rng, route)) crosses++
        }
        if (crosses < 3) {
            for (origin in walkableCells(cells).filter { it != start && it != end }) {
                if (!isStraight(cells[origin.first][origin.second])) continue
                if (addLoop(cells, origin, rng, route)) {
                    crosses++
                    if (crosses >= 3) break
                }
            }
        }
        return Maze(SIZE, cells, start.first, start.second, end.first, end.second, seed, route)
    }

    private fun pickEnds(rng: Random): Pair<Pair<Int, Int>, Pair<Int, Int>> {
        val edge = ArrayList<Pair<Int, Int>>(SIZE * 4)
        for (i in 0 until SIZE) {
            edge += 0 to i
            edge += (SIZE - 1) to i
            edge += i to 0
            edge += i to (SIZE - 1)
        }
        val start = edge[rng.nextInt(edge.size)]
        val far = edge.filter { abs(it.first - start.first) + abs(it.second - start.second) >= 12 }
        val end = if (far.isNotEmpty()) far[rng.nextInt(far.size)] else {
            ((SIZE - 1 - start.first) to (SIZE - 1 - start.second))
        }
        return start to end
    }

    private fun carveMain(
        rng: Random,
        start: Pair<Int, Int>,
        end: Pair<Int, Int>,
    ): List<Pair<Int, Int>>? {
        repeat(72) {
            val path = randomWalk(rng, start, end) ?: return@repeat
            return path
        }
        return null
    }

    private fun randomWalk(
        rng: Random,
        start: Pair<Int, Int>,
        end: Pair<Int, Int>,
    ): List<Pair<Int, Int>>? {
        val dist0 = abs(end.first - start.first) + abs(end.second - start.second)
        val minLen = (dist0 + 8).coerceIn(18, 28)
        val maxLen = 52
        val path = ArrayList<Pair<Int, Int>>(maxLen)
        val seen = HashSet<Pair<Int, Int>>(maxLen)
        var r = start.first
        var c = start.second
        path += start
        seen += start
        val options = ArrayList<Dir>(4)
        while (path.size < maxLen) {
            if (r == end.first && c == end.second) {
                return if (path.size >= minLen) path else null
            }
            val dist = abs(end.first - r) + abs(end.second - c)
            if (dist > maxLen - path.size) return null
            options.clear()
            var best = Int.MIN_VALUE
            for (dir in Dir.entries) {
                val nr = r + dir.dr
                val nc = c + dir.dc
                if (nr !in 0 until SIZE || nc !in 0 until SIZE) continue
                val next = nr to nc
                if (next in seen) continue
                val nextDist = abs(end.first - nr) + abs(end.second - nc)
                val toward = nextDist < dist
                val score = when {
                    path.size < minLen && next == end -> -8
                    path.size < minLen && !toward -> 4
                    path.size >= minLen && toward -> 5
                    else -> 1
                }
                if (score > best) {
                    best = score
                    options.clear()
                    options += dir
                } else if (score == best) {
                    options += dir
                }
            }
            if (options.isEmpty()) return null
            val dir = options[rng.nextInt(options.size)]
            r += dir.dr
            c += dir.dc
            val step = r to c
            path += step
            seen += step
        }
        return if (r == end.first && c == end.second && path.size >= minLen) path else null
    }

    private fun addLoop(
        cells: Array<Array<Cell>>,
        origin: Pair<Int, Int>,
        rng: Random,
        route: ArrayList<Pair<Int, Int>>,
    ): Boolean {
        val r = origin.first
        val c = origin.second
        val cell = cells[r][c]
        val horiz = cell.e && cell.w && !cell.n && !cell.s
        val vert = cell.n && cell.s && !cell.e && !cell.w
        if (!horiz && !vert) return false
        val widths = mutableListOf(2, 3, 4, 5)
        val signs = mutableListOf(-1, 1)
        widths.shuffle(rng)
        signs.shuffle(rng)
        for (w in widths) {
            for (sign in signs) {
                val loop = if (horiz) {
                    carveRing(cells, r, c, acrossRow = true, sign = sign, span = w)
                } else {
                    carveRing(cells, r, c, acrossRow = false, sign = sign, span = w)
                }
                if (loop != null) {
                    spliceLoop(route, origin, loop)
                    return true
                }
            }
        }
        return false
    }

    private fun carveRing(
        cells: Array<Array<Cell>>,
        r: Int,
        c: Int,
        acrossRow: Boolean,
        sign: Int,
        span: Int,
    ): List<Pair<Int, Int>>? {
        val loop = ArrayList<Pair<Int, Int>>()
        loop += r to c
        if (acrossRow) {
            val farC = c + sign * span
            if (farC !in 0 until SIZE) return null
            loop += (r - 1) to c
            for (i in 1..span) loop += (r - 1) to (c + sign * i)
            loop += r to farC
            loop += (r + 1) to farC
            for (i in span - 1 downTo 0) loop += (r + 1) to (c + sign * i)
            loop += r to c
        } else {
            val farR = r + sign * span
            if (farR !in 0 until SIZE) return null
            loop += r to (c - 1)
            for (i in 1..span) loop += (r + sign * i) to (c - 1)
            loop += farR to c
            loop += farR to (c + 1)
            for (i in span - 1 downTo 0) loop += (r + sign * i) to (c + 1)
            loop += r to c
        }
        val far = if (acrossRow) r to (c + sign * span) else (r + sign * span) to c
        val body = loop.filterIndexed { i, _ -> i != 0 && i != loop.lastIndex }
        val mid = body.filter { it != far }
        if (mid.any { it.first !in 0 until SIZE || it.second !in 0 until SIZE || !tree(cells, it.first, it.second) }) {
            return null
        }
        if (!farOk(cells, far.first, far.second, acrossRow)) return null
        for (i in 0 until loop.lastIndex) {
            val a = loop[i]
            val b = loop[i + 1]
            if (abs(a.first - b.first) + abs(a.second - b.second) != 1) return null
        }
        markPath(cells, loop)
        return if (cells[r][c].linkCount() == 4) loop else null
    }

    private fun farOk(cells: Array<Array<Cell>>, r: Int, c: Int, acrossRow: Boolean): Boolean {
        if (r !in 0 until SIZE || c !in 0 until SIZE) return false
        val cell = cells[r][c]
        if (cell.kind == CellKind.ENTRANCE || cell.kind == CellKind.EXIT) return false
        if (cell.kind == CellKind.TREE) return true
        if (cell.kind != CellKind.PATH || cell.linkCount() != 2) return false
        return if (acrossRow) cell.e && cell.w else cell.n && cell.s
    }

    private fun spliceLoop(
        route: ArrayList<Pair<Int, Int>>,
        origin: Pair<Int, Int>,
        loop: List<Pair<Int, Int>>,
    ) {
        val i = route.indexOf(origin)
        if (i < 0) return
        val body = loop.subList(1, loop.lastIndex)
        route.addAll(i + 1, body + origin)
    }

    private fun markPath(cells: Array<Array<Cell>>, list: List<Pair<Int, Int>>) {
        for (i in 0 until list.lastIndex) {
            val (r, c) = list[i]
            val (nr, nc) = list[i + 1]
            if (r == nr && c == nc) continue
            if (abs(r - nr) + abs(c - nc) != 1) continue
            link(cells, r, c, nr, nc)
        }
    }

    private fun link(cells: Array<Array<Cell>>, r: Int, c: Int, nr: Int, nc: Int) {
        val dir = Dir.entries.first { r + it.dr == nr && c + it.dc == nc }
        cells[r][c].setLink(dir, true)
        cells[nr][nc].setLink(dir.opposite(), true)
        if (cells[r][c].kind == CellKind.TREE) cells[r][c].kind = CellKind.PATH
        if (cells[nr][nc].kind == CellKind.TREE) cells[nr][nc].kind = CellKind.PATH
    }

    private fun tree(cells: Array<Array<Cell>>, r: Int, c: Int): Boolean {
        if (r !in 0 until SIZE || c !in 0 until SIZE) return false
        return cells[r][c].kind == CellKind.TREE
    }

    private fun isStraight(cell: Cell): Boolean {
        val n = cell.linkCount()
        if (n != 2) return false
        return (cell.n && cell.s) || (cell.e && cell.w)
    }

    private fun walkableCells(cells: Array<Array<Cell>>): List<Pair<Int, Int>> {
        val out = ArrayList<Pair<Int, Int>>()
        for (r in 0 until SIZE) for (c in 0 until SIZE) {
            if (cells[r][c].isWalkable()) out += r to c
        }
        return out
    }

    private fun valid(maze: Maze): Boolean {
        var crosses = 0
        var walkable = 0
        for (r in 0 until SIZE) {
            for (c in 0 until SIZE) {
                val cell = maze.cell(r, c)
                if (!cell.isWalkable()) continue
                walkable++
                val n = cell.linkCount()
                if (n == 3) return false
                if (n == 0 || n > 4) return false
                if (cell.kind != CellKind.ENTRANCE && cell.kind != CellKind.EXIT && n != 2 && n != 4) return false
                if (n == 4) crosses++
            }
        }
        if (crosses < 3) return false
        if (walkable < 30) return false
        if (maze.route.size < 22) return false
        if (maze.route.first() != (maze.startR to maze.startC)) return false
        if (maze.route.last() != (maze.endR to maze.endC)) return false
        for (i in 0 until maze.route.lastIndex) {
            val (r, c) = maze.route[i]
            val (nr, nc) = maze.route[i + 1]
            if (abs(r - nr) + abs(c - nc) != 1) return false
            val dir = Dir.entries.firstOrNull { r + it.dr == nr && c + it.dc == nc } ?: return false
            if (!maze.cell(r, c).linked(dir)) return false
        }
        return true
    }

    private fun plantGaps(maze: Maze, rng: Random) {
        val firstAt = HashMap<Pair<Int, Int>, Int>()
        maze.route.forEachIndexed { i, p -> if (p !in firstAt) firstAt[p] = i }
        val last = maze.route.lastIndex
        val candidates = ArrayList<Pair<Int, Int>>()
        for (p in maze.route.toSet()) {
            val (r, c) = p
            val cell = maze.cell(r, c)
            if (cell.kind != CellKind.PATH) continue
            val links = cell.linkCount()
            if (links != 2 && links != 4) continue
            val idx = firstAt[p] ?: continue
            if (idx < 3 || idx > last - 2) continue
            candidates += p
        }
        candidates.shuffle(rng)
        val want = rng.nextInt(4, 8)
        val picked = ArrayList<Pair<Int, Int>>()
        fun take(minDist: Int) {
            for (p in candidates) {
                if (p in picked) continue
                if (picked.any { abs(it.first - p.first) + abs(it.second - p.second) < minDist }) continue
                picked += p
                if (picked.size >= want) return
            }
        }
        take(2)
        if (picked.size < want) take(1)
        for ((r, c) in picked) {
            maze.cell(r, c).gap = true
            maze.cell(r, c).revealed = false
        }
    }

    private fun fallback(seed: Long): Maze {
        val rng = Random(seed)
        val (start, end) = pickEnds(rng)
        val cells = Array(SIZE) {
            Array(SIZE) {
                Cell().also { cell ->
                    cell.treeSeed = rng.nextInt()
                    cell.stump = rng.nextFloat() < 0.08f
                }
            }
        }
        val path = corridor(rng, start, end)
        markPath(cells, path)
        cells[start.first][start.second].kind = CellKind.ENTRANCE
        cells[end.first][end.second].kind = CellKind.EXIT
        val route = ArrayList(path)
        walkableCells(cells).filter { it != start && it != end && isStraight(cells[it.first][it.second]) }
            .shuffled(rng)
            .take(8)
            .forEach { origin -> addLoop(cells, origin, rng, route) }
        return Maze(SIZE, cells, start.first, start.second, end.first, end.second, seed, route)
    }

    private fun corridor(rng: Random, start: Pair<Int, Int>, end: Pair<Int, Int>): List<Pair<Int, Int>> {
        val path = ArrayList<Pair<Int, Int>>()
        val seen = HashSet<Pair<Int, Int>>()
        var r = start.first
        var c = start.second
        fun add(nr: Int, nc: Int): Boolean {
            if (nr !in 0 until SIZE || nc !in 0 until SIZE) return false
            val p = nr to nc
            if (p in seen) return false
            r = nr
            c = nc
            path += p
            seen += p
            return true
        }
        add(r, c)
        val wander = rng.nextInt(10, 18)
        repeat(wander) {
            val dirs = Dir.entries.filter { d ->
                val nr = r + d.dr
                val nc = c + d.dc
                nr in 0 until SIZE && nc in 0 until SIZE && (nr to nc) !in seen
            }.shuffled(rng)
            if (dirs.isEmpty()) return@repeat
            val dir = dirs.first()
            add(r + dir.dr, c + dir.dc)
        }
        var guard = 0
        while ((r != end.first || c != end.second) && guard++ < 80) {
            val options = ArrayList<Dir>(4)
            if (r != end.first) options += if (end.first > r) Dir.S else Dir.N
            if (c != end.second) options += if (end.second > c) Dir.E else Dir.W
            options.shuffle(rng)
            var moved = false
            for (d in options + Dir.entries.shuffled(rng)) {
                val nr = r + d.dr
                val nc = c + d.dc
                if (add(nr, nc)) {
                    moved = true
                    break
                }
            }
            if (!moved) {
                if (r != end.first) r += if (end.first > r) 1 else -1
                else c += if (end.second > c) 1 else -1
                val p = r.coerceIn(0, SIZE - 1) to c.coerceIn(0, SIZE - 1)
                path += p
                seen += p
                r = p.first
                c = p.second
            }
        }
        if (path.last() != end) {
            path += end
        }
        return path
    }
}
