package com.edgard.labirinto.render

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import com.edgard.labirinto.game.Mood
import com.edgard.labirinto.model.Dir
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

class HeroDrawer {
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val path = Path()
    private val oval = RectF()

    fun draw(
        canvas: Canvas,
        cx: Float,
        feetY: Float,
        height: Float,
        facing: Dir,
        mood: Mood,
        moodT: Float,
        phase: Float,
        walking: Boolean,
    ) {
        val h = height.coerceAtLeast(24f)
        val sad = mood == Mood.SAD
        val walk = if (walking) 1f else if (sad) 0f else 0.12f
        val swing = sin(phase) * walk
        val bounce = when {
            walking -> abs(cos(phase)) * h * 0.055f
            sad -> sin(phase * 7f) * h * 0.028f
            else -> sin(phase * 0.45f) * h * 0.018f
        }
        val squash = when {
            walking -> 1f - 0.07f * abs(sin(phase * 2f))
            sad -> 1f - 0.05f * abs(sin(phase * 7f))
            else -> 1f
        }
        val jump = if (mood == Mood.HAPPY) {
            abs(sin((0.95f - moodT).coerceAtLeast(0f) * 16f)) * h * 0.16f
        } else {
            0f
        }
        val sag = if (sad) h * 0.07f else 0f
        val shake = if (sad) sin(phase * 16f) * h * 0.018f else 0f
        val ground = feetY + sag - jump
        val lean = if (sad) {
            6f + sin(phase * 5f) * 7f
        } else {
            when (facing) {
                Dir.E -> 8f
                Dir.W -> -8f
                Dir.N -> -3f
                Dir.S -> 3f
            } * walk + swing * 4f
        }

        fill.color = 0x66000000
        oval.set(cx - h * 0.22f, ground - h * 0.04f, cx + h * 0.22f, ground + h * 0.05f)
        canvas.drawOval(oval, fill)

        canvas.save()
        canvas.translate(cx + shake, ground - bounce)
        canvas.scale(if (facing == Dir.W && !sad) -1f else 1f, squash)
        canvas.rotate(lean)

        val hipY = -h * 0.30f
        val shoulderY = -h * (if (sad) 0.48f else 0.52f)
        val headY = -h * (if (sad) 0.66f else 0.72f)

        val leftArm = if (sad) 2.45f + 0.14f * sin(phase * 8f) else -swing * 0.95f
        val rightArm = if (sad) 2.25f + 0.14f * sin(phase * 8f + 1.2f) else swing * 0.95f
        val leftLeg = if (sad) 0.18f else swing
        val rightLeg = if (sad) -0.12f else -swing

        drawLeg(canvas, h, -h * 0.07f, hipY, leftLeg, true)
        drawLeg(canvas, h, h * 0.07f, hipY, rightLeg, false)
        drawBackpack(canvas, h, shoulderY)
        drawTorso(canvas, h, hipY, shoulderY, mood)
        drawArm(canvas, h, -h * 0.16f, shoulderY, leftArm, true)
        drawArm(canvas, h, h * 0.16f, shoulderY, rightArm, false)
        drawHead(canvas, h, headY, facing, mood, phase, walking)
        if (walking) drawDust(canvas, h, swing, phase)

        canvas.restore()

        if (mood == Mood.HAPPY) {
            val spark = 1f - moodT.coerceIn(0f, 1f)
            fill.color = 0xFFF2C14A.toInt()
            for (i in 0 until 6) {
                val a = i * 1.047f + spark * 8f
                val r = h * (0.42f + 0.10f * sin(spark * 9f + i))
                canvas.drawCircle(
                    cx + cos(a) * r,
                    ground - h * 0.72f - jump + sin(a) * r * 0.55f,
                    h * 0.035f,
                    fill,
                )
            }
        }
        if (sad) drawSadFx(canvas, cx, ground, h, phase, moodT)
    }

