# Android Beta Release

## Current beta

- Version: `10.2.0-beta.1+159`
- Release date: 2026-09-17
- Target: Android
- Application ID: `org.traccar.client`
- Status: merged feature stack on `main`; beta APK rebuilt from merged `main` before distribution

## Included resilient-tracking stack

1. Managed-device background hardening and service watchdog.
2. Fresh-position heartbeat with stale cached-position filtering.
3. Adaptive Tracking Profiles for Driving, Walking, Stationary, Charging, and Battery Saver states.
4. Smart Sync with Instant, Batch, and Offline modes.
5. SQLDelight durable queue reuse with manual sync.
6. Queue depth and last-successful-sync telemetry.
7. Advanced settings and native status reporting.

## SDK relationship

The Android client pins `minhtuancn/traccar-client-sdk` as the `vendor/traccar-client-sdk` git submodule. Gradle composite-build dependency substitution resolves the native Traccar SDK dependency to this pinned source checkout.

The SDK fork keeps the original queue and Traccar/OsmAnd-compatible per-position upload protocol. It does not introduce a second queue or a proprietary JSON batch protocol.

## Verification gates

The integrated stack has already passed:

- SDK Kotlin Multiplatform core verification.
- Flutter analysis with zero issues.
- 13 Flutter regression/integration tests.
- Android debug APK compilation and artifact upload.

A new beta artifact is built from merged `main` after the beta version bump so that the distributed APK exactly matches the documented beta source state.

## Device smoke-test checklist

After installation on a real Android device:

- Grant the required location and notification permissions.
- Start tracking and confirm the foreground location notification is visible.
- Confirm positions reach the configured Traccar server.
- Leave the phone stationary and confirm heartbeat/liveness behavior without arbitrarily stale coordinates being presented as fresh positions.
- Walk and drive to observe adaptive profile transitions.
- Test Charging and low-battery/Battery Saver profile behavior when practical.
- Select Offline mode, accumulate positions, then use Sync now and verify queue depth returns toward zero.
- Test Batch mode and confirm queued positions drain after the configured interval/burst policy.
- Reboot while tracking is enabled and verify recovery.
- Explicitly stop tracking, reboot or wait for the watchdog interval, and confirm the watchdog does not intentionally resurrect the stopped tracker.

## Managed-device notes

For dedicated devices, Device Owner provisioning can be used to apply supported Android management policies. Device Owner improves administrative control but does not make the application invisible to Android system-management interfaces.

`android:excludeFromRecents="true"` only removes the Activity from Recent Apps. The foreground location service remains subject to Android notification, process-management, and Force Stop behavior.

## iOS status

The SDK fork contains cross-platform implementation work, including iOS-side profile and sync behavior, but this Flutter client currently consumes the enhanced native source fork only on Android. A forked XCFramework/SPM distribution path is still required before declaring the iOS client part of this beta.
