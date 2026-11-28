import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:traccar_client/update_manifest.dart';

void main() {
  test('installer provider is limited to private update cache and not exported', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final paths = File('android/app/src/main/res/xml/update_file_paths.xml').readAsStringSync();
    expect(manifest, contains('org.traccar.client.UpdateFileProvider'));
    expect(manifest, contains(r'android:authorities="${applicationId}.updates"'));
    expect(paths, contains('path="zalgps-updates/"'));
    expect(paths, isNot(contains('root-path')));
    expect(paths, isNot(contains('external-path')));
  });
  test('native installer checks installed and candidate identities before launching Android UI', () {
    final native = File('android/app/src/main/kotlin/org/traccar/client/UpdateInstaller.kt').readAsStringSync();
    expect(native, contains(UpdateManifest.certificate));
    expect(native, contains('candidate.build > build(installed)'));
    expect(native, contains('signer(archive) == CERTIFICATE'));
    expect(native, contains('hex(digest.digest()) == candidate.hash'));
    expect(native, contains('archive.packageName == activity.packageName'));
    expect(native, contains('canRequestPackageInstalls()'));
    expect(native, contains('Intent.ACTION_VIEW'));
    expect(native, isNot(contains('DevicePolicyManager')));
  });
}
