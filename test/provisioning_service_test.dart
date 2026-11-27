import 'package:flutter_test/flutter_test.dart';
import 'package:traccar_client/provisioning_service.dart';
import 'package:traccar_client/preferences.dart';

void main() {
  test('only identity changes disable eligibility, not tracking tuning', () {
    expect(Preferences.identityChanged(currentId: '123', currentUrl: 'https://gps.go7s.net/'), isFalse);
    expect(Preferences.identityChanged(currentId: '123', currentUrl: 'https://gps.go7s.net/', nextId: '123', nextUrl: 'https://gps.go7s.net/'), isFalse);
    expect(Preferences.identityChanged(currentId: '123', currentUrl: 'https://gps.go7s.net/', nextId: '456'), isTrue);
  });

  final valid = {
    'deviceId': 'zg-0123456789abcdef0123456789abcdef',
    'name': 'Samsung A54-ABCDEF',
    'serverUrl': 'https://gps.go7s.net/',
  };

  test('accepts the reviewed ZalGps server and new unique ID', () {
    final result = ProvisioningService.validateResponse(valid);
    expect(result['id'], valid['deviceId']);
    expect(result['name'], valid['name']);
  });

  test('rejects foreign servers and existing arbitrary IDs', () {
    expect(
      () => ProvisioningService.validateResponse({...valid, 'serverUrl': 'https://example.org/'}),
      throwsFormatException,
    );
    expect(
      () => ProvisioningService.validateResponse({...valid, 'deviceId': '12345678'}),
      throwsFormatException,
    );
  });
}
