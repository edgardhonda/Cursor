package com.edgard.labirinto.render

import android.content.Context
import android.graphics.Canvas
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import com.edgard.labirinto.R
import com.edgard.labirinto.game.GameWorld
import com.edgard.labirinto.game.PlayState
import com.edgard.labirinto.model.CellKind
import com.edgard.labirinto.model.PathShape
import kotlin.math.abs
import kotlin.math.min
import kotlin.math.sin

class MazeView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {
    var world: GameWorld? = null
    var onWin: (() -> Unit)? = null
    var onState: ((PlayState) -> Unit)? = null

    private val grass = Paint(Paint.ANTI_ALIAS_FLAG)
    private val grid = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = 0x33224422
        strokeWidth = 1.5f
    }
    private val pathFill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val pathEdge = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }
    private val wood = Paint(Paint.ANTI_ALIAS_FLAG)
    private val leaf = Paint(Paint.ANTI_ALIAS_FLAG)
    private val ink = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xFFF4E8C8.toInt()
        textAlign = Paint.Align.CENTER
        typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
    }
    private val hero = HeroDrawer()
    private val dash = DashPathEffect(floatArrayOf(10f, 8f), 0f)
    private val tmp = Path()
    private val rect = RectF()
    private val optionRects = Array(3) { RectF() }
    private var originX = 0f
    private var originY = 0f
    private var cell = 40f
    private var landscape = false
    private var panelLeft = 0f
    private var panelTop = 0f
    private var panelWidth = 0f
    private var lastNs = 0L
    private var downX = 0f
    private var downY = 0f
    private var lastState: PlayState? = null

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        lastNs = 0L
        postInvalidateOnAnimation()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        lastNs = 0L
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = world ?: return
        tick()
        canvas.drawColor(0xFF16321F.toInt())
        layoutBoard(w)
        val maze = w.maze
        val n = maze.size
        for (r in 0 until n) {
            for (c in 0 until n) {
                drawCell(canvas, w, r, c)
            }
        }
        drawWalker(canvas, w)
        if (w.state == PlayState.FILLING && !w.isSad()) {
            drawFillPanel(canvas, w)
        } else {
            drawHeroStage(canvas, w)
        }
        if (w.state != lastState) {
            lastState = w.state
            val state = w.state
            post {
                onState?.invoke(state)
                if (state == PlayState.WON) onWin?.invoke()
            }
        }
        if (w.state == PlayState.READY) {
            drawTapHint(canvas, w)
        } else if (w.state == PlayState.LOADING) {
            drawLoadingHint(canvas, w)
        }
        if (
            w.state == PlayState.READY ||
            w.state == PlayState.LOADING ||
            w.state == PlayState.WALKING ||
            w.state == PlayState.FILLING ||
            w.state == PlayState.CELEBRATING
        ) {
            postInvalidateOnAnimation()
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val w = world ?: return false
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downX = event.x
                downY = event.y
            }
            MotionEvent.ACTION_UP -> {
                if (w.state == PlayState.READY) {
                    w.beginWalk()
                    invalidate()
                    return true
                }
                if (w.state == PlayState.FILLING) {
                    if (w.isSad()) return true
                    for (i in w.fillOptions.indices) {
                        if (optionRects[i].contains(event.x, event.y)) {
                            w.chooseFill(i)
                            invalidate()
                            return true
                        }
                    }
                }
            }
        }
        return true
    }

    private fun layoutBoard(w: GameWorld) {
        val n = w.maze.size
        landscape = width > height
        val pad = min(width, height) * 0.035f
        if (landscape) {
            cell = min((width * 0.56f) / n, (height - pad * 2) / n)
            originX = pad
            originY = (height - cell * n) * 0.5f
            panelLeft = originX + cell * n + pad
            panelTop = pad
            panelWidth = (width - panelLeft - pad).coerceAtLeast(cell * 2.4f)
        } else {
            val stage = height * 0.28f
            cell = min((width - pad * 2) / n, (height - pad * 2 - stage) / n)
            originX = (width - cell * n) * 0.5f
            originY = pad * 0.8f
            panelLeft = 0f
            panelTop = originY + cell * n + 10f
            panelWidth = width.toFloat()
        }
    }

    private fun tick() {
        val w = world ?: return
        val now = System.nanoTime()
        val dt = if (lastNs == 0L) 0.016f else ((now - lastNs) / 1_000_000_000f).coerceIn(0.001f, 0.05f)
        lastNs = now
        w.update(dt)
    }

    private fun drawCell(canvas: Canvas, w: GameWorld, r: Int, c: Int) {
        val x = originX + c * cell
        val y = originY + r * cell
        val cellData = w.maze.cell(r, c)
        val shade = ((cellData.treeSeed ushr 8) and 15) / 80f
        grass.color = rgb(0.18f + shade, 0.42f + shade * 0.3f, 0.16f)
        canvas.drawRect(x, y, x + cell, y + cell, grass)
        canvas.drawRect(x, y, x + cell, y + cell, grid)
        if (cellData.isOpenGap()) {
            drawGap(canvas, x, y, w.walker.bob)
        } else if (cellData.isWalkable()) {
            drawPath(canvas, x, y, cell, cellData.n, cellData.e, cellData.s, cellData.w)
        }
        when (cellData.kind) {
            CellKind.TREE -> drawForest(canvas, x, y, cellData.treeSeed, cellData.stump)
            CellKind.ENTRANCE -> drawSign(canvas, x, y, "ENTRADA")
            CellKind.EXIT -> drawSign(canvas, x, y, "SAÍDA")
            CellKind.PATH, CellKind.BLOCKED -> {}
        }
    }

    private fun drawGap(canvas: Canvas, x: Float, y: Float, pulse: Float) {
        val inset = cell * 0.14f
        val glow = 0.04f + 0.03f * (0.5f + 0.5f * sin(pulse * 1.6f))
        grass.color = rgb(0.22f + glow, 0.16f, 0.08f)
        canvas.drawRoundRect(x + inset, y + inset, x + cell - inset, y + cell - inset, 10f, 10f, grass)
        pathEdge.strokeCap = Paint.Cap.SQUARE
        pathEdge.strokeWidth = 4f
        pathEdge.color = 0xCCE6C97A.toInt()
        pathEdge.pathEffect = dash
        canvas.drawRoundRect(x + inset, y + inset, x + cell - inset, y + cell - inset, 10f, 10f, pathEdge)
        pathEdge.pathEffect = null
        pathEdge.strokeCap = Paint.Cap.ROUND
        ink.textSize = cell * 0.38f
        ink.color = 0xAAF4E8C8.toInt()
        canvas.drawText("?", x + cell * 0.5f, y + cell * 0.62f, ink)
        ink.color = 0xFFF4E8C8.toInt()
    }

    private fun drawPath(
        canvas: Canvas,
        x: Float,
        y: Float,
        size: Float,
        n: Boolean,
        e: Boolean,
        s: Boolean,
        w: Boolean,
        sand: Int = 0xFFD7B56A.toInt(),
        highlight: Int = 0xFFE6C97A.toInt(),
    ) {
        val cx = x + size * 0.5f
        val cy = y + size * 0.5f
        val t = size * 0.34f
        pathFill.color = sand
        canvas.drawCircle(cx, cy, t * 0.52f, pathFill)
        pathEdge.strokeWidth = t
        pathEdge.color = sand
        if (n) canvas.drawLine(cx, cy, cx, y, pathEdge)
        if (s) canvas.drawLine(cx, cy, cx, y + size, pathEdge)
        if (w) canvas.drawLine(cx, cy, x, cy, pathEdge)
        if (e) canvas.drawLine(cx, cy, x + size, cy, pathEdge)
        pathFill.color = highlight
        canvas.drawCircle(cx, cy, t * 0.22f, pathFill)
    }

    private fun drawForest(canvas: Canvas, x: Float, y: Float, seed: Int, stump: Boolean) {
        val cx = x + cell * 0.5f
        val cy = y + cell * 0.58f
        if (stump && (seed and 3) == 0) {
            wood.color = 0xFF6B4A2A.toInt()
            canvas.drawCircle(cx, cy + cell * 0.08f, cell * 0.14f, wood)
            wood.color = 0xFF8A6234.toInt()
            canvas.drawCircle(cx, cy + cell * 0.06f, cell * 0.09f, wood)
            return
        }
        val count = 1 + (abs(seed) % 2)
        for (i in 0 until count) {
            val ox = if (i == 0) 0f else cell * 0.16f * if (seed % 2 == 0) 1 else -1
            val tx = cx + ox
            wood.color = 0xFF5A3A1C.toInt()
            canvas.drawRect(tx - cell * 0.05f, cy, tx + cell * 0.05f, y + cell * 0.88f, wood)
            leaf.color = 0xFF2F7A3A.toInt()
            canvas.drawCircle(tx, cy - cell * 0.08f, cell * 0.28f, leaf)
            leaf.color = 0xFF3F9A48.toInt()
            canvas.drawCircle(tx - cell * 0.06f, cy - cell * 0.16f, cell * 0.2f, leaf)
            leaf.color = 0xFF58B85C.toInt()
            canvas.drawCircle(tx + cell * 0.05f, cy - cell * 0.22f, cell * 0.16f, leaf)
        }
    }

    private fun drawSign(canvas: Canvas, x: Float, y: Float, label: String) {
        val cx = x + cell * 0.5f
        wood.color = 0xFF6B4A28.toInt()
        canvas.drawRect(cx - cell * 0.03f, y + cell * 0.42f, cx + cell * 0.03f, y + cell * 0.78f, wood)
        wood.color = 0xFFC4A15A.toInt()
        rect.set(x + cell * 0.12f, y + cell * 0.08f, x + cell * 0.88f, y + cell * 0.42f)
        canvas.drawRoundRect(rect, 6f, 6f, wood)
        ink.textSize = cell * 0.13f
        canvas.drawText(label, cx, y + cell * 0.24f, ink)
        tmp.reset()
        tmp.moveTo(cx - cell * 0.08f, y + cell * 0.30f)
        tmp.lineTo(cx + cell * 0.08f, y + cell * 0.30f)
        tmp.lineTo(cx, y + cell * 0.38f)
        tmp.close()
        wood.color = 0xFF4A3018.toInt()
        canvas.drawPath(tmp, wood)
    }

    private fun drawWalker(canvas: Canvas, w: GameWorld) {
        val px = originX + w.walkerX() * cell
        val py = originY + w.walkerY() * cell
        hero.draw(
            canvas,
            px,
            py + cell * 0.18f,
            cell * 0.82f,
            w.walker.facing,
            w.walker.mood,
            w.walker.moodT,
            w.heroPhase(),
            w.heroWalking(),
        )
    }

    private fun drawHeroStage(canvas: Canvas, w: GameWorld) {
        val pad = min(width, height) * 0.02f
        val left = if (landscape) panelLeft else pad
        val top = panelTop
        val right = if (landscape) panelLeft + panelWidth else width - pad
        val bottom = height - pad
        wood.color = 0xFF1A3322.toInt()
        rect.set(left, top, right, bottom)
        canvas.drawRoundRect(rect, 18f, 18f, wood)
        pathEdge.strokeWidth = 3f
        pathEdge.color = 0x66E6C97A.toInt()
        canvas.drawRoundRect(rect, 18f, 18f, pathEdge)

        ink.textSize = (if (landscape) panelWidth * 0.075f else cell * 0.22f).coerceIn(18f, 34f)
        ink.color = 0xFFE8D9A8.toInt()
        val title = when {
            w.isSad() -> context.getString(R.string.sad)
            w.state == PlayState.WALKING || w.state == PlayState.CELEBRATING -> context.getString(R.string.walking)
            else -> context.getString(R.string.waiting)
        }
        canvas.drawText(title, (left + right) * 0.5f, top + ink.textSize * 1.35f, ink)

        val stageH = (bottom - top) * if (landscape) 0.78f else 0.82f
        val stageW = right - left
        val heroH = min(stageW * 0.92f, stageH * 0.88f)
        val cx = (left + right) * 0.5f
        val feet = bottom - (bottom - top) * 0.12f
        hero.draw(
            canvas,
            cx,
            feet,
            heroH,
            w.walker.facing,
            w.walker.mood,
            w.walker.moodT,
            w.heroPhase(),
            w.heroWalking(),
        )
        ink.color = 0xFFF4E8C8.toInt()
    }

    private fun drawFillPanel(canvas: Canvas, w: GameWorld) {
        ink.textSize = cell * 0.22f
        ink.color = 0xFFF4E8C8.toInt()
        val count = w.fillOptions.size.coerceAtMost(optionRects.size)
        val title = context.getString(R.string.fill)
        if (landscape) {
            val cx = panelLeft + panelWidth * 0.5f
            canvas.drawText(title, cx, panelTop + cell * 0.45f, ink)
            if (count == 0) return
            val box = min(panelWidth * 0.42f, (height - panelTop - cell * 0.6f) / 4.1f)
            val gap = cell * 0.16f
            val x = panelLeft + (panelWidth - box) * 0.5f
            var y = panelTop + cell * 0.75f
            for (i in 0 until count) {
                optionRects[i].set(x, y, x + box, y + box)
                val reject = w.rejectIndex == i && w.rejectT > 0f
                drawOptionCard(canvas, optionRects[i], w.fillOptions[i], reject)
                y += box + gap
            }
        } else {
            canvas.drawText(title, width * 0.5f, panelTop + cell * 0.28f, ink)
            if (count == 0) return
            val box = min(cell * 1.45f, (panelWidth * 0.82f - cell * 0.4f) / count)
            val gap = cell * 0.2f
            val total = count * box + (count - 1) * gap
            var x = (width - total) * 0.5f
            val y = panelTop + cell * 0.42f
            for (i in 0 until count) {
                optionRects[i].set(x, y, x + box, y + box)
                val reject = w.rejectIndex == i && w.rejectT > 0f
                drawOptionCard(canvas, optionRects[i], w.fillOptions[i], reject)
                x += box + gap
            }
        }
    }

    private fun drawOptionCard(canvas: Canvas, box: RectF, shape: PathShape, reject: Boolean) {
        wood.color = 0xFF1E3A24.toInt()
        canvas.drawRoundRect(box, 14f, 14f, wood)
        pathEdge.strokeWidth = 4f
        pathEdge.strokeCap = Paint.Cap.SQUARE
        pathEdge.color = if (reject) 0xFFE45B4A.toInt() else 0xFFE6C97A.toInt()
        canvas.drawRoundRect(box, 14f, 14f, pathEdge)
        pathEdge.strokeCap = Paint.Cap.ROUND
        val pad = box.width() * 0.16f
        drawPath(
            canvas,
            box.left + pad,
            box.top + pad,
            box.width() - pad * 2,
            shape.n,
            shape.e,
            shape.s,
            shape.w,
            if (reject) 0xFFB85A48.toInt() else 0xFFD7B56A.toInt(),
            if (reject) 0xFFE8A090.toInt() else 0xFFE6C97A.toInt(),
        )
    }

    private fun drawTapHint(canvas: Canvas, w: GameWorld) {
        drawCenterHint(canvas, w, context.getString(R.string.tap_start))
    }

    private fun drawLoadingHint(canvas: Canvas, w: GameWorld) {
        drawCenterHint(canvas, w, context.getString(R.string.loading))
    }

    private fun drawCenterHint(canvas: Canvas, w: GameWorld, text: String) {
        val pulse = 0.55f + 0.45f * (0.5f + 0.5f * sin(w.walker.bob * 2.2f))
        val alpha = (pulse * 255).toInt().coerceIn(80, 255)
        ink.color = (alpha shl 24) or 0x00F4E8C8
        ink.textSize = cell * 0.32f
        val mazeW = cell * w.maze.size
        val cx = originX + mazeW * 0.5f
        val cy = originY + mazeW * 0.5f
        canvas.drawText(text, cx, cy, ink)
        ink.color = 0xFFF4E8C8.toInt()
    }

    private fun rgb(r: Float, g: Float, b: Float): Int {
        val rr = (r.coerceIn(0f, 1f) * 255).toInt()
        val gg = (g.coerceIn(0f, 1f) * 255).toInt()
        val bb = (b.coerceIn(0f, 1f) * 255).toInt()
        return (0xFF shl 24) or (rr shl 16) or (gg shl 8) or bb
    }
}
