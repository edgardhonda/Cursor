package com.edgard.luta.character

import com.edgard.luta.combat.Attack
import com.edgard.luta.combat.AttackType
import com.edgard.luta.combat.CombatController
import com.edgard.luta.combat.GestureAction
import com.edgard.luta.enemy.EnemyManager
import com.edgard.luta.math.CombatConfig
import kotlin.math.abs
import kotlin.math.sign

class PlayerController {
    var nextIsKick: Boolean = false
    var combo: Int = 0
    var comboTimer: Float = 0f
    var bestCombo: Int = 0
    var kills: Int = 0

    fun reset() {
        nextIsKick = false
        combo = 0
        comboTimer = 0f
        kills = 0
    }

    fun registerHit() {
        combo++
        if (combo > bestCombo) bestCombo = combo
        comboTimer = CombatConfig.COMBO_TIMEOUT
    }

    fun updateCombo(dt: Float) {
        if (combo <= 0) return
        comboTimer -= dt
        if (comboTimer <= 0f) combo = 0
    }

    fun tryConsume(player: Stickman, queue: CombatController, height: Float, enemies: EnemyManager): Boolean {
        if (!player.canCancel() && player.attacking) return false
        if (player.state == ActorState.DEAD) return false
        if (player.stun > 0f && !player.isPlayer) return false
        val action = queue.poll() ?: return false
        if (action == GestureAction.TAP) faceMelee(player, enemies)
        start(player, action, height)
        return true
    }

    fun start(player: Stickman, action: GestureAction, height: Float) {
        val a = player.attack
        fillAttack(a, action, player, height)
        player.attacking = true
        player.state = if (a.aerial) ActorState.AIRBORNE else ActorState.ATTACK
        player.actionT = 0f
        player.actionDur = a.duration
        player.strikeId++
        if (abs(a.dirX) > 0.15f) player.facing = sign(a.dirX)
        applyImpulse(player, a, height)
        if (action == GestureAction.TAP) nextIsKick = !nextIsKick
    }

    private fun fillAttack(a: Attack, action: GestureAction, player: Stickman, h: Float) {
        a.dirX = 1f
        a.dirY = 0f
        a.aerial = false
        a.jumpSpeed = 0f
        a.canHitMultipleEnemies = false
        a.activeStart = 0.10f
        a.activeEnd = 0.82f
        when (action) {
            GestureAction.TAP -> {
                if (nextIsKick) {
                    a.type = AttackType.KICK
                    a.duration = CombatConfig.KICK_DURATION
                    a.damage = CombatConfig.KICK_DAMAGE
                    a.range = h * CombatConfig.KICK_RANGE
                    a.movementDistance = h * CombatConfig.KICK_MOVE
                    a.knockback = CombatConfig.KICK_KNOCKBACK
                    a.hitboxW = h * 0.7f
                    a.hitboxH = h * 0.42f
                } else {
                    a.type = AttackType.JAB
                    a.duration = CombatConfig.JAB_DURATION
                    a.damage = CombatConfig.JAB_DAMAGE
                    a.range = h * CombatConfig.JAB_RANGE
                    a.movementDistance = h * CombatConfig.JAB_MOVE
                    a.knockback = CombatConfig.JAB_KNOCKBACK
                    a.hitboxW = h * 0.62f
                    a.hitboxH = h * 0.38f
                }
                a.canHitMultipleEnemies = true
                a.dirX = player.facing
            }
            GestureAction.SWIPE_RIGHT, GestureAction.SWIPE_LEFT -> {
                a.type = AttackType.DASH
                a.dirX = if (action == GestureAction.SWIPE_RIGHT) 1f else -1f
                a.duration = CombatConfig.DASH_DURATION
                a.damage = CombatConfig.DASH_DAMAGE
                a.range = h * CombatConfig.DASH_RANGE
                a.movementDistance = h * CombatConfig.DASH_MOVE
                a.knockback = CombatConfig.DASH_KNOCKBACK
                a.canHitMultipleEnemies = true
                a.hitboxW = h * 0.85f
                a.hitboxH = h * 0.42f
                a.activeStart = 0.05f
                a.activeEnd = 0.92f
            }
            GestureAction.SWIPE_UP -> {
                a.type = AttackType.JUMP_UP
                a.dirX = player.facing
                a.dirY = -1f
                a.duration = CombatConfig.JUMP_DURATION
                a.damage = CombatConfig.JUMP_DAMAGE
                a.range = h * CombatConfig.JUMP_RANGE
                a.movementDistance = h * CombatConfig.JUMP_MOVE
                a.knockback = CombatConfig.JUMP_KNOCKBACK
                a.aerial = true
                a.jumpSpeed = CombatConfig.JUMP_SPEED
                a.canHitMultipleEnemies = true
                a.hitboxW = h * 0.7f
                a.hitboxH = h * 1.05f
            }
            GestureAction.SWIPE_UP_RIGHT, GestureAction.SWIPE_UP_LEFT -> {
                a.type = AttackType.JUMP_DIAG
                a.dirX = if (action == GestureAction.SWIPE_UP_RIGHT) 1f else -1f
                a.dirY = -0.75f
                a.duration = CombatConfig.JUMP_DURATION
                a.damage = CombatConfig.JUMP_DAMAGE
                a.range = h * CombatConfig.JUMP_RANGE
                a.movementDistance = h * CombatConfig.DIAG_MOVE
                a.knockback = CombatConfig.JUMP_KNOCKBACK
                a.aerial = true
                a.jumpSpeed = CombatConfig.DIAG_JUMP_SPEED
                a.canHitMultipleEnemies = true
                a.hitboxW = h * 0.85f
                a.hitboxH = h * 0.95f
            }
            GestureAction.SWIPE_DOWN,
            GestureAction.SWIPE_DOWN_RIGHT,
            GestureAction.SWIPE_DOWN_LEFT,
            -> {
                a.type = AttackType.DIVE
                a.dirX = when (action) {
                    GestureAction.SWIPE_DOWN_LEFT -> -1f
                    GestureAction.SWIPE_DOWN_RIGHT -> 1f
                    else -> player.facing
                }
                a.dirY = 0.85f
                a.duration = CombatConfig.DIVE_DURATION
                a.damage = CombatConfig.DIVE_DAMAGE
                a.range = h * CombatConfig.DIVE_RANGE
                a.movementDistance = h * CombatConfig.DIVE_MOVE
                a.knockback = CombatConfig.DIVE_KNOCKBACK
                a.aerial = player.airborne
                a.canHitMultipleEnemies = true
                a.hitboxW = h * 0.6f
                a.hitboxH = h * 0.55f
                a.activeStart = 0.08f
                player.invuln = a.duration * 0.55f
            }
        }
    }

