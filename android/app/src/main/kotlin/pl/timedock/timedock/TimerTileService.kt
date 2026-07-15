package pl.timedock.timedock

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/**
 * Quick Settings tile for the timer.
 *
 * - When a timer is running: the tile is ACTIVE and shows the current context;
 *   tapping it stops the timer (same path as the notification's STOP, so it
 *   works even if the app is dead).
 * - When idle: the tile is INACTIVE; tapping resumes the most recent context
 *   without opening the app (via [WidgetStartReceiver]), or opens the app to
 *   pick one when no recent context is known yet.
 */
class TimerTileService : TileService() {

    companion object {
        /** Ask the Quick Settings tile to re-read the timer state. */
        fun requestUpdate(context: Context) {
            try {
                TileService.requestListeningState(
                    context,
                    ComponentName(context, TimerTileService::class.java)
                )
            } catch (_: Exception) {
                // Tile not added / not available.
            }
        }
    }

    override fun onStartListening() {
        super.onStartListening()
        refresh()
    }

    override fun onClick() {
        super.onClick()
        if (TimerState.isActive(this)) {
            // Reuse the notification STOP path: record the stop instant, cancel
            // the notification, stop the service and poke Dart if alive.
            sendBroadcast(Intent(this, TimerStopReceiver::class.java))
            TimerService.stop(this)
            refresh()
        } else if (hasRecentContext()) {
            // Resume the most recent context without opening the app.
            sendBroadcast(
                Intent(this, WidgetStartReceiver::class.java)
                    .putExtra(WidgetStartReceiver.EXTRA_INDEX, 0)
            )
        } else {
            openApp()
        }
    }

    private fun hasRecentContext(): Boolean {
        val prefs = getSharedPreferences(
            WidgetStartReceiver.PREFS_FILE, Context.MODE_PRIVATE)
        val json = prefs.getString(WidgetStartReceiver.RECENT_KEY, null)
        return !json.isNullOrEmpty() && json != "[]"
    }

    private fun refresh() {
        val tile = qsTile ?: return
        val active = TimerState.isActive(this)
        tile.state = if (active) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = "TimeDock"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = if (active) TimerState.title(this) else "Zatrzymany"
        }
        tile.icon = Icon.createWithResource(this, R.mipmap.ic_launcher)
        tile.updateTile()
    }

    private fun openApp() {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
            ?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) } ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pending = PendingIntent.getActivity(
                this, 0, launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            startActivityAndCollapse(pending)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(launch)
        }
    }
}
