package com.edgard.luta.character

import com.edgard.luta.math.Mathx
import kotlin.math.cos
import kotlin.math.sin

class Skeleton {
    val joints: Array<Joint> = Array(JointId.entries.size) { i ->
        Joint(JointId.entries[i])
    }

    operator fun get(id: JointId): Joint = joints[id.ordinal]

    var upperArm: Float = 44f
    var forearm: Float = 40f
    var thigh: Float = 58f
    var shin: Float = 54f
    var torsoLen: Float = 72f
    var neckLen: Float = 22f
    var headR: Float = 16f
    var shoulderW: Float = 16f
    var hipW: Float = 12f

    fun applyHeight(height: Float) {
        upperArm = height * 0.16f
        forearm = height * 0.155f
        thigh = height * 0.255f
        shin = height * 0.235f
        torsoLen = height * 0.27f
        neckLen = height * 0.085f
        headR = height * 0.072f
        shoulderW = height * 0.055f
        hipW = height * 0.045f
        this[JointId.HEAD].radius = headR
        this[JointId.TORSO].radius = height * 0.07f
        this[JointId.HIP].radius = height * 0.055f
        this[JointId.L_HAND].radius = height * 0.028f
        this[JointId.R_HAND].radius = height * 0.028f
        this[JointId.L_FOOT].radius = height * 0.03f
        this[JointId.R_FOOT].radius = height * 0.03f
        this[JointId.L_ELBOW].radius = height * 0.022f
        this[JointId.R_ELBOW].radius = height * 0.022f
        this[JointId.L_KNEE].radius = height * 0.024f
        this[JointId.R_KNEE].radius = height * 0.024f
        this[JointId.L_SHOULDER].radius = height * 0.026f
        this[JointId.R_SHOULDER].radius = height * 0.026f
        this[JointId.L_HIP].radius = height * 0.026f
        this[JointId.R_HIP].radius = height * 0.026f
    }

    fun placeCore(
        hipX: Float,
        hipY: Float,
        facing: Float,
        torsoRot: Float,
        hipRot: Float,
        headRot: Float,
        shoulderShiftX: Float,
        shoulderShiftY: Float,
        squash: Float,
    ) {
        val squashY = 1f - Mathx.clamp(squash, -0.12f, 0.18f)
        val squashX = 1f + Mathx.clamp(squash, -0.12f, 0.18f) * 0.5f
        val hip = this[JointId.HIP]
        hip.set(hipX, hipY)

        val totalTorso = torsoRot + hipRot * 0.35f
        val torso = this[JointId.TORSO]
        torso.set(
            hipX + sin(totalTorso) * torsoLen * squashX * 0.15f * facing,
            hipY - cos(totalTorso) * torsoLen * squashY,
        )

        val head = this[JointId.HEAD]
        head.set(
            torso.worldX + sin(totalTorso + headRot) * neckLen * facing * 0.25f,
            torso.worldY - cos(headRot * 0.4f) * neckLen * squashY,
        )

        val lShoulder = this[JointId.L_SHOULDER]
        val rShoulder = this[JointId.R_SHOULDER]
        val across = shoulderW * squashX
        lShoulder.set(
            torso.worldX - facing * across + shoulderShiftX * 0.35f,
            torso.worldY + 6f + shoulderShiftY * 0.25f,
        )
        rShoulder.set(
            torso.worldX + facing * across + shoulderShiftX,
            torso.worldY + 4f + shoulderShiftY,
        )

        val lHip = this[JointId.L_HIP]
        val rHip = this[JointId.R_HIP]
        lHip.set(hipX - facing * hipW, hipY + 2f)
        rHip.set(hipX + facing * hipW, hipY + 2f)
    }
}
