package com.edgard.luta.enemy

import com.edgard.luta.character.ActorState
import com.edgard.luta.character.Stickman
import com.edgard.luta.combat.AttackType
import com.edgard.luta.combat.Hitbox
import com.edgard.luta.math.CombatConfig
import kotlin.math.abs
import kotlin.math.sign
import kotlin.math.sin
import kotlin.random.Random

enum class EnemyState {
    IDLE,
    APPROACH,
    ATTACK,
    HIT,
    STUN,
    DEAD,
    AIRBORNE,
}

class Enemy(color: Int) {
    val body = Stickman(isPlayer = false, fillColor = color)
    var ai: EnemyState = EnemyState.IDLE
    var think: Float = 0f
    var attackWind: Float = 0f
    var wantsSlot: Boolean = false
    var hasSlot: Boolean = false
    var spawnDelay: Float = 0f
    var wishVx: Float = 0f
    var flying: Boolean = false
    var hoverY: Float = 0f
    var fallingDead: Boolean = false
    var cueSwing: Boolean = false
    var cueDissolve: Boolean = false
    var dissolving: Boolean = false
    var dissolve: Float = 0f
    val shatterX = FloatArray(JointCount)
    val shatterY = FloatArray(JointCount)
    val shatterVx = FloatArray(JointCount)
    val shatterVy = FloatArray(JointCount)
    val strikeBox = Hitbox()

    fun alive(): Boolean = ai != EnemyState.DEAD && body.health > 0f && !dissolving

    fun beginDissolve(dirX: Float) {
        dissolving = true
        dissolve = 0f
        cueDissolve = true
        ai = EnemyState.DEAD
        val cx = body.hipX
        val cy = body.hipY - body.height * 0.2f
        val joints = body.skeleton.joints
        for (i in joints.indices) {
            val j = joints[i]
            val dx = j.worldX - cx
            val dy = j.worldY - cy
            shatterX[i] = 0f
            shatterY[i] = 0f
            shatterVx[i] = dirX * (140f + i * 11f) + dx * 9.5f
            shatterVy[i] = -260f - i * 8f + dy * 7f
        }
    }

    fun resetDissolve() {
        dissolving = false
        dissolve = 0f
        cueDissolve = false
        fallingDead = false
        for (i in shatterX.indices) {
            shatterX[i] = 0f
            shatterY[i] = 0f
            shatterVx[i] = 0f
            shatterVy[i] = 0f
        }
    }

    companion object {
        val JointCount = com.edgard.luta.character.JointId.entries.size
    }
}

class EnemyManager {
    val enemies = Array(CombatConfig.MAX_ENEMIES) { i ->
        val flying = i >= CombatConfig.MAX_GROUND
        val tone = if (flying) {
            if (i % 3 == 0) 0xFF5EC8D8.toInt() else if (i % 3 == 1) 0xFF7B8CFF.toInt() else 0xFF4AD4A8.toInt()
        } else {
            if (i % 3 == 0) 0xFFE07070.toInt() else if (i % 3 == 1) 0xFFD98B4B.toInt() else 0xFFC45C7A.toInt()
        }
        Enemy(tone).also { it.flying = flying }
    }
    private val rng = Random(23)
    private var slots: Int = 0
    private var spawnT: Float = 0.2f
    private var flyerSpawnT: Float = 0.4f

    fun reset(worldW: Float, groundY: Float, groundH: Float, flyerH: Float, groundN: Int, flyerN: Int) {
        slots = 0
        spawnT = 0.15f
        flyerSpawnT = 0.35f
        for (i in enemies.indices) {
            val e = enemies[i]
            e.flying = i >= CombatConfig.MAX_GROUND
            e.hasSlot = false
            e.wantsSlot = false
            val h = if (e.flying) flyerH else groundH
            e.body.flying = e.flying
            e.body.height = h
            e.body.maxHealth = if (e.flying) CombatConfig.FLYER_HP else CombatConfig.ENEMY_HP
            e.body.skeleton.applyHeight(h)
            val start = if (e.flying) {
                i - CombatConfig.MAX_GROUND < flyerN
            } else {
                i < groundN
            }
            if (start) {
                spawn(e, worldW, groundY, immediate = true)
            } else {
                e.ai = EnemyState.DEAD
                e.body.health = 0f
                e.resetDissolve()
                e.spawnDelay = 0.4f + i * 0.12f
            }
        }
    }

