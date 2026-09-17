import 'package:traccar_client_sdk/traccar_client_sdk.dart';

import 'enhanced_tracking_service.dart';
import 'tracking_watchdog.dart';

class GeolocationService {
  static final tracker = TraccarClientSdk();

  static Future<void> init(Config config) async {
    await tracker.init(config);
    await EnhancedTrackingService.apply();
  }

  static Future<void> setConfig(Config config) async {
    await tracker.setConfig(config);
    await EnhancedTrackingService.apply();
  }

  static Future<void> start() async {
    await tracker.start();
    try {
      await TrackingWatchdog.arm();
    } catch (_) {
      // Tracking remains valid even if the optional app-layer watchdog bridge
      // is unavailable. The SDK foreground service/boot recovery still apply.
    }
  }

  static Future<void> stop() async {
    await tracker.stop();
    try {
      await TrackingWatchdog.cancel();
    } catch (_) {
      // Do not turn a successful explicit stop into an application error.
    }
  }
}
