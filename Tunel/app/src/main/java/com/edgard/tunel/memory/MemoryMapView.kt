package com.edgard.tunel.memory

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Typeface
import android.util.AttributeSet
import android.view.View
import com.edgard.tunel.model.GameMap
import com.edgard.tunel.model.NodeType
import com.edgard.tunel.model.ThreatType
import kotlin.math.max
import kotlin.math.min

class MemoryMapView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {
    private var map: GameMap? = null
    private val tunnelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 3f
        color = 0xFFE8E4D8.toInt()
    }
    private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xFFF4F0E6.toInt()
        textAlign = Paint.Align.CENTER
        typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
    }
    private val glyph = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xFFF4F0E6.toInt()
        textAlign = Paint.Align.CENTER
        typeface = Typeface.DEFAULT_BOLD
    }
    private val tmp = Path()

    fun setMap(gameMap: GameMap?) {
        map = gameMap
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val m = map ?: return
        if (m.nodes.isEmpty()) return
        var minX = Float.POSITIVE_INFINITY
        var maxX = Float.NEGATIVE_INFINITY
        var minZ = Float.POSITIVE_INFINITY
        var maxZ = Float.NEGATIVE_INFINITY
        for (n in m.nodes) {
            minX = min(minX, n.x)
            maxX = max(maxX, n.x)
            minZ = min(minZ, n.z)
            maxZ = max(maxZ, n.z)
        }
        val pad = 56f * resources.displayMetrics.density
        val spanX = max(maxX - minX, 8f)
        val spanZ = max(maxZ - minZ, 8f)
        val scale = min((width - pad * 2) / spanX, (height - pad * 2) / spanZ)
        val cx = (minX + maxX) * 0.5f
        val cz = (minZ + maxZ) * 0.5f
        fun sx(x: Float) = width * 0.5f + (x - cx) * scale
        fun sy(z: Float) = height * 0.5f + (z - cz) * scale
        val roomR = max(22f, min(width, height) * 0.042f)

        tunnelPaint.strokeWidth = roomR * 0.55f
        for (t in m.tunnels) {
            val a = m.node(t.from)
            val b = m.node(t.to)
            tunnelPaint.color = (0xFF000000.toInt()) or t.color.rgb
            canvas.drawLine(sx(a.x), sy(a.z), sx(b.x), sy(b.z), tunnelPaint)
        }

        text.textSize = roomR * 0.42f
        glyph.textSize = roomR * 0.72f
        for (n in m.nodes) {
            val x = sx(n.x)
            val y = sy(n.z)
            when (n.type) {
                NodeType.START -> {
                    fill.color = 0xFF2E7D4F.toInt()
                    canvas.drawCircle(x, y, roomR, fill)
                    canvas.drawCircle(x, y, roomR, stroke)
                    canvas.drawText("ENTRADA", x, y + text.textSize * 0.35f, text)
                }
                NodeType.NORMAL -> {
                    fill.color = 0xFF243044.toInt()
                    canvas.drawCircle(x, y, roomR * 0.86f, fill)
                    canvas.drawCircle(x, y, roomR * 0.86f, stroke)
                }
                NodeType.TREASURE -> {
                    fill.color = 0xFFC9A227.toInt()
                    canvas.drawCircle(x, y, roomR, fill)
                    canvas.drawCircle(x, y, roomR, stroke)
                    drawCrown(canvas, x, y, roomR * 0.7f)
                }
                NodeType.THREAT -> {
                    fill.color = 0xFF6B2430.toInt()
                    canvas.drawCircle(x, y, roomR, fill)
                    canvas.drawCircle(x, y, roomR, stroke)
                    val mark = when (n.threat) {
                        ThreatType.SPIDER -> "🕷️"
                        ThreatType.SKULL -> "💀"
                        else -> "👹"
                    }
                    canvas.drawText(mark, x, y + glyph.textSize * 0.35f, glyph)
                }
            }
        }
    }

    private fun drawCrown(canvas: Canvas, x: Float, y: Float, r: Float) {
        tmp.reset()
        tmp.moveTo(x - r * 0.7f, y + r * 0.25f)
        tmp.lineTo(x - r * 0.7f, y - r * 0.05f)
        tmp.lineTo(x - r * 0.35f, y + r * 0.08f)
        tmp.lineTo(x, y - r * 0.55f)
        tmp.lineTo(x + r * 0.35f, y + r * 0.08f)
        tmp.lineTo(x + r * 0.7f, y - r * 0.05f)
        tmp.lineTo(x + r * 0.7f, y + r * 0.25f)
        tmp.close()
        fill.color = 0xFFFFF3C4.toInt()
        canvas.drawPath(tmp, fill)
        canvas.drawPath(tmp, stroke)
    }
}
