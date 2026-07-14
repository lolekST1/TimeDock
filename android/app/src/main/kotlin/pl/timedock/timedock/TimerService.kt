package pl.timedock.timedock

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Minimal foreground service for the running timer.
 *
 * The elapsed-time counter uses the system chronometer
 * (setUsesChronometer + setWhen), so ANDROID renders the ticking clock —
 * no process needs to stay awake, which makes it immune to Doze and
 * aggressive OEM throttling (ColorOS etc.). The service itself does nothing
 * after posting the notification.
 */
class TimerService : Service() {

    companion object {
        const val CHANNEL_ID = "timedock_timer"
        const val NOTIFICATION_ID = 256
        const val ACTION_START = "pl.timedock.timedock.action.START"
        const val EXTRA_START_MILLIS = "startMillis"
        const val EXTRA_TITLE = "title"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_START) {
            val startMillis =
                intent.getLongExtra(EXTRA_START_MILLIS, System.currentTimeMillis())
            val title = intent.getStringExtra(EXTRA_TITLE) ?: "TimeDock"
            ensureChannel()
            val notification = buildNotification(title, startMillis)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        }
        // Redeliver the last intent if the system recreates the service, so
        // the notification comes back with the right start time and title.
        return START_REDELIVER_INTENT
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID,
                        "Aktywny timer",
                        NotificationManager.IMPORTANCE_LOW
                    ).apply {
                        description = "Pokazuje działający pomiar czasu"
                        setShowBadge(false)
                    }
                )
            }
        }
    }

    private fun buildNotification(title: String, startMillis: Long)
            : android.app.Notification {
        val openIntent = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stopIntent = PendingIntent.getBroadcast(
            this,
            1,
            Intent(this, TimerStopReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setSmallIcon(R.mipmap.ic_launcher)
            // System-rendered elapsed time; keeps ticking with zero CPU.
            .setUsesChronometer(true)
            .setWhen(startMillis)
            .setShowWhen(true)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(openIntent)
            .addAction(0, "STOP", stopIntent)
            .build()
    }
}
