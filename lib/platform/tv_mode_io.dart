import 'dart:io';

import 'package:flutter/services.dart';

const _forcedTvMode = bool.fromEnvironment('TV_MODE');
const _platformChannel = MethodChannel('software.baycho.zmp3chart/platform');

Future<bool> detectTvMode() async {
  if (_forcedTvMode) return true;
  if (!Platform.isAndroid) return false;
  try {
    return await _platformChannel.invokeMethod<bool>('isTelevision') ?? false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
