# ZalGps Android Beta Release

## Current beta

- Version: `10.2.0-beta.5+163`
- Candidate date: 2026-11-27
- Target: Android
- Application ID: `org.traccar.client`
- Source branch: `beta/10.2.0-beta.5`
- GitHub tag: `v10.2.0-beta.5`
- Release type: GitHub draft pre-release (pending physical-device validation)

## Verified artifact

See [build evidence](BUILD_STATUS.md). Beta.5 is signed and available as a draft to authorized maintainers. Install the release APK, not the debug artifact; verify the checksum before installation. Keep beta.5 in draft until both registration paths and genuine GPS delivery are tested. See [Vietnamese installation guide](HUONG_DAN_ANDROID.md).

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

The beta workflow generates the final artifact metadata dynamically from the APK it just built, including workflow run ID, source commit, file size, and SHA-256. Cross-check the release body, checksum asset and GitHub asset digest before promotion; duplicate draft builds can otherwise leave inconsistent metadata.

## Beta signing and upgrades

Starting with beta.3, the beta workflow requires the dedicated ZalGps PKCS12 keystore through the four repository Actions secrets: ZALGPS_KEYSTORE_BASE64, ZALGPS_KEYSTORE_PASSWORD, ZALGPS_KEY_ALIAS, ZALGPS_KEY_PASSWORD. It builds a release APK, verifies its signing certificate against the configured key, and stages a draft only after verification succeeds. The certificate must also match the public beta.3 certificate. Missing secrets fail the build.

Keep the original keystore and credentials backed up securely outside the repository. Never commit private keys or passwords. Use the same signing key for future releases and increase the Android version code. Compare certificate SHA-256 across published releases to detect accidental key changes.

The earlier debug-signed beta and official Traccar builds may have a different certificate. Android does not allow in-place upgrades across different signing certificates. Back up settings and ensure queued positions are delivered before uninstalling an incompatible build. Physical-device validation is required.

## Beta.5 enrollment acceptance gate

- Verify HTTPS health and readiness at `https://gps-api.go7s.net/healthz` and `/readyz`.
- Upgrade an existing signed beta.3/4 installation without clearing data. Confirm that the registration section is visible, the current identifier is unchanged, and tracking settings and any queued positions are preserved.
- For an existing device, verify it is assigned to the scoped ZalGPS account in Traccar, stop tracking, and issue a bound link code using `runuser -u zalgps-prov -- python3 /opt/zalgps-provisioning/server.py issue --ttl 900 --existing-id DEVICE_ID`. Choose Link existing device, enter the code, and confirm the same device ID and display name with no duplicate created.
- Install the signed candidate on a separate fresh authorized Android test device for new-device enrollment.
- On LXC112, issue a fresh one-use code with `runuser -u zalgps-prov -- python3 /opt/zalgps-provisioning/server.py issue --ttl 900`. Keep the code private.
- On the fresh installation, choose Register device, enter the new-device code and verify the displayed name and new identifier match the device in Traccar. Restart the app and confirm the registration status is still visible.
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

Beta.5 restores the Activity in Recent Apps with `android:excludeFromRecents="false"`. The foreground location service remains subject to Android notification, process-management, and Force Stop behavior.

## iOS status

The SDK fork contains cross-platform implementation work, including iOS-side profile and sync behavior, but this Flutter client currently consumes the enhanced native source fork only on Android. A forked XCFramework/SPM distribution path is still required before declaring the iOS client part of this beta.

## Release integrity guard (main, for subsequent candidates)

The workflow now rejects an existing draft or published release for the same version and creates a new draft instead of updating assets in place. It validates staged metadata and asset digests against the exact locally built APK, commit and run. If a failed run leaves a partial draft, inspect it manually; do not rerun over a candidate already under device test. The beta.5 draft remains unchanged.
