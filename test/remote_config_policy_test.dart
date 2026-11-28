import 'package:flutter_test/flutter_test.dart';
import 'package:traccar_client/remote_config_policy.dart';

void main() {
  Map<String, dynamic> envelope(Map<String, dynamic> settings, {int revision = 2}) =>
      {'schema': 1, 'revision': revision, 'settings': settings};
  test('matches server allowlist and returns immutable settings', () {
    final result = RemoteConfigPolicy.validate(envelope({'interval': 30, 'distance': 25, 'adaptive_tracking': true, 'sync_mode': 'batch'}), 1);
    expect(result.revision, 2);
    expect(result.settings['interval'], 30);
    expect(() => result.settings['interval'] = 1, throwsUnsupportedError);
  });
  test('rejects forbidden fields, invalid values and stale revisions', () {
    for (final value in <Map<String, dynamic>>[
      {'id': 'other'}, {'url': 'other'}, {'tracking': true}, {'buffer': false},
      {'permissions': true}, {'location_commands_allowed': true},
      {'interval': true}, {'interval': 1}, {'accuracy': 'highest'},
      {'heartbeat_max_age': 0}, {'adaptive_tracking': 1}, {},
    ]) {
      expect(() => RemoteConfigPolicy.validate(envelope(value), 1), throwsFormatException);
    }
    expect(() => RemoteConfigPolicy.validate(envelope({'interval': 30}, revision: 1), 1), throwsFormatException);
  });
}
