package com.edgard.luta.physics

import com.edgard.luta.character.ActorState
import com.edgard.luta.character.Stickman
import com.edgard.luta.combat.AttackType
import com.edgard.luta.math.CombatConfig
import com.edgard.luta.math.Mathx

class PhysicsController {
    fun update(
        s: Stickman,
        dt: Float,
        groundY: Float,
        minX: Float,
        maxX: Float,
        frozen: Boolean,
    ) {
        if (frozen) {
            place(s, groundY)
            return
        }
        if (s.state == ActorState.DEAD) {
            s.vx *= 0.92f
            s.hipX += s.vx * dt
            s.hipX = Mathx.clamp(s.hipX, minX, maxX)
            val restY = groundY - s.height * 0.42f
            if (s.airborne || s.hipY < restY - 0.5f) {
                s.vy += CombatConfig.GRAVITY * dt
                s.hipY += s.vy * dt
            }
            if (s.hipY >= restY) {
                s.hipY = restY
                if (s.vy > 0f) s.vy = 0f
                s.airborne = false
            } else {
                s.airborne = true
            }
            place(s, groundY)
            return
        }
        if (s.flying) {
            s.hipX += s.vx * dt
            s.hipY += s.vy * dt
            s.hipX = Mathx.clamp(s.hipX, minX, maxX)
            val ceil = -s.height * 0.5f
            val floor = groundY - s.height * 0.52f
            s.hipY = Mathx.clamp(s.hipY, ceil, floor)
            s.airborne = true
            place(s, groundY)
            return
        }

        val damping = when {
            s.attacking && s.attack.type == AttackType.DASH -> 0.12f
            s.attacking && (s.attack.type == AttackType.JAB || s.attack.type == AttackType.KICK) -> 3.8f
            s.airborne -> 0.8f
            else -> 7.5f
        }
        s.vx *= (1f - damping * dt).coerceAtLeast(0.2f)

        if (s.airborne || s.hipY < groundY - s.height * 0.42f - 1f) {
            s.vy += CombatConfig.GRAVITY * dt
        }

        s.hipX += s.vx * dt
        s.hipY += s.vy * dt
        s.hipX = Mathx.clamp(s.hipX, minX, maxX)

        val restY = groundY - s.height * 0.42f
        if (s.hipY >= restY) {
            s.hipY = restY
            if (s.vy > 0f) s.vy = 0f
            s.airborne = false
            if (s.state == ActorState.AIRBORNE && !s.attacking) s.state = ActorState.IDLE
        } else {
            s.airborne = true
        }
        place(s, groundY)
    }

    private fun place(s: Stickman, groundY: Float) {
        s.skeleton.placeCore(
            s.hipX,
            s.hipY,
            s.facing,
            s.lean,
            s.lean * 0.35f,
            s.lean * 0.2f,
            s.facing * s.stretch * s.height * 0.08f,
            if (s.airborne) -s.height * 0.04f else 0f,
            s.squash,
        )
    }
}
