package com.edgard.luta.game

import android.graphics.Canvas
import android.view.MotionEvent
import com.edgard.luta.animation.AnimationController
import com.edgard.luta.audio.GameAudio
import com.edgard.luta.camera.CameraController
import com.edgard.luta.character.ActorState
import com.edgard.luta.character.PlayerController
import com.edgard.luta.character.Stickman
import com.edgard.luta.collision.CollisionSystem
import com.edgard.luta.combat.AttackType
import com.edgard.luta.combat.CombatController
import com.edgard.luta.enemy.EnemyManager
import com.edgard.luta.enemy.EnemyState
import com.edgard.luta.input.GestureRecognizer
import com.edgard.luta.input.InputManager
import com.edgard.luta.input.TouchSample
import com.edgard.luta.math.CombatConfig
import com.edgard.luta.physics.PhysicsController
import com.edgard.luta.render.ParticleSystem
import com.edgard.luta.render.Renderer

enum class GameSpeed(val scale: Float, val label: String) {
    SLOW(CombatConfig.SPEED_SLOW, "Lenta"),
    MEDIUM(CombatConfig.SPEED_MED, "Média"),
    FAST(CombatConfig.SPEED_FAST, "Rápida"),
}

class GameWorld(
    private val onHitFeel: () -> Unit,
    private val audio: GameAudio,
) {
    val input = InputManager()
    val gestures = GestureRecognizer()
    val combat = CombatController()
    val player = Stickman(isPlayer = true, fillColor = 0xFFF4F0E6.toInt())
    val playerCtrl = PlayerController()
    val enemies = EnemyManager()
    val anim = AnimationController()
    val physics = PhysicsController()
    val collision = CollisionSystem()
    val camera = CameraController()
    val renderer = Renderer()
    val vfx = ParticleSystem()

    private val touchScratch = Array(32) { TouchSample() }

    var viewW: Float = 0f
    var viewH: Float = 0f
    var worldW: Float = 0f
    var groundY: Float = 0f
    var fps: Float = 60f
    var gestureLabel: String = "—"
    var hitStop: Float = 0f
    var paused: Boolean = false
    var pauseLeft: Float = 0f
    var pauseTop: Float = 0f
    var pauseRight: Float = 0f
    var pauseBottom: Float = 0f
    var speed: GameSpeed = GameSpeed.MEDIUM
    var onSpeedChanged: ((GameSpeed) -> Unit)? = null
    val speedChipL = FloatArray(3)
    val speedChipR = FloatArray(3)
    var speedChipT: Float = 0f
    var speedChipB: Float = 0f
    private var fpsEma: Float = 60f
    private var ready: Boolean = false
    private var koTimer: Float = 0f
    private var koPlayed: Boolean = false

    fun resize(w: Int, h: Int) {
        if (w <= 1 || h <= 1) return
        val first = !ready
        viewW = w.toFloat()
        viewH = h.toFloat()
        worldW = viewW * CombatConfig.WORLD_WIDTH_MUL
        groundY = viewH * CombatConfig.GROUND_FRAC
        camera.resize(viewW, viewH)
        val ph = viewH * CombatConfig.PLAYER_HEIGHT_FRAC
        val eh = viewH * CombatConfig.ENEMY_HEIGHT_FRAC
        val fh = viewH * CombatConfig.FLYER_HEIGHT_FRAC
        player.height = ph
        player.maxHealth = CombatConfig.PLAYER_HP
        player.skeleton.applyHeight(ph)
        if (first) {
            reset()
            ready = true
        } else {
            player.hipY = groundY - player.height * 0.42f
            for (e in enemies.enemies) {
                val h = if (e.flying) fh else eh
                e.body.height = h
                e.body.skeleton.applyHeight(h)
            }
            layoutPauseButton()
        }
    }

    fun reset() {
        combat.clear()
        playerCtrl.reset()
        player.reset(CombatConfig.PLAYER_HP)
        player.facing = 1f
        player.hipX = worldW * 0.35f
        player.hipY = groundY - player.height * 0.42f
        vfx.reset()
        hitStop = 0f
        koTimer = 0f
        koPlayed = false
        val eh = viewH * CombatConfig.ENEMY_HEIGHT_FRAC
        val fh = viewH * CombatConfig.FLYER_HEIGHT_FRAC
        enemies.reset(
            worldW,
            groundY,
            eh,
            fh,
            CombatConfig.START_ENEMIES,
            CombatConfig.START_FLYERS,
        )
        physics.update(player, 0f, groundY, player.height, worldW - player.height, false)
        anim.update(player, 0f, groundY, false)
        for (e in enemies.enemies) {
            physics.update(e.body, 0f, groundY, 0f, worldW, false)
            anim.update(e.body, 0f, groundY, false)
        }
        camera.snap(player.hipX, worldW)
        paused = false
        layoutPauseButton()
    }

    fun pause() {
        if (paused) return
        paused = true
        combat.clear()
        gestures.cancel()
    }

    private fun layoutPauseButton() {
        if (viewW <= 1f || viewH <= 1f) return
        val size = viewH * 0.08f
        val pad = (viewH * 0.022f).coerceAtLeast(10f)
        pauseRight = viewW - pad
        pauseTop = pad
        pauseLeft = pauseRight - size
        pauseBottom = pauseTop + size
        val chipW = viewW * 0.22f
        val chipH = viewH * 0.072f
        val gap = viewW * 0.016f
        val total = chipW * 3f + gap * 2f
        var x = (viewW - total) * 0.5f
        speedChipT = viewH * 0.62f
        speedChipB = speedChipT + chipH
        for (i in 0 until 3) {
            speedChipL[i] = x
            speedChipR[i] = x + chipW
            x += chipW + gap
        }
    }

    private fun hitSpeedChip(x: Float, y: Float): Int {
        if (y < speedChipT || y > speedChipB) return -1
        for (i in 0 until 3) {
            if (x >= speedChipL[i] && x <= speedChipR[i]) return i
        }
        return -1
    }

    fun selectSpeed(next: GameSpeed) {
        if (speed == next) return
        speed = next
        onSpeedChanged?.invoke(next)
    }

    private fun hitPauseButton(x: Float, y: Float): Boolean {
        val m = viewH * 0.012f
        return x >= pauseLeft - m && x <= pauseRight + m && y >= pauseTop - m && y <= pauseBottom + m
    }

    private fun handlePauseTouches(n: Int): Boolean {
        var onButton = false
        var anyDown = false
        for (i in 0 until n) {
            val s = touchScratch[i]
            if (s.action != MotionEvent.ACTION_DOWN && s.action != MotionEvent.ACTION_POINTER_DOWN) continue
            anyDown = true
            if (hitPauseButton(s.x, s.y)) onButton = true
        }
        if (onButton) {
            paused = !paused
            combat.clear()
            gestures.cancel()
            return true
        }
        if (paused) {
            for (i in 0 until n) {
                val s = touchScratch[i]
                if (s.action != MotionEvent.ACTION_DOWN && s.action != MotionEvent.ACTION_POINTER_DOWN) continue
                val chip = hitSpeedChip(s.x, s.y)
                if (chip >= 0) {
                    selectSpeed(GameSpeed.entries[chip])
                    return true
                }
            }
            if (anyDown) {
                paused = false
                combat.clear()
                gestures.cancel()
                return true
            }
        }
        return false
    }

    fun update(rawDt: Float) {
        if (!ready) return
        layoutPauseButton()
        val n = input.drain(touchScratch)
        val pauseTouch = handlePauseTouches(n)
        if (paused) return
        if (!pauseTouch) {
            gestures.process(touchScratch, n, combat)
            gestureLabel = gestures.lastLabel
        }

        val dt = rawDt * speed.scale

        if (player.health <= 0f) {
            if (!koPlayed) {
                player.state = ActorState.DEAD
                player.attacking = false
                anim.update(player, 0f, groundY, false)
                val dir = if (player.vx >= 0f) 1f else -1f
                player.beginExplode(dir)
                vfx.explode(player)
                audio.ko()
                hitStop = 0.08f
                onHitFeel()
                koPlayed = true
            }
            player.tickExplode(dt)
            koTimer += dt
            var tapped = false
            if (!pauseTouch) {
                for (i in 0 until n) {
                    val s = touchScratch[i]
                    if (s.action == MotionEvent.ACTION_DOWN && !hitPauseButton(s.x, s.y)) tapped = true
                }
            }
            if (tapped && koTimer > CombatConfig.PLAYER_EXPLODE + 0.25f) reset()
        }

        val frozen = hitStop > 0f
        if (frozen) hitStop -= dt

        val brawl = player.health <= 0f || player.state == ActorState.DEAD
        if (!brawl) playerCtrl.faceThreats(player, enemies)
        if (!brawl && !frozen) {
            if (playerCtrl.tryConsume(player, combat, player.height, enemies)) audio.swing(player.attack.type)
        } else if (!brawl && player.canCancel()) {
            if (playerCtrl.tryConsume(player, combat, player.height, enemies)) audio.swing(player.attack.type)
        }

        val minX = player.height * 0.4f
        val maxX = worldW - player.height * 0.4f
        if (player.state != ActorState.DEAD) {
            val wasAir = player.airborne
            val fallVy = player.vy
            physics.update(player, dt, groundY, minX, maxX, frozen)
            if (wasAir && !player.airborne && fallVy > 280f) audio.land()
            anim.update(player, dt, groundY, frozen)
        } else {
            anim.update(player, dt, groundY, frozen)
        }

        enemies.update(dt, player, groundY, worldW, minX, maxX, frozen, brawl)
        for (e in enemies.enemies) {
            if (e.cueSwing) {
                e.cueSwing = false
                audio.enemySwing(e.body.attack.type)
            }
            if (e.fallingDead) {
                physics.update(e.body, dt, groundY, minX, maxX, frozen)
                anim.update(e.body, dt, groundY, frozen)
                val restY = groundY - e.body.height * 0.42f
                if (!frozen && (!e.body.airborne || e.body.hipY >= restY - 0.5f)) {
                    e.body.hipY = restY
                    e.body.airborne = false
                    e.fallingDead = false
                    e.spawnDelay = CombatConfig.FLYER_RESPAWN + CombatConfig.ENEMY_DISSOLVE
                    val dir = if (e.body.vx >= 0f) 1f else -1f
                    e.beginDissolve(dir)
                }
                continue
            }
            if (e.ai == EnemyState.DEAD || e.dissolving) {
                anim.update(e.body, dt, groundY, frozen)
                continue
            }
            physics.update(e.body, dt, groundY, minX, maxX, frozen)
            anim.update(e.body, dt, groundY, frozen)
        }

        val hits = collision.resolve(player, enemies, brawl) {
            audio.hurt()
            onHitFeel()
        }
        if (hits > 0) {
            if (!brawl) {
                playerCtrl.registerHit()
                playerCtrl.kills += collision.killsThisFrame
                hitStop = CombatConfig.HIT_STOP.coerceAtMost(CombatConfig.HIT_STOP_MAX)
                audio.hit(player.attack.type, playerCtrl.combo)
                if (player.attacking) {
                    vfx.slash(
                        player.hipX,
                        player.hipY - player.height * 0.25f,
                        player.hipX + player.facing * player.attack.range * 0.6f,
                        player.hipY - player.height * 0.3f,
                    )
                }
                onHitFeel()
            } else {
                audio.hit(AttackType.KICK, 2)
                onHitFeel()
            }
            for (i in 0 until collision.sparkCount) {
                val s = collision.sparks[i]
                if (!s.vsPlayer) vfx.impact(s.x, s.y, s.nx, s.ny, s.force)
            }
        }
        for (e in enemies.enemies) {
            if (!e.cueDissolve) continue
            e.cueDissolve = false
            val dir = if (e.shatterVx[0] >= 0f) 1f else -1f
            anim.update(e.body, 0f, groundY, frozen)
            vfx.disintegrate(e.body, dir)
        }
        if (!frozen) playerCtrl.updateCombo(dt)
        vfx.update(if (frozen) dt * 0.35f else dt)
        camera.update(player.hipX, worldW, dt, frozen)
    }

    fun render(canvas: Canvas) {
        renderer.draw(canvas, this)
    }

    fun noteFrame(dt: Float) {
        if (dt <= 1e-4f) return
        fpsEma = fpsEma * 0.9f + (1f / dt) * 0.1f
        fps = fpsEma
    }
}
