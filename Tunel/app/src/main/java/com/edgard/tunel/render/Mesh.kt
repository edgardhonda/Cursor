package com.edgard.tunel.render

import android.opengl.GLES20
import java.nio.ByteBuffer
import java.nio.ByteOrder

class Mesh(private val verts: FloatArray) {
    private var vbo = 0
    private var uploaded = false
    val vertexCount: Int = verts.size / STRIDE_FLOATS

    fun upload() {
        if (uploaded) return
        val buf = ByteBuffer.allocateDirect(verts.size * 4).order(ByteOrder.nativeOrder()).asFloatBuffer()
        buf.put(verts).position(0)
        val ids = IntArray(1)
        GLES20.glGenBuffers(1, ids, 0)
        vbo = ids[0]
        GLES20.glBindBuffer(GLES20.GL_ARRAY_BUFFER, vbo)
        GLES20.glBufferData(GLES20.GL_ARRAY_BUFFER, verts.size * 4, buf, GLES20.GL_STATIC_DRAW)
        uploaded = true
    }

    fun invalidate() {
        uploaded = false
        vbo = 0
    }

    fun bind(prog: ShaderProgram) {
        upload()
        GLES20.glBindBuffer(GLES20.GL_ARRAY_BUFFER, vbo)
        val stride = STRIDE_BYTES
        GLES20.glEnableVertexAttribArray(prog.aPos)
        GLES20.glVertexAttribPointer(prog.aPos, 3, GLES20.GL_FLOAT, false, stride, 0)
        GLES20.glEnableVertexAttribArray(prog.aNormal)
        GLES20.glVertexAttribPointer(prog.aNormal, 3, GLES20.GL_FLOAT, false, stride, 12)
        GLES20.glEnableVertexAttribArray(prog.aColor)
        GLES20.glVertexAttribPointer(prog.aColor, 4, GLES20.GL_FLOAT, false, stride, 24)
    }

    fun draw() {
        GLES20.glDrawArrays(GLES20.GL_TRIANGLES, 0, vertexCount)
    }

    companion object {
        const val STRIDE_FLOATS = 10
        const val STRIDE_BYTES = STRIDE_FLOATS * 4
    }
}

class MeshBuilder {
    private val data = ArrayList<Float>(4096)

    fun addTri(
        ax: Float, ay: Float, az: Float,
        bx: Float, by: Float, bz: Float,
        cx: Float, cy: Float, cz: Float,
        r: Float, g: Float, b: Float,
        shade: Float = 1f,
    ) {
        val ux = bx - ax
        val uy = by - ay
        val uz = bz - az
        val vx = cx - ax
        val vy = cy - ay
        val vz = cz - az
        var nx = uy * vz - uz * vy
        var ny = uz * vx - ux * vz
        var nz = ux * vy - uy * vx
        val len = kotlin.math.sqrt(nx * nx + ny * ny + nz * nz)
        if (len > 1e-6f) {
            nx /= len
            ny /= len
            nz /= len
        }
        val cr = (r * shade).coerceIn(0f, 1f)
        val cg = (g * shade).coerceIn(0f, 1f)
        val cb = (b * shade).coerceIn(0f, 1f)
        vert(ax, ay, az, nx, ny, nz, cr, cg, cb)
        vert(bx, by, bz, nx, ny, nz, cr, cg, cb)
        vert(cx, cy, cz, nx, ny, nz, cr, cg, cb)
    }

    fun addQuad(
        ax: Float, ay: Float, az: Float,
        bx: Float, by: Float, bz: Float,
        cx: Float, cy: Float, cz: Float,
        dx: Float, dy: Float, dz: Float,
        r: Float, g: Float, b: Float,
        shade: Float = 1f,
    ) {
        addTri(ax, ay, az, bx, by, bz, cx, cy, cz, r, g, b, shade)
        addTri(ax, ay, az, cx, cy, cz, dx, dy, dz, r, g, b, shade)
    }

    fun addBox(cx: Float, cy: Float, cz: Float, sx: Float, sy: Float, sz: Float, yaw: Float, r: Float, g: Float, b: Float) {
        val hx = sx * 0.5f
        val hy = sy * 0.5f
        val hz = sz * 0.5f
        val c = kotlin.math.cos(yaw)
        val s = kotlin.math.sin(yaw)
        fun px(lx: Float, lz: Float) = cx + lx * c + lz * s
        fun pz(lx: Float, lz: Float) = cz - lx * s + lz * c
        val x0 = px(-hx, -hz)
        val z0 = pz(-hx, -hz)
        val x1 = px(hx, -hz)
        val z1 = pz(hx, -hz)
        val x2 = px(hx, hz)
        val z2 = pz(hx, hz)
        val x3 = px(-hx, hz)
        val z3 = pz(-hx, hz)
        val y0 = cy - hy
        val y1 = cy + hy
        addQuad(x3, y0, z3, x2, y0, z2, x2, y1, z2, x3, y1, z3, r, g, b, 1f)
        addQuad(x0, y0, z0, x3, y0, z3, x3, y1, z3, x0, y1, z0, r, g, b, 0.82f)
        addQuad(x1, y0, z1, x0, y0, z0, x0, y1, z0, x1, y1, z1, r, g, b, 0.74f)
        addQuad(x2, y0, z2, x1, y0, z1, x1, y1, z1, x2, y1, z2, r, g, b, 0.9f)
        addQuad(x3, y1, z3, x2, y1, z2, x1, y1, z1, x0, y1, z0, r, g, b, 1.05f)
        addQuad(x0, y0, z0, x1, y0, z1, x2, y0, z2, x3, y0, z3, r, g, b, 0.55f)
    }

    fun addDisk(cx: Float, cy: Float, cz: Float, radius: Float, segs: Int, r: Float, g: Float, b: Float, yNormal: Float) {
        val up = yNormal >= 0f
        for (i in 0 until segs) {
            val a0 = (i.toFloat() / segs) * (Math.PI * 2).toFloat()
            val a1 = ((i + 1).toFloat() / segs) * (Math.PI * 2).toFloat()
            val x0 = cx + kotlin.math.sin(a0) * radius
            val z0 = cz + kotlin.math.cos(a0) * radius
            val x1 = cx + kotlin.math.sin(a1) * radius
            val z1 = cz + kotlin.math.cos(a1) * radius
            if (up) addTri(cx, cy, cz, x0, cy, z0, x1, cy, z1, r, g, b, 1f)
            else addTri(cx, cy, cz, x1, cy, z1, x0, cy, z0, r, g, b, 0.45f)
        }
    }

    fun build(): Mesh = Mesh(data.toFloatArray())

    private fun vert(
        x: Float, y: Float, z: Float,
        nx: Float, ny: Float, nz: Float,
        r: Float, g: Float, b: Float,
    ) {
        data += x
        data += y
        data += z
        data += nx
        data += ny
        data += nz
        data += r
        data += g
        data += b
        data += 1f
    }
}
