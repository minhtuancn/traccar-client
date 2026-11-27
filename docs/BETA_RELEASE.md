# ZalGps Android Beta Release

## Current beta

- Version: `10.2.0-beta.4+162`
- Candidate date: 2026-11-27
- Target: Android
- Application ID: `org.traccar.client`
- Source branch: `beta/10.2.0-beta.4`
- GitHub tag: `v10.2.0-beta.4`
- Release type: GitHub draft pre-release (pending physical-device validation)

## ZalGps branding

- User-facing app name: **ZalGps**.
- New ZalGps location-pin/Z launcher icon generated reproducibly for Android and iOS.
- Android application ID remains `org.traccar.client` for compatibility.
- Deep-link scheme and Traccar/OsmAnd protocol behavior are unchanged.

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

## GitHub Actions

The app repository owns both CI and beta publishing:

- `.github/workflows/build.yml` runs SDK core verification, `flutter analyze`, `flutter test`, builds a debug APK, generates SHA-256, and uploads the artifact for `main`, beta branches, pull requests, and manual runs.
- `.github/workflows/beta-release.yml` runs on `beta/**` and manual dispatch. It verifies the pinned SDK and Flutter app, builds the beta APK, generates SHA-256, uploads the CI artifact, stages a GitHub draft pre-release with the APK and checksum attached. Publish the draft only after the smoke tests below pass.
- `.github/workflows/release.yml` remains the production publishing workflow. Pre-release tags containing `-` are excluded from the production tag trigger so beta/RC tags cannot accidentally publish to Google Play or App Store.

The beta workflow generates the final artifact metadata dynamically from the APK it just built, including workflow run ID, source commit, file size, and SHA-256. This avoids stale checksums in release notes.

## Beta signing and upgrades

Starting with beta.3, the beta workflow requires the dedicated ZalGps PKCS12 keystore through the four repository Actions secrets: ZALGPS_KEYSTORE_BASE64, ZALGPS_KEYSTORE_PASSWORD, ZALGPS_KEY_ALIAS, ZALGPS_KEY_PASSWORD. It builds a release APK, verifies its signing certificate against the configured key, and stages a draft only after verification succeeds. The certificate must also match the public beta.3 certificate. Missing secrets fail the build.

Keep the original keystore and credentials backed up securely outside the repository. Never commit private keys or passwords. Use the same signing key for future releases and increase the Android version code. Compare certificate SHA-256 across published releases to detect accidental key changes.

The earlier debug-signed beta and official Traccar builds may have a different certificate. Android does not allow in-place upgrades across different signing certificates. Back up settings and ensure queued positions are delivered before uninstalling an incompatible build. Physical-device validation is required.

## Beta.4 enrollment acceptance gate

Download the signed test APK from the draft release using the authenticated repository maintainer account, or from the matching Beta Release workflow artifact. Do not distribute the draft publicly before the acceptance gate passes. If the existing beta.3 installation already has a device identifier, use a separate fresh Android test installation for enrollment instead of clearing a production device's app data.

- Verify HTTPS health and readiness at `https://gps-api.go7s.net/healthz` and `/readyz`.
- Install the signed candidate on a fresh authorized Android test device; existing beta.3 device configurations are preserved and are not automatically re-enrolled.
- On LXC112, issue a fresh one-use code with `runuser -u zalgps-prov -- python3 /opt/zalgps-provisioning/server.py issue --ttl 900`. Keep the code private.
- In ZalGps, choose Register device, enter the code and verify the displayed name and new identifier match the device in Traccar.
- Verify registration alone does not start tracking. Explicitly enable tracking, grant the required permissions and confirm a genuine position reaches the server.
- Confirm a second installation cannot redeem the same code. Never create fake production positions.
- Publish the draft only after these checks pass. If enrollment fails, retain the candidate and repair the existing branch before publication.

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
