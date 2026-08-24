import 'dart:io';

import 'package:flutter/services.dart';

typedef NativeZingLinkHandler = Future<void> Function(String route);

const _channel = MethodChannel('software.baycho.zmp3chart/deep_link');

bool get _usesNativeBridge =>
    Platform.isMacOS || Platform.operatingSystem == 'ohos';

Future<String?> consumeInitialNativeZingRoute() async {
  if (!_usesNativeBridge) return null;
  try {
    return await _channel.invokeMethod<String>('getInitialRoute');
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

void setNativeZingLinkHandler(NativeZingLinkHandler? handler) {
  if (!_usesNativeBridge) return;
  _channel.setMethodCallHandler(
    handler == null
        ? null
        : (call) async {
            if (call.method != 'open') return null;
            final arguments = call.arguments;
            final route = arguments is Map
                ? arguments['route'] as String?
                : null;
            if (route != null && route.trim().isNotEmpty) {
              await handler(route);
            }
            return null;
          },
  );
  if (handler != null) _announceReady();
}

Future<void> _announceReady() async {
  try {
    await _channel.invokeMethod<void>('ready');
  } on MissingPluginException {
    // The native target does not include the optional bridge.
  } on PlatformException {
    // Native launch support must never prevent the player from starting.
  }
}