    fun update(
        dt: Float,
        player: Stickman,
        groundY: Float,
        worldW: Float,
        minX: Float,
        maxX: Float,
        frozen: Boolean,
        brawl: Boolean,
    ) {
        for (e in enemies) {
            if (e.ai == EnemyState.DEAD || e.dissolving) {
                tickDissolve(e, dt)
            }
        }
        if (frozen) return
        spawnT -= dt
        flyerSpawnT -= dt
        var liveG = 0
        var liveF = 0
        for (e in enemies) {
            if (!e.alive()) continue
            if (e.flying) liveF++ else liveG++
        }
        if (!brawl) {
            if (liveG < CombatConfig.START_ENEMIES && spawnT <= 0f) {
                val idle = enemies.firstOrNull { !it.flying && !it.alive() && !it.dissolving && !it.fallingDead && it.spawnDelay <= 0f }
                if (idle != null) {
                    spawn(idle, worldW, groundY, immediate = false)
                    spawnT = CombatConfig.ENEMY_RESPAWN
                }
            }
            if (liveF < CombatConfig.START_FLYERS && flyerSpawnT <= 0f) {
                val idle = enemies.firstOrNull { it.flying && !it.alive() && !it.dissolving && !it.fallingDead && it.spawnDelay <= 0f }
                if (idle != null) {
                    spawn(idle, worldW, groundY, immediate = false)
                    flyerSpawnT = CombatConfig.FLYER_RESPAWN
                }
            }
        }
        for (e in enemies) {
            if (!e.alive()) continue
            val target = if (brawl) rival(e) else player
            if (target == null) {
                e.wishVx *= 0.92f
                e.body.vx = e.wishVx
                continue
            }
            if (e.flying) thinkFlyer(e, target, dt, groundY, minX, maxX, brawl)
            else think(e, target, dt, groundY, minX, maxX, brawl)
        }
    }

    fun releaseSlot(e: Enemy) {
        if (e.hasSlot) {
            e.hasSlot = false
            slots = (slots - 1).coerceAtLeast(0)
        }
    }

    private fun spawn(e: Enemy, worldW: Float, groundY: Float, immediate: Boolean) {
        e.body.flying = e.flying
        e.body.reset(if (e.flying) CombatConfig.FLYER_HP else CombatConfig.ENEMY_HP)
        e.ai = EnemyState.APPROACH
        e.think = rng.nextFloat() * 0.4f
        e.attackWind = 0f
        e.hasSlot = false
        e.wantsSlot = false
        val fromLeft = rng.nextBoolean()
        e.body.hipX = if (fromLeft) worldW * 0.06f else worldW * 0.94f
        e.body.facing = if (fromLeft) 1f else -1f
        e.spawnDelay = 0f
        e.resetDissolve()
        if (e.flying) {
            e.hoverY = groundY - e.body.height * CombatConfig.FLYER_HOVER
            e.body.airborne = true
            e.body.flying = true
            e.body.hipY = if (immediate) e.hoverY else -e.body.height
            e.wishVx = 0f
            e.body.vx = e.body.facing * CombatConfig.FLYER_SPEED * 0.7f
            e.body.vy = if (immediate) 0f else CombatConfig.FLYER_DIVE_SPEED * 0.35f
            e.ai = EnemyState.IDLE
        } else {
            e.body.hipY = groundY - e.body.height * 0.42f
            e.wishVx = e.body.facing * CombatConfig.ENEMY_SPEED * (1.15f + rng.nextFloat() * 0.35f)
            e.body.vx = e.wishVx
            e.body.hipX = e.body.hipX.coerceIn(e.body.height * 0.4f, worldW - e.body.height * 0.4f)
        }
    }

