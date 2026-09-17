# Resilient Android Tracking — Execution Status

**Goal:** Make the Android Traccar Client fork survive ordinary service/process death, produce trustworthy stationary heartbeats, adapt tracking cadence to device state, retain positions through network loss, and expose enough telemetry to diagnose delivery health without breaking Traccar protocol compatibility.

**Architecture:** Flutter remains the UI/configuration layer. Location capture, heartbeat policy, adaptive profiles, durable queueing and Smart Sync live in the forked Traccar Client SDK. Android service recovery is supplemented by an app-layer watchdog until a stable SDK-level watchdog API is proven equivalent. The Android app consumes an immutable SDK gitlink through Gradle composite-build dependency substitution.

**Repositories:**

- App: `minhtuancn/traccar-client`
- SDK: `minhtuancn/traccar-client-sdk`

## Global constraints

- Android is the first production target; iOS behavior must not regress.
- Do not copy AGPL-3.0 Colota source. Architecture/behavior may be studied and reimplemented clean-room only.
- Do not hide the process or foreground location service from Android system/security surfaces.
- Never restart tracking after an explicit user Stop; persisted tracker intent is authoritative.
- Reuse the SDK SQLDelight queue; do not add a second Flutter queue.
- Preserve Traccar/OsmAnd request compatibility; Batch means bounded draining of ordinary requests, not a new JSON batch wire format.
- Android Force Stop remains a platform boundary and is not bypassed.

---

## Task 1 — Android Service Watchdog

**Status:** implementation complete; physical-device recovery gate pending.

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
- [ ] Verify ordinary process/service death recovery on a physical Android device.
- [ ] Reboot device and verify tracking/watchdog recovery without opening Flutter UI.
- [ ] Leave explicitly stopped for at least one watchdog interval and confirm it remains stopped.

---

## Task 2 — Fresh-Position Heartbeat

**Status:** SDK implementation and automated CI complete; device validation pending.

Implemented in SDK PR #1 and carried by the pinned SDK stack:

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
- [x] SDK GitHub CI passed for the heartbeat head.
- [ ] Physical stationary-device test: verify old cached coordinates are not represented as fresh fixes.

---

## Task 3 — Adaptive Tracking Profiles

**Status:** SDK implementation and automated CI complete; real motion/OEM validation pending.

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
- [x] SDK GitHub CI passed for the adaptive-profile head.
- [ ] Physical walking/driving/stationary transition test with noisy GPS/activity signals.
- [ ] Verify charging and low-battery profile priority on a real device.

---

## Task 4 — Smart Offline / Batch Sync

**Status:** queue policy and automated CI complete; long offline/reconnect validation pending.

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
- [x] SDK GitHub CI passed for Smart Sync head.
- [ ] Long offline accumulation test on device.
- [ ] Reconnect and verify FIFO drain with no lost/duplicated positions.
- [ ] Server-down test to confirm retry/backoff does not spin continuously.

---

## Task 5 — SDK Fork Integration

**Status:** Android integration complete and pinned; upstream-maintenance procedure still required.

Checklist:

- [x] Fork `traccar/traccar-client-sdk` to `minhtuancn/traccar-client-sdk`.
- [x] Implement Fresh Heartbeat, Adaptive Profiles and Smart Sync as stacked SDK PRs.
- [x] Pin the client to immutable SDK commits using `vendor/traccar-client-sdk` gitlink.
- [x] Use Gradle composite-build dependency substitution instead of publishing over official Maven coordinates.
- [x] Add GitHub and Woodpecker CI definitions.
- [x] Document Android-only client source substitution and iOS packaging limitation.
- [ ] Document routine upstream sync/rebase procedure and conflict policy.
- [ ] Evaluate moving watchdog ownership into SDK only after equivalent Android recovery behavior is proven by tests; until then keep the app-layer compatibility adapter.

---

## Task 6 — Sync Status Telemetry

**Status:** implementation complete on stacked SDK/client branches; CI and device validation pending.

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
- [x] GitHub client workflow changed so stacked pull requests are eligible for verification.
- [ ] SDK telemetry PR CI must complete successfully.
- [ ] Client `flutter analyze`, `flutter test` and Android debug APK build must complete successfully.
- [ ] Device test: queue count rises while offline/held, falls after sync, and timestamp advances only after successful upload.

---

## Current pull-request stack

SDK dependency order:

```text
SDK PR #1 Fresh Heartbeat
  -> SDK PR #2 Adaptive Tracking Profiles
  -> SDK PR #3 Smart Offline / Batch Sync
  -> SDK PR #4 Sync Status Telemetry
```

Client dependency order:

```text
Client PR #1 Managed-device + watchdog foundation
  -> Client PR #2 Enhanced SDK integration
  -> Client PR #3 Sync queue telemetry
```

SDK PR #1–#3 have successful GitHub CI evidence. SDK PR #4 and the client integration stack remain gated until their current automated verification completes successfully.

---

## Production verification gate

Do **not** call the resilient-tracking project production-complete until all of these are true:

- [ ] Client CI passes `flutter analyze`.
- [ ] Client CI passes `flutter test`.
- [ ] Client CI builds Android debug APK successfully with the pinned SDK submodule.
- [ ] Explicit Stop remains stopped across watchdog ticks and reboot.
- [ ] Ordinary process/service death recovers without opening Flutter UI.
- [ ] Stationary heartbeat uses a fresh/age-bounded location or liveness-only fallback as designed.
- [ ] Driving/walking/stationary transitions do not flap on the target Android device/OEM.
- [ ] Offline positions survive process death/reboot and later drain FIFO without loss/duplication.
- [ ] Retry/backoff behaves safely during prolonged network/server failure.
- [ ] Queue telemetry matches actual offline/sync behavior.
- [ ] Default Traccar endpoint behavior remains compatible with the target server.

Automated tests prove policy and build integrity; Android background reliability still requires real-device validation because Doze and OEM battery management cannot be faithfully proven by unit tests alone.
