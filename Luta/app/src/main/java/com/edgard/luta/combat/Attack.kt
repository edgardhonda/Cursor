package com.edgard.luta.combat

enum class AttackType {
    JAB,
    KICK,
    DASH,
    JUMP_UP,
    JUMP_DIAG,
    DIVE,
}

enum class GestureAction {
    TAP,
    SWIPE_UP,
    SWIPE_DOWN,
    SWIPE_LEFT,
    SWIPE_RIGHT,
    SWIPE_UP_LEFT,
    SWIPE_UP_RIGHT,
    SWIPE_DOWN_LEFT,
    SWIPE_DOWN_RIGHT,
}

class Attack {
    var type: AttackType = AttackType.JAB
    var dirX: Float = 1f
    var dirY: Float = 0f
    var duration: Float = 0.11f
    var damage: Float = 8f
    var range: Float = 40f
    var movementDistance: Float = 10f
    var knockback: Float = 140f
    var canHitMultipleEnemies: Boolean = false
    var aerial: Boolean = false
    var jumpSpeed: Float = 0f
    var hitboxW: Float = 24f
    var hitboxH: Float = 20f
    var activeStart: Float = 0.12f
    var activeEnd: Float = 0.78f

    fun copyFrom(o: Attack) {
        type = o.type
        dirX = o.dirX
        dirY = o.dirY
        duration = o.duration
        damage = o.damage
        range = o.range
        movementDistance = o.movementDistance
        knockback = o.knockback
        canHitMultipleEnemies = o.canHitMultipleEnemies
        aerial = o.aerial
        jumpSpeed = o.jumpSpeed
        hitboxW = o.hitboxW
        hitboxH = o.hitboxH
        activeStart = o.activeStart
        activeEnd = o.activeEnd
    }
}

class Hitbox {
    var x: Float = 0f
    var y: Float = 0f
    var halfW: Float = 12f
    var halfH: Float = 16f

    fun set(cx: Float, cy: Float, hw: Float, hh: Float) {
        x = cx
        y = cy
        halfW = hw
        halfH = hh
    }

    fun overlaps(o: Hitbox): Boolean {
        return kotlin.math.abs(x - o.x) <= halfW + o.halfW &&
            kotlin.math.abs(y - o.y) <= halfH + o.halfH
    }
}
