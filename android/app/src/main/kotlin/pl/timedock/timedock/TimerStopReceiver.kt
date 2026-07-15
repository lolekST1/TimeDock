package pl.timedock.timedock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Handles the STOP action on the timer notification.
 *
 * Records the exact stop instant in the plugin-visible SharedPreferences file
 * so the session gets closed at the moment the user pressed STOP even if the
 * Dart side is frozen or dead (the app applies the pending stop on next
 * launch/resume), removes the notification, and pokes the Dart side if alive.
 */
class TimerStopReceiver : BroadcastReceiver() {

    companion object {
        const val PENDING_STOP_KEY = "flutter.pending_stop_millis"
        const val PREFS_FILE = "FlutterSharedPreferences"
    }

    override fun onReceive(context: Context, intent: Intent) {
        context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
            .edit()
            .putLong(PENDING_STOP_KEY, System.currentTimeMillis())
            .apply()

        TimerState.setInactive(context)
        TimerNotification.cancel(context)
        TimerService.stop(context)

        MainActivity.notifyStopRequested()
    }
}