    private fun applyImpulse(player: Stickman, a: Attack, h: Float) {
        val dur = a.duration.coerceAtLeast(0.05f)
        when (a.type) {
            AttackType.DASH -> {
                player.vx = a.dirX * (a.movementDistance / dur) * 1.05f
                player.vy = 0f
            }
            AttackType.JUMP_UP -> {
                player.vy = -a.jumpSpeed
                player.vx = a.dirX * (a.movementDistance / dur)
                player.airborne = true
            }
            AttackType.JUMP_DIAG -> {
                player.vy = -a.jumpSpeed
                player.vx = a.dirX * (a.movementDistance / dur)
                player.airborne = true
            }
            AttackType.DIVE -> {
                player.vx = a.dirX * (a.movementDistance / dur)
                player.vy = if (player.airborne) h * 8f else h * 1.2f
                if (player.airborne) player.vy = CombatConfig.JUMP_SPEED * 0.55f
            }
            AttackType.JAB, AttackType.KICK -> {
                player.vx = a.dirX * (a.movementDistance / dur)
            }
        }
    }

    fun faceThreats(player: Stickman, enemies: EnemyManager) {
        if (player.state == ActorState.DEAD) return
        val directed = player.attacking &&
            player.attack.type != AttackType.JAB &&
            player.attack.type != AttackType.KICK
        if (directed) return
        val meleeR = player.height * CombatConfig.MELEE_LOCK
        var meleeD = Float.MAX_VALUE
        var meleeDir = player.facing
        for (e in enemies.enemies) {
            if (!e.alive() || e.flying) continue
            val dx = e.body.hipX - player.hipX
            val d = abs(dx)
            if (d <= meleeR && d < meleeD) {
                meleeD = d
                meleeDir = if (dx >= 0f) 1f else -1f
            }
        }
        if (meleeD <= meleeR) {
            player.facing = meleeDir
            if (player.attacking) player.attack.dirX = meleeDir
        }
    }

    private fun faceMelee(player: Stickman, enemies: EnemyManager) {
        val meleeR = player.height * CombatConfig.MELEE_LOCK
        var best = Float.MAX_VALUE
        var dir = player.facing
        for (e in enemies.enemies) {
            if (!e.alive() || e.flying) continue
            val dx = e.body.hipX - player.hipX
            val d = abs(dx)
            if (d <= meleeR && d < best) {
                best = d
                dir = if (dx >= 0f) 1f else -1f
            }
        }
        if (best <= meleeR) player.facing = dir
    }
}
