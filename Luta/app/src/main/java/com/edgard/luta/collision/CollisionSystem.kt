package com.edgard.luta.collision

import com.edgard.luta.character.ActorState
import com.edgard.luta.character.Stickman
import com.edgard.luta.combat.AttackType
import com.edgard.luta.enemy.Enemy
import com.edgard.luta.enemy.EnemyManager
import com.edgard.luta.enemy.EnemyState
import com.edgard.luta.math.CombatConfig
import kotlin.math.abs
import kotlin.math.sign

class HitSpark {
    var x: Float = 0f
    var y: Float = 0f
    var nx: Float = 1f
    var ny: Float = 0f
    var force: Float = 0f
    var vsPlayer: Boolean = false
}

class CollisionSystem {
    val sparks = Array(12) { HitSpark() }
    var sparkCount: Int = 0
    var killsThisFrame: Int = 0

    fun resolve(
        player: Stickman,
        manager: EnemyManager,
        brawl: Boolean,
        onPlayerHit: () -> Unit,
    ): Int {
        sparkCount = 0
        killsThisFrame = 0
        var hits = 0
        if (brawl) {
            hits += resolveBrawl(manager)
            return hits
        }
        val n = player.actionNorm()
        val playerActive = player.attacking &&
            n >= player.attack.activeStart &&
            n <= player.attack.activeEnd &&
            player.hitbox.halfW > 1f

        if (playerActive) {
            val closeCombat = player.attack.type == AttackType.JAB || player.attack.type == AttackType.KICK
            val meleeR = player.height * CombatConfig.MELEE_LOCK
            for (e in manager.enemies) {
                if (!e.alive()) continue
                val b = e.body
                if (b.lastHitBy == player.strikeId) continue
                if (e.flying) {
                    val jump = player.attack.type == AttackType.JUMP_UP ||
                        player.attack.type == AttackType.JUMP_DIAG
                    if (!jump) continue
                    if (!player.hitbox.overlaps(b.bodyBox)) continue
                } else if (closeCombat) {
                    val dx = b.hipX - player.hipX
                    val gap = abs(dx)
                    if (gap <= meleeR) {
                        if (dx * player.facing < -player.height * 0.45f) continue
                    } else if (!player.hitbox.overlaps(b.bodyBox)) {
                        continue
                    }
                } else {
                    if (!player.hitbox.overlaps(b.bodyBox)) continue
                    if (!player.attack.canHitMultipleEnemies) {
                        val dx = b.hipX - player.hipX
                        if (dx * player.facing < -player.height * 0.2f) continue
                    }
                }
                b.lastHitBy = player.strikeId
                applyToEnemy(player, b, e, manager)
                addSpark(b.chestX(), b.chestY(), player.facing, -0.15f, player.attack.knockback * 0.04f, false)
                hits++
            }
        }

        if (player.invuln <= 0f && player.health > 0f) {
            for (e in manager.enemies) {
                if (!e.alive() || e.ai != EnemyState.ATTACK) continue
                val box = if (e.body.hitbox.halfW > 1f) e.body.hitbox else e.strikeBox
                if (box.halfW <= 1f) continue
                if (!box.overlaps(player.bodyBox)) continue
                val dir = sign(player.hipX - e.body.hipX)
                val dmg = if (e.flying) CombatConfig.FLYER_ATTACK_DAMAGE else CombatConfig.ENEMY_ATTACK_DAMAGE
                player.health = (player.health - dmg).coerceAtLeast(0f)
                player.vx += dir * 220f
                player.flash = 0.12f
                player.invuln = CombatConfig.PLAYER_IFRAMES
                addSpark(player.chestX(), player.chestY(), dir, -0.1f, 8f, true)
                onPlayerHit()
                e.attackWind = 0f
                manager.releaseSlot(e)
                break
            }
        }
        return hits
    }

