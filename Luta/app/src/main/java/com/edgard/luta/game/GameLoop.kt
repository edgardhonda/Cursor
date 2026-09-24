package com.edgard.luta.game

import android.graphics.Canvas
import android.view.SurfaceHolder

class GameLoop(
    private val holder: SurfaceHolder,
    private val world: GameWorld,
) : Thread("LutaLoop") {
    @Volatile
    var running: Boolean = false

    override fun run() {
        var last = System.nanoTime()
        while (running) {
            val now = System.nanoTime()
            var dt = (now - last) / 1_000_000_000f
            last = now
            if (dt > 0.05f) dt = 0.05f
            if (dt < 0f) dt = 0.008f

            world.update(dt)

            var canvas: Canvas? = null
            try {
                canvas = holder.lockHardwareCanvas()
                if (canvas == null) canvas = holder.lockCanvas()
                if (canvas != null) {
                    world.render(canvas)
                } else {
                    sleep(4)
                }
            } catch (_: Exception) {
                // Surface can vanish during rotation; skip the frame.
            } finally {
                if (canvas != null) {
                    try {
                        holder.unlockCanvasAndPost(canvas)
                    } catch (_: Exception) {
                    }
                }
            }
            world.noteFrame(dt)
        }
    }
}
