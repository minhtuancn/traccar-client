# Build verification status

This file tracks verification evidence for the resilient Android tracking fork.

## Current beta

- Version: `10.2.0-beta.1+159`
- Target: Android
- Beta branch: `beta/10.2.0-beta.1`
- GitHub tag: `v10.2.0-beta.1`
- GitHub Pre-release: published in `minhtuancn/traccar-client`
- Feature stacks: merged to `main` in both the client and SDK repositories

## SDK stack

The full SDK enhancement stack is merged to `minhtuancn/traccar-client-sdk` `main`:

- Fresh-position Heartbeat — merged from SDK PR #1.
- Adaptive Tracking Profiles — merged from SDK PR #2.
- Smart Offline / Batch Sync — merged from SDK PR #3.
- Sync Status Telemetry — merged from SDK PR #4 after CI success.

SDK automated verification covers Kotlin Multiplatform core checks and the Flutter wrapper.

## Client integration

The complete client stack is merged to `minhtuancn/traccar-client` `main`:

- Managed-device/watchdog foundation — client PR #1.
- Enhanced SDK integration — client PR #2.
- Queue telemetry and Android build-toolchain compatibility — client PR #3.

## App repository CI

The client repository now owns its Android build and beta publishing workflows.

### Build workflow

`.github/workflows/build.yml`

Runs for `main`, `beta/**`, pull requests, and manual dispatch. Successful gates include:

1. recursive submodule checkout;
2. pinned SDK core verification;
3. `flutter pub get`;
4. `flutter analyze`;
5. `flutter test`;
6. `flutter build apk --debug`;
7. APK rename + SHA-256 generation;
8. artifact upload.

Initial verified run after enabling the workflow:

- Run: `35213462873`
- Result: **success**
- Source: `beta/10.2.0-beta.1`

### Beta Release workflow

`.github/workflows/beta-release.yml`

Runs for `beta/**` and manual dispatch. It performs all SDK/app verification, builds the beta APK, generates its checksum, uploads the CI artifact, and creates or updates a GitHub Pre-release for the beta version.

Initial verified run:

- Run: `35213462878`
- Result: **success**
- Tag: `v10.2.0-beta.1`
- Pre-release: `Traccar Client 10.2.0-beta.1`

The release workflow generates run ID, source commit, APK size, and APK SHA-256 from the artifact built in that same run so release metadata cannot silently retain a checksum from an older build.

## Production release isolation

`.github/workflows/release.yml` remains the production Android/iOS publishing workflow. Its tag filter now explicitly excludes tags containing `-`, so beta/RC tags such as `v10.2.0-beta.1` do not trigger Google Play production or App Store publishing.

Production checkout also initializes the SDK git submodule recursively.

## Signing status

The automated beta APK is debug-signed and intended for sideload/device validation. Android requires the same signing certificate for an in-place update, so this beta may not install over an official/differently signed `org.traccar.client` package.

A persistent beta/update channel should use a dedicated private signing keystore injected through protected CI secrets. Signing keys and passwords must not be committed to the public repository.

## Remaining physical-device validation

Automated build/test gates are complete. Physical-device validation remains required before calling the project production-complete:

- reboot and ordinary process/service recovery;
- explicit Stop remaining stopped across watchdog ticks and reboot;
- stationary fresh-heartbeat behavior;
- adaptive Driving/Walking/Stationary/Charging/Battery Saver transitions;
- prolonged Offline/Batch/Instant queue behavior and retry/backoff;
- queue depth and last-success telemetry matching actual delivery behavior;
- target OEM battery-management/Doze behavior.
