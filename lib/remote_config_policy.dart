/// Client-side independent validation for future opt-in remote configuration.
/// Pure data validation; no network, storage, permission or tracking actions.
class RemoteConfigPolicy {
  static const _ranges = <String, (int, int)>{
    'interval': (15, 3600), 'distance': (10, 1000), 'heartbeat': (60, 3600),
    'sync_batch_size': (1, 100), 'sync_batch_interval': (30, 3600),
    'heartbeat_max_age': (30, 900),
  };
  static const _enums = <String, Set<String>>{
    'accuracy': {'high', 'medium', 'low'},
    'sync_mode': {'instant', 'batch', 'offline'},
  };

  static ({int revision, Map<String, Object> settings}) validate(
      Object? payload, int currentRevision) {
    const invalid = FormatException('Invalid remote configuration');
    if (currentRevision < 0 || payload is! Map<String, dynamic> ||
        payload.length != 3 || payload['schema'] is! int || payload['schema'] != 1) {
      throw invalid;
    }
    final revision = payload['revision'];
    final settings = payload['settings'];
    if (revision is! int || revision <= currentRevision ||
        revision > 9007199254740991 || settings is! Map<String, dynamic> ||
        settings.isEmpty) throw invalid;
    final result = <String, Object>{};
    for (final entry in settings.entries) {
      final value = entry.value;
      final range = _ranges[entry.key];
      final choices = _enums[entry.key];
      if (range != null) {
        if (value is! int || value < range.$1 || value > range.$2) throw invalid;
      } else if (choices != null) {
        if (value is! String || !choices.contains(value)) throw invalid;
      } else if (entry.key == 'adaptive_tracking') {
        if (value is! bool) throw invalid;
      } else {
        throw invalid;
      }
      result[entry.key] = value as Object;
    }
    return (revision: revision, settings: Map.unmodifiable(result));
  }
}
