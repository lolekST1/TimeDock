package pl.timedock.timedock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONArray
import org.json.JSONObject

/**
 * Handles a recent context tapped on the home-screen widget, without opening
 * the app.
 *
 * - No timer running: starts a new session for the context.
 * - A timer already running: switches the running timer's context in place,
 *   keeping the elapsed time (the domain's switchContext), rather than
 *   restarting the clock.
 *
 * Mirrors the pending-stop pattern: the intent (context + instant + mode) is
 * recorded natively ([PENDING_START_KEY]) and the visible surfaces (clock
 * notification, foreground service, widget) are updated immediately; the Dart
 * side applies it to the database — the source of truth — as soon as it is
 * poked (app alive) or on the next launch/resume ([MainActivity] /
 * applyPendingStart).
 */
class WidgetStartReceiver : BroadcastReceiver() {

    companion object {
        const val PREFS_FILE = "FlutterSharedPreferences"
        const val PENDING_START_KEY = "flutter.pending_start"
        const val RECENT_KEY = "flutter.widget_recent_contexts"
        const val EXTRA_INDEX = "index"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val index = intent.getIntExtra(EXTRA_INDEX, 0)
        val prefs = context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
        val json = prefs.getString(RECENT_KEY, null) ?: return
        val item = try {
            val arr = JSONArray(json)
            if (index < 0 || index >= arr.length()) return
            arr.getJSONObject(index)
        } catch (e: Exception) {
            return
        }

        // Switch in place if a timer is already running: keep the original
        // start so the clock does not reset, just re-label it.
        val switching = TimerState.isActive(context)
        val startMillis =
            if (switching) TimerState.startMillis(context)
            else System.currentTimeMillis()
        val title = item.optString("title", "TimeDock")

        val pending = JSONObject().apply {
            put("workspaceId", item.getString("workspaceId"))
            put("projectId", item.getString("projectId"))
            if (!item.isNull("subProjectId")) {
                put("subProjectId", item.getString("subProjectId"))
            }
            if (!item.isNull("taskId")) put("taskId", item.getString("taskId"))
            put("startMillis", startMillis)
            put("mode", if (switching) "switch" else "start")
        }
        prefs.edit().putString(PENDING_START_KEY, pending.toString()).apply()

        // Immediate visible feedback. The clock is posted first (always works);
        // the foreground service (which arms the wake lock + reminder) may be
        // refused if the OS doesn't grant this tap an FGS-start exemption — then
        // it starts on next app launch/resume instead, so swallow that.
        TimerState.setActive(context, title, startMillis)
        TimerNotification.show(context, title, startMillis)
        try {
            TimerService.start(context, title, startMillis)
        } catch (e: Exception) {
            // Foreground service start not allowed from here; deferred to launch.
        }
        TimerWidgetProvider.refresh(context)

        // Create the DB session now if the app is alive; else on next launch.
        MainActivity.notifyStartRequested()
    }
}
