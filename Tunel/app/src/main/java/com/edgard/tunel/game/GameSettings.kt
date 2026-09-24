package com.edgard.tunel.game

import android.content.Context
import com.edgard.tunel.model.Difficulty

class GameSettings(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences("tunel", Context.MODE_PRIVATE)

    var difficulty: Difficulty
        get() = Difficulty.fromLevel(prefs.getInt("level", 1))
        set(value) {
            prefs.edit().putInt("level", value.level).apply()
        }
}
