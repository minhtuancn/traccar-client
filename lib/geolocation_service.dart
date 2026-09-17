import 'package:traccar_client_sdk/traccar_client_sdk.dart';

import 'enhanced_tracking_service.dart';

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
}
