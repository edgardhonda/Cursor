package com.edgard.labirinto.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import com.edgard.labirinto.R

class GameAudio(context: Context) {
    private val pool: SoundPool
    private val ids = HashMap<String, Int>(16)
    private val ready = HashSet<Int>(16)
    private var released = false
    private var lastStepNs = 0L

    init {
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        pool = SoundPool.Builder()
            .setMaxStreams(8)
            .setAudioAttributes(attrs)
            .build()
        pool.setOnLoadCompleteListener { _, sampleId, status ->
            if (status == 0) ready.add(sampleId)
        }
        fun load(name: String, res: Int) {
            ids[name] = pool.load(context, res, 1)
        }
        load(CLICK, R.raw.ui_click)
        load(START, R.raw.start)
        load(STEP, R.raw.step)
        load(PUZZLE, R.raw.puzzle)
        load(WRONG, R.raw.wrong)
        load(CORRECT, R.raw.correct)
        load(WIN, R.raw.win)
    }

    fun click() = play(CLICK, 0.55f, 1.0f)

    fun start() = play(START, 0.78f, 1.0f)

    fun step() {
        val now = System.nanoTime()
        if (now - lastStepNs < 180_000_000L) return
        lastStepNs = now
        play(STEP, 0.38f, 0.96f + (now % 7) * 0.012f)
    }

    fun puzzle() = play(PUZZLE, 0.72f, 1.0f)

    fun wrong() = play(WRONG, 0.95f, 1.0f)

    fun correct() = play(CORRECT, 0.92f, 1.0f)

    fun win() = play(WIN, 1.0f, 1.0f)

    fun release() {
        if (released) return
        released = true
        pool.release()
        ids.clear()
        ready.clear()
    }

    private fun play(name: String, volume: Float, rate: Float) {
        if (released) return
        val id = ids[name] ?: return
        if (id == 0 || id !in ready) return
        pool.play(id, volume, volume, 1, 0, rate)
    }

    companion object {
        private const val CLICK = "click"
        private const val START = "start"
        private const val STEP = "step"
        private const val PUZZLE = "puzzle"
        private const val WRONG = "wrong"
        private const val CORRECT = "correct"
        private const val WIN = "win"
    }
}
