# Android managed-device mode

This fork supports two Android deployment modes:

1. Standard application mode. The Traccar SDK runs location tracking as a foreground location service and restores tracking after reboot or app update when tracking was previously enabled.
2. Managed-device mode. Provision the app as Device Owner on a dedicated device to get the Android-supported management privileges intended for company-owned or purpose-built devices.

Managed-device mode does not hide the process from Android system management. The application can be excluded from the Recent Apps screen, while Android may still show an active foreground service and its notification.

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

## Background tracking

The app uses `traccar_client_sdk`, whose Android manifest provides background location, foreground-service location, boot-completed, notification, and wake-lock permissions/components. The SDK's boot receiver handles `BOOT_COMPLETED` and `MY_PACKAGE_REPLACED`, and its tracker service uses `START_STICKY`.

The fork adds a second recovery layer: `TrackingWatchdogScheduler` arms a 15-minute inexact `ELAPSED_REALTIME_WAKEUP` alarm using `setAndAllowWhileIdle`. The receiver reconstructs the persisted SDK tracker, checks `tracker.state.value.enabled`, and only requests service recovery when tracking is still explicitly enabled. Each successful/attempted watchdog tick re-arms the next check; explicit Stop cancels the watchdog. A dedicated boot/update receiver re-arms it after reboot or package replacement.

The watchdog is intentionally not an exact timer. Doze can defer its delivery, so 15 minutes is a minimum recovery cadence rather than a guaranteed wall-clock deadline.

For reliable tracking, grant Always/Background location access, allow notifications, keep location services enabled, and avoid placing the app in the OEM battery "Restricted" state. Device Owner deployments have a stronger background-start position than ordinary apps, but Android platform rules still apply.

### Recommended reliable-tracking settings

For a managed tracking device, start with:

- `buffer = true` so positions use the SDK durable SQLDelight queue and survive network loss.
- `stop_detection = true` so the tracker can enter stationary mode instead of running high-rate GPS forever.
- `heartbeat = 900` (15 minutes) to request a position heartbeat while stationary. SDK 1.0.11 includes location in heartbeat events.
- `wakelock = false` initially. Enable it only on devices/OEMs where testing shows the normal foreground-service + alarm recovery path is insufficient, because a continuous wakelock increases power use.
- keep the app exempt from aggressive OEM battery restriction when possible.

These values can be delivered through the existing managed-configuration/deep-link configuration path; they do not require a second queue or tracking service.

## Android Force Stop boundary

Android's user/OEM **Force stop** action is stronger than ordinary process death. A force-stopped package enters the stopped state and alarms/receivers may not run again until the package is explicitly launched or otherwise re-enabled by platform/device-management policy. The watchdog is designed for service/process death, memory pressure, reboot, package update and ordinary background restrictions; it does not attempt to bypass Android's force-stop semantics.

## Recent Apps

`MainActivity` is marked `android:excludeFromRecents="true"`. This removes the UI task from the Recent Apps overview; it does not attempt to conceal the Android process or foreground service from system administration surfaces.

## System/privileged app builds

A true `/system/priv-app` installation requires control of the Android system image, platform/privileged permission allowlists, and appropriate signing. Do not add platform signing keys or `sharedUserId=android.uid.system` to this public repository. Keep any OEM/system-image integration in a private build/release pipeline.

## Next resilient-tracking phases

The detailed implementation plan is in `docs/superpowers/plans/2026-09-17-resilient-tracking.md`:

1. Service Watchdog — implemented in the app layer in this branch.
2. Fresh-position Heartbeat policy — requires the SDK fork for stale-fix age policy.
3. Adaptive Tracking Profiles — Driving, Walking, Stationary, Charging and Battery Saver with debounce/hysteresis.
4. Smart Offline/Batch Sync — policy-controlled draining of the existing durable queue without changing Traccar protocol compatibility.

`minhtuancn/traccar-client-sdk` does not exist yet. Create that fork before Tasks 2-4 so those behaviors live below Flutter and continue working after the UI process is gone.
