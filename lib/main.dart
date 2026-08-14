import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'data/library_repository.dart';
import 'data/music_repository.dart';
import 'music_player_controller.dart';
import 'music_player_scope.dart';
import 'platform/platform_setup.dart';
import 'widgets/configuration_error_screen.dart';
import 'zing_chart_screen.dart';
import 'zing_mp3_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializePlatformWindow();
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
  runApp(MyApp(playerController: playerController));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.playerController, this.home});

  final MusicPlayerController playerController;
  final Widget? home;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    widget.playerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF101113);
    const paper = Color(0xFFF5F0E8);
    const coral = Color(0xFFFF6B4A);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: coral,
      brightness: Brightness.dark,
      surface: ink,
    );

    return MusicPlayerScope(
      controller: widget.playerController,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '#zingChart',
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: colorScheme,
          scaffoldBackgroundColor: ink,
          fontFamily: 'sans-serif',
          textTheme: ThemeData.dark().textTheme.apply(
            bodyColor: paper,
            displayColor: paper,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            foregroundColor: paper,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF1C1D20),
            hintStyle: const TextStyle(color: Color(0xFF929296)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFF36373B)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFF36373B)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: coral, width: 2),
            ),
          ),
        ),
        home: widget.home ?? const ZingChartScreen(),
      ),
    );
  }
}
