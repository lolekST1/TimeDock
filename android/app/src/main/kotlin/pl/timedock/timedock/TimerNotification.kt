package pl.timedock.timedock

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/**
 * The ongoing timer notification, posted directly (no foreground service).
 *
 * The elapsed time uses the system chronometer (setUsesChronometer+setWhen),
 * so ANDROID renders the ticking clock: no app process needs to run, which
 * makes it immune to Doze and aggressive OEM throttling/killing (a plain
 * notification lives in system UI and survives even process death).
 */
object TimerNotification {

    // v2: a fresh channel id, since the previous app version registered the
    // old id via a plugin with settings we can no longer change.
    private const val CHANNEL_ID = "timedock_timer_v2"
    const val ID = 256

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID,
                        "Aktywny timer",
                        NotificationManager.IMPORTANCE_DEFAULT
                    ).apply {
                        description = "Pokazuje działający pomiar czasu"
                        setShowBadge(false)
                        setSound(null, null)
                        enableVibration(false)
                    }
                )
            }
        }
    }

    fun show(context: Context, title: String, startMillis: Long) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                context, Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return // no permission yet; caller requests it and retries later
        }
        ensureChannel(context)

        val launchIntent =
            context.packageManager.getLaunchIntentForPackage(context.packageName)
        val openIntent = launchIntent?.let {
            PendingIntent.getActivity(
                context, 0, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
        val stopIntent = PendingIntent.getBroadcast(
            context, 1,
            Intent(context, TimerStopReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setSmallIcon(R.mipmap.ic_launcher)
            // System-rendered elapsed time; ticks forever with zero CPU.
            .setUsesChronometer(true)
            .setWhen(startMillis)
            .setShowWhen(true)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(openIntent)
            .addAction(0, "STOP", stopIntent)
            .build()

        NotificationManagerCompat.from(context).notify(ID, notification)
    }

    fun cancel(context: Context) =
        NotificationManagerCompat.from(context).cancel(ID)
}
