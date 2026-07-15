package pl.timedock.timedock

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray

/**
 * Home-screen widget mirroring the timer.
 *
 * Running: shows the context and a live chronometer (rendered by the launcher
 * host, so it ticks with no app process) plus a STOP button. Idle: shows up to
 * three recent contexts as one-tap start tiles (via [WidgetStartReceiver]), or
 * a hint when none are known yet; tapping the body opens the app. State comes
 * from [TimerState] so it is correct even when the process is dead; it is
 * refreshed on start/stop via [refresh].
 */
class TimerWidgetProvider : AppWidgetProvider() {

    companion object {
        /** Re-render every placed widget from the current [TimerState]. */
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val component = ComponentName(context, TimerWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            for (id in ids) {
                manager.updateAppWidget(id, buildViews(context))
            }
        }

        private fun buildViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.timer_widget)
            val active = TimerState.isActive(context)

            val openIntent =
                context.packageManager.getLaunchIntentForPackage(context.packageName)
            val openPending = openIntent?.let {
                PendingIntent.getActivity(
                    context, 0, it,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            }
            views.setOnClickPendingIntent(R.id.widget_root, openPending)

            if (active) {
                views.setTextViewText(R.id.widget_title, TimerState.title(context))
                views.setViewVisibility(R.id.widget_hint, View.GONE)
                views.setViewVisibility(R.id.widget_chrono, View.VISIBLE)
                views.setViewVisibility(R.id.widget_stop, View.VISIBLE)
                views.setTextColor(R.id.widget_stop, TILE_TEXT_COLOR)

                val elapsed = System.currentTimeMillis() - TimerState.startMillis(context)
                val base = SystemClock.elapsedRealtime() - elapsed
                views.setChronometer(R.id.widget_chrono, base, null, true)

                val stopPending = PendingIntent.getBroadcast(
                    context, 2,
                    Intent(context, TimerStopReceiver::class.java),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_stop, stopPending)
            } else {
                views.setTextViewText(R.id.widget_title, "TimeDock")
                views.setViewVisibility(R.id.widget_chrono, View.GONE)
                views.setViewVisibility(R.id.widget_stop, View.GONE)
                bindRecentTiles(context, views)
            }
            return views
        }

        private val tileIds = intArrayOf(
            R.id.widget_recent_0, R.id.widget_recent_1, R.id.widget_recent_2
        )

        // Dark blue, set in code because some launchers ignore the layout colour.
        private val TILE_TEXT_COLOR = 0xFF0D47A1.toInt()

        /** Fill the idle state with one-tap start tiles for recent contexts. */
        private fun bindRecentTiles(context: Context, views: RemoteViews) {
            val titles = readRecentTitles(context)
            if (titles.isEmpty()) {
                views.setViewVisibility(R.id.widget_recent, View.GONE)
                views.setViewVisibility(R.id.widget_hint, View.VISIBLE)
                views.setTextViewText(R.id.widget_hint, "Dotknij, aby rozpocząć")
                return
            }
            views.setViewVisibility(R.id.widget_hint, View.GONE)
            views.setViewVisibility(R.id.widget_recent, View.VISIBLE)
            for (i in tileIds.indices) {
                if (i < titles.size) {
                    val label = titles[i].ifBlank { "(bez nazwy)" }
                    views.setViewVisibility(tileIds[i], View.VISIBLE)
                    views.setTextViewText(tileIds[i], "▶  $label")
                    // Force a dark text colour: some launchers (ColorOS) default
                    // RemoteViews text to white, which is invisible on the white
                    // tile and ignores the layout's android:textColor.
                    views.setTextColor(tileIds[i], TILE_TEXT_COLOR)
                    val startIntent = Intent(context, WidgetStartReceiver::class.java)
                        .putExtra(WidgetStartReceiver.EXTRA_INDEX, i)
                    val pending = PendingIntent.getBroadcast(
                        context, 100 + i, startIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(tileIds[i], pending)
                } else {
                    views.setViewVisibility(tileIds[i], View.GONE)
                }
            }
        }

        private fun readRecentTitles(context: Context): List<String> {
            val prefs = context.getSharedPreferences(
                WidgetStartReceiver.PREFS_FILE, Context.MODE_PRIVATE)
            val json = prefs.getString(WidgetStartReceiver.RECENT_KEY, null)
                ?: return emptyList()
            return try {
                val arr = JSONArray(json)
                (0 until arr.length()).map { arr.getJSONObject(it).optString("title", "—") }
            } catch (e: Exception) {
                emptyList()
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context))
        }
    }
}
