# Changelog

All notable changes to the ZalGps resilient-tracking fork are documented here.

## 10.2.0-beta.5 — 2026-11-27

- Keep the registration section visible on the Android home screen, with registration status and a copyable current identifier.
- Preserve enrollment eligibility after unrelated settings changes or failed tracking start.
- Add operator-issued, expiring codes bound to an existing Traccar device identifier. Linking uses a scoped read-only lookup and preserves the device ID, server settings, and queued positions.
- Restore normal Recent Apps visibility and keep the management UI open after quick actions.
- Show startup loading/error state and avoid blocking the UI on optional notification registration.
- Keep the beta.3 release certificate and increment Android version code to 163.
- Keep the release as a draft until authorized physical-device acceptance checks pass.

## 10.2.0-beta.4 — 2026-11-27

- Add opt-in Android device enrollment with one-use activation codes, automatic manufacturer/model detection, Vietnamese and English UI, and a random device identifier.
- Keep existing device identifiers and configuration on upgrades; enrollment is offered on a fresh, not yet manually configured installation.
- Add isolated provisioning API with expiring activation codes, idempotent registration and scoped Traccar token checks.
- Keep tracking disabled until the user explicitly starts it; enrollment does not grant location permission.
- Sign with the same certificate as beta.3. Stage the APK as a draft pre-release until authorized physical-device enrollment and GPS upload have been verified.

## 10.2.0-beta.3 — 2026-11-26

- Configure persistent ZalGps release signing via GitHub Actions Secrets.
- Verify the APK signing certificate against the configured keystore before publishing.
- Reject reuse of published beta tags.
- First signed beta candidate; upgrading from debug-signed builds requires migration or reinstall if certificates differ.

## 10.2.0-beta.2 — 2026-11-25

### Branding

- Renamed the user-facing application from Traccar Client to **ZalGps**.
- Added a dedicated ZalGps GPS-pin/Z launcher icon source.
- Added reproducible Android/iOS launcher-icon generation through `flutter_launcher_icons`.
- Kept Android application ID `org.traccar.client`, deep-link scheme and Traccar/OsmAnd protocol compatibility unchanged.

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
