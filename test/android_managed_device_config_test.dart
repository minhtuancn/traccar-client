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
}
