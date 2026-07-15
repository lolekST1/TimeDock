package pl.timedock.timedock

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * Foreground service that runs for the lifetime of a running timer.
 *
 * Its purpose is NOT the notification (that is posted directly by
 * [TimerNotification.show] so it appears even if this service is delayed) but
 * keeping the app process out of the frozen/cached state. OEMs like
 * ColorOS/Oppo freeze a plain backgrounded app, which holds its AlarmManager
 * alarms until the app is reopened — the reason the forgotten-timer reminder
 * used to only appear on resume. While a foreground service runs the process
 * is exempt, so the reminder alarm fires on time in the background.
 *
 * It adopts the existing notification [TimerNotification.ID] as its foreground
 * notification, so no second notification appears.
 */
class TimerService : Service() {

    companion object {
        private const val EXTRA_START_MILLIS = "startMillis"
        private const val EXTRA_TITLE = "title"

        fun start(context: Context, title: String, startMillis: Long) {
            val intent = Intent(context, TimerService::class.java).apply {
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_START_MILLIS, startMillis)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, TimerService::class.java))
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        acquireWakeLock()

        val startMillis =
            intent?.getLongExtra(EXTRA_START_MILLIS, System.currentTimeMillis())
                ?: TimerState.startMillis(this)
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: TimerState.title(this)

        val notification = TimerNotification.build(this, title, startMillis)
        // startForeground must be called within ~5s of startForegroundService.
        when {
            Build.VERSION.SDK_INT >= 34 -> startForeground(
                TimerNotification.ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q -> startForeground(
                TimerNotification.ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
            else -> startForeground(TimerNotification.ID, notification)
        }

        // Rebuild with the last intent if the system restarts us, so the
        // notification returns with the correct start time and title.
        return START_REDELIVER_INTENT
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK, "timedock:timer"
        ).also { it.acquire() }
    }

    override fun onDestroy() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onDestroy()
    }
}
