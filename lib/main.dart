import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'data/library_repository.dart';
import 'data/music_repository.dart';
import 'music_player_controller.dart';
import 'music_player_scope.dart';
import 'models/local_library.dart';
import 'platform/platform_setup.dart';
import 'platform/initial_zing_link.dart';
import 'platform/native_zing_link_bridge.dart';
import 'platform/tv_mode.dart';
import 'theme/app_theme.dart';
import 'widgets/configuration_error_screen.dart';
import 'zing_chart_screen.dart';
import 'zing_mp3_api.dart';

typedef AppHomeBuilder = Widget Function(String? officialUrl);

Future<void> main(List<String> arguments) async {
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
    qualitySourceResolver: (code, quality) =>
        repository.getSongSource(code, quality: quality),
    songRadioLoader: repository.getSongRadio,
    liveRadioSourceResolver: repository.getLiveRadioSource,
    libraryRepository: SharedPreferencesLibraryRepository(),
  );
  await playerController.initialize();
  final nativeRoute = await consumeInitialNativeZingRoute();
  runApp(
    MyApp(
      playerController: playerController,
      tvMode: tvMode,
      initialOfficialUrl: initialOfficialZingUrl([
        ...arguments,
        if (nativeRoute != null) nativeRoute,
      ]),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    required this.playerController,
    this.home,
    this.homeBuilder,
    this.tvMode = false,
    this.initialOfficialUrl,
  });

  final MusicPlayerController playerController;
  final Widget? home;
  final AppHomeBuilder? homeBuilder;
  final bool tvMode;
  final String? initialOfficialUrl;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late AppThemePreference _themePreference;
  String? _officialUrl;
  int _officialUrlRevision = 0;

  @override
  void initState() {
    super.initState();
    _themePreference = widget.playerController.themePreference;
    _officialUrl = widget.initialOfficialUrl;
    WidgetsBinding.instance.addObserver(this);
    setNativeZingLinkHandler(_handleNativeZingRoute);
    widget.playerController.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant MyApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialOfficialUrl != widget.initialOfficialUrl) {
      _officialUrl = widget.initialOfficialUrl;
      _officialUrlRevision++;
    }
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
    WidgetsBinding.instance.removeObserver(this);
    setNativeZingLinkHandler(null);
    widget.playerController.removeListener(_handleControllerChanged);
    widget.playerController.dispose();
    super.dispose();
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) {
    final candidate = officialZingUrlFromRouteInformation(routeInformation);
    if (candidate == null) return Future<bool>.value(false);
    _applyOfficialUrl(candidate);
    return Future<bool>.value(true);
  }

  Future<void> _handleNativeZingRoute(String route) async {
    final candidate = officialZingUrlFromRouteName(route);
    if (candidate == null || !mounted) return;
    _applyOfficialUrl(candidate);
  }

  void _applyOfficialUrl(String candidate) {
    setState(() {
      _officialUrl = candidate;
      _officialUrlRevision++;
    });
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return MusicPlayerScope(
      controller: widget.playerController,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        title: '#zingChart',
        themeMode: switch (_themePreference) {
          AppThemePreference.system => ThemeMode.system,
          AppThemePreference.light => ThemeMode.light,
          AppThemePreference.dark => ThemeMode.dark,
        },
        theme: buildZingLightTheme(tvMode: widget.tvMode),
        darkTheme: buildZingDarkTheme(tvMode: widget.tvMode),
        home:
            widget.home ??
            widget.homeBuilder?.call(_officialUrl) ??
            ZingChartScreen(
              tvMode: widget.tvMode,
              initialOfficialUrl: _officialUrl,
              officialUrlRevision: _officialUrlRevision,
              searchCatalogPage: (query, section, page, limit) =>
                  ZingMP3API.searchCatalogPage(
                    query,
                    section,
                    page: page,
                    limit: limit,
                  ),
              loadChartSuggestion: ZingMP3API.getDiscoveryRecommendations,
            ),
      ),
    );
  }
}
