package org.traccar.client

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Checks that the service implied by the persisted tracking intent is alive.
 *
 * The SDK persists tracker state independently from the Flutter UI. If the
 * process/service is killed, [sharedTracker] reconstructs the SDK graph from
 * persisted config/state. Starting [TrackerService] again is idempotent when
 * it is already alive and repairs the service when Android removed it.
 */
class TrackingWatchdogReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        val appContext = context.applicationContext

        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            var keepArmed = false
            try {
                val tracker = sharedTracker()
                if (tracker == null) {
                    Log.d(TAG, "No persisted tracker configuration; watchdog disarmed")
                    return@launch
                }

                keepArmed = tracker.state.value.enabled
                if (!keepArmed) {
                    Log.d(TAG, "Tracking is explicitly disabled; watchdog disarmed")
                    TrackingWatchdogScheduler.cancel(appContext)
                    return@launch
                }

                if (!hasLocationPermission(appContext)) {
                    Log.w(TAG, "Tracking is enabled but location permission is missing")
                    return@launch
                }

                tryStartTrackerService(appContext)
            } catch (e: Exception) {
                Log.w(TAG, "Watchdog recovery attempt failed", e)
            } finally {
                if (keepArmed) {
                    TrackingWatchdogScheduler.schedule(appContext)
                }
                pending.finish()
            }
        }
    }

    private fun tryStartTrackerService(context: Context) {
        val serviceIntent = Intent(context, TrackerService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && hasNotificationPermission(context)) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d(TAG, "Tracker service recovery requested")
        } catch (e: IllegalStateException) {
            // Android 12+ can reject a foreground-service start while the app
            // is background restricted. The next watchdog tick gets another
            // chance; managed/device-owner deployments are normally exempt.
            Log.w(TAG, "Tracker service start blocked by Android", e)
        } catch (e: SecurityException) {
            Log.w(TAG, "Tracker service start denied", e)
        }
    }

    private fun hasLocationPermission(context: Context): Boolean =
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED

    private fun hasNotificationPermission(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED

    companion object {
        private const val TAG = "TrackingWatchdog"
    }
}
