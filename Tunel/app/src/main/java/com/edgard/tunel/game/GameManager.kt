package com.edgard.tunel.game

import com.edgard.tunel.gen.MapGenerator
import com.edgard.tunel.model.Difficulty
import com.edgard.tunel.model.GameMap
import kotlin.random.Random

enum class GameState {
    MENU,
    SETTINGS,
    MEMORY,
    EXPLORATION,
    SUCCESS,
    FAILURE,
}

class GameManager(private val settings: GameSettings) {
    interface Listener {
        fun onState(state: GameState, map: GameMap?)
    }

    var state: GameState = GameState.MENU
        private set
    var map: GameMap? = null
        private set
    var seed: Long = 0L
        private set
    var listener: Listener? = null
    val difficulty: Difficulty get() = settings.difficulty

    fun play() {
        seed = Random.nextLong()
        map = MapGenerator.generate(seed, settings.difficulty)
        setState(GameState.MEMORY)
    }

    fun ready() {
        if (map == null) return
        setState(GameState.EXPLORATION)
    }

    fun success() = setState(GameState.SUCCESS)

    fun failure() = setState(GameState.FAILURE)

    fun retrySame() {
        if (map == null) play() else setState(GameState.MEMORY)
    }

    fun newMap() {
        seed = Random.nextLong()
        map = MapGenerator.generate(seed, settings.difficulty)
        setState(GameState.MEMORY)
    }

    fun openSettings() = setState(GameState.SETTINGS)

    fun backToMenu() = setState(GameState.MENU)

    fun setDifficulty(d: Difficulty) {
        settings.difficulty = d
        listener?.onState(state, map)
    }

    private fun setState(next: GameState) {
        state = next
        listener?.onState(state, map)
    }
}