    private fun rival(e: Enemy): Stickman? {
        var bestSame: Stickman? = null
        var bestAny: Stickman? = null
        var dSame = Float.MAX_VALUE
        var dAny = Float.MAX_VALUE
        for (o in enemies) {
            if (o === e || !o.alive()) continue
            val d = abs(o.body.hipX - e.body.hipX) + abs(o.body.hipY - e.body.hipY) * 0.35f
            if (d < dAny) {
                dAny = d
                bestAny = o.body
            }
            if (o.flying == e.flying && d < dSame) {
                dSame = d
                bestSame = o.body
            }
        }
        return bestSame ?: bestAny
    }

    private fun thinkFlyer(e: Enemy, target: Stickman, dt: Float, groundY: Float, minX: Float, maxX: Float, brawl: Boolean) {
        val b = e.body
        b.flying = true
        b.airborne = true
        e.hoverY = groundY - b.height * CombatConfig.FLYER_HOVER
        if (b.stun > 0f) {
            e.ai = EnemyState.STUN
        }
        val gap = abs(target.hipX - b.hipX)
        e.think -= dt
        when (e.ai) {
            EnemyState.HIT, EnemyState.STUN -> {
                if (b.stun <= 0f && b.state != ActorState.HIT) {
                    e.ai = EnemyState.IDLE
                    e.think = 0.2f
                }
            }
            EnemyState.DEAD -> Unit
            EnemyState.ATTACK -> {
                e.attackWind -= dt
                val dir = toward(target, b)
                b.facing = dir
                b.vx += dir * 520f * dt
                b.vx = b.vx.coerceIn(-CombatConfig.FLYER_SPEED * 1.4f, CombatConfig.FLYER_SPEED * 1.4f)
                b.vy = CombatConfig.FLYER_DIVE_SPEED
                b.attacking = true
                updateFlyerStrike(e)
                val near = if (target.flying) {
                    gap < b.height * 1.3f && abs(b.hipY - target.hipY) < b.height * 0.55f
                } else {
                    b.hipY >= target.hipY - target.height * 0.55f
                }
                if (e.attackWind <= 0f || near) {
                    e.ai = EnemyState.AIRBORNE
                    e.attackWind = 0f
                    b.attacking = false
                    b.vy = -CombatConfig.FLYER_DIVE_SPEED * 0.9f
                    e.strikeBox.set(b.hipX, b.hipY, 0f, 0f)
                    b.hitbox.set(b.hipX, b.hipY, 0f, 0f)
                }
            }
            EnemyState.AIRBORNE -> {
                e.strikeBox.set(b.hipX, b.hipY, 0f, 0f)
                b.attacking = false
                val bob = sin(b.time * 3.4f) * b.height * 0.1f
                if (b.hipY <= e.hoverY + bob + 8f) {
                    e.ai = EnemyState.IDLE
                    b.vy = 0f
                    e.think = 0.25f + rng.nextFloat() * 0.4f
                } else {
                    b.vy = -CombatConfig.FLYER_DIVE_SPEED * 0.85f
                    b.vx *= 0.96f
                }
            }
            else -> {
                e.strikeBox.set(b.hipX, b.hipY, 0f, 0f)
                b.attacking = false
                val phase = (e.hashCode() and 255) * 0.02f
                val bob = sin(b.time * 3.2f + phase) * b.height * 0.14f
                val targetY = e.hoverY + bob
                b.vy = (targetY - b.hipY) * 5.2f
                val orbit = target.hipX + sin(b.time * 1.05f + phase) * b.height * 2.6f
                val wish = ((orbit - b.hipX) * 2.4f).coerceIn(-CombatConfig.FLYER_SPEED, CombatConfig.FLYER_SPEED)
                b.vx = wish
                b.facing = if (target.hipX >= b.hipX) 1f else -1f
                if (e.think <= 0f) {
                    e.think = if (brawl) 0.22f + rng.nextFloat() * 0.28f else 0.55f + rng.nextFloat() * 0.7f
                    val diveChance = if (brawl) 0.82f else 0.58f
                    if (gap < b.height * 4.8f && rng.nextFloat() < diveChance) {
                        startFlyerDive(e, target)
                    }
                }
            }
        }
        b.hipX = b.hipX.coerceIn(minX, maxX)
    }

