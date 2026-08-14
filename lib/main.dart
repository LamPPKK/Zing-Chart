import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'data/library_repository.dart';
import 'data/music_repository.dart';
import 'music_player_controller.dart';
import 'music_player_scope.dart';
import 'models/local_library.dart';
import 'platform/platform_setup.dart';
import 'platform/tv_mode.dart';
import 'theme/app_theme.dart';
import 'widgets/configuration_error_screen.dart';
import 'zing_chart_screen.dart';
import 'zing_mp3_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializePlatformWindow();
  final tvMode = await detectTvMode();
  final config = AppConfig.fromEnvironment();
  if (!config.isValid) {
    runApp(ConfigurationErrorScreen(message: config.errorMessage!));
    return;
  }
  final repository = CachingMusicRepository(
    ProxyMusicRepository(baseUrl: config.apiBaseUrl),
  );
  ZingMP3API.configure(repository);
  final playerController = MusicPlayerController(
    sourceResolver: repository.getSongSource,
    libraryRepository: SharedPreferencesLibraryRepository(),
  );
  await playerController.initialize();
  runApp(MyApp(playerController: playerController, tvMode: tvMode));
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    required this.playerController,
    this.home,
    this.tvMode = false,
  });

  final MusicPlayerController playerController;
  final Widget? home;
  final bool tvMode;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppThemePreference _themePreference;

  @override
  void initState() {
    super.initState();
    _themePreference = widget.playerController.themePreference;
    widget.playerController.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant MyApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerController == widget.playerController) return;
    oldWidget.playerController.removeListener(_handleControllerChanged);
    _themePreference = widget.playerController.themePreference;
    widget.playerController.addListener(_handleControllerChanged);
  }

  void _handleControllerChanged() {
    final next = widget.playerController.themePreference;
    if (next != _themePreference && mounted) {
      setState(() => _themePreference = next);
    }
  }

  @override
  void dispose() {
    widget.playerController.removeListener(_handleControllerChanged);
    widget.playerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MusicPlayerScope(
      controller: widget.playerController,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '#zingChart',
        themeMode: switch (_themePreference) {
          AppThemePreference.system => ThemeMode.system,
          AppThemePreference.light => ThemeMode.light,
          AppThemePreference.dark => ThemeMode.dark,
        },
        theme: buildZingLightTheme(tvMode: widget.tvMode),
        darkTheme: buildZingDarkTheme(tvMode: widget.tvMode),
        home: widget.home ?? ZingChartScreen(tvMode: widget.tvMode),
      ),
    );
  }
}
