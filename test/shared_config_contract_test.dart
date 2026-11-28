import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:traccar_client/remote_config_policy.dart';

void main() {
  final fixtures = jsonDecode(File(
    'test/fixtures/client-control/v1/config-cases.json',
  ).readAsStringSync()) as List<dynamic>;
  for (final item in fixtures) {
    final fixture = item as Map<String, dynamic>;
    test('CTRL-01: ${fixture['name']}', () {
      final revision = fixture['currentRevision'] as int;
      final payload = fixture['payload'];
      if (fixture['accepted'] == true) {
        final result = RemoteConfigPolicy.validate(payload, revision);
        expect(result.revision, (payload as Map<String, dynamic>)['revision']);
        expect(result.settings, payload['settings']);
      } else {
        expect(
          () => RemoteConfigPolicy.validate(payload, revision),
          throwsFormatException,
        );
      }
    });
  }
}
