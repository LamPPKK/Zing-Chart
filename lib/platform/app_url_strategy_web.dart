import 'package:flutter_web_plugins/url_strategy.dart';

void configureAppUrlStrategy({required bool enabled}) {
  if (enabled) usePathUrlStrategy();
}
