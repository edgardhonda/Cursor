package com.edgard.luta.character

enum class JointId {
    HIP,
    TORSO,
    HEAD,
    L_SHOULDER,
    L_ELBOW,
    L_HAND,
    R_SHOULDER,
    R_ELBOW,
    R_HAND,
    L_HIP,
    L_KNEE,
    L_FOOT,
    R_HIP,
    R_KNEE,
    R_FOOT,
}

class Joint(val id: JointId) {
    var worldX: Float = 0f
    var worldY: Float = 0f
    var lastX: Float = 0f
    var lastY: Float = 0f
    var radius: Float = 8f

    fun remember() {
        lastX = worldX
        lastY = worldY
    }

    fun set(x: Float, y: Float) {
        worldX = x
        worldY = y
    }
}
