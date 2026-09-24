package com.edgard.tunel.render

import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.Matrix
import com.edgard.tunel.audio.GameAudio
import com.edgard.tunel.explore.ExplorationPhase
import com.edgard.tunel.explore.ExploreMode
import com.edgard.tunel.explore.GameInput
import com.edgard.tunel.game.GameManager
import com.edgard.tunel.game.GameState
import com.edgard.tunel.model.GameMap
import com.edgard.tunel.model.ThreatType
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import kotlin.math.cos
import kotlin.math.sin

class GameRenderer(
    private val manager: GameManager,
    private val input: GameInput,
    private val audio: GameAudio,
    private val mainHandler: android.os.Handler,
) : GLSurfaceView.Renderer {
    private val shader = ShaderProgram()
    private val identity = FloatArray(16).also { Matrix.setIdentityM(it, 0) }
    private val model = FloatArray(16)
    private val mvp = FloatArray(16)
    private val tmp = FloatArray(16)
    private var unitBox: Mesh? = null
    private var phase: ExplorationPhase? = null
    private var pendingMap: GameMap? = null
    private var lastNs = 0L
    private var width = 1
    private var height = 1

    @Synchronized
    fun startMap(map: GameMap) {
        pendingMap = map
    }

    @Synchronized
    fun clearPhase() {
        phase = null
        pendingMap = null
    }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        GLES20.glClearColor(0.045f, 0.055f, 0.07f, 1f)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
        GLES20.glEnable(GLES20.GL_CULL_FACE)
        GLES20.glCullFace(GLES20.GL_BACK)
        shader.compile()
        unitBox?.invalidate()
        val b = MeshBuilder()
        b.addBox(0f, 0f, 0f, 1f, 1f, 1f, 0f, 1f, 1f, 1f)
        unitBox = b.build()
        phase?.world?.mesh?.invalidate()
        lastNs = 0L
    }

    override fun onSurfaceChanged(gl: GL10?, w: Int, h: Int) {
        width = w
        height = h
        GLES20.glViewport(0, 0, w, h)
        input.viewW = w
        input.viewH = h
        phase?.camera?.setProjection(w, h)
    }

    override fun onDrawFrame(gl: GL10?) {
        val now = System.nanoTime()
        val dt = if (lastNs == 0L) 0.016f else ((now - lastNs) / 1_000_000_000f).coerceIn(0.001f, 0.05f)
        lastNs = now

        val fresh = synchronized(this) {
            val m = pendingMap
            pendingMap = null
            m
        }
        if (fresh != null) {
            val world = WorldBuilder.build(fresh)
            val p = ExplorationPhase(
                fresh,
                world,
                audio,
                onWin = { mainHandler.post { manager.success() } },
                onLose = { mainHandler.post { manager.failure() } },
            )
            p.camera.setProjection(width, height)
            p.start()
            phase = p
        }

        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        val p = phase ?: return
        if (manager.state == GameState.EXPLORATION || manager.state == GameState.SUCCESS || manager.state == GameState.FAILURE) {
            if (manager.state == GameState.EXPLORATION) p.update(dt, input)
            else {
                p.treasure.update(dt)
                p.threat.update(dt)
                p.camera.update(dt, p.player)
            }
        }
        drawWorld(p)
    }

    private fun drawWorld(p: ExplorationPhase) {
        val box = unitBox ?: return
        shader.use()
        val cam = p.camera
        val lightR: Float
        val lightG: Float
        val lightB: Float
        if (p.mode == ExploreMode.TRAVEL) {
            lightR = 0.75f + p.tunnelColor.r * 0.45f
            lightG = 0.75f + p.tunnelColor.g * 0.45f
            lightB = 0.75f + p.tunnelColor.b * 0.45f
        } else {
            lightR = 1.05f
            lightG = 1f
            lightB = 0.98f
        }
        GLES20.glUniform3f(shader.uLightPos, p.player.x, 3.4f, p.player.z)
        GLES20.glUniform3f(shader.uCamPos, cam.eyeX, cam.eyeY, cam.eyeZ)
        GLES20.glUniform3f(shader.uLightColor, lightR, lightG, lightB)
        GLES20.glUniform4f(shader.uTint, 1f, 1f, 1f, 1f)

        Matrix.setIdentityM(model, 0)
        Matrix.multiplyMM(mvp, 0, cam.vp, 0, model, 0)
        GLES20.glUniformMatrix4fv(shader.uMvp, 1, false, mvp, 0)
        GLES20.glUniformMatrix4fv(shader.uModel, 1, false, model, 0)
        p.world.mesh.bind(shader)
        p.world.mesh.draw()

        drawPlayer(p, box)
        if (p.treasure.revealed) drawCrown(p, box)
        if (p.threat.revealed) drawThreat(p, box)
        GLES20.glBindBuffer(GLES20.GL_ARRAY_BUFFER, 0)
    }

    private fun drawPlayer(p: ExplorationPhase, box: Mesh) {
        val pl = p.player
        val yaw = pl.yaw
        val bob = pl.y
        val swing = sin(pl.walkPhase) * if (pl.moving || p.mode == ExploreMode.TRAVEL) 0.55f else 0.05f
        part(box, pl.x, 0.95f + bob, pl.z, 0.42f, 0.7f, 0.28f, yaw, 0.85f, 0.78f, 0.62f)
        part(box, pl.x + sin(yaw) * 0.02f, 1.42f + bob, pl.z + cos(yaw) * 0.02f, 0.28f, 0.28f, 0.28f, yaw, 0.93f, 0.86f, 0.72f)
        val lx = cos(yaw) * 0.14f
        val lz = -sin(yaw) * 0.14f
        part(box, pl.x + lx, 0.38f + bob, pl.z + lz, 0.14f, 0.7f, 0.14f, yaw + swing, 0.22f, 0.24f, 0.3f)
        part(box, pl.x - lx, 0.38f + bob, pl.z - lz, 0.14f, 0.7f, 0.14f, yaw - swing, 0.22f, 0.24f, 0.3f)
        part(box, pl.x + lx, 1.05f + bob, pl.z + lz, 0.12f, 0.55f, 0.12f, yaw - swing * 0.6f, 0.85f, 0.78f, 0.62f)
        part(box, pl.x - lx, 1.05f + bob, pl.z - lz, 0.12f, 0.55f, 0.12f, yaw + swing * 0.6f, 0.85f, 0.78f, 0.62f)
    }

    private fun drawCrown(p: ExplorationPhase, box: Mesh) {
        val t = p.treasure
        val y = t.lift()
        val s = t.scale()
        val yaw = t.yaw()
        part(box, t.x, y, t.z, 0.7f * s, 0.16f * s, 0.7f * s, yaw, 0.95f, 0.78f, 0.22f)
        part(box, t.x, y + 0.28f * s, t.z, 0.18f * s, 0.45f * s, 0.18f * s, yaw, 1f, 0.86f, 0.3f)
        val d = 0.28f * s
        part(box, t.x + sin(yaw) * d, y + 0.22f * s, t.z + cos(yaw) * d, 0.12f * s, 0.32f * s, 0.12f * s, yaw, 1f, 0.9f, 0.4f)
        part(box, t.x - sin(yaw) * d, y + 0.22f * s, t.z - cos(yaw) * d, 0.12f * s, 0.32f * s, 0.12f * s, yaw, 1f, 0.9f, 0.4f)
        part(box, t.x, 0.18f, t.z, 0.7f, 0.35f, 0.7f, 0f, 0.45f, 0.32f, 0.12f)
    }

    private fun drawThreat(p: ExplorationPhase, box: Mesh) {
        val th = p.threat
        val s = th.scale()
        val y = th.height()
        val x = th.x + th.shake()
        val z = th.z
        when (th.type) {
            ThreatType.MONSTER -> {
                part(box, x, 1.1f * s + y, z, 0.9f * s, 1.3f * s, 0.6f * s, 0f, 0.45f, 0.12f, 0.12f)
                part(box, x - 0.28f * s, 1.85f * s + y, z, 0.16f * s, 0.45f * s, 0.16f * s, 0.4f, 0.7f, 0.15f, 0.1f)
                part(box, x + 0.28f * s, 1.85f * s + y, z, 0.16f * s, 0.45f * s, 0.16f * s, -0.4f, 0.7f, 0.15f, 0.1f)
                part(box, x - 0.18f * s, 1.25f * s + y, z + 0.28f * s, 0.14f * s, 0.12f * s, 0.08f * s, 0f, 0.95f, 0.2f, 0.15f)
                part(box, x + 0.18f * s, 1.25f * s + y, z + 0.28f * s, 0.14f * s, 0.12f * s, 0.08f * s, 0f, 0.95f, 0.2f, 0.15f)
            }
            ThreatType.SPIDER -> {
                part(box, x, 0.55f * s + y, z, 0.7f * s, 0.35f * s, 0.55f * s, 0f, 0.18f, 0.16f, 0.2f)
                part(box, x, 0.55f * s + y, z + 0.4f * s, 0.38f * s, 0.28f * s, 0.38f * s, 0f, 0.28f, 0.12f, 0.12f)
                for (i in 0 until 8) {
                    val a = i * 0.7f + 0.2f
                    val lx = sin(a) * 0.7f * s
                    val lz = cos(a) * 0.7f * s
                    part(box, x + lx, 0.28f * s + y, z + lz, 0.08f * s, 0.08f * s, 0.85f * s, a, 0.12f, 0.1f, 0.12f)
                }
            }
            ThreatType.SKULL -> {
                part(box, x, 1.1f * s + y, z, 0.7f * s, 0.7f * s, 0.55f * s, th.time, 0.9f, 0.88f, 0.8f)
                part(box, x - 0.16f * s, 1.18f * s + y, z + 0.26f * s, 0.16f * s, 0.14f * s, 0.08f * s, 0f, 0.08f, 0.06f, 0.06f)
                part(box, x + 0.16f * s, 1.18f * s + y, z + 0.26f * s, 0.16f * s, 0.14f * s, 0.08f * s, 0f, 0.08f, 0.06f, 0.06f)
                part(box, x, 0.78f * s + y, z + 0.22f * s, 0.35f * s, 0.18f * s, 0.16f * s, 0f, 0.15f, 0.12f, 0.12f)
            }
        }
    }

    private fun part(
        box: Mesh,
        x: Float, y: Float, z: Float,
        sx: Float, sy: Float, sz: Float,
        yaw: Float,
        r: Float, g: Float, b: Float,
    ) {
        Matrix.setIdentityM(model, 0)
        Matrix.translateM(model, 0, x, y, z)
        Matrix.rotateM(model, 0, Math.toDegrees(yaw.toDouble()).toFloat(), 0f, 1f, 0f)
        Matrix.scaleM(model, 0, sx, sy, sz)
        Matrix.multiplyMM(mvp, 0, phase!!.camera.vp, 0, model, 0)
        GLES20.glUniformMatrix4fv(shader.uMvp, 1, false, mvp, 0)
        GLES20.glUniformMatrix4fv(shader.uModel, 1, false, model, 0)
        GLES20.glUniform4f(shader.uTint, r, g, b, 1f)
        box.bind(shader)
        box.draw()
    }
}
