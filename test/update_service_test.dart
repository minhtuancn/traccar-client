import 'package:flutter_test/flutter_test.dart';
import 'package:traccar_client/update_service.dart';

void main() {
  const prefix = 'https://github.com/minhtuancn/traccar-client/releases/download/v10.2.0-beta.6/';
  final release = <String, dynamic>{
    'draft': false, 'prerelease': true, 'published_at': '2026-11-28T00:00:00Z',
    'tag_name': 'v10.2.0-beta.6',
    'assets': [
      {'name': 'zalgps-10.2.0-beta.6.update.json', 'browser_download_url': '${prefix}zalgps-10.2.0-beta.6.update.json', 'size': 400},
      {'name': 'zalgps-10.2.0-beta.6.apk', 'browser_download_url': '${prefix}zalgps-10.2.0-beta.6.apk', 'size': 70000000, 'digest': 'sha256:${List.filled(64, 'a').join()}'},
    ],
  };
  test('only published official beta assets qualify', () {
    expect(UpdateService.candidate(release), isNotNull);
    expect(UpdateService.candidate({...release, 'draft': true}), isNull);
    expect(UpdateService.candidate({...release, 'prerelease': false}), isNull);
    expect(UpdateService.candidate({...release, 'assets': []}), isNull);
    expect(UpdateService.candidate({...release, 'tag_name': 'v10.2.0'}), isNull);
  });
  test('redirects must use exact official HTTPS asset hosts', () {
    expect(UpdateService.trustedAssetRedirect(Uri.parse('https://release-assets.githubusercontent.com/path')), isTrue);
    for (final url in ['http://release-assets.githubusercontent.com/path', 'https://release-assets.githubusercontent.com.evil.test/', 'https://user@release-assets.githubusercontent.com/path', 'https://example.org/']) {
      expect(UpdateService.trustedAssetRedirect(Uri.parse(url)), isFalse);
    }
  });
}
