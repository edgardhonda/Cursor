package com.edgard.tunel.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import com.edgard.tunel.R
import com.edgard.tunel.model.ThreatType

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
        load(READY, R.raw.ui_ready)
        load(STEP, R.raw.step)
        load(TUNNEL, R.raw.tunnel)
        load(ROOM, R.raw.room)
        load(TREASURE, R.raw.treasure)
        load(MONSTER, R.raw.monster)
        load(SPIDER, R.raw.spider)
        load(SKULL, R.raw.skull)
    }

    fun click() = play(CLICK, 0.55f, 1.0f)

    fun ready() = play(READY, 0.78f, 1.0f)

    fun tunnel() = play(TUNNEL, 0.72f, 1.0f)

    fun room() = play(ROOM, 0.48f, 1.0f)

    fun treasure() = play(TREASURE, 1.0f, 1.0f)

    fun threat(type: ThreatType) {
        when (type) {
            ThreatType.MONSTER -> play(MONSTER, 0.95f, 1.0f)
            ThreatType.SPIDER -> play(SPIDER, 0.88f, 1.0f)
            ThreatType.SKULL -> play(SKULL, 0.90f, 1.0f)
        }
    }

    fun step(inTunnel: Boolean) {
        val now = System.nanoTime()
        if (now - lastStepNs < 220_000_000L) return
        lastStepNs = now
        val vol = if (inTunnel) 0.28f else 0.40f
        val rate = if (inTunnel) 0.92f else 1.0f
        play(STEP, vol, rate)
    }

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
        private const val READY = "ready"
        private const val STEP = "step"
        private const val TUNNEL = "tunnel"
        private const val ROOM = "room"
        private const val TREASURE = "treasure"
        private const val MONSTER = "monster"
        private const val SPIDER = "spider"
        private const val SKULL = "skull"
    }
}