    private fun drawLeg(canvas: Canvas, h: Float, hipX: Float, hipY: Float, swing: Float, left: Boolean) {
        canvas.save()
        canvas.translate(hipX, hipY)
        canvas.rotate(swing * 32f)
        stroke.color = 0xFF4A3018.toInt()
        stroke.strokeWidth = h * 0.075f
        canvas.drawLine(0f, 0f, 0f, h * 0.16f, stroke)
        canvas.translate(0f, h * 0.16f)
        canvas.rotate(abs(swing) * 14f * if (left) 1f else -1f)
        canvas.drawLine(0f, 0f, 0f, h * 0.13f, stroke)
        fill.color = 0xFF3A2412.toInt()
        oval.set(-h * 0.07f, h * 0.10f, h * 0.11f, h * 0.18f)
        canvas.drawOval(oval, fill)
        fill.color = 0xFF6B4A28.toInt()
        canvas.drawCircle(h * 0.04f, h * 0.14f, h * 0.035f, fill)
        canvas.restore()
    }

    private fun drawArm(canvas: Canvas, h: Float, sx: Float, sy: Float, swing: Float, left: Boolean) {
        canvas.save()
        canvas.translate(sx, sy)
        canvas.rotate(swing * 38f + if (left) 8f else -8f)
        stroke.color = 0xFFE8B889.toInt()
        stroke.strokeWidth = h * 0.055f
        canvas.drawLine(0f, 0f, 0f, h * 0.20f, stroke)
        fill.color = 0xFFF0C49A.toInt()
        canvas.drawCircle(0f, h * 0.22f, h * 0.038f, fill)
        if (!left) {
            fill.color = 0xFF8A6234.toInt()
            canvas.drawRoundRect(-h * 0.02f, h * 0.10f, h * 0.02f, h * 0.28f, 4f, 4f, fill)
            fill.color = 0xFFC4A15A.toInt()
            canvas.drawCircle(0f, h * 0.08f, h * 0.028f, fill)
        }
        canvas.restore()
    }

    private fun drawBackpack(canvas: Canvas, h: Float, shoulderY: Float) {
        fill.color = 0xFF6B3A1C.toInt()
        canvas.drawRoundRect(-h * 0.16f, shoulderY - h * 0.02f, h * 0.16f, shoulderY + h * 0.18f, 10f, 10f, fill)
        fill.color = 0xFF8A5230.toInt()
        canvas.drawRoundRect(-h * 0.12f, shoulderY + h * 0.02f, h * 0.12f, shoulderY + h * 0.14f, 8f, 8f, fill)
        fill.color = 0xFFE6C97A.toInt()
        canvas.drawCircle(0f, shoulderY + h * 0.08f, h * 0.03f, fill)
    }

    private fun drawTorso(canvas: Canvas, h: Float, hipY: Float, shoulderY: Float, mood: Mood) {
        fill.color = 0xFF2F6B3A.toInt()
        canvas.drawRoundRect(-h * 0.145f, shoulderY, h * 0.145f, hipY + h * 0.04f, 12f, 12f, fill)
        fill.color = 0xFF3F8A48.toInt()
        canvas.drawRoundRect(-h * 0.10f, shoulderY + h * 0.02f, h * 0.04f, hipY, 8f, 8f, fill)
        fill.color = 0xFF6B4A28.toInt()
        canvas.drawRoundRect(-h * 0.15f, hipY - h * 0.02f, h * 0.15f, hipY + h * 0.035f, 6f, 6f, fill)
        fill.color = 0xFFC4A15A.toInt()
        canvas.drawCircle(0f, hipY + h * 0.008f, h * 0.028f, fill)
        fill.color = 0xFF8A6234.toInt()
        canvas.drawRoundRect(-h * 0.13f, hipY + h * 0.02f, -h * 0.01f, hipY + h * 0.12f, 8f, 8f, fill)
        canvas.drawRoundRect(h * 0.01f, hipY + h * 0.02f, h * 0.13f, hipY + h * 0.12f, 8f, 8f, fill)
        if (mood == Mood.SAD) {
            fill.color = 0xFF245A32.toInt()
            canvas.drawRoundRect(-h * 0.12f, shoulderY + h * 0.06f, h * 0.12f, hipY, 8f, 8f, fill)
        }
        fill.color = 0xFF58B85C.toInt()
        path.reset()
        path.moveTo(-h * 0.02f, shoulderY - h * 0.02f)
        path.quadTo(h * 0.16f, shoulderY + h * 0.08f, h * 0.06f, hipY + h * 0.02f)
        path.quadTo(h * 0.12f, shoulderY + h * 0.04f, 0f, shoulderY)
        path.close()
        canvas.drawPath(path, fill)
    }

