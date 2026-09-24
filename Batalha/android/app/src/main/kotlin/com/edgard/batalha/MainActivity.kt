package com.edgard.batalha

import android.media.AudioAttributes
import android.media.SoundPool
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var audioChannel: MethodChannel? = null
    private var soundPool: SoundPool? = null
    private val soundIds = mutableMapOf<String, Int>()
    private val loadedSoundIds = mutableSetOf<Int>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes = window.attributes.apply {
                layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
        hideSystemUi()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
        hideSystemUi()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) hideSystemUi()
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
        soundIds["cachorro"] = pool.load(this, R.raw.cachorro, 1)
        soundIds["soldado"] = pool.load(this, R.raw.soldado, 1)
        soundIds["cavaleiro"] = pool.load(this, R.raw.cavaleiro, 1)
        soundIds["gigante"] = pool.load(this, R.raw.gigante, 1)
        soundIds["arqueiro"] = pool.load(this, R.raw.arqueiro, 1)
        soundIds["canhao"] = pool.load(this, R.raw.canhao, 1)
        soundIds["vitoria"] = pool.load(this, R.raw.vitoria, 1)
        soundPool = pool
    }

    private fun playSound(name: String?) {
        val pool = soundPool ?: return
        val id = soundIds[name] ?: return
        if (id == 0 || id !in loadedSoundIds) return
        val volume = when (name) {
            "vitoria" -> 0.95f
            "canhao" -> 0.95f
            "gigante" -> 0.88f
            "cachorro" -> 0.72f
            else -> 0.82f
        }
        pool.play(id, volume, volume, 1, 0, 1f)
    }

    private fun releaseSounds() {
        soundPool?.release()
        soundPool = null
        soundIds.clear()
        loadedSoundIds.clear()
    }

    private fun hideSystemUi() {
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

    companion object {
        private const val AUDIO_CHANNEL_NAME = "com.edgard.batalha/game_audio"
    }
}
