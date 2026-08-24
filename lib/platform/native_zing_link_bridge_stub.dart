typedef NativeZingLinkHandler = Future<void> Function(String route);

Future<String?> consumeInitialNativeZingRoute() async => null;

void setNativeZingLinkHandler(NativeZingLinkHandler? handler) {}
