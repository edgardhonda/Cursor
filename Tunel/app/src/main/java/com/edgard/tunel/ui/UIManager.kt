package com.edgard.tunel.ui

import android.view.View
import android.widget.Button
import android.widget.TextView
import com.edgard.tunel.R
import com.edgard.tunel.audio.GameAudio
import com.edgard.tunel.game.GameManager
import com.edgard.tunel.game.GameState
import com.edgard.tunel.memory.MemoryMapView
import com.edgard.tunel.memory.MemoryPhase
import com.edgard.tunel.model.Difficulty
import com.edgard.tunel.model.GameMap

class UIManager(
    private val manager: GameManager,
    private val menu: View,
    private val settings: View,
    private val memory: View,
    private val result: View,
    private val memoryMap: MemoryMapView,
    private val gl: View,
    private val joystick: View,
    private val audio: GameAudio,
) {
    private val memoryPhase = MemoryPhase()
    private val resultIcon: TextView = result.findViewById(R.id.result_icon)
    private val resultTitle: TextView = result.findViewById(R.id.result_title)
    private val btnRetry: Button = result.findViewById(R.id.btn_retry)
    private val level1: View = settings.findViewById(R.id.level_1)
    private val level2: View = settings.findViewById(R.id.level_2)
    private val level3: View = settings.findViewById(R.id.level_3)

    fun bind() {
        menu.findViewById<Button>(R.id.btn_play).setOnClickListener {
            audio.click()
            manager.play()
        }
        menu.findViewById<Button>(R.id.btn_settings).setOnClickListener {
            audio.click()
            manager.openSettings()
        }
        settings.findViewById<Button>(R.id.btn_back).setOnClickListener {
            audio.click()
            manager.backToMenu()
        }
        level1.setOnClickListener {
            audio.click()
            manager.setDifficulty(Difficulty.LEVEL_1)
        }
        level2.setOnClickListener {
            audio.click()
            manager.setDifficulty(Difficulty.LEVEL_2)
        }
        level3.setOnClickListener {
            audio.click()
            manager.setDifficulty(Difficulty.LEVEL_3)
        }
        memory.findViewById<Button>(R.id.btn_ready).setOnClickListener {
            audio.ready()
            manager.ready()
        }
        btnRetry.setOnClickListener {
            audio.click()
            manager.retrySame()
        }
        result.findViewById<Button>(R.id.btn_new_map).setOnClickListener {
            audio.click()
            manager.newMap()
        }
    }

    fun show(state: GameState, map: GameMap?, difficulty: Difficulty) {
        menu.visibility = visible(state == GameState.MENU)
        settings.visibility = visible(state == GameState.SETTINGS)
        memory.visibility = visible(state == GameState.MEMORY)
        result.visibility = visible(state == GameState.SUCCESS || state == GameState.FAILURE)
        val exploring = state == GameState.EXPLORATION || state == GameState.SUCCESS || state == GameState.FAILURE
        gl.visibility = visible(exploring)
        joystick.visibility = visible(state == GameState.EXPLORATION)
        if (state == GameState.MEMORY) memoryPhase.show(map, memoryMap)
        if (state == GameState.SUCCESS) {
            resultIcon.text = "👑"
            resultTitle.setText(R.string.treasure_found)
            resultTitle.setTextColor(result.resources.getColor(R.color.gold, null))
            btnRetry.setText(R.string.play_again)
        }
        if (state == GameState.FAILURE) {
            resultIcon.text = "☠️"
            resultTitle.setText(R.string.threat_found)
            resultTitle.setTextColor(result.resources.getColor(R.color.danger, null))
            btnRetry.setText(R.string.try_again)
        }
        paintLevel(level1, difficulty == Difficulty.LEVEL_1)
        paintLevel(level2, difficulty == Difficulty.LEVEL_2)
        paintLevel(level3, difficulty == Difficulty.LEVEL_3)
    }

    private fun paintLevel(v: View, selected: Boolean) {
        v.setBackgroundResource(if (selected) R.drawable.bg_selected else R.drawable.bg_button)
    }

    private fun visible(on: Boolean) = if (on) View.VISIBLE else View.GONE
}
