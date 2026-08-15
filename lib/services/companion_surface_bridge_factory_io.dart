import 'dart:io';

import 'package:flutter/services.dart';

import 'companion_surface_bridge.dart';

Future<CompanionSurfaceBridge> createCompanionSurfaceBridge() async {
  if (!Platform.isAndroid &&
      !Platform.isIOS &&
      !Platform.isMacOS &&
      Platform.operatingSystem != 'ohos') {
    return NoopCompanionSurfaceBridge();
  }
  return MethodChannelCompanionSurfaceBridge();
}

class MethodChannelCompanionSurfaceBridge implements CompanionSurfaceBridge {
  static const _channel = MethodChannel('software.baycho.zmp3chart/companion');

  CompanionCallbacks? _callbacks;

  @override
  Future<void> bind(CompanionCallbacks callbacks) async {
    _callbacks = callbacks;
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method != 'command' || _callbacks == null) return null;
    final arguments = call.arguments is Map
        ? Map<Object?, Object?>.from(call.arguments as Map)
        : const <Object?, Object?>{};
    final action = arguments['action'] as String?;
    switch (action) {
      case 'play':
        await _callbacks!.play();
      case 'pause':
        await _callbacks!.pause();
      case 'togglePlayPause':
        await _callbacks!.togglePlayPause();
      case 'previous':
        await _callbacks!.previous();
      case 'next':
        await _callbacks!.next();
      case 'stop':
        await _callbacks!.stop();
      case 'seekBackward':
        await _callbacks!.seekRelative(const Duration(seconds: -10));
      case 'seekForward':
        await _callbacks!.seekRelative(const Duration(seconds: 10));
    }
    return null;
  }

  @override
  Future<void> publish(CompanionPlayerSnapshot snapshot) =>
      _channel.invokeMethod<void>('publishSnapshot', snapshot.toMap());

  @override
  Future<void> dispose() async {
    _callbacks = null;
    _channel.setMethodCallHandler(null);
  }
}
