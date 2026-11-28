/// Coalesces concurrent diagnostic refresh requests. No tracking side effects.
class StatusRefreshGate {
  bool _running = false;
  bool _disposed = false;

  Future<bool> run(Future<void> Function() refresh) async {
    if (_running || _disposed) return false;
    _running = true;
    try {
      await refresh();
      return true;
    } finally {
      _running = false;
    }
  }

  void dispose() => _disposed = true;
}
