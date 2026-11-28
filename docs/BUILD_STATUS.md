# Build verification status

This file tracks verification evidence for the resilient Android tracking fork.

## Current beta — verified 2026-11-28

| Item | Evidence | Status |
| --- | --- | --- |
| Candidate | 10.2.0-beta.5+163; beta/10.2.0-beta.5 | VERIFIED |
| APK source commit | 62c6a691a593404cfa2e122c1c07c1be1c2371f3 | VERIFIED |
| Pinned SDK | 528bb32a22e2fbc067bb7b91c9cc8a18dbebf423 | VERIFIED |
| Signed beta CI | [46005439328](https://github.com/minhtuancn/traccar-client/actions/runs/46005439328) | PASS |
| Android build | [46005439408](https://github.com/minhtuancn/traccar-client/actions/runs/46005439408) | PASS |
| Main Flutter Analyze | [46005439339](https://github.com/minhtuancn/traccar-client/actions/runs/46005439339) | PASS |
| Registration UI fix | [PR #6](https://github.com/minhtuancn/traccar-client/pull/6) merged | VERIFIED |
| Backend tests | 17/17 | PASS |
| Production provisioning | HTTPS readiness true; Traccar, MySQL and provisioning services active; SQLite quick_check ok | VERIFIED |
| New enrollment and existing-device linking on physical phone | No completed records in provisioning SQLite at the 2026-11-28 read-only check; manual dashboard registration is a separate path | NOT VERIFIED |
| Public release | beta.5 draft; beta.3 latest public signed beta | PENDING |

APK: `zalgps-10.2.0-beta.5.apk` (70,819,738 bytes). SHA-256:
```
24f9e58a1df651f7d0213dbeada1ea51d02eb35b5d9ad4fed4f44525ffe7f951
```
The downloaded checksum asset, GitHub asset digest and release metadata matched. The CI signing certificate SHA-256 matches beta.3:
```
1779fcc58da759bb71b1b65995039fa1cab6205361d53095005565e8dc52367f
```
These are artifact verification results, not evidence of successful on-device installation or GPS delivery.

P0 recheck (2026-11-28): downloaded the full signed draft APK to shared storage and ran `sha256sum -c` successfully (70,819,738 bytes). Main documentation commit `75d9f77` passed [Build](https://github.com/minhtuancn/traccar-client/actions/runs/46097343449) and [Flutter Analyze](https://github.com/minhtuancn/traccar-client/actions/runs/46097343440). Runtime source is unchanged from the candidate. Public health/readiness returned HTTP 200 with TLS verification successful; an invalid activation request returned HTTP 400. SQLite integrity remained OK and completed new enrollments/links were both zero. No connected Android test runner was available on the development host. P0 remains blocked on authorized physical-device evidence; do not promote the draft or start P1 until that gate is satisfied.

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

Runs for `beta/**` and manual dispatch. It performs all SDK/app verification, builds the beta APK, generates its checksum, uploads the CI artifact, and stages a signed GitHub draft pre-release for the beta version. Public promotion requires physical-device acceptance.

Initial verified run:

- Run: `35213462878`
- Result: **success**
- Tag: `v10.2.0-beta.1`
- Pre-release: `Traccar Client 10.2.0-beta.1`

The release workflow generates run ID, source commit, APK size, and APK SHA-256. A beta.4 duplicate draft build exposed a release-notes/asset mismatch that was corrected. Always cross-check release metadata, downloaded checksum and asset digest; avoid multiple builds for the same candidate.

## Production release isolation

`.github/workflows/release.yml` remains the production Android/iOS publishing workflow. Its tag filter now explicitly excludes tags containing `-`, so beta/RC tags such as `v10.2.0-beta.1` do not trigger Google Play production or App Store publishing.

Production checkout also initializes the SDK git submodule recursively.

## Signing status

Beta.1 and beta.2 used debug signing. Starting with beta.3, release APKs use the dedicated ZalGps signing key via protected CI secrets; beta.5 CI checks the certificate against the public beta.3 certificate. In-place upgrades from the same signed package are expected, subject to real-device verification. Never uninstall a tracked production device or clear its queue merely to resolve a signing conflict.

## Remaining physical-device validation

Automated build/test gates are complete. Physical-device validation remains required before calling the project production-complete:

- reboot and ordinary process/service recovery;
- explicit Stop remaining stopped across watchdog ticks and reboot;
- stationary fresh-heartbeat behavior;
- adaptive Driving/Walking/Stationary/Charging/Battery Saver transitions;
- prolonged Offline/Batch/Instant queue behavior and retry/backoff;
- queue depth and last-success telemetry matching actual delivery behavior;
- target OEM battery-management/Doze behavior.

### P0 follow-up — 2026-11-28

Operator reports active use on two physical Samsung Android phones and successful access to history after troubleshooting report permissions. The exact APK versions, upgrade preservation, tracking duration and Stop/reboot behavior remain unverified. A read-only provisioning check confirms one completed new-device API enrollment, zero completed existing-device links, SQLite integrity OK, all three services active and public readiness true. No personal identifiers or location history were collected. P0 remains open pending the remaining device acceptance checks.

### P0 follow-up — mixed-version field use

Operator confirms one Samsung phone runs beta.4 and one runs beta.5; history is viewable for both in Traccar Manager. This establishes operator-reported real-device GPS/history functionality for beta.5 alongside beta.4. It does not yet establish an in-place beta.4 to beta.5 upgrade, preserved identity/configuration/queue, successful existing-ID linking, explicit Stop/reboot behavior or long-running battery performance. No personal device identifiers or locations recorded.

### P0 follow-up — isolated HTTP acceptance

Added `provisioning/test_http.py`: six integration tests using the real HTTP handler on loopback, a temporary SQLite database and a fake Traccar upstream. All 23 provisioning tests passed locally (17 previous + 6 HTTP). Coverage includes restart-safe retries for new and linked devices, no duplicate creation, wrong-ID and wrong-installation rejection, expired codes, upstream failure and readiness. No production records, credentials or devices were used; the signed beta.5 runtime remains unchanged. Physical-device upgrade, link and Stop/reboot/queue acceptance remain open.

### P0 release-integrity tooling

Added read-only release verification and five regression tests (nine total including signer tests). Executed against the downloaded beta.5 APK, checksum and actual GitHub API release metadata: PASS. Added future-release draft collision guard and metadata verification to main CI; the existing beta.5 branch/artifact is unchanged. CI for the workflow changes must be checked separately.
