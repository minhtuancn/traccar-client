import 'dart:io';

import 'package:flutter/services.dart';

import 'preferences.dart';

class EnhancedTrackingStatus {
  const EnhancedTrackingStatus({
    required this.profile,
    required this.syncMode,
    required this.adaptiveEnabled,
  });

  final String profile;
  final String syncMode;
  final bool adaptiveEnabled;
}

class EnhancedTrackingService {
  static const MethodChannel _channel =
      MethodChannel('traccar_client/enhanced_tracking');

  static Future<void> apply() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('configure', {
      'adaptiveEnabled':
          Preferences.instance.getBool(Preferences.adaptiveTracking) ?? true,
      'syncMode':
          Preferences.instance.getString(Preferences.syncMode) ?? 'instant',
      'batchSize':
          Preferences.instance.getInt(Preferences.syncBatchSize) ?? 25,
      'batchIntervalSeconds':
          Preferences.instance.getInt(Preferences.syncBatchInterval) ?? 60,
      'heartbeatMaxAgeSeconds':
          Preferences.instance.getInt(Preferences.heartbeatMaxAge) ?? 300,
    });
  }

  static Future<EnhancedTrackingStatus?> getStatus() async {
    if (!Platform.isAndroid) return null;
    final raw = await _channel
        .invokeMapMethod<String, Object?>('getStatus');
    if (raw == null) return null;
    return EnhancedTrackingStatus(
      profile: raw['profile'] as String? ?? 'default',
      syncMode: raw['syncMode'] as String? ?? 'instant',
      adaptiveEnabled: raw['adaptiveEnabled'] as bool? ?? false,
    );
  }

  static Future<void> syncNow() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('syncNow');
  }
}
