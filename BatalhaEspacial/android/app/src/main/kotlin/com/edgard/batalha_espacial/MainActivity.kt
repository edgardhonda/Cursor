package com.edgard.batalha_espacial

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
    private val soundIds = mutableMapOf<String, Int>()
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
                    } catch (_: Exception) {}
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
                    playSound(call.argument("sound"))
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
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun initSounds() {
        if (soundPool != null) return
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val pool = SoundPool.Builder()
            .setMaxStreams(8)
            .setAudioAttributes(attrs)
            .build()
        pool.setOnLoadCompleteListener { _, sampleId, status ->
            if (status == 0) loadedSoundIds.add(sampleId)
        }
        soundIds["start"] = pool.load(this, R.raw.start, 1)
        soundIds["alert"] = pool.load(this, R.raw.alert, 1)
        soundIds["laser"] = pool.load(this, R.raw.laser, 1)
        soundIds["destroy"] = pool.load(this, R.raw.destroy, 1)
        soundIds["wrong"] = pool.load(this, R.raw.wrong, 1)
        soundIds["blast"] = pool.load(this, R.raw.blast, 1)
        soundPool = pool
    }

    private fun playSound(name: String?) {
        val pool = soundPool ?: return
        val id = soundIds[name] ?: return
        if (id == 0 || id !in loadedSoundIds) return
        val volume = when (name) {
            "alert" -> 0.72f
            "laser" -> 0.8f
            "destroy" -> 0.85f
            "wrong" -> 0.78f
            "blast" -> 0.9f
            else -> 0.7f
        }
        pool.play(id, volume, volume, 1, 0, 1f)
    }

    private fun releaseSounds() {
        soundPool?.release()
        soundPool = null
        soundIds.clear()
        loadedSoundIds.clear()
    }

    private fun isPhysicalButton(keyCode: Int): Boolean =
        keyCode == KeyEvent.KEYCODE_BACK ||
            keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
            keyCode == KeyEvent.KEYCODE_VOLUME_DOWN ||
            keyCode == KeyEvent.KEYCODE_VOLUME_MUTE

    private fun isInLockTask(): Boolean {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            am.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
        } else {
            @Suppress("DEPRECATION")
            am.isInLockTaskMode
        }
    }

    private fun attachSystemUiGuard() {
        window.decorView.setOnSystemUiVisibilityChangeListener {
            if (!systemUiVisible) applyHiddenSystemUi()
        }
    }

    private fun applyHiddenSystemUi() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                controller.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
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
                WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars(),
            )
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility =
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        }
    }

    companion object {
        private const val CHANNEL_NAME = "com.edgard.batalha_espacial/system_ui"
        private const val AUDIO_CHANNEL_NAME = "com.edgard.batalha_espacial/game_audio"
    }
}
