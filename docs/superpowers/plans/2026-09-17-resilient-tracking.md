# Resilient Android Tracking — Execution Status

**Release status:** feature implementation has been merged into `main` in both `minhtuancn/traccar-client` and `minhtuancn/traccar-client-sdk`. Android beta `10.2.0-beta.1+159` is the current validation release. Automated SDK/client verification is complete; physical-device reliability validation remains open.

**Goal:** Make the Android Traccar Client fork survive ordinary service/process death, produce trustworthy stationary heartbeats, adapt tracking cadence to device state, retain positions through network loss, and expose enough telemetry to diagnose delivery health without breaking Traccar protocol compatibility.

**Architecture:** Flutter remains the UI/configuration layer. Location capture, heartbeat policy, adaptive profiles, durable queueing and Smart Sync live in the forked Traccar Client SDK. Android service recovery is supplemented by an app-layer watchdog. The Android app consumes an immutable SDK gitlink through Gradle composite-build dependency substitution.

**Repositories:**

- App: `minhtuancn/traccar-client`
- SDK: `minhtuancn/traccar-client-sdk`

## Global constraints

- Android is the first beta target; iOS behavior must not regress.
- Do not copy AGPL-3.0 Colota source. Architecture/behavior may be studied and reimplemented clean-room only.
- Do not hide the process or foreground location service from Android system/security surfaces.
- Never restart tracking after an explicit user Stop; persisted tracker intent is authoritative.
- Reuse the SDK SQLDelight queue; do not add a second Flutter queue.
- Preserve Traccar/OsmAnd request compatibility; Batch means bounded draining of ordinary requests, not a new JSON batch wire format.
- Android Force Stop remains a platform boundary and is not bypassed.

---

## Task 1 — Android Service Watchdog

**Status:** merged to app `main`; physical-device recovery gate pending.

Implemented in the app layer:

- `TrackingWatchdogScheduler.kt`
- `TrackingWatchdogReceiver.kt`
- `TrackingWatchdogBootReceiver.kt`
- watchdog manifest registrations
- Flutter `traccar_client/watchdog` bridge
- Start arms watchdog; explicit Stop cancels watchdog
- watchdog checks persisted `tracker.state.value.enabled`
- reboot/package replacement re-arms recovery
- 15-minute inexact `ELAPSED_REALTIME_WAKEUP` + `setAndAllowWhileIdle`

Checklist:

- [x] Regression coverage for watchdog/Device Admin wiring added.
- [x] Scheduler/receiver/boot recovery implemented.
- [x] Main switch, Quick Actions and action deep-links route through common `GeolocationService.start/stop` lifecycle.
- [x] Explicit Stop is represented by persisted SDK state and watchdog never intentionally resurrects disabled tracking.
- [x] Android Force Stop boundary documented.
- [x] Changes merged to app `main`.
- [ ] Verify ordinary process/service death recovery on a physical Android device.
- [ ] Reboot device and verify tracking/watchdog recovery without opening Flutter UI.
- [ ] Leave explicitly stopped for at least one watchdog interval and confirm it remains stopped.

---

## Task 2 — Fresh-Position Heartbeat

**Status:** merged to SDK `main`; automated CI complete; device validation pending.

Implemented:

- `LocationConfig.heartbeatMaxAgeSeconds`
- fresh `fetchOnce()` attempt remains first choice
- cached location is accepted only inside configured age policy
- stale/no-fix heartbeat becomes liveness-only position
- Android/iOS Flutter and React Native wrapper compatibility retained
- common regression tests for fresh/stale/no-fix/disabled filtering

Checklist:

- [x] Policy tests added.
- [x] Heartbeat age policy integrated into `TrackerEngine`.
- [x] Existing queue/uploader pipeline preserved.
- [x] Client exposes conservative heartbeat max-age setting (default 300 s).
- [x] SDK GitHub CI passed.
- [x] Changes merged to SDK `main`.
- [ ] Physical stationary-device test: verify old cached coordinates are not represented as fresh fixes.

---

## Task 3 — Adaptive Tracking Profiles

**Status:** merged to SDK `main`; automated CI complete; real motion/OEM validation pending.

Profiles implemented:

- `DRIVING`
- `WALKING`
- `STATIONARY`
- `CHARGING`
- `BATTERY_SAVER`
- default/base profile

Behavior includes speed hysteresis, debounced motion transitions, immediate power/stationary policy changes and effective-location-config subscription restarts only when necessary.

Checklist:

- [x] Pure policy tests for precedence/hysteresis/profile selection.
- [x] Platform-neutral profile policy/controller implemented.
- [x] Android motion/activity + battery/charging inputs integrated.
- [x] iOS implementation retained in SDK fork.
- [x] Active profile exposed to Android Flutter client Status UI.
- [x] SDK GitHub CI passed.
- [x] Changes merged to SDK `main`.
- [ ] Physical walking/driving/stationary transition test with noisy GPS/activity signals.
- [ ] Verify charging and low-battery profile priority on a real device.

---

## Task 4 — Smart Offline / Batch Sync

**Status:** merged to SDK `main`; queue policy and automated CI complete; long offline/reconnect validation pending.

Implemented modes:

