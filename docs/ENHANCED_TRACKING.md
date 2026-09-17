# Enhanced Tracking Integration

This document describes how the `minhtuancn/traccar-client` fork consumes the enhanced `minhtuancn/traccar-client-sdk` fork and how the reliability features interact.

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
./gradlew :core:check --no-configuration-cache
cd ../..
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

`.woodpecker.yml` runs the same sequence in self-hosted CI. GitHub pull-request CI is also configured for stacked feature branches so integration branches can be verified before they target `main`.

## Updating the SDK pin

Do not point the app at a moving SDK branch for production builds. Update the submodule to a reviewed SDK commit, commit the changed gitlink in this repository, and let CI validate the exact pair.

Current dependency order is:

```text
Fresh Heartbeat
      -> Adaptive Tracking Profiles
      -> Smart Offline / Batch Sync
      -> Sync Status Telemetry
      -> client SDK pin update
```

## Verification gate

A feature branch is not considered verified merely because it is mergeable. Before merging to the production branch, require evidence for:

1. SDK core tests / checks.
2. `flutter analyze`.
3. `flutter test`.
4. Android debug APK build.
5. On-device smoke test for Start/Stop, reboot recovery, stationary heartbeat, adaptive transitions and queue recovery after a network outage.
6. Status telemetry validation: queue depth rises while delivery is held/offline, falls after sync, and last-success time advances only after successful upload.

The on-device checks are especially important because Android background execution and OEM battery-management behavior cannot be fully proven by unit tests alone.
