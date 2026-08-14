const _forcedTvMode = bool.fromEnvironment('TV_MODE');

Future<bool> detectTvMode() async => _forcedTvMode;
