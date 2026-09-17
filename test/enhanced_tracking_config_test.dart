import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('enhanced tracking bridge exposes configure status and manual sync', () {
    final native = File(
      'android/app/src/main/kotlin/org/traccar/client/EnhancedTrackingBridge.kt',
    ).readAsStringSync();

    expect(native, contains('"configure"'));
    expect(native, contains('"getStatus"'));
    expect(native, contains('"syncNow"'));
    expect(native, contains('adaptiveTracking = current.adaptiveTracking.copy('));
    expect(native, contains('enabled = adaptiveEnabled'));
    expect(native, contains('SmartSyncConfig'));
    expect(native, contains('heartbeatMaxAgeSeconds'));
  });

  test('all base SDK config writes reapply fork enhancements', () {
    final service = File('lib/geolocation_service.dart').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final settings = File('lib/settings_screen.dart').readAsStringSync();
    final configuration = File('lib/configuration_service.dart').readAsStringSync();

    expect(service, contains('EnhancedTrackingService.apply'));
    expect(service, contains('Future<void> init'));
    expect(service, contains('Future<void> setConfig'));
    expect(main, contains('GeolocationService.init('));
    expect(settings, isNot(contains('GeolocationService.tracker.setConfig')));
    expect(configuration, isNot(contains('GeolocationService.tracker.setConfig')));
  });

  test('enhanced preferences persist adaptive and sync settings', () {
    final preferences = File('lib/preferences.dart').readAsStringSync();

    expect(preferences, contains("adaptiveTracking = 'adaptive_tracking'"));
    expect(preferences, contains("syncMode = 'sync_mode'"));
    expect(preferences, contains("heartbeatMaxAge = 'heartbeat_max_age'"));
  });
}