    private fun startFlyerDive(e: Enemy, target: Stickman) {
        val b = e.body
        val dir = toward(target, b)
        e.ai = EnemyState.ATTACK
        e.attackWind = 0.62f
        e.think = 0.62f
        e.cueSwing = true
        b.strikeId++
        b.facing = dir
        b.attacking = true
        b.state = ActorState.ATTACK
        b.actionT = 0f
        b.actionDur = 0.62f
        b.attack.type = AttackType.DIVE
        b.attack.dirX = dir
        b.attack.dirY = 0.9f
        b.attack.range = b.height * 1.1f
        b.attack.hitboxW = b.height * 0.38f
        b.attack.hitboxH = b.height * 0.5f
        b.attack.activeStart = 0.08f
        b.attack.activeEnd = 1f
        b.attack.aerial = true
        b.vy = CombatConfig.FLYER_DIVE_SPEED
        b.vx = dir * CombatConfig.FLYER_SPEED * 0.55f
    }

    private fun updateFlyerStrike(e: Enemy) {
        val b = e.body
        e.strikeBox.set(
            b.hipX,
            b.hipY + b.height * 0.08f,
            b.height * 0.28f,
            b.height * 0.42f,
        )
        b.hitbox.set(e.strikeBox.x, e.strikeBox.y, e.strikeBox.halfW, e.strikeBox.halfH)
    }

    private fun think(e: Enemy, target: Stickman, dt: Float, groundY: Float, minX: Float, maxX: Float, brawl: Boolean) {
        val b = e.body
        if (b.stun > 0f) {
            e.ai = EnemyState.STUN
        }
        val busy = e.ai == EnemyState.ATTACK || e.ai == EnemyState.AIRBORNE || b.attacking || b.airborne
        if (!busy) {
            b.facing = if (target.hipX >= b.hipX) 1f else -1f
        }
        val gap = abs(target.hipX - b.hipX)
        e.think -= dt
        when (e.ai) {
            EnemyState.HIT, EnemyState.STUN -> {
                e.wishVx = 0f
                if (b.stun <= 0f && b.state != ActorState.HIT) {
                    e.ai = EnemyState.APPROACH
                    releaseSlot(e)
                    e.think = 0f
                }
            }
            EnemyState.DEAD -> Unit
            EnemyState.AIRBORNE -> {
                updateStrikeBox(e)
                if (!b.airborne) {
                    e.ai = EnemyState.APPROACH
                    b.attacking = false
                    e.wishVx = b.facing * CombatConfig.ENEMY_SPEED
                    e.think = 0.08f + rng.nextFloat() * 0.12f
                }
            }
            EnemyState.ATTACK -> {
                e.attackWind -= dt
                updateStrikeBox(e)
                val jumping = b.attack.type == AttackType.JUMP_UP || b.attack.type == AttackType.JUMP_DIAG
                if (!jumping && e.attackWind < 0.14f && e.attackWind > 0f) {
                    val dir = toward(target, b)
                    e.wishVx = dir * b.height * 7f
                    b.vx = e.wishVx
                    b.facing = dir
                }
                if (e.attackWind <= 0f) {
                    releaseSlot(e)
                    if (b.airborne) {
                        e.ai = EnemyState.AIRBORNE
                    } else {
                        e.ai = EnemyState.APPROACH
                        b.attacking = false
                        e.wishVx = b.facing * CombatConfig.ENEMY_SPEED * 0.9f
                    }
                }
            }
            else -> {
                e.strikeBox.set(b.hipX, b.hipY, 0f, 0f)
                if (!b.airborne) {
                    b.vx = e.wishVx
                    if (e.think <= 0f) pickManeuver(e, target, gap, brawl)
                }
            }
        }
        b.hipX = b.hipX.coerceIn(minX, maxX)
    }

