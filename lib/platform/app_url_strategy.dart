import 'app_url_strategy_stub.dart'
    if (dart.library.js_interop) 'app_url_strategy_web.dart'
    as implementation;

void configureAppUrlStrategy({required bool enabled}) =>
    implementation.configureAppUrlStrategy(enabled: enabled);
