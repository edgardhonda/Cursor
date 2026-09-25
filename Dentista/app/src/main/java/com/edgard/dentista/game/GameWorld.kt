package com.edgard.dentista.game

import com.edgard.dentista.audio.GameAudio
import kotlin.math.hypot
import kotlin.math.sin
import kotlin.random.Random

enum class PlayState {
    MENU,
    PLAYING,
    LOST,
}

class Tooth(
    val id: Int,
    val upper: Boolean,
    val nx: Float,
    val ny: Float,
    val nw: Float,
    val nh: Float,
) {
    var damage: Int = 0
    val destroyed: Boolean get() = damage >= 10
}

class Cavity(
    val id: Int,
    var nx: Float,
    var ny: Float,
    var targetId: Int,
    val seed: Int,
    var attached: Boolean = false,
    var t: Float = 0f,
    var chew: Float = 0f,
    var rubs: Int = 0,
    var rubDist: Float = 0f,
    var dirX: Float = 0f,
    var dirY: Float = 0f,
)

class Popup(
    var nx: Float,
    var ny: Float,
    val text: String,
    var life: Float = 0.9f,
)

class GameWorld {
    val teeth = ArrayList<Tooth>(16)
    val cavities = ArrayList<Cavity>(16)
    val popups = ArrayList<Popup>(8)
    var state: PlayState = PlayState.MENU
    var cleaned: Int = 0
    var brushOn: Boolean = false
    var brushNx: Float = 0f
    var brushNy: Float = 0f
    var brushAngle: Float = 0f
    var brushTooth: Int = -1
    var brushShow: Float = 0f
    var strokes: Int = 0
    var audio: GameAudio? = null

    private var lastNx: Float = 0f
    private var lastNy: Float = 0f
    private var scrubId: Int = -1
    private var spawnWait: Float = 0f
    private var nextBugId: Int = 1
    private val rng = Random(System.nanoTime())

    fun focusedCavity(): Cavity? {
        if (scrubId < 0) return null
        for (bug in cavities) if (bug.id == scrubId) return bug
        return null
    }

    init {
        layoutTeeth()
    }

    fun play() {
        teeth.forEach { it.damage = 0 }
        cavities.clear()
        popups.clear()
        cleaned = 0
        brushOn = false
        brushShow = 0f
        brushTooth = -1
        scrubId = -1
        strokes = 0
        spawnWait = 0f
        state = PlayState.PLAYING
        spawnOne()
        spawnOne()
    }

    fun livingCount(): Int = teeth.count { !it.destroyed }

    fun pointerDown(nx: Float, ny: Float) {
        if (state != PlayState.PLAYING) return
        lastNx = nx
        lastNy = ny
        followFinger(nx, ny)
        lockBug(pickBug(nx, ny))
    }

    fun pointerMove(nx: Float, ny: Float) {
        if (state != PlayState.PLAYING) return
        val dx = nx - lastNx
        val dy = ny - lastNy
        val len = hypot(dx, dy)
        followFinger(nx, ny)
        lastNx = nx
        lastNy = ny
        var bug = focusedCavity()
        if (bug == null) {
            bug = pickBug(nx, ny)
            lockBug(bug)
        }
        if (bug == null || len < 0.0007f) return
        brushAngle = kotlin.math.atan2(dy, dx)
        addScrubMotion(bug, dx / len, dy / len, len)
        strokes = focusedCavity()?.rubs ?: 0
    }

    fun pointerUp(nx: Float, ny: Float) {
        brushOn = false
        lastNx = nx
        lastNy = ny
        scrubId = -1
        brushTooth = -1
    }

    private fun lockBug(bug: Cavity?) {
        if (bug == null) {
            scrubId = -1
            brushTooth = -1
            strokes = 0
            return
        }
        if (scrubId == bug.id) {
            strokes = bug.rubs
            return
        }
        scrubId = bug.id
        brushTooth = bug.targetId
        strokes = bug.rubs
        bug.dirX = 0f
        bug.dirY = 0f
        bug.rubDist = 0f
    }

    private fun followFinger(nx: Float, ny: Float) {
        brushOn = true
        brushShow = 0.85f
        brushNx = nx
        brushNy = ny
    }