    private fun drawHead(
        canvas: Canvas,
        h: Float,
        headY: Float,
        facing: Dir,
        mood: Mood,
        phase: Float,
        walking: Boolean,
    ) {
        val look = when (facing) {
            Dir.E -> h * 0.03f
            Dir.W -> -h * 0.01f
            Dir.N -> 0f
            Dir.S -> 0f
        }
        val lookY = if (facing == Dir.N) -h * 0.02f else if (facing == Dir.S) h * 0.01f else 0f
        val nod = when {
            walking -> sin(phase) * h * 0.012f
            mood == Mood.SAD -> h * 0.04f + sin(phase * 8f) * h * 0.018f
            else -> 0f
        }

        fill.color = 0xFF5A3A22.toInt()
        canvas.drawCircle(-h * 0.12f, headY + h * 0.02f + nod, h * 0.07f, fill)
        canvas.drawCircle(h * 0.12f, headY + h * 0.02f + nod, h * 0.07f, fill)

        fill.color = 0xFFF3C99A.toInt()
        canvas.drawCircle(0f, headY + nod, h * 0.155f, fill)

        fill.color = 0xFF4A2E18.toInt()
        path.reset()
        path.moveTo(-h * 0.15f, headY - h * 0.04f + nod)
        path.quadTo(0f, headY - h * 0.20f + nod, h * 0.15f, headY - h * 0.04f + nod)
        path.quadTo(0f, headY - h * 0.08f + nod, -h * 0.15f, headY - h * 0.04f + nod)
        path.close()
        canvas.drawPath(path, fill)
        canvas.drawCircle(-h * 0.02f, headY - h * 0.16f + nod + sin(phase * 2f) * h * 0.01f, h * 0.055f, fill)

        fill.color = 0xFF2F6B3A.toInt()
        oval.set(-h * 0.17f, headY - h * 0.20f + nod, h * 0.17f, headY - h * 0.02f + nod)
        canvas.drawOval(oval, fill)
        fill.color = 0xFF3F8A48.toInt()
        oval.set(-h * 0.13f, headY - h * 0.18f + nod, h * 0.13f, headY - h * 0.06f + nod)
        canvas.drawOval(oval, fill)
        fill.color = 0xFF58B85C.toInt()
        canvas.drawCircle(h * 0.10f, headY - h * 0.16f + nod, h * 0.045f, fill)
        fill.color = 0xFFE6C97A.toInt()
        canvas.drawCircle(h * 0.11f, headY - h * 0.06f + nod, h * 0.025f, fill)

        fill.color = 0xFFFFB7C8.toInt()
        canvas.drawCircle(-h * 0.10f, headY + h * 0.04f + nod, h * 0.028f, fill)
        canvas.drawCircle(h * 0.10f, headY + h * 0.04f + nod, h * 0.028f, fill)

        when (mood) {
            Mood.SAD -> {
                fill.color = 0xFFFFFFFF.toInt()
                oval.set(-h * 0.09f + look, headY - h * 0.01f + nod + lookY, -h * 0.01f + look, headY + h * 0.06f + nod + lookY)
                canvas.drawOval(oval, fill)
                oval.set(h * 0.01f + look, headY - h * 0.01f + nod + lookY, h * 0.09f + look, headY + h * 0.06f + nod + lookY)
                canvas.drawOval(oval, fill)
                fill.color = 0xFF2A1A10.toInt()
                canvas.drawCircle(-h * 0.045f + look, headY + h * 0.032f + nod + lookY, h * 0.016f, fill)
                canvas.drawCircle(h * 0.055f + look, headY + h * 0.032f + nod + lookY, h * 0.016f, fill)
                stroke.color = 0xFF3A2A18.toInt()
                stroke.strokeWidth = h * 0.02f
                canvas.drawArc(-h * 0.06f, headY + h * 0.05f + nod, h * 0.06f, headY + h * 0.13f + nod, 200f, 140f, false, stroke)
                fill.color = 0xFF6EC8E8.toInt()
                canvas.drawCircle(h * 0.09f, headY + h * 0.08f + nod, h * 0.028f, fill)
                canvas.drawCircle(-h * 0.08f, headY + h * 0.09f + nod, h * 0.022f, fill)
                stroke.color = 0xFF4A90C8.toInt()
                stroke.strokeWidth = h * 0.012f
                canvas.drawLine(-h * 0.07f, headY - h * 0.02f + nod, -h * 0.13f, headY + h * 0.01f + nod, stroke)
                canvas.drawLine(h * 0.07f, headY - h * 0.02f + nod, h * 0.13f, headY + h * 0.01f + nod, stroke)
            }
            Mood.HAPPY -> {
                fill.color = 0xFFFFFFFF.toInt()
                canvas.drawCircle(-h * 0.05f + look, headY + nod + lookY, h * 0.038f, fill)
                canvas.drawCircle(h * 0.05f + look, headY + nod + lookY, h * 0.038f, fill)
                fill.color = 0xFF2A1A10.toInt()
                canvas.drawCircle(-h * 0.04f + look, headY + nod + lookY, h * 0.018f, fill)
                canvas.drawCircle(h * 0.06f + look, headY + nod + lookY, h * 0.018f, fill)
                stroke.color = 0xFF3A2A18.toInt()
                stroke.strokeWidth = h * 0.018f
                canvas.drawArc(-h * 0.06f, headY + h * 0.02f + nod, h * 0.06f, headY + h * 0.11f + nod, 15f, 150f, false, stroke)
            }
            Mood.IDLE -> {
                fill.color = 0xFFFFFFFF.toInt()
                canvas.drawCircle(-h * 0.05f + look, headY + nod + lookY, h * 0.036f, fill)
                canvas.drawCircle(h * 0.05f + look, headY + nod + lookY, h * 0.036f, fill)
                fill.color = 0xFF2A1A10.toInt()
                canvas.drawCircle(-h * 0.04f + look, headY + h * 0.004f + nod + lookY, h * 0.016f, fill)
                canvas.drawCircle(h * 0.06f + look, headY + h * 0.004f + nod + lookY, h * 0.016f, fill)
                fill.color = 0xFFFFFFFF.toInt()
                canvas.drawCircle(-h * 0.048f + look, headY - h * 0.006f + nod + lookY, h * 0.007f, fill)
                canvas.drawCircle(h * 0.052f + look, headY - h * 0.006f + nod + lookY, h * 0.007f, fill)
                stroke.color = 0xFF3A2A18.toInt()
                stroke.strokeWidth = h * 0.014f
                canvas.drawArc(-h * 0.04f, headY + h * 0.03f + nod, h * 0.04f, headY + h * 0.09f + nod, 20f, 140f, false, stroke)
            }
        }

        fill.color = 0xFFE8B889.toInt()
        canvas.drawCircle(h * 0.01f, headY + h * 0.04f + nod, h * 0.018f, fill)
    }

