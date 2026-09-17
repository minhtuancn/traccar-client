# Android managed-device mode

This fork supports two Android deployment modes:

1. **Standard application mode.** The Traccar SDK runs location tracking as a foreground location service and restores tracking after reboot or app update when tracking was previously enabled.
2. **Managed-device mode.** Provision the app as Device Owner on a dedicated device to use Android-supported management privileges intended for company-owned or purpose-built devices.

Managed-device mode does not hide the process from Android system management. The Activity can be excluded from Recent Apps, while Android may still show an active foreground service and its required notification/indicators.

For the full enhanced SDK architecture, Adaptive Profiles and Smart Sync settings, see [`ENHANCED_TRACKING.md`](ENHANCED_TRACKING.md). The current Android validation build is `10.2.0-beta.1+159`; see [`BETA_RELEASE.md`](BETA_RELEASE.md).

## Provisioning

Device Owner provisioning is intended for a freshly provisioned device without existing accounts or another Device Owner/Profile Owner.

For development devices, install the APK first and then provision the receiver:

```bash
adb shell dpm set-device-owner org.traccar.client/.ManagedDeviceAdminReceiver
```

Verify:

```bash
adb shell dpm list-owners
adb shell dumpsys device_policy
```

Remove Device Owner only on development/test devices using Android-supported device-policy tooling or by factory resetting the device when required by the platform/OEM.

Installing the APK alone does **not** make it Device Owner.

## Background tracking

The app uses `traccar_client_sdk`, whose Android manifest provides background location, foreground-service location, boot-completed, notification and wake-lock permissions/components. The SDK boot receiver handles `BOOT_COMPLETED` and `MY_PACKAGE_REPLACED`, and its tracker service uses `START_STICKY`.

The fork adds a second recovery layer: `TrackingWatchdogScheduler` arms a 15-minute inexact `ELAPSED_REALTIME_WAKEUP` alarm using `setAndAllowWhileIdle`. The receiver reconstructs the persisted SDK tracker, checks `tracker.state.value.enabled`, and only requests service recovery when tracking is still explicitly enabled. Each watchdog tick re-arms the next check; explicit Stop cancels the watchdog. A dedicated boot/update receiver re-arms it after reboot or package replacement.

The watchdog is intentionally not an exact timer. Doze can defer its delivery, so 15 minutes is a recovery target/cadence rather than a guaranteed wall-clock deadline.

Every app entry point routes Start/Stop through `GeolocationService`, including the main tracking switch, quick actions and action deep-links. This keeps watchdog arm/cancel semantics consistent.

For reliable tracking, grant Always/Background location access, allow notifications, keep location services enabled, and avoid placing the app in the OEM battery `Restricted` state. Device Owner deployments can improve policy control, but Android platform rules still apply.

## Recommended reliable-tracking settings

For a managed tracking device, start with:

- `buffer = true` so positions use the SDK durable SQLDelight queue and survive network loss.
- `stop_detection = true` so the tracker can enter stationary mode instead of running high-rate GPS indefinitely.
- `heartbeat = 900` (15 minutes) for a stationary heartbeat cadence.
- `heartbeat_max_age = 300` so cached coordinates older than 5 minutes are not presented as newly confirmed heartbeat locations.
- `adaptive_tracking = true` so Driving / Walking / Stationary / Charging / Battery Saver profiles can tune GPS behavior at runtime.
- `sync_mode = instant` for normal real-time delivery. Use `batch` to reduce upload churn or `offline` when the operator explicitly wants local queueing only.
- `sync_batch_size = 25` and `sync_batch_interval = 60` as initial Batch defaults.
- `wakelock = false` initially. Enable it only on devices/OEMs where testing shows the normal foreground-service + alarm recovery path is insufficient, because a continuous wakelock increases power use.

The enhanced values are persisted in app preferences and applied through the Android enhanced-tracking native bridge after every base SDK init/config update.

## Fresh-position Heartbeat

The forked SDK still asks the platform for a fresh one-shot location on heartbeat. If the platform falls back to a cached position, its timestamp is checked against `heartbeat_max_age`.

When the cached fix is too old, the SDK sends a liveness-only heartbeat instead of reusing stale latitude/longitude as though it were a fresh observation.

## Adaptive Tracking Profiles

The pinned SDK provides:

- Driving
- Walking
- Stationary
- Charging
- Battery Saver

Motion activity, speed, charging/battery state and confirmed stationary state feed the native profile engine. Android Fused Location Provider / `LocationManager` subscriptions are restarted only when the effective profile changes the location configuration.

The active profile can be inspected from the app Status screen.

## Smart Offline / Batch Sync

The fork keeps the original SQLDelight durable queue and Traccar/OsmAnd-compatible uploader.

- **Instant**: normal automatic draining.
- **Batch**: keep queueing, wait for the configured interval, then drain a bounded burst.
- **Offline**: keep queueing without automatic upload until the operator triggers `Sync queued positions now`.

Batch mode does not send a new JSON-array protocol. Each queued position is still sent through the existing uploader and removed only after a successful upload.

The Status screen also reports queued-position count and the last successful queued upload timestamp.

## Android Force Stop boundary

Android's user/OEM **Force stop** action is stronger than ordinary process death. A force-stopped package enters the stopped state and alarms/receivers may not run again until the package is explicitly launched or otherwise re-enabled by platform/device-management policy.

The watchdog is designed for service/process death, memory pressure, reboot, package update and ordinary background restrictions. It does not attempt to bypass Android force-stop semantics.

## Recent Apps and system visibility

`MainActivity` is marked `android:excludeFromRecents="true"`. This removes the UI task from the Recent Apps overview; it does not conceal the Android process or foreground location service from system administration, Active Apps, security or privacy surfaces.

Android-required foreground-location notifications/indicators remain visible.

## System/privileged app builds

A true `/system/priv-app` installation requires control of the Android system image, platform/privileged permission allowlists and appropriate signing. Do not add platform signing keys or `sharedUserId=android.uid.system` to this public repository. Keep OEM/system-image integration in a private build/release pipeline.

## SDK source integration

The Android app pins `minhtuancn/traccar-client-sdk` as `vendor/traccar-client-sdk`. Gradle composite-build dependency substitution replaces the official native Maven core with that exact pinned SDK commit.

The complete SDK enhancement stack is now merged to `minhtuancn/traccar-client-sdk` `main`:

1. Fresh-position Heartbeat.
2. Adaptive Tracking Profiles.
3. Smart Offline / Batch Sync.
4. Sync status telemetry.

The client itself has also merged the managed-device/watchdog, enhanced SDK integration, telemetry and Android build-toolchain work to `main`. Future gitlink updates should move only to reviewed SDK commits and must be validated by CI.

## Verification

The repository includes a Woodpecker pipeline that initializes the submodule, runs the pinned SDK core verification, runs Flutter analysis/tests and builds an Android debug APK.

The merged stack has passed automated SDK verification, Flutter analysis/tests and Android APK compilation. The remaining beta gate is physical-device behavior.

Before production deployment perform real-device tests for:

1. Start/Stop from the main screen, deep-link and quick action.
2. Reboot while tracking is enabled.
3. Explicit Stop followed by reboot — tracking must remain stopped.
4. Stationary heartbeat for several heartbeat intervals.
5. Driving/walking/stationary profile changes.
6. Network outage followed by recovery.
7. Batch mode and manual Offline `Sync now`.
8. Queue count/last-success telemetry while accumulating and draining positions.
9. OEM battery restriction behavior on the target device model.
