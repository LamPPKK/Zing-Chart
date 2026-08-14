import 'dart:io';

import 'system_media_bridge.dart';
import 'system_media_bridge_audio_service.dart';
import 'system_media_bridge_windows.dart';

Future<SystemMediaBridge> createSystemMediaBridge() {
  if (Platform.isWindows) return WindowsSystemMediaBridge.create();
  return AudioServiceMediaBridge.create();
}
