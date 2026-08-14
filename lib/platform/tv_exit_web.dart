import 'dart:js_interop';

@JS('window.zingChartRequestExit')
external JSBoolean? _requestTvPlatformExit();

bool requestTvPlatformExit() {
  try {
    return _requestTvPlatformExit()?.toDart ?? false;
  } catch (_) {
    return false;
  }
}
