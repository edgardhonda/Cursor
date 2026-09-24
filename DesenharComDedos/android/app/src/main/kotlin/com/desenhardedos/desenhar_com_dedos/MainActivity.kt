package com.desenhardedos.desenhar_com_dedos

import android.app.ActivityManager
import android.content.Context
import android.graphics.Rect
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.KeyEvent
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "com.desenhardedos.desenhar_com_dedos/system_ui"
    private val storageChannelName = "com.desenhardedos.desenhar_com_dedos/storage"
    private val drawingFileName = "drawing.json"
    private var systemUiVisible = false
    private var guardAttached = false
    private var methodChannel: MethodChannel? = null

    private val hideHandler = Handler(Looper.getMainLooper())
    private val keepHiddenRunnable = object : Runnable {
        override fun run() {
            if (!systemUiVisible) {
                applyHiddenSystemUi()
                // Reocultação imediata (sem atraso) para minimizar o tempo visível.
                hideHandler.post(this)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes = window.attributes.apply {
                layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        attachSystemUiGuard()
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "hide" -> {
                    systemUiVisible = false
                    applyHiddenSystemUi()
                    startKeepingHidden()
                    result.success(null)
                }
                "show" -> {
                    systemUiVisible = true
                    stopKeepingHidden()
                    applyVisibleSystemUi()
                    result.success(null)
                }
                "pinScreen" -> {
                    val ok = try {
                        startLockTask()
                        true
                    } catch (e: Exception) {
                        false
                    }
                    result.success(ok)
                }
                "unpinScreen" -> {
                    try {
                        stopLockTask()
                    } catch (e: Exception) {
                        // ignora — pode já estar desafixado
                    }
                    result.success(true)
                }
                "isPinned" -> {
                    result.success(isInLockTask())
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, storageChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "save" -> {
                        val data = call.argument<String>("data") ?: ""
                        val ok = try {
                            File(filesDir, drawingFileName).writeText(data)
                            true
                        } catch (e: Exception) {
                            false
                        }
                        result.success(ok)
                    }
                    "load" -> {
                        val content = try {
                            val file = File(filesDir, drawingFileName)
                            if (file.exists()) file.readText() else null
                        } catch (e: Exception) {
                            null
                        }
                        result.success(content)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isInLockTask(): Boolean {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            am.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
        } else {
            @Suppress("DEPRECATION")
            am.isInLockTaskMode
        }
    }

    override fun onPostResume() {
        super.onPostResume()
        if (!systemUiVisible) {
            applyHiddenSystemUi()
            startKeepingHidden()
        }
        updateGestureExclusion()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && !systemUiVisible) {
            applyHiddenSystemUi()
            startKeepingHidden()
        }
        if (hasFocus) {
            updateGestureExclusion()
            methodChannel?.invokeMethod("pinStateChanged", isInLockTask())
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (isPhysicalButton(keyCode)) {
            systemUiVisible = true
            stopKeepingHidden()
            applyVisibleSystemUi()
            return super.onKeyDown(keyCode, event)
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun isPhysicalButton(keyCode: Int): Boolean {
        return keyCode == KeyEvent.KEYCODE_BACK ||
            keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
            keyCode == KeyEvent.KEYCODE_VOLUME_DOWN ||
            keyCode == KeyEvent.KEYCODE_VOLUME_MUTE ||
            keyCode == KeyEvent.KEYCODE_HOME ||
            keyCode == KeyEvent.KEYCODE_APP_SWITCH
    }

    private fun startKeepingHidden() {
        hideHandler.removeCallbacks(keepHiddenRunnable)
        hideHandler.post(keepHiddenRunnable)
    }

    private fun stopKeepingHidden() {
        hideHandler.removeCallbacks(keepHiddenRunnable)
    }

    private fun attachSystemUiGuard() {
        if (guardAttached) return
        guardAttached = true

        val decorView = window.decorView
        decorView.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ ->
            updateGestureExclusion()
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            decorView.setOnApplyWindowInsetsListener { view, insets ->
                val barsVisible = insets.isVisible(WindowInsets.Type.statusBars()) ||
                    insets.isVisible(WindowInsets.Type.navigationBars())
                if (!systemUiVisible && barsVisible) {
                    view.post { applyHiddenSystemUi() }
                }
                view.onApplyWindowInsets(insets)
            }
        } else {
            @Suppress("DEPRECATION")
            decorView.setOnSystemUiVisibilityChangeListener {
                if (!systemUiVisible) {
                    decorView.post { applyHiddenSystemUi() }
                }
            }
        }
    }

    private fun updateGestureExclusion() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val decorView = window.decorView
        val height = decorView.height
        val width = decorView.width
        if (height <= 0 || width <= 0) return

        val exclusionPx = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            GESTURE_EXCLUSION_DP,
            resources.displayMetrics,
        ).toInt()

        decorView.systemGestureExclusionRects = listOf(
            Rect(0, 0, width, exclusionPx),
            Rect(0, height - exclusionPx, width, height),
        )
    }

    private fun applyHiddenSystemUi() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                controller.hide(
                    WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars(),
                )
                controller.systemBarsBehavior = WindowInsetsController.BEHAVIOR_DEFAULT
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_FULLSCREEN
                )
        }
    }

    private fun applyVisibleSystemUi() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.show(
                WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars(),
            )
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.decorView.systemGestureExclusionRects = emptyList()
        }
    }

    companion object {
        private const val GESTURE_EXCLUSION_DP = 48f
    }
}
