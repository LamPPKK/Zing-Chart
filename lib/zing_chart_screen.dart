import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'analytics_dashboard_screen.dart';
import 'data/music_repository.dart';
import 'models/app_navigation_route.dart';
import 'models/catalog_artist_detail.dart';
import 'models/catalog_search.dart';
import 'models/catalog_hub.dart';
import 'models/chart_snapshot.dart';
import 'models/discovery_home.dart';
import 'models/local_library.dart';
import 'models/listening_analytics.dart';
import 'models/live_radio.dart';
import 'models/new_release_chart.dart';
import 'models/official_zing_link.dart';
import 'models/playback_origin.dart';
import 'models/release_catalog.dart';
import 'models/search_suggestions.dart';
import 'models/song.dart';
import 'models/song_detail.dart';
import 'models/weekly_chart.dart';
import 'music_player_controller.dart';
import 'music_player_scope.dart';
import 'music_player_screen.dart';
import 'platform/tv_exit.dart';
import 'services/library_backup_file_service.dart';
import 'services/official_content_share_service.dart';
import 'theme/app_theme.dart';
import 'widgets/album_art.dart';
import 'widgets/artist_desktop_overview.dart';
import 'widgets/artist_profile_hero.dart';
import 'widgets/artist_profile_catalog.dart';
import 'widgets/app_settings_sheet.dart';
import 'widgets/collection_detail_catalog.dart';
import 'widgets/collection_detail_hero.dart';
import 'widgets/catalog_hub_browser.dart';
import 'widgets/catalog_video_handoff_dialog.dart';
import 'widgets/desktop_now_playing_panel.dart';
import 'widgets/desktop_catalog_sidebar.dart';
import 'widgets/desktop_playback_queue_panel.dart';
import 'widgets/discovery_home_hub.dart';
import 'widgets/for_you_hub.dart';
import 'widgets/library_hub.dart';
import 'widgets/live_radio_hub.dart';
import 'widgets/local_playlist_workspace.dart';
import 'widgets/mini_player.dart';
import 'widgets/official_content_share_dialog.dart';
import 'widgets/realtime_chart.dart';
import 'widgets/release_catalog_view.dart';
import 'widgets/search_discovery_summary.dart';
import 'widgets/search_suggestion_dropdown.dart';
import 'widgets/song_radio_controls.dart';
import 'widgets/song_detail_panel.dart';
import 'widgets/song_action_menu.dart';
import 'widgets/song_lyrics_panel.dart';
import 'widgets/weekly_chart_view.dart';
import 'wrapped_screen.dart';
import 'zing_mp3_api.dart';

typedef ChartLoader = Future<List<Song>> Function();
typedef ChartSnapshotLoader = Future<ChartSnapshot> Function();
typedef CatalogSearchLoader =
    Future<CatalogSearchResult> Function(String query);
typedef CatalogSearchPageLoader =
    Future<CatalogSearchPage> Function(
      String query,
      CatalogSearchSection section,
      int page,
      int limit,
    );
typedef SearchSuggestionLoader =
    Future<SearchSuggestionSnapshot> Function(String query);
typedef CatalogCollectionLoader =
    Future<CatalogCollectionDetail> Function(String id);
typedef CatalogArtistDetailLoader =
    Future<CatalogArtistDetail> Function(String alias);
typedef CatalogSongDetailLoader = Future<SongDetail> Function(String songId);
typedef NewReleaseChartLoader = Future<NewReleaseChart> Function();
typedef DiscoveryHomeLoader = Future<DiscoveryHome> Function();
typedef DiscoveryCategoriesLoader = Future<DiscoveryCategories> Function();
typedef DiscoveryRecommendationsLoader =
    Future<DiscoveryRecommendations> Function();
typedef ChartSuggestionLoader = Future<DiscoveryRecommendations> Function();
typedef DiscoveryCategoryHomeLoader =
    Future<DiscoveryHome> Function(String categoryId);
typedef CatalogHubHomeLoader = Future<CatalogHubHome> Function();
typedef CatalogHubDetailLoader = Future<CatalogHubDetail> Function(String id);
typedef Top100CatalogLoader = Future<Top100Catalog> Function();
typedef ReleaseCatalogLoader = Future<ReleaseCatalog> Function();
typedef WeeklyChartLoader =
    Future<WeeklyChart> Function(
      WeeklyChartRegion region, {
      int? week,
      int? year,
    });
typedef LiveRadioLoader = Future<LiveRadioSnapshot> Function();
typedef ExternalCatalogLauncher = Future<bool> Function(Uri uri);
typedef ClipboardTextReader = Future<String?> Function();
typedef NavigationRouteChanged =
    void Function(AppNavigationRoute route, {required bool replace});
typedef PlatformHistoryRequest = bool Function();
typedef _PlaylistPickerSelection = ({bool create, String? playlistId});

