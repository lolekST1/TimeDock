package pl.timedock.timedock

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.quicksettings.TileService
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private var channel: MethodChannel? = null

        /** Called from [TimerStopReceiver]; no-op when the engine is gone. */
        fun notifyStopRequested() {
            Handler(Looper.getMainLooper()).post {
                channel?.invokeMethod("stopRequested", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "timedock/timer_service"
        )
        channel = ch
        ch.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> {
                        requestNotificationPermissionIfNeeded()
                        val start = (call.argument<Number>("startMillis"))?.toLong()
                            ?: System.currentTimeMillis()
                        val title = call.argument<String>("title") ?: "TimeDock"
                        // Post the clock directly first (guaranteed to appear),
                        // then run the foreground service which adopts it and
                        // keeps the process unfrozen so the reminder can fire.
                        TimerNotification.show(this, title, start)
                        TimerState.setActive(this, title, start)
                        TimerService.start(this, title, start)
                        requestTileListeningUpdate()
                        result.success(null)
                    }
                    "stop" -> {
                        TimerState.setInactive(this)
                        TimerNotification.cancel(this)
                        TimerService.stop(this)
                        requestTileListeningUpdate()
                        result.success(null)
                    }
                    "takePendingStop" -> {
                        // Read + clear natively to bypass the Dart prefs cache.
                        val prefs = getSharedPreferences(
                            TimerStopReceiver.PREFS_FILE, MODE_PRIVATE)
                        val value =
                            prefs.getLong(TimerStopReceiver.PENDING_STOP_KEY, -1L)
                        if (value > 0) {
                            prefs.edit()
                                .remove(TimerStopReceiver.PENDING_STOP_KEY)
                                .apply()
                            result.success(value)
                        } else {
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("timer_service", e.message, null)
            }
        }
    }

    /** Nudge the Quick Settings tile to re-read the timer state. */
    private fun requestTileListeningUpdate() {
        try {
            TileService.requestListeningState(
                this,
                android.content.ComponentName(this, TimerTileService::class.java)
            )
        } catch (_: Exception) {
            // Tile not added / not available: nothing to refresh.
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                this, Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 100)
        }
    }

    override fun onDestroy() {
        channel = null
        super.onDestroy()
    }
}
