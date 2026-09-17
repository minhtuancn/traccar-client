# Resilient Android Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Android Traccar Client fork survive service/process death, produce trustworthy stationary heartbeats, adapt tracking cadence to motion state, and sync a durable offline queue intelligently without breaking Traccar protocol compatibility.

**Architecture:** Keep Flutter as the UI/configuration layer. Keep durable location capture, heartbeats, queueing and upload behavior in the Traccar Client SDK/native Android layer so behavior survives Flutter process death. Until `minhtuancn/traccar-client-sdk` exists, ship the watchdog as an Android app-layer extension that uses the SDK's public `sharedTracker()` / `TrackerService` APIs; migrate it into the SDK fork later without changing Flutter behavior.

**Tech Stack:** Flutter/Dart, Android Kotlin, AlarmManager, Traccar Client SDK 1.0.11+, Kotlin coroutines, SQLDelight durable queue.

**Spec:** `docs/ANDROID_MANAGED_DEVICE.md` plus the architecture decisions in this plan.

## Global Constraints

- Android is the first target; iOS behavior must not regress.
- Do not copy AGPL-3.0 Colota source code. Reimplement behavior clean-room from documented architecture/behavior only.
- Do not hide the process or foreground service from Android system-management surfaces.
- Never restart tracking after an explicit user Stop; persisted tracker intent/state is authoritative.
- Reuse the SDK SQLDelight queue; do not create a second location queue in the Flutter app.
- Preserve Traccar OsmAnd endpoint compatibility; initial batching means controlled queue draining, not an incompatible JSON-array protocol.
- Watchdog must use an inexact allow-while-idle alarm and re-arm itself; no exact-alarm permission is required.
- Background recovery must tolerate Android 12+ foreground-service start restrictions and notification permission differences.

---

## File Structure

### App repository (`minhtuancn/traccar-client`)

- `android/app/src/main/kotlin/org/traccar/client/TrackingWatchdogScheduler.kt`: owns watchdog alarm schedule/cancel only.
- `android/app/src/main/kotlin/org/traccar/client/TrackingWatchdogReceiver.kt`: checks persisted tracking intent/state and repairs a dead tracker service when allowed.
- `android/app/src/main/kotlin/org/traccar/client/TrackingWatchdogBootReceiver.kt`: re-arms the watchdog after reboot/app replacement.
- `android/app/src/main/kotlin/org/traccar/client/MainActivity.kt`: exposes a small MethodChannel for arm/cancel operations after explicit Start/Stop.
- `lib/tracking_watchdog.dart`: Dart wrapper around the Android MethodChannel; no-op on non-Android platforms.
- `lib/main_screen.dart`: arms watchdog after successful Start and cancels after Stop.
- `android/app/src/main/AndroidManifest.xml`: registers watchdog receivers.
- `test/android_managed_device_config_test.dart`: regression coverage for manifest and native extension files.

### Future SDK fork (`minhtuancn/traccar-client-sdk`)

- `core/src/commonMain/kotlin/org/traccar/client/HeartbeatPolicy.kt`: fresh-fix policy and maximum acceptable cached-fix age.
- `core/src/commonMain/kotlin/org/traccar/client/TrackingProfile.kt`: profile model and precedence.
- `core/src/commonMain/kotlin/org/traccar/client/TrackingProfileEngine.kt`: pure profile selection with hysteresis/debounce.
- `core/src/androidMain/kotlin/org/traccar/client/AndroidTrackingSignals.kt`: Android motion/charging inputs.
- `core/src/commonMain/kotlin/org/traccar/client/SyncPolicy.kt`: instant/periodic/offline queue-drain policy.
- `core/src/commonMain/kotlin/org/traccar/client/TrackerEngine.kt`: consumes heartbeat/profile/sync policies while retaining the existing SQLDelight queue.
- Flutter bridge files expose configuration/status only; they do not own runtime tracking logic.

---

### Task 1: Android Service Watchdog

**Files:**
- Create: `android/app/src/main/kotlin/org/traccar/client/TrackingWatchdogScheduler.kt`
- Create: `android/app/src/main/kotlin/org/traccar/client/TrackingWatchdogReceiver.kt`
- Create: `android/app/src/main/kotlin/org/traccar/client/TrackingWatchdogBootReceiver.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/src/main/kotlin/org/traccar/client/MainActivity.kt`
- Create: `lib/tracking_watchdog.dart`
- Modify: `lib/main_screen.dart`
- Test: `test/android_managed_device_config_test.dart`

**Interfaces:**
- Produces native MethodChannel `traccar_client/watchdog` methods `arm` and `cancel`.
- Watchdog interval: 15 minutes; first arm after explicit Start may use the same interval.
- Receiver calls `sharedTracker()`, returns without re-arming when tracker is absent or `state.value.enabled == false`, and otherwise ensures `TrackerService` is started before re-arming.

- [ ] **Step 1: Write failing regression tests**
  Assert manifest contains both watchdog receivers, scheduler uses `setAndAllowWhileIdle`, receiver reads `tracker.state.value.enabled`, and Dart Start/Stop paths invoke the watchdog wrapper.

- [ ] **Step 2: Run tests and confirm RED**
  Run `flutter test test/android_managed_device_config_test.dart` and expect failures for missing watchdog files/registrations.

- [ ] **Step 3: Implement scheduler, receiver, boot re-arm and MethodChannel**
  Use `AlarmManager.ELAPSED_REALTIME_WAKEUP`, `SystemClock.elapsedRealtime() + 15min`, immutable/update-current `PendingIntent`, and `setAndAllowWhileIdle` on API 23+.

