package com.edgard.labirinto.game

import android.os.Handler
import android.os.Looper
import com.edgard.labirinto.audio.GameAudio
import com.edgard.labirinto.gen.MazeGenerator
import com.edgard.labirinto.model.CellKind
import com.edgard.labirinto.model.Dir
import com.edgard.labirinto.model.Maze
import com.edgard.labirinto.model.PathShape
import java.util.concurrent.Executors
import kotlin.random.Random

enum class PlayState {
    MENU,
    LOADING,
    READY,
    WALKING,
    FILLING,
    CELEBRATING,
    WON,
}

enum class Mood {
    IDLE,
    HAPPY,
    SAD,
}

class Walker {
    var row: Int = 0
    var col: Int = 0
    var facing: Dir = Dir.S
    var progress: Float = 0f
    var bob: Float = 0f
    var mood: Mood = Mood.IDLE
    var moodT: Float = 0f
}

class GameWorld {
    var maze: Maze = MazeGenerator.preview(1L)
        private set
    var state: PlayState = PlayState.MENU
    val walker = Walker()
    var fillOptions: List<PathShape> = emptyList()
    var rejectIndex: Int = -1
    var rejectT: Float = 0f
    var seed: Long = 1L
        private set
    var onChanged: (() -> Unit)? = null
    var audio: GameAudio? = null
    private var routeIndex: Int = 0
    private val main = Handler(Looper.getMainLooper())
    private val gen = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "labirinto-gen").apply { isDaemon = true }
    }
    private val cacheLock = Any()
    private var cached: Maze? = null
    private var genSeq: Int = 0
    private val recentSeeds = ArrayDeque<Long>()

    init {
        prefetch()
    }

    fun newMap() {
        val ready = takeCached()
        if (ready != null) {
            applyMaze(ready)
            prefetch()
            return
        }
        state = PlayState.LOADING
        val seq = ++genSeq
        gen.execute {
            val maze = freshMaze()
            main.post {
                if (seq != genSeq) return@post
                applyMaze(maze)
                prefetch()
            }
        }
    }

    private fun takeCached(): Maze? = synchronized(cacheLock) {
        val hit = cached ?: return null
        if (hit.seed in recentSeeds) {
            cached = null
            return null
        }
        cached = null
        hit
    }

    private fun freshMaze(): Maze {
        var maze: Maze
        var guard = 0
        do {
            maze = MazeGenerator.generate(System.nanoTime() xor Random.nextLong() xor guard.toLong())
            guard++
        } while (maze.seed in recentSeeds && guard < 6)
        return maze
    }

    fun retrySame() {
        maze.resetGaps()
        resetWalker()
        state = PlayState.READY
        onChanged?.invoke()
    }

    fun beginWalk() {
        if (state != PlayState.READY) return
        state = PlayState.WALKING
        audio?.start()
    }

    fun play() {
        newMap()
    }

    private fun applyMaze(next: Maze) {
        seed = next.seed
        maze = next
        recentSeeds.addLast(next.seed)
        if (recentSeeds.size > 10) recentSeeds.removeFirst()
        resetWalker()
        state = PlayState.READY
        onChanged?.invoke()
    }

    private fun prefetch() {
        gen.execute {
            val maze = freshMaze()
            synchronized(cacheLock) { cached = maze }
        }
    }

    private fun resetWalker() {
        routeIndex = 0
        walker.row = maze.startR
        walker.col = maze.startC
        walker.progress = 0f
        walker.bob = 0f
        walker.mood = Mood.IDLE
        walker.moodT = 0f
        walker.facing = dirToNext()
        fillOptions = emptyList()
        rejectIndex = -1
        rejectT = 0f
    }

    fun chooseFill(index: Int) {
        if (state != PlayState.FILLING) return
        if (index !in fillOptions.indices) return
        val cell = maze.cell(walker.row, walker.col)
        val picked = fillOptions[index]
        val correct = PathShape.of(cell)
        if (picked != correct) {
            rejectIndex = index
            rejectT = 1.55f
            walker.mood = Mood.SAD
            walker.moodT = 1.55f
            audio?.wrong()
            return
        }
        cell.revealed = true
        fillOptions = emptyList()
        rejectIndex = -1
        rejectT = 0f
        walker.facing = dirToNext()
        walker.progress = 0f
        walker.mood = Mood.HAPPY
        walker.moodT = 0.95f
        state = PlayState.CELEBRATING
        audio?.correct()
    }

    fun update(dt: Float) {
        if (rejectT > 0f) rejectT = (rejectT - dt).coerceAtLeast(0f)
        when (state) {
            PlayState.FILLING -> {
                walker.bob += if (walker.mood == Mood.SAD) dt * 12f else dt * 3.2f
                if (walker.moodT > 0f) {
                    walker.moodT = (walker.moodT - dt).coerceAtLeast(0f)
                    if (walker.moodT <= 0f && walker.mood == Mood.SAD) {
                        walker.mood = Mood.IDLE
                    }
                }
            }
            PlayState.CELEBRATING -> {
                walker.bob += dt * 16f
                walker.moodT -= dt
                if (walker.moodT <= 0f) {
                    walker.mood = Mood.IDLE
                    walker.moodT = 0f
                    state = PlayState.WALKING
                }
            }
            PlayState.READY, PlayState.LOADING -> {
                walker.bob += dt * 5f
            }
            PlayState.WALKING -> {
                walker.bob += dt * 11f
                walker.progress += dt * 1.55f
                while (walker.progress >= 1f && state == PlayState.WALKING) {
                    walker.progress -= 1f
                    enterNext()
                }
            }
            else -> {}
        }
    }

    private fun enterNext() {
        val nextIdx = routeIndex + 1
        if (nextIdx >= maze.route.size) {
            if (maze.cell(walker.row, walker.col).kind == CellKind.EXIT) {
                state = PlayState.WON
                walker.progress = 0f
                audio?.win()
            }
            return
        }
        val (nr, nc) = maze.route[nextIdx]
        walker.row = nr
        walker.col = nc
        routeIndex = nextIdx
        audio?.step()
        val cell = maze.cell(nr, nc)
        if (cell.isOpenGap()) {
            beginFill()
            return
        }
        if (cell.kind == CellKind.EXIT && nextIdx == maze.route.lastIndex) {
            state = PlayState.WON
            walker.progress = 0f
            audio?.win()
            return
        }
        walker.facing = dirToNext()
    }

    private fun beginFill() {
        val came = walker.facing.opposite()
        val cell = maze.cell(walker.row, walker.col)
        val correct = PathShape.of(cell)
        val options = PathShape.optionsFor(came, correct).toMutableList()
        options.shuffle(Random(cell.treeSeed.toLong() xor came.ordinal.toLong()))
        fillOptions = options
        rejectIndex = -1
        rejectT = 0f
        walker.progress = 0f
        walker.mood = Mood.IDLE
        walker.moodT = 0f
        state = PlayState.FILLING
        audio?.puzzle()
    }

    private fun dirToNext(): Dir {
        val route = maze.route
        if (route.isEmpty()) return Dir.S
        if (routeIndex + 1 >= route.size) return walker.facing
        val (r, c) = route[routeIndex]
        val (nr, nc) = route[routeIndex + 1]
        return Dir.entries.firstOrNull { r + it.dr == nr && c + it.dc == nc } ?: walker.facing
    }

    fun heroWalking(): Boolean = state == PlayState.WALKING

    fun isSad(): Boolean = walker.mood == Mood.SAD && walker.moodT > 0.04f

    fun heroPhase(): Float =
        if (state == PlayState.WALKING) walker.progress * (Math.PI * 4.0).toFloat() else walker.bob

    fun walkerX(): Float = walker.col + 0.5f + walker.facing.dc * walker.progress

    fun walkerY(): Float = walker.row + 0.5f + walker.facing.dr * walker.progress
}
