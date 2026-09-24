package com.edgard.luta.combat

import com.edgard.luta.math.CombatConfig

class CombatController {
    private val q = Array(CombatConfig.COMMAND_QUEUE) { GestureAction.TAP }
    private var head: Int = 0
    private var count: Int = 0

    fun clear() {
        head = 0
        count = 0
    }

    fun enqueue(action: GestureAction) {
        if (count >= CombatConfig.COMMAND_QUEUE) {
            head = (head + 1) % CombatConfig.COMMAND_QUEUE
            count--
        }
        q[(head + count) % CombatConfig.COMMAND_QUEUE] = action
        count++
    }

    fun poll(): GestureAction? {
        if (count == 0) return null
        val a = q[head]
        head = (head + 1) % CombatConfig.COMMAND_QUEUE
        count--
        return a
    }

    fun peek(): GestureAction? = if (count == 0) null else q[head]

    fun isEmpty(): Boolean = count == 0
}