- [ ] **Step 4: Add explicit Start/Stop hooks**
  On successful `tracker.start()`, call `TrackingWatchdog.arm()`. After `tracker.stop()`, call `TrackingWatchdog.cancel()`.

- [ ] **Step 5: Verify**
  Run `flutter test`, `flutter analyze`, and `flutter build apk --debug`.

- [ ] **Step 6: Device tests**
  Start tracking, force-stop only the service/process where possible without issuing Android Settings Force Stop, wait for/watchdog trigger, verify service returns. Reboot and verify boot recovery + watchdog re-arm. Explicit Stop must remain stopped after 20+ minutes.

---

### Task 2: Fresh-Position Heartbeat Policy (SDK fork)

**Interfaces:**
- Add `heartbeatFreshFix: Boolean = true`.
- Add `heartbeatMaxAgeSeconds: Int = 120`.
- Keep `heartbeatIntervalSeconds` as cadence.
- Heartbeat attempts a fresh fix for up to the existing 30-second location fetch timeout; a last-known fallback is accepted only when its age is within policy. Otherwise emit a metadata/time-only heartbeat only if the server/protocol path supports it safely.

- [ ] Write pure policy tests covering fresh, cached-within-age, stale and no-fix cases.
- [ ] Implement `HeartbeatPolicy` and integrate into `TrackerEngine.applyHeartbeatTick()`.
- [ ] Preserve the existing queue pipeline and location processors.
- [ ] Bridge the new config values through Flutter.
- [ ] Add client settings with conservative defaults.
- [ ] Run SDK unit tests plus Flutter client tests/build.

---

### Task 3: Adaptive Tracking Profiles (SDK fork)

**Interfaces:**
- Profiles: `DRIVING`, `WALKING`, `STATIONARY`, `CHARGING`, `BATTERY_SAVER`, plus base/default.
- Profile output is an effective `LocationConfig` plus `SyncPolicy`; user base config remains immutable.
- Selection uses priority + activation/deactivation debounce to prevent flapping.

Initial presets:

| Profile | Location interval | Distance | Heartbeat | Queue drain |
| --- | ---: | ---: | ---: | --- |
| Driving | 10 s | 10 m | disabled while moving | instant |
| Walking | 30 s | 15 m | disabled while moving | instant/30 s |
| Stationary | paused/low-power | n/a | 15 min fresh-fix | instant |
| Charging | 10 s | 5 m | normal | instant |
| Battery saver | 180 s | 75 m | 30 min | 300 s |

- [ ] Write pure profile-selection tests first: precedence, debounce, transition hysteresis and low-battery override.
- [ ] Implement platform-neutral `TrackingProfileEngine`.
- [ ] Feed Android motion/activity and charging/battery signals into the engine.
- [ ] Apply effective config without resetting persisted user intent or losing queued positions.
- [ ] Expose active profile/status to Flutter UI.
- [ ] Verify profile transitions with fake signals and Android device tests.

---

### Task 4: Smart Offline / Batch Sync (SDK fork)

**Interfaces:**
- `SyncMode`: `INSTANT`, `PERIODIC`, `OFFLINE`.
- `syncIntervalSeconds` controls periodic drain cadence.
- `drainLimit` bounds positions per pass to avoid radio/server bursts.
- Network policy initially supports `ANY` and `UNMETERED`; Android-specific VPN/SSID constraints can follow without changing queue format.
- Existing SQLDelight `PositionQueue` remains the single durable source of pending uploads.

- [ ] Write queue-drain tests for offline accumulation, network restore, bounded periodic draining, retry backoff and order preservation.
- [ ] Refactor `TrackerEngine.syncLoop()` behind a `SyncPolicy` without changing current default behavior.
- [ ] Add periodic/offline modes and bounded drain passes.
- [ ] Preserve exponential backoff and FIFO semantics.
- [ ] Expose queue count, last successful sync and current sync mode through SDK Flutter bridge.
- [ ] Add status UI and manual `Sync now` action when policy permits.
- [ ] Run long offline/reconnect device test and verify no positions are lost or duplicated.

---

### Task 5: SDK Fork Integration

- [ ] Fork `traccar/traccar-client-sdk` to `minhtuancn/traccar-client-sdk`.
- [ ] Implement Tasks 2-4 on feature branches/PRs in that fork.
- [ ] Publish a forked package or pin the client to an immutable Git commit/tag.
- [ ] Move the app-layer watchdog into the SDK once a stable SDK watchdog API exists; keep the Flutter `TrackingWatchdog` wrapper temporarily as a compatibility adapter.
- [ ] Remove duplicate watchdog code only after migration tests prove equivalent recovery behavior.
- [ ] Document upstream sync/rebase procedure so future official SDK fixes can be pulled without overwriting custom extensions.

---

## Verification Gate

Before declaring the resilient-tracking work complete, all of the following must be true:

- Explicit Stop remains stopped across watchdog ticks and reboot.
- OS/process death recovery does not require opening Flutter UI.
- Stationary device emits a heartbeat using a fresh or age-bounded location according to policy.
- Driving/walking/stationary transitions do not flap under noisy GPS/activity signals.
- Offline positions survive process death/reboot and later upload FIFO without loss.
- Retry/backoff cannot spin continuously while offline/server-down.
- Default Traccar endpoint behavior remains compatible with existing server installations.
- Android CI passes `flutter analyze`, `flutter test`, and APK build.
