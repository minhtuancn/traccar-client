# Build verification status

This file tracks verification evidence for the resilient Android tracking fork.

## SDK stack

- Fresh-position Heartbeat — CI verified on SDK PR #1.
- Adaptive Tracking Profiles — CI verified on SDK PR #2.
- Smart Offline / Batch Sync — CI verified on SDK PR #3.
- Sync Status Telemetry — CI run #15 passed on SDK head `58a7b266170ebbdecfa5f22ba04822ba791edb71`.

## Client integration

Required automated gate for the final Android integration head:

1. initialize git submodules recursively;
2. run pinned SDK core verification;
3. run `flutter pub get`;
4. run `flutter analyze`;
5. run `flutter test`;
6. run `flutter build apk --debug`;
7. publish the resulting debug APK as a CI artifact.

Physical-device validation remains a separate release gate for reboot recovery, stationary heartbeat, adaptive profile transitions, offline queue recovery and telemetry behavior.
