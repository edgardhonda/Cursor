package com.edgard.dentista.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import com.edgard.dentista.R

class GameAudio(context: Context) {
    private val pool: SoundPool
    private val ids = HashMap<String, Int>(16)
    private val ready = HashSet<Int>(16)
    private var released = false
    private var lastChewNs = 0L
    private var lastSfxNs = 0L

    init {
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        pool = SoundPool.Builder()
            .setMaxStreams(4)
            .setAudioAttributes(attrs)
            .build()
        pool.setOnLoadCompleteListener { _, sampleId, status ->
            if (status == 0) ready.add(sampleId)
        }
        fun load(name: String, res: Int) {
            ids[name] = pool.load(context, res, 1)
        }
        load(CLICK, R.raw.ui_click)
        load(SLURP, R.raw.slurp)
        load(SPLAT, R.raw.splat)
        load(CHEW, R.raw.chew)
        load(BRUSH, R.raw.brush)
        load(CLEAN, R.raw.clean)
        load(CRACK, R.raw.crack)
        load(LOSE, R.raw.lose)
    }

    fun click() = play(CLICK, 0.55f, 1.0f)

    fun slurp() = playThrottled(SLURP, 0.62f, 1.0f, 280_000_000L)

    fun splat() = playThrottled(SPLAT, 0.78f, 1.0f, 180_000_000L)

    fun chew() {
        val now = System.nanoTime()
        if (now - lastChewNs < 220_000_000L) return
        lastChewNs = now
        play(CHEW, 0.42f, 0.95f)
    }

    fun brush() = play(BRUSH, 0.48f, 1.05f)

    fun clean() = play(CLEAN, 0.92f, 1.0f)

    fun crack() = play(CRACK, 0.88f, 1.0f)

    fun lose() = play(LOSE, 0.95f, 1.0f)

    fun release() {
        if (released) return
        released = true
        pool.release()
        ids.clear()
        ready.clear()
    }

    private fun playThrottled(name: String, volume: Float, rate: Float, gapNs: Long) {
        val now = System.nanoTime()
        if (now - lastSfxNs < gapNs) return
        lastSfxNs = now
        play(name, volume, rate)
    }

    private fun play(name: String, volume: Float, rate: Float) {
        if (released) return
        val id = ids[name] ?: return
        if (id == 0 || id !in ready) return
        try {
            pool.play(id, volume, volume, 1, 0, rate)
        } catch (_: Throwable) {
        }
    }

    companion object {
        private const val CLICK = "click"
        private const val SLURP = "slurp"
        private const val SPLAT = "splat"
        private const val CHEW = "chew"
        private const val BRUSH = "brush"
        private const val CLEAN = "clean"
        private const val CRACK = "crack"
        private const val LOSE = "lose"
    }
}
