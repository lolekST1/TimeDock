package pl.timedock.timedock

import android.content.Context

/**
 * Tiny persisted mirror of whether a timer is running, plus its title and
 * start instant. Stored in the same file flutter's shared_preferences uses
 * (with the "flutter." key prefix) so both the Dart side and the native
 * services/tile read a single source of truth — it stays correct even when the
 * app process is dead (e.g. Quick Settings tile queried by the system).
 */
object TimerState {
    private const val PREFS_FILE = "FlutterSharedPreferences"
    private const val ACTIVE_KEY = "flutter.timer_active"
    private const val TITLE_KEY = "flutter.timer_title"
    private const val START_KEY = "flutter.timer_start_millis"

    fun setActive(context: Context, title: String, startMillis: Long) {
        context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(ACTIVE_KEY, true)
            .putString(TITLE_KEY, title)
            .putLong(START_KEY, startMillis)
            .apply()
    }

    fun setInactive(context: Context) {
        context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(ACTIVE_KEY, false)
            .apply()
    }

    fun isActive(context: Context): Boolean =
        context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
            .getBoolean(ACTIVE_KEY, false)

    fun title(context: Context): String =
        context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
            .getString(TITLE_KEY, null) ?: "TimeDock"

    fun startMillis(context: Context): Long =
        context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
            .getLong(START_KEY, System.currentTimeMillis())
}
