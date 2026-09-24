package com.edgard.luta.render

import android.graphics.Canvas
import android.graphics.DashPathEffect
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import com.edgard.luta.character.Joint
import com.edgard.luta.character.JointId
import com.edgard.luta.character.Stickman
import com.edgard.luta.enemy.Enemy
import com.edgard.luta.enemy.EnemyState
import com.edgard.luta.game.GameSpeed
import com.edgard.luta.game.GameWorld
import com.edgard.luta.math.CombatConfig
import com.edgard.luta.math.Mathx

class Renderer {
    private val bgPaint = Paint()
    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val linePaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val trailPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val smallPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val bar = RectF()
    private val iconPath = Path()
    private var bgShader: LinearGradient? = null
    private var lastW: Int = 0
    private var lastH: Int = 0
    private val dash = DashPathEffect(floatArrayOf(10f, 12f), 0f)

    init {
        linePaint.style = Paint.Style.STROKE
        linePaint.strokeCap = Paint.Cap.ROUND
        linePaint.strokeJoin = Paint.Join.ROUND
        fillPaint.style = Paint.Style.FILL
        trailPaint.style = Paint.Style.STROKE
        trailPaint.strokeCap = Paint.Cap.ROUND
        textPaint.color = 0xFFF4F0E6.toInt()
        textPaint.typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
        smallPaint.color = 0xCCF4F0E6.toInt()
        smallPaint.typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.NORMAL)
    }

    fun draw(canvas: Canvas, world: GameWorld) {
        val w = world.viewW
        val h = world.viewH
        if (w <= 1f || h <= 1f) return
        ensureBg(w.toInt(), h.toInt())
        canvas.drawRect(0f, 0f, w, h, bgPaint)

        canvas.save()
        canvas.translate(-world.camera.x + world.vfx.shakeX, -world.camera.y + world.vfx.shakeY)
        drawArena(canvas, world)
        for (e in world.enemies.enemies) {
            if (e.ai == EnemyState.DEAD && !e.dissolving && !e.fallingDead) continue
            if (e.flying && !e.dissolving) drawFlyerShadow(canvas, e, world.groundY)
            drawStickman(canvas, e.body, e)
        }
        drawStickman(canvas, world.player)
        drawVfx(canvas, world)
        canvas.restore()
        drawHud(canvas, world)
    }

    private fun ensureBg(w: Int, h: Int) {
        if (w == lastW && h == lastH && bgShader != null) return
        lastW = w
        lastH = h
        bgShader = LinearGradient(
            0f, 0f, 0f, h.toFloat(),
            intArrayOf(0xFF12151C.toInt(), 0xFF1C2433.toInt(), 0xFF101318.toInt()),
            floatArrayOf(0f, 0.58f, 1f),
            Shader.TileMode.CLAMP,
        )
        bgPaint.shader = bgShader
    }

    private fun drawArena(canvas: Canvas, world: GameWorld) {
        val g = world.groundY
        fillPaint.color = 0xFF222A38.toInt()
        canvas.drawRect(0f, g, world.worldW, world.viewH + 40f, fillPaint)
        fillPaint.color = 0xFF323B4E.toInt()
        canvas.drawRect(0f, g, world.worldW, g + 8f, fillPaint)
        linePaint.color = 0x22F5C14A.toInt()
        linePaint.strokeWidth = 3f
        linePaint.pathEffect = dash
        var x = world.worldW * 0.15f
        while (x < world.worldW) {
            canvas.drawLine(x, world.viewH * 0.2f, x, g, linePaint)
            x += world.worldW * 0.18f
        }
        linePaint.pathEffect = null
    }

    private fun drawFlyerShadow(canvas: Canvas, e: Enemy, groundY: Float) {
        val s = e.body
        val dist = ((groundY - s.hipY) / (s.height * 3.2f)).coerceIn(0.15f, 1f)
        val rw = s.height * (0.34f - dist * 0.12f)
        val rh = rw * 0.28f
        fillPaint.color = 0x6610151C.toInt()
        fillPaint.alpha = ((1f - dist * 0.45f) * 110f).toInt()
        canvas.drawOval(s.hipX - rw, groundY - rh, s.hipX + rw, groundY + rh * 0.45f, fillPaint)
        fillPaint.alpha = 255
    }

    private fun drawStickman(canvas: Canvas, s: Stickman, enemy: Enemy? = null) {
        val dissolve = when {
            s.exploding || s.explode > 0f -> s.explode
            else -> enemy?.dissolve ?: 0f
        }
        val shattering = s.exploding || s.explode > 0f || enemy?.dissolving == true
        val alphaMul = if (shattering) {
            ((1f - dissolve) * (1f - dissolve)).coerceIn(0f, 1f)
        } else {
            1f
        }
        if (alphaMul <= 0.02f) return
        val a = (alphaMul * 255f).toInt()
        val color = if (s.flash > 0f && dissolve < 0.22f) 0xFFFFFFFF.toInt() else s.fillColor
        val h = s.height * (1f - dissolve * 0.4f)
        linePaint.color = color
        linePaint.alpha = a
        linePaint.strokeWidth = h * 0.055f * (1f - dissolve * 0.5f)
        val sk = s.skeleton
        val sx = if (s.explode > 0f || s.exploding) s.shatterX else enemy?.shatterX
        val sy = if (s.explode > 0f || s.exploding) s.shatterY else enemy?.shatterY
        bone(canvas, sk[JointId.HIP], sk[JointId.TORSO], sx, sy)
        bone(canvas, sk[JointId.TORSO], sk[JointId.HEAD], sx, sy)
        linePaint.strokeWidth = h * 0.042f * (1f - dissolve * 0.45f)
        bone(canvas, sk[JointId.TORSO], sk[JointId.L_SHOULDER], sx, sy)
        bone(canvas, sk[JointId.TORSO], sk[JointId.R_SHOULDER], sx, sy)
        bone(canvas, sk[JointId.L_SHOULDER], sk[JointId.L_ELBOW], sx, sy)
        bone(canvas, sk[JointId.L_ELBOW], sk[JointId.L_HAND], sx, sy)
        bone(canvas, sk[JointId.R_SHOULDER], sk[JointId.R_ELBOW], sx, sy)
        bone(canvas, sk[JointId.R_ELBOW], sk[JointId.R_HAND], sx, sy)
        linePaint.strokeWidth = h * 0.048f * (1f - dissolve * 0.45f)
        bone(canvas, sk[JointId.HIP], sk[JointId.L_HIP], sx, sy)
        bone(canvas, sk[JointId.HIP], sk[JointId.R_HIP], sx, sy)
        bone(canvas, sk[JointId.L_HIP], sk[JointId.L_KNEE], sx, sy)
        bone(canvas, sk[JointId.L_KNEE], sk[JointId.L_FOOT], sx, sy)
        bone(canvas, sk[JointId.R_HIP], sk[JointId.R_KNEE], sx, sy)
        bone(canvas, sk[JointId.R_KNEE], sk[JointId.R_FOOT], sx, sy)
        if (dissolve < 0.55f) drawTrail(canvas, s)
        fillPaint.color = color
        fillPaint.alpha = a
        val head = sk[JointId.HEAD]
        canvas.drawCircle(
            px(head, sx),
            py(head, sy),
            sk.headR * (1f - dissolve * 0.75f),
            fillPaint,
        )
        canvas.drawCircle(px(sk[JointId.L_HAND], sx), py(sk[JointId.L_HAND], sy), sk[JointId.L_HAND].radius, fillPaint)
        canvas.drawCircle(px(sk[JointId.R_HAND], sx), py(sk[JointId.R_HAND], sy), sk[JointId.R_HAND].radius, fillPaint)
        linePaint.alpha = 255
        fillPaint.alpha = 255
    }

    private fun px(j: Joint, shatter: FloatArray?): Float {
        return j.worldX + (if (shatter != null) shatter[j.id.ordinal] else 0f)
    }

    private fun py(j: Joint, shatter: FloatArray?): Float {
        return j.worldY + (if (shatter != null) shatter[j.id.ordinal] else 0f)
    }

    private fun bone(canvas: Canvas, a: Joint, b: Joint, sx: FloatArray? = null, sy: FloatArray? = null) {
        canvas.drawLine(px(a, sx), py(a, sy), px(b, sx), py(b, sy), linePaint)
    }

    private fun drawTrail(canvas: Canvas, s: Stickman) {
        if (s.trailCount < 2) return
        trailPaint.color = s.fillColor
        val n = s.trailCount
        var prevX = 0f
        var prevY = 0f
        for (i in 0 until n) {
            val idx = (s.trailHead - n + i + CombatConfig.TRAIL_POINTS) % CombatConfig.TRAIL_POINTS
            val x = s.trailX[idx]
            val y = s.trailY[idx]
            if (i > 0) {
                trailPaint.alpha = ((i.toFloat() / n) * 150f).toInt()
                trailPaint.strokeWidth = s.height * 0.04f * (i.toFloat() / n)
                canvas.drawLine(prevX, prevY, x, y, trailPaint)
            }
            prevX = x
            prevY = y
        }
        trailPaint.alpha = 255
    }

    private fun drawVfx(canvas: Canvas, world: GameWorld) {
        val vfx = world.vfx
        if (vfx.burstLife > 0f) {
            val t = (vfx.burstLife / 0.16f).coerceIn(0f, 1f)
            fillPaint.color = 0xAAFFF4C2.toInt()
            fillPaint.alpha = (t * 180f).toInt()
            canvas.drawCircle(vfx.burstX, vfx.burstY, 18f + (1f - t) * 42f, fillPaint)
            fillPaint.alpha = 255
        }
        if (vfx.shockLife > 0f) {
            val t = 1f - (vfx.shockLife / 0.22f).coerceIn(0f, 1f)
            linePaint.color = 0xFFFFE08A.toInt()
            linePaint.alpha = ((1f - t) * 200f).toInt()
            linePaint.strokeWidth = 6f * (1f - t)
            canvas.drawCircle(vfx.shockX, vfx.shockY, 12f + t * 90f, linePaint)
            linePaint.alpha = 255
        }
        linePaint.color = 0xEEFFE08A.toInt()
        for (s in vfx.slashes) {
            if (!s.active) continue
            linePaint.alpha = ((s.life / 0.09f) * 200f).toInt()
            linePaint.strokeWidth = 5f
            canvas.drawLine(s.x0, s.y0, s.x1, s.y1, linePaint)
        }
        linePaint.alpha = 255
        for (p in vfx.particles) {
            if (!p.active) continue
            val life = p.life / p.maxLife
            fillPaint.color = p.color
            fillPaint.alpha = (life * 220f).toInt()
            linePaint.color = p.color
            linePaint.alpha = (life * 200f).toInt()
            if (p.kind == 1) {
                val r = p.size * life
                canvas.drawLine(p.x - r, p.y, p.x + r, p.y, linePaint)
                canvas.drawLine(p.x, p.y - r, p.x, p.y + r, linePaint)
            } else if (p.kind == 2) {
                val r = p.size * life * 1.4f
                canvas.drawLine(p.x - r, p.y - r * 0.3f, p.x + r, p.y + r * 0.3f, linePaint)
            } else {
                canvas.drawCircle(p.x, p.y, p.size * life, fillPaint)
            }
        }
        fillPaint.alpha = 255
        linePaint.alpha = 255
    }

    private fun drawHud(canvas: Canvas, world: GameWorld) {
        val w = world.viewW
        val h = world.viewH
        val pad = w * 0.035f
        smallPaint.textSize = h * 0.028f
        textPaint.textSize = h * 0.055f
        drawBar(canvas, pad, pad * 0.85f, w * 0.28f, h * 0.038f, world.player.health / world.player.maxHealth, 0xFF7DCF9A.toInt())
        smallPaint.textAlign = Paint.Align.LEFT
        canvas.drawText("VOCÊ", pad, pad * 0.65f, smallPaint)
        drawPauseButton(canvas, world)
        smallPaint.textAlign = Paint.Align.RIGHT
        canvas.drawText("${world.fps.toInt()} FPS", world.pauseLeft - pad * 0.35f, pad * 0.7f, smallPaint)
        canvas.drawText(world.speed.label, world.pauseRight, world.pauseBottom + h * 0.028f, smallPaint)
        canvas.drawText(world.gestureLabel, w - pad, h - pad * 0.4f, smallPaint)
        smallPaint.textAlign = Paint.Align.LEFT
        canvas.drawText("${world.enemies.liveCount()} inimigos", pad, h - pad * 0.4f, smallPaint)
        if (world.playerCtrl.combo >= 2 && !world.paused) {
            textPaint.textAlign = Paint.Align.CENTER
            textPaint.alpha = 230
            canvas.drawText("COMBO x${world.playerCtrl.combo}", w * 0.5f, pad * 1.7f, textPaint)
            textPaint.alpha = 255
        }
        smallPaint.textAlign = Paint.Align.CENTER
        val hint = when {
            world.paused -> "Pausa"
            world.player.health <= 0f -> "KO — toque para reiniciar"
            else -> "Toque: jab/chute  ·  swipe ↑: salto nos voadores"
        }
        canvas.drawText(hint, w * 0.5f, h - pad * 0.4f, smallPaint)
        if (world.paused) drawPauseOverlay(canvas, world)
        else if (world.player.health <= 0f) drawKoOverlay(canvas, world)
    }

    private fun drawKoOverlay(canvas: Canvas, world: GameWorld) {
        val w = world.viewW
        val h = world.viewH
        fillPaint.color = 0x9912151C.toInt()
        canvas.drawRect(0f, 0f, w, h, fillPaint)
        drawPauseButton(canvas, world)
        textPaint.textAlign = Paint.Align.CENTER
        textPaint.alpha = 245
        textPaint.textSize = h * 0.09f
        canvas.drawText("KO", w * 0.5f, h * 0.36f, textPaint)
        smallPaint.textAlign = Paint.Align.CENTER
        smallPaint.color = 0xCCF4F0E6.toInt()
        smallPaint.textSize = h * 0.028f
        canvas.drawText("Inimigos destruídos", w * 0.5f, h * 0.46f, smallPaint)
        textPaint.textSize = h * 0.12f
        canvas.drawText("${world.playerCtrl.kills}", w * 0.5f, h * 0.60f, textPaint)
        smallPaint.textSize = h * 0.032f
        canvas.drawText("Toque para reiniciar", w * 0.5f, h * 0.70f, smallPaint)
        textPaint.alpha = 255
        fillPaint.alpha = 255
        smallPaint.color = 0xCCF4F0E6.toInt()
    }

    private fun drawPauseButton(canvas: Canvas, world: GameWorld) {
        val l = world.pauseLeft
        val t = world.pauseTop
        val r = world.pauseRight
        val b = world.pauseBottom
        if (r - l < 4f) return
        val rr = (b - t) * 0.22f
        fillPaint.color = 0x9912151C.toInt()
        canvas.drawRoundRect(l, t, r, b, rr, rr, fillPaint)
        linePaint.color = 0xEEF4F0E6.toInt()
        linePaint.strokeWidth = (b - t) * 0.06f
        linePaint.alpha = 220
        canvas.drawRoundRect(l, t, r, b, rr, rr, linePaint)
        fillPaint.color = 0xFFF4F0E6.toInt()
        val cx = (l + r) * 0.5f
        val cy = (t + b) * 0.5f
        val s = (b - t) * 0.22f
        if (world.paused) {
            val pathX0 = cx - s * 0.35f
            val pathY0 = cy - s * 0.85f
            val pathX1 = cx - s * 0.35f
            val pathY1 = cy + s * 0.85f
            val pathX2 = cx + s * 0.95f
            iconPath.reset()
            iconPath.moveTo(pathX0, pathY0)
            iconPath.lineTo(pathX2, cy)
            iconPath.lineTo(pathX1, pathY1)
            iconPath.close()
            canvas.drawPath(iconPath, fillPaint)
        } else {
            val bw = s * 0.38f
            val gap = s * 0.45f
            canvas.drawRoundRect(cx - gap - bw, cy - s, cx - gap, cy + s, bw * 0.4f, bw * 0.4f, fillPaint)
            canvas.drawRoundRect(cx + gap, cy - s, cx + gap + bw, cy + s, bw * 0.4f, bw * 0.4f, fillPaint)
        }
        linePaint.alpha = 255
        fillPaint.alpha = 255
    }

    private fun drawPauseOverlay(canvas: Canvas, world: GameWorld) {
        val w = world.viewW
        val h = world.viewH
        fillPaint.color = 0xB312151C.toInt()
        canvas.drawRect(0f, 0f, w, h, fillPaint)
        drawPauseButton(canvas, world)
        textPaint.textAlign = Paint.Align.CENTER
        textPaint.textSize = h * 0.09f
        textPaint.alpha = 240
        canvas.drawText("PAUSA", w * 0.5f, h * 0.42f, textPaint)
        smallPaint.textAlign = Paint.Align.CENTER
        smallPaint.textSize = h * 0.028f
        canvas.drawText("Velocidade", w * 0.5f, world.speedChipT - h * 0.018f, smallPaint)
        drawSpeedSelector(canvas, world)
        smallPaint.textSize = h * 0.032f
        canvas.drawText("Toque para continuar", w * 0.5f, world.speedChipB + h * 0.055f, smallPaint)
        textPaint.alpha = 255
        fillPaint.alpha = 255
    }

    private fun drawSpeedSelector(canvas: Canvas, world: GameWorld) {
        val speeds = GameSpeed.entries
        val hChip = world.speedChipB - world.speedChipT
        if (hChip < 4f) return
        val rr = hChip * 0.22f
        smallPaint.textAlign = Paint.Align.CENTER
        smallPaint.textSize = hChip * 0.38f
        for (i in speeds.indices) {
            val l = world.speedChipL[i]
            val r = world.speedChipR[i]
            val selected = world.speed == speeds[i]
            fillPaint.color = if (selected) 0xE6F5C14A.toInt() else 0x6612151C.toInt()
            canvas.drawRoundRect(l, world.speedChipT, r, world.speedChipB, rr, rr, fillPaint)
            linePaint.color = if (selected) 0xFFF4F0E6.toInt() else 0x88F4F0E6.toInt()
            linePaint.strokeWidth = hChip * 0.05f
            linePaint.alpha = if (selected) 230 else 140
            canvas.drawRoundRect(l, world.speedChipT, r, world.speedChipB, rr, rr, linePaint)
            smallPaint.color = if (selected) 0xFF12151C.toInt() else 0xCCF4F0E6.toInt()
            canvas.drawText(
                speeds[i].label,
                (l + r) * 0.5f,
                (world.speedChipT + world.speedChipB) * 0.5f + hChip * 0.14f,
                smallPaint,
            )
        }
        smallPaint.color = 0xCCF4F0E6.toInt()
        linePaint.alpha = 255
        fillPaint.alpha = 255
    }

    private fun drawBar(canvas: Canvas, x: Float, y: Float, width: Float, height: Float, ratio: Float, color: Int) {
        bar.set(x, y, x + width, y + height)
        fillPaint.color = 0x6612151C.toInt()
        canvas.drawRoundRect(bar, 7f, 7f, fillPaint)
        val r = Mathx.clamp(ratio, 0f, 1f)
        bar.set(x + 2f, y + 2f, x + 2f + (width - 4f) * r, y + height - 2f)
        fillPaint.color = color
        canvas.drawRoundRect(bar, 5f, 5f, fillPaint)
    }
}
