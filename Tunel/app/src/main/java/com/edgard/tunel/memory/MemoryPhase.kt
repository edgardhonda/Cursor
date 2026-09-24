package com.edgard.tunel.memory

import com.edgard.tunel.model.GameMap

class MemoryPhase {
    fun show(map: GameMap?, view: MemoryMapView) {
        view.setMap(map)
    }
}
