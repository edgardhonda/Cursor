package com.edgard.luta.render

import com.edgard.luta.character.Stickman
import com.edgard.luta.math.Mathx
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

class ParticleSystem {
    class Particle {
        var x: Float = 0f
        var y: Float = 0f
        var vx: Float = 0f
        var vy: Float = 0f
        var life: Float = 0f
        var maxLife: Float = 1f
        var size: Float = 4f
        var kind: Int = 0
        var color: Int = 0xFFFFE08A.toInt()
        var active: Boolean = false
    }

    class Slash {
        var x0: Float = 0f
        var y0: Float = 0f
        var x1: Float = 0f
        var y1: Float = 0f
        var life: Float = 0f
        var active: Boolean = false
    }

    val particles = Array(160) { Particle() }
    val slashes = Array(10) { Slash() }
    private val rng = Random(11)

    var shakeX: Float = 0f
    var shakeY: Float = 0f
    private var shake: Float = 0f
    var burstX: Float = 0f
    var burstY: Float = 0f
    var burstLife: Float = 0f
    var shockX: Float = 0f
    var shockY: Float = 0f
    var shockLife: Float = 0f

    fun update(dt: Float) {
        shake *= (1f - dt * 14f).coerceAtLeast(0.55f)
        if (shake < 0.12f) shake = 0f
        shakeX = (rng.nextFloat() - 0.5f) * 2f * shake
        shakeY = (rng.nextFloat() - 0.5f) * 2f * shake
        if (burstLife > 0f) burstLife -= dt
        if (shockLife > 0f) shockLife -= dt
        for (i in particles.indices) {
            val p = particles[i]
            if (!p.active) continue
            p.life -= dt
            if (p.life <= 0f) {
                p.active = false
                continue
            }
            p.x += p.vx * dt
            p.y += p.vy * dt
            p.vy += 380f * dt
            p.vx *= 0.9f
        }
        for (i in slashes.indices) {
            val s = slashes[i]
            if (!s.active) continue
            s.life -= dt
            if (s.life <= 0f) s.active = false
        }
    }

    fun impact(x: Float, y: Float, nx: Float, ny: Float, force: Float) {
        shake = Mathx.clamp(force * 0.55f, 2.5f, 9f)
        burstX = x
        burstY = y
        burstLife = 0.05f
        spawnBurst(x, y, nx, ny, force)
        slash(x - nx * 18f, y - ny * 10f, x + nx * 28f, y + ny * 8f)
    }

    fun slash(x0: Float, y0: Float, x1: Float, y1: Float) {
        for (i in slashes.indices) {
            val s = slashes[i]
            if (s.active) continue
            s.x0 = x0
            s.y0 = y0
            s.x1 = x1
            s.y1 = y1
            s.life = 0.09f
            s.active = true
            return
        }
    }

    private fun spawnBurst(x: Float, y: Float, nx: Float, ny: Float, force: Float) {
        val n = Mathx.clamp(4f + force * 0.35f, 5f, 12f).toInt()
        var spawned = 0
        for (i in particles.indices) {
            if (spawned >= n) break
            val p = particles[i]
            if (p.active) continue
            val ang = rng.nextFloat() * 6.283f
            val spd = 220f + rng.nextFloat() * 380f
            p.x = x
            p.y = y
            p.vx = nx * spd * 0.4f + cos(ang) * spd * 0.75f
            p.vy = ny * spd * 0.3f + sin(ang) * spd * 0.75f
            p.maxLife = 0.12f + rng.nextFloat() * 0.12f
            p.life = p.maxLife
            p.size = 2.5f + rng.nextFloat() * 4f
            p.kind = if (rng.nextFloat() < 0.25f) 1 else 0
            p.color = 0xFFFFE08A.toInt()
            p.active = true
            spawned++
        }
    }

    fun disintegrate(s: Stickman, dirX: Float) {
        val joints = s.skeleton.joints
        var spawned = 0
        val want = 22
        for (i in particles.indices) {
            if (spawned >= want) break
            val p = particles[i]
            if (p.active) continue
            val j = joints[spawned % joints.size]
            val ang = rng.nextFloat() * 6.283f
            val spd = 90f + rng.nextFloat() * 340f
            p.x = j.worldX
            p.y = j.worldY
            p.vx = dirX * 160f + cos(ang) * spd
            p.vy = -180f + sin(ang) * spd
            p.maxLife = 0.18f + rng.nextFloat() * 0.16f
            p.life = p.maxLife
            p.size = 2f + rng.nextFloat() * 5.5f
            p.kind = if (spawned % 3 == 0) 2 else 0
            p.color = s.fillColor
            p.active = true
            spawned++
        }
        burstX = s.chestX()
        burstY = s.chestY()
        burstLife = 0.07f
        shake = 5.5f
    }

    fun explode(s: Stickman) {
        val joints = s.skeleton.joints
        var spawned = 0
        val want = 48
        val palette = intArrayOf(
            s.fillColor,
            0xFFFFE08A.toInt(),
            0xFFFF9A3C.toInt(),
            0xFFFFF4C2.toInt(),
            0xFFFFFFFF.toInt(),
        )
        for (i in particles.indices) {
            if (spawned >= want) break
            val p = particles[i]
            if (p.active) continue
            val j = joints[spawned % joints.size]
            val ang = rng.nextFloat() * 6.283f
            val spd = 180f + rng.nextFloat() * 620f
            p.x = j.worldX
            p.y = j.worldY
            p.vx = cos(ang) * spd
            p.vy = sin(ang) * spd - 220f
            p.maxLife = 0.22f + rng.nextFloat() * 0.22f
            p.life = p.maxLife
            p.size = 3f + rng.nextFloat() * 8f
            p.kind = spawned % 3
            p.color = palette[spawned % palette.size]
            p.active = true
            spawned++
        }
        burstX = s.chestX()
        burstY = s.chestY()
        burstLife = 0.16f
        shockX = s.chestX()
        shockY = s.chestY()
        shockLife = 0.22f
        shake = 18f
    }

    fun reset() {
        shake = 0f
        shakeX = 0f
        shakeY = 0f
        burstLife = 0f
        shockLife = 0f
        for (i in particles.indices) particles[i].active = false
        for (i in slashes.indices) slashes[i].active = false
    }
}