    private fun toothById(id: Int): Tooth? {
        for (tooth in teeth) if (tooth.id == id) return tooth
        return null
    }

    private fun toothAt(nx: Float, ny: Float): Tooth? {
        var best: Tooth? = null
        var bestD = 0.095f
        for (tooth in teeth) {
            if (tooth.destroyed) continue
            val d = hypot(nx - tooth.nx, ny - tooth.ny)
            if (d < bestD) {
                bestD = d
                best = tooth
            }
        }
        return best
    }

    private fun pickBug(nx: Float, ny: Float): Cavity? {
        val onTooth = toothAt(nx, ny)
        var best: Cavity? = null
        var bestScore = Float.POSITIVE_INFINITY
        for (bug in cavities) {
            val tooth = toothById(bug.targetId) ?: continue
            if (tooth.destroyed) continue
            val dBug = hypot(nx - bug.nx, ny - bug.ny)
            val sameTooth = onTooth != null && onTooth.id == tooth.id
            if (!sameTooth && dBug > 0.085f) continue
            if (sameTooth && dBug > 0.18f) continue
            var score = dBug
            if (!bug.attached) score += 0.22f
            if (sameTooth) score -= 0.14f
            if (score < bestScore) {
                bestScore = score
                best = bug
            }
        }
        return best
    }

    private fun addScrubMotion(bug: Cavity, ndx: Float, ndy: Float, len: Float) {
        bug.rubDist += len
        val dirLen = hypot(bug.dirX, bug.dirY)
        if (dirLen < 0.001f) {
            bug.dirX = ndx
            bug.dirY = ndy
            return
        }
        val rev = ndx * bug.dirX + ndy * bug.dirY
        if (rev < 0f && bug.rubDist >= 0.010f) {
            bug.dirX = ndx
            bug.dirY = ndy
            addRub(bug)
            return
        }
        if (rev >= 0f) {
            bug.dirX = ndx
            bug.dirY = ndy
        }
        if (bug.rubDist >= 0.020f) addRub(bug)
    }

    private fun addRub(bug: Cavity) {
        if (bug !in cavities || bug.rubs >= 5) return
        bug.rubs++
        bug.rubDist = 0f
        strokes = bug.rubs
        audio?.brush()
        if (bug.rubs >= 5) cleanBug(bug)
    }

    private fun cleanBug(bug: Cavity) {
        if (!cavities.remove(bug)) return
        popups += Popup(bug.nx, bug.ny, "Limpo!")
        cleaned++
        audio?.clean()
        val keepBrushing = scrubId == bug.id && brushOn
        if (scrubId == bug.id) {
            scrubId = -1
            brushTooth = -1
        }
        strokes = 0
        spawnWait = minOf(spawnWait, 0.12f)
        if (keepBrushing) lockBug(pickBug(brushNx, brushNy))
    }

    fun update(dt: Float) {
        val capped = dt.coerceIn(0.001f, 0.05f)
        if (state != PlayState.PLAYING) {
            popups.forEach { it.life -= capped }
            popups.removeAll { it.life <= 0f }
            return
        }
        if (!brushOn) brushShow = (brushShow - capped).coerceAtLeast(0f)
        spawnWait -= capped
        maybeSpawn()
        val it = cavities.iterator()
        while (it.hasNext()) {
            val bug = it.next()
            bug.t += capped
            var tooth = toothById(bug.targetId)
            if (tooth == null || tooth.destroyed) {
                tooth = retarget(bug)
                if (tooth == null) {
                    dropBug(bug)
                    it.remove()
                    if (livingCount() == 0) state = PlayState.LOST
                    continue
                }
            }
            if (!bug.attached) {
                if (scrubId == bug.id && brushOn) continue
                crawl(bug, tooth, capped)
            } else {
                chew(bug, tooth, capped, it)
            }
        }
        val pit = popups.iterator()
        while (pit.hasNext()) {
            val p = pit.next()
            p.life -= capped
            p.ny -= capped * 0.12f
            if (p.life <= 0f) pit.remove()
        }
        maybeSpawn()
        if (livingCount() == 0 && state == PlayState.PLAYING) state = PlayState.LOST
    }

