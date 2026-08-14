import 'system_media_bridge.dart';
import 'system_media_bridge_audio_service.dart';

Future<SystemMediaBridge> createSystemMediaBridge() =>
    AudioServiceMediaBridge.create();
