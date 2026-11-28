package org.traccar.client

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var enhancedTrackingBridge: EnhancedTrackingBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        enhancedTrackingBridge?.dispose()
        enhancedTrackingBridge = EnhancedTrackingBridge(
            flutterEngine.dartExecutor.binaryMessenger,
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "zalgps/device_info",
        ).setMethodCallHandler { call, result ->
            if (call.method == "model") {
                result.success("${Build.MANUFACTURER} ${Build.MODEL}".trim())
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "zalgps/update_info",
        ).setMethodCallHandler { call, result ->
            if (call.method == "versionCode") {
                @Suppress("DEPRECATION")
                val info = packageManager.getPackageInfo(packageName, 0)
                @Suppress("DEPRECATION")
                val code = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
                result.success(code)
            } else {
                result.notImplemented()
            }
        }

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

    override fun onDestroy() {
        enhancedTrackingBridge?.dispose()
        enhancedTrackingBridge = null
        super.onDestroy()
    }

    companion object {
        private const val WATCHDOG_CHANNEL = "traccar_client/watchdog"
    }
}
