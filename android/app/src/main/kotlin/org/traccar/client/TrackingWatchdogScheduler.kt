package org.traccar.client

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock

/**
 * Schedules a low-frequency liveness check for background tracking.
 *
 * This intentionally uses an inexact allow-while-idle alarm. The watchdog is
 * recovery infrastructure, not a wall-clock schedule, so it does not require
 * exact-alarm permission and its interval is a minimum while the device is in
 * Doze.
 */
object TrackingWatchdogScheduler {
    const val INTERVAL_MS = 15 * 60_000L

    private const val REQUEST_CODE = 0x7AC1

    fun schedule(context: Context) {
        val appContext = context.applicationContext
        val alarmManager = appContext.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: return
        val pendingIntent = pendingIntent(appContext)
        val triggerAt = SystemClock.elapsedRealtime() + INTERVAL_MS

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                triggerAt,
                pendingIntent,
            )
        } else {
            alarmManager.set(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                triggerAt,
                pendingIntent,
            )
        }
    }

    fun cancel(context: Context) {
        val appContext = context.applicationContext
        val alarmManager = appContext.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: return
        alarmManager.cancel(pendingIntent(appContext))
    }

    private fun pendingIntent(context: Context): PendingIntent {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            Intent(context, TrackingWatchdogReceiver::class.java),
            flags,
        )
    }
}
