import 'package:flutter/widgets.dart';

import '../models/official_zing_link.dart';

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

String? officialZingUrlFromRouteName(String routeName) {
  final candidate = _candidateFromRoute(routeName)?.trim() ?? '';
  return OfficialZingLink.tryParse(candidate) == null ? null : candidate;
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
