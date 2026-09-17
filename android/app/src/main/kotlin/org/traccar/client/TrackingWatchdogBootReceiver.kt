package org.traccar.client

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Re-arms liveness recovery after alarms are cleared by reboot/app update. */
class TrackingWatchdogBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            -> TrackingWatchdogScheduler.schedule(context)
        }
    }
}
