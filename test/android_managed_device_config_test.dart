import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main activity is excluded from Android recents', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:excludeFromRecents="true"'));
  });

  test('Android device admin receiver is registered', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:name=".ManagedDeviceAdminReceiver"'));
    expect(manifest, contains('android.permission.BIND_DEVICE_ADMIN'));
    expect(manifest, contains('android.app.device_admin'));
    expect(manifest, contains('android.app.action.DEVICE_ADMIN_ENABLED'));
  });

  test('managed device admin implementation and policy resource exist', () {
    final receiver = File(
      'android/app/src/main/kotlin/org/traccar/client/ManagedDeviceAdminReceiver.kt',
    );
    final policy = File(
      'android/app/src/main/res/xml/device_admin_receiver.xml',
    );

    expect(receiver.existsSync(), isTrue);
    expect(policy.existsSync(), isTrue);

    expect(
      receiver.readAsStringSync(),
      contains('class ManagedDeviceAdminReceiver : DeviceAdminReceiver()'),
    );
    expect(policy.readAsStringSync(), contains('<device-admin'));
  });

  test('tracking watchdog receivers are registered', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:name=".TrackingWatchdogReceiver"'));
    expect(
      manifest,
      contains('android:name=".TrackingWatchdogBootReceiver"'),
    );
    expect(manifest, contains('android.intent.action.BOOT_COMPLETED'));
    expect(manifest, contains('android.intent.action.MY_PACKAGE_REPLACED'));
  });

  test('watchdog uses persisted tracking intent and allow-while-idle alarm', () {
    final scheduler = File(
      'android/app/src/main/kotlin/org/traccar/client/TrackingWatchdogScheduler.kt',
    );
    final receiver = File(
      'android/app/src/main/kotlin/org/traccar/client/TrackingWatchdogReceiver.kt',
    );

    expect(scheduler.existsSync(), isTrue);
    expect(receiver.existsSync(), isTrue);

    final schedulerSource = scheduler.readAsStringSync();
    final receiverSource = receiver.readAsStringSync();
    expect(schedulerSource, contains('setAndAllowWhileIdle'));
    expect(schedulerSource, contains('ELAPSED_REALTIME_WAKEUP'));
    expect(receiverSource, contains('sharedTracker()'));
    expect(receiverSource, contains('tracker.state.value.enabled'));
    expect(receiverSource, contains('TrackingWatchdogScheduler.schedule'));
  });

  test('central tracking lifecycle arms and cancels the watchdog', () {
    final wrapper = File('lib/tracking_watchdog.dart');
    final service = File('lib/geolocation_service.dart').readAsStringSync();
    final screen = File('lib/main_screen.dart').readAsStringSync();

    expect(wrapper.existsSync(), isTrue);
    final wrapperSource = wrapper.readAsStringSync();
    expect(wrapperSource, contains("MethodChannel('traccar_client/watchdog')"));
    expect(wrapperSource, contains("invokeMethod<void>('arm')"));
    expect(wrapperSource, contains("invokeMethod<void>('cancel')"));

    expect(service, contains('await tracker.start();'));
    expect(service, contains('await TrackingWatchdog.arm();'));
    expect(service, contains('await tracker.stop();'));
    expect(service, contains('await TrackingWatchdog.cancel();'));

    expect(screen, contains('await GeolocationService.start();'));
    expect(screen, contains('await GeolocationService.stop();'));
    expect(screen, isNot(contains('TrackingWatchdog.arm()')));
    expect(screen, isNot(contains('TrackingWatchdog.cancel()')));
  });
}
