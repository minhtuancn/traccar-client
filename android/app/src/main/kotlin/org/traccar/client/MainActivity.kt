package org.traccar.client

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WATCHDOG_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "arm" -> {
                    TrackingWatchdogScheduler.schedule(applicationContext)
                    result.success(null)
                }
                "cancel" -> {
                    TrackingWatchdogScheduler.cancel(applicationContext)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val WATCHDOG_CHANNEL = "traccar_client/watchdog"
    }
}
