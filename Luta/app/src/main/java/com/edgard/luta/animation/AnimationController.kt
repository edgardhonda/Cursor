package com.edgard.luta.animation

import com.edgard.luta.character.ActorState
import com.edgard.luta.character.IKSolver
import com.edgard.luta.character.JointId
import com.edgard.luta.character.Stickman
import com.edgard.luta.combat.AttackType
import com.edgard.luta.math.Mathx
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

class AnimationController {
    fun update(s: Stickman, dt: Float, groundY: Float, frozen: Boolean) {
        s.time += dt
        if (s.flash > 0f) s.flash -= dt
        if (s.invuln > 0f) s.invuln -= dt
        if (s.stun > 0f) s.stun -= dt
        if (!frozen && s.attacking) {
            s.actionT += dt
            if (s.actionT >= s.actionDur) {
                s.attacking = false
                s.state = if (s.airborne) ActorState.AIRBORNE else ActorState.IDLE
            }
        }
        if (s.state == ActorState.HIT && s.stun <= 0f && !s.attacking) {
            s.state = if (s.airborne) ActorState.AIRBORNE else ActorState.IDLE
        }
        pose(s, groundY)
    }

    private fun pose(s: Stickman, groundY: Float) {
        val h = s.height
        val t = s.actionNorm()
        val bounce = sin(s.time * 7.5f) * h * 0.012f
        s.stretch = 1f
        s.lean = 0f
        s.squash = sin(s.time * 5.2f) * 0.03f

        val guardR = h * 0.28f
        s.rHandTx = s.hipX + s.facing * guardR
        s.rHandTy = s.hipY - h * 0.38f + bounce
        s.lHandTx = s.hipX + s.facing * h * 0.12f
        s.lHandTy = s.hipY - h * 0.32f - bounce
        s.lFootTx = s.hipX - s.facing * h * 0.10f
        s.rFootTx = s.hipX + s.facing * h * 0.08f
        if (s.flying) {
            s.lFootTy = s.hipY + h * 0.2f
            s.rFootTy = s.hipY + h * 0.16f
        } else {
            s.lFootTy = groundY
            s.rFootTy = groundY
        }

        if (s.attacking) {
            when (s.attack.type) {
                AttackType.JAB -> {
                    val e = Mathx.easeOutCubic((t / 0.55f).coerceIn(0f, 1f))
                    s.stretch = 1f + 0.55f * e
                    s.lean = s.facing * 0.45f * e
                    s.rHandTx = s.hipX + s.facing * h * (0.3f + 1.35f * e)
                    s.rHandTy = s.hipY - h * (0.38f - 0.04f * e)
                    s.lHandTx = s.hipX - s.facing * h * 0.18f * e
                    s.squash = -0.08f * e
                }
                AttackType.KICK -> {
                    val e = Mathx.easeOutCubic((t / 0.5f).coerceIn(0f, 1f))
                    s.stretch = 1f + 0.4f * e
                    s.lean = -s.facing * 0.35f * e
                    s.rFootTx = s.hipX + s.facing * h * (0.2f + 1.55f * e)
                    s.rFootTy = s.hipY - h * 0.08f * (1f - e) + groundY * 0f
                    s.rFootTy = Mathx.lerp(groundY, s.hipY - h * 0.05f, e)
                    s.lHandTx = s.hipX - s.facing * h * 0.22f
                    s.rHandTx = s.hipX + s.facing * h * 0.08f
                }
                AttackType.DASH -> {
                    val go = if (t < 0.7f) 1f else 1f - (t - 0.7f) / 0.3f
                    s.stretch = 1f + 0.7f * go
                    s.lean = s.facing * 0.7f * go
                    s.squash = 0.12f * go
                    s.rHandTx = s.hipX + s.facing * h * (0.4f + 1.6f * go)
                    s.rHandTy = s.hipY - h * 0.28f
                    s.lHandTx = s.hipX - s.facing * h * 0.35f * go
                    s.lHandTy = s.hipY - h * 0.22f
                    s.rFootTy = groundY - h * 0.04f * go
                }
                AttackType.JUMP_UP, AttackType.JUMP_DIAG -> {
                    val up = Mathx.easeOutCubic((t / 0.35f).coerceIn(0f, 1f))
                    s.stretch = 1f + 0.35f * up
                    s.lean = s.facing * 0.25f
                    s.rHandTx = s.hipX + s.facing * h * (0.2f + 0.9f * up)
                    s.rHandTy = s.hipY - h * (0.55f + 0.35f * up)
                    s.lHandTx = s.hipX - s.facing * h * 0.15f
                    s.lHandTy = s.hipY - h * 0.2f
                    s.rFootTx = s.hipX + s.facing * h * 0.35f * up
                    s.rFootTy = s.hipY + h * 0.12f
                    s.lFootTy = s.hipY + h * 0.18f
                }
                AttackType.DIVE -> {
                    val e = Mathx.easeInCubic((t / 0.45f).coerceIn(0f, 1f))
                    s.stretch = 1f + 0.45f * e
                    s.lean = s.facing * 0.85f * e
                    s.rHandTx = s.hipX + s.facing * h * (0.15f + 1.1f * e)
                    s.rHandTy = s.hipY + h * 0.15f * e
                    s.rFootTx = s.hipX - s.facing * h * 0.2f
                    s.rFootTy = s.hipY - h * 0.1f
                }
            }
        } else if (s.state == ActorState.DEAD) {
            s.lean = -s.facing * 0.95f
            s.squash = 0.22f
            s.stretch = 0.72f
            s.lHandTx = s.hipX - s.facing * h * 0.42f
            s.lHandTy = s.hipY - h * 0.12f
            s.rHandTx = s.hipX + s.facing * h * 0.48f
            s.rHandTy = s.hipY - h * 0.05f
            s.lFootTx = s.hipX - s.facing * h * 0.28f
            s.rFootTx = s.hipX + s.facing * h * 0.32f
            if (s.airborne) {
                s.lFootTy = s.hipY + h * 0.2f
                s.rFootTy = s.hipY + h * 0.16f
                s.lHandTy = s.hipY + h * 0.02f
                s.rHandTy = s.hipY + h * 0.06f
            }
        } else if (s.state == ActorState.HIT || s.state == ActorState.STUN) {
            s.lean = -s.facing * 0.5f
            s.squash = 0.12f
            s.lHandTx = s.hipX - s.facing * h * 0.2f
            s.rHandTx = s.hipX - s.facing * h * 0.05f
        } else if (s.flying) {
            val flap = sin(s.time * 9.2f)
            s.stretch = 1.08f
            s.lean = s.facing * 0.12f
            s.rHandTx = s.hipX + s.facing * h * (0.62f + 0.22f * flap)
            s.rHandTy = s.hipY - h * (0.32f - 0.14f * flap)
            s.lHandTx = s.hipX - s.facing * h * (0.58f - 0.22f * flap)
            s.lHandTy = s.hipY - h * (0.30f + 0.14f * flap)
            s.lFootTx = s.hipX - s.facing * h * 0.06f
            s.rFootTx = s.hipX + s.facing * h * 0.1f
            s.lFootTy = s.hipY + h * 0.22f
            s.rFootTy = s.hipY + h * 0.18f
        } else if (s.airborne) {
            s.rHandTx = s.hipX + s.facing * h * 0.2f
            s.rHandTy = s.hipY - h * 0.5f
            s.lFootTx = s.hipX - s.facing * h * 0.06f
            s.rFootTx = s.hipX + s.facing * h * 0.16f
            s.lFootTy = s.hipY + h * 0.16f
            s.rFootTy = s.hipY + h * 0.10f
        } else {
            walkOrIdle(s, h, groundY)
        }

        val sk = s.skeleton
        val arm1 = sk.upperArm * s.stretch
        val arm2 = sk.forearm * s.stretch
        val thigh = sk.thigh
        val shin = sk.shin
        val lBend = if (s.facing > 0f) 1f else -1f
        val rBend = -lBend
        IKSolver.solveTwoBone(
            sk[JointId.L_SHOULDER].worldX, sk[JointId.L_SHOULDER].worldY,
            arm1, arm2, s.lHandTx, s.lHandTy, lBend, sk[JointId.L_ELBOW], sk[JointId.L_HAND],
        )
        IKSolver.solveTwoBone(
            sk[JointId.R_SHOULDER].worldX, sk[JointId.R_SHOULDER].worldY,
            arm1, arm2, s.rHandTx, s.rHandTy, rBend, sk[JointId.R_ELBOW], sk[JointId.R_HAND],
        )
        val kneeBend = if (s.facing >= 0f) -1f else 1f
        val lfy = if (s.airborne) s.lFootTy else s.lFootTy.coerceAtMost(groundY)
        val rfy = if (s.airborne) s.rFootTy else s.rFootTy.coerceAtMost(groundY)
        IKSolver.solveTwoBone(
            sk[JointId.L_HIP].worldX, sk[JointId.L_HIP].worldY,
            thigh, shin, s.lFootTx, lfy, kneeBend, sk[JointId.L_KNEE], sk[JointId.L_FOOT],
        )
        IKSolver.solveTwoBone(
            sk[JointId.R_HIP].worldX, sk[JointId.R_HIP].worldY,
            thigh, shin, s.rFootTx, rfy, kneeBend, sk[JointId.R_KNEE], sk[JointId.R_FOOT],
        )
        if (!s.airborne) {
            sk[JointId.L_FOOT].worldY = sk[JointId.L_FOOT].worldY.coerceAtMost(groundY + 1f)
            sk[JointId.R_FOOT].worldY = sk[JointId.R_FOOT].worldY.coerceAtMost(groundY + 1f)
        }

        if (s.attacking) {
            val tip = when (s.attack.type) {
                AttackType.KICK, AttackType.DIVE -> sk[JointId.R_FOOT]
                else -> sk[JointId.R_HAND]
            }
            s.pushTrail(tip.worldX, tip.worldY)
            val n = s.actionNorm()
            val active = n >= s.attack.activeStart && n <= s.attack.activeEnd
            if (active) {
                val cx = when (s.attack.type) {
                    AttackType.JUMP_UP -> s.hipX + s.facing * h * 0.12f
                    AttackType.JAB, AttackType.KICK -> s.hipX + s.facing * (s.attack.range * 0.28f)
                    else -> s.hipX + s.facing * (s.attack.range * 0.45f)
                }
                val cy = when (s.attack.type) {
                    AttackType.JUMP_UP, AttackType.JUMP_DIAG -> s.hipY - h * 0.55f
                    AttackType.DIVE -> s.hipY + h * 0.05f
                    AttackType.KICK -> s.hipY - h * 0.08f
                    else -> s.hipY - h * 0.28f
                }
                s.hitbox.set(cx, cy, s.attack.hitboxW, s.attack.hitboxH)
            } else {
                s.hitbox.set(s.hipX, s.hipY, 0f, 0f)
            }
        } else {
            s.hitbox.set(s.hipX, s.hipY, 0f, 0f)
            s.trailCount = (s.trailCount - 1).coerceAtLeast(0)
        }
        s.updateBodyBox()
    }