    private fun pickManeuver(e: Enemy, target: Stickman, gap: Float, brawl: Boolean) {
        val b = e.body
        val h = b.height
        val dir = toward(target, b)
        val roll = rng.nextFloat()
        val slotCap = if (brawl) 8 else CombatConfig.ATTACK_SLOTS
        if (gap > h * 2.8f) {
            when {
                roll < (if (brawl) 0.48f else 0.36f) -> beginLeap(e, target, diag = true, damaging = brawl)
                roll < 0.78f -> {
                    e.ai = EnemyState.APPROACH
                    e.wishVx = dir * CombatConfig.ENEMY_SPEED * (1.25f + rng.nextFloat() * 0.55f)
                    b.vx = e.wishVx
                    e.think = 0.22f + rng.nextFloat() * 0.28f
                }
                else -> {
                    e.ai = EnemyState.APPROACH
                    e.wishVx = dir * CombatConfig.ENEMY_SPEED * 2.15f
                    b.vx = e.wishVx
                    e.think = 0.16f + rng.nextFloat() * 0.12f
                }
            }
            return
        }
        val attackRoll = if (brawl) 0.72f else 0.40f
        if (slots < slotCap && roll < attackRoll) {
            val jumpAtFlyer = target.flying && rng.nextFloat() < 0.7f
            if (!jumpAtFlyer && rng.nextFloat() < 0.48f && gap < h * 2.15f) startJab(e, target) else startJumpAttack(e, target)
            return
        }
        when {
            roll < 0.30f -> beginLeap(e, target, diag = gap > h * 1.15f || rng.nextBoolean(), damaging = brawl)
            roll < 0.55f -> {
                e.ai = EnemyState.IDLE
                val orbit = if (rng.nextBoolean()) 1f else -1f
                e.wishVx = orbit * CombatConfig.ENEMY_SPEED * (0.95f + rng.nextFloat() * 0.55f)
                b.vx = e.wishVx
                e.think = 0.22f + rng.nextFloat() * 0.28f
            }
            roll < 0.76f -> {
                e.ai = EnemyState.APPROACH
                e.wishVx = dir * CombatConfig.ENEMY_SPEED * (1.05f + rng.nextFloat() * 0.4f)
                b.vx = e.wishVx
                e.think = 0.18f + rng.nextFloat() * 0.22f
            }
            roll < 0.90f -> {
                e.ai = EnemyState.APPROACH
                e.wishVx = dir * CombatConfig.ENEMY_SPEED * 2.4f
                b.vx = e.wishVx
                e.think = 0.18f + rng.nextFloat() * 0.1f
            }
            else -> {
                e.ai = EnemyState.IDLE
                e.wishVx = -dir * CombatConfig.ENEMY_SPEED * (1.35f + rng.nextFloat() * 0.4f)
                b.vx = e.wishVx
                e.think = 0.16f + rng.nextFloat() * 0.16f
            }
        }
    }

    private fun startJab(e: Enemy, target: Stickman) {
        val b = e.body
        val h = b.height
        val dir = toward(target, b)
        slots++
        e.hasSlot = true
        e.ai = EnemyState.ATTACK
        e.attackWind = 0.38f
        e.think = 0.38f
        e.cueSwing = true
        e.wishVx = 0f
        b.strikeId++
        b.facing = dir
        b.attacking = true
        b.state = ActorState.ATTACK
        b.actionT = 0f
        b.actionDur = 0.38f
        b.attack.type = AttackType.JAB
        b.attack.dirX = dir
        b.attack.dirY = 0f
        b.attack.range = h * CombatConfig.ENEMY_ATTACK_RANGE
        b.attack.hitboxW = h * 0.42f
        b.attack.hitboxH = h * 0.32f
        b.attack.activeStart = 0.55f
        b.attack.activeEnd = 0.95f
        b.attack.aerial = false
        b.attack.jumpSpeed = 0f
    }

    private fun startJumpAttack(e: Enemy, target: Stickman) {
        slots++
        e.hasSlot = true
        beginLeap(e, target, diag = abs(target.hipX - e.body.hipX) > e.body.height * 1.25f || rng.nextBoolean(), damaging = true)
    }

