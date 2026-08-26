abstract interface class AppRouteHistory {
  Future<void> initialize();

  Future<void> update(Uri uri, {required bool replace});

  /// Returns whether a platform history request was dispatched.
  bool back();

  /// Returns whether a platform history request was dispatched.
  bool forward();
}

/// History adapter used by TV shells and non-browser hosts.
///
/// Keeping this adapter in the shared layer lets Web-based TV packages avoid
/// touching `window.history` even though they are compiled with Web support.
class NoopAppRouteHistory implements AppRouteHistory {
  const NoopAppRouteHistory();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> update(Uri uri, {required bool replace}) async {}

  @override
  bool back() => false;

  @override
  bool forward() => false;
}
