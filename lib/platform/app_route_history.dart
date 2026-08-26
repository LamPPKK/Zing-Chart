import 'app_route_history_base.dart';
import 'app_route_history_stub.dart'
    if (dart.library.js_interop) 'app_route_history_web.dart'
    as implementation;

export 'app_route_history_base.dart';

AppRouteHistory createAppRouteHistory() =>
    implementation.createAppRouteHistory();
