package com.edgard.sapos

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
    private var systemUiChannel: MethodChannel? = null
    private var audioChannel: MethodChannel? = null
    private var soundPool: SoundPool? = null
    private var tongueId = 0
    private var gulpId = 0
    private var boomId = 0
    private var ribbitId = 0
    private var buzzId = 0
    private var cheerId = 0
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
        systemUiChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SYSTEM_UI_CHANNEL,
        )
        systemUiChannel?.setMethodCallHandler { call, result ->
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
                else -> result.notImplemented()
            }
        }

        audioChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUDIO_CHANNEL,
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
        tongueId = pool.load(this, R.raw.tongue, 1)
        gulpId = pool.load(this, R.raw.gulp, 1)
        boomId = pool.load(this, R.raw.boom, 1)
        ribbitId = pool.load(this, R.raw.ribbit, 1)
        buzzId = pool.load(this, R.raw.buzz, 1)
        cheerId = pool.load(this, R.raw.cheer, 1)
        soundPool = pool
    }

    private fun playSound(name: String?) {
        val pool = soundPool ?: return
        val id = when (name) {
            "tongue" -> tongueId
            "gulp" -> gulpId
            "boom" -> boomId
            "ribbit" -> ribbitId
            "buzz" -> buzzId
            "cheer" -> cheerId
            else -> return
        }
        if (id == 0 || id !in loadedSoundIds) return
        val volume = when (name) {
            "boom" -> 0.9f
            "tongue" -> 0.75f
            "gulp" -> 0.8f
            "cheer" -> 0.7f
            "ribbit" -> 0.55f
            else -> 0.4f
        }
        pool.play(id, volume, volume, 1, 0, 1f)
    }

    private fun releaseSounds() {
        soundPool?.release()
        soundPool = null
        tongueId = 0
        gulpId = 0
        boomId = 0
        ribbitId = 0
        buzzId = 0
        cheerId = 0
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
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_BACK ||
            keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
            keyCode == KeyEvent.KEYCODE_VOLUME_DOWN
        ) {
            systemUiVisible = true
            applyVisibleSystemUi()
        }
        return super.onKeyDown(keyCode, event)
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
        private const val SYSTEM_UI_CHANNEL = "com.edgard.sapos/system_ui"
        private const val AUDIO_CHANNEL = "com.edgard.sapos/audio"
    }
}
