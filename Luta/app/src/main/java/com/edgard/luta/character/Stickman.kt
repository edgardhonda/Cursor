package com.edgard.luta.character

import com.edgard.luta.combat.Attack
import com.edgard.luta.combat.Hitbox
import com.edgard.luta.math.CombatConfig

enum class Hand { LEFT, RIGHT }

enum class ActorState {
    IDLE,
    ATTACK,
    HIT,
    STUN,
    DEAD,
    AIRBORNE,
}

class Stickman(
    val isPlayer: Boolean,
    var fillColor: Int,
) {
    val skeleton = Skeleton()
    val attack = Attack()
    val hitbox = Hitbox()
    val bodyBox = Hitbox()

    var hipX: Float = 0f
    var hipY: Float = 0f
    var height: Float = 80f
    var facing: Float = 1f
    var vx: Float = 0f
    var vy: Float = 0f
    var airborne: Boolean = false
    var flying: Boolean = false

    var health: Float = if (isPlayer) CombatConfig.PLAYER_HP else CombatConfig.ENEMY_HP
    var maxHealth: Float = health

    var state: ActorState = ActorState.IDLE
    var actionT: Float = 0f
    var actionDur: Float = 0.1f
    var attacking: Boolean = false
    var strikeId: Int = 0
    var lastHitBy: Int = -1
    var flash: Float = 0f
    var invuln: Float = 0f
    var stun: Float = 0f
    var time: Float = 0f

    var stretch: Float = 1f
    var lean: Float = 0f
    var squash: Float = 0f

    var lHandTx: Float = 0f
    var lHandTy: Float = 0f
    var rHandTx: Float = 0f
    var rHandTy: Float = 0f
    var lFootTx: Float = 0f
    var lFootTy: Float = 0f
    var rFootTx: Float = 0f
    var rFootTy: Float = 0f

    val trailX = FloatArray(CombatConfig.TRAIL_POINTS)
    val trailY = FloatArray(CombatConfig.TRAIL_POINTS)
    var trailCount: Int = 0
    var trailHead: Int = 0

    var exploding: Boolean = false
    var explode: Float = 0f
    val shatterX = FloatArray(JointId.entries.size)
    val shatterY = FloatArray(JointId.entries.size)
    val shatterVx = FloatArray(JointId.entries.size)
    val shatterVy = FloatArray(JointId.entries.size)

    fun reset(hp: Float = maxHealth) {
        health = hp
        vx = 0f
        vy = 0f
        airborne = flying
        state = ActorState.IDLE
        attacking = false
        actionT = 0f
        flash = 0f
        invuln = 0f
        stun = 0f
        stretch = 1f
        lean = 0f
        squash = 0f
        lastHitBy = -1
        trailCount = 0
        trailHead = 0
        exploding = false
        explode = 0f
        for (i in shatterX.indices) {
            shatterX[i] = 0f
            shatterY[i] = 0f
            shatterVx[i] = 0f
            shatterVy[i] = 0f
        }
    }

    fun beginExplode(dirX: Float) {
        exploding = true
        explode = 0f
        state = ActorState.DEAD
        attacking = false
        vx = 0f
        vy = 0f
        airborne = false
        flash = 0.16f
        val cx = hipX
        val cy = hipY - height * 0.22f
        val joints = skeleton.joints
        for (i in joints.indices) {
            val j = joints[i]
            val dx = j.worldX - cx
            val dy = j.worldY - cy
            shatterX[i] = 0f
            shatterY[i] = 0f
            shatterVx[i] = dirX * (220f + i * 18f) + dx * 14f
            shatterVy[i] = -420f - i * 14f + dy * 11f
        }
    }

    fun tickExplode(dt: Float) {
        if (!exploding) return
        explode = (explode + dt / CombatConfig.PLAYER_EXPLODE).coerceAtMost(1f)
        for (i in shatterX.indices) {
            shatterVy[i] += 920f * dt
            shatterVx[i] *= 0.93f
            shatterX[i] += shatterVx[i] * dt
            shatterY[i] += shatterVy[i] * dt
        }
        if (explode >= 1f) exploding = false
    }

    fun chestX(): Float = skeleton[JointId.TORSO].worldX
    fun chestY(): Float = skeleton[JointId.TORSO].worldY

    fun actionNorm(): Float {
        return if (actionDur <= 1e-4f) 1f else (actionT / actionDur).coerceIn(0f, 1f)
    }

    fun canCancel(): Boolean {
        if (!attacking) return true
        return actionNorm() >= CombatConfig.CANCEL_AT
    }

    fun pushTrail(x: Float, y: Float) {
        trailX[trailHead] = x
        trailY[trailHead] = y
        trailHead = (trailHead + 1) % CombatConfig.TRAIL_POINTS
        if (trailCount < CombatConfig.TRAIL_POINTS) trailCount++
    }

    fun updateBodyBox() {
        bodyBox.set(hipX, hipY - height * 0.22f, height * 0.18f, height * 0.42f)
    }
}
