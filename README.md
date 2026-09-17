# Traccar Client app — resilient tracking fork

This repository is a fork of the official [Traccar Client](https://www.traccar.org/client) app. It keeps Traccar server/protocol compatibility while adding reliability features for long-running Android tracking and managed-device deployments.

## Current beta

**Android beta:** `10.2.0-beta.1+159` (2026-09-17)

The resilient-tracking feature stack has been merged to `main`. The beta includes managed-device watchdog/recovery, fresh-position heartbeat, adaptive tracking profiles, Smart Sync, and durable queue telemetry.

See [`CHANGELOG.md`](CHANGELOG.md) for release changes and [`docs/BETA_RELEASE.md`](docs/BETA_RELEASE.md) for installation/validation guidance and platform boundaries.

## Fork enhancements

- **Service Watchdog** — app-layer watchdog supplements the SDK foreground service, `START_STICKY`, and boot recovery. It only attempts recovery when tracking is still enabled.
- **Fresh-position Heartbeat** — heartbeat attempts a fresh fix and refuses to present arbitrarily old cached coordinates as a new location.
- **Adaptive Tracking Profiles** — automatic Driving, Walking, Stationary, Charging, and Battery Saver profiles adjust the effective GPS configuration at runtime.
- **Smart Sync** — Instant, Batch, and Offline delivery modes reuse the existing SQLDelight durable queue. `Sync now` can explicitly drain queued positions.
- **Sync telemetry** — Status shows pending queued-position count and the last successful queued upload time.
- **Managed Android deployment** — Device Admin/Device Owner support, boot/update recovery, and optional exclusion from Recent Apps.
- **Status visibility** — the Status screen shows the current adaptive profile, sync mode, queue health, and diagnostic logs.

The Android app consumes the enhanced native SDK from the pinned `vendor/traccar-client-sdk` git submodule. Gradle dependency substitution replaces the official native Maven dependency with that pinned source build. This keeps builds reproducible without publishing over Traccar's official Maven coordinates.

> The enhanced source substitution in this app is currently Android-specific. The SDK fork contains iOS implementations, but this client still needs a dedicated forked XCFramework/SPM release strategy before the iOS app can consume those enhanced native changes.

## Architecture

```text
Flutter UI / Managed Config
          |
          v
GeolocationService + EnhancedTrackingService
          |
          +---- Service Watchdog
          |
          v
Pinned minhtuancn/traccar-client-sdk
          |
          +---- Fresh Heartbeat
          +---- Adaptive Tracking Profiles
          +---- Smart Sync
          +---- Queue / sync telemetry
          |
          v
SQLDelight Durable Queue
          |
          v
Traccar / OsmAnd-compatible HTTP endpoint
```

See:

- [`docs/BETA_RELEASE.md`](docs/BETA_RELEASE.md) — current Android beta, verification and device smoke-test checklist.
- [`docs/ENHANCED_TRACKING.md`](docs/ENHANCED_TRACKING.md) — fork architecture, settings, status telemetry, build and verification workflow.
- [`docs/ANDROID_MANAGED_DEVICE.md`](docs/ANDROID_MANAGED_DEVICE.md) — managed-device / Device Owner deployment and Android recovery behavior.
- [`docs/superpowers/plans/2026-09-17-resilient-tracking.md`](docs/superpowers/plans/2026-09-17-resilient-tracking.md) — implementation status, remaining device gates and history.

## Build

Clone with the pinned SDK submodule:

```shell
git clone --recurse-submodules https://github.com/minhtuancn/traccar-client.git
cd traccar-client
```

If the repository was cloned without submodules:

```shell
git submodule sync --recursive
git submodule update --init --recursive
```

Then build normally:

```shell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

To verify the pinned SDK core as well:

```shell
cd vendor/traccar-client-sdk
./gradlew :core:check --no-configuration-cache
```

The repository also includes `.woodpecker.yml` so the same SDK tests, Flutter analysis/tests, and Android debug build can run on the self-hosted CI pipeline.

## Android behavior and privacy

Continuous Android location tracking uses a foreground location service and therefore keeps Android's required user-visible foreground-service notification/indicators. This fork does not attempt to hide tracking from Android security/process management surfaces. `excludeFromRecents` only removes the Activity from the Recent Apps UI.

A user or device administrator explicitly stopping/force-stopping the app can still affect background execution according to Android platform rules. Device Owner management and the watchdog improve recovery but do not bypass Android's security model.

## Upstream overview

Traccar Client is a GPS tracking app for Android and iOS. It runs in the background and sends location updates to a user-selected Traccar-compatible server.

- **Real-time Tracking** — send the device's location to a private server.
- **Open Source** — based on the Apache-2.0 Traccar Client codebase.
- **Customizable** — configurable update intervals, accuracy, heartbeat and data usage.
- **Privacy** — location data is sent to the configured server.

## License

Apache License, Version 2.0. See [LICENSE.txt](LICENSE.txt). Third-party projects such as Colota are used only as architectural/behavior references; their source code is not copied into this fork.
