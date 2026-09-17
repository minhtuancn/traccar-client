# Build verification status

This file tracks verification evidence for the resilient Android tracking fork.

## Current beta

- Version: `10.2.0-beta.1+159`
- Target: Android
- Beta branch: `beta/10.2.0-beta.1`
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

## Beta build evidence

A fresh beta artifact was built from the merged client `main` after the beta version bump.

GitHub Actions cross-repo build runner:

- Repository: `minhtuancn/traccar-client-sdk`
- Workflow: `Client Android Beta Build`
- Run: `35208519120`
- Result: **success**

Successful gates:

1. checkout client `main` with git submodules recursively;
2. pinned SDK core verification;
3. `flutter pub get`;
4. `flutter analyze`;
5. `flutter test` — 13 regression/integration tests passed;
6. `flutter build apk --debug`;
7. rename and SHA-256 generation;
8. artifact upload.

Final beta files:

- APK: `traccar-client-10.2.0-beta.1.apk`
- APK size: `185,818,790` bytes
- APK SHA-256: `ac3b79a111e9b49ae99c6c104ec58821070f87ec565779a4ff4a9854d54581a6`
- GitHub Actions artifact ZIP SHA-256: `7aa51cedff5d6520fcf726923294703903040868f78e95d0689ffcb05f448824`

The CI-generated checksum file contains the same APK SHA-256 shown above.

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
