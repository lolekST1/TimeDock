package pl.timedock.timedock

import android.app.PendingIntent
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
 * - When idle: the tile is INACTIVE; tapping opens the app so the user can pick
 *   a context and start (starting needs the UI, so we launch rather than guess).
 */
class TimerTileService : TileService() {

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
        } else {
            openApp()
        }
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
