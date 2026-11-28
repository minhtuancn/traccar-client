# ZalGps — ordered roadmap and handoff

Updated 2026-11-28. This is the current client/provisioning roadmap; the older resilient tracking plan records historical SDK work. See [BUILD_STATUS](BUILD_STATUS.md) for verified evidence and [CHANGELOG](../CHANGELOG.md) for implemented features.

## P0 — close beta.5 acceptance (current)

- [x] PR #6 merged, Android CI passed, 17 provisioning tests passed.
- [x] Deploy existing-device linking backend; verify readiness and database integrity.
- [x] Signed beta.5 draft built; verify certificate and checksum.
- [ ] Upgrade an existing authorized beta.4 installation without clearing data.
- [ ] Link its existing device ID and verify no duplicate.
- [ ] New-device enrollment on separate authorized fresh installation.
- [x] Genuine GPS delivery/history on beta.5 — operator confirmed.
- [x] Isolated HTTP integration: new/link retry after restart, no duplicates, invalid/expired code and upstream failure (23/23 total provisioning tests).
- [ ] Confirm explicit Stop, reboot recovery and queue preservation on a physical phone.
- [ ] Record evidence and promote the exact tested artifact (no rebuild).

P0 recheck: full APK download checksum verified; latest main CI green; live HTTPS health/readiness 200; malformed enrollment rejected.

P0 follow-up: operator reports successful use on two physical Samsung phones; backend independently confirms one completed new-device enrollment. Existing-device linking still has zero completed records. Operator confirms one phone on beta.4 and one on beta.5, with history viewable for both. Real-device beta.5 GPS/history functionality is operator-confirmed; upgrade preservation, existing-ID linking and remaining tracking acceptance checks are pending. Manual dashboard registration is not proof of API success. The operator must test on a physical phone. Do not fabricate GPS or create test devices in production without explicit authorization.

Automated acceptance: PASS at runtime candidate and main CI; release-integrity checks passed with real artifact and mocked draft creation. Physical-device acceptance remains the release gate. No new signed build is needed solely for documentation or test-only changes.

## P1 — in-app update check

Status: DESIGN ONLY, not implemented. Depends on P0 for first published compatible beta. Implement in a separate reviewed increment after acceptance.

- Use published, non-draft releases from the fixed official fork repository; opt-in beta channel, compare Android version codes rather than timestamps or lexicographic versions.
- Use HTTPS, reject untrusted URLs/redirects, cap response/download size, handle network errors and no update without blocking startup.
- Bind update metadata to the specific APK, verify SHA-256 and the expected release signing certificate/application ID before presenting the Android installer. Validate package version and reject downgrades.
- User explicitly confirms installation using normal Android installation UI. No silent installation or bypass of OS policies.
- Cover malformed metadata, wrong package/signature, checksum mismatch, offline, downgrade, and valid signed upgrade in tests. Verify on physical Android before publishing.

## P2 — remote configuration

Status: DESIGN ONLY, not implemented. Requires stable enrollment/link lifecycle and explicit device authentication. Do not treat a public device identifier as an authentication secret.

- Design a scoped authenticated per-installation channel and explicit administrator/device assignment with revocation, audit, and retry/rollback.
- Define versioned allowlisted tracking parameters with type/range validation, stale/replayed revision rejection, local safe defaults, and previous known-good config.
- Keep identity, server URL, enrollment credentials, tracking enable/disable, Android permissions and notification visibility outside automatic remote configuration.
- Apply only to the authorized installation without replacing its ID or losing queued positions. Show the user the source/status of configuration.
- Prototype against a fake/staging upstream; test authorization isolation and offline behavior before any production rollout.

## P3 — reliability and battery acceptance

- Long-running stationary and motion tests, charging/Battery Saver profiles, Doze and OEM restrictions.
- Offline/Batch/Instant queue delivery, stale heartbeat protection, ordinary process/reboot recovery and explicit Stop persistence.
- Measure battery use, sync latency and queue integrity on actual target phones; document device model and OS without personal identifiers.
- iOS enhanced SDK integration remains a separate scope.

## Agent workflow

Read current source and CI evidence before making changes. Finish existing PRs sequentially and avoid speculative PRs. Work on shared storage, keep credentials and device data outside public repositories. Use immutable SDK pins, test exact SHAs, keep signed draft releases until physical acceptance. Never change unrelated services, bypass Android permissions, restart explicitly stopped tracking, or report unverified steps as passed.
