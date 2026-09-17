# Changelog

All notable changes to the resilient-tracking fork are documented here.

## 10.2.0-beta.1 — 2026-09-17

First public beta of the resilient Android tracking stack.

### Added

- Managed-device background tracking hardening and Device Admin/Device Owner integration.
- 15-minute service watchdog that only repairs tracking when persisted tracking state is enabled.
- Reboot and package-update watchdog re-arming.
- Fresh-position heartbeat policy with stale cached-position age filtering.
- Adaptive Tracking Profiles: Driving, Walking, Stationary, Charging, and Battery Saver.
- Smart Sync delivery modes: Instant, Batch, and Offline.
- Manual `Sync now` for queued positions.
- Durable queue telemetry: pending position count and last successful queued upload time.
- Advanced Android settings for adaptive tracking, heartbeat freshness, and sync policy.
- Status screen diagnostics for active profile, sync mode, queue depth, and last successful sync.
- Pinned forked SDK source integration through a git submodule and Gradle dependency substitution.
- Woodpecker CI coverage for SDK verification, Flutter analysis/tests, and Android APK build.

### Build and compatibility

- Version: `10.2.0-beta.1+159`.
- Android build toolchain: Gradle 9.5.1, Android Gradle Plugin 9.2.0, Kotlin 2.3.21.
- Installed Android application ID remains `org.traccar.client`.
- The app build namespace is `org.traccar.client.app` to avoid namespace collision with the SDK library under AGP 9.
- Enhanced native source integration is currently Android-only in the client. The SDK fork includes iOS-side implementation work, but the client still uses the upstream iOS wrapper consumption path.

### Verification

Before the beta version bump, the integrated feature head passed:

- Kotlin Multiplatform SDK core verification.
- Flutter analyze with zero issues.
- 13 Flutter regression/integration tests.
- Android debug APK compilation.
- APK artifact upload.

The beta build is rebuilt from merged `main` after the version/documentation update before distribution.

### Platform boundaries

- Android foreground-location notification and system visibility remain intact.
- `excludeFromRecents` only removes the Activity from Recent Apps; it does not hide the process or foreground service from Android management/security surfaces.
- Android Force Stop remains a platform boundary.

### Beta validation focus

- Reboot recovery.
- Stationary fresh-heartbeat behavior.
- Adaptive profile transitions.
- Instant/Batch/Offline queue behavior.
- Manual sync and queue telemetry.
- Watchdog recovery without restarting an explicitly stopped tracker.