- `INSTANT` — upstream-compatible immediate draining.
- `BATCH` — configurable interval + bounded burst.
- `OFFLINE` — durable accumulation until manual `syncNow()`.

The existing SQLDelight queue and uploader remain the only delivery pipeline. Rows are removed only after successful upload; online restoration and exponential retry/backoff remain active.

Checklist:

- [x] Smart Sync policy tests added.
- [x] Instant/Batch/Offline behavior implemented without changing wire protocol.
- [x] Manual full drain implemented.
- [x] Existing FIFO queue retained.
- [x] Existing network wait and exponential retry/backoff retained.
- [x] Android client settings expose sync mode, batch size and interval.
- [x] SDK GitHub CI passed.
- [x] Changes merged to SDK `main`.
- [ ] Long offline accumulation test on device.
- [ ] Reconnect and verify FIFO drain with no lost/duplicated positions.
- [ ] Server-down test to confirm retry/backoff does not spin continuously.

---

## Task 5 — SDK Fork Integration

**Status:** merged to app `main`; reproducible source pin and upstream-maintenance documentation complete.

Checklist:

- [x] Fork `traccar/traccar-client-sdk` to `minhtuancn/traccar-client-sdk`.
- [x] Implement Fresh Heartbeat, Adaptive Profiles, Smart Sync and sync telemetry.
- [x] Pin the client to an immutable SDK commit using `vendor/traccar-client-sdk` gitlink.
- [x] Use Gradle composite-build dependency substitution instead of publishing over official Maven coordinates.
- [x] Add GitHub and Woodpecker CI definitions.
- [x] Document Android-only client source substitution and iOS packaging limitation.
- [x] Document routine SDK upstream sync/rebase procedure and conflict policy in `traccar-client-sdk/docs/UPSTREAM_SYNC.md`.
- [x] Upgrade Android build compatibility to Gradle 9.5.1 / AGP 9.2.0 / Kotlin 2.3.21.
- [x] Keep application ID `org.traccar.client` while separating app build namespace from the SDK namespace.
- [x] Changes merged to app `main`.
- [ ] Evaluate moving watchdog ownership into SDK only after equivalent Android recovery behavior is proven by device tests.

---

## Task 6 — Sync Status Telemetry

**Status:** merged to SDK/app `main`; automated CI complete; device validation pending.

Implemented:

- SQLDelight queue `COUNT(*)` exposed through `PositionQueue.count()`.
- `Tracker.pendingPositionCount()`.
- persisted nullable `State.lastSuccessfulSyncMillis` with backward-compatible state decoding.
- successful queue drain records last-success timestamp.
- Android enhanced bridge returns queue depth and last-success time.
- Status screen displays **Queued positions** and **Last successful sync**.

Checklist:

- [x] SDK telemetry contract tests added.
- [x] Backward-compatibility test added for persisted state without telemetry field.
- [x] SDK queue count and last-success timestamp implemented.
- [x] Client bridge/model/UI implemented.
- [x] Client gitlink pinned to the telemetry SDK commit.
- [x] SDK telemetry CI completed successfully.
- [x] Integrated client `flutter analyze` passed with zero issues.
- [x] Integrated client Flutter regression/integration tests passed (13 tests).
- [x] Integrated Android debug APK build and artifact upload succeeded.
- [x] Changes merged to SDK and app `main`.
- [ ] Device test: queue count rises while offline/held, falls after sync, and timestamp advances only after successful upload.

---

## Merge and beta milestone

All previously stacked pull requests have been merged in dependency order.

SDK:

```text
PR #1 Fresh Heartbeat
  -> PR #2 Adaptive Tracking Profiles
  -> PR #3 Smart Offline / Batch Sync
  -> PR #4 Sync Status Telemetry
  -> main
```

Client:

```text
PR #1 Managed-device + watchdog foundation
  -> PR #2 Enhanced SDK integration
  -> PR #3 Sync queue telemetry + Android toolchain compatibility
  -> main
```

Current beta version: `10.2.0-beta.1+159`.

See `CHANGELOG.md` and `docs/BETA_RELEASE.md` for the release-facing summary and device validation checklist.

---

## Production verification gate

Automated gates:

- [x] Client `flutter analyze` passes.
- [x] Client `flutter test` passes.
- [x] Android debug APK builds successfully with the pinned SDK submodule.
- [x] SDK core and Flutter wrapper verification pass.

Physical-device gates before calling the resilient-tracking work production-complete:

- [ ] Explicit Stop remains stopped across watchdog ticks and reboot.
- [ ] Ordinary process/service death recovers without opening Flutter UI.
- [ ] Stationary heartbeat uses a fresh/age-bounded location or liveness-only fallback as designed.
- [ ] Driving/walking/stationary transitions do not flap on the target Android device/OEM.
- [ ] Offline positions survive process death/reboot and later drain FIFO without loss/duplication.
- [ ] Retry/backoff behaves safely during prolonged network/server failure.
- [ ] Queue telemetry matches actual offline/sync behavior.
- [ ] Default Traccar endpoint behavior remains compatible with the target server.

Automated tests prove policy and build integrity; Android background reliability still requires real-device validation because Doze and OEM battery management cannot be faithfully proven by unit tests alone.
