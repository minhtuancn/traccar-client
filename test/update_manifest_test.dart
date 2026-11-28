import 'package:flutter_test/flutter_test.dart';
import 'package:traccar_client/update_manifest.dart';

void main() {
  final valid = <String, dynamic>{
    'schema': 1,
    'applicationId': 'org.traccar.client',
    'certificateSha256': UpdateManifest.certificate,
    'version': '10.2.0-beta.6',
    'versionCode': 164,
    'sha256': List.filled(64, 'a').join(),
    'size': 70000000,
    'apkUrl': 'https://github.com/minhtuancn/traccar-client/releases/download/v10.2.0-beta.6/zalgps-10.2.0-beta.6.apk',
  };
  test('accepts official metadata and compares Android build numbers', () {
    final manifest = UpdateManifest.parse(valid);
    expect(manifest.isNewerThan(163), isTrue);
    expect(manifest.isNewerThan(164), isFalse);
    expect(manifest.isNewerThan(165), isFalse);
  });
  test('rejects untrusted or malformed metadata', () {
    for (final change in <Map<String, dynamic>>[
      {'schema': 2}, {'version': '10.2.0'}, {'versionCode': '164'},
      {'versionCode': 0}, {'size': 999999999}, {'sha256': 'bad'},
      {'applicationId': 'other.app'}, {'certificateSha256': 'wrong'},
      {'apkUrl': 'https://example.org/app.apk'}, {'apkUrl': '${valid['apkUrl']}?redirect=1'},
    ]) {
      expect(() => UpdateManifest.parse({...valid, ...change}), throwsFormatException);
    }
  });
}
