# Enhanced Tracking Integration

This document describes how the `minhtuancn/traccar-client` fork consumes the enhanced `minhtuancn/traccar-client-sdk` fork and how the reliability features interact.

**Current status:** the complete enhanced Android stack is merged to `main` and is being validated as Android beta `10.2.0-beta.1+159`.

## Scope

The enhanced native integration in this app currently targets **Android**. The SDK fork also contains iOS implementations for Fresh Heartbeat, Adaptive Tracking Profiles and Smart Sync, but the client app does not yet consume a forked iOS XCFramework/SPM binary. Do not assume the Android source-substitution mechanism also changes the iOS app.

## Dependency model

The SDK fork is checked in as a git submodule:

```text
vendor/traccar-client-sdk
```

The gitlink is pinned to a concrete commit. Android Gradle uses composite-build dependency substitution so requests for the native artifact:

```text
org.traccar:traccar-client-sdk
```

resolve to the pinned source module instead of the public Maven artifact.

The Dart package remains compatible with the published `traccar_client_sdk` 1.0.11 API. Fork-only fields are applied after the base SDK `init` / `setConfig` call through the Android method channel `traccar_client/enhanced_tracking`.

This split is intentional: it prevents the fork from publishing over the official Traccar coordinates and keeps the app able to follow upstream Flutter changes while the native Android engine evolves independently.

## Runtime architecture

```text
                   Flutter UI
                       |
          +------------+-------------+
          |                          |
          v                          v
  GeolocationService        EnhancedTrackingService
          |                          |
          |                MethodChannel: enhanced_tracking
          |                          |
          +------------+-------------+
                       v
             Forked Android SDK core
                       |
       +---------------+----------------+
       |               |                |
       v               v                v
 Fresh Heartbeat   Profile Engine    Smart Sync
       |               |                |
       |        Driving / Walking       |
       |        Stationary / Charge     |
       |        Battery Saver           |
       +---------------+----------------+
                       v
               TrackerEngine
                       |
                       v
             SQLDelight durable queue
                       |
              +--------+---------+
              |                  |
              v                  v
        Queue telemetry      Traccar server
```

The app-layer Service Watchdog is separate from the SDK engine and supplements, rather than replaces, the SDK foreground service, `START_STICKY`, `BootReceiver`, alarm heartbeat, queue and retry behavior.

## Default enhanced settings

Enhanced defaults are applied both to fresh installs and upgrades from the upstream client:

| Setting | Default |
| --- | --- |
| Adaptive tracking | enabled |
| Smart Sync | `instant` |
| Batch size | 25 positions |
| Batch interval | 60 seconds |
| Heartbeat max cached-position age | 300 seconds |

The settings are persisted in `SharedPreferences` under:

- `adaptive_tracking`
- `sync_mode`
- `sync_batch_size`
- `sync_batch_interval`
- `heartbeat_max_age`

The Advanced Settings screen can modify these values. Managed configuration/deep configuration can also update the supported enhanced keys through the existing configuration service.

## Fresh-position Heartbeat

The heartbeat still attempts `fetchOnce()` so a fresh location is preferred. The enhanced SDK then evaluates the returned timestamp:

```text
heartbeat tick
     |
     v
request fresh position
     |
     +-- acceptable age --> keep real coordinate
     |
     +-- too old --------> liveness-only position
     |
     +-- no fix ---------> liveness-only position
```

The default maximum cached-position age is 300 seconds. Setting the max age to `0` disables age filtering.

This prevents a very old cached point from appearing at the server as though it were a newly confirmed GPS fix.

## Adaptive Tracking Profiles

The native SDK can select among these profiles:

- `DRIVING`
- `WALKING`
- `STATIONARY`
- `CHARGING`
- `BATTERY_SAVER`
- default/base profile when adaptive tracking is disabled

Inputs include motion classification, speed, battery/charging state and confirmed stationary state. Driving uses speed hysteresis and motion transitions are debounced so GPS noise does not rapidly switch profiles.

When the effective profile changes, Android `LocationManager` or Fused Location Provider subscriptions are restarted only when the effective location configuration actually changes.

The Status screen displays the profile currently reported by the native engine.

## Smart Sync

Smart Sync reuses the existing SQLDelight position queue. It does not introduce a second queue and does not invent a JSON batch protocol.

### Instant

Positions are drained from the queue using the existing uploader as soon as network conditions permit. This is the default and most closely matches upstream behavior.

### Batch