    private fun walkOrIdle(s: Stickman, h: Float, groundY: Float) {
        val speed = abs(s.vx)
        if (speed < 28f) {
            s.lFootTx = s.hipX - s.facing * h * 0.10f
            s.rFootTx = s.hipX + s.facing * h * 0.07f
            s.lFootTy = groundY
            s.rFootTy = groundY
            s.lean = s.facing * 0.04f
            return
        }
        val cadence = (3.1f + speed * 0.014f).coerceIn(3.1f, 8.2f)
        val phase = s.time * cadence
        val stride = (h * 0.16f + speed * 0.011f).coerceAtMost(h * 0.34f)
        val lift = (h * 0.055f + speed * 0.0035f).coerceAtMost(h * 0.13f)
        val front = sin(phase)
        val back = sin(phase + PI.toFloat())
        s.rFootTx = s.hipX + s.facing * (h * 0.04f + front * stride)
        s.lFootTx = s.hipX + s.facing * (-h * 0.03f + back * stride)
        val rSwing = (-cos(phase)).coerceAtLeast(0f)
        val lSwing = (-cos(phase + PI.toFloat())).coerceAtLeast(0f)
        s.rFootTy = groundY - rSwing * lift
        s.lFootTy = groundY - lSwing * lift
        s.rHandTx = s.hipX + s.facing * (h * 0.24f - front * h * 0.16f)
        s.lHandTx = s.hipX + s.facing * (h * 0.10f - back * h * 0.14f)
        s.rHandTy = s.hipY - h * 0.36f + front * h * 0.035f
        s.lHandTy = s.hipY - h * 0.32f + back * h * 0.035f
        s.lean = s.facing * (0.08f + (speed / 420f).coerceAtMost(0.18f))
        s.squash = sin(phase * 2f) * 0.045f
    }
}