    private fun beginLeap(e: Enemy, target: Stickman, diag: Boolean, damaging: Boolean) {
        val b = e.body
        val h = b.height
        val dir = toward(target, b)
        b.facing = dir
        b.attacking = true
        b.state = ActorState.AIRBORNE
        b.airborne = true
        b.actionT = 0f
        b.actionDur = CombatConfig.JUMP_DURATION
        b.attack.dirX = dir
        b.attack.dirY = if (diag) -0.75f else -1f
        b.attack.duration = CombatConfig.JUMP_DURATION
        b.attack.range = h * CombatConfig.JUMP_RANGE
        b.attack.activeStart = 0.10f
        b.attack.activeEnd = 0.82f
        b.attack.aerial = true
        if (damaging) b.strikeId++
        e.cueSwing = true
        e.wishVx = 0f
        e.think = CombatConfig.JUMP_DURATION
        if (diag) {
            b.attack.type = AttackType.JUMP_DIAG
            b.attack.hitboxW = h * 0.7f
            b.attack.hitboxH = h * 0.6f
            b.attack.jumpSpeed = CombatConfig.DIAG_JUMP_SPEED
            b.vy = -CombatConfig.DIAG_JUMP_SPEED
            b.vx = dir * (h * CombatConfig.DIAG_MOVE / CombatConfig.JUMP_DURATION)
        } else {
            b.attack.type = AttackType.JUMP_UP
            b.attack.hitboxW = h * 0.55f
            b.attack.hitboxH = h * 0.7f
            b.attack.jumpSpeed = CombatConfig.JUMP_SPEED
            b.vy = -CombatConfig.JUMP_SPEED
            b.vx = dir * (h * CombatConfig.JUMP_MOVE / CombatConfig.JUMP_DURATION)
        }
        if (damaging) {
            e.ai = EnemyState.ATTACK
            e.attackWind = CombatConfig.JUMP_DURATION
        } else {
            e.ai = EnemyState.AIRBORNE
            e.attackWind = 0f
            b.hitbox.set(b.hipX, b.hipY, 0f, 0f)
        }
    }

    private fun updateStrikeBox(e: Enemy) {
        val b = e.body
        if (!b.attacking || e.ai != EnemyState.ATTACK) {
            e.strikeBox.set(b.hipX, b.hipY, 0f, 0f)
            return
        }
        val n = b.actionNorm()
        val a = b.attack
        if (n < a.activeStart || n > a.activeEnd) {
            e.strikeBox.set(b.hipX, b.hipY, 0f, 0f)
            return
        }
        val h = b.height
        val cx = b.hipX + b.facing * (a.range * 0.45f)
        val cy = when (a.type) {
            AttackType.JUMP_UP -> b.hipY - h * 0.45f
            AttackType.JUMP_DIAG -> b.hipY - h * 0.32f
            AttackType.KICK -> b.hipY - h * 0.08f
            else -> b.hipY - h * 0.22f
        }
        val hw = if (a.hitboxW > 1f) a.hitboxW else h * 0.4f
        val hh = if (a.hitboxH > 1f) a.hitboxH else h * 0.35f
        e.strikeBox.set(cx, cy, hw, hh)
    }

    private fun toward(target: Stickman, b: Stickman): Float {
        val dir = sign(target.hipX - b.hipX)
        return if (dir == 0f) b.facing else dir
    }

    fun liveCount(): Int {
        var n = 0
        for (e in enemies) if (e.alive()) n++
        return n
    }

    private fun tickDissolve(e: Enemy, dt: Float) {
        e.spawnDelay -= dt
        if (!e.dissolving) return
        e.dissolve = (e.dissolve + dt / CombatConfig.ENEMY_DISSOLVE).coerceAtMost(1f)
        for (i in e.shatterX.indices) {
            e.shatterVy[i] += 780f * dt
            e.shatterVx[i] *= 0.94f
            e.shatterX[i] += e.shatterVx[i] * dt
            e.shatterY[i] += e.shatterVy[i] * dt
        }
        if (e.dissolve >= 1f) e.dissolving = false
    }
}
