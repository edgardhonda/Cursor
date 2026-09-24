package com.edgard.luta.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import com.edgard.luta.R
import com.edgard.luta.combat.AttackType

class GameAudio(context: Context) {
    private val pool: SoundPool
    private val ids = HashMap<String, Int>(16)
    private val ready = HashSet<Int>(16)
    private var released = false

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
        load(SWING_JAB, R.raw.swing_jab)
        load(SWING_KICK, R.raw.swing_kick)
        load(SWING_DASH, R.raw.swing_dash)
        load(SWING_JUMP, R.raw.swing_jump)
        load(SWING_DIVE, R.raw.swing_dive)
        load(HIT_LIGHT, R.raw.hit_light)
        load(HIT_MID, R.raw.hit_mid)
        load(HIT_HEAVY, R.raw.hit_heavy)
        load(HURT, R.raw.hurt)
        load(KO, R.raw.ko)
        load(LAND, R.raw.land)
    }

    fun swing(type: AttackType) {
        when (type) {
            AttackType.JAB -> play(SWING_JAB, 0.52f, 1.06f)
            AttackType.KICK -> play(SWING_KICK, 0.62f, 0.98f)
            AttackType.DASH -> play(SWING_DASH, 0.70f, 1.0f)
            AttackType.JUMP_UP, AttackType.JUMP_DIAG -> play(SWING_JUMP, 0.58f, 1.02f)
            AttackType.DIVE -> play(SWING_DIVE, 0.64f, 0.96f)
        }
    }

    fun hit(type: AttackType, combo: Int) {
        val rate = (0.94f + (combo % 6) * 0.018f).coerceIn(0.92f, 1.08f)
        when (type) {
            AttackType.JAB -> play(HIT_LIGHT, 0.82f, rate)
            AttackType.KICK, AttackType.JUMP_UP, AttackType.JUMP_DIAG -> play(HIT_MID, 0.90f, rate)
            AttackType.DASH, AttackType.DIVE -> play(HIT_HEAVY, 1.0f, rate * 0.97f)
        }
    }

    fun hurt() = play(HURT, 0.78f, 0.97f)

    fun ko() = play(KO, 1.0f, 1.0f)

    fun land() = play(LAND, 0.38f, 1.0f)

    fun enemySwing(type: AttackType = AttackType.JAB) {
        when (type) {
            AttackType.JUMP_UP, AttackType.JUMP_DIAG -> play(SWING_JUMP, 0.36f, 0.90f)
            AttackType.DASH -> play(SWING_DASH, 0.34f, 0.90f)
            AttackType.KICK -> play(SWING_KICK, 0.34f, 0.90f)
            AttackType.DIVE -> play(SWING_DIVE, 0.34f, 0.90f)
            else -> play(SWING_JAB, 0.32f, 0.88f)
        }
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
        private const val SWING_JAB = "swing_jab"
        private const val SWING_KICK = "swing_kick"
        private const val SWING_DASH = "swing_dash"
        private const val SWING_JUMP = "swing_jump"
        private const val SWING_DIVE = "swing_dive"
        private const val HIT_LIGHT = "hit_light"
        private const val HIT_MID = "hit_mid"
        private const val HIT_HEAVY = "hit_heavy"
        private const val HURT = "hurt"
        private const val KO = "ko"
        private const val LAND = "land"
    }
}