    private fun drawSadFx(canvas: Canvas, cx: Float, ground: Float, h: Float, phase: Float, moodT: Float) {
        val cloudY = ground - h * 0.98f
        fill.color = 0xAA8AA0B8.toInt()
        canvas.drawCircle(cx - h * 0.08f, cloudY, h * 0.10f, fill)
        canvas.drawCircle(cx + h * 0.07f, cloudY + h * 0.01f, h * 0.09f, fill)
        canvas.drawCircle(cx, cloudY - h * 0.04f, h * 0.11f, fill)
        fill.color = 0xCC6EC8E8.toInt()
        for (i in 0 until 6) {
            val t = ((phase * 0.28f + i * 0.17f) % 1f)
            val x = cx + (i - 2.5f) * h * 0.07f + sin(phase + i) * h * 0.02f
            val y = ground - h * 0.62f + t * h * 0.55f
            val drop = h * (0.028f + 0.01f * (i % 3))
            path.reset()
            path.moveTo(x, y - drop)
            path.quadTo(x + drop * 0.7f, y + drop * 0.2f, x, y + drop)
            path.quadTo(x - drop * 0.7f, y + drop * 0.2f, x, y - drop)
            path.close()
            val a = ((1f - t) * moodT.coerceIn(0.25f, 1f) * 220).toInt().coerceIn(40, 220)
            fill.color = (a shl 24) or 0x006EC8E8
            canvas.drawPath(path, fill)
        }
    }

    private fun drawDust(canvas: Canvas, h: Float, swing: Float, phase: Float) {
        val puff = abs(sin(phase))
        fill.color = 0x55E8D9A8.toInt()
        canvas.drawCircle(-h * 0.16f - swing * h * 0.08f, h * 0.02f, h * 0.045f * (0.3f + puff), fill)
        canvas.drawCircle(h * 0.14f + swing * h * 0.08f, h * 0.03f, h * 0.032f * (0.2f + puff), fill)
    }
}
