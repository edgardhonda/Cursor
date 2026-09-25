package com.edgard.dentista.render

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import com.edgard.dentista.game.Cavity
import com.edgard.dentista.game.GameWorld
import com.edgard.dentista.game.PlayState
import com.edgard.dentista.game.Tooth
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

class MouthView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {
    var world: GameWorld? = null
    var onLost: (() -> Unit)? = null

    init {
        isClickable = true
        isFocusable = true
    }

    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val ink = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xFFF4F0E6.toInt()
        textAlign = Paint.Align.CENTER
        typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
    }
    private val tmp = Path()
    private val rect = RectF()
    private var lastNs = 0L
    private var originX = 0f
    private var originY = 0f
    private var boardW = 0f
    private var boardH = 0f
    private var lastState: PlayState? = null
    private val clock = Handler(Looper.getMainLooper())
    private val beat = object : Runnable {
        override fun run() {
            if (isAttachedToWindow) clock.postDelayed(this, 16)
            val w = world ?: return
            if (w.state == PlayState.PLAYING) postInvalidateOnAnimation()
        }
    }

    fun kick() {
        lastNs = 0L
        clock.removeCallbacks(beat)
        clock.post(beat)
        postInvalidateOnAnimation()
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        kick()
    }

    override fun onDetachedFromWindow() {
        clock.removeCallbacks(beat)
        super.onDetachedFromWindow()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        layoutBoard()
        lastNs = 0L
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = world ?: return
        canvas.drawColor(0xFF2A0A14.toInt())
        layoutBoard()
        if (w.state == PlayState.PLAYING) tick()
        drawMouth(canvas)
        for (tooth in w.teeth) drawTooth(canvas, tooth)
            val focused = w.focusedCavity()
            for (bug in w.cavities) drawCavity(canvas, bug, focused != null && focused.id == bug.id)
        if (w.brushOn || w.brushShow > 0f) drawBrush(canvas, w)
        for (p in w.popups) {
            val a = (p.life / 0.9f).coerceIn(0f, 1f)
            ink.alpha = (a * 255).toInt()
            ink.textSize = min(boardW, boardH) * 0.055f
            canvas.drawText(p.text, sx(p.nx), sy(p.ny), ink)
        }
        ink.alpha = 255
        drawHud(canvas, w)
        if (w.state != lastState) {
            lastState = w.state
            if (w.state == PlayState.LOST) post { onLost?.invoke() }
        }
        if (w.state == PlayState.PLAYING) postInvalidateOnAnimation()
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val w = world ?: return super.onTouchEvent(event)
        if (boardW < 1f || boardH < 1f) layoutBoard()
        if (boardW < 1f || boardH < 1f) return true
        parent?.requestDisallowInterceptTouchEvent(true)
        val nx = normX(event.x)
        val ny = normY(event.y)
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> w.pointerDown(nx, ny)
            MotionEvent.ACTION_MOVE -> {
                for (i in 0 until event.historySize) {
                    w.pointerMove(normX(event.getHistoricalX(i)), normY(event.getHistoricalY(i)))
                }
                w.pointerMove(nx, ny)
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> w.pointerUp(nx, ny)
        }
        invalidate()
        return true
    }

    private fun normX(x: Float) = ((x - originX) / boardW).coerceIn(0f, 1f)
    private fun normY(y: Float) = ((y - originY) / boardH).coerceIn(0f, 1f)

    private fun tick() {
        val w = world ?: return
        val now = System.nanoTime()
        val dt = if (lastNs == 0L) 0.016f else ((now - lastNs) / 1_000_000_000f).coerceIn(0.001f, 0.05f)
        lastNs = now
        w.update(dt)
    }

    private fun layoutBoard() {
        val pad = min(width, height) * 0.04f
        boardW = width - pad * 2
        boardH = height - pad * 2
        originX = pad
        originY = pad
    }

    private fun sx(n: Float) = originX + n * boardW
    private fun sy(n: Float) = originY + n * boardH

    private fun drawMouth(canvas: Canvas) {
        fill.color = 0xFF6B1A28.toInt()
        rect.set(sx(0.04f), sy(0.08f), sx(0.96f), sy(0.92f))
        canvas.drawOval(rect, fill)
        fill.color = 0xFFC4455A.toInt()
        stroke.color = 0xFF8A2036.toInt()
        stroke.strokeWidth = min(boardW, boardH) * 0.055f
        canvas.drawOval(rect, stroke)
        fill.color = 0xFFE06A7A.toInt()
        rect.set(sx(0.12f), sy(0.14f), sx(0.88f), sy(0.34f))
        canvas.drawOval(rect, fill)
        rect.set(sx(0.12f), sy(0.66f), sx(0.88f), sy(0.86f))
        canvas.drawOval(rect, fill)
        fill.color = 0xFFD45A78.toInt()
        rect.set(sx(0.28f), sy(0.42f), sx(0.72f), sy(0.78f))
        canvas.drawOval(rect, fill)
        fill.color = 0xFFB83E5C.toInt()
        canvas.drawCircle(sx(0.50f), sy(0.58f), min(boardW, boardH) * 0.045f, fill)
    }

    private fun drawTooth(canvas: Canvas, tooth: Tooth) {
        val cx = sx(tooth.nx)
        val cy = sy(tooth.ny)
        val hw = tooth.nw * boardW * 0.5f
        val hh = tooth.nh * boardH * 0.5f
        val d = tooth.damage
        val enamel = when {
            tooth.destroyed -> 0xFF4A3028.toInt()
            d >= 8 -> 0xFFC4A070.toInt()
            d >= 5 -> 0xFFE8D4A0.toInt()
            d >= 3 -> 0xFFF3E6C4.toInt()
            else -> 0xFFFFF6E8.toInt()
        }
        fill.color = enamel
        val top = if (tooth.upper) cy - hh * 0.18f else cy - hh
        val bot = if (tooth.upper) cy + hh else cy + hh * 0.18f
        val shrink = d * 0.014f * min(hw, hh)
        val left = cx - hw + shrink
        val right = cx + hw - shrink
        val gum = if (tooth.upper) top + shrink else bot - shrink
        val bite = if (tooth.upper) bot - shrink * 0.35f else top + shrink * 0.35f
        tmp.reset()
        if (tooth.upper) {
            tmp.moveTo(left, gum)
            tmp.lineTo(right, gum)
            tmp.quadTo(right + hw * 0.08f, (gum + bite) * 0.5f, right - hw * 0.18f, bite)
            tmp.quadTo(cx, bite + hh * 0.10f, left + hw * 0.18f, bite)
            tmp.quadTo(left - hw * 0.08f, (gum + bite) * 0.5f, left, gum)
        } else {
            tmp.moveTo(left, gum)
            tmp.lineTo(right, gum)
            tmp.quadTo(right + hw * 0.08f, (gum + bite) * 0.5f, right - hw * 0.18f, bite)
            tmp.quadTo(cx, bite - hh * 0.10f, left + hw * 0.18f, bite)
            tmp.quadTo(left - hw * 0.08f, (gum + bite) * 0.5f, left, gum)
        }
        tmp.close()
        canvas.drawPath(tmp, fill)
        if (!tooth.destroyed) {
            fill.color = 0x66FFFFFF
            canvas.drawOval(
                cx - hw * 0.42f,
                (if (tooth.upper) gum else bite) + hh * 0.10f,
                cx - hw * 0.05f,
                (if (tooth.upper) gum else bite) + hh * 0.38f,
                fill,
            )
        }
        if (d > 0 && !tooth.destroyed) {
            fill.color = 0xFF6B3A22.toInt()
            val holes = min(d, 8)
            val seed = tooth.id * 17 + 3
            for (i in 0 until holes) {
                val ox = ((seed * (i + 3)) % 17 - 8) / 18f * hw
                val oy = ((seed * (i + 9)) % 15 - 7) / 16f * hh * 0.45f
                val r = hw * (0.10f + i * 0.018f)
                canvas.drawCircle(cx + ox, cy + oy, r, fill)
            }
        }
        if (tooth.destroyed) {
            fill.color = 0xFF2A1410.toInt()
            canvas.drawOval(cx - hw * 0.35f, cy - hh * 0.12f, cx + hw * 0.35f, cy + hh * 0.22f, fill)
        }
    }

    private fun drawCavity(canvas: Canvas, bug: Cavity, focused: Boolean) {
        val cx = sx(bug.nx)
        val cy = sy(bug.ny)
        val s = min(boardW, boardH) * 0.055f
        val wob = 1f + 0.12f * sin(bug.t * 7f)
        if (focused) {
            stroke.style = Paint.Style.STROKE
            stroke.color = 0xFFE8C15A.toInt()
            stroke.strokeWidth = s * 0.22f
            canvas.drawCircle(cx, cy, s * 1.18f, stroke)
        }
        tmp.reset()
        val n = 8
        for (i in 0 until n) {
            val a = i / n.toFloat() * (Math.PI * 2).toFloat() + bug.t * 0.8f
            val rad = s * wob * (0.72f + 0.28f * sin(a * 3f + bug.seed))
            val x = cx + cos(a) * rad
            val y = cy + sin(a) * rad * 0.88f
            if (i == 0) tmp.moveTo(x, y) else tmp.lineTo(x, y)
        }
        tmp.close()
        fill.color = if (focused) 0xDD9BE05A.toInt() else 0xCC7BCB4A.toInt()
        canvas.drawPath(tmp, fill)
        fill.color = 0xAA3D8A2A.toInt()
        canvas.drawCircle(cx, cy + s * 0.08f, s * 0.32f, fill)
        fill.color = 0xFFFFFFFF.toInt()
        canvas.drawCircle(cx - s * 0.22f, cy - s * 0.18f, s * 0.16f, fill)
        canvas.drawCircle(cx + s * 0.22f, cy - s * 0.18f, s * 0.16f, fill)
        fill.color = 0xFF1A1A12.toInt()
        canvas.drawCircle(cx - s * 0.18f, cy - s * 0.16f, s * 0.07f, fill)
        canvas.drawCircle(cx + s * 0.26f, cy - s * 0.16f, s * 0.07f, fill)
        fill.color = 0xAA8FD95A.toInt()
        canvas.drawCircle(cx + s * 0.08f, cy + s * 0.55f, s * 0.12f, fill)
        canvas.drawCircle(cx - s * 0.06f, cy + s * 0.72f, s * 0.08f, fill)
        if (focused) {
            ink.textAlign = Paint.Align.CENTER
            ink.textSize = s * 0.72f
            ink.color = 0xFFE8C15A.toInt()
            canvas.drawText("${bug.rubs}/5", cx, cy - s * 1.45f, ink)
            ink.color = 0xFFF4F0E6.toInt()
        }
    }

    private fun drawBrush(canvas: Canvas, w: GameWorld) {
        val px = sx(w.brushNx)
        val py = sy(w.brushNy)
        val s = min(boardW, boardH) * 0.09f
        canvas.save()
        canvas.translate(px, py)
        canvas.rotate(Math.toDegrees(w.brushAngle.toDouble()).toFloat() + 90f)
        fill.color = 0xFF3A86FF.toInt()
        canvas.drawRoundRect(-s * 0.18f, -s * 0.15f, s * 0.18f, s * 1.15f, 8f, 8f, fill)
        fill.color = 0xFFF4F0E6.toInt()
        canvas.drawRoundRect(-s * 0.32f, -s * 0.85f, s * 0.32f, s * 0.05f, 10f, 10f, fill)
        fill.color = 0xFFE8C15A.toInt()
        val bristle = s * 0.22f
        for (i in 0 until 5) {
            val x = -s * 0.22f + i * s * 0.11f
            canvas.drawRect(x, -s * 0.85f - bristle, x + s * 0.07f, -s * 0.80f, fill)
        }
        canvas.restore()
        ink.textSize = min(boardW, boardH) * 0.04f
        ink.color = 0xFFF4F0E6.toInt()
        canvas.drawText("${w.strokes}/5", px, py - s * 1.15f, ink)
    }

    private fun drawHud(canvas: Canvas, w: GameWorld) {
        ink.textAlign = Paint.Align.LEFT
        ink.textSize = min(boardW, boardH) * 0.042f
        ink.color = 0xFFF4F0E6.toInt()
        canvas.drawText("Limpas  ${w.cleaned}", originX + 8f, originY + ink.textSize, ink)
        ink.textAlign = Paint.Align.RIGHT
        canvas.drawText("Dentes  ${w.livingCount()}", originX + boardW - 8f, originY + ink.textSize, ink)
        ink.textAlign = Paint.Align.CENTER
    }
}
