import 'package:flutter/widgets.dart';

import '../models/app_navigation_route.dart';
import '../models/official_zing_link.dart';

AppNavigationRoute? extractInitialAppNavigationRoute({
  required Uri baseUri,
  required String defaultRouteName,
  Iterable<String> arguments = const [],
}) {
  final legacyHashRoute = baseUri.fragment.startsWith('/')
      ? Uri.tryParse(baseUri.fragment)
      : null;
  final candidates = <Uri?>[
    Uri.tryParse(defaultRouteName.trim()),
    legacyHashRoute,
    ...arguments.map((argument) => Uri.tryParse(argument.trim())),
  ];
  for (final candidate in candidates) {
    if (candidate == null) continue;
    final route = _appNavigationRouteFromUri(
      candidate,
      basePath: '/',
      appBaseUri: baseUri,
    );
    if (route != null && _isImplicitDiscovery(candidate, route)) {
      continue;
    }
    if (route != null) return route;
  }
  if (baseUri.hasQuery) {
    final logicalQueryRoute = Uri(path: '/', query: baseUri.query);
    final route = _appNavigationRouteFromUri(
      logicalQueryRoute,
      basePath: '/',
      appBaseUri: baseUri,
    );
    if (route != null && !_isImplicitDiscovery(logicalQueryRoute, route)) {
      return route;
    }
  }
  return null;
}

AppNavigationRoute? initialAppNavigationRoute([
  Iterable<String> arguments = const [],
]) => extractInitialAppNavigationRoute(
  baseUri: Uri.base,
  defaultRouteName: WidgetsBinding.instance.platformDispatcher.defaultRouteName,
  arguments: arguments,
);

String? extractOfficialZingUrl({
  required Uri baseUri,
  required String defaultRouteName,
  Iterable<String> arguments = const [],
}) {
  final candidates = <String?>[
    baseUri.queryParameters['open'],
    _candidateFromRoute(defaultRouteName),
    ...arguments.map(_candidateFromRoute),
  ];
  for (final candidate in candidates) {
    final value = candidate?.trim() ?? '';
    if (OfficialZingLink.tryParse(value) != null) return value;
  }
  return null;
}

String? initialOfficialZingUrl([Iterable<String> arguments = const []]) =>
    extractOfficialZingUrl(
      baseUri: Uri.base,
      defaultRouteName:
          WidgetsBinding.instance.platformDispatcher.defaultRouteName,
      arguments: arguments,
    );

String? officialZingUrlFromRouteInformation(RouteInformation information) {
  final candidate = _candidateFromUri(information.uri)?.trim() ?? '';
  return OfficialZingLink.tryParse(candidate) == null ? null : candidate;
}

AppNavigationRoute? appNavigationRouteFromRouteInformation(
  RouteInformation information, {
  String basePath = '/',
  Uri? appBaseUri,
}) => _appNavigationRouteFromUri(
  information.uri,
  basePath: basePath,
  appBaseUri: appBaseUri,
);

String? officialZingUrlFromRouteName(String routeName) {
  final candidate = _candidateFromRoute(routeName)?.trim() ?? '';
  return OfficialZingLink.tryParse(candidate) == null ? null : candidate;
}

AppNavigationRoute? appNavigationRouteFromRouteName(
  String routeName, {
  String basePath = '/',
}) {
  final uri = Uri.tryParse(routeName.trim());
  return uri == null
      ? null
      : _appNavigationRouteFromUri(uri, basePath: basePath);
}

String? _candidateFromRoute(String routeName) {
  final raw = routeName.trim();
  if (raw.isEmpty || raw == '/') return null;
  final direct = Uri.tryParse(raw);
  if (direct == null) return null;
  return _candidateFromUri(direct);
}

String? _candidateFromUri(Uri uri) {
  if (OfficialZingLink.tryParse(uri.toString()) != null) {
    return uri.toString();
  }
  final openCandidate = uri.queryParameters['open'];
  if (openCandidate != null) return openCandidate;
  if (uri.scheme == 'zingchart' && uri.host == 'open') {
    return uri.queryParameters['url'];
  }
  if ((uri.scheme.isEmpty || uri.scheme == 'https') && uri.path == '/open') {
    return uri.queryParameters['url'];
  }
  return null;
}

AppNavigationRoute? _appNavigationRouteFromUri(
  Uri uri, {
  required String basePath,
  Uri? appBaseUri,
}) {
  final direct = OfficialZingLink.tryParse(uri.toString());
  if (direct != null) return AppNavigationRoute.official(direct);
  if (uri.fragment.isNotEmpty || uri.userInfo.isNotEmpty) return null;

  final parameters = uri.queryParametersAll;
  if (uri.scheme == 'zingchart' && uri.host == 'open') {
    if (parameters.length != 1 || !parameters.containsKey('url')) return null;
    final values = parameters['url']!;
    if (values.length != 1) return null;
    return AppNavigationRoute.fromOfficialUrl(values.single);
  }
  final isAppRoute =
      (!uri.hasScheme && !uri.hasAuthority) ||
      (appBaseUri != null &&
          uri.scheme.toLowerCase() == appBaseUri.scheme.toLowerCase() &&
          uri.host.toLowerCase() == appBaseUri.host.toLowerCase() &&
          uri.port == appBaseUri.port);
  if (isAppRoute && uri.path == '/open') {
    if (parameters.length != 1 || !parameters.containsKey('url')) return null;
    final values = parameters['url']!;
    if (values.length != 1) return null;
    return AppNavigationRoute.fromOfficialUrl(values.single);
  }
  return AppNavigationRoute.tryParse(
    uri,
    basePath: basePath,
    appBaseUri: appBaseUri,
  );
}

bool _isImplicitDiscovery(Uri uri, AppNavigationRoute route) =>
    route.shellDestination == AppShellDestination.discovery &&
    uri.queryParametersAll.isEmpty;
