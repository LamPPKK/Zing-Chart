import 'dart:js_interop';

import 'package:flutter/services.dart';

import 'app_route_history_base.dart';

AppRouteHistory createAppRouteHistory() => const _WebAppRouteHistory();

class _WebAppRouteHistory implements AppRouteHistory {
  const _WebAppRouteHistory();

  @override
  Future<void> initialize() => SystemNavigator.selectMultiEntryHistory();

  @override
  Future<void> update(Uri uri, {required bool replace}) async {
    // MaterialApp's root Navigator selects single-entry history during its
    // initialization. Reassert multi-entry immediately before every update so
    // push/replace semantics remain deterministic after the first frame.
    await SystemNavigator.selectMultiEntryHistory();
    await SystemNavigator.routeInformationUpdated(uri: uri, replace: replace);
  }

  @override
  bool back() {
    _browserHistoryBack();
    return true;
  }

  @override
  bool forward() {
    _browserHistoryForward();
    return true;
  }
}

@JS('window.history.back')
external void _browserHistoryBack();

@JS('window.history.forward')
external void _browserHistoryForward();