Future<bool> launchExternalCatalogPage(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

Future<String?> readClipboardText() async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

enum _CatalogBrowseView { discovery, hubs, top100, releases, weekly }

class _CatalogNavigationState {
  const _CatalogNavigationState({
    required this.selectedTab,
    required this.catalogBrowseView,
    required this.searchQuery,
    required this.searchSection,
    required this.searchResult,
    required this.aggregateSearchResult,
    required this.searchPages,
    required this.selectedArtist,
    required this.artistResult,
    required this.artistDetail,
    required this.artistSection,
    required this.selectedCollection,
    required this.collectionDetail,
    required this.collectionOriginArtist,
    required this.collectionOriginArtistDetail,
    required this.collectionOriginArtistResult,
    required this.collectionOriginArtistSection,
    required this.selectedHub,
    required this.hubDetail,
    required this.selectedDiscoveryCategoryId,
    required this.discoveryHome,
    required this.selectedPlaylistId,
    required this.librarySection,
    required this.releaseContentType,
    required this.releaseRegion,
    required this.weeklyRegion,
    required this.showAllChartSongs,
  });

  final int selectedTab;
  final _CatalogBrowseView catalogBrowseView;
  final String searchQuery;
  final CatalogSearchSection searchSection;
  final CatalogSearchResult? searchResult;
  final CatalogSearchResult? aggregateSearchResult;
  final Map<CatalogSearchSection, CatalogSearchPage> searchPages;
  final CatalogArtist? selectedArtist;
  final CatalogSearchResult? artistResult;
  final CatalogArtistDetail? artistDetail;
  final OfficialArtistSection artistSection;
  final CatalogCollection? selectedCollection;
  final CatalogCollectionDetail? collectionDetail;
  final CatalogArtist? collectionOriginArtist;
  final CatalogArtistDetail? collectionOriginArtistDetail;
  final CatalogSearchResult? collectionOriginArtistResult;
  final OfficialArtistSection collectionOriginArtistSection;
  final CatalogHub? selectedHub;
  final CatalogHubDetail? hubDetail;
  final String selectedDiscoveryCategoryId;
  final DiscoveryHome discoveryHome;
  final String? selectedPlaylistId;
  final LibrarySection librarySection;
  final ReleaseContentType releaseContentType;
  final ReleaseRegion releaseRegion;
  final WeeklyChartRegion weeklyRegion;
  final bool showAllChartSongs;

  String get identity => <Object?>[
    selectedTab,
    catalogBrowseView.name,
    searchQuery,
    searchSection.name,
    selectedArtist?.id,
    artistSection.name,
    selectedCollection?.id,
    selectedHub?.id,
    selectedDiscoveryCategoryId,
    selectedPlaylistId,
    librarySection.name,
    releaseContentType.name,
    releaseRegion.name,
    weeklyRegion.name,
    showAllChartSongs,
  ].join('|');
}

/// Optional catalog destination for deep links and deterministic app surfaces.
enum CatalogLanding { discovery, hubs, top100, releases, weekly }

List<Song> filterSongs(List<Song> songs, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return List<Song>.unmodifiable(songs);
  return songs
      .where(
        (song) =>
            song.displayTitle.toLowerCase().contains(normalized) ||
            song.artistsNames.toLowerCase().contains(normalized),
      )
      .toList(growable: false);
}

class ZingChartScreen extends StatefulWidget {
  const ZingChartScreen({
    super.key,
    this.loadSongs,
    this.loadChart = ZingMP3API.getZingChartSnapshot,
    this.searchCatalog = ZingMP3API.searchCatalog,
    this.searchCatalogPage,
    this.searchSuggestions = ZingMP3API.getSearchSuggestions,
    this.loadCollection = ZingMP3API.getCollection,
    this.loadArtistDetail = ZingMP3API.getArtistDetail,
    this.loadSongDetail = ZingMP3API.getSongDetail,
    this.lyricsLoader = ZingMP3API.getSongLyrics,
    this.loadNewReleases = ZingMP3API.getNewReleaseChart,
    this.loadDiscoveryHome = ZingMP3API.getDiscoveryHome,
    this.loadDiscoveryCategories = ZingMP3API.getDiscoveryCategories,
    this.loadDiscoveryRecommendations = ZingMP3API.getDiscoveryRecommendations,
    this.loadChartSuggestion,
    this.chartRefreshInterval = const Duration(minutes: 2),
    this.loadDiscoveryCategoryHome = ZingMP3API.getDiscoveryCategoryHome,
    this.loadHubHome = ZingMP3API.getHubHome,
    this.loadHubDetail = ZingMP3API.getHubDetail,
    this.loadTop100 = ZingMP3API.getTop100,
    this.loadReleaseCatalog = ZingMP3API.getReleaseCatalog,
    this.loadWeeklyChart = ZingMP3API.getWeeklyChart,
    this.loadLiveRadio = ZingMP3API.getLiveRadio,
    this.tvMode = false,
    this.backupFileService,
    this.initialTab = 0,
    this.initialCatalogLanding = CatalogLanding.discovery,
    this.initialArtist,
    this.initialSearchQuery = '',
    this.initialSearchSection = CatalogSearchSection.all,
    this.initialOfficialUrl,
    this.officialUrlRevision = 0,
    this.navigationRoute,
    this.navigationRouteRevision = 0,
    this.onNavigationRouteChanged,
    this.onPlatformHistoryBack,
    this.onPlatformHistoryForward,
    this.initialDesktopQueueVisible = false,
    this.initialDesktopPanelTab = DesktopPlaybackPanelTab.queue,
    this.clipboardTextReader = readClipboardText,
    this.launchExternalCatalog = launchExternalCatalogPage,
    this.officialContentShareService =
        const SharePlusOfficialContentShareService(),
  });

  final ChartLoader? loadSongs;
  final ChartSnapshotLoader loadChart;
  final CatalogSearchLoader searchCatalog;
  final CatalogSearchPageLoader? searchCatalogPage;
  final SearchSuggestionLoader searchSuggestions;
  final CatalogCollectionLoader loadCollection;
  final CatalogArtistDetailLoader loadArtistDetail;
  final CatalogSongDetailLoader loadSongDetail;
  final SongLyricsLoader lyricsLoader;
  final NewReleaseChartLoader loadNewReleases;
  final DiscoveryHomeLoader loadDiscoveryHome;
  final DiscoveryCategoriesLoader loadDiscoveryCategories;
  final DiscoveryRecommendationsLoader loadDiscoveryRecommendations;
  final ChartSuggestionLoader? loadChartSuggestion;
  final Duration? chartRefreshInterval;
  final DiscoveryCategoryHomeLoader loadDiscoveryCategoryHome;
  final CatalogHubHomeLoader loadHubHome;
  final CatalogHubDetailLoader loadHubDetail;
  final Top100CatalogLoader loadTop100;
  final ReleaseCatalogLoader loadReleaseCatalog;
  final WeeklyChartLoader loadWeeklyChart;
  final LiveRadioLoader loadLiveRadio;
  final bool tvMode;
  final LibraryBackupFileService? backupFileService;
  final int initialTab;
  final CatalogLanding initialCatalogLanding;
  final CatalogArtist? initialArtist;
  final String initialSearchQuery;
  final CatalogSearchSection initialSearchSection;
  final String? initialOfficialUrl;
  final int officialUrlRevision;
  final AppNavigationRoute? navigationRoute;
  final int navigationRouteRevision;
  final NavigationRouteChanged? onNavigationRouteChanged;
  final PlatformHistoryRequest? onPlatformHistoryBack;
  final PlatformHistoryRequest? onPlatformHistoryForward;
  final bool initialDesktopQueueVisible;
  final DesktopPlaybackPanelTab initialDesktopPanelTab;
  final ClipboardTextReader clipboardTextReader;
  final ExternalCatalogLauncher launchExternalCatalog;
  final OfficialContentShareService officialContentShareService;

  @override
  State<ZingChartScreen> createState() => _ZingChartScreenState();
}

class _ZingChartScreenState extends State<ZingChartScreen>
    with WidgetsBindingObserver {
  static const _chartPreviewSongCount = 10;
  static const _navigationHistoryLimit = 50;
  static const _chartTab = 0;
  static const _discoveryTab = 1;
  static const _newReleaseTab = 2;
  static const _forYouTab = 3;
  static const _libraryTab = 4;
  static const _liveRadioTab = 5;
  static const _navigationTabs = <int>[
    _chartTab,
    _discoveryTab,
    _liveRadioTab,
    _newReleaseTab,
    _forYouTab,
    _libraryTab,
  ];
  static const _mobileNavigationTabs = <int>[
    _libraryTab,
    _discoveryTab,
    _chartTab,
    _liveRadioTab,
    _forYouTab,
  ];

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _contentScrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final OverlayPortalController _searchOverlayController =
      OverlayPortalController();
  final LayerLink _searchLayerLink = LayerLink();
  final GlobalKey _searchFieldBoundsKey = GlobalKey();
  final Object _searchTapRegionGroup = Object();
  late final LibraryBackupFileService _backupFileService;
  MusicPlayerController? _playerControllerSubscription;
  List<Song> _songs = const [];
  ChartSnapshot _chartSnapshot = const ChartSnapshot(songs: []);
  bool _isLoading = true;
  bool _isChartRequestPending = false;
  bool _isChartRefreshing = false;
  String? _errorMessage;
  String? _chartRefreshErrorMessage;
  DateTime? _lastChartLoadedAt;
  Timer? _chartRefreshTimer;
  bool _appIsActive = true;
  bool _showAllChartSongs = false;
  CatalogSong? _chartSuggestion;
  bool _isChartSuggestionLoading = false;
  String? _chartSuggestionErrorMessage;
  int _chartSuggestionRequestId = 0;
  late int _selectedTab;
  bool _desktopPlayerVisible = false;
  late DesktopPlaybackPanelTab _desktopPlayerTab;
  bool _isCurrentMvLoading = false;
  int _currentMvRequestId = 0;
  String? _selectedPlaylistId;
  LibrarySection _librarySection = LibrarySection.overview;
  Timer? _searchDebounce;
  Timer? _searchSuggestionDebounce;
  CatalogSearchResult? _searchResult;
  CatalogSearchResult? _aggregateSearchResult;
  Map<CatalogSearchSection, CatalogSearchPage> _searchPages = const {};
  Set<CatalogSearchSection> _searchPaginationUnavailable = const {};
  String? _searchErrorMessage;
  bool _isSearching = false;
  bool _isSearchPageLoading = false;
  String? _searchPageErrorMessage;
  int _searchRequestId = 0;
  int _searchPageRequestId = 0;
  int _searchSuggestionRequestId = 0;
  int _searchSuggestionDetailRequestId = 0;
  SearchSuggestionSnapshot? _searchSuggestionSnapshot;
  bool _isLoadingSearchSuggestions = false;
  String? _loadingSearchSuggestionSongId;
  String? _searchSuggestionErrorMessage;
  int _highlightedSearchSuggestion = -1;
  CatalogSearchSection _searchSection = CatalogSearchSection.all;
  CatalogArtist? _selectedArtist;
  CatalogSearchResult? _artistResult;
  CatalogArtistDetail? _artistDetail;
  OfficialArtistSection _artistSection = OfficialArtistSection.profile;
  String? _artistErrorMessage;
  bool _isArtistLoading = false;
  CatalogCollection? _selectedCollection;
  CatalogCollectionDetail? _collectionDetail;
  String? _collectionErrorMessage;
  CatalogArtist? _collectionOriginArtist;
  CatalogArtistDetail? _collectionOriginArtistDetail;
  CatalogSearchResult? _collectionOriginArtistResult;
  OfficialArtistSection _collectionOriginArtistSection =
      OfficialArtistSection.profile;
  bool _isCollectionLoading = false;
  int _quickPlayCollectionRequestId = 0;
  String? _quickPlayingCollectionId;
  NewReleaseChart _newReleaseChart = const NewReleaseChart.empty();
  bool _isNewReleaseLoading = false;
  String? _newReleaseErrorMessage;
  DiscoveryHome _discoveryHome = const DiscoveryHome.empty();
  DiscoveryCategories _discoveryCategories = const DiscoveryCategories.empty();
  DiscoveryRecommendations _officialDiscoveryRecommendations =
      const DiscoveryRecommendations.empty();
  bool _isDiscoveryLoading = false;
  bool _isDiscoveryCategoriesLoading = false;
  bool _isDiscoveryRecommendationsLoading = false;
  String? _discoveryErrorMessage;
  String? _discoveryCategoriesErrorMessage;
  String _selectedDiscoveryCategoryId = '-1';
  int _discoveryRequestId = 0;
  _CatalogBrowseView _catalogBrowseView = _CatalogBrowseView.discovery;
  CatalogHubHome _hubHome = const CatalogHubHome.empty();
  bool _isHubHomeLoading = false;
  String? _hubHomeErrorMessage;
  CatalogHub? _selectedHub;
  CatalogHubDetail? _hubDetail;
  bool _isHubDetailLoading = false;
  String? _hubDetailErrorMessage;
  Top100Catalog _top100Catalog = const Top100Catalog.empty();
  bool _isTop100Loading = false;
  String? _top100ErrorMessage;
  ReleaseCatalog _releaseCatalog = const ReleaseCatalog.empty();
  bool _isReleaseCatalogLoading = false;
  String? _releaseCatalogErrorMessage;
  ReleaseContentType _releaseContentType = ReleaseContentType.songs;
  ReleaseRegion _releaseRegion = ReleaseRegion.all;
  DiscoveryReleaseRegion _discoveryReleaseRegion = DiscoveryReleaseRegion.all;
  WeeklyChart _weeklyChart = const WeeklyChart.empty();
  WeeklyChartRegion _weeklyRegion = WeeklyChartRegion.vietnam;
  bool _isWeeklyChartLoading = false;
  String? _weeklyChartErrorMessage;
  int _weeklyRequestId = 0;
  int _hubRequestId = 0;
  LiveRadioSnapshot _liveRadio = const LiveRadioSnapshot.empty();
  bool _isLiveRadioLoading = false;
  String? _liveRadioErrorMessage;
  int _discoveryRecommendationPage = 0;
  String _lastObservedSearchQuery = '';
  _CatalogNavigationState? _lastCommittedSearchState;
  final List<_CatalogNavigationState> _backHistory = [];
  final List<_CatalogNavigationState> _forwardHistory = [];
  bool _navigationBatchOpen = false;
  bool _restoringNavigation = false;
  bool _routeReportingReady = false;
  bool _routeReportScheduled = false;
  bool _suppressRouteReporting = false;
  bool _replaceNextRouteReport = true;
  bool _replaceNextSearchRouteReport = false;
  int _incomingNavigationRequestId = 0;
  AppNavigationRoute? _lastReportedNavigationRoute;

  ({
    List<Song> songs,
    bool canRefresh,
    bool official,
    Map<String, CatalogSong> catalogBySongId,
  })
  _discoveryRecommendations() {
    const displayCount = 9;
    final unique = <String, Song>{};
    final officialCatalogBySongId = <String, CatalogSong>{};
    for (final entry in _officialDiscoveryRecommendations.playableEntries) {
      officialCatalogBySongId.putIfAbsent(entry.song.id, () => entry);
    }
    final officialSongs = officialCatalogBySongId.values
        .map((entry) => entry.song)
        .toList(growable: false);
    final source = officialSongs.isNotEmpty ? officialSongs : _songs;
    for (final song in source) {
      if (song.id.trim().isEmpty || song.code.trim().isEmpty) continue;
      unique.putIfAbsent(song.id, () => song);
    }
    final candidates = unique.values.toList(growable: false);
    if (candidates.length <= displayCount) {
      return (
        songs: candidates,
        canRefresh: false,
        official: officialSongs.isNotEmpty,
        catalogBySongId: Map<String, CatalogSong>.unmodifiable(
          officialCatalogBySongId,
        ),
      );
    }
    final offset = (_discoveryRecommendationPage * 3) % candidates.length;
    return (
      songs: List<Song>.generate(
        displayCount,
        (index) => candidates[(offset + index) % candidates.length],
        growable: false,
      ),
      canRefresh: true,
      official: officialSongs.isNotEmpty,
      catalogBySongId: Map<String, CatalogSong>.unmodifiable(
        officialCatalogBySongId,
      ),
    );
  }

  CatalogSong? _discoveryRecommendationFor(Song song) {
    for (final entry in _officialDiscoveryRecommendations.entries) {
      if (entry.song.id == song.id) return entry;
    }
    return null;
  }

  List<ReleaseSong> _discoveryReleaseSongs() {
    final unique = <String, ReleaseSong>{};
    for (final release in _releaseCatalog.songs) {
      final matches = switch (_discoveryReleaseRegion) {
        DiscoveryReleaseRegion.all => true,
        DiscoveryReleaseRegion.vietnam =>
          release.region == ReleaseRegion.vietnam,
        DiscoveryReleaseRegion.international =>
          release.region != ReleaseRegion.vietnam,
      };
      if (!matches || release.song.id.trim().isEmpty) continue;
      unique.putIfAbsent(release.song.id, () => release);
      if (unique.length == 12) break;
    }
    return unique.values.toList(growable: false);
  }

  List<Song> _visibleSongs(MusicPlayerController controller) {
    if (_selectedTab == _liveRadioTab) return const [];
    if (_selectedTab == _discoveryTab) {
      if (_selectedCollection != null) {
        return _collectionDetail?.songs
                .map((item) => item.song)
                .toList(growable: false) ??
            const [];
      }
      final artist = _selectedArtist;
      if (artist != null) {
        final detail = _artistDetail;
        if (detail != null) {
          final catalogSongs = switch (_artistSection) {
            OfficialArtistSection.profile =>
              detail.featuredSongs.isNotEmpty
                  ? detail.featuredSongs
                  : detail.songs.take(6).toList(growable: false),
            OfficialArtistSection.songs => detail.songs,
            OfficialArtistSection.singles ||
            OfficialArtistSection.videos => const <CatalogSong>[],
          };
          return catalogSongs.map((item) => item.song).toList(growable: false);
        }
        final result = _artistResult ?? _searchResult;
        if (result == null) return const [];
        final matching = result.songs
            .where((item) => _songMatchesArtist(item.song, artist))
            .map((item) => item.song)
            .toList(growable: false);
        return matching.isEmpty
            ? result.songs.map((item) => item.song).toList(growable: false)
            : matching;
      }
      if (_catalogBrowseView == _CatalogBrowseView.releases) {
        if (_releaseContentType == ReleaseContentType.albums) return const [];
        return _releaseCatalog
            .songsFor(_releaseRegion)
            .map((item) => item.song)
            .toList(growable: false);
      }
      if (_catalogBrowseView == _CatalogBrowseView.weekly) {
        return _weeklyChart.songs;
      }
      if (_searchSection == CatalogSearchSection.artists ||
          _searchSection == CatalogSearchSection.collections ||
          _searchSection == CatalogSearchSection.videos) {
        return const [];
      }
      final query = _searchController.text.trim();
      if (query.isEmpty) return _songs.take(8).toList(growable: false);
      final result = _searchResult;
      if (result != null) {
        final songs = result.songs.map((item) => item.song);
        return (_searchSection == CatalogSearchSection.all
                ? songs.take(6)
                : songs)
            .toList(growable: false);
      }
      return filterSongs(_songs, query);
    }
    if (_selectedTab == _newReleaseTab) {
      return _newReleaseChart.songs;
    }
    if (_selectedTab == _chartTab && _searchController.text.isEmpty) {
      return _showAllChartSongs
          ? List<Song>.unmodifiable(_songs)
          : _songs.take(_chartPreviewSongCount).toList(growable: false);
    }
    final source = _selectedTab == _libraryTab
        ? _selectedPlaylistId == null
              ? controller.likedSongs
              : _selectedPlaylist(controller)?.songs ?? const <Song>[]
        : _songs;
    return filterSongs(source, _searchController.text);
  }

  ({CatalogCollection collection, String sectionLabel})? _artistLatestRelease(
    CatalogArtistDetail detail,
  ) {
    for (final section in detail.collectionSections) {
      final sectionName = section.title.trim();
      final normalized = sectionName.toLowerCase();
      final isReleaseSection =
          normalized.contains('single') ||
          RegExp(r'(^|[^a-z])ep([^a-z]|$)').hasMatch(normalized) ||
          normalized.contains('album') ||
          normalized.contains('phát hành') ||
          normalized.contains('mới');
      if (!isReleaseSection) continue;
      for (final collection in section.collections) {
        if (collection.kind == CatalogCollectionKind.album) {
          return (
            collection: collection,
            sectionLabel: sectionName.isEmpty ? 'Phát hành mới' : sectionName,
          );
        }
      }
    }
    return null;
  }

  List<Song> _desktopArtistFeaturedSongs(CatalogArtistDetail detail) {
    final songsById = <String, Song>{};
    final source = detail.featuredSongs.isNotEmpty
        ? detail.featuredSongs
        : detail.songs;
    for (final item in source) {
      songsById.putIfAbsent(item.song.id, () => item.song);
      if (songsById.length == 3) break;
    }
    return songsById.values.toList(growable: false);
  }

  CatalogSong? _catalogSongFor(Song song) {
    if (_selectedArtist != null) {
      final detail = _artistDetail;
      for (final item in <CatalogSong>[
        ...?detail?.featuredSongs,
        ...?detail?.songs,
      ]) {
        if (item.song.id == song.id) return item;
      }
    }
    final result = _selectedArtist == null
        ? _searchResult
        : _artistResult ?? _searchResult;
    if (_selectedCollection != null) {
      for (final item in _collectionDetail?.songs ?? const <CatalogSong>[]) {
        if (item.song.id == song.id) return item;
      }
      return null;
    }
    if (_selectedTab == _discoveryTab &&
        _catalogBrowseView == _CatalogBrowseView.releases) {
      return _releaseSongFor(song)?.catalogSong;
    }
    if (_selectedTab == _discoveryTab &&
        _catalogBrowseView == _CatalogBrowseView.weekly) {
      return _weeklyEntryFor(song)?.catalogSong;
    }
    if (_selectedTab == _newReleaseTab) {
      return _newReleaseEntryFor(song)?.catalogSong;
    }
    if (_selectedTab != _discoveryTab || result == null) return null;
    for (final item in result.songs) {
      if (item.song.id == song.id) return item;
    }
    return null;
  }

  NewReleaseEntry? _newReleaseEntryFor(Song song) {
    for (final entry in _newReleaseChart.entries) {
      if (entry.song.id == song.id) return entry;
    }
    return null;
  }

  ReleaseSong? _releaseSongFor(Song song) {
    for (final entry in _releaseCatalog.songs) {
      if (entry.song.id == song.id) return entry;
    }
    return null;
  }

  WeeklyChartEntry? _weeklyEntryFor(Song song) {
    for (final entry in _weeklyChart.entries) {
      if (entry.song.id == song.id) return entry;
    }
    return null;
  }

  bool _songMatchesArtist(Song song, CatalogArtist artist) => song.artistsNames
      .toLowerCase()
      .split(',')
      .map((name) => name.trim())
      .any((name) => name == artist.name.toLowerCase());

  LocalPlaylist? _selectedPlaylist(MusicPlayerController controller) {
    final id = _selectedPlaylistId;
    if (id == null) return null;
    for (final playlist in controller.playlists) {
      if (playlist.id == id) return playlist;
    }
    return null;
  }

  _CatalogNavigationState _captureNavigationState({String? searchQuery}) =>
      _CatalogNavigationState(
        selectedTab: _selectedTab,
        catalogBrowseView: _catalogBrowseView,
        searchQuery: searchQuery ?? _searchController.text,
        searchSection: _searchSection,
        searchResult: _searchResult,
        aggregateSearchResult: _aggregateSearchResult,
        searchPages: Map<CatalogSearchSection, CatalogSearchPage>.unmodifiable(
          _searchPages,
        ),
        selectedArtist: _selectedArtist,
        artistResult: _artistResult,
        artistDetail: _artistDetail,
        artistSection: _artistSection,
        selectedCollection: _selectedCollection,
        collectionDetail: _collectionDetail,
        collectionOriginArtist: _collectionOriginArtist,
        collectionOriginArtistDetail: _collectionOriginArtistDetail,
        collectionOriginArtistResult: _collectionOriginArtistResult,
        collectionOriginArtistSection: _collectionOriginArtistSection,
        selectedHub: _selectedHub,
        hubDetail: _hubDetail,
        selectedDiscoveryCategoryId: _selectedDiscoveryCategoryId,
        discoveryHome: _discoveryHome,
        selectedPlaylistId: _selectedPlaylistId,
        librarySection: _librarySection,
        releaseContentType: _releaseContentType,
        releaseRegion: _releaseRegion,
        weeklyRegion: _weeklyRegion,
        showAllChartSongs: _showAllChartSongs,
      );

  AppNavigationRoute? _navigationRouteForState(
    _CatalogNavigationState state, {
    bool requireCommittedSearch = false,
  }) {
    if (state.selectedTab == _chartTab) {
      return _officialNavigationRoute('https://zingmp3.vn/zing-chart');
    }
    if (state.selectedTab == _newReleaseTab) {
      return _officialNavigationRoute('https://zingmp3.vn/moi-phat-hanh');
    }
    if (state.selectedTab == _liveRadioTab) {
      return _officialNavigationRoute('https://zingmp3.vn/radio');
    }
    if (state.selectedTab == _forYouTab) {
      return const AppNavigationRoute.forYou();
    }
    if (state.selectedTab == _libraryTab) {
      return AppNavigationRoute.library(
        section: state.librarySection,
        playlistId: state.selectedPlaylistId,
      );
    }
    if (state.selectedTab != _discoveryTab) return null;

    final collection = state.selectedCollection;
    if (collection != null) {
      final official = OfficialZingLink.tryParse(collection.externalUrl);
      if (official?.kind == OfficialZingLinkKind.collection) {
        return AppNavigationRoute.official(official!);
      }
      if (collection.kind == CatalogCollectionKind.album) {
        return _officialNavigationRoute(
          'https://zingmp3.vn/link/album/${collection.id}',
        );
      }
    }

    final artist = state.selectedArtist;
    if (artist != null) {
      final suffix = switch (state.artistSection) {
        OfficialArtistSection.profile => '',
        OfficialArtistSection.songs => '/bai-hat',
        OfficialArtistSection.singles => '/single',
        OfficialArtistSection.videos => '/video',
      };
      return _officialNavigationRoute(
        suffix.isEmpty
            ? 'https://zingmp3.vn/nghe-si/${artist.aliasName}'
            : 'https://zingmp3.vn/${artist.aliasName}$suffix',
      );
    }

    final hub = state.selectedHub;
    if (hub != null) {
      final official = OfficialZingLink.tryParse(hub.externalUrl);
      if (official?.kind == OfficialZingLinkKind.hub) {
        return AppNavigationRoute.official(official!);
      }
    }

    final query = state.searchQuery.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (query.isNotEmpty) {
      if (requireCommittedSearch &&
          state.aggregateSearchResult == null &&
          state.searchResult == null) {
        return null;
      }
      final path = switch (state.searchSection) {
        CatalogSearchSection.all => '/tim-kiem/tat-ca',
        CatalogSearchSection.songs => '/tim-kiem/bai-hat',
        CatalogSearchSection.collections => '/tim-kiem/playlist',
        CatalogSearchSection.artists => '/tim-kiem/artist',
        CatalogSearchSection.videos => '/tim-kiem/video',
      };
      return _officialNavigationRoute(
        Uri.https('zingmp3.vn', path, {'q': query}).toString(),
      );
    }

    return switch (state.catalogBrowseView) {
      _CatalogBrowseView.discovery => const AppNavigationRoute.discovery(),
      _CatalogBrowseView.hubs => const AppNavigationRoute.hubs(),
      _CatalogBrowseView.top100 => _officialNavigationRoute(
        'https://zingmp3.vn/top100',
      ),
      _CatalogBrowseView.releases => _officialNavigationRoute(
        state.releaseContentType == ReleaseContentType.albums
            ? 'https://zingmp3.vn/new-release/album'
            : 'https://zingmp3.vn/new-release/song',
      ),
      _CatalogBrowseView.weekly => _officialNavigationRoute(
        switch (state.weeklyRegion) {
          WeeklyChartRegion.vietnam =>
            'https://zingmp3.vn/zing-chart-tuan/'
                'Bai-hat-Viet-Nam/IWZ9Z08I.html',
          WeeklyChartRegion.usuk =>
            'https://zingmp3.vn/zing-chart-tuan/'
                'Bai-hat-US-UK/IWZ9Z0BW.html',
          WeeklyChartRegion.korea =>
            'https://zingmp3.vn/zing-chart-tuan/'
                'Bai-hat-KPop/IWZ9Z0BO.html',
        },
      ),
    };
  }

  AppNavigationRoute? _officialNavigationRoute(String url) {
    final link = OfficialZingLink.tryParse(url);
    return link == null ? null : AppNavigationRoute.official(link);
  }

  AppNavigationRoute? _currentNavigationRoute({
    bool requireCommittedSearch = true,
  }) => _navigationRouteForState(
    _captureNavigationState(),
    requireCommittedSearch: requireCommittedSearch,
  );

  void _enableRouteReporting() {
    _routeReportingReady = true;
    // If a warm platform route already won the startup race, its browser entry
    // is authoritative and there is no initial route left to replace.
    _replaceNextRouteReport = _lastReportedNavigationRoute == null;
    if (!_replaceNextRouteReport) _replaceNextSearchRouteReport = false;
    _scheduleNavigationRouteReport();
  }

  void _scheduleNavigationRouteReport() {
    if (!_routeReportingReady ||
        _suppressRouteReporting ||
        widget.onNavigationRouteChanged == null ||
        _routeReportScheduled) {
      return;
    }
    _routeReportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeReportScheduled = false;
      if (!mounted || _suppressRouteReporting) return;
      final route = _currentNavigationRoute();
      if (route == null) return;
      final previous = _lastReportedNavigationRoute;
      final sameIdentity = previous?.identity == route.identity;
      final samePresentation =
          previous?.officialLink?.canonicalUri.toString() ==
              route.officialLink?.canonicalUri.toString() &&
          previous?.shellDestination == route.shellDestination &&
          previous?.librarySection == route.librarySection &&
          previous?.playlistId == route.playlistId;
      if (sameIdentity && samePresentation) {
        // A warm platform route can settle before the initial async catalog
        // loader enables reporting. Consume its initial-replace intent here so
        // the user's next real navigation is pushed instead of overwritten.
        _replaceNextRouteReport = false;
        _replaceNextSearchRouteReport = false;
        return;
      }
      final isSearchRoute =
          route.officialLink?.kind == OfficialZingLinkKind.search;
      final replaceSearchRoute =
          isSearchRoute &&
          previous?.officialLink?.kind == OfficialZingLinkKind.search &&
          _replaceNextSearchRouteReport;
      final replace =
          _replaceNextRouteReport || sameIdentity || replaceSearchRoute;
      _replaceNextRouteReport = false;
      _replaceNextSearchRouteReport = false;
      _lastReportedNavigationRoute = route;
      widget.onNavigationRouteChanged!(route, replace: replace);
    });
  }

  Future<void> _applyIncomingNavigationRoute(AppNavigationRoute route) async {
    final requestId = ++_incomingNavigationRequestId;
    final current = _currentNavigationRoute(requireCommittedSearch: false);
    if (current?.identity == route.identity) {
      _lastReportedNavigationRoute = route;
      _suppressRouteReporting = false;
      _scheduleNavigationRouteReport();
      return;
    }

    _cancelPendingNavigationLoads();
    _suppressRouteReporting = true;
    try {
      final backIndex = _lastRouteIndex(_backHistory, route.identity);
      if (backIndex >= 0) {
        final steps = _backHistory.length - backIndex;
        for (var index = 0; index < steps; index++) {
          _navigateBackLocally();
        }
      } else {
        final forwardIndex = _lastRouteIndex(_forwardHistory, route.identity);
        if (forwardIndex >= 0) {
          final steps = _forwardHistory.length - forwardIndex;
          for (var index = 0; index < steps; index++) {
            _navigateForwardLocally();
          }
        } else {
          await _openNavigationRoute(route);
        }
      }
      if (!mounted || requestId != _incomingNavigationRequestId) return;
      _lastReportedNavigationRoute = route;
    } finally {
      if (requestId == _incomingNavigationRequestId) {
        _suppressRouteReporting = false;
        _scheduleNavigationRouteReport();
      }
    }
  }

  int _lastRouteIndex(List<_CatalogNavigationState> history, String identity) {
    for (var index = history.length - 1; index >= 0; index--) {
      if (_navigationRouteForState(history[index])?.identity == identity) {
        return index;
      }
    }
    return -1;
  }

  Future<void> _openNavigationRoute(
    AppNavigationRoute route, {
    bool recordCurrentOrigin = true,
  }) async {
    final wasRestoring = _restoringNavigation;
    if (!recordCurrentOrigin) _restoringNavigation = true;
    try {
      final official = route.officialLink;
      if (official != null) {
        await _openOfficialZingLink(
          official,
          recordCurrentOrigin: recordCurrentOrigin,
        );
        return;
      }
      switch (route.shellDestination!) {
        case AppShellDestination.discovery:
          _selectTab(_discoveryTab);
        case AppShellDestination.hubs:
          if (_selectedTab != _discoveryTab) _selectTab(_discoveryTab);
          _openHubHome();
        case AppShellDestination.library:
          final needsSeparateOrigin =
              _selectedTab == _libraryTab &&
              (_librarySection != route.librarySection ||
                  _selectedPlaylistId != route.playlistId);
          if (needsSeparateOrigin) _recordNavigationOrigin();
          _selectTab(_libraryTab);
          setState(() {
            _librarySection = route.librarySection;
            _selectedPlaylistId = route.playlistId;
          });
          _scrollContentToStart();
        case AppShellDestination.forYou:
          _selectTab(_forYouTab);
      }
    } finally {
      _restoringNavigation = wasRestoring;
    }
  }

  void _recordNavigationOrigin({_CatalogNavigationState? state}) {
    if (_restoringNavigation || _navigationBatchOpen) return;
    final current = state ?? _captureNavigationState();
    if (_backHistory.isEmpty ||
        _backHistory.last.identity != current.identity) {
      _backHistory.add(current);
      if (_backHistory.length > _navigationHistoryLimit) {
        _backHistory.removeAt(0);
      }
    }
    _forwardHistory.clear();
    _navigationBatchOpen = true;
    scheduleMicrotask(() => _navigationBatchOpen = false);
  }

  bool get _canNavigateBack => _backHistory.isNotEmpty;
  bool get _canNavigateForward => _forwardHistory.isNotEmpty;

  void _navigateBack() {
    if (_shouldUseLocalHistoryFirst(_backHistory)) {
      _navigateBackLocally();
      return;
    }
    if (!_suppressRouteReporting &&
        _requestPlatformHistory(widget.onPlatformHistoryBack)) {
      return;
    }
    _navigateBackLocally();
  }

  void _navigateBackLocally() {
    if (_backHistory.isEmpty) return;
    final current = _captureNavigationState();
    _CatalogNavigationState target;
    do {
      target = _backHistory.removeLast();
    } while (_backHistory.isNotEmpty && target.identity == current.identity);
    if (target.identity == current.identity) return;
    _forwardHistory.add(current);
    if (_forwardHistory.length > _navigationHistoryLimit) {
      _forwardHistory.removeAt(0);
    }
    _restoreNavigationState(target);
  }

  void _navigateForward() {
    if (_shouldUseLocalHistoryFirst(_forwardHistory)) {
      _navigateForwardLocally();
      return;
    }
    if (!_suppressRouteReporting &&
        _requestPlatformHistory(widget.onPlatformHistoryForward)) {
      return;
    }
    _navigateForwardLocally();
  }

  void _navigateForwardLocally() {
    if (_forwardHistory.isEmpty) return;
    final current = _captureNavigationState();
    _CatalogNavigationState target;
    do {
      target = _forwardHistory.removeLast();
    } while (_forwardHistory.isNotEmpty && target.identity == current.identity);
    if (target.identity == current.identity) return;
    if (_backHistory.isEmpty ||
        _backHistory.last.identity != current.identity) {
      _backHistory.add(current);
      if (_backHistory.length > _navigationHistoryLimit) {
        _backHistory.removeAt(0);
      }
    }
    _restoreNavigationState(target);
  }

  bool _shouldUseLocalHistoryFirst(List<_CatalogNavigationState> history) {
    if (history.isEmpty) return false;
    final currentState = _captureNavigationState();
    _CatalogNavigationState? target;
    for (var index = history.length - 1; index >= 0; index--) {
      if (history[index].identity != currentState.identity) {
        target = history[index];
        break;
      }
    }
    if (target == null) return false;
    final currentRoute = _navigationRouteForState(
      currentState,
      requireCommittedSearch: false,
    );
    final targetRoute = _navigationRouteForState(
      target,
      requireCommittedSearch: false,
    );
    if (currentRoute == null || targetRoute == null) return true;
    return currentRoute.identity == targetRoute.identity;
  }

  void _cancelPendingNavigationLoads() {
    _searchDebounce?.cancel();
    _searchSuggestionDebounce?.cancel();
    _searchRequestId++;
    _searchPageRequestId++;
    _searchSuggestionRequestId++;
    _searchSuggestionDetailRequestId++;
    _hubRequestId++;
    _weeklyRequestId++;
    _discoveryRequestId++;
  }

  bool _requestPlatformHistory(PlatformHistoryRequest? request) {
    if (request == null) return false;
    try {
      return request();
    } catch (_) {
      return false;
    }
  }

  void _restoreNavigationState(_CatalogNavigationState target) {
    _restoringNavigation = true;
    _navigationBatchOpen = false;
    _searchDebounce?.cancel();
    _searchSuggestionDebounce?.cancel();
    _searchRequestId++;
    _searchPageRequestId++;
    _searchSuggestionRequestId++;
    _searchSuggestionDetailRequestId++;
    _hubRequestId++;
    _weeklyRequestId++;
    _discoveryRequestId++;
    _hideSearchSuggestionOverlay();
    _searchController.value = TextEditingValue(
      text: target.searchQuery,
      selection: TextSelection.collapsed(offset: target.searchQuery.length),
    );
    _lastObservedSearchQuery = target.searchQuery.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    _lastCommittedSearchState =
        target.searchQuery.trim().isNotEmpty && target.searchResult != null
        ? target
        : null;
    setState(() {
      _selectedTab = target.selectedTab;
      _catalogBrowseView = target.catalogBrowseView;
      _searchSection = target.searchSection;
      _searchResult = target.searchResult;
      _aggregateSearchResult = target.aggregateSearchResult;
      _searchPages = Map<CatalogSearchSection, CatalogSearchPage>.unmodifiable(
        target.searchPages,
      );
      _searchPaginationUnavailable = const {};
      _searchErrorMessage = null;
      _isSearching = false;
      _isSearchPageLoading = false;
      _searchPageErrorMessage = null;
      _searchSuggestionSnapshot = null;
      _searchSuggestionErrorMessage = null;
      _isLoadingSearchSuggestions = false;
      _loadingSearchSuggestionSongId = null;
      _highlightedSearchSuggestion = -1;
      _selectedArtist = target.selectedArtist;
      _artistResult = target.artistResult;
      _artistDetail = target.artistDetail;
      _artistSection = target.artistSection;
      _artistErrorMessage = null;
      _isArtistLoading = false;
      _selectedCollection = target.selectedCollection;
      _collectionDetail = target.collectionDetail;
      _collectionErrorMessage = null;
      _collectionOriginArtist = target.collectionOriginArtist;
      _collectionOriginArtistDetail = target.collectionOriginArtistDetail;
      _collectionOriginArtistResult = target.collectionOriginArtistResult;
      _collectionOriginArtistSection = target.collectionOriginArtistSection;
      _isCollectionLoading = false;
      _selectedHub = target.selectedHub;
      _hubDetail = target.hubDetail;
      _hubDetailErrorMessage = null;
      _isHubDetailLoading = false;
      _selectedDiscoveryCategoryId = target.selectedDiscoveryCategoryId;
      _discoveryHome = target.discoveryHome;
      _selectedPlaylistId = target.selectedPlaylistId;
      _librarySection = target.librarySection;
      _releaseContentType = target.releaseContentType;
      _releaseRegion = target.releaseRegion;
      _weeklyRegion = target.weeklyRegion;
      _isWeeklyChartLoading = false;
      _weeklyChartErrorMessage = null;
      _showAllChartSongs = target.showAllChartSongs;
    });
    _restoringNavigation = false;
    _scrollContentToStart();
    _ensureNavigationTargetLoaded();
  }

  void _ensureNavigationTargetLoaded() {
    if (_selectedTab == _chartTab) {
      _ensureChartSuggestionLoaded();
      _refreshChartIfStale();
      return;
    }
    if (_selectedTab == _newReleaseTab) {
      if (_newReleaseChart.entries.isEmpty && !_isNewReleaseLoading) {
        unawaited(_loadNewReleases());
      }
      return;
    }
    if (_selectedTab == _liveRadioTab) {
      if (_liveRadio.isEmpty && !_isLiveRadioLoading) {
        unawaited(_loadLiveRadio());
      }
      return;
    }
    if (_selectedTab != _discoveryTab) return;
    if (_selectedCollection != null && _collectionDetail == null) {
      unawaited(_openCollection(_selectedCollection!, preserveDetail: true));
      return;
    }
    if (_selectedArtist != null && _artistDetail == null) {
      unawaited(_openArtist(_selectedArtist!, preserveResult: true));
      return;
    }
    final searchQuery = _searchController.text.trim();
    if (searchQuery.isNotEmpty) {
      if (_aggregateSearchResult == null && _searchResult == null) {
        unawaited(_runCatalogSearch(searchQuery));
      } else if (_searchSection != CatalogSearchSection.all &&
          !_searchPages.containsKey(_searchSection) &&
          !_searchPaginationUnavailable.contains(_searchSection)) {
        unawaited(_loadSearchPage(_searchSection));
      }
      return;
    }
    if (_selectedHub != null && _hubDetail == null) {
      unawaited(_openHub(_selectedHub!, preserveDetail: true));
      return;
    }
    switch (_catalogBrowseView) {
      case _CatalogBrowseView.discovery:
        _ensureDiscoveryLoaded();
      case _CatalogBrowseView.hubs:
        if (_hubHome.isEmpty && !_isHubHomeLoading) {
          unawaited(_loadHubHome());
        }
      case _CatalogBrowseView.top100:
        if (_top100Catalog.isEmpty && !_isTop100Loading) {
          unawaited(_loadTop100());
        }
      case _CatalogBrowseView.releases:
        if (_releaseCatalog.isEmpty && !_isReleaseCatalogLoading) {
          unawaited(_loadReleaseCatalog());
        }
      case _CatalogBrowseView.weekly:
        if ((_weeklyChart.isEmpty || _weeklyChart.region != _weeklyRegion) &&
            !_isWeeklyChartLoading) {
          unawaited(_loadWeeklyChart(region: _weeklyRegion));
        }
    }
  }

  void _navigateBackOr(VoidCallback fallback) {
    if (_canNavigateBack) {
      _navigateBack();
    } else {
      fallback();
    }
  }

  bool get _canUseToolbarBack =>
      _canNavigateBack ||
      _selectedPlaylistId != null ||
      _selectedCollection != null ||
      _selectedArtist != null ||
      _selectedHub != null ||
      _catalogBrowseView != _CatalogBrowseView.discovery ||
      Navigator.of(context).canPop();

  void _navigateToolbarBack() {
    if (_canNavigateBack) {
      _navigateBack();
      return;
    }
    if (_selectedPlaylistId != null) {
      _closeLocalPlaylist();
      return;
    }
    if (_selectedCollection != null) {
      _closeCollection();
      return;
    }
    if (_selectedArtist != null) {
      _closeArtist();
      return;
    }
    if (_selectedHub != null ||
        _catalogBrowseView != _CatalogBrowseView.discovery) {
      _closeCatalogBrowse();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appIsActive = switch (WidgetsBinding.instance.lifecycleState) {
      null || AppLifecycleState.resumed => true,
      _ => false,
    };
    _searchFocusNode.addListener(_handleSearchFocusChanged);
    _contentScrollController.addListener(_handleContentScroll);
    _desktopPlayerVisible = widget.initialDesktopQueueVisible;
    _desktopPlayerTab = widget.initialDesktopPanelTab;
    _selectedTab = widget.initialCatalogLanding == CatalogLanding.discovery
        ? widget.initialTab.clamp(_chartTab, _liveRadioTab)
        : _discoveryTab;
    _catalogBrowseView = switch (widget.initialCatalogLanding) {
      CatalogLanding.discovery => _CatalogBrowseView.discovery,
      CatalogLanding.hubs => _CatalogBrowseView.hubs,
      CatalogLanding.top100 => _CatalogBrowseView.top100,
      CatalogLanding.releases => _CatalogBrowseView.releases,
      CatalogLanding.weekly => _CatalogBrowseView.weekly,
    };
    _backupFileService =
        widget.backupFileService ?? createLibraryBackupFileService();
    _searchSection = widget.initialSearchSection;
    final initialSearchQuery = widget.initialSearchQuery.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    if (initialSearchQuery.isNotEmpty) {
      _lastObservedSearchQuery = initialSearchQuery;
      _selectedTab = _discoveryTab;
      _catalogBrowseView = _CatalogBrowseView.discovery;
      _searchController.value = TextEditingValue(
        text: initialSearchQuery,
        selection: TextSelection.collapsed(offset: initialSearchQuery.length),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _searchFocusNode.requestFocus();
        _onSearchChanged(initialSearchQuery);
      });
    }
    if (_appIsActive) unawaited(_loadSongs());
    _scheduleChartRefresh();
    final initialNavigationRoute =
        widget.navigationRoute ??
        AppNavigationRoute.fromOfficialUrl(widget.initialOfficialUrl ?? '');
    if (initialNavigationRoute != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(() async {
          await _openNavigationRoute(
            initialNavigationRoute,
            recordCurrentOrigin: false,
          );
          if (mounted) _enableRouteReporting();
        }());
      });
      return;
    }
    final initialArtist = widget.initialArtist;
    if (initialArtist != null) {
      _selectedTab = _discoveryTab;
      _catalogBrowseView = _CatalogBrowseView.discovery;
      _selectedArtist = initialArtist;
      unawaited(_openArtist(initialArtist, preserveResult: true));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _enableRouteReporting();
      });
      return;
    }
    if (_selectedTab == _newReleaseTab) unawaited(_loadNewReleases());
    if (_selectedTab == _liveRadioTab) unawaited(_loadLiveRadio());
    if (_selectedTab == _discoveryTab) {
      unawaited(switch (_catalogBrowseView) {
        _CatalogBrowseView.discovery => _loadInitialDiscovery(),
        _CatalogBrowseView.hubs => _loadHubHome(),
        _CatalogBrowseView.top100 => _loadTop100(),
        _CatalogBrowseView.releases => _loadReleaseCatalog(),
        _CatalogBrowseView.weekly => _loadWeeklyChart(),
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _enableRouteReporting();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachPlayerController(MusicPlayerScope.read(context));
  }

  MusicPlayerController get _playerController {
    final controller = MusicPlayerScope.read(context);
    _attachPlayerController(controller);
    return controller;
  }

  void _attachPlayerController(MusicPlayerController controller) {
    if (identical(_playerControllerSubscription, controller)) return;
    _playerControllerSubscription?.catalogChanges.removeListener(
      _handleCatalogChanged,
    );
    _playerControllerSubscription = controller;
    controller.catalogChanges.addListener(_handleCatalogChanged);
  }

  void _handleCatalogChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ZingChartScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chartRefreshInterval != widget.chartRefreshInterval) {
      _scheduleChartRefresh();
    }
    if (oldWidget.navigationRouteRevision != widget.navigationRouteRevision ||
        oldWidget.navigationRoute?.identity !=
            widget.navigationRoute?.identity ||
        oldWidget.officialUrlRevision != widget.officialUrlRevision ||
        oldWidget.initialOfficialUrl != widget.initialOfficialUrl) {
      final route =
          widget.navigationRoute ??
          AppNavigationRoute.fromOfficialUrl(widget.initialOfficialUrl ?? '');
      if (route != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_applyIncomingNavigationRoute(route));
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playerControllerSubscription?.catalogChanges.removeListener(
      _handleCatalogChanged,
    );
    _chartRefreshTimer?.cancel();
    _searchDebounce?.cancel();
    _searchSuggestionDebounce?.cancel();
    _searchFocusNode.removeListener(_handleSearchFocusChanged);
    _contentScrollController.removeListener(_handleContentScroll);
    _searchController.dispose();
    _contentScrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasActive = _appIsActive;
    _appIsActive = state == AppLifecycleState.resumed;
    if (!_appIsActive) {
      _chartRefreshTimer?.cancel();
      return;
    }
    if (!wasActive) unawaited(_resumeChartRefresh());
  }

  Future<void> _resumeChartRefresh() async {
    await _refreshChartIfStale();
    if (mounted && _appIsActive) {
      _scheduleChartRefresh(initialDelay: const Duration(milliseconds: 1));
    }
  }

  void _scheduleChartRefresh({Duration initialDelay = Duration.zero}) {
    _chartRefreshTimer?.cancel();
    final interval = widget.chartRefreshInterval;
    if (interval == null || interval <= Duration.zero) return;
    _chartRefreshTimer = Timer(interval + initialDelay, () {
      if (_appIsActive && _selectedTab == _chartTab) {
        unawaited(_loadSongs(silent: _songs.isNotEmpty));
      }
      if (mounted && _appIsActive) _scheduleChartRefresh();
    });
  }

  Future<void> _refreshChartIfStale() async {
    final interval = widget.chartRefreshInterval;
    if (interval == null ||
        interval <= Duration.zero ||
        !_appIsActive ||
        _selectedTab != _chartTab ||
        _isChartRequestPending) {
      return;
    }
    final lastLoadedAt = _lastChartLoadedAt;
    if (lastLoadedAt != null &&
        DateTime.now().difference(lastLoadedAt) < interval) {
      return;
    }
    await _loadSongs(silent: _songs.isNotEmpty);
  }

  Future<void> _loadSongs({bool silent = false}) async {
    if (_isChartRequestPending) return;
    _isChartRequestPending = true;
    final preserveChart = silent && _songs.isNotEmpty;
    setState(() {
      _chartRefreshErrorMessage = null;
      if (preserveChart) {
        _isChartRefreshing = true;
      } else {
        _isLoading = true;
        _errorMessage = null;
      }
    });
    try {
      final snapshot = widget.loadSongs == null
          ? await widget.loadChart()
          : ChartSnapshot(songs: await widget.loadSongs!());
      if (!mounted) return;
      setState(() {
        _songs = snapshot.songs;
        _chartSnapshot = snapshot;
        _errorMessage = null;
        _chartRefreshErrorMessage = null;
      });
      _lastChartLoadedAt = DateTime.now();
      _playerController.updateCatalog(snapshot.songs);
      if (_selectedTab == _chartTab && _searchController.text.isEmpty) {
        unawaited(
          _loadChartSuggestion(preserveSuggestion: _chartSuggestion != null),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (preserveChart) {
          _chartRefreshErrorMessage = error.toString();
        } else {
          _errorMessage = error.toString();
        }
      });
    } finally {
      _isChartRequestPending = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isChartRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadChartSuggestion({bool preserveSuggestion = false}) async {
    final loader = widget.loadChartSuggestion;
    if (loader == null || _isChartSuggestionLoading) return;
    final requestId = ++_chartSuggestionRequestId;
    setState(() {
      _isChartSuggestionLoading = true;
      _chartSuggestionErrorMessage = null;
      if (!preserveSuggestion) _chartSuggestion = null;
    });
    try {
      final recommendations = await loader();
      if (!mounted || requestId != _chartSuggestionRequestId) return;
      final chartSongIds = _songs.map((song) => song.id).toSet();
      CatalogSong? suggestion;
      if (recommendations.catalogPlaybackEnabled) {
        for (final entry in recommendations.playableEntries) {
          if (entry.song.id.trim().isEmpty ||
              entry.song.code.trim().isEmpty ||
              chartSongIds.contains(entry.song.id)) {
            continue;
          }
          suggestion = entry;
          break;
        }
      }
      setState(() => _chartSuggestion = suggestion);
    } catch (error) {
      if (!mounted || requestId != _chartSuggestionRequestId) return;
      setState(() {
        _chartSuggestionErrorMessage = error.toString();
        if (!preserveSuggestion) _chartSuggestion = null;
      });
    } finally {
      if (mounted && requestId == _chartSuggestionRequestId) {
        setState(() => _isChartSuggestionLoading = false);
      }
    }
  }

  void _ensureChartSuggestionLoaded() {
    if (widget.loadChartSuggestion == null ||
        _chartSuggestion != null ||
        _isChartSuggestionLoading ||
        _songs.isEmpty) {
      return;
    }
    unawaited(_loadChartSuggestion());
  }

  Future<void> _loadNewReleases() async {
    if (_isNewReleaseLoading) return;
    setState(() {
      _isNewReleaseLoading = true;
      _newReleaseErrorMessage = null;
    });
    try {
      final chart = await widget.loadNewReleases();
      if (!mounted) return;
      setState(() => _newReleaseChart = chart);
    } catch (error) {
      if (!mounted) return;
      setState(() => _newReleaseErrorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isNewReleaseLoading = false);
    }
  }

  Future<void> _loadLiveRadio() async {
    if (_isLiveRadioLoading) return;
    setState(() {
      _isLiveRadioLoading = true;
      _liveRadioErrorMessage = null;
    });
    try {
      final snapshot = await widget.loadLiveRadio();
      if (!mounted) return;
      setState(() => _liveRadio = snapshot);
    } catch (error) {
      if (!mounted) return;
      setState(() => _liveRadioErrorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLiveRadioLoading = false);
    }
  }

  Future<void> _loadInitialDiscovery() async {
    await Future.wait([
      _loadDiscoveryCategories(),
      _loadDiscoveryRecommendations(),
      _loadDiscoveryHome(),
      _loadReleaseCatalog(),
      _loadNewReleases(),
    ]);
  }

  Future<void> _loadDiscoveryRecommendations() async {
    if (_isDiscoveryRecommendationsLoading) return;
    setState(() => _isDiscoveryRecommendationsLoading = true);
    try {
      final recommendations = await widget.loadDiscoveryRecommendations();
      if (!mounted) return;
      setState(() {
        _officialDiscoveryRecommendations = recommendations;
        _discoveryRecommendationPage = 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _officialDiscoveryRecommendations =
            const DiscoveryRecommendations.empty();
        _discoveryRecommendationPage = 0;
      });
    } finally {
      if (mounted) {
        setState(() => _isDiscoveryRecommendationsLoading = false);
      }
    }
  }

  Future<void> _loadDiscoveryCategories({bool force = false}) async {
    if (_isDiscoveryCategoriesLoading ||
        (!force && !_discoveryCategories.isEmpty)) {
      return;
    }
    setState(() {
      _isDiscoveryCategoriesLoading = true;
      _discoveryCategoriesErrorMessage = null;
    });
    try {
      final categories = await widget.loadDiscoveryCategories();
      if (!mounted) return;
      setState(() => _discoveryCategories = categories);
    } catch (error) {
      if (!mounted) return;
      setState(() => _discoveryCategoriesErrorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isDiscoveryCategoriesLoading = false);
    }
  }

  Future<void> _loadDiscoveryHome({String? categoryId}) async {
    final targetCategoryId = categoryId?.trim() ?? _selectedDiscoveryCategoryId;
    final requestId = ++_discoveryRequestId;
    setState(() {
      _isDiscoveryLoading = true;
      _discoveryErrorMessage = null;
      _selectedDiscoveryCategoryId = targetCategoryId;
    });
    try {
      final home = targetCategoryId == '-1'
          ? await widget.loadDiscoveryHome()
          : await widget.loadDiscoveryCategoryHome(targetCategoryId);
      if (!mounted || requestId != _discoveryRequestId) return;
      setState(() {
        _discoveryHome = home;
        _selectedDiscoveryCategoryId = home.categoryId;
      });
    } catch (error) {
      if (!mounted || requestId != _discoveryRequestId) return;
      setState(() {
        _discoveryErrorMessage = error.toString();
        _selectedDiscoveryCategoryId = _discoveryHome.categoryId;
      });
    } finally {
      if (mounted && requestId == _discoveryRequestId) {
        setState(() => _isDiscoveryLoading = false);
      }
    }
  }

  void _selectDiscoveryCategory(String categoryId) {
    if (categoryId == _selectedDiscoveryCategoryId && !_discoveryHome.isEmpty) {
      return;
    }
    _recordNavigationOrigin();
    if (categoryId == '-1' &&
        _releaseCatalog.isEmpty &&
        !_isReleaseCatalogLoading) {
      unawaited(_loadReleaseCatalog());
    }
    if (categoryId == '-1' &&
        _newReleaseChart.entries.isEmpty &&
        !_isNewReleaseLoading) {
      unawaited(_loadNewReleases());
    }
    unawaited(_loadDiscoveryHome(categoryId: categoryId));
  }

  Future<void> _loadHubHome() async {
    if (_isHubHomeLoading) return;
    setState(() {
      _isHubHomeLoading = true;
      _hubHomeErrorMessage = null;
    });
    try {
      final home = await widget.loadHubHome();
      if (!mounted) return;
      setState(() => _hubHome = home);
    } catch (error) {
      if (!mounted) return;
      setState(() => _hubHomeErrorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isHubHomeLoading = false);
    }
  }

  Future<void> _loadTop100() async {
    if (_isTop100Loading) return;
    setState(() {
      _isTop100Loading = true;
      _top100ErrorMessage = null;
    });
    try {
      final catalog = await widget.loadTop100();
      if (!mounted) return;
      setState(() => _top100Catalog = catalog);
    } catch (error) {
      if (!mounted) return;
      setState(() => _top100ErrorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isTop100Loading = false);
    }
  }

  Future<void> _loadReleaseCatalog() async {
    if (_isReleaseCatalogLoading) return;
    setState(() {
      _isReleaseCatalogLoading = true;
      _releaseCatalogErrorMessage = null;
    });
    try {
      final catalog = await widget.loadReleaseCatalog();
      if (!mounted) return;
      setState(() => _releaseCatalog = catalog);
    } catch (error) {
      if (!mounted) return;
      setState(() => _releaseCatalogErrorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isReleaseCatalogLoading = false);
    }
  }

  Future<void> _loadWeeklyChart({
    WeeklyChartRegion? region,
    int? week,
    int? year,
    bool preserveChart = false,
  }) async {
    final targetRegion = region ?? _weeklyRegion;
    final requestId = ++_weeklyRequestId;
    setState(() {
      _weeklyRegion = targetRegion;
      if (!preserveChart && _weeklyChart.region != targetRegion) {
        _weeklyChart = WeeklyChart.empty(targetRegion);
      }
      _isWeeklyChartLoading = true;
      _weeklyChartErrorMessage = null;
    });
    try {
      final chart = await widget.loadWeeklyChart(
        targetRegion,
        week: week,
        year: year,
      );
      if (!mounted || requestId != _weeklyRequestId) return;
      setState(() {
        _weeklyChart = chart;
        _weeklyRegion = chart.region;
      });
    } catch (error) {
      if (!mounted || requestId != _weeklyRequestId) return;
      setState(() => _weeklyChartErrorMessage = error.toString());
    } finally {
      if (mounted && requestId == _weeklyRequestId) {
        setState(() => _isWeeklyChartLoading = false);
      }
    }
  }

  void _openHubHome() {
    if (_catalogBrowseView == _CatalogBrowseView.hubs && _selectedHub == null) {
      return;
    }
    _recordNavigationOrigin();
    _hubRequestId++;
    _weeklyRequestId++;
    setState(() {
      _catalogBrowseView = _CatalogBrowseView.hubs;
      _selectedHub = null;
      _hubDetail = null;
      _hubDetailErrorMessage = null;
      _isHubDetailLoading = false;
    });
    if (_hubHome.isEmpty) unawaited(_loadHubHome());
  }

  void _openTop100() {
    if (_catalogBrowseView == _CatalogBrowseView.top100 &&
        _selectedHub == null) {
      return;
    }
    _recordNavigationOrigin();
    _hubRequestId++;
    _weeklyRequestId++;
    setState(() {
      _catalogBrowseView = _CatalogBrowseView.top100;
      _selectedHub = null;
      _hubDetail = null;
      _hubDetailErrorMessage = null;
      _isHubDetailLoading = false;
    });
    if (_top100Catalog.isEmpty) unawaited(_loadTop100());
  }

  void _openReleaseCatalog({
    ReleaseRegion initialRegion = ReleaseRegion.all,
    ReleaseContentType initialContentType = ReleaseContentType.songs,
  }) {
    _recordNavigationOrigin();
    _hubRequestId++;
    _weeklyRequestId++;
    setState(() {
      _catalogBrowseView = _CatalogBrowseView.releases;
      _selectedHub = null;
      _hubDetail = null;
      _hubDetailErrorMessage = null;
      _isHubDetailLoading = false;
      _releaseContentType = initialContentType;
      _releaseRegion = initialRegion;
      _searchSection = CatalogSearchSection.all;
    });
    if (_releaseCatalog.isEmpty) unawaited(_loadReleaseCatalog());
  }

  void _openDiscoveryReleaseCatalog() {
    final initialRegion = switch (_discoveryReleaseRegion) {
      DiscoveryReleaseRegion.vietnam => ReleaseRegion.vietnam,
      DiscoveryReleaseRegion.all ||
      DiscoveryReleaseRegion.international => ReleaseRegion.all,
    };
    _openReleaseCatalog(initialRegion: initialRegion);
  }

  void _openWeeklyChart() {
    _openWeeklyChartRegion(WeeklyChartRegion.vietnam);
  }

  void _openWeeklyChartRegion(WeeklyChartRegion region) {
    final needsLoad = _weeklyChart.isEmpty || _weeklyChart.region != region;
    _recordNavigationOrigin();
    _hubRequestId++;
    _weeklyRequestId++;
    setState(() {
      _catalogBrowseView = _CatalogBrowseView.weekly;
      _selectedHub = null;
      _hubDetail = null;
      _hubDetailErrorMessage = null;
      _isHubDetailLoading = false;
      _searchSection = CatalogSearchSection.all;
      _weeklyRegion = region;
      _isWeeklyChartLoading = false;
      _weeklyChartErrorMessage = null;
    });
    if (needsLoad) {
      unawaited(_loadWeeklyChart(region: region));
    }
  }

  void _changeWeeklyRegion(WeeklyChartRegion region) {
    if (region == _weeklyRegion && !_weeklyChart.isEmpty) return;
    _recordNavigationOrigin();
    unawaited(_loadWeeklyChart(region: region));
  }

  void _changeReleaseContentType(ReleaseContentType type) {
    if (type == _releaseContentType) return;
    _recordNavigationOrigin();
    setState(() => _releaseContentType = type);
  }

  void _changeWeeklyPeriod(int week, int year) {
    unawaited(
      _loadWeeklyChart(
        region: _weeklyRegion,
        week: week,
        year: year,
        preserveChart: true,
      ),
    );
  }

  Future<void> _openHub(CatalogHub hub, {bool preserveDetail = false}) async {
    if (!preserveDetail) _recordNavigationOrigin();
    final requestId = ++_hubRequestId;
    setState(() {
      _catalogBrowseView = _CatalogBrowseView.hubs;
      _selectedHub = hub;
      if (!preserveDetail) _hubDetail = null;
      _hubDetailErrorMessage = null;
      _isHubDetailLoading = true;
    });
    try {
      final detail = await widget.loadHubDetail(hub.id);
      if (!mounted || requestId != _hubRequestId) return;
      setState(() {
        _hubDetail = detail;
        _selectedHub = detail.hub;
      });
    } catch (error) {
      if (!mounted || requestId != _hubRequestId) return;
      setState(() => _hubDetailErrorMessage = error.toString());
    } finally {
      if (mounted && requestId == _hubRequestId) {
        setState(() => _isHubDetailLoading = false);
      }
    }
  }

  void _closeHubDetail() {
    _hubRequestId++;
    setState(() {
      _selectedHub = null;
      _hubDetail = null;
      _hubDetailErrorMessage = null;
      _isHubDetailLoading = false;
      _catalogBrowseView = _CatalogBrowseView.hubs;
    });
  }

  void _closeCatalogBrowse() {
    if (_selectedHub != null) {
      _closeHubDetail();
      return;
    }
    _hubRequestId++;
    _weeklyRequestId++;
    setState(() {
      _catalogBrowseView = _CatalogBrowseView.discovery;
      _selectedHub = null;
      _hubDetail = null;
      _hubDetailErrorMessage = null;
      _isHubDetailLoading = false;
      _isWeeklyChartLoading = false;
    });
    _ensureDiscoveryLoaded();
  }

  void _handleSearchFocusChanged() {
    if (mounted) setState(() {});
    if (!_searchFocusNode.hasFocus) {
      _hideSearchSuggestionOverlay();
      return;
    }
    final query = _searchController.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (query.isEmpty) return;
    _showSearchSuggestionOverlay();
    if (_searchSuggestionSnapshot?.query.toLowerCase() != query.toLowerCase()) {
      _scheduleSearchSuggestions(query);
    }
  }

  void _showSearchSuggestionOverlay() {
    if (!_searchOverlayController.isShowing) {
      _searchOverlayController.show();
    }
  }

  void _hideSearchSuggestionOverlay({bool cancelSongDetail = true}) {
    if (_searchOverlayController.isShowing) {
      _searchOverlayController.hide();
    }
    final cancelLoadingSong =
        cancelSongDetail && _loadingSearchSuggestionSongId != null;
    if (cancelLoadingSong) _searchSuggestionDetailRequestId++;
    if ((_highlightedSearchSuggestion != -1 || cancelLoadingSong) && mounted) {
      setState(() {
        _highlightedSearchSuggestion = -1;
        if (cancelLoadingSong) _loadingSearchSuggestionSongId = null;
      });
    }
  }

  void _scheduleSearchSuggestions(String query) {
    _searchSuggestionDebounce?.cancel();
    final normalized = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      _searchSuggestionRequestId++;
      _hideSearchSuggestionOverlay();
      if (mounted) {
        setState(() {
          _searchSuggestionSnapshot = null;
          _searchSuggestionErrorMessage = null;
          _isLoadingSearchSuggestions = false;
          _highlightedSearchSuggestion = -1;
        });
      }
      return;
    }
    final requestId = ++_searchSuggestionRequestId;
    setState(() {
      _searchSuggestionSnapshot = null;
      _searchSuggestionErrorMessage = null;
      _isLoadingSearchSuggestions = true;
      _highlightedSearchSuggestion = -1;
    });
    _showSearchSuggestionOverlay();
    _searchSuggestionDebounce = Timer(
      const Duration(milliseconds: 140),
      () => unawaited(_loadSearchSuggestions(normalized, requestId)),
    );
  }

  Future<void> _loadSearchSuggestions(String query, int requestId) async {
    try {
      final snapshot = await widget.searchSuggestions(query);
      if (!mounted || requestId != _searchSuggestionRequestId) return;
      setState(() => _searchSuggestionSnapshot = snapshot);
    } catch (error) {
      if (!mounted || requestId != _searchSuggestionRequestId) return;
      setState(() => _searchSuggestionErrorMessage = error.toString());
    } finally {
      if (mounted && requestId == _searchSuggestionRequestId) {
        setState(() => _isLoadingSearchSuggestions = false);
      }
    }
  }

  int get _searchSuggestionOptionCount {
    if (_searchController.text.trim().isEmpty) return 0;
    final snapshot = _searchSuggestionSnapshot;
    return (snapshot?.keywords.length ?? 0) + 1 + (snapshot?.songs.length ?? 0);
  }

  KeyEventResult _handleSearchKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final count = _searchSuggestionOptionCount;
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        _searchOverlayController.isShowing) {
      _hideSearchSuggestionOverlay();
      return KeyEventResult.handled;
    }
    if (count == 0) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _showSearchSuggestionOverlay();
      setState(() {
        _highlightedSearchSuggestion =
            (_highlightedSearchSuggestion + 1) % count;
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _showSearchSuggestionOverlay();
      setState(() {
        _highlightedSearchSuggestion = _highlightedSearchSuggestion <= 0
            ? count - 1
            : _highlightedSearchSuggestion - 1;
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        _highlightedSearchSuggestion >= 0) {
      _activateHighlightedSearchSuggestion();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _activateHighlightedSearchSuggestion() {
    final snapshot = _searchSuggestionSnapshot;
    final keywordCount = snapshot?.keywords.length ?? 0;
    final index = _highlightedSearchSuggestion;
    if (index < 0) return;
    if (index < keywordCount) {
      _applySearchSuggestion(snapshot!.keywords[index]);
      return;
    }
    if (index == keywordCount) {
      unawaited(_submitSearch(_searchController.text));
      return;
    }
    final songIndex = index - keywordCount - 1;
    final songs = snapshot?.songs ?? const <SearchSuggestionSong>[];
    if (songIndex >= 0 && songIndex < songs.length) {
      unawaited(_openSearchSuggestionSong(songs[songIndex]));
    }
  }

  Future<void> _openSearchSuggestionSong(
    SearchSuggestionSong suggestion,
  ) async {
    final requestId = ++_searchSuggestionDetailRequestId;
    setState(() => _loadingSearchSuggestionSongId = suggestion.id);
    try {
      final detail = await widget.loadSongDetail(suggestion.id);
      if (!mounted || requestId != _searchSuggestionDetailRequestId) return;
      final catalogSong = detail.catalogSong;
      if (catalogSong.song.id != suggestion.id) {
        throw StateError('Thông tin trả về không khớp bài được chọn.');
      }
      setState(() => _loadingSearchSuggestionSongId = null);
      _hideSearchSuggestionOverlay(cancelSongDetail: false);
      _searchFocusNode.unfocus();
      final canPlay = detail.catalogPlaybackEnabled && catalogSong.playable;
      await showSongDetail(
        context,
        controller: _playerController,
        detailLoader: widget.loadSongDetail,
        initialDetail: detail,
        onPlay: canPlay
            ? () => _selectSong(
                catalogSong.song,
                <Song>[catalogSong.song],
                origin: const PlaybackOrigin(
                  kind: PlaybackOriginKind.search,
                  label: 'Gợi ý tìm kiếm · Zing MP3',
                ),
              )
            : null,
        onOpenArtist: _openArtistFromSongDetail,
        onOpenAlbum: _openAlbumFromSongDetail,
        externalLauncher: widget.launchExternalCatalog,
        shareService: widget.officialContentShareService,
        tvMode: widget.tvMode,
      );
    } catch (_) {
      if (!mounted || requestId != _searchSuggestionDetailRequestId) return;
      setState(() => _loadingSearchSuggestionSongId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chưa mở được thông tin ${suggestion.title}. Vui lòng thử lại.',
          ),
        ),
      );
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    final previousQuery = _lastObservedSearchQuery;
    if (previousQuery.isEmpty && query.isNotEmpty) {
      _recordNavigationOrigin(
        state: _captureNavigationState(searchQuery: previousQuery),
      );
    } else if (previousQuery.isNotEmpty &&
        query.isNotEmpty &&
        previousQuery != query) {
      // The first settled query creates one semantic history entry. Further
      // debounced typing replaces that entry instead of creating one per word
      // fragment; an explicit section/result navigation can still push.
      _replaceNextSearchRouteReport = true;
      final committed = _lastCommittedSearchState;
      if (committed != null &&
          committed.searchQuery.trim().toLowerCase() ==
              previousQuery.toLowerCase()) {
        _recordNavigationOrigin(state: committed);
      }
    }
    _lastObservedSearchQuery = query;
    final looksLikeUrl = OfficialZingLink.looksLikeAbsoluteUrl(query);
    _searchRequestId++;
    _searchPageRequestId++;
    _searchSuggestionDetailRequestId++;
    _hubRequestId++;
    _weeklyRequestId++;
    _enterDiscovery();
    setState(() {
      _catalogBrowseView = _CatalogBrowseView.discovery;
      _selectedHub = null;
      _hubDetail = null;
      _hubDetailErrorMessage = null;
      _isHubDetailLoading = false;
      _selectedArtist = null;
      _artistResult = null;
      _artistDetail = null;
      _artistSection = OfficialArtistSection.profile;
      _artistErrorMessage = null;
      _isArtistLoading = false;
      _selectedCollection = null;
      _collectionDetail = null;
      _collectionErrorMessage = null;
      _collectionOriginArtist = null;
      _collectionOriginArtistDetail = null;
      _collectionOriginArtistResult = null;
      _collectionOriginArtistSection = OfficialArtistSection.profile;
      _isCollectionLoading = false;
      _searchErrorMessage = null;
      _searchResult = null;
      _aggregateSearchResult = null;
      _searchPages = const {};
      _searchPaginationUnavailable = const {};
      _isSearchPageLoading = false;
      _searchPageErrorMessage = null;
      _isSearching = query.isNotEmpty && !looksLikeUrl;
      _loadingSearchSuggestionSongId = null;
    });
    if (looksLikeUrl) {
      _hideSearchSuggestionOverlay();
      _searchSuggestionDebounce?.cancel();
      _searchDebounce = Timer(
        const Duration(milliseconds: 180),
        () => unawaited(_submitSearch(query)),
      );
      return;
    }
    _scheduleSearchSuggestions(query);
    if (query.isEmpty) return;
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_runCatalogSearch(query)),
    );
  }

  Future<void> _submitSearch(
    String value, {
    _CatalogNavigationState? officialLinkOrigin,
  }) async {
    _searchDebounce?.cancel();
    _searchSuggestionDebounce?.cancel();
    _searchSuggestionRequestId++;
    _hideSearchSuggestionOverlay();
    _searchFocusNode.unfocus();
    if (mounted && _isLoadingSearchSuggestions) {
      setState(() => _isLoadingSearchSuggestions = false);
    }
    final query = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (query.isEmpty) return;
    if (OfficialZingLink.looksLikeAbsoluteUrl(query)) {
      final link = OfficialZingLink.tryParse(query);
      if (link == null) {
        if (!mounted) return;
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Liên kết Zing MP3 chưa được hỗ trợ hoặc không hợp lệ.',
            ),
          ),
        );
        return;
      }
      await _openOfficialZingLink(
        link,
        navigationOrigin: officialLinkOrigin,
        recordCurrentOrigin: officialLinkOrigin != null,
      );
      return;
    }
    if (mounted) {
      setState(() {
        _selectedArtist = null;
        _artistResult = null;
        _artistDetail = null;
        _artistSection = OfficialArtistSection.profile;
        _artistErrorMessage = null;
        _isArtistLoading = false;
        _selectedCollection = null;
        _collectionDetail = null;
        _collectionErrorMessage = null;
        _collectionOriginArtist = null;
        _collectionOriginArtistDetail = null;
        _collectionOriginArtistResult = null;
        _collectionOriginArtistSection = OfficialArtistSection.profile;
        _isCollectionLoading = false;
      });
    }
    _playerController.recordSearch(query);
    await _runCatalogSearch(query);
  }

  void _applySearchSuggestion(String query) {
    if (_searchController.text.trim().isEmpty && query.trim().isNotEmpty) {
      _recordNavigationOrigin();
    }
    _hideSearchSuggestionOverlay();
    _searchController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _lastObservedSearchQuery = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    unawaited(_submitSearch(query));
  }

  Future<void> _pasteOfficialZingLink() async {
    try {
      final value = (await widget.clipboardTextReader())?.trim() ?? '';
      if (!mounted) return;
      if (value.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard chưa có liên kết.')),
        );
        return;
      }
      final navigationOrigin = _captureNavigationState();
      _searchController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
      _lastObservedSearchQuery = value.replaceAll(RegExp(r'\s+'), ' ');
      await _submitSearch(value, officialLinkOrigin: navigationOrigin);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không đọc được clipboard trên thiết bị.'),
        ),
      );
    }
  }

  void _prepareOfficialRouteTransition() {
    _searchRequestId++;
    _searchPageRequestId++;
    _searchSuggestionRequestId++;
    _searchSuggestionDetailRequestId++;
    _hubRequestId++;
    _weeklyRequestId++;
    setState(() {
      _catalogBrowseView = _CatalogBrowseView.discovery;
      _selectedArtist = null;
      _artistResult = null;
      _artistDetail = null;
      _artistSection = OfficialArtistSection.profile;
      _artistErrorMessage = null;
      _isArtistLoading = false;
      _selectedCollection = null;
      _collectionDetail = null;
      _collectionErrorMessage = null;
      _collectionOriginArtist = null;
      _collectionOriginArtistDetail = null;
      _collectionOriginArtistResult = null;
      _collectionOriginArtistSection = OfficialArtistSection.profile;
      _isCollectionLoading = false;
      _selectedHub = null;
      _hubDetail = null;
      _hubDetailErrorMessage = null;
      _isHubDetailLoading = false;
      _isWeeklyChartLoading = false;
      _weeklyChartErrorMessage = null;
      _searchSection = CatalogSearchSection.all;
      _searchResult = null;
      _aggregateSearchResult = null;
      _searchPages = const {};
      _searchPaginationUnavailable = const {};
      _searchErrorMessage = null;
      _isSearching = false;
      _isSearchPageLoading = false;
      _searchPageErrorMessage = null;
      _searchSuggestionSnapshot = null;
      _searchSuggestionErrorMessage = null;
      _isLoadingSearchSuggestions = false;
      _loadingSearchSuggestionSongId = null;
      _highlightedSearchSuggestion = -1;
    });
  }

  Future<void> _openOfficialZingLink(
    OfficialZingLink link, {
    _CatalogNavigationState? navigationOrigin,
    bool recordCurrentOrigin = true,
  }) async {
    // Record the current route before replacing its query. This keeps every
    // warm official deep link reversible without recreating the player.
    if (recordCurrentOrigin) {
      _recordNavigationOrigin(state: navigationOrigin);
    }
    _scrollContentToStart();
    _searchDebounce?.cancel();
    _searchSuggestionDebounce?.cancel();
    _hideSearchSuggestionOverlay();
    _searchFocusNode.unfocus();
    _searchController.clear();
    _lastObservedSearchQuery = '';
    _lastCommittedSearchState = null;
    _prepareOfficialRouteTransition();
    switch (link.kind) {
      case OfficialZingLinkKind.search:
        _enterDiscovery();
        final query = link.searchQuery;
        _searchController.value = TextEditingValue(
          text: query,
          selection: TextSelection.collapsed(offset: query.length),
        );
        _lastObservedSearchQuery = query;
        setState(() {
          _searchSection = link.searchSection;
        });
        _playerController.recordSearch(query);
        await _runCatalogSearch(query);
      case OfficialZingLinkKind.chart:
        _selectTab(_chartTab);
      case OfficialZingLinkKind.newReleaseChart:
        _selectTab(_newReleaseTab);
      case OfficialZingLinkKind.liveRadio:
        _selectTab(_liveRadioTab);
      case OfficialZingLinkKind.top100:
        _enterDiscovery();
        _openTop100();
      case OfficialZingLinkKind.releases:
        _enterDiscovery();
        _openReleaseCatalog(initialContentType: link.releaseContentType!);
      case OfficialZingLinkKind.weeklyChart:
        _enterDiscovery();
        _openWeeklyChartRegion(link.weeklyRegion!);
      case OfficialZingLinkKind.hub:
        _enterDiscovery();
        await _openHub(
          CatalogHub(
            id: link.id,
            title: _officialLinkTitle(link.uri, fallback: 'Chủ đề Zing MP3'),
            description: 'Đang tải nội dung chính thức từ Zing MP3',
            image: '',
            externalUrl: link.uri.toString(),
          ),
        );
      case OfficialZingLinkKind.artist:
        _enterDiscovery();
        await _openArtist(
          CatalogArtist(
            id: link.alias,
            name: _labelFromSlug(link.alias),
            aliasName: link.alias,
            avatar: '',
            externalUrl: Uri.https(
              'zingmp3.vn',
              '/nghe-si/${link.alias}',
            ).toString(),
          ),
          section: link.artistSection,
        );
      case OfficialZingLinkKind.collection:
        _enterDiscovery();
        await _openCollection(
          CatalogCollection(
            id: link.id,
            title: _officialLinkTitle(
              link.uri,
              fallback: link.collectionKind == CatalogCollectionKind.album
                  ? 'Album trên Zing MP3'
                  : 'Playlist trên Zing MP3',
            ),
            artist: 'Zing MP3',
            thumbnail: '',
            kind: link.collectionKind!,
            externalUrl: link.uri.toString(),
          ),
        );
      case OfficialZingLinkKind.song:
        _enterDiscovery();
        final requestId = ++_searchRequestId;
        setState(() {
          _isSearching = true;
          _searchErrorMessage = null;
        });
        try {
          final detail = await widget.loadSongDetail(link.id);
          if (!mounted || requestId != _searchRequestId) return;
          final song = detail.catalogSong;
          await showSongDetail(
            context,
            controller: _playerController,
            detailLoader: widget.loadSongDetail,
            initialDetail: detail,
            onPlay: song.playable && detail.catalogPlaybackEnabled
                ? () => _selectSong(
                    song.song,
                    [song.song],
                    origin: const PlaybackOrigin(
                      kind: PlaybackOriginKind.other,
                      label: 'Liên kết Zing MP3',
                    ),
                  )
                : null,
            onOpenArtist: _openArtistFromSongDetail,
            onOpenAlbum: _openAlbumFromSongDetail,
            tvMode: widget.tvMode,
          );
        } catch (error) {
          if (!mounted || requestId != _searchRequestId) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chưa mở được liên kết bài hát: $error')),
          );
        } finally {
          if (mounted && requestId == _searchRequestId) {
            setState(() => _isSearching = false);
          }
        }
      case OfficialZingLinkKind.video:
        final video = CatalogVideo(
          id: link.id,
          title: _officialLinkTitle(link.uri, fallback: 'MV trên Zing MP3'),
          artist: 'Zing MP3',
          thumbnail: '',
          duration: Duration.zero,
          externalUrl: link.uri.toString(),
        );
        if (!mounted) return;
        await showCatalogVideoHandoffDialog(
          context,
          video,
          externalLauncher: widget.tvMode ? null : widget.launchExternalCatalog,
        );
    }
  }

  String _officialLinkTitle(Uri uri, {required String fallback}) {
    if (uri.pathSegments.length < 2) return fallback;
    final candidate = uri.pathSegments[uri.pathSegments.length - 2];
    final label = _labelFromSlug(candidate);
    return label.isEmpty ? fallback : label;
  }

  String _labelFromSlug(String value) => value
      .replaceAll(RegExp(r'[._-]+'), ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) => part.length == 1
            ? part.toUpperCase()
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');

  Future<void> _openArtist(
    CatalogArtist artist, {
    bool preserveResult = false,
    OfficialArtistSection? section,
  }) async {
    if (!preserveResult) _recordNavigationOrigin();
    _searchDebounce?.cancel();
    final requestId = ++_searchRequestId;
    final switchingArtist =
        _selectedArtist != null && _selectedArtist!.id != artist.id;
    final targetSection =
        section ??
        (preserveResult ? _artistSection : OfficialArtistSection.profile);
    setState(() {
      _selectedArtist = artist;
      _artistSection = targetSection;
      if (!preserveResult) {
        _artistDetail = null;
        _artistResult = switchingArtist ? null : _searchResult;
      }
      _artistErrorMessage = null;
      _isArtistLoading = true;
    });
    if (!preserveResult) _scrollContentToStart();
    try {
      final detail = await widget.loadArtistDetail(artist.aliasName);
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _artistDetail = detail;
        _selectedArtist = detail.artist;
      });
    } catch (error) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() => _artistErrorMessage = error.toString());
    } finally {
      if (mounted && requestId == _searchRequestId) {
        setState(() => _isArtistLoading = false);
      }
    }
  }

  void _showArtistSection(OfficialArtistSection section) {
    if (_selectedArtist == null || _artistSection == section) return;
    _recordNavigationOrigin();
    setState(() => _artistSection = section);
    _scrollContentToStart();
  }

  void _scrollContentToStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_contentScrollController.hasClients) return;
      _contentScrollController.jumpTo(0);
    });
  }

  void _handleContentScroll() {
    if (widget.tvMode ||
        !_contentScrollController.hasClients ||
        !_isOfficialSearchSurface ||
        _searchSection == CatalogSearchSection.all ||
        _isSearchPageLoading ||
        _searchPageErrorMessage != null ||
        _searchPaginationUnavailable.contains(_searchSection)) {
      return;
    }
    final page = _searchPages[_searchSection];
    if (page == null || !page.hasMore) return;
    if (_contentScrollController.position.extentAfter > 520) return;
    unawaited(_loadSearchPage(_searchSection, loadMore: true));
  }

  void _closeArtist() {
    _searchRequestId++;
    setState(() {
      _selectedArtist = null;
      _artistResult = null;
      _artistDetail = null;
      _artistSection = OfficialArtistSection.profile;
      _artistErrorMessage = null;
      _isArtistLoading = false;
    });
  }

  Future<void> _openCollection(
    CatalogCollection collection, {
    bool preserveDetail = false,
  }) async {
    if (!preserveDetail) _recordNavigationOrigin();
    _searchDebounce?.cancel();
    final requestId = ++_searchRequestId;
    setState(() {
      if (!preserveDetail) {
        _collectionOriginArtist = _selectedArtist;
        _collectionOriginArtistDetail = _artistDetail;
        _collectionOriginArtistResult = _artistResult;
        _collectionOriginArtistSection = _artistSection;
      }
      _selectedArtist = null;
      _artistResult = null;
      _artistDetail = null;
      _artistSection = OfficialArtistSection.profile;
      _artistErrorMessage = null;
      _isArtistLoading = false;
      _selectedCollection = collection;
      if (!preserveDetail) _collectionDetail = null;
      _collectionErrorMessage = null;
      _isCollectionLoading = true;
    });
    if (!preserveDetail) _scrollContentToStart();
    try {
      final detail = await widget.loadCollection(collection.id);
      if (!mounted || requestId != _searchRequestId) return;
      if (detail.collection.id != collection.id) {
        throw const FormatException(
          'Phản hồi tuyển tập không khớp nội dung được yêu cầu.',
        );
      }
      setState(() {
        _collectionDetail = detail;
        _selectedCollection = detail.collection;
        _collectionErrorMessage = null;
      });
    } catch (error) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _collectionErrorMessage =
            'Không thể tải dữ liệu chính thức của ${collection.title}. '
            'Hãy kiểm tra kết nối rồi thử lại.';
      });
    } finally {
      if (mounted && requestId == _searchRequestId) {
        setState(() => _isCollectionLoading = false);
      }
    }
  }

  Future<void> _quickPlayCollection(CatalogCollection collection) async {
    final requestId = ++_quickPlayCollectionRequestId;
    setState(() => _quickPlayingCollectionId = collection.id);
    try {
      final detail = await widget.loadCollection(collection.id);
      if (!mounted || requestId != _quickPlayCollectionRequestId) return;
      if (detail.collection.id != collection.id) {
        throw const FormatException(
          'Phản hồi tuyển tập không khớp nội dung được yêu cầu.',
        );
      }
      final queue = detail.catalogPlaybackEnabled
          ? detail.songs
                .where((item) => item.playable)
                .map((item) => item.song)
                .toList(growable: false)
          : const <Song>[];
      if (queue.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${detail.collection.title} chưa có bài được phép phát.',
            ),
          ),
        );
        return;
      }
      _selectSong(
        queue.first,
        queue,
        origin: PlaybackOrigin(
          kind: PlaybackOriginKind.collection,
          label: detail.collection.title,
        ),
      );
    } catch (error) {
      if (!mounted || requestId != _quickPlayCollectionRequestId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chưa phát được ${collection.title}: $error')),
      );
    } finally {
      if (mounted && requestId == _quickPlayCollectionRequestId) {
        setState(() => _quickPlayingCollectionId = null);
      }
    }
  }

  void _closeCollection() {
    _searchRequestId++;
    final originArtist = _collectionOriginArtist;
    final originDetail = _collectionOriginArtistDetail;
    final originResult = _collectionOriginArtistResult;
    final originSection = _collectionOriginArtistSection;
    setState(() {
      _selectedCollection = null;
      _collectionDetail = null;
      _collectionErrorMessage = null;
      _selectedArtist = originArtist;
      _artistDetail = originDetail;
      _artistResult = originResult;
      _artistSection = originSection;
      _artistErrorMessage = null;
      _collectionOriginArtist = null;
      _collectionOriginArtistDetail = null;
      _collectionOriginArtistResult = null;
      _collectionOriginArtistSection = OfficialArtistSection.profile;
      _isCollectionLoading = false;
    });
  }

  void _openHighlightedSong(CatalogSong item) {
    if (!item.playable ||
        (_isOfficialSearchSurface && !_activeSearchPlaybackEnabled) ||
        (_selectedCollection != null &&
            _collectionDetail?.catalogPlaybackEnabled != true)) {
      _showUnavailable(item.song);
      return;
    }
    final sourceSongs = _selectedCollection != null
        ? _collectionDetail?.songs ?? const <CatalogSong>[]
        : (_selectedArtist == null
                      ? _searchResult
                      : _artistDetail == null
                      ? _artistResult ?? _searchResult
                      : null)
                  ?.songs ??
              _artistDetail?.songs ??
              const <CatalogSong>[];
    final queue = sourceSongs
        .where(
          (song) =>
              song.playable &&
              (!_isOfficialSearchSurface || _activeSearchPlaybackEnabled) &&
              (_selectedCollection == null ||
                  _collectionDetail?.catalogPlaybackEnabled == true),
        )
        .map((song) => song.song)
        .toList(growable: false);
    _selectSong(item.song, queue.isEmpty ? [item.song] : queue);
  }

  bool get _isOfficialSearchSurface =>
      _selectedTab == _discoveryTab &&
      _catalogBrowseView == _CatalogBrowseView.discovery &&
      _selectedArtist == null &&
      _selectedCollection == null &&
      _searchController.text.trim().isNotEmpty;

  bool get _activeSearchPlaybackEnabled {
    if (!_isOfficialSearchSurface) return true;
    return (_searchPages[_searchSection]?.catalogPlaybackEnabled ??
            _searchResult?.catalogPlaybackEnabled) ==
        true;
  }

  Future<void> _openCatalogVideo(CatalogVideo video) async {
    if (!widget.tvMode) {
      try {
        if (await widget.launchExternalCatalog(Uri.parse(video.externalUrl))) {
          return;
        }
      } catch (_) {
        // Platforms without a URL-launcher adapter use the QR/copy fallback.
      }
    }
    if (!mounted) return;
    await showCatalogVideoHandoffDialog(context, video);
  }

  void _openDesktopPlayerPanel(DesktopPlaybackPanelTab tab) {
    if (_desktopPlayerVisible && _desktopPlayerTab == tab) return;
    setState(() {
      _desktopPlayerTab = tab;
      _desktopPlayerVisible = true;
    });
  }

  Future<void> _openCurrentSongMv(MusicPlayerController controller) async {
    final song = controller.currentSong;
    if (song == null || controller.isLiveRadio || _isCurrentMvLoading) return;
    final requestId = ++_currentMvRequestId;
    setState(() => _isCurrentMvLoading = true);
    try {
      final detail = await widget.loadSongDetail(song.id);
      if (!mounted ||
          requestId != _currentMvRequestId ||
          controller.currentSong?.id != song.id) {
        return;
      }
      final mv = detail.mv;
      if (mv == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${song.displayTitle} chưa có MV chính thức trên Zing MP3.',
            ),
          ),
        );
        return;
      }
      await _openCatalogVideo(mv);
    } catch (_) {
      if (!mounted || requestId != _currentMvRequestId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa tải được MV chính thức. Vui lòng thử lại.'),
        ),
      );
    } finally {
      if (mounted && requestId == _currentMvRequestId) {
        setState(() => _isCurrentMvLoading = false);
      }
    }
  }

  Future<void> _handleDesktopDockSongAction(
    MusicPlayerController controller,
    DesktopDockSongAction action,
  ) async {
    final song = controller.currentSong;
    if (song == null || controller.isLiveRadio) return;
    final queue = controller.queue.isEmpty ? <Song>[song] : controller.queue;
    switch (action) {
      case DesktopDockSongAction.detail:
        await _openSongDetail(song, queue, canPlay: true);
        return;
      case DesktopDockSongAction.radio:
        await startSongRadioWithFeedback(context, controller, song);
        return;
      case DesktopDockSongAction.playlist:
        await _showPlaylistPicker(controller, song);
        return;
      case DesktopDockSongAction.share:
        await _shareSong(song, _catalogSongFor(song));
        return;
    }
  }

  Future<void> _shareSong(Song song, CatalogSong? catalogSong) async {
    CatalogSong? officialSong = catalogSong;
    final directContent = officialSong == null
        ? null
        : OfficialContentShare(
            kind: OfficialContentKind.song,
            title: officialSong.song.displayTitle,
            subtitle: officialSong.song.artistsNames,
            externalUrl: officialSong.externalUrl,
          );
    if (directContent == null || !isTrustedOfficialContentUrl(directContent)) {
      try {
        officialSong = (await widget.loadSongDetail(song.id)).catalogSong;
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Chưa lấy được liên kết chính thức của ${song.displayTitle}.',
            ),
          ),
        );
        return;
      }
    }
    if (!mounted || officialSong == null) return;
    await shareOfficialContent(
      context,
      OfficialContentShare(
        kind: OfficialContentKind.song,
        title: officialSong.song.displayTitle,
        subtitle: officialSong.song.artistsNames,
        externalUrl: officialSong.externalUrl,
      ),
      service: widget.officialContentShareService,
      forceHandoff: widget.tvMode,
    );
  }

  void _addSongToQueueWithFeedback(
    MusicPlayerController controller,
    Song song,
  ) {
    final didAdd = controller.addToQueue(song);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          didAdd
              ? 'Đã thêm ${song.displayTitle} vào hàng đợi'
              : '${song.displayTitle} đã ở vị trí tiếp theo',
        ),
      ),
    );
  }

  Future<void> _shareCollection(CatalogCollection collection) =>
      shareOfficialContent(
        context,
        OfficialContentShare(
          kind: OfficialContentKind.collection,
          title: collection.title,
          subtitle: collection.artist,
          externalUrl: collection.externalUrl,
        ),
        service: widget.officialContentShareService,
        forceHandoff: widget.tvMode,
      );

  void _toggleCollectionSaved(
    MusicPlayerController controller,
    CatalogCollection collection,
  ) {
    final saved = controller.toggleCollectionSaved(collection);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Đã lưu ${collection.title} vào thư viện.'
              : 'Đã bỏ ${collection.title} khỏi thư viện.',
        ),
      ),
    );
  }

  void _toggleArtistFollowWithFeedback(
    MusicPlayerController controller,
    CatalogArtist artist,
  ) {
    final followed = controller.toggleArtistFollow(artist);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          followed
              ? 'Đã quan tâm ${artist.name} trên thiết bị này.'
              : 'Đã bỏ quan tâm ${artist.name}.',
        ),
      ),
    );
  }

  Future<void> _shareArtist(CatalogArtist artist) => shareOfficialContent(
    context,
    OfficialContentShare(
      kind: OfficialContentKind.artist,
      title: artist.name,
      subtitle: 'Nghệ sĩ trên Zing MP3',
      externalUrl: artist.officialExternalUrl,
    ),
    service: widget.officialContentShareService,
    forceHandoff: widget.tvMode,
  );

  void _showUnavailable(Song song) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${song.displayTitle} chưa có nguồn phát được phép trên proxy. '
          'Bạn vẫn có thể yêu thích hoặc lưu vào playlist.',
        ),
      ),
    );
  }

  Future<void> _runCatalogSearch(String query) async {
    final normalized = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return;
    final previousResultQuery =
        _aggregateSearchResult?.query ?? _searchResult?.query;
    if (previousResultQuery != null && previousResultQuery != normalized) {
      _searchPageRequestId++;
      setState(() {
        _searchResult = null;
        _aggregateSearchResult = null;
        _searchPages = const {};
        _searchPaginationUnavailable = const {};
        _isSearchPageLoading = false;
        _searchPageErrorMessage = null;
      });
    }
    final requestId = ++_searchRequestId;
    setState(() {
      _isSearching = true;
      _searchErrorMessage = null;
    });
    final typedSection = _searchSection;
    if (typedSection != CatalogSearchSection.all &&
        widget.searchCatalogPage != null &&
        !_searchPages.containsKey(typedSection) &&
        !_searchPaginationUnavailable.contains(typedSection)) {
      // The signed typed endpoint remains useful even when legacy aggregate
      // search is temporarily unavailable.
      unawaited(_loadSearchPage(typedSection));
    }
    try {
      final result = await widget.searchCatalog(normalized);
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _aggregateSearchResult = result;
        _searchResult = _resultForSearchSection(result, _searchSection);
      });
      _lastCommittedSearchState = _captureNavigationState();
    } catch (error) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() => _searchErrorMessage = error.toString());
    } finally {
      if (mounted && requestId == _searchRequestId) {
        setState(() => _isSearching = false);
      }
    }
  }

  CatalogSearchResult _resultForSearchSection(
    CatalogSearchResult aggregate,
    CatalogSearchSection section,
  ) {
    final page = _searchPages[section];
    if (page != null) return page.asSearchResult;
    return switch (section) {
      CatalogSearchSection.all => aggregate,
      CatalogSearchSection.songs => CatalogSearchResult(
        query: aggregate.query,
        songs: aggregate.songs,
        artists: const [],
        catalogPlaybackEnabled: aggregate.catalogPlaybackEnabled,
      ),
      CatalogSearchSection.artists => CatalogSearchResult(
        query: aggregate.query,
        songs: const [],
        artists: aggregate.artists,
        catalogPlaybackEnabled: aggregate.catalogPlaybackEnabled,
      ),
      CatalogSearchSection.collections => CatalogSearchResult(
        query: aggregate.query,
        songs: const [],
        artists: const [],
        collections: aggregate.collections,
        catalogPlaybackEnabled: aggregate.catalogPlaybackEnabled,
      ),
      CatalogSearchSection.videos => CatalogSearchResult(
        query: aggregate.query,
        songs: const [],
        artists: const [],
        videos: aggregate.videos,
        catalogPlaybackEnabled: aggregate.catalogPlaybackEnabled,
      ),
    };
  }

  Future<void> _loadSearchPage(
    CatalogSearchSection section, {
    bool loadMore = false,
  }) async {
    final loader = widget.searchCatalogPage;
    if (loader == null ||
        section == CatalogSearchSection.all ||
        _searchPaginationUnavailable.contains(section) ||
        _isSearchPageLoading) {
      return;
    }
    final query = _searchController.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (query.isEmpty) return;
    final current = _searchPages[section];
    if (loadMore && (current == null || !current.hasMore)) return;
    final targetPage = loadMore ? current!.page + 1 : 1;
    final requestId = ++_searchPageRequestId;
    setState(() {
      _isSearchPageLoading = true;
      _searchPageErrorMessage = null;
    });
    try {
      final response = await loader(query, section, targetPage, 18);
      final activeQuery = _searchController.text.trim().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      if (!mounted ||
          requestId != _searchPageRequestId ||
          activeQuery != query ||
          response.query != query ||
          response.section != section ||
          response.page != targetPage ||
          response.limit != 18) {
        return;
      }
      final merged = loadMore ? current!.append(response) : response;
      setState(() {
        _searchPages =
            Map<CatalogSearchSection, CatalogSearchPage>.unmodifiable({
              ..._searchPages,
              section: merged,
            });
        if (_searchSection == section) {
          _searchResult = merged.asSearchResult;
        }
      });
      _lastCommittedSearchState = _captureNavigationState();
    } on MusicRepositoryException catch (error) {
      if (!mounted || requestId != _searchPageRequestId) return;
      if (error.code == 'SEARCH_PAGINATION_UNAVAILABLE') {
        setState(() {
          _searchPaginationUnavailable = Set<CatalogSearchSection>.unmodifiable(
            {..._searchPaginationUnavailable, section},
          );
          _searchPageErrorMessage = null;
        });
      } else {
        setState(() => _searchPageErrorMessage = error.message);
      }
    } catch (error) {
      if (!mounted || requestId != _searchPageRequestId) return;
      setState(() => _searchPageErrorMessage = error.toString());
    } finally {
      if (mounted && requestId == _searchPageRequestId) {
        setState(() => _isSearchPageLoading = false);
      }
    }
  }

  PlaybackOrigin _visiblePlaybackOrigin() {
    final collection = _collectionDetail?.collection ?? _selectedCollection;
    if (collection != null) {
      return PlaybackOrigin(
        kind: PlaybackOriginKind.collection,
        label: collection.title,
      );
    }
    final artist = _artistDetail?.artist ?? _selectedArtist;
    if (artist != null) {
      return PlaybackOrigin(
        kind: PlaybackOriginKind.artist,
        label: artist.name,
      );
    }
    if (_selectedTab == _chartTab) return const PlaybackOrigin.chart();
    if (_selectedTab == _newReleaseTab) {
      return const PlaybackOrigin(
        kind: PlaybackOriginKind.newReleaseChart,
        label: 'BXH Nhạc Mới',
      );
    }
    if (_selectedTab == _forYouTab) {
      return const PlaybackOrigin(
        kind: PlaybackOriginKind.forYou,
        label: 'Dành cho bạn',
      );
    }
    if (_selectedTab == _libraryTab) {
      final controller = _playerController;
      final playlist = _selectedPlaylist(controller);
      if (playlist != null) {
        return PlaybackOrigin(
          kind: PlaybackOriginKind.playlist,
          label: playlist.name,
        );
      }
      return const PlaybackOrigin(
        kind: PlaybackOriginKind.library,
        label: 'Thư viện của bạn',
      );
    }
    if (_selectedTab == _discoveryTab) {
      final query = _searchController.text.trim();
      if (query.isNotEmpty) {
        return PlaybackOrigin(
          kind: PlaybackOriginKind.search,
          label: 'Tìm kiếm · $query',
        );
      }
      if (_selectedHub != null) {
        return PlaybackOrigin(
          kind: PlaybackOriginKind.discovery,
          label: _selectedHub!.title,
        );
      }
      return switch (_catalogBrowseView) {
        _CatalogBrowseView.hubs => const PlaybackOrigin(
          kind: PlaybackOriginKind.discovery,
          label: 'Chủ đề & Thể loại',
        ),
        _CatalogBrowseView.top100 => const PlaybackOrigin(
          kind: PlaybackOriginKind.discovery,
          label: 'Top 100',
        ),
        _CatalogBrowseView.releases => const PlaybackOrigin(
          kind: PlaybackOriginKind.releaseCatalog,
          label: 'Mới Phát Hành',
        ),
        _CatalogBrowseView.weekly => PlaybackOrigin(
          kind: PlaybackOriginKind.weeklyChart,
          label: 'BXH Tuần · ${_weeklyRegion.label}',
        ),
        _CatalogBrowseView.discovery => PlaybackOrigin(
          kind: PlaybackOriginKind.discovery,
          label: _selectedDiscoveryCategoryName(),
        ),
      };
    }
    return const PlaybackOrigin.chart();
  }

  String _selectedDiscoveryCategoryName() {
    for (final category in _discoveryCategories.items) {
      if (category.id == _selectedDiscoveryCategoryId) {
        return 'Khám phá · ${category.name}';
      }
    }
    return 'Khám phá';
  }

  void _selectSong(Song song, List<Song> queue, {PlaybackOrigin? origin}) {
    final controller = _playerController;
    unawaited(
      controller.playSong(
        song,
        queue: queue,
        origin: origin ?? _visiblePlaybackOrigin(),
      ),
    );
    if (widget.tvMode) {
      if (!_desktopPlayerVisible) {
        setState(() => _desktopPlayerVisible = true);
      }
      return;
    }
    if (MediaQuery.sizeOf(context).width >= 1100 &&
        !controller.alwaysOpenFullscreenPlayer) {
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MusicPlayerScreen()));
  }

  Future<void> _openSongDetail(
    Song song,
    List<Song> queue, {
    required bool canPlay,
  }) => showSongDetail(
    context,
    controller: _playerController,
    detailLoader: widget.loadSongDetail,
    initialSong: song,
    onPlay: canPlay ? () => _selectSong(song, queue) : null,
    onOpenArtist: _openArtistFromSongDetail,
    onOpenAlbum: _openAlbumFromSongDetail,
    externalLauncher: widget.launchExternalCatalog,
    shareService: widget.officialContentShareService,
    tvMode: widget.tvMode,
  );

  void _openArtistFromSongDetail(CatalogArtist artist) {
    if (!mounted) return;
    Navigator.of(context).pop();
    _selectTab(_discoveryTab);
    unawaited(_openArtist(artist));
  }

  void _openArtistFromCollectionHero(CatalogArtist artist) {
    if (!mounted) return;
    _recordNavigationOrigin();
    setState(() {
      _selectedCollection = null;
      _collectionDetail = null;
      _collectionErrorMessage = null;
      _collectionOriginArtist = null;
      _collectionOriginArtistDetail = null;
      _collectionOriginArtistResult = null;
      _collectionOriginArtistSection = OfficialArtistSection.profile;
      _isCollectionLoading = false;
    });
    unawaited(_openArtist(artist));
  }

  void _openAlbumFromSongDetail(CatalogCollection album) {
    if (!mounted) return;
    Navigator.of(context).pop();
    _selectTab(_discoveryTab);
    unawaited(_openCollection(album));
  }

  void _selectLiveRadio(LiveRadioRoom room) {
    final controller = _playerController;
    unawaited(controller.playLiveRadio(room));
    if (widget.tvMode) {
      if (!_desktopPlayerVisible) {
        setState(() => _desktopPlayerVisible = true);
      }
      return;
    }
    if (MediaQuery.sizeOf(context).width >= 1100 &&
        !controller.alwaysOpenFullscreenPlayer) {
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MusicPlayerScreen()));
  }

  @override
  Widget build(BuildContext context) {
    _scheduleNavigationRouteReport();
    final controller = _playerController;
    final visibleSongs = _visibleSongs(controller);
    final width = MediaQuery.sizeOf(context).width;
    final useRail = widget.tvMode || width >= 720;
    final useDesktopCatalogSidebar = !widget.tvMode && width >= 1320;
    final extendRail = widget.tvMode || width >= 1180;
    final showDesktopQueue =
        !widget.tvMode && width >= 1100 && _desktopPlayerVisible;

    return CallbackShortcuts(
      bindings: _shortcutBindings(controller, width),
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Focus(
          autofocus: !widget.tvMode,
          child: PopScope<void>(
            canPop:
                !_canNavigateBack &&
                _selectedArtist == null &&
                _selectedCollection == null &&
                _selectedHub == null &&
                _catalogBrowseView == _CatalogBrowseView.discovery &&
                (!widget.tvMode ||
                    (_selectedTab == _chartTab && !_searchFocusNode.hasFocus)),
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _handleBack(width);
            },
            child: Scaffold(
              bottomNavigationBar: useRail
                  ? null
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const MiniPlayer(),
                        _buildMobileNavigation(width),
                      ],
                    ),
              body: Row(
                children: [
                  if (useRail)
                    if (useDesktopCatalogSidebar)
                      DesktopCatalogSidebar(
                        selected: _desktopCatalogDestination,
                        onDestinationSelected: _selectDesktopCatalogDestination,
                        likedSongs: controller.likedSongs.length,
                        playlists: controller.playlists.length,
                        listeningMinutes: controller
                            .analyticsSummary(AnalyticsPeriod.thirtyDays)
                            .listened
                            .inMinutes,
                        onOpenLocalProfile: () =>
                            _selectDesktopCatalogDestination(
                              DesktopCatalogDestination.forYou,
                            ),
                        onCreatePlaylist: () => _showCreatePlaylist(controller),
                        onShowQueue: () => _openDesktopPlayerPanel(
                          DesktopPlaybackPanelTab.queue,
                        ),
                      )
                    else
                      _buildNavigationRail(
                        tvMode: widget.tvMode,
                        extended: extendRail,
                      ),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) =>
                                      _buildContent(
                                        controller,
                                        visibleSongs,
                                        contentWidth: constraints.maxWidth,
                                      ),
                                ),
                              ),
                              if (showDesktopQueue)
                                DesktopPlaybackQueuePanel(
                                  lyricsLoader: widget.lyricsLoader,
                                  initialTab: _desktopPlayerTab,
                                  onTabChanged: (tab) {
                                    if (_desktopPlayerTab == tab) return;
                                    setState(() => _desktopPlayerTab = tab);
                                  },
                                  onClose: () => setState(
                                    () => _desktopPlayerVisible = false,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (useRail && !widget.tvMode)
                          MiniPlayer(
                            desktop: !widget.tvMode && width >= 1100,
                            onOpenQueue: !widget.tvMode && width >= 1100
                                ? () => _openDesktopPlayerPanel(
                                    DesktopPlaybackPanelTab.queue,
                                  )
                                : null,
                            onOpenLyrics: !widget.tvMode && width >= 1100
                                ? () => _openDesktopPlayerPanel(
                                    DesktopPlaybackPanelTab.lyrics,
                                  )
                                : null,
                            onOpenMv: !widget.tvMode && width >= 1100
                                ? () =>
                                      unawaited(_openCurrentSongMv(controller))
                                : null,
                            onSongAction: !widget.tvMode && width >= 1100
                                ? (action) => unawaited(
                                    _handleDesktopDockSongAction(
                                      controller,
                                      action,
                                    ),
                                  )
                                : null,
                            mvLoading: _isCurrentMvLoading,
                          ),
                      ],
                    ),
                  ),
                  if (widget.tvMode) const DesktopNowPlayingPanel(tvMode: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _shortcutBindings(
    MusicPlayerController controller,
    double width,
  ) {
    final bindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.space): () {
        if (!_isEditingText()) unawaited(controller.togglePlayPause());
      },
      const SingleActivator(LogicalKeyboardKey.keyF, control: true):
          _focusSearch,
      const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _focusSearch,
      const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
          controller.previous,
      const SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true):
          controller.previous,
      const SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
          controller.next,
      const SingleActivator(LogicalKeyboardKey.arrowRight, meta: true):
          controller.next,
      const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
          _navigateBack,
      const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
          _navigateForward,
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          _handleBack(width),
      const SingleActivator(LogicalKeyboardKey.mediaPlayPause):
          controller.togglePlayPause,
      const SingleActivator(LogicalKeyboardKey.mediaPlay): () {
        if (!controller.isPlaying) unawaited(controller.togglePlayPause());
      },
      const SingleActivator(LogicalKeyboardKey.mediaPause): () {
        if (controller.isPlaying) unawaited(controller.togglePlayPause());
      },
      const SingleActivator(LogicalKeyboardKey.mediaStop): controller.stop,
      const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious):
          controller.previous,
      const SingleActivator(LogicalKeyboardKey.mediaTrackNext): controller.next,
      const SingleActivator(LogicalKeyboardKey.mediaRewind): () =>
          unawaited(_seekBy(controller, -10)),
      const SingleActivator(LogicalKeyboardKey.mediaFastForward): () =>
          unawaited(_seekBy(controller, 10)),
    };
    if (!widget.tvMode) {
      bindings
        ..[const SingleActivator(LogicalKeyboardKey.arrowLeft)] = () {
          if (!_isEditingText()) unawaited(_seekBy(controller, -10));
        }
        ..[const SingleActivator(LogicalKeyboardKey.arrowRight)] = () {
          if (!_isEditingText()) unawaited(_seekBy(controller, 10));
        };
    }
    return bindings;
  }

  void _handleBack(double width) {
    if (!widget.tvMode && width >= 1100 && _desktopPlayerVisible) {
      setState(() => _desktopPlayerVisible = false);
      return;
    }
    if (_selectedPlaylistId != null) {
      _navigateBackOr(_closeLocalPlaylist);
      return;
    }
    if (_selectedCollection != null) {
      _navigateBackOr(_closeCollection);
      return;
    }
    if (_selectedArtist != null) {
      _navigateBackOr(_closeArtist);
      return;
    }
    if (_selectedHub != null ||
        _catalogBrowseView != _CatalogBrowseView.discovery) {
      _navigateBackOr(_closeCatalogBrowse);
      return;
    }
    if (widget.tvMode) {
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus(
          disposition: UnfocusDisposition.previouslyFocusedChild,
        );
      } else if (_canNavigateBack) {
        _navigateBack();
      } else if (_selectedTab != _chartTab) {
        _selectTab(_chartTab);
      } else {
        if (!requestTvPlatformExit()) unawaited(SystemNavigator.pop());
      }
      return;
    }
    if (_canNavigateBack) {
      _navigateBack();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _seekBy(MusicPlayerController controller, int seconds) =>
      controller.seek(controller.position + Duration(seconds: seconds));

  Future<void> _refreshContent() {
    final selectedCollection = _selectedCollection;
    if (selectedCollection != null) {
      return _openCollection(
        _collectionDetail?.collection ?? selectedCollection,
        preserveDetail: true,
      );
    }
    final selectedArtist = _selectedArtist;
    if (selectedArtist != null) {
      return _openArtist(selectedArtist, preserveResult: true);
    }
    final selectedHub = _selectedHub;
    if (selectedHub != null) {
      return _openHub(_hubDetail?.hub ?? selectedHub, preserveDetail: true);
    }
    if (_selectedTab == _discoveryTab &&
        _catalogBrowseView == _CatalogBrowseView.hubs) {
      return _loadHubHome();
    }
    if (_selectedTab == _discoveryTab &&
        _catalogBrowseView == _CatalogBrowseView.top100) {
      return _loadTop100();
    }
    if (_selectedTab == _discoveryTab &&
        _catalogBrowseView == _CatalogBrowseView.releases) {
      return _loadReleaseCatalog();
    }
    if (_selectedTab == _discoveryTab &&
        _catalogBrowseView == _CatalogBrowseView.weekly) {
      return _loadWeeklyChart(
        region: _weeklyRegion,
        week: _weeklyChart.isEmpty ? null : _weeklyChart.week,
        year: _weeklyChart.isEmpty ? null : _weeklyChart.year,
        preserveChart: true,
      );
    }
    if (_selectedTab == _newReleaseTab) return _loadNewReleases();
    if (_selectedTab == _liveRadioTab) return _loadLiveRadio();
    if (_selectedTab == _discoveryTab) {
      final query = _searchController.text.trim();
      return query.isEmpty ? _refreshDiscoveryHome() : _runCatalogSearch(query);
    }
    return _loadSongs();
  }

  Future<void> _refreshDiscoveryHome() async {
    await Future.wait([
      _loadDiscoveryHome(categoryId: _selectedDiscoveryCategoryId),
      _loadDiscoveryRecommendations(),
      if (_selectedDiscoveryCategoryId == '-1') _loadReleaseCatalog(),
      if (_selectedDiscoveryCategoryId == '-1') _loadNewReleases(),
    ]);
  }

  Widget _buildPinnedDiscoveryCategoryRail() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('pinned-discovery-categories'),
      color: scheme.surface.withValues(alpha: 0.98),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.38),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: DiscoveryCategoryRail(
            categories: _discoveryCategories.items,
            loading: _isDiscoveryCategoriesLoading,
            errorMessage: _discoveryCategoriesErrorMessage,
            selectedCategoryId: _selectedDiscoveryCategoryId,
            onSelected: _selectDiscoveryCategory,
            onRetry: () => unawaited(_loadDiscoveryCategories(force: true)),
            tvMode: false,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    MusicPlayerController controller,
    List<Song> visibleSongs, {
    required double contentWidth,
  }) {
    final pinCatalogToolbar =
        !widget.tvMode && MediaQuery.sizeOf(context).width >= 720;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selectedPlaylist = _selectedPlaylist(controller);
    final localPlaylistRequested =
        _selectedTab == _libraryTab && _selectedPlaylistId != null;
    final selectedArtist = _selectedArtist;
    final effectiveArtist = _artistDetail?.artist ?? selectedArtist;
    final selectedCollection = _selectedCollection;
    final effectiveCollection =
        _collectionDetail?.collection ?? selectedCollection;
    final desktopCollectionWorkspace =
        !widget.tvMode &&
        MediaQuery.sizeOf(context).width >= 1200 &&
        contentWidth >= 820 &&
        effectiveCollection != null;
    final compactContentSongRows = !widget.tvMode && contentWidth < 980;
    final collectionCatalogSongs =
        _collectionDetail?.songs ?? const <CatalogSong>[];
    final fallbackArtistSongs = selectedArtist == null
        ? const <CatalogSong>[]
        : (_artistResult ?? _searchResult)?.songs
                  .where(
                    (item) => _songMatchesArtist(item.song, selectedArtist),
                  )
                  .toList(growable: false) ??
              const <CatalogSong>[];
    final fullArtistSongs = _artistDetail?.songs ?? fallbackArtistSongs;
    final artistDetail = _artistDetail;
    final artistLatestRelease = artistDetail == null
        ? null
        : _artistLatestRelease(artistDetail);
    final desktopArtistSongs = artistDetail == null
        ? const <Song>[]
        : _desktopArtistFeaturedSongs(artistDetail);
    final desktopArtistOverview =
        !widget.tvMode &&
        MediaQuery.sizeOf(context).width >= 1180 &&
        selectedArtist != null &&
        artistDetail != null &&
        _artistSection == OfficialArtistSection.profile &&
        artistLatestRelease != null &&
        desktopArtistSongs.isNotEmpty;
    final artistSongView =
        selectedArtist != null &&
        (_artistSection == OfficialArtistSection.profile ||
            _artistSection == OfficialArtistSection.songs);
    final hasSearchQuery = _searchController.text.trim().isNotEmpty;
    final pinDiscoveryCategoryRail =
        pinCatalogToolbar &&
        _selectedTab == _discoveryTab &&
        selectedCollection == null &&
        selectedArtist == null &&
        !hasSearchQuery &&
        _selectedHub == null &&
        _catalogBrowseView == _CatalogBrowseView.discovery;
    final pinnedDiscoveryChromeExtent =
        pinDiscoveryCategoryRail &&
            _discoveryCategories.items.isEmpty &&
            _discoveryCategoriesErrorMessage != null
        ? _pinnedDiscoveryChromeErrorExtent
        : _pinnedDiscoveryChromeExtent;
    final discoveryRecommendations = _discoveryRecommendations();
    final discoveryReleaseSongs = _discoveryReleaseSongs();
    final isReleaseSongView =
        _selectedTab == _discoveryTab &&
        _catalogBrowseView == _CatalogBrowseView.releases &&
        _releaseContentType == ReleaseContentType.songs;
    final isWeeklySongView =
        _selectedTab == _discoveryTab &&
        _catalogBrowseView == _CatalogBrowseView.weekly;
    final showLibrarySongList =
        _selectedTab != _libraryTab ||
        (_selectedPlaylistId == null &&
            _librarySection == LibrarySection.songs);
    final showSearchSongList =
        _selectedTab != _liveRadioTab &&
        showLibrarySongList &&
        (isReleaseSongView ||
            isWeeklySongView ||
            _selectedTab != _discoveryTab ||
            selectedCollection != null ||
            artistSongView ||
            (hasSearchQuery &&
                _searchSection != CatalogSearchSection.artists &&
                _searchSection != CatalogSearchSection.collections &&
                _searchSection != CatalogSearchSection.videos));
    final officialSearchSongRows =
        _selectedTab == _discoveryTab &&
        hasSearchQuery &&
        selectedCollection == null &&
        selectedArtist == null &&
        _catalogBrowseView == _CatalogBrowseView.discovery &&
        (_searchSection == CatalogSearchSection.all ||
            _searchSection == CatalogSearchSection.songs);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF21142F), ZingColors.ink]
              : const [Color(0xFFF0E8F8), ZingColors.paper],
          stops: [0, 0.5],
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshContent,
          color: const Color(0xFFFF6B4A),
          backgroundColor: const Color(0xFF242529),
          child: CustomScrollView(
            controller: _contentScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (pinCatalogToolbar)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _CatalogToolbarDelegate(
                    extent: pinDiscoveryCategoryRail
                        ? pinnedDiscoveryChromeExtent
                        : _catalogToolbarExtent,
                    child: Column(
                      children: [
                        SizedBox(
                          height: _catalogToolbarExtent,
                          child: _buildCatalogToolbar(controller),
                        ),
                        if (pinDiscoveryCategoryRail)
                          Expanded(child: _buildPinnedDiscoveryCategoryRail()),
                      ],
                    ),
                  ),
                ),
              if (!localPlaylistRequested)
                SliverToBoxAdapter(
                  child: _buildHeader(pinCatalogToolbar: pinCatalogToolbar),
                ),
              if (localPlaylistRequested && selectedPlaylist != null)
                LocalPlaylistWorkspace(
                  playlist: selectedPlaylist,
                  tvMode: widget.tvMode,
                  showBack: !pinCatalogToolbar,
                  currentSongId: controller.currentSong?.id,
                  isPlaying: controller.isPlaying,
                  onBack: () => _navigateBackOr(_closeLocalPlaylist),
                  onPlayAll: () => _playLocalPlaylist(
                    controller,
                    selectedPlaylist,
                    shuffle: false,
                  ),
                  onShuffle: () => _playLocalPlaylist(
                    controller,
                    selectedPlaylist,
                    shuffle: true,
                  ),
                  onRename: () =>
                      _showRenamePlaylist(controller, selectedPlaylist),
                  onDelete: () =>
                      _confirmDeletePlaylist(controller, selectedPlaylist),
                  onSongTap: (song) => _selectSong(
                    song,
                    selectedPlaylist.songs,
                    origin: PlaybackOrigin(
                      kind: PlaybackOriginKind.playlist,
                      label: selectedPlaylist.name,
                    ),
                  ),
                  onReorderItem: (oldIndex, targetIndex) =>
                      controller.reorderPlaylistSongItem(
                        selectedPlaylist.id,
                        oldIndex,
                        targetIndex,
                      ),
                  onMoveItem: (oldIndex, targetIndex) =>
                      controller.reorderPlaylistSongItem(
                        selectedPlaylist.id,
                        oldIndex,
                        targetIndex,
                      ),
                  onRemove: (song) => _removePlaylistSongWithUndo(
                    controller,
                    selectedPlaylist.id,
                    song,
                  ),
                  actionResolver: (song) => _localPlaylistSongActions(
                    controller,
                    selectedPlaylist,
                    song,
                  ),
                )
              else if (localPlaylistRequested)
                SliverToBoxAdapter(
                  child: LocalPlaylistMissingState(
                    onBackToPlaylists: () =>
                        _navigateBackOr(_closeLocalPlaylist),
                  ),
                )
              else if (_selectedTab == _discoveryTab &&
                  effectiveCollection != null &&
                  desktopCollectionWorkspace)
                _buildDesktopCollectionWorkspace(
                  controller,
                  effectiveCollection,
                  visibleSongs,
                  availableWidth: contentWidth,
                )
              else if (_selectedTab == _discoveryTab &&
                  effectiveCollection != null)
                SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: CollectionDetailHero(
                        collection: effectiveCollection,
                        detail: _collectionDetail,
                        loading: _isCollectionLoading,
                        tvMode: widget.tvMode,
                        isSaved: controller.isCollectionSaved(
                          effectiveCollection,
                        ),
                        onToggleSave: _collectionDetail == null
                            ? null
                            : () => _toggleCollectionSaved(
                                controller,
                                effectiveCollection,
                              ),
                        onShare: effectiveCollection.externalUrl.isEmpty
                            ? null
                            : () => unawaited(
                                _shareCollection(effectiveCollection),
                              ),
                        onArtistTap: _openArtistFromCollectionHero,
                        shufflePlay:
                            effectiveCollection.kind ==
                            CatalogCollectionKind.playlist,
                        onPlay:
                            _collectionDetail?.catalogPlaybackEnabled == true &&
                                collectionCatalogSongs.any(
                                  (song) => song.playable,
                                )
                            ? () {
                                controller.setShuffleEnabled(
                                  effectiveCollection.kind ==
                                      CatalogCollectionKind.playlist,
                                );
                                final playable = collectionCatalogSongs
                                    .where((song) => song.playable)
                                    .toList(growable: false);
                                _openHighlightedSong(playable.first);
                              }
                            : null,
                      ),
                    ),
                    if (_collectionDetail != null &&
                        _collectionErrorMessage != null)
                      SliverToBoxAdapter(
                        child: _CollectionErrorState(
                          message: _collectionErrorMessage!,
                          compact: true,
                          onRetry: () => _openCollection(
                            effectiveCollection,
                            preserveDetail: true,
                          ),
                        ),
                      ),
                  ],
                )
              else if (_selectedTab == _discoveryTab && selectedArtist != null)
                SliverToBoxAdapter(
                  child: ArtistProfileHero(
                    artist: selectedArtist,
                    songs: fullArtistSongs,
                    detail: _artistDetail,
                    errorMessage: _artistErrorMessage,
                    onRetry: () => unawaited(
                      _openArtist(selectedArtist, preserveResult: true),
                    ),
                    loading: _isArtistLoading,
                    tvMode: widget.tvMode,
                    isFollowed: controller.isArtistFollowed(effectiveArtist!),
                    onToggleFollow: () => _toggleArtistFollowWithFeedback(
                      controller,
                      effectiveArtist,
                    ),
                    onShare: effectiveArtist.officialExternalUrl.isEmpty
                        ? null
                        : () => unawaited(_shareArtist(effectiveArtist)),
                    onPlay: fullArtistSongs.any((song) => song.playable)
                        ? () {
                            final playable = fullArtistSongs
                                .where((song) => song.playable)
                                .toList(growable: false);
                            _openHighlightedSong(playable.first);
                          }
                        : null,
                  ),
                )
              else if (_selectedTab == _discoveryTab && hasSearchQuery)
                SliverToBoxAdapter(
                  child: SearchDiscoverySummary(
                    query: _searchController.text.trim(),
                    isLoading: _isSearching,
                    result: _searchResult,
                    errorMessage: _searchErrorMessage,
                    section: _searchSection,
                    onSuggestion: _applySearchSuggestion,
                    onArtistTap: (artist) => unawaited(_openArtist(artist)),
                    onSongTap: _openHighlightedSong,
                    onCollectionTap: (collection) =>
                        unawaited(_openCollection(collection)),
                    onVideoTap: (video) => unawaited(_openCatalogVideo(video)),
                    onRetry: () =>
                        unawaited(_runCatalogSearch(_searchController.text)),
                    tvMode: widget.tvMode,
                  ),
                )
              else if (_selectedTab == _discoveryTab && _selectedHub != null)
                SliverToBoxAdapter(
                  child: CatalogHubDetailView(
                    detail: _hubDetail,
                    loading: _isHubDetailLoading,
                    errorMessage: _hubDetailErrorMessage,
                    onBack: _navigateToolbarBack,
                    onRetry: () => unawaited(
                      _openHub(
                        _hubDetail?.hub ?? _selectedHub!,
                        preserveDetail: true,
                      ),
                    ),
                    onCollectionTap: (collection) =>
                        unawaited(_openCollection(collection)),
                    onCollectionPlay: (collection) =>
                        unawaited(_quickPlayCollection(collection)),
                    onCollectionToggleSaved: (collection) =>
                        _toggleCollectionSaved(controller, collection),
                    onCollectionShare: (collection) =>
                        unawaited(_shareCollection(collection)),
                    onArtistTap: (artist) => unawaited(_openArtist(artist)),
                    savedCollectionIds: controller.savedCollections
                        .map((collection) => collection.id)
                        .toSet(),
                    quickPlayingCollectionId: _quickPlayingCollectionId,
                    tvMode: widget.tvMode,
                  ),
                )
              else if (_selectedTab == _discoveryTab &&
                  _catalogBrowseView == _CatalogBrowseView.hubs)
                SliverToBoxAdapter(
                  child: CatalogHubHomeView(
                    home: _hubHome,
                    loading: _isHubHomeLoading,
                    errorMessage: _hubHomeErrorMessage,
                    onBack: _navigateToolbarBack,
                    onRetry: () => unawaited(_loadHubHome()),
                    onHubTap: (hub) => unawaited(_openHub(hub)),
                    onCollectionTap: (collection) =>
                        unawaited(_openCollection(collection)),
                    onCollectionPlay: (collection) =>
                        unawaited(_quickPlayCollection(collection)),
                    onCollectionToggleSaved: (collection) =>
                        _toggleCollectionSaved(controller, collection),
                    onCollectionShare: (collection) =>
                        unawaited(_shareCollection(collection)),
                    onArtistTap: (artist) => unawaited(_openArtist(artist)),
                    savedCollectionIds: controller.savedCollections
                        .map((collection) => collection.id)
                        .toSet(),
                    quickPlayingCollectionId: _quickPlayingCollectionId,
                    tvMode: widget.tvMode,
                  ),
                )
              else if (_selectedTab == _discoveryTab &&
                  _catalogBrowseView == _CatalogBrowseView.top100)
                SliverToBoxAdapter(
                  child: Top100CatalogView(
                    catalog: _top100Catalog,
                    loading: _isTop100Loading,
                    errorMessage: _top100ErrorMessage,
                    onBack: _navigateToolbarBack,
                    onRetry: () => unawaited(_loadTop100()),
                    onCollectionTap: (collection) =>
                        unawaited(_openCollection(collection)),
                    onCollectionPlay: (collection) =>
                        unawaited(_quickPlayCollection(collection)),
                    onCollectionToggleSaved: (collection) =>
                        _toggleCollectionSaved(controller, collection),
                    onCollectionShare: (collection) =>
                        unawaited(_shareCollection(collection)),
                    onArtistTap: (artist) => unawaited(_openArtist(artist)),
                    savedCollectionIds: controller.savedCollections
                        .map((collection) => collection.id)
                        .toSet(),
                    quickPlayingCollectionId: _quickPlayingCollectionId,
                    tvMode: widget.tvMode,
                  ),
                )
              else if (_selectedTab == _discoveryTab &&
                  _catalogBrowseView == _CatalogBrowseView.releases)
                SliverToBoxAdapter(
                  child: ReleaseCatalogView(
                    catalog: _releaseCatalog,
                    loading: _isReleaseCatalogLoading,
                    errorMessage: _releaseCatalogErrorMessage,
                    contentType: _releaseContentType,
                    region: _releaseRegion,
                    onBack: _navigateToolbarBack,
                    onRetry: () => unawaited(_loadReleaseCatalog()),
                    onContentTypeChanged: _changeReleaseContentType,
                    onRegionChanged: (region) => setState(() {
                      _releaseRegion = region;
                    }),
                    onCollectionTap: (collection) =>
                        unawaited(_openCollection(collection)),
                    onCollectionPlay: (collection) =>
                        unawaited(_quickPlayCollection(collection)),
                    onCollectionToggleSaved: (collection) =>
                        _toggleCollectionSaved(controller, collection),
                    onCollectionShare: (collection) =>
                        unawaited(_shareCollection(collection)),
                    onArtistTap: (artist) => unawaited(_openArtist(artist)),
                    savedCollectionIds: controller.savedCollections
                        .map((collection) => collection.id)
                        .toSet(),
                    quickPlayingCollectionId: _quickPlayingCollectionId,
                    songCount: _releaseCatalog.songsFor(_releaseRegion).length,
                    playableSongCount: _releaseCatalog
                        .songsFor(_releaseRegion)
                        .where((item) => item.playable)
                        .length,
                    onPlayAll:
                        _releaseCatalog
                            .songsFor(_releaseRegion)
                            .any((item) => item.playable)
                        ? () {
                            final playable = _releaseCatalog
                                .songsFor(_releaseRegion)
                                .where((item) => item.playable)
                                .map((item) => item.song)
                                .toList(growable: false);
                            _selectSong(playable.first, playable);
                          }
                        : null,
                    tvMode: widget.tvMode,
                  ),
                )
              else if (_selectedTab == _discoveryTab &&
                  _catalogBrowseView == _CatalogBrowseView.weekly)
                SliverToBoxAdapter(
                  child: WeeklyChartView(
                    chart: _weeklyChart,
                    loading: _isWeeklyChartLoading,
                    errorMessage: _weeklyChartErrorMessage,
                    region: _weeklyRegion,
                    onBack: _navigateToolbarBack,
                    onRetry: () => unawaited(
                      _loadWeeklyChart(
                        region: _weeklyRegion,
                        week: _weeklyChart.isEmpty ? null : _weeklyChart.week,
                        year: _weeklyChart.isEmpty ? null : _weeklyChart.year,
                        preserveChart: !_weeklyChart.isEmpty,
                      ),
                    ),
                    onRegionChanged: _changeWeeklyRegion,
                    onPeriodChanged: _changeWeeklyPeriod,
                    songCount: _weeklyChart.entries.length,
                    playableSongCount: _weeklyChart.playableSongs.length,
                    onPlayAll: _weeklyChart.playableSongs.isEmpty
                        ? null
                        : () {
                            final songs = _weeklyChart.playableSongs;
                            _selectSong(songs.first, songs);
                          },
                    tvMode: widget.tvMode,
                  ),
                )
              else if (_selectedTab == _discoveryTab)
                SliverToBoxAdapter(
                  child: DiscoveryHomeHub(
                    home: _discoveryHome,
                    loading: _isDiscoveryLoading,
                    errorMessage: _discoveryErrorMessage,
                    onRetry: () => unawaited(
                      _loadDiscoveryHome(
                        categoryId: _selectedDiscoveryCategoryId,
                      ),
                    ),
                    categories: _discoveryCategories.items,
                    categoriesLoading: _isDiscoveryCategoriesLoading,
                    categoriesErrorMessage: _discoveryCategoriesErrorMessage,
                    selectedCategoryId: _selectedDiscoveryCategoryId,
                    onCategorySelected: _selectDiscoveryCategory,
                    onRetryCategories: () =>
                        unawaited(_loadDiscoveryCategories(force: true)),
                    showCategoryRail: !pinDiscoveryCategoryRail,
                    onCollectionTap: (collection) =>
                        unawaited(_openCollection(collection)),
                    onCollectionPlay: (collection) =>
                        unawaited(_quickPlayCollection(collection)),
                    onCollectionToggleSaved: (collection) =>
                        _toggleCollectionSaved(controller, collection),
                    onCollectionShare: (collection) =>
                        unawaited(_shareCollection(collection)),
                    onCollectionArtistTap: (artist) =>
                        unawaited(_openArtist(artist)),
                    savedCollectionIds: controller.savedCollections
                        .map((collection) => collection.id)
                        .toSet(),
                    quickPlayingCollectionId: _quickPlayingCollectionId,
                    onVideoTap: (video) => unawaited(_openCatalogVideo(video)),
                    onOpenHubHome: _openHubHome,
                    onOpenTop100: _openTop100,
                    onOpenReleases: _openDiscoveryReleaseCatalog,
                    onOpenWeeklyChart: _openWeeklyChart,
                    onOpenWeeklyChartRegion: _openWeeklyChartRegion,
                    realtimeChartSnapshot: _chartSnapshot,
                    onRealtimeChartPlay: (song, queue) => _selectSong(
                      song,
                      queue,
                      origin: const PlaybackOrigin(
                        kind: PlaybackOriginKind.chart,
                        label: '#zingchart realtime',
                      ),
                    ),
                    onOpenRealtimeChart: () => _selectTab(_chartTab),
                    recommendations: discoveryRecommendations.songs,
                    recommendationsOfficial: discoveryRecommendations.official,
                    recommendationCatalogBySongId:
                        discoveryRecommendations.catalogBySongId,
                    canRefreshRecommendations:
                        discoveryRecommendations.canRefresh,
                    onRecommendationTap: (song) => _selectSong(
                      song,
                      discoveryRecommendations.songs,
                      origin: PlaybackOrigin(
                        kind: PlaybackOriginKind.recommendations,
                        label: discoveryRecommendations.official
                            ? 'Gợi ý bài hát · Zing MP3'
                            : 'Gợi ý từ #zingChart',
                      ),
                    ),
                    onRefreshRecommendations: () =>
                        setState(() => _discoveryRecommendationPage++),
                    likedRecommendationIds: controller.likedSongs
                        .map((song) => song.id)
                        .toSet(),
                    onRecommendationToggleLike: controller.toggleLike,
                    onRecommendationAddToQueue: (song) =>
                        _addSongToQueueWithFeedback(controller, song),
                    onRecommendationOpenDetail: (song) => unawaited(
                      _openSongDetail(
                        song,
                        discoveryRecommendations.songs,
                        canPlay: true,
                      ),
                    ),
                    onRecommendationStartRadio: (song) => unawaited(
                      startSongRadioWithFeedback(context, controller, song),
                    ),
                    onRecommendationAddToPlaylist: (song) =>
                        unawaited(_showPlaylistPicker(controller, song)),
                    onRecommendationShare: (song) => unawaited(
                      _shareSong(song, _discoveryRecommendationFor(song)),
                    ),
                    onRecommendationArtistTap: (artist) =>
                        unawaited(_openArtist(artist)),
                    recentlyPlayed: controller.recentlyPlayed
                        .take(10)
                        .toList(growable: false),
                    onRecentSongTap: (song) {
                      final queue = controller.recentlyPlayed
                          .take(10)
                          .toList(growable: false);
                      if (queue.isNotEmpty) {
                        _selectSong(
                          song,
                          queue,
                          origin: const PlaybackOrigin(
                            kind: PlaybackOriginKind.recentlyPlayed,
                            label: 'Nghe gần đây',
                          ),
                        );
                      }
                    },
                    recentSongActionResolver: (song) {
                      final queue = controller.recentlyPlayed
                          .take(10)
                          .toList(growable: false);
                      return SongActionMenuConfiguration(
                        isLiked: controller.isLiked(song),
                        moods: controller.moodsFor(song),
                        handlers: SongActionHandlers(
                          onPlay: () => _selectSong(
                            song,
                            queue,
                            origin: const PlaybackOrigin(
                              kind: PlaybackOriginKind.recentlyPlayed,
                              label: 'Nghe gần đây',
                            ),
                          ),
                          onOpenDetail: () => unawaited(
                            _openSongDetail(song, queue, canPlay: true),
                          ),
                          onAddToQueue: () =>
                              _addSongToQueueWithFeedback(controller, song),
                          onStartRadio: () => unawaited(
                            startSongRadioWithFeedback(
                              context,
                              controller,
                              song,
                            ),
                          ),
                          onAddToPlaylist: () =>
                              unawaited(_showPlaylistPicker(controller, song)),
                          onShare: () => unawaited(
                            _shareSong(song, _catalogSongFor(song)),
                          ),
                          onToggleLike: () => controller.toggleLike(song),
                          onToggleMood: (mood) =>
                              controller.toggleMood(song, mood),
                        ),
                      );
                    },
                    onOpenLibrary: () => _selectTab(_libraryTab),
                    newReleaseChartEntries: _newReleaseChart.entries,
                    newReleaseChartLoading: _isNewReleaseLoading,
                    newReleaseChartErrorMessage: _newReleaseErrorMessage,
                    onNewReleaseChartEntryTap: (entry) {
                      if (!entry.playable) return;
                      final queue = _newReleaseChart.entries
                          .take(3)
                          .where((item) => item.playable)
                          .map((item) => item.song)
                          .toList(growable: false);
                      if (queue.isNotEmpty) {
                        _selectSong(
                          entry.song,
                          queue,
                          origin: const PlaybackOrigin(
                            kind: PlaybackOriginKind.newReleaseChart,
                            label: 'BXH Nhạc Mới',
                          ),
                        );
                      }
                    },
                    newReleaseChartActionResolver: (entry) {
                      final queue = _newReleaseChart.entries
                          .take(3)
                          .where((item) => item.playable)
                          .map((item) => item.song)
                          .toList(growable: false);
                      return SongActionMenuConfiguration(
                        isLiked: controller.isLiked(entry.song),
                        moods: controller.moodsFor(entry.song),
                        handlers: SongActionHandlers(
                          onPlay: entry.playable
                              ? () => _selectSong(
                                  entry.song,
                                  queue,
                                  origin: const PlaybackOrigin(
                                    kind: PlaybackOriginKind.newReleaseChart,
                                    label: 'BXH Nhạc Mới',
                                  ),
                                )
                              : null,
                          onOpenDetail: () => unawaited(
                            _openSongDetail(
                              entry.song,
                              queue,
                              canPlay: entry.playable,
                            ),
                          ),
                          onAddToQueue: entry.playable
                              ? () => _addSongToQueueWithFeedback(
                                  controller,
                                  entry.song,
                                )
                              : null,
                          onStartRadio: entry.playable
                              ? () => unawaited(
                                  startSongRadioWithFeedback(
                                    context,
                                    controller,
                                    entry.song,
                                  ),
                                )
                              : null,
                          onAddToPlaylist: () => unawaited(
                            _showPlaylistPicker(controller, entry.song),
                          ),
                          onShare: () => unawaited(
                            _shareSong(entry.song, entry.catalogSong),
                          ),
                          onToggleLike: () => controller.toggleLike(entry.song),
                          onToggleMood: (mood) =>
                              controller.toggleMood(entry.song, mood),
                        ),
                      );
                    },
                    onOpenNewReleaseChart: () => _selectTab(_newReleaseTab),
                    onRetryNewReleaseChart: () => unawaited(_loadNewReleases()),
                    releaseSongs: discoveryReleaseSongs,
                    releaseLoading: _isReleaseCatalogLoading,
                    releaseErrorMessage: _releaseCatalogErrorMessage,
                    releaseRegion: _discoveryReleaseRegion,
                    onReleaseRegionChanged: (region) =>
                        setState(() => _discoveryReleaseRegion = region),
                    onReleaseTap: (release) {
                      if (!release.playable) return;
                      final queue = discoveryReleaseSongs
                          .where((item) => item.playable)
                          .map((item) => item.song)
                          .toList(growable: false);
                      _selectSong(
                        release.song,
                        queue,
                        origin: const PlaybackOrigin(
                          kind: PlaybackOriginKind.releaseCatalog,
                          label: 'Mới Phát Hành',
                        ),
                      );
                    },
                    likedReleaseSongIds: controller.likedSongs
                        .map((song) => song.id)
                        .toSet(),
                    onReleaseToggleLike: (release) =>
                        controller.toggleLike(release.song),
                    onReleaseAddToQueue: (release) =>
                        _addSongToQueueWithFeedback(controller, release.song),
                    onReleaseOpenDetail: (release) => unawaited(
                      _openSongDetail(
                        release.song,
                        discoveryReleaseSongs
                            .where((item) => item.playable)
                            .map((item) => item.song)
                            .toList(growable: false),
                        canPlay: release.playable,
                      ),
                    ),
                    onReleaseStartRadio: (release) => unawaited(
                      startSongRadioWithFeedback(
                        context,
                        controller,
                        release.song,
                      ),
                    ),
                    onReleaseAddToPlaylist: (release) => unawaited(
                      _showPlaylistPicker(controller, release.song),
                    ),
                    onReleaseShare: (release) => unawaited(
                      _shareSong(release.song, release.catalogSong),
                    ),
                    onRetryReleases: () => unawaited(_loadReleaseCatalog()),
                    tvMode: widget.tvMode,
                  ),
                )
              else if (_selectedTab == _liveRadioTab)
                SliverToBoxAdapter(
                  child: LiveRadioHub(
                    snapshot: _liveRadio,
                    loading: _isLiveRadioLoading,
                    errorMessage: _liveRadioErrorMessage,
                    activeRoomId: controller.currentLiveRadio?.id,
                    isPlaying: controller.isPlaying,
                    onRetry: () => unawaited(_loadLiveRadio()),
                    onRoomTap: _selectLiveRadio,
                    tvMode: widget.tvMode,
                  ),
                )
              else if (_selectedTab == _forYouTab)
                SliverToBoxAdapter(
                  child: ForYouHub(
                    controller: controller,
                    onPlaySongs: (songs) {
                      if (songs.isNotEmpty) _selectSong(songs.first, songs);
                    },
                    onOpenAnalytics: _openAnalytics,
                    onOpenWrapped: _openWrapped,
                  ),
                )
              else if (_selectedTab == _libraryTab)
                SliverToBoxAdapter(
                  child: LibraryHub(
                    controller: controller,
                    selectedPlaylistId: _selectedPlaylistId,
                    section: _librarySection,
                    onSectionChanged: _selectLibrarySection,
                    onSelectPlaylist: _selectLibraryPlaylist,
                    onCreatePlaylist: () => _showCreatePlaylist(controller),
                    onRenamePlaylist: (playlist) =>
                        _showRenamePlaylist(controller, playlist),
                    onDeletePlaylist: (playlist) =>
                        _confirmDeletePlaylist(controller, playlist),
                    onPlaySongs: (songs) {
                      if (songs.isNotEmpty) _selectSong(songs.first, songs);
                    },
                    onExportBackup: () => _exportBackupFile(controller),
                    onImportBackup: () => _importBackupFile(controller),
                    onOpenAnalytics: _openAnalytics,
                    onOpenWrapped: _openWrapped,
                    tvMode: widget.tvMode,
                    onArtistTap: (artist) {
                      _selectTab(_discoveryTab);
                      unawaited(_openArtist(artist));
                    },
                    onCollectionTap: (collection) {
                      _selectTab(_discoveryTab);
                      unawaited(_openCollection(collection));
                    },
                  ),
                )
              else if (!_isLoading &&
                  _errorMessage == null &&
                  _selectedTab == _chartTab &&
                  _searchController.text.isEmpty &&
                  _chartSnapshot.hasRealtimeSeries)
                SliverToBoxAdapter(
                  child: RealtimeChart(
                    snapshot: _chartSnapshot,
                    onPlay: _selectSong,
                    refreshing: _isChartRefreshing,
                    refreshFailed: _chartRefreshErrorMessage != null,
                    onRetry: () =>
                        unawaited(_loadSongs(silent: _songs.isNotEmpty)),
                  ),
                ),
              if (desktopArtistOverview)
                SliverToBoxAdapter(
                  child: ArtistDesktopOverview(
                    latestRelease: artistLatestRelease.collection,
                    releaseLabel: artistLatestRelease.sectionLabel,
                    featuredSongs: desktopArtistSongs,
                    totalSongCount: artistDetail.songs.length,
                    songBuilder: (context, index) => _buildSongTile(
                      controller,
                      desktopArtistSongs,
                      index,
                      compactMetadata: true,
                    ),
                    onReleaseTap: () => unawaited(
                      _openCollection(artistLatestRelease.collection),
                    ),
                    onShowAllSongs: () =>
                        _showArtistSection(OfficialArtistSection.songs),
                  ),
                ),
              if (!_isLoading &&
                  _errorMessage == null &&
                  _selectedTab == _chartTab &&
                  _searchController.text.isEmpty &&
                  (_chartSuggestion != null || _isChartSuggestionLoading))
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    widget.tvMode ? 28 : 12,
                    10,
                    widget.tvMode ? 28 : 12,
                    8,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _buildChartSuggestion(controller),
                  ),
                ),
              if (_selectedTab == _discoveryTab &&
                  selectedCollection != null &&
                  _collectionErrorMessage == null &&
                  !desktopCollectionWorkspace)
                SliverToBoxAdapter(
                  child: _buildCollectionSongSectionHeader(visibleSongs.length),
                )
              else if (_selectedTab == _discoveryTab &&
                  artistSongView &&
                  !desktopArtistOverview)
                SliverToBoxAdapter(
                  child: _buildArtistSongSectionHeader(
                    visibleSongs.length,
                    totalSongCount: fullArtistSongs.length,
                  ),
                )
              else if (_selectedTab == _discoveryTab &&
                  showSearchSongList &&
                  !isReleaseSongView &&
                  !isWeeklySongView)
                SliverToBoxAdapter(
                  child: _buildSearchSongSectionHeader(controller),
                ),
              if (_selectedTab == _chartTab && _isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_selectedTab == _chartTab && _errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorState(
                    message: _errorMessage!,
                    onRetry: _loadSongs,
                  ),
                )
              else if (_selectedTab == _newReleaseTab && _isNewReleaseLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_selectedTab == _newReleaseTab &&
                  _newReleaseErrorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorState(
                    message: _newReleaseErrorMessage!,
                    onRetry: _loadNewReleases,
                  ),
                )
              else if (_selectedTab != _forYouTab &&
                  !desktopCollectionWorkspace &&
                  !desktopArtistOverview &&
                  showSearchSongList &&
                  visibleSongs.isEmpty &&
                  !(selectedCollection != null && _isCollectionLoading) &&
                  !(selectedCollection != null &&
                      _collectionErrorMessage != null) &&
                  !(selectedArtist != null && _isArtistLoading) &&
                  !(_selectedTab == _discoveryTab && _isSearching) &&
                  !(_selectedTab == _discoveryTab &&
                      _searchController.text.trim().isEmpty))
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 46),
                    child: _EmptyState(
                      message: _selectedTab == _libraryTab
                          ? _selectedPlaylist(controller) == null
                                ? 'Thư viện yêu thích đang trống'
                                : 'Playlist này chưa có bài hát'
                          : 'Không tìm thấy bài hát phù hợp',
                    ),
                  ),
                )
              else if (_selectedTab != _forYouTab &&
                  !desktopCollectionWorkspace &&
                  !desktopArtistOverview &&
                  showSearchSongList)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    widget.tvMode
                        ? 28
                        : officialSearchSongRows
                        ? 20
                        : 12,
                    4,
                    widget.tvMode
                        ? 28
                        : officialSearchSongRows
                        ? 20
                        : 12,
                    widget.tvMode ? 48 : 28,
                  ),
                  sliver: widget.tvMode
                      ? SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount:
                                    MediaQuery.sizeOf(context).width >= 1500
                                    ? 2
                                    : 1,
                                mainAxisExtent: 104,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: visibleSongs.length,
                          itemBuilder: (context, index) => _buildSongTile(
                            controller,
                            visibleSongs,
                            index,
                            tvMode: true,
                          ),
                        )
                      : officialSearchSongRows && contentWidth >= 1080
                      ? SliverGrid.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisExtent: 66,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 2,
                              ),
                          itemCount: visibleSongs.length,
                          itemBuilder: (context, index) => _buildSongTile(
                            controller,
                            visibleSongs,
                            index,
                            compactMetadata: true,
                          ),
                        )
                      : SliverList.separated(
                          itemCount: visibleSongs.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            indent: officialSearchSongRows ? 0 : 62,
                            color: Theme.of(context).colorScheme.outlineVariant
                                .withValues(alpha: 0.24),
                          ),
                          itemBuilder: (context, index) => _buildSongTile(
                            controller,
                            visibleSongs,
                            index,
                            compactMetadata: compactContentSongRows,
                          ),
                        ),
                ),
              if (_selectedTab == _discoveryTab &&
                  selectedCollection != null &&
                  !desktopCollectionWorkspace &&
                  _collectionDetail == null &&
                  _collectionErrorMessage != null)
                SliverToBoxAdapter(
                  child: _CollectionErrorState(
                    message: _collectionErrorMessage!,
                    onRetry: () => _openCollection(
                      selectedCollection,
                      preserveDetail: true,
                    ),
                  ),
                ),
              if (_selectedTab == _discoveryTab &&
                  hasSearchQuery &&
                  selectedCollection == null &&
                  selectedArtist == null &&
                  _searchSection == CatalogSearchSection.all &&
                  !_isSearching &&
                  _searchErrorMessage == null &&
                  _searchResult != null &&
                  !_searchResult!.isEmpty)
                SliverToBoxAdapter(
                  child: SearchDiscoverySecondarySections(
                    result: _searchResult!,
                    onArtistTap: (artist) => unawaited(_openArtist(artist)),
                    onCollectionTap: (collection) =>
                        unawaited(_openCollection(collection)),
                    onVideoTap: (video) => unawaited(_openCatalogVideo(video)),
                    onSectionSelected: _selectSearchSection,
                    tvMode: widget.tvMode,
                  ),
                ),
              if (_selectedTab == _discoveryTab &&
                  hasSearchQuery &&
                  selectedCollection == null &&
                  selectedArtist == null &&
                  _searchSection != CatalogSearchSection.all)
                SliverToBoxAdapter(child: _buildSearchPaginationFooter()),
              if (_selectedTab == _discoveryTab &&
                  selectedCollection != null &&
                  !desktopCollectionWorkspace &&
                  _collectionDetail != null)
                SliverToBoxAdapter(
                  child: CollectionDetailCatalog(
                    detail: _collectionDetail!,
                    onCollectionTap: (collection) =>
                        unawaited(_openCollection(collection)),
                    onArtistTap: _openArtistFromCollectionHero,
                    onArtistToggleFollow: (artist) =>
                        _toggleArtistFollowWithFeedback(controller, artist),
                    followedArtistIds: controller.followedArtists
                        .map((artist) => artist.id)
                        .toSet(),
                    onCollectionPlay: (collection) =>
                        unawaited(_quickPlayCollection(collection)),
                    onCollectionToggleSaved: (collection) =>
                        _toggleCollectionSaved(controller, collection),
                    onCollectionShare: (collection) =>
                        unawaited(_shareCollection(collection)),
                    savedCollectionIds: controller.savedCollections
                        .map((collection) => collection.id)
                        .toSet(),
                    quickPlayingCollectionId: _quickPlayingCollectionId,
                    tvMode: widget.tvMode,
                  ),
                ),
              if (_selectedTab == _chartTab &&
                  !_isLoading &&
                  _errorMessage == null &&
                  !_showAllChartSongs &&
                  _songs.length > _chartPreviewSongCount)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      widget.tvMode ? 28 : 12,
                      0,
                      widget.tvMode ? 28 : 12,
                      widget.tvMode ? 52 : 32,
                    ),
                    child: Center(
                      child: OutlinedButton(
                        key: const ValueKey('chart-show-top-100'),
                        onPressed: () =>
                            setState(() => _showAllChartSongs = true),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(
                            widget.tvMode ? 220 : 164,
                            widget.tvMode ? 56 : 44,
                          ),
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurface,
                          side: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.58),
                          ),
                          shape: const StadiumBorder(),
                          textStyle: TextStyle(
                            fontSize: widget.tvMode ? 17 : 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: Text(
                          _songs.length >= 100
                              ? 'Xem top 100'
                              : 'Xem tất cả (${_songs.length})',
                        ),
                      ),
                    ),
                  ),
                ),
              if (_selectedTab == _discoveryTab &&
                  selectedArtist != null &&
                  _artistDetail != null &&
                  _artistSection != OfficialArtistSection.songs)
                SliverToBoxAdapter(
                  child: ArtistProfileCatalog(
                    detail: _artistDetail!,
                    view: switch (_artistSection) {
                      OfficialArtistSection.singles =>
                        ArtistProfileCatalogView.singles,
                      OfficialArtistSection.videos =>
                        ArtistProfileCatalogView.videos,
                      OfficialArtistSection.profile ||
                      OfficialArtistSection.songs =>
                        ArtistProfileCatalogView.profile,
                    },
                    onShowAllSingles: () =>
                        _showArtistSection(OfficialArtistSection.singles),
                    onShowAllVideos: () =>
                        _showArtistSection(OfficialArtistSection.videos),
                    onCollectionTap: (collection) =>
                        unawaited(_openCollection(collection)),
                    onCollectionPlay: (collection) =>
                        unawaited(_quickPlayCollection(collection)),
                    onCollectionToggleSaved: (collection) =>
                        _toggleCollectionSaved(controller, collection),
                    onCollectionShare: (collection) =>
                        unawaited(_shareCollection(collection)),
                    savedCollectionIds: controller.savedCollections
                        .map((collection) => collection.id)
                        .toSet(),
                    quickPlayingCollectionId: _quickPlayingCollectionId,
                    onArtistTap: (artist) => unawaited(_openArtist(artist)),
                    onArtistToggleFollow: (artist) =>
                        _toggleArtistFollowWithFeedback(controller, artist),
                    followedArtistIds: controller.followedArtists
                        .map((artist) => artist.id)
                        .toSet(),
                    onVideoTap: (video) => unawaited(_openCatalogVideo(video)),
                    tvMode: widget.tvMode,
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.paddingOf(context).bottom + 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopCollectionWorkspace(
    MusicPlayerController controller,
    CatalogCollection collection,
    List<Song> visibleSongs, {
    required double availableWidth,
  }) {
    final detail = _collectionDetail;
    final catalogSongs = detail?.songs ?? const <CatalogSong>[];
    final playbackEnabled = detail?.catalogPlaybackEnabled == true;
    final playable = playbackEnabled
        ? catalogSongs.where((song) => song.playable).toList(growable: false)
        : const <CatalogSong>[];
    final shuffleCollection = collection.kind == CatalogCollectionKind.playlist;
    final showAlbumColumn = collection.kind == CatalogCollectionKind.playlist;
    final horizontalPadding = availableWidth < 900 ? 16.0 : 20.0;
    final workspaceWidth = availableWidth - horizontalPadding * 2;
    final sidebarWidth = workspaceWidth >= 1120
        ? 320.0
        : workspaceWidth >= 900
        ? 280.0
        : 250.0;
    final songTableWidth = workspaceWidth - sidebarWidth;
    final compactRows = songTableWidth < 780;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 36),
      sliver: SliverCrossAxisGroup(
        slivers: [
          SliverConstrainedCrossAxis(
            maxExtent: sidebarWidth,
            sliver: SliverToBoxAdapter(
              child: CollectionDetailHero(
                collection: collection,
                detail: detail,
                loading: _isCollectionLoading,
                layout: CollectionDetailHeroLayout.sidebar,
                isSaved: controller.isCollectionSaved(collection),
                onToggleSave: detail == null
                    ? null
                    : () => _toggleCollectionSaved(controller, collection),
                onShare: collection.externalUrl.isEmpty
                    ? null
                    : () => unawaited(_shareCollection(collection)),
                onArtistTap: _openArtistFromCollectionHero,
                shufflePlay: shuffleCollection,
                onPlay: playable.isEmpty
                    ? null
                    : () {
                        controller.setShuffleEnabled(shuffleCollection);
                        _openHighlightedSong(playable.first);
                      },
              ),
            ),
          ),
          SliverCrossAxisExpanded(
            flex: 1,
            sliver: SliverMainAxisGroup(
              slivers: [
                if (_collectionErrorMessage == null || detail != null)
                  SliverToBoxAdapter(
                    child: CollectionDetailDesktopOverview(
                      detail: detail,
                      loading: _isCollectionLoading,
                    ),
                  ),
                if (detail != null && _collectionErrorMessage != null)
                  SliverToBoxAdapter(
                    child: _CollectionErrorState(
                      message: _collectionErrorMessage!,
                      compact: true,
                      onRetry: () =>
                          _openCollection(collection, preserveDetail: true),
                    ),
                  ),
                if ((_collectionErrorMessage == null || detail != null) &&
                    !(_isCollectionLoading && detail == null))
                  SliverToBoxAdapter(
                    child: _buildDesktopCollectionSongTableHeader(
                      visibleSongs.length,
                      compact: compactRows,
                      showAlbum: showAlbumColumn,
                    ),
                  ),
                if (detail == null && _collectionErrorMessage != null)
                  SliverToBoxAdapter(
                    child: _CollectionErrorState(
                      message: _collectionErrorMessage!,
                      onRetry: () =>
                          _openCollection(collection, preserveDetail: true),
                    ),
                  )
                else if (_isCollectionLoading && detail == null)
                  const SliverToBoxAdapter(
                    child: SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (visibleSongs.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: _EmptyState(
                        message: 'Tuyển tập chưa có bài hát khả dụng',
                      ),
                    ),
                  )
                else
                  SliverList.separated(
                    itemCount: visibleSongs.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: 62,
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.24),
                    ),
                    itemBuilder: (context, index) => _buildSongTile(
                      controller,
                      visibleSongs,
                      index,
                      compactMetadata: compactRows,
                      hideAlbumMetadata: !showAlbumColumn,
                      plainTrackNumber: showAlbumColumn ? null : index + 1,
                    ),
                  ),
                if (detail != null)
                  SliverToBoxAdapter(
                    child: CollectionDetailCatalog(
                      detail: detail,
                      onCollectionTap: (target) =>
                          unawaited(_openCollection(target)),
                      onArtistTap: _openArtistFromCollectionHero,
                      onArtistToggleFollow: (artist) =>
                          _toggleArtistFollowWithFeedback(controller, artist),
                      followedArtistIds: controller.followedArtists
                          .map((artist) => artist.id)
                          .toSet(),
                      onCollectionPlay: (target) =>
                          unawaited(_quickPlayCollection(target)),
                      onCollectionToggleSaved: (target) =>
                          _toggleCollectionSaved(controller, target),
                      onCollectionShare: (target) =>
                          unawaited(_shareCollection(target)),
                      savedCollectionIds: controller.savedCollections
                          .map((collection) => collection.id)
                          .toSet(),
                      quickPlayingCollectionId: _quickPlayingCollectionId,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopCollectionSongTableHeader(
    int songCount, {
    required bool compact,
    required bool showAlbum,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = TextStyle(
      color: scheme.onSurfaceVariant,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.9,
    );
    return Padding(
      key: const ValueKey('collection-desktop-table-header'),
      padding: const EdgeInsets.fromLTRB(10, 22, 10, 8),
      child: Row(
        children: [
          Expanded(child: Text('BÀI HÁT · $songCount', style: labelStyle)),
          if (!compact && showAlbum) ...[
            SizedBox(width: 220, child: Text('ALBUM', style: labelStyle)),
            const SizedBox(width: 14),
          ],
          SizedBox(
            width: 44,
            child: Text(
              'THỜI GIAN',
              textAlign: TextAlign.end,
              style: labelStyle,
            ),
          ),
          SizedBox(width: compact ? 104 : 144),
        ],
      ),
    );
  }

  Widget _buildSongTile(
    MusicPlayerController controller,
    List<Song> visibleSongs,
    int index, {
    bool tvMode = false,
    bool compactMetadata = false,
    bool hideAlbumMetadata = false,
    int? plainTrackNumber,
  }) {
    final song = visibleSongs[index];
    final catalogSong = _catalogSongFor(song);
    final newReleaseEntry = _selectedTab == _newReleaseTab
        ? _newReleaseEntryFor(song)
        : null;
    final weeklyEntry =
        _selectedTab == _discoveryTab &&
            _catalogBrowseView == _CatalogBrowseView.weekly
        ? _weeklyEntryFor(song)
        : null;
    final releaseSong =
        _selectedTab == _discoveryTab &&
            _catalogBrowseView == _CatalogBrowseView.releases
        ? _releaseSongFor(song)
        : null;
    final officialSearchRow =
        _selectedTab == _discoveryTab &&
        _searchController.text.trim().isNotEmpty &&
        _selectedArtist == null &&
        _selectedCollection == null &&
        _catalogBrowseView == _CatalogBrowseView.discovery &&
        (_searchSection == CatalogSearchSection.all ||
            _searchSection == CatalogSearchSection.songs);
    final collectionPlaybackEnabled = _selectedCollection == null
        ? true
        : _collectionDetail?.catalogPlaybackEnabled == true;
    final surfacePlaybackEnabled =
        collectionPlaybackEnabled &&
        (!officialSearchRow || _activeSearchPlaybackEnabled);
    final collectionKind =
        _collectionDetail?.collection.kind ?? _selectedCollection?.kind;
    final effectiveHideAlbumMetadata =
        hideAlbumMetadata || collectionKind == CatalogCollectionKind.album;
    final effectiveTrackNumber =
        plainTrackNumber ??
        (collectionKind == CatalogCollectionKind.album ? index + 1 : null);
    final canPlay =
        surfacePlaybackEnabled &&
        (_selectedCollection == null
            ? catalogSong?.playable ?? !officialSearchRow
            : catalogSong?.playable == true);
    final chartIndex = _songs.indexWhere((item) => item.id == song.id);
    final chartMetadata = _selectedTab == _chartTab
        ? _chartSnapshot.songMetadata[song.id]
        : null;
    final collectionDetail = _selectedCollection == null
        ? null
        : _collectionDetail;
    final isCurrentCollectionSong =
        collectionDetail?.songs.any((item) => item.song.id == song.id) == true;
    final currentCollectionAlbum =
        isCurrentCollectionSong &&
            collectionDetail!.collection.kind == CatalogCollectionKind.album
        ? collectionDetail.collection
        : null;
    final rowAlbum =
        catalogSong?.album ?? chartMetadata?.album ?? currentCollectionAlbum;
    final rowArtists = catalogSong?.artists.isNotEmpty == true
        ? catalogSong!.artists
        : chartMetadata?.artists ?? const <CatalogArtist>[];
    final rowDuration =
        catalogSong?.duration != null && catalogSong!.duration > Duration.zero
        ? catalogSong.duration
        : weeklyEntry?.catalogSong.duration ??
              releaseSong?.catalogSong.duration ??
              newReleaseEntry?.catalogSong.duration ??
              chartMetadata?.duration ??
              Duration.zero;
    final rank =
        weeklyEntry?.rank ??
        newReleaseEntry?.rank ??
        (catalogSong == null
            ? (chartIndex >= 0 ? chartIndex + 1 : index + 1)
            : null);
    final playableQueue = _selectedTab == _chartTab
        ? _songs
        : catalogSong == null
        ? (surfacePlaybackEnabled ? visibleSongs : const <Song>[])
        : visibleSongs
              .where(
                (item) =>
                    surfacePlaybackEnabled &&
                    (_catalogSongFor(item)?.playable ?? !officialSearchRow),
              )
              .toList(growable: false);
    void addToQueue() {
      if (!canPlay) {
        _showUnavailable(song);
        return;
      }
      final didAdd = controller.addToQueue(song);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            didAdd
                ? 'Đã thêm ${song.displayTitle} vào hàng đợi'
                : '${song.displayTitle} đã ở vị trí tiếp theo',
          ),
        ),
      );
    }

    final tile = _SongTile(
      key: ValueKey(song.id),
      song: song,
      rank: rank,
      rankChange:
          weeklyEntry?.rankChange ??
          newReleaseEntry?.rankChange ??
          chartMetadata?.rankChange,
      albumTitle:
          rowAlbum?.title ??
          weeklyEntry?.albumTitle ??
          newReleaseEntry?.albumTitle ??
          chartMetadata?.albumTitle ??
          '',
      duration: rowDuration,
      releasedAt: releaseSong?.releasedAt ?? newReleaseEntry?.releasedAt,
      dense:
          officialSearchRow ||
          weeklyEntry != null ||
          newReleaseEntry != null ||
          releaseSong != null,
      showLeading: !officialSearchRow,
      padDurationMinutes: officialSearchRow,
      hasLyrics: catalogSong?.hasLyrics ?? false,
      canPlay: canPlay,
      isLiked: controller.isLiked(song),
      isCurrent: controller.currentSong?.id == song.id,
      moods: controller.moodsFor(song),
      onLike: () => controller.toggleLike(song),
      onToggleMood: (mood) => controller.toggleMood(song, mood),
      onAddToQueue: addToQueue,
      onStartRadio: () => startSongRadioWithFeedback(context, controller, song),
      onAddToPlaylist: () => _showPlaylistPicker(controller, song),
      onShare: () => _shareSong(song, catalogSong),
      artists: rowArtists,
      onOpenDetail: () =>
          unawaited(_openSongDetail(song, playableQueue, canPlay: canPlay)),
      onArtistTap: rowArtists.isNotEmpty
          ? (artist) {
              if (isCurrentCollectionSong) {
                _openArtistFromCollectionHero(artist);
              } else if (_selectedArtist?.id == artist.id) {
                _scrollContentToStart();
              } else {
                _selectTab(_discoveryTab);
                unawaited(_openArtist(artist));
              }
            }
          : null,
      onAlbumTap: rowAlbum == null || rowAlbum.id == _selectedCollection?.id
          ? null
          : () {
              _selectTab(_discoveryTab);
              unawaited(_openCollection(rowAlbum));
            },
      onTap: canPlay
          ? () => _selectSong(song, playableQueue)
          : () => _showUnavailable(song),
      tvMode: tvMode,
      compactMetadata: compactMetadata,
      hideAlbumMetadata: effectiveHideAlbumMetadata,
      plainTrackNumber: effectiveTrackNumber,
      autofocus: tvMode && index == 0,
    );
    if (tvMode) return tile;
    return Dismissible(
      key: ValueKey('swipe-queue-${song.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        addToQueue();
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        decoration: BoxDecoration(
          color: ZingColors.lime.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(Icons.playlist_add_rounded, color: ZingColors.lime),
            SizedBox(width: 8),
            Text(
              'THÊM VÀO HÀNG ĐỢI',
              style: TextStyle(
                color: ZingColors.lime,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
      child: tile,
    );
  }

  Widget _buildChartSuggestion(MusicPlayerController controller) {
    final entry = _chartSuggestion;
    if (entry == null) {
      return Semantics(
        key: const ValueKey('chart-suggestion-loading'),
        label: 'Đang tải bài hát gợi ý từ Zing MP3',
        liveRegion: true,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.tvMode ? 22 : 16,
            vertical: widget.tvMode ? 18 : 13,
          ),
          decoration: BoxDecoration(
            color: ZingColors.purple.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(widget.tvMode ? 18 : 12),
            border: Border.all(
              color: ZingColors.purpleBright.withValues(alpha: 0.16),
            ),
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text(
                'Đang tải gợi ý từ Zing MP3…',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }
    final song = entry.song;
    final artists = entry.artists;
    final album = entry.album;
    final queue = <Song>[song, ..._songs.where((item) => item.id != song.id)];
    void addToQueue() {
      final didAdd = controller.addToQueue(song);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            didAdd
                ? 'Đã thêm ${song.displayTitle} vào hàng đợi'
                : '${song.displayTitle} đã ở vị trí tiếp theo',
          ),
        ),
      );
    }

    return Column(
      key: const ValueKey('chart-suggestion-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SongTile(
          key: ValueKey('chart-suggestion-${song.id}'),
          song: song,
          rank: null,
          rankChange: null,
          leadingLabel: 'Gợi ý',
          albumTitle: album?.title ?? '',
          duration: entry.duration,
          releasedAt: null,
          dense: true,
          hasLyrics: entry.hasLyrics,
          canPlay: true,
          isLiked: controller.isLiked(song),
          isCurrent: controller.currentSong?.id == song.id,
          moods: controller.moodsFor(song),
          onLike: () => controller.toggleLike(song),
          onToggleMood: (mood) => controller.toggleMood(song, mood),
          onAddToQueue: addToQueue,
          onStartRadio: () =>
              startSongRadioWithFeedback(context, controller, song),
          onAddToPlaylist: () => _showPlaylistPicker(controller, song),
          onShare: () => _shareSong(song, entry),
          artists: artists,
          onOpenDetail: () =>
              unawaited(_openSongDetail(song, queue, canPlay: true)),
          onArtistTap: artists.isEmpty
              ? null
              : (artist) {
                  _selectTab(_discoveryTab);
                  unawaited(_openArtist(artist));
                },
          onAlbumTap: album == null
              ? null
              : () {
                  _selectTab(_discoveryTab);
                  unawaited(_openCollection(album));
                },
          onTap: () => _selectSong(song, queue),
          tvMode: widget.tvMode,
        ),
        if (_isChartSuggestionLoading)
          const LinearProgressIndicator(
            key: ValueKey('chart-suggestion-refreshing'),
            minHeight: 2,
          )
        else if (_chartSuggestionErrorMessage != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('chart-suggestion-retry'),
              onPressed: () =>
                  unawaited(_loadChartSuggestion(preserveSuggestion: true)),
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Thử tải lại gợi ý'),
            ),
          ),
      ],
    );
  }

  NavigationRail _buildNavigationRail({
    required bool tvMode,
    required bool extended,
  }) => NavigationRail(
    selectedIndex: _navigationTabs.indexOf(_selectedTab),
    onDestinationSelected: (index) => _selectTab(_navigationTabs[index]),
    extended: extended,
    minWidth: tvMode ? 96 : 72,
    minExtendedWidth: tvMode ? 220 : 238,
    groupAlignment: -1,
    labelType: extended
        ? NavigationRailLabelType.none
        : NavigationRailLabelType.all,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? ZingColors.sidebar
        : Theme.of(context).colorScheme.surface,
    leading: Padding(
      padding: EdgeInsets.fromLTRB(extended ? 24 : 8, 22, 8, 32),
      child: Align(
        alignment: extended ? Alignment.centerLeft : Alignment.center,
        child: Column(
          crossAxisAlignment: extended
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Text(
              extended ? '#zingChart' : '#Z',
              style: const TextStyle(
                color: ZingColors.purpleBright,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
              ),
            ),
            if (extended) ...[
              const SizedBox(height: 2),
              Text(
                'MUSIC CLIENT',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.1,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    trailing: tvMode
        ? null
        : Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: IconButton(
                  tooltip: 'Hiện bảng đang phát',
                  onPressed: () =>
                      _openDesktopPlayerPanel(DesktopPlaybackPanelTab.queue),
                  icon: const Icon(Icons.queue_music_rounded),
                ),
              ),
            ),
          ),
    destinations: const [
      NavigationRailDestination(
        icon: Icon(Icons.insights_outlined),
        selectedIcon: Icon(Icons.insights_rounded),
        label: Text('#zingchart'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.explore_outlined),
        selectedIcon: Icon(Icons.explore_rounded),
        label: Text('Khám phá'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.radio_outlined),
        selectedIcon: Icon(Icons.radio_rounded),
        label: Text('Phòng Nhạc'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.new_releases_outlined),
        selectedIcon: Icon(Icons.new_releases_rounded),
        label: Text('BXH Nhạc Mới'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.auto_awesome_outlined),
        selectedIcon: Icon(Icons.auto_awesome_rounded),
        label: Text('Dành cho bạn'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.library_music_outlined),
        selectedIcon: Icon(Icons.library_music_rounded),
        label: Text('Thư viện'),
      ),
    ],
  );

  Widget _buildMobileNavigation(double width) {
    final effectiveTab = _selectedTab == _newReleaseTab
        ? _discoveryTab
        : _selectedTab;
    final selectedIndex = _mobileNavigationTabs.indexOf(effectiveTab);
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: width < 350 ? 9.5 : 10.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: -0.15,
          );
        }),
      ),
      child: NavigationBar(
        key: const ValueKey('mobile-primary-navigation'),
        height: 72,
        selectedIndex: selectedIndex < 0 ? 2 : selectedIndex,
        onDestinationSelected: (index) =>
            _selectTab(_mobileNavigationTabs[index]),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: ZingColors.purpleBright.withValues(alpha: 0.24),
        destinations: const [
          NavigationDestination(
            key: ValueKey('mobile-nav-library'),
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music_rounded),
            label: 'Thư viện',
          ),
          NavigationDestination(
            key: ValueKey('mobile-nav-discovery'),
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Khám phá',
          ),
          NavigationDestination(
            key: ValueKey('mobile-nav-chart'),
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: '#zingchart',
          ),
          NavigationDestination(
            key: ValueKey('mobile-nav-radio'),
            icon: Icon(Icons.radio_outlined),
            selectedIcon: Icon(Icons.radio_rounded),
            label: 'Radio',
          ),
          NavigationDestination(
            key: ValueKey('mobile-nav-for-you'),
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }

  DesktopCatalogDestination get _desktopCatalogDestination {
    if (_selectedTab == _discoveryTab) {
      return switch (_catalogBrowseView) {
        _CatalogBrowseView.hubs => DesktopCatalogDestination.hubs,
        _CatalogBrowseView.top100 => DesktopCatalogDestination.top100,
        _ => DesktopCatalogDestination.discovery,
      };
    }
    return switch (_selectedTab) {
      _chartTab => DesktopCatalogDestination.chart,
      _newReleaseTab => DesktopCatalogDestination.newReleaseChart,
      _forYouTab => DesktopCatalogDestination.forYou,
      _libraryTab => DesktopCatalogDestination.library,
      _liveRadioTab => DesktopCatalogDestination.liveRadio,
      _ => DesktopCatalogDestination.discovery,
    };
  }

  void _selectDesktopCatalogDestination(DesktopCatalogDestination destination) {
    switch (destination) {
      case DesktopCatalogDestination.library:
        _selectTab(_libraryTab);
      case DesktopCatalogDestination.discovery:
        _selectTab(_discoveryTab);
      case DesktopCatalogDestination.chart:
        _selectTab(_chartTab);
      case DesktopCatalogDestination.liveRadio:
        _selectTab(_liveRadioTab);
      case DesktopCatalogDestination.newReleaseChart:
        _selectTab(_newReleaseTab);
      case DesktopCatalogDestination.hubs:
        if (_selectedTab != _discoveryTab) _selectTab(_discoveryTab);
        _openHubHome();
      case DesktopCatalogDestination.top100:
        if (_selectedTab != _discoveryTab) _selectTab(_discoveryTab);
        _openTop100();
      case DesktopCatalogDestination.forYou:
        _selectTab(_forYouTab);
    }
  }

  void _selectTab(int index) {
    final isSameRoot =
        _selectedTab == index &&
        _selectedArtist == null &&
        _selectedCollection == null &&
        _selectedHub == null &&
        _catalogBrowseView == _CatalogBrowseView.discovery;
    if (isSameRoot) return;
    _recordNavigationOrigin();
    _hubRequestId++;
    _weeklyRequestId++;
    if (index != _discoveryTab) {
      _searchDebounce?.cancel();
      _searchSuggestionDebounce?.cancel();
      _searchRequestId++;
      _searchPageRequestId++;
      _searchSuggestionRequestId++;
      _hideSearchSuggestionOverlay();
    }
    setState(() {
      _selectedTab = index;
      _selectedArtist = null;
      _artistResult = null;
      _artistDetail = null;
      _artistSection = OfficialArtistSection.profile;
      _artistErrorMessage = null;
      _isArtistLoading = false;
      _selectedCollection = null;
      _collectionDetail = null;
      _collectionErrorMessage = null;
      _collectionOriginArtist = null;
      _collectionOriginArtistDetail = null;
      _collectionOriginArtistResult = null;
      _collectionOriginArtistSection = OfficialArtistSection.profile;
      _isCollectionLoading = false;
      _catalogBrowseView = _CatalogBrowseView.discovery;
      _selectedHub = null;
      _hubDetail = null;
      _hubDetailErrorMessage = null;
      _isHubDetailLoading = false;
      if (index != _discoveryTab) {
        _searchController.clear();
        _lastObservedSearchQuery = '';
        _lastCommittedSearchState = null;
        _searchResult = null;
        _aggregateSearchResult = null;
        _searchPages = const {};
        _searchPaginationUnavailable = const {};
        _searchErrorMessage = null;
        _isSearching = false;
        _isSearchPageLoading = false;
        _searchPageErrorMessage = null;
        _searchSuggestionSnapshot = null;
        _searchSuggestionErrorMessage = null;
        _isLoadingSearchSuggestions = false;
        _highlightedSearchSuggestion = -1;
      }
    });
    if (index == _discoveryTab) _ensureDiscoveryLoaded();
    if (index == _chartTab) {
      _ensureChartSuggestionLoaded();
      _refreshChartIfStale();
    }
    if (index == _newReleaseTab &&
        _newReleaseChart.entries.isEmpty &&
        !_isNewReleaseLoading) {
      unawaited(_loadNewReleases());
    }
    if (index == _liveRadioTab && _liveRadio.isEmpty && !_isLiveRadioLoading) {
      unawaited(_loadLiveRadio());
    }
  }

  void _selectLibrarySection(LibrarySection section) {
    if (_librarySection == section &&
        (section == LibrarySection.playlists || _selectedPlaylistId == null)) {
      return;
    }
    _recordNavigationOrigin();
    setState(() {
      _librarySection = section;
      if (section != LibrarySection.playlists) {
        _selectedPlaylistId = null;
      }
    });
  }

  void _selectLibraryPlaylist(String? playlistId) {
    final section = playlistId == null
        ? LibrarySection.songs
        : LibrarySection.playlists;
    if (_selectedPlaylistId == playlistId && _librarySection == section) return;
    _recordNavigationOrigin();
    setState(() {
      _selectedPlaylistId = playlistId;
      _librarySection = section;
      _searchController.clear();
      _lastObservedSearchQuery = '';
    });
    _scrollContentToStart();
  }

  void _closeLocalPlaylist() {
    if (_selectedPlaylistId == null) return;
    _replaceNextRouteReport = true;
    setState(() {
      _selectedPlaylistId = null;
      _librarySection = LibrarySection.playlists;
      _searchController.clear();
      _lastObservedSearchQuery = '';
    });
    _scrollContentToStart();
  }

  void _focusSearch() {
    _enterDiscovery();
    _searchFocusNode.requestFocus();
  }

  void _enterDiscovery() {
    if (_selectedTab != _discoveryTab) {
      _selectTab(_discoveryTab);
    } else {
      if (_catalogBrowseView != _CatalogBrowseView.discovery ||
          _selectedHub != null) {
        _recordNavigationOrigin();
        _hubRequestId++;
        _weeklyRequestId++;
        setState(() {
          _catalogBrowseView = _CatalogBrowseView.discovery;
          _selectedHub = null;
          _hubDetail = null;
          _hubDetailErrorMessage = null;
          _isHubDetailLoading = false;
        });
      }
      _ensureDiscoveryLoaded();
    }
  }

  void _ensureDiscoveryLoaded() {
    if (_discoveryCategories.isEmpty && !_isDiscoveryCategoriesLoading) {
      unawaited(_loadDiscoveryCategories());
    }
    if (_discoveryHome.isEmpty && !_isDiscoveryLoading) {
      unawaited(_loadDiscoveryHome(categoryId: _selectedDiscoveryCategoryId));
    }
    if (_officialDiscoveryRecommendations.isEmpty &&
        !_isDiscoveryRecommendationsLoading) {
      unawaited(_loadDiscoveryRecommendations());
    }
    if (_selectedDiscoveryCategoryId == '-1' &&
        _releaseCatalog.isEmpty &&
        !_isReleaseCatalogLoading) {
      unawaited(_loadReleaseCatalog());
    }
    if (_selectedDiscoveryCategoryId == '-1' &&
        _newReleaseChart.entries.isEmpty &&
        !_isNewReleaseLoading) {
      unawaited(_loadNewReleases());
    }
  }

  bool _isEditingText() =>
      FocusManager.instance.primaryFocus?.context?.widget is EditableText;

  void _openAnalytics() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AnalyticsDashboardScreen()),
    );
  }

  void _openWrapped() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WrappedScreen(tvMode: widget.tvMode),
      ),
    );
  }

  Future<void> _openSettings(MusicPlayerController controller) =>
      showAppSettings(context, controller: controller, tvMode: widget.tvMode);

  void _playLocalPlaylist(
    MusicPlayerController controller,
    LocalPlaylist playlist, {
    required bool shuffle,
  }) {
    if (playlist.songs.isEmpty) return;
    controller.setShuffleEnabled(shuffle);
    _selectSong(
      playlist.songs.first,
      playlist.songs,
      origin: PlaybackOrigin(
        kind: PlaybackOriginKind.playlist,
        label: playlist.name,
      ),
    );
  }

  SongActionMenuConfiguration _localPlaylistSongActions(
    MusicPlayerController controller,
    LocalPlaylist playlist,
    Song song,
  ) => SongActionMenuConfiguration(
    isLiked: controller.isLiked(song),
    moods: controller.moodsFor(song),
    handlers: SongActionHandlers(
      onPlay: () => _selectSong(
        song,
        playlist.songs,
        origin: PlaybackOrigin(
          kind: PlaybackOriginKind.playlist,
          label: playlist.name,
        ),
      ),
      onOpenDetail: () =>
          unawaited(_openSongDetail(song, playlist.songs, canPlay: true)),
      onAddToQueue: () => _addSongToQueueWithFeedback(controller, song),
      onStartRadio: () =>
          unawaited(startSongRadioWithFeedback(context, controller, song)),
      onAddToPlaylist: () => unawaited(_showPlaylistPicker(controller, song)),
      onRemoveFromPlaylist: () =>
          _removePlaylistSongWithUndo(controller, playlist.id, song),
      onShare: () => unawaited(_shareSong(song, _catalogSongFor(song))),
      onToggleLike: () => controller.toggleLike(song),
      onToggleMood: (mood) => controller.toggleMood(song, mood),
    ),
  );

  void _removePlaylistSongWithUndo(
    MusicPlayerController controller,
    String playlistId,
    Song song,
  ) {
    final removal = controller.removeSongFromPlaylist(playlistId, song.id);
    if (removal == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Đã xóa ${song.displayTitle} khỏi playlist'),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () {
              if (!controller.restoreSongToPlaylist(removal) && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Không thể hoàn tác thay đổi này'),
                  ),
                );
              }
            },
          ),
        ),
      );
  }

  Future<void> _showCreatePlaylist(MusicPlayerController controller) async {
    final playlist = await _promptAndCreatePlaylist(controller);
    if (playlist == null || !mounted) return;
    final alreadyInLibrary = _selectedTab == _libraryTab;
    if (!alreadyInLibrary) {
      _selectTab(_libraryTab);
    } else {
      _recordNavigationOrigin();
    }
    setState(() {
      _librarySection = LibrarySection.playlists;
      _selectedPlaylistId = playlist.id;
    });
    _scrollContentToStart();
  }

  Future<LocalPlaylist?> _promptAndCreatePlaylist(
    MusicPlayerController controller, {
    List<Song> initialSongs = const [],
  }) async {
    final name = await _promptPlaylistName(title: 'Tạo playlist mới');
    if (name == null) return null;
    try {
      return controller.createPlaylist(name, initialSongs: initialSongs);
    } on ArgumentError catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
      return null;
    }
  }

  Future<void> _showRenamePlaylist(
    MusicPlayerController controller,
    LocalPlaylist playlist,
  ) async {
    final name = await _promptPlaylistName(
      title: 'Đổi tên playlist',
      initialValue: playlist.name,
    );
    if (name == null) return;
    try {
      controller.renamePlaylist(playlist.id, name);
    } on ArgumentError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    }
  }

  Future<String?> _promptPlaylistName({
    required String title,
    String initialValue = '',
  }) => showDialog<String>(
    context: context,
    builder: (_) =>
        _PlaylistNameDialog(title: title, initialValue: initialValue),
  );

  Future<void> _confirmDeletePlaylist(
    MusicPlayerController controller,
    LocalPlaylist playlist,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa playlist?'),
        content: Text(
          '“${playlist.name}” sẽ bị xóa khỏi thiết bị. Bài hát gốc không bị ảnh hưởng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    controller.deletePlaylist(playlist.id);
    if (mounted && _selectedPlaylistId == playlist.id) {
      _backHistory.removeWhere(
        (state) => state.selectedPlaylistId == playlist.id,
      );
      _forwardHistory.removeWhere(
        (state) => state.selectedPlaylistId == playlist.id,
      );
      _replaceNextRouteReport = true;
      setState(() {
        _selectedPlaylistId = null;
        _librarySection = LibrarySection.playlists;
      });
    }
  }

  Future<void> _showPlaylistPicker(
    MusicPlayerController controller,
    Song song,
  ) async {
    final selection = await showModalBottomSheet<_PlaylistPickerSelection>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
          ),
          child: ListView(
            key: const ValueKey('playlist-picker'),
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
            children: [
              const ListTile(
                title: Text(
                  'Thêm vào playlist',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              ListTile(
                key: const ValueKey('playlist-picker-create'),
                leading: const CircleAvatar(
                  backgroundColor: ZingColors.purple,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.add_rounded),
                ),
                title: const Text(
                  'Tạo playlist mới',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Tạo và thêm bài hát ngay'),
                onTap: () => Navigator.pop(sheetContext, (
                  create: true,
                  playlistId: null,
                )),
              ),
              const Divider(height: 16),
              ...controller.playlists.map((playlist) {
                final alreadyAdded = playlist.songs.any(
                  (item) => item.id == song.id,
                );
                return ListTile(
                  key: ValueKey('playlist-picker-item-${playlist.id}'),
                  enabled: !alreadyAdded,
                  leading: const Icon(Icons.queue_music_rounded),
                  title: Text(playlist.name),
                  subtitle: Text('${playlist.songs.length} bài hát'),
                  trailing: alreadyAdded
                      ? const Icon(Icons.check_rounded, color: ZingColors.lime)
                      : const Icon(Icons.add_rounded),
                  onTap: alreadyAdded
                      ? null
                      : () => Navigator.pop(sheetContext, (
                          create: false,
                          playlistId: playlist.id,
                        )),
                );
              }),
            ],
          ),
        ),
      ),
    );
    if (selection == null || !mounted) return;
    if (selection.create) {
      final playlist = await _promptAndCreatePlaylist(
        controller,
        initialSongs: [song],
      );
      if (playlist == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã tạo ${playlist.name} và thêm ${song.displayTitle}'),
        ),
      );
      return;
    }
    final playlistId = selection.playlistId;
    if (playlistId == null) return;
    final added = controller.addSongToPlaylist(playlistId, song);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? 'Đã thêm ${song.displayTitle} vào playlist'
              : '${song.displayTitle} đã có trong playlist',
        ),
      ),
    );
  }

  Future<void> _showExportBackup(MusicPlayerController controller) async {
    final json = controller.exportLibraryJson();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Backup thư viện JSON'),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sao chép nội dung này vào file có đuôi .json. File không chứa nhạc hoặc URL stream.',
              ),
              const SizedBox(height: 14),
              Container(
                constraints: const BoxConstraints(maxHeight: 260),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    json,
                    key: const ValueKey('backup-json-content'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Đóng'),
          ),
          FilledButton.icon(
            key: const ValueKey('copy-backup-json-button'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép backup JSON')),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Sao chép JSON'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackupFile(MusicPlayerController controller) async {
    final json = controller.exportLibraryJson();
    final date = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    try {
      final exported = await _backupFileService.exportJson(
        json,
        fileName: 'zingchart-library-$date.json',
      );
      if (exported && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xuất backup thư viện')),
        );
      }
    } catch (_) {
      if (mounted) await _showExportBackup(controller);
    }
  }

  Future<void> _importBackupFile(MusicPlayerController controller) async {
    try {
      final json = await _backupFileService.importJson();
      if (json != null && mounted) {
        await _showImportBackup(controller, initialJson: json);
      }
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    } catch (_) {
      if (mounted) await _showImportBackup(controller);
    }
  }

  Future<void> _showImportBackup(
    MusicPlayerController controller, {
    String initialJson = '',
  }) async {
    final restored = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _ImportBackupDialog(controller: controller, initialJson: initialJson),
    );
    if (restored == true && mounted) {
      setState(() => _selectedPlaylistId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã khôi phục thư viện local')),
      );
    }
  }

  Widget _buildCatalogToolbar(
    MusicPlayerController controller, {
    bool embedded = false,
  }) {
    final refreshAction = _catalogToolbarRefreshAction();
    final showLocalProfile =
        !widget.tvMode && MediaQuery.sizeOf(context).width >= 1100;
    final scheme = Theme.of(context).colorScheme;
    final toolbar = Row(
      children: [
        IconButton.filledTonal(
          key: const ValueKey('catalog-history-back'),
          tooltip: 'Quay lại',
          onPressed: _canUseToolbarBack ? _navigateToolbarBack : null,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 6),
        IconButton.filledTonal(
          key: const ValueKey('catalog-history-forward'),
          tooltip: 'Tiến',
          onPressed: _canNavigateForward ? _navigateForward : null,
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
        const SizedBox(width: 14),
        Expanded(child: _buildSearchField(compact: false)),
        if (refreshAction != null) ...[
          const SizedBox(width: 10),
          IconButton.filledTonal(
            key: const ValueKey('catalog-toolbar-refresh'),
            tooltip: refreshAction.tooltip,
            onPressed: refreshAction.onPressed,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        const SizedBox(width: 6),
        IconButton.filledTonal(
          key: const ValueKey('open-app-settings'),
          tooltip: 'Cài đặt',
          onPressed: () => unawaited(_openSettings(controller)),
          icon: const Icon(Icons.settings_outlined),
        ),
        if (showLocalProfile) ...[
          const SizedBox(width: 6),
          IconButton(
            key: const ValueKey('open-local-profile'),
            tooltip: 'Cá nhân local · không cần tài khoản',
            onPressed: () => _selectTab(_forYouTab),
            style: IconButton.styleFrom(
              minimumSize: const Size.square(44),
              backgroundColor: _selectedTab == _forYouTab
                  ? ZingColors.coral
                  : scheme.surfaceContainerHighest,
              foregroundColor: _selectedTab == _forYouTab
                  ? const Color(0xFF171318)
                  : scheme.onSurface,
              side: BorderSide(
                color: _selectedTab == _forYouTab
                    ? ZingColors.coral
                    : scheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            icon: const Icon(Icons.person_outline_rounded),
          ),
        ],
      ],
    );
    if (embedded) return toolbar;
    return Material(
      key: const ValueKey('pinned-catalog-toolbar'),
      color: scheme.surface.withValues(alpha: 0.98),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.38),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: toolbar,
        ),
      ),
    );
  }

  ({String tooltip, VoidCallback? onPressed})? _catalogToolbarRefreshAction() {
    if (_selectedTab == _chartTab) {
      return (
        tooltip: 'Làm mới bảng xếp hạng',
        onPressed: _isLoading ? null : _loadSongs,
      );
    }
    if (_selectedTab == _newReleaseTab) {
      return (
        tooltip: 'Làm mới BXH Nhạc Mới',
        onPressed: _isNewReleaseLoading ? null : _loadNewReleases,
      );
    }
    if (_selectedTab == _liveRadioTab) {
      return (
        tooltip: 'Làm mới Phòng Nhạc',
        onPressed: _isLiveRadioLoading ? null : _loadLiveRadio,
      );
    }
    if (_selectedTab == _discoveryTab &&
        _catalogBrowseView == _CatalogBrowseView.weekly) {
      return (
        tooltip: 'Làm mới bảng xếp hạng tuần',
        onPressed: _isWeeklyChartLoading
            ? null
            : () => unawaited(_refreshContent()),
      );
    }
    return null;
  }

  Widget _buildHeader({required bool pinCatalogToolbar}) {
    final controller = _playerController;
    final selectedPlaylist = _selectedPlaylist(controller);
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final selectedCollection =
        _collectionDetail?.collection ?? _selectedCollection;
    if (selectedCollection != null) {
      return _buildCollectionHeader(
        controller,
        selectedCollection,
        wide: wide,
        pinCatalogToolbar: pinCatalogToolbar,
      );
    }
    final selectedArtist = _selectedArtist;
    if (selectedArtist != null) {
      return _buildArtistHeader(
        controller,
        selectedArtist,
        wide: wide,
        pinCatalogToolbar: pinCatalogToolbar,
      );
    }
    if (_selectedTab == _discoveryTab &&
        _catalogBrowseView == _CatalogBrowseView.weekly) {
      return _buildWeeklyToolbar(
        controller,
        wide: wide,
        pinCatalogToolbar: pinCatalogToolbar,
      );
    }
    final compactDiscoveryLanding =
        wide &&
        !widget.tvMode &&
        _selectedTab == _discoveryTab &&
        _catalogBrowseView == _CatalogBrowseView.discovery &&
        _selectedHub == null &&
        _searchController.text.trim().isEmpty;
    final hasSearchQuery = _searchController.text.trim().isNotEmpty;
    final discoveryTitle =
        _selectedHub?.title ??
        (hasSearchQuery && _catalogBrowseView == _CatalogBrowseView.discovery
            ? 'Kết Quả Tìm Kiếm'
            : switch (_catalogBrowseView) {
                _CatalogBrowseView.discovery => 'Khám phá',
                _CatalogBrowseView.hubs => 'Chủ đề & Thể loại',
                _CatalogBrowseView.top100 => 'Top 100',
                _CatalogBrowseView.releases => 'Mới Phát Hành',
                _CatalogBrowseView.weekly => 'Bảng Xếp Hạng Tuần',
              });
    final discoverySubtitle =
        hasSearchQuery && _catalogBrowseView == _CatalogBrowseView.discovery
        ? 'TẤT CẢ · BÀI HÁT · PLAYLIST/ALBUM · NGHỆ SĨ/OA · MV'
        : switch (_catalogBrowseView) {
            _CatalogBrowseView.discovery =>
              'BÀI HÁT · NGHỆ SĨ · LỜI BÀI HÁT · MV',
            _CatalogBrowseView.hubs =>
              'QUỐC GIA · TÂM TRẠNG · HOẠT ĐỘNG · THỂ LOẠI',
            _CatalogBrowseView.top100 => 'VIỆT NAM · CHÂU Á · ÂU MỸ · HÒA TẤU',
            _CatalogBrowseView.releases =>
              'BÀI HÁT · ALBUM · CẬP NHẬT LIÊN TỤC',
            _CatalogBrowseView.weekly => 'VIỆT NAM · US-UK · K-POP · THEO TUẦN',
          };
    final titles = [
      '#zingchart',
      discoveryTitle,
      _newReleaseChart.title,
      wide || widget.tvMode ? 'Dành cho bạn' : 'Cá nhân',
      selectedPlaylist?.name ?? 'Thư viện',
      'Phòng Nhạc',
    ];
    final subtitles = [
      'BẢNG XẾP HẠNG · CẬP NHẬT THEO THỜI GIAN THỰC',
      discoverySubtitle,
      'CA KHÚC MỚI · XẾP HẠNG VÀ XU HƯỚNG',
      wide || widget.tvMode
          ? 'DAILY MIX · MOOD MIX · WRAPPED LOCAL'
          : 'MIX LOCAL · THỐNG KÊ · WRAPPED',
      selectedPlaylist == null
          ? switch (_librarySection) {
              LibrarySection.overview =>
                '${controller.likedSongs.length} BÀI THÍCH · ${controller.followedArtists.length} NGHỆ SĨ · ${controller.savedCollections.length} ĐÃ LƯU · ${controller.playlists.length} PLAYLIST',
              LibrarySection.songs =>
                '${controller.likedSongs.length} BÀI HÁT ĐÃ THÍCH · LƯU TRÊN THIẾT BỊ',
              LibrarySection.playlists =>
                '${controller.playlists.length} PLAYLIST CÁ NHÂN · KHÔNG CẦN TÀI KHOẢN',
              LibrarySection.albums =>
                '${controller.savedCollections.length} ALBUM & PLAYLIST ZING MP3 ĐÃ LƯU',
              LibrarySection.artists =>
                '${controller.followedArtists.length} NGHỆ SĨ ĐANG QUAN TÂM',
            }
          : '${selectedPlaylist.songs.length} BÀI HÁT · LƯU TRÊN THIẾT BỊ',
      'LIVE · V-POP · BOLERO · US-UK · K-POP',
    ];
    return Padding(
      key: const ValueKey('catalog-page-header'),
      padding: EdgeInsets.fromLTRB(
        widget.tvMode ? 32 : 20,
        widget.tvMode ? 26 : 16,
        widget.tvMode ? 32 : 20,
        compactDiscoveryLanding
            ? 8
            : widget.tvMode
            ? 24
            : 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wide && !pinCatalogToolbar) ...[
            _buildCatalogToolbar(controller, embedded: true),
            SizedBox(
              height: compactDiscoveryLanding
                  ? 12
                  : widget.tvMode
                  ? 42
                  : 34,
            ),
          ],
          if (compactDiscoveryLanding)
            const SizedBox.shrink(key: ValueKey('compact-discovery-header')),
          if (!compactDiscoveryLanding)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GradientTitle(
                        title: titles[_selectedTab],
                        gradient: _selectedTab == _chartTab,
                        fontSize: widget.tvMode
                            ? 52
                            : wide
                            ? 44
                            : 38,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitles[_selectedTab],
                        style: TextStyle(
                          color: _selectedTab == _chartTab
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : Theme.of(context).colorScheme.secondary,
                          fontSize: widget.tvMode ? 14 : 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedTab == _chartTab || _selectedTab == _newReleaseTab)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedTab == _chartTab) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: ZingColors.coral.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: ZingColors.coral.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _LiveDot(),
                              SizedBox(width: 7),
                              Text(
                                'REALTIME',
                                style: TextStyle(
                                  color: ZingColors.coral,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      IconButton.filled(
                        tooltip: _selectedTab == _newReleaseTab
                            ? 'Phát BXH Nhạc Mới'
                            : 'Phát bảng xếp hạng',
                        onPressed:
                            (_selectedTab == _newReleaseTab
                                    ? _newReleaseChart.playableSongs
                                    : _songs)
                                .isEmpty
                            ? null
                            : () {
                                final songs = _selectedTab == _newReleaseTab
                                    ? _newReleaseChart.playableSongs
                                    : _songs;
                                _selectSong(songs.first, songs);
                              },
                        icon: const Icon(Icons.play_arrow_rounded),
                      ),
                    ],
                  ),
              ],
            ),
          if (!wide) ...[
            const SizedBox(height: 22),
            _buildSearchField(compact: true),
          ],
          if (_selectedTab == _discoveryTab &&
              _selectedArtist == null &&
              _selectedCollection == null &&
              _searchController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSearchSectionTabs(),
          ],
          if (_selectedTab == _discoveryTab &&
              _catalogBrowseView == _CatalogBrowseView.discovery &&
              _searchController.text.isEmpty &&
              !compactDiscoveryLanding &&
              controller.recentSearches.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: controller.recentSearches
                        .map(
                          (query) => ActionChip(
                            avatar: const Icon(Icons.history_rounded, size: 17),
                            label: Text(query),
                            onPressed: () => _applySearchSuggestion(query),
                          ),
                        )
                        .toList(),
                  ),
                ),
                IconButton(
                  tooltip: 'Xóa tìm kiếm gần đây',
                  onPressed: controller.clearRecentSearches,
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
              ],
            ),
          ],
          if (_selectedTab != _forYouTab &&
              _selectedTab != _discoveryTab &&
              _selectedTab != _liveRadioTab &&
              (_selectedTab != _libraryTab ||
                  _librarySection == LibrarySection.songs ||
                  selectedPlaylist != null)) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedTab == _libraryTab
                        ? selectedPlaylist?.name.toUpperCase() ??
                              'BÀI HÁT ĐÃ THÍCH'
                        : _selectedTab == _newReleaseTab
                        ? 'XẾP HẠNG PHÁT HÀNH MỚI'
                        : _searchController.text.isEmpty
                        ? 'BẢNG XẾP HẠNG'
                        : 'KẾT QUẢ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if ((_selectedTab == _newReleaseTab
                    ? !_isNewReleaseLoading && _newReleaseErrorMessage == null
                    : !_isLoading && _errorMessage == null))
                  Text(
                    '${_selectedTab == _chartTab ? _songs.length : _visibleSongs(controller).length} bài hát',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyToolbar(
    MusicPlayerController controller, {
    required bool wide,
    required bool pinCatalogToolbar,
  }) => Padding(
    padding: EdgeInsets.fromLTRB(
      widget.tvMode ? 32 : 20,
      wide && pinCatalogToolbar
          ? 0
          : widget.tvMode
          ? 26
          : 16,
      widget.tvMode ? 32 : 20,
      wide && pinCatalogToolbar
          ? 0
          : widget.tvMode
          ? 26
          : 20,
    ),
    child: wide && pinCatalogToolbar
        ? const SizedBox.shrink()
        : wide
        ? Row(
            children: [
              IconButton.filledTonal(
                key: const ValueKey('catalog-history-back'),
                tooltip: 'Quay lại Khám phá',
                onPressed: _navigateToolbarBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                key: const ValueKey('catalog-history-forward'),
                tooltip: 'Tiến',
                onPressed: _canNavigateForward ? _navigateForward : null,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              const SizedBox(width: 14),
              Expanded(child: _buildSearchField(compact: false)),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: 'Làm mới bảng xếp hạng tuần',
                onPressed: _isWeeklyChartLoading
                    ? null
                    : () => unawaited(_refreshContent()),
                icon: const Icon(Icons.refresh_rounded),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                key: const ValueKey('open-app-settings'),
                tooltip: 'Cài đặt',
                onPressed: () => unawaited(_openSettings(controller)),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          )
        : _buildSearchField(compact: true),
  );

  Widget _buildCollectionHeader(
    MusicPlayerController controller,
    CatalogCollection collection, {
    required bool wide,
    required bool pinCatalogToolbar,
  }) => Padding(
    padding: EdgeInsets.fromLTRB(
      widget.tvMode ? 32 : 20,
      wide && pinCatalogToolbar
          ? 0
          : widget.tvMode
          ? 26
          : 16,
      widget.tvMode ? 32 : 20,
      wide && pinCatalogToolbar
          ? 0
          : widget.tvMode
          ? 24
          : 18,
    ),
    child: wide && pinCatalogToolbar
        ? const SizedBox.shrink()
        : wide
        ? Row(
            children: [
              IconButton.filledTonal(
                key: const ValueKey('catalog-history-back'),
                tooltip: 'Quay lại kết quả tìm kiếm',
                onPressed: _navigateToolbarBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                key: const ValueKey('catalog-history-forward'),
                tooltip: 'Tiến',
                onPressed: _canNavigateForward ? _navigateForward : null,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              const SizedBox(width: 14),
              Expanded(child: _buildSearchField(compact: false)),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                key: const ValueKey('open-app-settings'),
                tooltip: 'Cài đặt',
                onPressed: () => unawaited(_openSettings(controller)),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          )
        : Row(
            children: [
              IconButton.filledTonal(
                key: const ValueKey('collection-back-button'),
                tooltip: 'Quay lại kết quả tìm kiếm',
                onPressed: _navigateToolbarBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  collection.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('open-app-settings'),
                tooltip: 'Cài đặt',
                onPressed: () => unawaited(_openSettings(controller)),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
  );

  Widget _buildArtistHeader(
    MusicPlayerController controller,
    CatalogArtist artist, {
    required bool wide,
    required bool pinCatalogToolbar,
  }) => Padding(
    padding: EdgeInsets.fromLTRB(
      widget.tvMode ? 32 : 20,
      wide && pinCatalogToolbar
          ? 0
          : widget.tvMode
          ? 26
          : 16,
      widget.tvMode ? 32 : 20,
      wide && pinCatalogToolbar
          ? 0
          : widget.tvMode
          ? 24
          : 18,
    ),
    child: wide && pinCatalogToolbar
        ? const SizedBox.shrink()
        : wide
        ? Row(
            children: [
              IconButton.filledTonal(
                key: const ValueKey('catalog-history-back'),
                tooltip: 'Quay lại kết quả tìm kiếm',
                onPressed: _navigateToolbarBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                key: const ValueKey('catalog-history-forward'),
                tooltip: 'Tiến',
                onPressed: _canNavigateForward ? _navigateForward : null,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              const SizedBox(width: 14),
              Expanded(child: _buildSearchField(compact: false)),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                key: const ValueKey('open-app-settings'),
                tooltip: 'Cài đặt',
                onPressed: () => unawaited(_openSettings(controller)),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          )
        : Row(
            children: [
              IconButton.filledTonal(
                key: const ValueKey('artist-back-button'),
                tooltip: 'Quay lại kết quả tìm kiếm',
                onPressed: _navigateToolbarBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  artist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('open-app-settings'),
                tooltip: 'Cài đặt',
                onPressed: () => unawaited(_openSettings(controller)),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
  );

  Widget _buildSearchSectionTabs() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: CatalogSearchSection.values
          .map((section) {
            final selected = _searchSection == section;
            return Padding(
              padding: const EdgeInsets.only(right: 28),
              child: Semantics(
                key: ValueKey('search-section-${section.name}'),
                button: true,
                selected: selected,
                label: '${section.label}, tab kết quả tìm kiếm',
                onTap: () => _selectSearchSection(section),
                child: ExcludeSemantics(
                  child: InkWell(
                    onTap: () => _selectSearchSection(section),
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: 48,
                        minHeight: widget.tvMode ? 56 : 48,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              section.label,
                              style: TextStyle(
                                color: selected
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                fontSize: widget.tvMode ? 16 : 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 7),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: selected ? 38 : 0,
                              height: 2,
                              decoration: BoxDecoration(
                                color: ZingColors.purpleBright,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    ),
  );

  Widget _buildSearchPaginationFooter() {
    final section = _searchSection;
    final page = _searchPages[section];
    final unavailable = _searchPaginationUnavailable.contains(section);
    if (widget.searchCatalogPage == null || unavailable) {
      return const SizedBox.shrink();
    }
    final total = page?.total;
    final countLabel = total == null
        ? '${page?.itemCount ?? 0} kết quả'
        : '${page?.itemCount ?? 0} / $total kết quả';
    Widget control;
    if (_isSearchPageLoading) {
      control = Semantics(
        key: const ValueKey('search-page-loading'),
        liveRegion: true,
        label: page == null
            ? 'Đang tải ${section.label}'
            : 'Đang tải thêm ${section.label}',
        child: const SizedBox.square(
          dimension: 30,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    } else if (_searchPageErrorMessage != null) {
      control = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Chưa tải được trang tiếp theo. Kết quả hiện tại vẫn được giữ.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const ValueKey('search-page-retry'),
            onPressed: () =>
                unawaited(_loadSearchPage(section, loadMore: page != null)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('THỬ LẠI'),
          ),
        ],
      );
    } else if (page == null) {
      return const SizedBox.shrink();
    } else if (!page.hasMore) {
      control = Text(
        countLabel,
        key: const ValueKey('search-page-complete'),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: widget.tvMode ? 15 : 12,
          fontWeight: FontWeight.w700,
        ),
      );
    } else {
      control = OutlinedButton.icon(
        key: const ValueKey('search-page-load-more'),
        onPressed: () => unawaited(_loadSearchPage(section, loadMore: true)),
        style: OutlinedButton.styleFrom(
          minimumSize: Size(widget.tvMode ? 220 : 160, widget.tvMode ? 56 : 48),
          padding: EdgeInsets.symmetric(horizontal: widget.tvMode ? 28 : 20),
        ),
        icon: const Icon(Icons.expand_more_rounded),
        label: Text('XEM THÊM · $countLabel'),
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.tvMode ? 32 : 20,
        12,
        widget.tvMode ? 32 : 20,
        widget.tvMode ? 52 : 34,
      ),
      child: Center(child: control),
    );
  }

  void _selectSearchSection(CatalogSearchSection section) {
    if (_searchSection == section) return;
    _recordNavigationOrigin();
    _searchPageRequestId++;
    final aggregate = _aggregateSearchResult ?? _searchResult;
    setState(() {
      _searchSection = section;
      _isSearchPageLoading = false;
      _searchPageErrorMessage = null;
      if (aggregate != null) {
        _searchResult = _resultForSearchSection(aggregate, section);
      }
    });
    _scrollContentToStart();
    if (section == CatalogSearchSection.all &&
        _aggregateSearchResult == null &&
        _searchController.text.trim().isNotEmpty) {
      unawaited(_runCatalogSearch(_searchController.text));
    } else if (section != CatalogSearchSection.all &&
        !_searchPages.containsKey(section) &&
        !_searchPaginationUnavailable.contains(section)) {
      unawaited(_loadSearchPage(section));
    }
  }

  Widget _buildSearchField({required bool compact}) => Focus(
    canRequestFocus: false,
    onKeyEvent: _handleSearchKey,
    child: OverlayPortal(
      controller: _searchOverlayController,
      overlayChildBuilder: (overlayContext) {
        final renderBox = _searchFieldBoundsKey.currentContext
            ?.findRenderObject();
        final width = renderBox is RenderBox && renderBox.hasSize
            ? renderBox.size.width
            : (MediaQuery.sizeOf(context).width * 0.7).clamp(280.0, 680.0);
        final query = _searchController.text.trim().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
        return CompositedTransformFollower(
          link: _searchLayerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 8),
          child: TapRegion(
            groupId: _searchTapRegionGroup,
            child: SizedBox(
              width: width,
              child: SearchSuggestionDropdown(
                query: query,
                snapshot: _searchSuggestionSnapshot,
                loading: _isLoadingSearchSuggestions,
                loadingSongId: _loadingSearchSuggestionSongId,
                errorMessage: _searchSuggestionErrorMessage,
                highlightedIndex: _highlightedSearchSuggestion,
                onKeywordTap: _applySearchSuggestion,
                onSongTap: (song) => unawaited(_openSearchSuggestionSong(song)),
                onSearchAll: () => unawaited(_submitSearch(query)),
                onHighlightChanged: (index) {
                  if (_highlightedSearchSuggestion != index) {
                    setState(() => _highlightedSearchSuggestion = index);
                  }
                },
                tvMode: widget.tvMode,
              ),
            ),
          ),
        );
      },
      child: TapRegion(
        groupId: _searchTapRegionGroup,
        onTapOutside: (_) => _hideSearchSuggestionOverlay(),
        child: CompositedTransformTarget(
          link: _searchLayerLink,
          child: SizedBox(
            key: _searchFieldBoundsKey,
            child: TextField(
              key: const ValueKey('chart-search-field'),
              controller: _searchController,
              focusNode: _searchFocusNode,
              onTapAlwaysCalled: true,
              onTap: () {
                _enterDiscovery();
                if (_searchController.text.trim().isNotEmpty) {
                  _showSearchSuggestionOverlay();
                }
              },
              onChanged: _onSearchChanged,
              onSubmitted: (query) => unawaited(_submitSearch(query)),
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: widget.tvMode ? 20 : 15),
              decoration: InputDecoration(
                hintText: compact
                    ? 'Tìm bài hát, nghệ sĩ, lời bài hát...'
                    : 'Tìm kiếm bài hát, nghệ sĩ, lời bài hát...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? _searchFocusNode.hasFocus
                          ? IconButton(
                              key: const ValueKey('paste-zing-link-button'),
                              tooltip: 'Dán liên kết Zing MP3',
                              onPressed: () =>
                                  unawaited(_pasteOfficialZingLink()),
                              icon: const Icon(Icons.link_rounded),
                            )
                          : null
                    : IconButton(
                        tooltip: 'Xóa tìm kiếm',
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: compact ? 14 : 12,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildSearchSongSectionHeader(MusicPlayerController controller) {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final visibleCount = _visibleSongs(controller).length;
    final totalCount = hasQuery
        ? _searchPages[_searchSection]?.total ??
              _searchResult?.songs.length ??
              visibleCount
        : visibleCount;
    return Semantics(
      key: const ValueKey('search-song-section-header'),
      container: true,
      label: hasQuery && _searchSection == CatalogSearchSection.all
          ? 'Bài hát, hiển thị $visibleCount trong $totalCount'
          : 'Bài hát, $visibleCount kết quả',
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          widget.tvMode ? 32 : 20,
          0,
          widget.tvMode ? 32 : 20,
          12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasQuery ? 'BÀI HÁT' : 'GỢI Ý TỪ #ZINGCHART',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (!_isSearching &&
                hasQuery &&
                _searchSection == CatalogSearchSection.all)
              TextButton(
                key: const ValueKey('search-song-see-all'),
                onPressed: () =>
                    _selectSearchSection(CatalogSearchSection.songs),
                style: TextButton.styleFrom(
                  minimumSize: Size(widget.tvMode ? 108 : 80, 44),
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.tvMode ? 16 : 12,
                  ),
                ),
                child: Text(
                  'TẤT CẢ',
                  style: TextStyle(
                    fontSize: widget.tvMode ? 14 : 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              )
            else if (!_isSearching)
              Text(
                '$visibleCount bài hát',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionSongSectionHeader(int songCount) => Padding(
    padding: EdgeInsets.fromLTRB(
      widget.tvMode ? 32 : 20,
      0,
      widget.tvMode ? 32 : 20,
      12,
    ),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'DANH SÁCH BÀI HÁT',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$songCount bài hát',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );

  Widget _buildArtistSongSectionHeader(
    int songCount, {
    required int totalSongCount,
  }) => Padding(
    padding: EdgeInsets.fromLTRB(
      widget.tvMode ? 32 : 20,
      0,
      widget.tvMode ? 32 : 20,
      12,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _artistSection == OfficialArtistSection.songs
                ? 'TẤT CẢ BÀI HÁT'
                : 'BÀI HÁT NỔI BẬT',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (_artistSection == OfficialArtistSection.profile &&
            totalSongCount > songCount) ...[
          TextButton(
            key: const ValueKey('artist-songs-show-all'),
            onPressed: () => _showArtistSection(OfficialArtistSection.songs),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              minimumSize: Size(
                widget.tvMode ? 108 : 76,
                widget.tvMode ? 52 : 40,
              ),
              textStyle: TextStyle(
                fontSize: widget.tvMode ? 14 : 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.05,
              ),
            ),
            child: const Text('TẤT CẢ'),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          '$songCount bài hát',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class _GradientTitle extends StatelessWidget {
  const _GradientTitle({
    required this.title,
    required this.gradient,
    required this.fontSize,
  });

  final String title;
  final bool gradient;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final titleWidget = Text(
      title,
      style: TextStyle(
        color: gradient ? Colors.white : null,
        fontSize: fontSize,
        height: 0.96,
        fontWeight: FontWeight.w900,
        letterSpacing: -2.4,
      ),
    );
    if (!gradient) return titleWidget;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFFF7B54), Color(0xFFED2B91), Color(0xFF7B61FF)],
      ).createShader(bounds),
      child: titleWidget,
    );
  }
}

class _CatalogMetadataLink extends StatefulWidget {
  const _CatalogMetadataLink({
    super.key,
    required this.text,
    required this.style,
    this.semanticLabel,
    this.onTap,
  });

  final String text;
  final TextStyle style;
  final String? semanticLabel;
  final VoidCallback? onTap;

  @override
  State<_CatalogMetadataLink> createState() => _CatalogMetadataLinkState();
}

class _CatalogMetadataLinkState extends State<_CatalogMetadataLink> {
  bool _hovered = false;
  bool _focused = false;

  void _handleFocusChange(bool focused) {
    if (_focused != focused) setState(() => _focused = focused);
    if (!focused) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    final text = Text(
      widget.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: widget.style.copyWith(
        color: _hovered || _focused
            ? ZingColors.purpleBright
            : widget.style.color,
        decoration: _hovered || _focused ? TextDecoration.underline : null,
        decorationColor: ZingColors.purpleBright,
      ),
    );
    if (onTap == null) return text;
    final semanticLabel = widget.semanticLabel ?? widget.text;
    final platform = Theme.of(context).platform;
    final touchPlatform =
        platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS ||
        platform == TargetPlatform.fuchsia;
    final width = MediaQuery.sizeOf(context).width;
    final compactTouchTarget =
        width >= 720 && (!touchPlatform || width >= 1024);
    return Tooltip(
      message: semanticLabel,
      child: TextButton(
        onPressed: onTap,
        onHover: (hovered) => setState(() => _hovered = hovered),
        onFocusChange: _handleFocusChange,
        style: TextButton.styleFrom(
          minimumSize: Size(0, compactTouchTarget ? 0 : 44),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.centerLeft,
          foregroundColor: widget.style.color,
        ),
        child: Semantics(
          label: semanticLabel,
          excludeSemantics: true,
          child: text,
        ),
      ),
    );
  }
}

class _CatalogArtistLinks extends StatelessWidget {
  const _CatalogArtistLinks({
    super.key,
    required this.fallbackText,
    required this.artists,
    required this.suffix,
    required this.style,
    this.onArtistTap,
  });

  final String fallbackText;
  final List<CatalogArtist> artists;
  final String suffix;
  final TextStyle style;
  final ValueChanged<CatalogArtist>? onArtistTap;

  @override
  Widget build(BuildContext context) {
    final callback = onArtistTap;
    if (artists.isEmpty || callback == null) {
      return Text(
        suffix.isEmpty ? fallbackText : '$fallbackText · $suffix',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    final children = <Widget>[];
    for (var index = 0; index < artists.length; index++) {
      final artist = artists[index];
      if (index > 0) children.add(Text(', ', style: style));
      children.add(
        _CatalogMetadataLink(
          key: ValueKey('artist-link-${artist.id}'),
          text: artist.name,
          semanticLabel: 'Mở nghệ sĩ ${artist.name}',
          onTap: () => callback(artist),
          style: style,
        ),
      );
    }
    if (suffix.isNotEmpty) {
      children.add(Text(' · $suffix', style: style));
    }
    if (artists.length == 1) {
      return Row(
        children: [
          Flexible(child: children.first),
          ...children.skip(1),
        ],
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _SongCover extends StatelessWidget {
  const _SongCover({
    super.key,
    required this.song,
    required this.size,
    required this.borderRadius,
    required this.highlighted,
    required this.isCurrent,
    required this.canPlay,
  });

  final Song song;
  final double size;
  final double borderRadius;
  final bool highlighted;
  final bool isCurrent;
  final bool canPlay;

  @override
  Widget build(BuildContext context) {
    final showAction = highlighted || isCurrent || !canPlay;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AlbumArt(
            imageUrl: song.thumbnail,
            semanticLabel: 'Bìa album ${song.displayTitle}',
            size: size,
            borderRadius: borderRadius,
          ),
          IgnorePointer(
            child: ExcludeSemantics(
              child: AnimatedOpacity(
                opacity: showAction ? 1 : 0,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                  child: Icon(
                    !canPlay
                        ? Icons.lock_outline_rounded
                        : isCurrent
                        ? Icons.graphic_eq_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: size * 0.48,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SongTile extends StatefulWidget {
  const _SongTile({
    super.key,
    required this.song,
    required this.rank,
    required this.rankChange,
    this.leadingLabel,
    required this.albumTitle,
    required this.duration,
    required this.releasedAt,
    required this.dense,
    this.showLeading = true,
    this.padDurationMinutes = false,
    required this.hasLyrics,
    required this.canPlay,
    required this.onTap,
    required this.isLiked,
    required this.isCurrent,
    required this.moods,
    required this.onLike,
    required this.onToggleMood,
    required this.onAddToQueue,
    required this.onStartRadio,
    required this.onAddToPlaylist,
    required this.onShare,
    required this.artists,
    required this.onOpenDetail,
    this.onArtistTap,
    this.onAlbumTap,
    this.tvMode = false,
    this.compactMetadata = false,
    this.hideAlbumMetadata = false,
    this.plainTrackNumber,
    this.autofocus = false,
  });

  final Song song;
  final int? rank;
  final int? rankChange;
  final String? leadingLabel;
  final String albumTitle;
  final Duration duration;
  final DateTime? releasedAt;
  final bool dense;
  final bool showLeading;
  final bool padDurationMinutes;
  final bool hasLyrics;
  final bool canPlay;
  final VoidCallback onTap;
  final bool isLiked;
  final bool isCurrent;
  final Set<MoodTag> moods;
  final VoidCallback onLike;
  final ValueChanged<MoodTag> onToggleMood;
  final VoidCallback onAddToQueue;
  final Future<void> Function() onStartRadio;
  final VoidCallback onAddToPlaylist;
  final Future<void> Function() onShare;
  final List<CatalogArtist> artists;
  final VoidCallback onOpenDetail;
  final ValueChanged<CatalogArtist>? onArtistTap;
  final VoidCallback? onAlbumTap;
  final bool tvMode;
  final bool compactMetadata;
  final bool hideAlbumMetadata;
  final int? plainTrackNumber;
  final bool autofocus;

  @override
  State<_SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<_SongTile> {
  bool _focused = false;
  bool _hovered = false;

  Color get rankColor {
    if (widget.rank == 1) return ZingColors.blue;
    if (widget.rank == 2) return ZingColors.lime;
    if (widget.rank == 3) return const Color(0xFFE35050);
    return const Color(0xFF958C9F);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.tvMode ? 16 : 10);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showDesktopMetadata =
        !widget.tvMode &&
        !widget.compactMetadata &&
        MediaQuery.sizeOf(context).width >= 1180;
    final compactSongRow =
        !widget.tvMode && MediaQuery.sizeOf(context).width < 480;
    final releaseLabel = widget.releasedAt == null
        ? ''
        : releaseAgeLabel(widget.releasedAt);
    final showActions =
        !widget.dense || !showDesktopMetadata || _focused || _hovered;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        key: ValueKey('song-row-${widget.song.id}'),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: _focused ? ZingColors.purpleBright : Colors.transparent,
            width: widget.tvMode ? 3 : 2,
          ),
          boxShadow: _focused
              ? const [
                  BoxShadow(
                    color: Color(0x559B4DE0),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: _focused
              ? ZingColors.purple.withValues(alpha: 0.18)
              : _hovered
              ? ZingColors.purple.withValues(alpha: 0.08)
              : widget.isCurrent
              ? ZingColors.purple.withValues(alpha: 0.11)
              : Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            autofocus: widget.autofocus,
            onFocusChange: (focused) {
              if (_focused != focused) setState(() => _focused = focused);
            },
            onTap: widget.onTap,
            onSecondaryTapDown: (details) => unawaited(
              showSongActionContextMenu(
                context: context,
                globalPosition: details.globalPosition,
                keyPrefix: 'song-action',
                song: widget.song,
                handlers: _actionHandlers,
                isLiked: widget.isLiked,
                moods: widget.moods,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.tvMode
                    ? 14
                    : widget.showLeading
                    ? 10
                    : 8,
                vertical: widget.tvMode
                    ? 11
                    : widget.dense
                    ? 5
                    : 9,
              ),
              child: Row(
                children: [
                  if (widget.showLeading) ...[
                    SizedBox(
                      width: widget.tvMode ? 58 : 46,
                      child: widget.isCurrent
                          ? const Icon(
                              Icons.graphic_eq_rounded,
                              color: ZingColors.purpleBright,
                            )
                          : widget.plainTrackNumber != null
                          ? Semantics(
                              key: ValueKey(
                                'collection-track-number-${widget.song.id}',
                              ),
                              label: 'Bài số ${widget.plainTrackNumber}',
                              child: ExcludeSemantics(
                                child: Text(
                                  widget.plainTrackNumber!.toString(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: widget.tvMode ? 18 : 14,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : widget.leadingLabel != null
                          ? Semantics(
                              label: 'Bài hát gợi ý',
                              child: Text(
                                widget.leadingLabel!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: ZingColors.coral,
                                  fontSize: widget.tvMode ? 12 : 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            )
                          : widget.rank == null
                          ? Icon(
                              widget.canPlay
                                  ? Icons.music_note_rounded
                                  : Icons.lock_outline_rounded,
                              color: widget.canPlay
                                  ? ZingColors.purpleBright
                                  : scheme.onSurfaceVariant,
                            )
                          : _buildRankMarker(),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _SongCover(
                    key: ValueKey('song-cover-action-${widget.song.id}'),
                    song: widget.song,
                    size: widget.tvMode
                        ? 72
                        : widget.dense
                        ? 40
                        : 52,
                    borderRadius: widget.tvMode ? 14 : 8,
                    highlighted: _hovered || _focused,
                    isCurrent: widget.isCurrent,
                    canPlay: widget.canPlay,
                  ),
                  SizedBox(width: compactSongRow ? 10 : 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.song.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: widget.tvMode
                                      ? 18
                                      : widget.dense
                                      ? 14
                                      : 15,
                                  color: widget.isCurrent
                                      ? ZingColors.purpleBright
                                      : null,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            if (widget.hasLyrics) ...[
                              const SizedBox(width: 7),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: widget.tvMode ? 8 : 6,
                                  vertical: widget.tvMode ? 4 : 2,
                                ),
                                decoration: BoxDecoration(
                                  color: ZingColors.purpleBright.withValues(
                                    alpha: 0.16,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'CÓ LỜI',
                                  style: TextStyle(
                                    color: ZingColors.purpleBright,
                                    fontSize: widget.tvMode ? 11 : 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.45,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        _CatalogArtistLinks(
                          key: ValueKey('song-artist-link-${widget.song.id}'),
                          fallbackText: widget.song.artistsNames,
                          artists: widget.artists,
                          suffix:
                              widget.tvMode && widget.duration > Duration.zero
                              ? _durationLabel(
                                  widget.duration,
                                  padMinutes: widget.padDurationMinutes,
                                )
                              : !showDesktopMetadata &&
                                    !compactSongRow &&
                                    releaseLabel.isNotEmpty
                              ? releaseLabel
                              : '',
                          onArtistTap: widget.onArtistTap,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: widget.tvMode
                                ? 15
                                : widget.dense
                                ? 12
                                : 13,
                          ),
                        ),
                        if (compactSongRow && releaseLabel.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            releaseLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ZingColors.coral,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        if (widget.tvMode && widget.albumTitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          _CatalogMetadataLink(
                            key: ValueKey('song-album-link-${widget.song.id}'),
                            text: widget.albumTitle,
                            semanticLabel: widget.onAlbumTap == null
                                ? null
                                : 'Mở album ${widget.albumTitle}',
                            onTap: widget.onAlbumTap,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.82,
                              ),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (showDesktopMetadata && !widget.hideAlbumMetadata) ...[
                    SizedBox(
                      width: 220,
                      child: widget.albumTitle.isEmpty
                          ? const SizedBox.shrink()
                          : _CatalogMetadataLink(
                              key: ValueKey(
                                'song-album-link-${widget.song.id}',
                              ),
                              text: widget.albumTitle,
                              semanticLabel: widget.onAlbumTap == null
                                  ? null
                                  : 'Mở album ${widget.albumTitle}',
                              onTap: widget.onAlbumTap,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  if (showDesktopMetadata && releaseLabel.isNotEmpty) ...[
                    SizedBox(
                      width: 92,
                      child: Text(
                        releaseLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ZingColors.coral,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (!compactSongRow &&
                      (showDesktopMetadata || widget.compactMetadata)) ...[
                    SizedBox(
                      width: 44,
                      child: widget.duration <= Duration.zero
                          ? const SizedBox.shrink()
                          : Text(
                              _durationLabel(
                                widget.duration,
                                padMinutes: widget.padDurationMinutes,
                              ),
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  AnimatedOpacity(
                    key: ValueKey('song-actions-${widget.song.id}'),
                    opacity: showActions ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: IgnorePointer(
                      ignoring: !showActions,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!compactSongRow)
                            IconButton(
                              tooltip: widget.isLiked
                                  ? 'Bỏ yêu thích'
                                  : 'Yêu thích',
                              onPressed: widget.onLike,
                              icon: Icon(
                                widget.isLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: widget.isLiked
                                    ? const Color(0xFFFF6B4A)
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          if (showDesktopMetadata || widget.tvMode)
                            IconButton(
                              key: ValueKey(
                                'song-detail-action-${widget.song.id}',
                              ),
                              tooltip: 'Thông tin ${widget.song.displayTitle}',
                              onPressed: widget.onOpenDetail,
                              icon: Icon(
                                Icons.info_outline_rounded,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          SongActionOverflowButton(
                            keyPrefix: 'song-action',
                            song: widget.song,
                            handlers: _actionHandlers,
                            isLiked: widget.isLiked,
                            moods: widget.moods,
                            iconColor: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRankMarker() {
    final change = widget.rankChange;
    final movementLabel = change == null
        ? ''
        : change == 0
        ? ', không đổi'
        : change > 0
        ? ', tăng $change bậc'
        : ', giảm ${change.abs()} bậc';
    return Semantics(
      key: ValueKey('rank-change-${widget.song.id}'),
      label: 'Hạng ${widget.rank}$movementLabel',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.rank!.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: rankColor,
                fontSize: widget.tvMode
                    ? (widget.rank! <= 3 ? 24 : 19)
                    : (widget.rank! <= 3 ? 20 : 15),
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (change != null) ...[
              const SizedBox(height: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    change == 0
                        ? Icons.remove_rounded
                        : change > 0
                        ? Icons.arrow_drop_up_rounded
                        : Icons.arrow_drop_down_rounded,
                    size: 13,
                    color: change == 0
                        ? const Color(0xFF958C9F)
                        : change > 0
                        ? const Color(0xFF16C79A)
                        : const Color(0xFFE35050),
                  ),
                  if (change != 0)
                    Text(
                      change.abs().toString(),
                      style: TextStyle(
                        color: change > 0
                            ? const Color(0xFF16C79A)
                            : const Color(0xFFE35050),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _durationLabel(Duration duration, {bool padMinutes = false}) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final minuteLabel = padMinutes
        ? minutes.toString().padLeft(2, '0')
        : minutes.toString();
    return '$minuteLabel:$seconds';
  }

  SongActionHandlers get _actionHandlers => SongActionHandlers(
    onPlay: widget.canPlay ? widget.onTap : null,
    onOpenDetail: widget.onOpenDetail,
    onAddToQueue: widget.canPlay ? widget.onAddToQueue : null,
    onStartRadio: widget.canPlay
        ? () => unawaited(widget.onStartRadio())
        : null,
    onAddToPlaylist: widget.onAddToPlaylist,
    onShare: () => unawaited(widget.onShare()),
    onToggleLike: widget.onLike,
    onToggleMood: widget.onToggleMood,
  );
}

class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog({required this.title, required this.initialValue});

  final String title;
  final String initialValue;

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _save() {
    final value = _textController.text.trim();
    if (value.isNotEmpty) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      key: const ValueKey('playlist-name-field'),
      controller: _textController,
      autofocus: true,
      maxLength: 60,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(labelText: 'Tên playlist'),
      onSubmitted: (_) => _save(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(onPressed: _save, child: const Text('Lưu')),
    ],
  );
}

class _ImportBackupDialog extends StatefulWidget {
  const _ImportBackupDialog({
    required this.controller,
    required this.initialJson,
  });

  final MusicPlayerController controller;
  final String initialJson;

  @override
  State<_ImportBackupDialog> createState() => _ImportBackupDialogState();
}

class _ImportBackupDialogState extends State<_ImportBackupDialog> {
  late final TextEditingController _textController;
  var _mode = BackupImportMode.merge;
  var _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialJson);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    if (_isRestoring) return;
    setState(() => _isRestoring = true);
    try {
      await widget.controller.importLibraryJson(_textController.text, _mode);
      if (mounted) Navigator.pop(context, true);
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _isRestoring = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isRestoring = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể khôi phục file này. Vui lòng thử lại.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Khôi phục thư viện'),
    content: SizedBox(
      width: 620,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<BackupImportMode>(
            segments: const [
              ButtonSegment(
                value: BackupImportMode.merge,
                icon: Icon(Icons.merge_rounded),
                label: Text('Hợp nhất'),
              ),
              ButtonSegment(
                value: BackupImportMode.overwrite,
                icon: Icon(Icons.sync_problem_rounded),
                label: Text('Ghi đè'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: _isRestoring
                ? null
                : (selection) => setState(() => _mode = selection.single),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('import-backup-json-field'),
            controller: _textController,
            enabled: !_isRestoring,
            minLines: 7,
            maxLines: 12,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            decoration: const InputDecoration(
              labelText: 'Dán nội dung file .json',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _isRestoring ? null : () => Navigator.pop(context, false),
        child: const Text('Hủy'),
      ),
      FilledButton(
        key: const ValueKey('confirm-import-backup-button'),
        onPressed: _isRestoring ? null : _restore,
        child: _isRestoring
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Khôi phục'),
      ),
    ],
  );
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: Color(0xFFFF6B4A),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Color(0xAAFF6B4A), blurRadius: 7)],
      ),
    );
  }
}

const _catalogToolbarExtent = 68.0;
const _pinnedDiscoveryChromeExtent = 132.0;
const _pinnedDiscoveryChromeErrorExtent = 180.0;

class _CatalogToolbarDelegate extends SliverPersistentHeaderDelegate {
  const _CatalogToolbarDelegate({required this.child, this.extent = 68});

  final Widget child;
  final double extent;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(child: child);

  @override
  bool shouldRebuild(covariant _CatalogToolbarDelegate oldDelegate) =>
      oldDelegate.child != child || oldDelegate.extent != extent;
}

class _CollectionErrorState extends StatelessWidget {
  const _CollectionErrorState({
    required this.message,
    required this.onRetry,
    this.compact = false,
  });

  final String message;
  final Future<void> Function() onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = compact
        ? 'Không làm mới được tuyển tập'
        : 'Chưa tải được tuyển tập';
    return Semantics(
      key: const ValueKey('collection-load-error'),
      liveRegion: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 24,
          vertical: compact ? 10 : 42,
        ),
        child: compact
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: scheme.error.withValues(alpha: 0.28),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 24,
                        color: scheme.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        key: const ValueKey('collection-retry-button'),
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('THỬ LẠI'),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 48, color: scheme.error),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const ValueKey('collection-retry-button'),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('THỬ LẠI'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 54,
            color: Color(0xFFFF6B4A),
          ),
          const SizedBox(height: 18),
          const Text(
            'Chưa tải được bảng xếp hạng',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFB5B6BA)),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.message = 'Không tìm thấy bài hát phù hợp'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.manage_search_rounded,
              size: 52,
              color: Color(0xFFB8F43D),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
