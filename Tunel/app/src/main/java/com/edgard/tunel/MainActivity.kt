package com.edgard.tunel

import android.app.Activity
import android.opengl.GLSurfaceView
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import com.edgard.tunel.audio.GameAudio
import com.edgard.tunel.explore.GameInput
import com.edgard.tunel.explore.JoystickView
import com.edgard.tunel.game.GameManager
import com.edgard.tunel.game.GameSettings
import com.edgard.tunel.game.GameState
import com.edgard.tunel.memory.MemoryMapView
import com.edgard.tunel.model.GameMap
import com.edgard.tunel.render.GameRenderer
import com.edgard.tunel.ui.UIManager

class MainActivity : Activity(), GameManager.Listener {
    private lateinit var manager: GameManager
    private lateinit var glView: GLSurfaceView
    private lateinit var renderer: GameRenderer
    private lateinit var ui: UIManager
    private lateinit var audio: GameAudio
    private val input = GameInput()
    private var glLive = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        val settings = GameSettings(this)
        manager = GameManager(settings)
        manager.listener = this
        audio = GameAudio(this)
        glView = findViewById(R.id.gl_view)
        glView.setEGLContextClientVersion(2)
        glView.setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        renderer = GameRenderer(manager, input, audio, Handler(Looper.getMainLooper()))
        glView.setRenderer(renderer)
        glView.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
        glView.preserveEGLContextOnPause = true
        val joystick = findViewById<JoystickView>(R.id.joystick)
        joystick.input = input
        ui = UIManager(
            manager,
            findViewById(R.id.overlay_menu),
            findViewById(R.id.overlay_settings),
            findViewById(R.id.overlay_memory),
            findViewById(R.id.overlay_result),
            findViewById<MemoryMapView>(R.id.memory_map),
            glView,
            joystick,
            audio,
        )
        ui.bind()
        onState(manager.state, manager.map)
    }

    override fun onState(state: GameState, map: GameMap?) {
        ui.show(state, map, manager.difficulty)
        val exploring = state == GameState.EXPLORATION || state == GameState.SUCCESS || state == GameState.FAILURE
        if (exploring) {
            if (state == GameState.EXPLORATION && map != null) renderer.startMap(map)
            glView.visibility = View.VISIBLE
            glView.onResume()
            glLive = true
        } else {
            renderer.clearPhase()
            if (glLive) {
                glView.onPause()
                glLive = false
            }
            glView.visibility = View.GONE
        }
    }

    override fun onResume() {
        super.onResume()
        if (glLive) glView.onResume()
    }

    override fun onPause() {
        if (glLive) glView.onPause()
        super.onPause()
    }

    override fun onDestroy() {
        audio.release()
        super.onDestroy()
    }
}
