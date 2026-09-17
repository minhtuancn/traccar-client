# Android Beta Release

## Current beta

- Version: `10.2.0-beta.1+159`
- Release date: 2026-09-17
- Target: Android
- Application ID: `org.traccar.client`
- Source branch: `beta/10.2.0-beta.1`
- Status: resilient-tracking stack merged to `main`; beta APK rebuilt successfully from merged `main`

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

## Final beta verification

The final beta artifact was built from merged client `main` with the beta version already set.

GitHub Actions verification:

- Workflow: `Client Android Beta Build`
- Run: `35208519120`
- Result: **success**
- SDK core verification: passed
- Flutter analyze: passed with zero issues
- Flutter tests: 13 passed
- Android debug APK build: passed
- SHA-256 generation: passed
- Artifact upload: passed

Final files:

- APK: `traccar-client-10.2.0-beta.1.apk`
- APK size: `185,818,790` bytes
- APK SHA-256: `ac3b79a111e9b49ae99c6c104ec58821070f87ec565779a4ff4a9854d54581a6`
- GitHub Actions artifact ZIP SHA-256: `7aa51cedff5d6520fcf726923294703903040868f78e95d0689ffcb05f448824`

The CI-generated `.sha256` file matches the APK checksum above.

## Beta signing and upgrades

The automated beta artifact is currently a **debug-signed APK intended for sideload/device validation**. Android requires the same signing certificate for an in-place app update.

Consequences:

- It may not install as an update over the official Traccar Client or any APK signed with a different certificate, even though the application ID remains `org.traccar.client`.
- A long-lived beta/update channel should use a dedicated private signing keystore stored outside this public repository and injected through a protected CI secret.
- Do not commit a release/private signing key, platform key, or keystore password to this repository.

For testing where a differently signed `org.traccar.client` is already installed, uninstall the old build first unless preserving app data is required. Establish a stable private beta signing key before relying on in-place beta-to-beta upgrades.

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
