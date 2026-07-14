package pl.timedock.timedock

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
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
            when (call.method) {
                "start" -> {
                    requestNotificationPermissionIfNeeded()
                    val start = (call.argument<Number>("startMillis"))?.toLong()
                        ?: System.currentTimeMillis()
                    val title = call.argument<String>("title") ?: "TimeDock"
                    val intent = Intent(this, TimerService::class.java)
                        .setAction(TimerService.ACTION_START)
                        .putExtra(TimerService.EXTRA_START_MILLIS, start)
                        .putExtra(TimerService.EXTRA_TITLE, title)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stop" -> {
                    stopService(Intent(this, TimerService::class.java))
                    result.success(null)
                }
                "takePendingStop" -> {
                    // Read + clear natively to bypass the Dart-side prefs cache.
                    val prefs = getSharedPreferences(
                        TimerStopReceiver.PREFS_FILE, MODE_PRIVATE)
                    val value = prefs.getLong(TimerStopReceiver.PENDING_STOP_KEY, -1L)
                    if (value > 0) {
                        prefs.edit().remove(TimerStopReceiver.PENDING_STOP_KEY).apply()
                        result.success(value)
                    } else {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
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