Positions continue to be written to the durable queue. Automatic delivery waits for the configured batch interval and then drains a bounded burst. Each queued position is still uploaded as an ordinary Traccar/OsmAnd-compatible request.

Defaults:

```text
batch size:     25
batch interval: 60 seconds
```

### Offline

Positions remain in the durable queue and are not automatically uploaded. Selecting **Sync queued positions now** calls native `syncNow()` and explicitly drains the pending queue when network access is available.

Rows are deleted only after successful upload. Existing network retry/backoff remains in use.

## Queue and sync telemetry

The enhanced SDK exposes operational health without creating a second storage layer:

- `pendingPositionCount()` reads the count directly from the existing SQLDelight `Position` table.
- `State.lastSuccessfulSyncMillis` records the most recent successful queued-position upload and is persisted through the existing `StateStore` JSON record.
- old persisted state without the telemetry field remains compatible because the field is nullable with a default value.

The Android bridge returns both values from `getStatus`. The Status screen refreshes them with the existing five-second status refresh cycle and displays:

- **Queued positions** — current durable queue depth.
- **Last successful sync** — local date/time of the most recent successful queued upload, or `Never` when none has completed yet.

These fields are diagnostics only. They do not alter upload scheduling, queue ordering or retry behavior.

## Tracking lifecycle and watchdog

Every app entry point must use `GeolocationService.start()` and `GeolocationService.stop()` rather than calling `TraccarClientSdk.start/stop` directly. This currently covers:

- main tracking switch
- quick actions
- action deep-links

`GeolocationService.start()` starts the SDK tracker first, then arms the optional app-layer watchdog. A watchdog bridge failure does not invalidate an otherwise successful SDK start.

`GeolocationService.stop()` stops the SDK first, then cancels the watchdog. The watchdog reads the persisted tracker enabled state and must never resurrect tracking after an explicit stop.

## Android managed-device deployment

For ordinary phones, Android foreground-service and background-location restrictions still apply. For devices that the operator owns and provisions as managed/dedicated devices, see [`ANDROID_MANAGED_DEVICE.md`](ANDROID_MANAGED_DEVICE.md).

The app includes Device Admin/Device Owner building blocks, but installing the APK does **not** automatically make it Device Owner. Device Owner provisioning is a separate Android management operation.

The app may be excluded from Recent Apps, but the fork intentionally does not attempt to hide a foreground location service from Android Active Apps, process management or security surfaces. Android-required location/foreground-service indicators remain visible.

## Clone and build

Always initialize the SDK submodule:

```shell
git clone --recurse-submodules https://github.com/minhtuancn/traccar-client.git
cd traccar-client
```

or, for an existing clone:

```shell
git submodule sync --recursive
git submodule update --init --recursive
```

Verification commands:

```shell
cd vendor/traccar-client-sdk
./gradlew :core:allTests --no-configuration-cache
cd ../..
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

`.woodpecker.yml` runs the same core/client verification path in self-hosted CI.

The Android beta build toolchain currently uses Gradle 9.5.1, Android Gradle Plugin 9.2.0 and Kotlin 2.3.21. The installed application ID remains `org.traccar.client`, while the app build namespace is `org.traccar.client.app` to avoid a namespace collision with the SDK library under AGP 9.

## Updating the SDK pin

Do not point the app at a moving SDK branch for beta/production builds. Update the submodule to a reviewed SDK commit, commit the changed gitlink in this repository, and let CI validate the exact pair.

The enhancement dependency order is:

```text
Fresh Heartbeat
      -> Adaptive Tracking Profiles
      -> Smart Offline / Batch Sync
      -> Sync Status Telemetry
      -> client SDK pin update
```

All four SDK phases and the corresponding client integration are now merged to their respective `main` branches.

## Verification gate

Automated integration verification has passed SDK core checks, `flutter analyze`, Flutter tests and Android debug APK compilation. Before promoting the beta to production, complete on-device smoke tests for:

1. Start/Stop from the main screen, deep-link and quick action.
2. Reboot recovery and ordinary process/service recovery.
3. Explicit Stop remaining stopped across watchdog ticks/reboot.
4. Stationary heartbeat age/freshness behavior.
5. Adaptive motion/power profile transitions on the target OEM.
6. Offline/Batch queue recovery after a network outage.
7. Status telemetry: queue depth rises while delivery is held/offline, falls after sync, and last-success time advances only after successful upload.

The on-device checks are especially important because Android background execution and OEM battery-management behavior cannot be fully proven by unit tests alone.
