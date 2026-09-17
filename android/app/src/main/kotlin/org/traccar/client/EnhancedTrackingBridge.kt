package org.traccar.client

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class EnhancedTrackingBridge(messenger: BinaryMessenger) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler { call, result ->
            scope.launch {
                try {
                    when (call.method) {
                        "configure" -> {
                            configure(call.arguments as? Map<*, *> ?: emptyMap<Any, Any>())
                            result.success(null)
                        }
                        "getStatus" -> result.success(getStatus())
                        "syncNow" -> {
                            sharedTracker()?.syncNow()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Throwable) {
                    result.error(
                        error::class.simpleName ?: "enhancedTrackingError",
                        error.message,
                        null,
                    )
                }
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        scope.cancel()
    }

    private suspend fun configure(arguments: Map<*, *>) {
        val tracker = sharedTracker() ?: error("Tracker is not initialized")
        val current = tracker.config

        val adaptiveEnabled = arguments["adaptiveEnabled"] as? Boolean ?: true
        val heartbeatMaxAgeSeconds =
            ((arguments["heartbeatMaxAgeSeconds"] as? Number)?.toInt() ?: 300)
                .coerceAtLeast(0)
        val batchSize =
            ((arguments["batchSize"] as? Number)?.toInt() ?: 25)
                .coerceIn(1, 10_000)
        val batchIntervalSeconds =
            ((arguments["batchIntervalSeconds"] as? Number)?.toInt() ?: 60)
                .coerceAtLeast(1)
        val syncMode = when ((arguments["syncMode"] as? String)?.lowercase()) {
            "batch" -> SyncMode.BATCH
            "offline" -> SyncMode.OFFLINE
            else -> SyncMode.INSTANT
        }

        val enhanced = current.copy(
            location = current.location.copy(
                heartbeatMaxAgeSeconds = heartbeatMaxAgeSeconds,
            ),
            adaptiveTracking = current.adaptiveTracking.copy(
                enabled = adaptiveEnabled,
            ),
            smartSync = SmartSyncConfig(
                enabled = true,
                mode = syncMode,
                batchSize = batchSize,
                batchIntervalSeconds = batchIntervalSeconds,
            ),
        )

        if (enhanced != current) {
            tracker.updateConfig(enhanced)
        }
    }

    private suspend fun getStatus(): Map<String, Any> {
        val tracker = sharedTracker()
            ?: return mapOf(
                "profile" to "default",
                "syncMode" to "instant",
                "adaptiveEnabled" to false,
            )
        return mapOf(
            "profile" to tracker.profile.value.name.lowercase(),
            "syncMode" to tracker.config.smartSync.mode.name.lowercase(),
            "adaptiveEnabled" to tracker.config.adaptiveTracking.enabled,
        )
    }

    companion object {
        private const val CHANNEL = "traccar_client/enhanced_tracking"
    }
}
