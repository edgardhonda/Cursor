package com.edgard.dentista

import android.app.Activity
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.TextView
import com.edgard.dentista.audio.GameAudio
import com.edgard.dentista.game.GameWorld
import com.edgard.dentista.render.MouthView

class MainActivity : Activity() {
    private val world = GameWorld()
    private lateinit var audio: GameAudio

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        audio = GameAudio(this)
        world.audio = audio
        val mouth = findViewById<MouthView>(R.id.mouth)
        val menu = findViewById<View>(R.id.overlay_menu)
        val lose = findViewById<View>(R.id.overlay_lose)
        val loseScore = findViewById<TextView>(R.id.lose_score)
        val restart = findViewById<Button>(R.id.btn_restart)
        mouth.world = world
        mouth.onLost = {
            audio.lose()
            loseScore.text = getString(R.string.lost) + "\nLimpas: ${world.cleaned}"
            lose.visibility = View.VISIBLE
            lose.isClickable = true
            restart.visibility = View.GONE
        }
        fun startGame() {
            audio.click()
            world.play()
            menu.visibility = View.GONE
            menu.isClickable = false
            lose.visibility = View.GONE
            lose.isClickable = false
            restart.visibility = View.VISIBLE
            mouth.invalidate()
            mouth.kick()
        }
        menu.isClickable = true
        menu.setOnClickListener { startGame() }
        findViewById<Button>(R.id.btn_play).setOnClickListener { startGame() }
        lose.isClickable = true
        lose.setOnClickListener(null)
        findViewById<Button>(R.id.btn_again).setOnClickListener { startGame() }
        restart.setOnClickListener { startGame() }
    }

    override fun onResume() {
        super.onResume()
        findViewById<MouthView>(R.id.mouth).kick()
    }

    override fun onDestroy() {
        world.audio = null
        audio.release()
        super.onDestroy()
    }
}
