# ZalGps — resilient GPS tracking

ZalGps is based on the official [Traccar Client](https://www.traccar.org/client) app. It keeps Traccar server/protocol compatibility while adding reliability features for long-running Android tracking and managed-device deployments.

## Current beta

**Android beta candidate:** `10.2.0-beta.5+163` (2026-11-27). Signed build and backend verification passed; physical-device acceptance is pending. The latest public signed beta remains beta.3.

ZalGps branding (new app name and launcher icon) is included alongside the resilient-tracking stack. The beta includes managed-device watchdog/recovery, fresh-position heartbeat, adaptive tracking profiles, Smart Sync, and durable queue telemetry.

See [`CHANGELOG.md`](CHANGELOG.md) for release changes, [`docs/BETA_RELEASE.md`](docs/BETA_RELEASE.md) for installation/validation guidance, and [`docs/BUILD_STATUS.md`](docs/BUILD_STATUS.md) for exact CI and artifact evidence. Download the signed beta.5 draft using an authorized maintainer account from [GitHub Releases](https://github.com/minhtuancn/traccar-client/releases).

## Fork enhancements

- **Service Watchdog** — app-layer watchdog supplements the SDK foreground service, `START_STICKY`, and boot recovery. It only attempts recovery when tracking is still enabled.
- **Fresh-position Heartbeat** — heartbeat attempts a fresh fix and refuses to present arbitrarily old cached coordinates as a new location.
- **Adaptive Tracking Profiles** — automatic Driving, Walking, Stationary, Charging, and Battery Saver profiles adjust the effective GPS configuration at runtime.
- **Smart Sync** — Instant, Batch, and Offline delivery modes reuse the existing SQLDelight durable queue. `Sync now` can explicitly drain queued positions.
- **Sync telemetry** — Status shows pending queued-position count and the last successful queued upload time.
- **Managed Android deployment** — Device Admin/Device Owner support, boot/update recovery, and normal Recent Apps visibility in beta.5.
- **Device registration** — one-use activation codes for new Android installations, or ID-bound linking for existing Traccar devices without changing their identity.
- **Status visibility** — the Status screen shows the current adaptive profile, sync mode, queue health, and diagnostic logs.

The Android app consumes the enhanced native SDK from the pinned `vendor/traccar-client-sdk` git submodule. Gradle dependency substitution replaces the official native Maven dependency with that pinned source build. This keeps builds reproducible without publishing over Traccar's official Maven coordinates.

> The enhanced source substitution in this app is currently Android-specific. The SDK fork contains iOS implementations, but this client still needs a dedicated forked XCFramework/SPM release strategy before the iOS app can consume those enhanced native changes.

## Device registration

The first screen displays registration status and the current device identifier. For a fresh installation, an administrator can issue a new-device activation code. For an existing manually registered device, choose Link existing device and use a code bound to its current identifier. Stop tracking before linking; the service account must have access to that existing device. Registration never starts tracking or grants Android permissions automatically.

For Vietnamese installation and troubleshooting instructions, see [`docs/HUONG_DAN_ANDROID.md`](docs/HUONG_DAN_ANDROID.md). Operators should follow [`provisioning/README.md`](provisioning/README.md).

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
- [`docs/BUILD_STATUS.md`](docs/BUILD_STATUS.md) — verified build, deployment evidence and open acceptance gates.
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — ordered next steps and agent handoff.
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

Then build normally. Generate ZalGps launcher icons before packaging:

```shell
flutter pub get
./tool/generate_branding.sh
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

Continuous Android location tracking uses a foreground location service and therefore keeps Android's required user-visible foreground-service notification/indicators. This fork does not attempt to hide tracking from Android security/process management surfaces. Beta.5 keeps the Activity visible in Recent Apps.

A user or device administrator explicitly stopping/force-stopping the app can still affect background execution according to Android platform rules. Device Owner management and the watchdog improve recovery but do not bypass Android's security model.

## Upstream overview

Traccar Client is a GPS tracking app for Android and iOS. It runs in the background and sends location updates to a user-selected Traccar-compatible server.

- **Real-time Tracking** — send the device's location to a private server.
- **Open Source** — based on the Apache-2.0 Traccar Client codebase.
- **Customizable** — configurable update intervals, accuracy, heartbeat and data usage.
- **Privacy** — location data is sent to the configured server.

## License

Apache License, Version 2.0. See [LICENSE.txt](LICENSE.txt). Third-party projects such as Colota are used only as architectural/behavior references; their source code is not copied into this fork.