    private fun resolveBrawl(manager: EnemyManager): Int {
        var hits = 0
        for (atk in manager.enemies) {
            if (!atk.alive() || atk.ai != EnemyState.ATTACK) continue
            val box = if (atk.body.hitbox.halfW > 1f) atk.body.hitbox else atk.strikeBox
            if (box.halfW <= 1f) continue
            val a = atk.body
            for (vic in manager.enemies) {
                if (vic === atk || !vic.alive()) continue
                val b = vic.body
                if (b.lastHitBy == a.strikeId) continue
                if (vic.flying) {
                    val aerial = a.attack.type == AttackType.JUMP_UP ||
                        a.attack.type == AttackType.JUMP_DIAG ||
                        a.attack.type == AttackType.DIVE
                    if (!aerial) continue
                }
                if (!box.overlaps(b.bodyBox)) continue
                b.lastHitBy = a.strikeId
                val dir = if (abs(a.attack.dirX) > 0.1f) sign(a.attack.dirX) else a.facing
                killEnemy(b, vic, manager, dir, a.attack.type)
                addSpark(b.chestX(), b.chestY(), dir, -0.15f, 10f, false)
                hits++
            }
        }
        return hits
    }

    private fun killEnemy(b: Stickman, e: Enemy, manager: EnemyManager, dir: Float, type: AttackType) {
        b.health = 0f
        b.state = ActorState.DEAD
        b.attacking = false
        b.flash = 0.12f
        b.stun = 0f
        manager.releaseSlot(e)
        if (e.flying) {
            e.fallingDead = true
            e.ai = EnemyState.DEAD
            b.flying = false
            b.airborne = true
            b.vx = dir * 90f
            b.vy = if (type == AttackType.DIVE) 480f else 380f
            e.spawnDelay = 8f
        } else {
            b.vx = dir * 48f
            b.vy = 0f
            b.airborne = false
            e.spawnDelay = CombatConfig.ENEMY_RESPAWN + CombatConfig.ENEMY_DISSOLVE
            e.beginDissolve(dir)
        }
    }

    private fun applyToEnemy(player: Stickman, b: Stickman, e: Enemy, manager: EnemyManager) {
        b.health -= player.attack.damage
        val dir = if (abs(player.attack.dirX) > 0.1f) sign(player.attack.dirX) else player.facing
        val up = when (player.attack.type) {
            AttackType.JUMP_UP -> -1f
            AttackType.JUMP_DIAG -> -0.55f
            AttackType.DIVE -> 0.2f
            else -> -0.18f
        }
        b.vx = dir * player.attack.knockback
        b.vy = up * player.attack.knockback * 0.5f
        if (up < 0f) b.airborne = true
        b.flash = 0.12f
        b.stun = CombatConfig.ENEMY_HIT_STUN
        b.state = ActorState.HIT
        b.attacking = false
        manager.releaseSlot(e)
        if (b.health <= 0f) {
            b.health = 0f
            b.state = ActorState.DEAD
            b.attacking = false
            if (e.flying) {
                e.fallingDead = true
                e.ai = EnemyState.DEAD
                b.flying = false
                b.airborne = true
                b.vx = dir * 90f
                b.vy = 380f
                e.spawnDelay = 8f
            } else {
                b.vx = dir * 36f
                b.vy = 0f
                b.airborne = false
                e.spawnDelay = CombatConfig.ENEMY_RESPAWN + CombatConfig.ENEMY_DISSOLVE
                e.beginDissolve(dir)
            }
            killsThisFrame++
        } else {
            e.ai = EnemyState.HIT
        }
    }

    private fun addSpark(x: Float, y: Float, nx: Float, ny: Float, force: Float, vsPlayer: Boolean) {
        if (sparkCount >= sparks.size) return
        val s = sparks[sparkCount++]
        s.x = x
        s.y = y
        s.nx = nx
        s.ny = ny
        s.force = force
        s.vsPlayer = vsPlayer
    }
}
