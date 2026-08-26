import 'dart:async';

import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'data/library_repository.dart';
import 'data/music_repository.dart';
import 'music_player_controller.dart';
import 'music_player_scope.dart';
import 'models/app_navigation_route.dart';
import 'models/local_library.dart';
import 'platform/app_route_history.dart';
import 'platform/app_url_strategy.dart';
import 'platform/initial_zing_link.dart';
import 'platform/native_zing_link_bridge.dart';
import 'platform/platform_setup.dart';
import 'platform/tv_mode.dart';
import 'theme/app_theme.dart';
import 'widgets/configuration_error_screen.dart';
import 'zing_chart_screen.dart';
import 'zing_mp3_api.dart';

typedef AppHomeBuilder = Widget Function(String? officialUrl);

Future<void> main(List<String> arguments) async {
  const forcedTvMode = bool.fromEnvironment('TV_MODE');
  configureAppUrlStrategy(enabled: !forcedTvMode);
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
  final navigationRoute = initialAppNavigationRoute([
    ...arguments,
    if (nativeRoute != null) nativeRoute,
  ]);
  runApp(
    MyApp(
      playerController: playerController,
      tvMode: tvMode,
      initialNavigationRoute: navigationRoute,
      initialOfficialUrl: navigationRoute?.officialLink?.canonicalUri
          .toString(),
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
    this.initialNavigationRoute,
    this.routeHistory,
    this.routeBaseUri,
  });

  final MusicPlayerController playerController;
  final Widget? home;
  final AppHomeBuilder? homeBuilder;
  final bool tvMode;
  final String? initialOfficialUrl;
  final AppNavigationRoute? initialNavigationRoute;
  final AppRouteHistory? routeHistory;
  final Uri? routeBaseUri;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late AppThemePreference _themePreference;
  late final AppRouteHistory _routeHistory;
  late final Future<void> _routeHistoryReady;
  late final Uri _appBaseUri;
  AppNavigationRoute? _navigationRoute;
  String? _officialUrl;
  int _navigationRouteRevision = 0;
  String? _lastPlatformLocation;

  @override
  void initState() {
    super.initState();
    _themePreference = widget.playerController.themePreference;
    _routeHistory =
        widget.routeHistory ??
        (widget.tvMode ? const NoopAppRouteHistory() : createAppRouteHistory());
    _routeHistoryReady = _initializeRouteHistory();
    _appBaseUri = widget.routeBaseUri ?? Uri.base;
    _navigationRoute =
        widget.initialNavigationRoute ??
        AppNavigationRoute.fromOfficialUrl(widget.initialOfficialUrl ?? '');
    _officialUrl =
        widget.initialOfficialUrl ??
        _navigationRoute?.officialLink?.canonicalUri.toString();
    WidgetsBinding.instance.addObserver(this);
    setNativeZingLinkHandler(_handleNativeZingRoute);
    widget.playerController.addListener(_handleControllerChanged);
  }

  Future<void> _initializeRouteHistory() async {
    // MaterialApp's legacy Navigator selects single-entry Web history while it
    // mounts. Waiting for the first frame lets the adapter make multi-entry the
    // final selection before the first canonical route update is written.
    await WidgetsBinding.instance.endOfFrame;
    await _routeHistory.initialize();
  }

  @override
  void didUpdateWidget(covariant MyApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialOfficialUrl != widget.initialOfficialUrl ||
        oldWidget.initialNavigationRoute?.identity !=
            widget.initialNavigationRoute?.identity) {
      _navigationRoute =
          widget.initialNavigationRoute ??
          AppNavigationRoute.fromOfficialUrl(widget.initialOfficialUrl ?? '');
      _officialUrl =
          widget.initialOfficialUrl ??
          _navigationRoute?.officialLink?.canonicalUri.toString();
      _navigationRouteRevision++;
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
    final route = appNavigationRouteFromRouteInformation(
      routeInformation,
      appBaseUri: _appBaseUri,
    );
    // Malformed warm URLs are intentionally consumed and ignored so they do
    // not fall through to MaterialApp's unknown named-route handling.
    if (route == null) return Future<bool>.value(true);
    _applyNavigationRoute(route, platformLocation: routeInformation.uri);
    return Future<bool>.value(true);
  }

  Future<void> _handleNativeZingRoute(String route) async {
    final candidate = appNavigationRouteFromRouteName(route);
    if (candidate == null || !mounted) return;
    _applyNavigationRoute(candidate);
  }

  void _applyNavigationRoute(
    AppNavigationRoute route, {
    Uri? platformLocation,
  }) {
    if (!widget.tvMode && platformLocation != null) {
      final canonicalLocation = route.webLocation();
      _lastPlatformLocation = canonicalLocation.toString();
      final logicalPlatformLocation = Uri(
        path: platformLocation.path,
        query: platformLocation.hasQuery ? platformLocation.query : null,
      );
      if (logicalPlatformLocation != canonicalLocation) {
        unawaited(_updatePlatformRoute(canonicalLocation, replace: true));
      }
    }
    setState(() {
      _navigationRoute = route;
      _officialUrl = route.officialLink?.canonicalUri.toString();
      _navigationRouteRevision++;
    });
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  void _handleNavigationRouteChanged(
    AppNavigationRoute route, {
    required bool replace,
  }) {
    _navigationRoute = route;
    _officialUrl = route.officialLink?.canonicalUri.toString();
    if (widget.tvMode) return;
    final location = route.webLocation();
    if (_lastPlatformLocation == location.toString()) return;
    _lastPlatformLocation = location.toString();
    unawaited(_updatePlatformRoute(location, replace: replace));
  }

  Future<void> _updatePlatformRoute(
    Uri location, {
    required bool replace,
  }) async {
    await _routeHistoryReady;
    await _routeHistory.update(location, replace: replace);
  }

  Widget _buildAppHome() =>
      widget.home ??
      widget.homeBuilder?.call(_officialUrl) ??
      ZingChartScreen(
        tvMode: widget.tvMode,
        initialOfficialUrl: _officialUrl,
        navigationRoute: _navigationRoute,
        navigationRouteRevision: _navigationRouteRevision,
        onNavigationRouteChanged: _handleNavigationRouteChanged,
        onPlatformHistoryBack: widget.tvMode ? null : _routeHistory.back,
        onPlatformHistoryForward: widget.tvMode ? null : _routeHistory.forward,
        searchCatalogPage: (query, section, page, limit) =>
            ZingMP3API.searchCatalogPage(
              query,
              section,
              page: page,
              limit: limit,
            ),
        loadChartSuggestion: ZingMP3API.getDiscoveryRecommendations,
      );

  Route<dynamic> _buildRootRoute([RouteSettings? settings]) =>
      MaterialPageRoute<void>(
        settings:
            settings ?? const RouteSettings(name: Navigator.defaultRouteName),
        builder: (_) => _buildAppHome(),
      );

  Route<dynamic>? _generateRoute(RouteSettings settings) =>
      settings.name == Navigator.defaultRouteName
      ? _buildRootRoute(settings)
      : null;

  List<Route<dynamic>> _generateInitialRoutes(String platformRouteName) => [
    // main() already parsed platformRouteName into _navigationRoute. Returning
    // one stable root prevents Navigator 1.0 from treating a Web URL as a
    // second named-route stack while preserving Navigator.push for players and
    // dialogs below it.
    _buildRootRoute(),
  ];

  @override
  Widget build(BuildContext context) {
    return MusicPlayerScope(
      controller: widget.playerController,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        onGenerateInitialRoutes: _generateInitialRoutes,
        onGenerateRoute: _generateRoute,
        debugShowCheckedModeBanner: false,
        title: '#zingChart',
        themeMode: switch (_themePreference) {
          AppThemePreference.system => ThemeMode.system,
          AppThemePreference.light => ThemeMode.light,
          AppThemePreference.dark => ThemeMode.dark,
        },
        theme: buildZingLightTheme(tvMode: widget.tvMode),
        darkTheme: buildZingDarkTheme(tvMode: widget.tvMode),
      ),
    );
  }
}
