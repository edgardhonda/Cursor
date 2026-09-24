package com.edgard.marcianos

import android.app.ActivityManager
import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var systemUiVisible = false
    private var methodChannel: MethodChannel? = null
    private var audioChannel: MethodChannel? = null
    private var soundPool: SoundPool? = null
    private var laserId = 0
    private var explosionId = 0
    private var saberId = 0
    private var chirpId = 0
    private val loadedSoundIds = mutableSetOf<Int>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes = window.attributes.apply {
                layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
        attachSystemUiGuard()
        applyHiddenSystemUi()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        )
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "hide" -> {
                    systemUiVisible = false
                    applyHiddenSystemUi()
                    result.success(null)
                }
                "show" -> {
                    systemUiVisible = true
                    applyVisibleSystemUi()
                    result.success(null)
                }
                "pinScreen" -> {
                    result.success(
                        try {
                            startLockTask()
                            true
                        } catch (_: Exception) {
                            false
                        },
                    )
                }
                "unpinScreen" -> {
                    try {
                        stopLockTask()
                    } catch (_: Exception) {
                    }
                    result.success(true)
                }
                "isPinned" -> result.success(isInLockTask())
                else -> result.notImplemented()
            }
        }

        audioChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUDIO_CHANNEL_NAME,
        )
        audioChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    initSounds()
                    result.success(null)
                }
                "play" -> {
                    val name = call.argument<String>("sound")
                    playSound(name)
                    result.success(null)
                }
                "dispose" -> {
                    releaseSounds()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun initSounds() {
        if (soundPool != null) return
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val pool = SoundPool.Builder()
            .setMaxStreams(6)
            .setAudioAttributes(attrs)
            .build()
        pool.setOnLoadCompleteListener { _, sampleId, status ->
            if (status == 0) loadedSoundIds.add(sampleId)
        }
        laserId = pool.load(this, R.raw.laser, 1)
        explosionId = pool.load(this, R.raw.explosion, 1)
        saberId = pool.load(this, R.raw.saber, 1)
        chirpId = pool.load(this, R.raw.chirp, 1)
        soundPool = pool
    }

    private fun playSound(name: String?) {
        val pool = soundPool ?: return
        val id = when (name) {
            "laser" -> laserId
            "explosion" -> explosionId
            "saber" -> saberId
            "chirp" -> chirpId
            else -> return
        }
        if (id == 0 || id !in loadedSoundIds) return
        val volume = when (name) {
            "explosion" -> 0.95f
            "laser" -> 0.75f
            "chirp" -> 0.55f
            else -> 0.6f
        }
        pool.play(id, volume, volume, 1, 0, 1f)
    }

    private fun releaseSounds() {
        soundPool?.release()
        soundPool = null
        laserId = 0
        explosionId = 0
        saberId = 0
        chirpId = 0
        loadedSoundIds.clear()
    }

    override fun onDestroy() {
        releaseSounds()
        super.onDestroy()
    }

    override fun onPostResume() {
        super.onPostResume()
        if (!systemUiVisible) applyHiddenSystemUi()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && !systemUiVisible) applyHiddenSystemUi()
        if (hasFocus) {
            methodChannel?.invokeMethod("pinStateChanged", isInLockTask())
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (isPhysicalButton(keyCode)) {
            systemUiVisible = true
            applyVisibleSystemUi()
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun isPhysicalButton(keyCode: Int): Boolean =
        keyCode == KeyEvent.KEYCODE_BACK ||
            keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
            keyCode == KeyEvent.KEYCODE_VOLUME_DOWN ||
            keyCode == KeyEvent.KEYCODE_VOLUME_MUTE ||
            keyCode == KeyEvent.KEYCODE_HOME ||
            keyCode == KeyEvent.KEYCODE_APP_SWITCH

    private fun isInLockTask(): Boolean {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            manager.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
        } else {
            @Suppress("DEPRECATION")
            manager.isInLockTaskMode
        }
    }

    private fun attachSystemUiGuard() {
        val decorView = window.decorView
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            decorView.setOnApplyWindowInsetsListener { view, insets ->
                val barsVisible =
                    insets.isVisible(WindowInsets.Type.statusBars()) ||
                        insets.isVisible(WindowInsets.Type.navigationBars())
                if (!systemUiVisible && barsVisible) {
                    view.post { applyHiddenSystemUi() }
                }
                view.onApplyWindowInsets(insets)
            }
        } else {
            @Suppress("DEPRECATION")
            decorView.setOnSystemUiVisibilityChangeListener {
                if (!systemUiVisible) decorView.post { applyHiddenSystemUi() }
            }
        }
    }

    private fun applyHiddenSystemUi() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                controller.hide(
                    WindowInsets.Type.statusBars() or
                        WindowInsets.Type.navigationBars(),
                )
                controller.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility =
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                    View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                    View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                    View.SYSTEM_UI_FLAG_FULLSCREEN
        }
    }

    private fun applyVisibleSystemUi() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.show(
                WindowInsets.Type.statusBars() or
                    WindowInsets.Type.navigationBars(),
            )
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility =
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        }
    }

    companion object {
        private const val CHANNEL_NAME = "com.edgard.marcianos/system_ui"
        private const val AUDIO_CHANNEL_NAME = "com.edgard.marcianos/audio"
    }
}
