package com.edgard.luta.math

/**
 * Central arcade combat feel. Times in seconds, distances relative to character height
 * unless noted as pixels or fractions of the screen.
 */
object CombatConfig {
    const val PLAYER_HEIGHT_FRAC = 0.13f
    const val ENEMY_HEIGHT_FRAC = 0.11f
    const val FLYER_HEIGHT_FRAC = 0.09f

    const val JAB_DURATION = 0.11f
    const val KICK_DURATION = 0.145f
    const val DASH_DURATION = 0.20f
    const val JUMP_DURATION = 0.30f
    const val DIVE_DURATION = 0.18f

    const val JAB_RANGE = 1.85f
    const val KICK_RANGE = 2.15f
    const val MELEE_LOCK = 2.25f
    const val DASH_RANGE = 4.6f
    const val JUMP_RANGE = 2.4f
    const val DIVE_RANGE = 2.8f

    const val JAB_MOVE = 0.22f
    const val KICK_MOVE = 0.28f
    const val DASH_MOVE = 4.4f
    const val JUMP_MOVE = 0.35f
    const val DIAG_MOVE = 3.4f
    const val DIVE_MOVE = 2.6f

    const val JAB_DAMAGE = 8f
    const val KICK_DAMAGE = 10f
    const val DASH_DAMAGE = 12f
    const val JUMP_DAMAGE = 11f
    const val DIVE_DAMAGE = 14f

    const val JAB_KNOCKBACK = 140f
    const val KICK_KNOCKBACK = 180f
    const val DASH_KNOCKBACK = 260f
    const val JUMP_KNOCKBACK = 200f
    const val DIVE_KNOCKBACK = 240f

    const val HIT_STOP = 0.034f
    const val HIT_STOP_MAX = 0.05f
    const val COMBO_TIMEOUT = 1.05f
    const val CANCEL_AT = 0.28f

    const val SWIPE_PX = 26f
    const val TAP_MAX_PX = 24f
    const val TAP_MAX_S = 0.24f
    const val DIAGONAL_RATIO = 0.40f

    const val MAX_GROUND = 10
    const val MAX_FLYERS = 3
    const val MAX_ENEMIES = MAX_GROUND + MAX_FLYERS
    const val START_ENEMIES = 6
    const val START_FLYERS = 3
    const val ATTACK_SLOTS = 2
    const val ENEMY_HP = 22f
    const val FLYER_HP = 10f
    const val PLAYER_HP = 100f
    const val ENEMY_SPEED = 175f
    const val FLYER_SPEED = 155f
    const val FLYER_HOVER = 2.35f
    const val FLYER_DIVE_SPEED = 560f
    const val ENEMY_ATTACK_RANGE = 1.35f
    const val ENEMY_ATTACK_DAMAGE = 7f
    const val FLYER_ATTACK_DAMAGE = 8f
    const val ENEMY_RESPAWN = 0.85f
    const val FLYER_RESPAWN = 1.15f
    const val ENEMY_DISSOLVE = 0.26f
    const val PLAYER_EXPLODE = 0.34f

    const val CAMERA_TAU = 0.14f
    const val WORLD_WIDTH_MUL = 1f
    const val GRAVITY = 2600f
    const val JUMP_SPEED = 900f
    const val DIAG_JUMP_SPEED = 820f
    const val DASH_SPEED = 1650f

    const val COMMAND_QUEUE = 5
    const val TRAIL_POINTS = 12
    const val GESTURE_SAMPLES = 32

    const val PLAYER_IFRAMES = 0.28f
    const val ENEMY_HIT_STUN = 0.18f
    const val GROUND_FRAC = 0.80f

    const val SPEED_FAST = 1f
    const val SPEED_MED = 0.50f
    const val SPEED_SLOW = SPEED_MED * 0.70f
}
