import 'dart:io';

import 'package:flutter/services.dart';

class TrackingWatchdog {
  static const MethodChannel _channel = MethodChannel('traccar_client/watchdog');

  static Future<void> arm() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('arm');
  }

  static Future<void> cancel() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('cancel');
  }
}