    private fun crawl(bug: Cavity, tooth: Tooth, dt: Float) {
        val dx = tooth.nx - bug.nx
        val dy = tooth.ny - bug.ny
        val dist = hypot(dx, dy)
        if (dist < 0.04f || dist == 0f) {
            bug.attached = true
            bug.nx = tooth.nx
            bug.ny = tooth.ny
            return
        }
        val speed = 0.55f + 0.08f * sin(bug.t * 5f)
        bug.nx += dx / dist * speed * dt
        bug.ny += dy / dist * speed * dt
        bug.nx += sin(bug.t * 9f + bug.seed) * 0.04f * dt
        bug.ny += sin(bug.t * 7f + 2f) * 0.03f * dt
    }

    private fun chew(bug: Cavity, tooth: Tooth, dt: Float, it: MutableIterator<Cavity>) {
        val ox = ((bug.seed and 7) - 3) * 0.016f
        val oy = ((bug.seed shr 3 and 7) - 3) * 0.014f
        bug.nx = tooth.nx + ox + sin(bug.t * 8f) * 0.005f
        bug.ny = tooth.ny + oy + sin(bug.t * 7f + 1f) * 0.004f
        bug.chew += if (scrubId == bug.id && brushOn) 0f else dt
        if (bug.chew < 1.15f) return
        bug.chew = 0f
        if (tooth.damage >= 10) return
        tooth.damage++
        if (!tooth.destroyed) return
        dropBug(bug)
        it.remove()
        if (livingCount() == 0) state = PlayState.LOST
    }

    private fun dropBug(bug: Cavity) {
        if (scrubId == bug.id) {
            scrubId = -1
            strokes = 0
        }
    }

    private fun retarget(bug: Cavity): Tooth? {
        val next = nextTarget() ?: return null
        bug.targetId = next.id
        bug.attached = false
        bug.chew = 0f
        return next
    }

    private fun desiredCavities(): Int {
        val n = livingCount()
        if (n <= 0) return 0
        return (n + 1).coerceIn(3, 8)
    }

    private fun maybeSpawn() {
        if (state != PlayState.PLAYING) return
        val want = desiredCavities()
        if (cavities.size >= want || spawnWait > 0f) return
        if (spawnOne()) spawnWait = 0.42f
    }

    private fun nextTarget(): Tooth? {
        val living = teeth.filter { !it.destroyed }
        if (living.isEmpty()) return null
        val free = living.filter { tooth -> cavities.none { it.targetId == tooth.id } }
        val pool = if (free.isNotEmpty()) free else living
        return pool.minByOrNull { tooth -> cavities.count { it.targetId == tooth.id } }
    }

    private fun spawnOne(): Boolean {
        val target = nextTarget() ?: return false
        val corners = arrayOf(
            0.00f to 0.50f,
            1.00f to 0.50f,
            0.00f to 0.12f,
            1.00f to 0.12f,
            0.00f to 0.88f,
            1.00f to 0.88f,
        )
        val from = corners[rng.nextInt(corners.size)]
        val jx = (rng.nextFloat() - 0.5f) * 0.06f
        val jy = (rng.nextFloat() - 0.5f) * 0.08f
        cavities += Cavity(
            id = nextBugId++,
            nx = (from.first + jx).coerceIn(0f, 1f),
            ny = (from.second + jy).coerceIn(0.08f, 0.92f),
            targetId = target.id,
            seed = rng.nextInt(),
        )
        return true
    }

    private fun layoutTeeth() {
        teeth.clear()
        val count = 8
        for (i in 0 until count) {
            val t = (i + 0.5f) / count
            val x = 0.14f + t * 0.72f
            val w = if (i == 0 || i == count - 1) 0.068f else if (i == 3 || i == 4) 0.078f else 0.072f
            val h = if (i == 3 || i == 4) 0.16f else 0.15f
            val arc = sin(t * Math.PI.toFloat()) * 0.035f
            teeth += Tooth(i, true, x, 0.27f + arc, w, h)
            teeth += Tooth(i + count, false, x, 0.73f - arc, w, h)
        }
    }
}
