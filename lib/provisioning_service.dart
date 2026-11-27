import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'configuration_service.dart';
import 'geolocation_service.dart';
import 'preferences.dart';
import 'push_service.dart';

class ProvisioningService {
  static final Uri endpoint = Uri.parse('https://gps-api.go7s.net/v1/enroll');
  static const String gpsUrl = 'https://gps.go7s.net/';
  static const _storage = FlutterSecureStorage();
  static const _installationKey = 'zalgps_enrollment_installation';
  static const _deviceInfo = MethodChannel('zalgps/device_info');

  static Future<String> _installationId() async {
    final existing = await _storage.read(key: _installationKey);
    if (existing != null && RegExp(r'^[a-f0-9]{32}$').hasMatch(existing)) {
      return existing;
    }
    final random = Random.secure();
    final id = List.generate(16, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    await _storage.write(key: _installationKey, value: id);
    return id;
  }

  // Never accept an arbitrary server URL or an arbitrary existing device ID.
  static Map<String, dynamic> validateResponse(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid enrollment response');
    }
    final id = value['deviceId'];
    final name = value['name'];
    if (id is! String ||
        !RegExp(r'^zg-[a-f0-9]{32}$').hasMatch(id) ||
        name is! String ||
        name.isEmpty ||
        name.length > 100 ||
        value['serverUrl'] != gpsUrl) {
      throw const FormatException('Invalid enrollment response');
    }
    return <String, dynamic>{'id': id, 'name': name};
  }

  static Future<String> enroll(String code) async {
    if (!Platform.isAndroid ||
        !Preferences.canEnroll ||
        await GeolocationService.tracker.isTracking()) {
      throw StateError('Enrollment is only available before manual tracking');
    }
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(code)) {
      throw const FormatException('Invalid activation code');
    }
    final model = await _deviceInfo.invokeMethod<String>('model') ?? 'Android';
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.postUrl(endpoint).timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'activationCode': code,
        'installationId': await _installationId(),
        'model': model,
      }));
      final response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Enrollment rejected (${response.statusCode})');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        bytes.addAll(chunk);
        if (bytes.length > 8192) throw const FormatException('Response too large');
      }
      final registration = validateResponse(jsonDecode(utf8.decode(bytes)));
      if (!Preferences.canEnroll || await GeolocationService.tracker.isTracking()) {
        throw StateError('Tracking configuration changed during enrollment');
      }
      // The locally reviewed defaults are already set for fresh installations.
      // Do not apply arbitrary remote settings or start location tracking here.
      await ConfigurationService.applyParameters(
        {Preferences.id: registration['id']},
        url: gpsUrl,
        provisioning: true,
      );
      final name = registration['name'] as String;
      await Preferences.instance.setString(Preferences.provisionedName, name);
      await Preferences.disableEnrollment();
      unawaited(PushService.refreshRegistration());
      return name;
    } finally {
      client.close(force: true);
    }
  }
}
