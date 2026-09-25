package com.edgard.labirinto

import android.app.Activity
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.TextView
import com.edgard.labirinto.audio.GameAudio
import com.edgard.labirinto.game.GameWorld
import com.edgard.labirinto.game.PlayState
import com.edgard.labirinto.render.MazeView

class MainActivity : Activity() {
    private val world = GameWorld()
    private lateinit var audio: GameAudio

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        audio = GameAudio(this)
        world.audio = audio
        val maze = findViewById<MazeView>(R.id.maze)
        val menu = findViewById<View>(R.id.overlay_menu)
        val win = findViewById<View>(R.id.overlay_win)
        val hint = findViewById<TextView>(R.id.hint)
        maze.world = world
        world.onChanged = { maze.invalidate() }
        maze.onWin = {
            win.visibility = View.VISIBLE
            hint.visibility = View.GONE
        }
        maze.onState = { state ->
            hint.visibility = View.GONE
            if (state == PlayState.WON) {
                win.visibility = View.VISIBLE
            }
        }
        findViewById<Button>(R.id.btn_play).setOnClickListener {
            audio.click()
            world.play()
            menu.visibility = View.GONE
            win.visibility = View.GONE
            maze.invalidate()
        }
        findViewById<Button>(R.id.btn_again).setOnClickListener {
            audio.click()
            world.retrySame()
            win.visibility = View.GONE
            maze.invalidate()
        }
        findViewById<Button>(R.id.btn_new).setOnClickListener {
            audio.click()
            world.newMap()
            win.visibility = View.GONE
            maze.invalidate()
        }
    }

    override fun onDestroy() {
        world.audio = null
        audio.release()
        super.onDestroy()
    }
}
