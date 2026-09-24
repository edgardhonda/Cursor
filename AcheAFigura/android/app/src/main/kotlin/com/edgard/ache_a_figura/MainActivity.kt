package com.edgard.ache_a_figura

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
    private lateinit var soundPool: SoundPool
    private val soundIds = mutableMapOf<String, Int>()
    private val activeStreams = mutableSetOf<Int>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initializeSounds()
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
            SYSTEM_UI_CHANNEL,
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
                "pinScreen" -> result.success(
                    try {
                        startLockTask()
                        true
                    } catch (_: Exception) {
                        false
                    },
                )
                "unpinScreen" -> {
                    try {
                        stopLockTask()
                    } catch (_: Exception) {}
                    result.success(true)
                }
                "isPinned" -> result.success(isInLockTask())
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUDIO_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "playSound" -> {
                    playSound(call.arguments as? String)
                    result.success(null)
                }
                "pauseAll" -> {
                    soundPool.autoPause()
                    result.success(null)
                }
                "resumeAll" -> {
                    soundPool.autoResume()
                    result.success(null)
                }
                "stopAll" -> {
                    stopAllSounds()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        stopAllSounds()
        soundPool.release()
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

    private fun initializeSounds() {
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        soundPool = SoundPool.Builder()
            .setMaxStreams(8)
            .setAudioAttributes(attributes)
            .build()
        soundIds["tada"] = soundPool.load(this, R.raw.tada, 1)
        soundIds["failure"] = soundPool.load(this, R.raw.failure, 1)
        soundIds["success"] = soundPool.load(this, R.raw.success, 1)
    }

    private fun playSound(name: String?) {
        val soundId = soundIds[name] ?: return
        val volume = when (name) {
            "failure" -> 0.76f
            "tada" -> 0.55f
            "success" -> 0.9f
            else -> 0.9f
        }
        val streamId = soundPool.play(soundId, volume, volume, 1, 0, 1f)
        if (streamId != 0) activeStreams.add(streamId)
    }

    private fun stopAllSounds() {
        activeStreams.forEach(soundPool::stop)
        activeStreams.clear()
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
        private const val SYSTEM_UI_CHANNEL =
            "com.edgard.ache_a_figura/system_ui"
        private const val AUDIO_CHANNEL =
            "com.edgard.ache_a_figura/game_audio"
    }
}
