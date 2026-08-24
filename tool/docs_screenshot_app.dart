import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:zmp3chart/analytics_dashboard_screen.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/data/listening_analytics_repository.dart';
import 'package:zmp3chart/main.dart';
import 'package:zmp3chart/models/listening_analytics.dart';
import 'package:zmp3chart/models/live_radio.dart';
import 'package:zmp3chart/models/local_library.dart';
import 'package:zmp3chart/models/chart_snapshot.dart';
import 'package:zmp3chart/models/catalog_hub.dart';
import 'package:zmp3chart/models/catalog_artist_detail.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/discovery_home.dart';
import 'package:zmp3chart/models/new_release_chart.dart';
import 'package:zmp3chart/models/release_catalog.dart';
import 'package:zmp3chart/models/search_suggestions.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/models/song_detail.dart';
import 'package:zmp3chart/models/song_lyrics.dart';
import 'package:zmp3chart/models/song_radio.dart';
import 'package:zmp3chart/models/weekly_chart.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_screen.dart';
import 'package:zmp3chart/services/companion_surface_bridge.dart';
import 'package:zmp3chart/services/playback_audio_player.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/theme/app_theme.dart';
import 'package:zmp3chart/wrapped_screen.dart';
import 'package:zmp3chart/zing_chart_screen.dart';
import 'package:zmp3chart/widgets/discovery_home_hub.dart';
import 'package:zmp3chart/widgets/artist_profile_catalog.dart';
import 'package:zmp3chart/widgets/collection_detail_catalog.dart';
import 'package:zmp3chart/widgets/desktop_playback_queue_panel.dart';
import 'package:zmp3chart/widgets/lyric_share_composer.dart';
import 'package:zmp3chart/widgets/realtime_chart.dart';
import 'package:zmp3chart/widgets/song_detail_panel.dart';
import 'package:zmp3chart/widgets/song_lyrics_panel.dart';
import 'package:zmp3chart/widgets/streaming_quality_controls.dart';

/// Deterministic documentation-only entry point used to capture README images.
///
/// It never calls the proxy or a platform media service. Choose a surface with
/// `?screen=home|queue|smart-shuffle|stream-quality|desktop-lyrics|realtime-chart|discovery|discovery-recommendations|discovery-mv|discovery-recent|discovery-new-releases|discovery-new-release-chart|live-radio|artist|artist-follow|artist-mv|collection-save|collection-information|hubs|top-100|release-catalog|weekly-chart|search|search-results|new-releases|player|car-mode|song-detail|lyrics|lyric-share|radio|library|for-you|analytics|wrapped|tv`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final audioPlayer = _DocsAudioPlayer();
  final controller = PlaybackService(
    playbackAudioPlayer: audioPlayer,
    sourceResolver: (code) async => 'https://audio.example/$code.mp3',
    songRadioLoader: (_) async => _docsRadio,
    liveRadioSourceResolver: (id) async =>
        'https://proxy.example/v1/live-streams/$id',
    libraryRepository: MemoryLibraryRepository(_librarySnapshot()),
    analyticsRepository: MemoryListeningAnalyticsRepository(
      _analyticsSnapshot(),
    ),
    systemMediaBridge: NoopSystemMediaBridge(),
    companionSurfaceBridge: NoopCompanionSurfaceBridge(),
  );
  final screen = Uri.base.queryParameters['screen'] ?? 'home';
  final initialQueue = screen == 'discovery-new-releases'
      ? _docsHomeReleaseSongs
            .where((item) => item.playable)
            .map((item) => item.song)
            .toList(growable: false)
      : screen == 'new-releases'
      ? _newReleaseChart.playableSongs
      : screen == 'weekly-chart'
      ? _weeklyChart.playableSongs
      : screen == 'artist' || screen == 'artist-follow' || screen == 'artist-mv'
      ? _artistDetail.songs
            .where((item) => item.playable)
            .map((item) => item.song)
            .toList(growable: false)
      : screen == 'release-catalog'
      ? _releaseCatalog.songs
            .where((item) => item.playable)
            .map((item) => item.song)
            .toList(growable: false)
      : screen == 'radio'
      ? [_songs.first]
      : _songs;
  final tvMode = screen == 'tv';
  runApp(
    MyApp(
      playerController: controller,
      tvMode: tvMode,
      home: switch (screen) {
        'realtime-chart' => Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF21142F), ZingColors.ink],
              ),
            ),
            child: Center(
              child: RealtimeChart(
                snapshot: _docsChartSnapshot,
                onPlay: (_, _) {},
                autofocus: true,
              ),
            ),
          ),
        ),
        'player' => const MusicPlayerScreen(),
        'car-mode' => const MusicPlayerScreen(),
        'song-detail' => Scaffold(
          backgroundColor: ZingColors.ink,
          body: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                width: 1080,
                height: 760,
                child: SongDetailPanel(
                  controller: controller,
                  detailLoader: (_) async => _docsSongDetail,
                  onOpenArtist: (_) {},
                  onOpenAlbum: (_) {},
                ),
              ),
            ),
          ),
        ),
        'lyrics' => SongLyricsPanel(
          controller: controller,
          lyricsLoader: (_) async => _docsLyrics,
          initialKaraoke: true,
          onClose: () {},
        ),
        'lyric-share' => Scaffold(
          backgroundColor: ZingColors.ink,
          body: Center(
            child: SizedBox(
              width: 1040,
              height: 680,
              child: LyricShareComposer(
                song: _songs.first,
                lyrics: _docsLyrics,
                initialLineIndex: 0,
                onClose: () {},
              ),
            ),
          ),
        ),
        'radio' => ZingChartScreen(
          loadSongs: _loadSongs,
          initialDesktopQueueVisible: true,
        ),
        'analytics' => const AnalyticsDashboardScreen(),
        'wrapped' => const WrappedScreen(),
        'queue' => ZingChartScreen(
          loadChart: () async => _docsChartSnapshot,
          loadChartSuggestion: () async => _docsChartSuggestion,
          initialDesktopQueueVisible: true,
        ),
        'smart-shuffle' => ZingChartScreen(
          loadSongs: _loadSongs,
          initialDesktopQueueVisible: true,
        ),
        'stream-quality' => Scaffold(
          backgroundColor: ZingColors.ink,
          body: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                width: 690,
                child: StreamingQualityPickerPanel(
                  controller: controller,
                  showCloseButton: false,
                ),
              ),
            ),
          ),
        ),
        'desktop-lyrics' => ZingChartScreen(
          loadChart: () async => _docsChartSnapshot,
          loadChartSuggestion: () async => _docsChartSuggestion,
          lyricsLoader: (_) async => _docsLyrics,
          initialDesktopQueueVisible: true,
          initialDesktopPanelTab: DesktopPlaybackPanelTab.lyrics,
        ),
        'search' => ZingChartScreen(
          loadSongs: _loadSongs,
          loadDiscoveryHome: _loadDiscoveryHome,
          searchSuggestions: _loadSearchSuggestions,
          searchCatalog: (query) async => CatalogSearchResult.empty(query),
          initialTab: 1,
          initialSearchQuery: 'một',
        ),
        'search-results' => ZingChartScreen(
          loadSongs: _loadSongs,
          loadDiscoveryHome: _loadDiscoveryHome,
          searchSuggestions: (query) async =>
              SearchSuggestionSnapshot.empty(query),
          searchCatalog: (_) async => _docsFullSearchResult,
          initialTab: 1,
          initialSearchQuery: 'chúng ta không thuộc về nhau',
          initialSearchSection: CatalogSearchSection.videos,
        ),
        'discovery' => ZingChartScreen(
          loadSongs: _loadSongs,
          loadDiscoveryHome: _loadDiscoveryHome,
          loadDiscoveryCategories: _loadDiscoveryCategories,
          loadDiscoveryRecommendations: _loadDiscoveryRecommendations,
          loadDiscoveryCategoryHome: _loadDiscoveryCategoryHome,
          loadReleaseCatalog: _loadReleaseCatalog,
          loadNewReleases: _loadNewReleases,
          initialTab: 1,
        ),
        'discovery-recommendations' => Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF21142F), ZingColors.ink],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(42),
              child: DiscoveryRecommendationShelf(
                songs: _docsRecommendationSongs,
                official: true,
                canRefresh: true,
                onSongTap: (_) {},
                onRefresh: () {},
              ),
            ),
          ),
        ),
        'discovery-mv' => Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF21142F), ZingColors.ink],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: DiscoveryVideoShelf(
                videos: _docsFullSearchResult.videos,
                onVideoTap: (_) {},
              ),
            ),
          ),
        ),
        'discovery-recent' => Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF21142F), ZingColors.ink],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(42),
              child: DiscoveryRecentlyPlayedShelf(
                songs: _songs.take(8).toList(growable: false),
                onSongTap: (_) {},
                onOpenLibrary: () {},
              ),
            ),
          ),
        ),
        'discovery-new-releases' => Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF21142F), ZingColors.ink],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(42),
              child: DiscoveryNewReleaseShelf(
                songs: _docsHomeReleaseSongs,
                loading: false,
                errorMessage: null,
                region: DiscoveryReleaseRegion.all,
                onRegionChanged: (_) {},
                onSongTap: (_) {},
                onOpenAll: () {},
                onRetry: () {},
              ),
            ),
          ),
        ),
        'discovery-new-release-chart' => Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF21142F), ZingColors.ink],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(42),
              child: DiscoveryNewReleaseChartSpotlight(
                entries: _docsNewReleaseChartSpotlightEntries,
                loading: false,
                errorMessage: null,
                onEntryTap: (_) {},
                onOpenAll: () {},
              ),
            ),
          ),
        ),
        'artist' => ZingChartScreen(
          loadSongs: _loadSongs,
          loadArtistDetail: _loadArtistDetail,
          initialArtist: _artistDetail.artist,
        ),
        'artist-follow' => ZingChartScreen(
          loadSongs: _loadSongs,
          loadArtistDetail: _loadArtistDetail,
          initialArtist: _artistDetail.artist,
          initialDesktopQueueVisible: true,
        ),
        'artist-mv' => const _ArtistCatalogDocsScreen(),
        'collection-save' => ZingChartScreen(
          loadSongs: _loadSongs,
          loadCollection: _loadCollection,
          loadArtistDetail: _loadArtistDetail,
          initialOfficialUrl:
              'https://zingmp3.vn/album/chung-ta-cua-tuong-lai/chung-ta-cua-tuong-lai.html',
        ),
        'collection-information' => Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF21142F), ZingColors.ink],
              ),
            ),
            child: SingleChildScrollView(
              child: CollectionDetailCatalog(
                detail: _docsCollectionDetail,
                onCollectionTap: (_) {},
                onArtistTap: (_) {},
                onArtistToggleFollow: (_) {},
                followedArtistIds: const {'mono'},
                onCollectionPlay: (_) {},
                onCollectionToggleSaved: (_) {},
                onCollectionShare: (_) {},
                savedCollectionIds: const {'best-of-vpop'},
              ),
            ),
          ),
        ),
        'hubs' => ZingChartScreen(
          loadSongs: _loadSongs,
          loadHubHome: _loadHubHome,
          initialCatalogLanding: CatalogLanding.hubs,
        ),
        'top-100' => ZingChartScreen(
          loadSongs: _loadSongs,
          loadTop100: _loadTop100,
          initialCatalogLanding: CatalogLanding.top100,
        ),
        'release-catalog' => ZingChartScreen(
          loadSongs: _loadSongs,
          loadReleaseCatalog: _loadReleaseCatalog,
          initialCatalogLanding: CatalogLanding.releases,
        ),
        'weekly-chart' => ZingChartScreen(
          loadSongs: _loadSongs,
          loadWeeklyChart: _loadWeeklyChart,
          initialCatalogLanding: CatalogLanding.weekly,
        ),
        'new-releases' => ZingChartScreen(
          loadSongs: _loadSongs,
          loadNewReleases: _loadNewReleases,
          initialTab: 2,
        ),
        'live-radio' => ZingChartScreen(
          loadSongs: _loadSongs,
          loadLiveRadio: _loadLiveRadio,
          initialTab: 5,
        ),
        'for-you' => ZingChartScreen(loadSongs: _loadSongs, initialTab: 3),
        'library' => ZingChartScreen(loadSongs: _loadSongs, initialTab: 4),
        'tv' => ZingChartScreen(
          loadSongs: _loadSongs,
          initialTab: 3,
          tvMode: true,
        ),
        _ => ZingChartScreen(
          loadChart: () async => _docsChartSnapshot,
          loadChartSuggestion: () async => _docsChartSuggestion,
        ),
      },
    ),
  );
  unawaited(() async {
    await controller.initialize();
    if (screen == 'car-mode') controller.setCarModeEnabled(true);
    if (screen == 'stream-quality') {
      controller.setStreamingQualityPreference(StreamingQualityPreference.high);
    }
    controller.updateCatalog([
      ..._songs,
      ..._artistDetail.songs.map((e) => e.song),
    ]);
    if (screen == 'live-radio') {
      await controller.playLiveRadio(_liveRadio.rooms.first);
    } else {
      await controller.playSong(initialQueue.first, queue: initialQueue);
      if (screen == 'radio') await controller.startSongRadio();
      if (screen == 'smart-shuffle') {
        controller.setSmartShuffleEnabled(true);
      }
    }
    audioPlayer
      ..emitDuration(const Duration(minutes: 3, seconds: 42))
      ..emitPosition(const Duration(minutes: 1, seconds: 18));
  }());
}

class _ArtistCatalogDocsScreen extends StatefulWidget {
  const _ArtistCatalogDocsScreen();

  @override
  State<_ArtistCatalogDocsScreen> createState() =>
      _ArtistCatalogDocsScreenState();
}

class _ArtistCatalogDocsScreenState extends State<_ArtistCatalogDocsScreen> {
  final _scrollController = ScrollController(initialScrollOffset: 310);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ZingColors.ink,
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF21142F), ZingColors.ink],
        ),
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: ArtistProfileCatalog(
          detail: _artistDetail,
          onCollectionTap: (_) {},
          onArtistTap: (_) {},
          onVideoTap: (_) {},
        ),
      ),
    ),
  );
}

Future<List<Song>> _loadSongs() async => _songs;

Future<CatalogCollectionDetail> _loadCollection(String _) async =>
    _docsCollectionDetail;

Future<NewReleaseChart> _loadNewReleases() async => _newReleaseChart;

Future<LiveRadioSnapshot> _loadLiveRadio() async => _liveRadio;

Future<DiscoveryHome> _loadDiscoveryHome() async => _discoveryHome;

Future<DiscoveryCategories> _loadDiscoveryCategories() async =>
    _discoveryCategories;

Future<DiscoveryRecommendations> _loadDiscoveryRecommendations() async =>
    DiscoveryRecommendations(
      updatedAt: null,
      entries: _docsRecommendationSongs
          .map(
            (song) => CatalogSong(
              song: song,
              duration: const Duration(minutes: 3, seconds: 42),
              externalUrl: '',
              playable: true,
            ),
          )
          .toList(growable: false),
      catalogPlaybackEnabled: true,
    );

Future<DiscoveryHome> _loadDiscoveryCategoryHome(String categoryId) async =>
    DiscoveryHome(
      categoryId: categoryId,
      updatedAt: _discoveryHome.updatedAt,
      quickPlay: _discoveryHome.quickPlay,
      banners: _discoveryHome.banners,
      videos: _discoveryHome.videos,
      sections: _discoveryHome.sections,
    );

Future<SearchSuggestionSnapshot> _loadSearchSuggestions(String query) async =>
    SearchSuggestionSnapshot(
      query: query,
      keywords: const [
        'một bài hát',
        'một bước yêu vạn dặm đau',
        'một vòng việt nam',
        'một đời người một rừng cây',
      ],
      songs: const [
        SearchSuggestionSong(
          id: 'search-one',
          title: 'Một Bước Yêu, Vạn Dặm Đau',
          artist: 'Mr. Siro',
          thumbnail: '',
          duration: Duration(minutes: 4, seconds: 59),
          externalUrl: 'https://zingmp3.vn/bai-hat/search-one.html',
        ),
        SearchSuggestionSong(
          id: 'search-two',
          title: 'Một Vòng Việt Nam',
          artist: 'Tùng Dương',
          thumbnail: '',
          duration: Duration(minutes: 3, seconds: 52),
          externalUrl: 'https://zingmp3.vn/bai-hat/search-two.html',
        ),
        SearchSuggestionSong(
          id: 'search-three',
          title: 'Một Đời Người Một Rừng Cây',
          artist: 'Trọng Tấn',
          thumbnail: '',
          duration: Duration(minutes: 4, seconds: 21),
          externalUrl: 'https://zingmp3.vn/bai-hat/search-three.html',
        ),
      ],
    );

Future<CatalogHubHome> _loadHubHome() async => _hubHome;

const _docsFullSearchResult = CatalogSearchResult(
  query: 'chúng ta không thuộc về nhau',
  catalogPlaybackEnabled: true,
  songs: [
    CatalogSong(
      song: Song(
        id: 'search-song',
        name: 'search-song',
        title: 'Chúng Ta Không Thuộc Về Nhau',
        thumbnail: '',
        artistsNames: 'Sơn Tùng M-TP',
        code: 'search-song',
      ),
      duration: Duration(minutes: 3, seconds: 53),
      externalUrl: '',
      playable: true,
      hasLyrics: true,
      artists: [_artist],
      album: _artistTrackAlbum,
    ),
  ],
  artists: [],
  videos: [
    CatalogVideo(
      id: 'docs-video-one',
      title: 'Chúng Ta Không Thuộc Về Nhau (Official MV)',
      artist: 'Sơn Tùng M-TP',
      artists: [_artist],
      thumbnail: '',
      duration: Duration(minutes: 4, seconds: 2),
      externalUrl: 'https://zingmp3.vn/video-clip/chung-ta/docs-video-one.html',
    ),
    CatalogVideo(
      id: 'docs-video-two',
      title: 'Chúng Ta Không Thuộc Về Nhau (Live)',
      artist: 'Trịnh Đình Quang',
      thumbnail: '',
      duration: Duration(minutes: 4, seconds: 28),
      externalUrl: 'https://zingmp3.vn/video-clip/chung-ta/docs-video-two.html',
    ),
    CatalogVideo(
      id: 'docs-video-three',
      title: 'Ta Không Thuộc Về Nhau (MV Lyric)',
      artist: 'Trần Đình Tôn',
      thumbnail: '',
      duration: Duration(minutes: 4, seconds: 23),
      externalUrl:
          'https://zingmp3.vn/video-clip/chung-ta/docs-video-three.html',
    ),
    CatalogVideo(
      id: 'docs-video-four',
      title: 'Chúng Ta Không Thuộc Về Nhau (Remake)',
      artist: 'CesferKhoi',
      thumbnail: '',
      duration: Duration(minutes: 3, seconds: 56),
      externalUrl:
          'https://zingmp3.vn/video-clip/chung-ta/docs-video-four.html',
    ),
  ],
);

final _docsSongDetail = SongDetail(
  catalogSong: CatalogSong(
    song: _songs.first,
    duration: const Duration(minutes: 3, seconds: 48),
    externalUrl: 'https://zingmp3.vn/bai-hat/mot-doi/mot-doi.html',
    playable: true,
    hasLyrics: true,
  ),
  artists: const [
    CatalogArtist(
      id: 'docs-artist-detail',
      name: '14 Casper & Bon Nghiêm',
      aliasName: '14-Casper-Bon-Nghiem',
      avatar: '',
    ),
  ],
  album: const CatalogCollection(
    id: 'docs-album-detail',
    title: 'Một Đời (Single)',
    artist: '14 Casper & Bon Nghiêm',
    thumbnail: '',
    kind: CatalogCollectionKind.album,
    externalUrl: 'https://zingmp3.vn/album/mot-doi/docs-album-detail.html',
  ),
  releasedAt: DateTime(2026, 8, 12),
  distributor: 'Universal Music Vietnam',
  genres: const ['Việt Nam', 'V-Pop', 'Ballad'],
  composers: const [
    CatalogArtist(
      id: 'docs-composer-detail',
      name: 'Bon Nghiêm',
      aliasName: 'Bon-Nghiem',
      avatar: '',
    ),
  ],
  listenCount: 12854067,
  likeCount: 683214,
  commentCount: 1238,
  mv: const CatalogVideo(
    id: 'docs-mv-detail',
    title: 'Một Đời (Official MV)',
    artist: '14 Casper & Bon Nghiêm',
    thumbnail: '',
    duration: Duration(minutes: 3, seconds: 48),
    externalUrl: 'https://zingmp3.vn/video-clip/mot-doi/docs-mv-detail.html',
  ),
  catalogPlaybackEnabled: true,
);

Future<Top100Catalog> _loadTop100() async => _top100Catalog;

Future<ReleaseCatalog> _loadReleaseCatalog() async => _releaseCatalog;

Future<WeeklyChart> _loadWeeklyChart(
  WeeklyChartRegion region, {
  int? week,
  int? year,
}) async => _weeklyChart;

Future<CatalogArtistDetail> _loadArtistDetail(String _) async => _artistDetail;

const _songs = [
  Song(
    id: 'mot-doi',
    name: 'mot-doi',
    title: 'Một Đời',
    thumbnail: 'docs-fixture-album-art.webp',
    artistsNames: '14 Casper & Bon Nghiêm',
    code: 'mot-doi',
  ),
  Song(
    id: 'nang-tho',
    name: 'nang-tho',
    title: 'Nàng Thơ',
    thumbnail: '',
    artistsNames: 'Hoàng Dũng',
    code: 'nang-tho',
  ),
  Song(
    id: 'muon-roi-ma-sao-con',
    name: 'muon-roi-ma-sao-con',
    title: 'Muộn Rồi Mà Sao Còn',
    thumbnail: '',
    artistsNames: 'Sơn Tùng M-TP',
    code: 'muon-roi-ma-sao-con',
  ),
  Song(
    id: 'buoc-qua-mua-co-don',
    name: 'buoc-qua-mua-co-don',
    title: 'Bước Qua Mùa Cô Đơn',
    thumbnail: '',
    artistsNames: 'Vũ.',
    code: 'buoc-qua-mua-co-don',
  ),
  Song(
    id: 'see-tinh',
    name: 'see-tinh',
    title: 'See Tình',
    thumbnail: '',
    artistsNames: 'Hoàng Thùy Linh',
    code: 'see-tinh',
  ),
  Song(
    id: 'waiting-for-you',
    name: 'waiting-for-you',
    title: 'Waiting For You',
    thumbnail: '',
    artistsNames: 'MONO',
    code: 'waiting-for-you',
  ),
  Song(
    id: 'co-hen-voi-thanh-xuan',
    name: 'co-hen-voi-thanh-xuan',
    title: 'Có Hẹn Với Thanh Xuân',
    thumbnail: '',
    artistsNames: 'MONSTAR',
    code: 'co-hen-voi-thanh-xuan',
  ),
  Song(
    id: 'thich-em-hoi-nhieu',
    name: 'thich-em-hoi-nhieu',
    title: 'Thích Em Hơi Nhiều',
    thumbnail: '',
    artistsNames: 'Wren Evans',
    code: 'thich-em-hoi-nhieu',
  ),
];

const _docsRecommendationSongs = [
  ..._songs,
  Song(
    id: 'noi-nay-co-anh',
    name: 'noi-nay-co-anh',
    title: 'Nơi Này Có Anh',
    thumbnail: '',
    artistsNames: 'Sơn Tùng M-TP',
    code: 'noi-nay-co-anh',
  ),
];

const _docsChartArtists = [
  CatalogArtist(
    id: 'docs-chart-artist-14-casper',
    name: '14 Casper & Bon Nghiêm',
    aliasName: '14-Casper-Bon-Nghiem',
    avatar: '',
  ),
  CatalogArtist(
    id: 'docs-chart-artist-hoang-dung',
    name: 'Hoàng Dũng',
    aliasName: 'Hoang-Dung',
    avatar: '',
  ),
  CatalogArtist(
    id: 'docs-chart-artist-son-tung',
    name: 'Sơn Tùng M-TP',
    aliasName: 'Son-Tung-M-TP',
    avatar: '',
  ),
  CatalogArtist(
    id: 'docs-chart-artist-vu',
    name: 'Vũ.',
    aliasName: 'Vu',
    avatar: '',
  ),
  CatalogArtist(
    id: 'docs-chart-artist-hoang-thuy-linh',
    name: 'Hoàng Thùy Linh',
    aliasName: 'Hoang-Thuy-Linh',
    avatar: '',
  ),
  CatalogArtist(
    id: 'docs-chart-artist-mono',
    name: 'MONO',
    aliasName: 'MONO-Nguyen-Viet-Hoang',
    avatar: '',
  ),
  CatalogArtist(
    id: 'docs-chart-artist-monstar',
    name: 'MONSTAR',
    aliasName: 'MONSTAR',
    avatar: '',
  ),
  CatalogArtist(
    id: 'docs-chart-artist-wren-evans',
    name: 'Wren Evans',
    aliasName: 'Wren-Evans',
    avatar: '',
  ),
];

const _docsChartAlbums = [
  CatalogCollection(
    id: 'docs-chart-album-mot-doi',
    title: 'Một Đời',
    artist: '14 Casper & Bon Nghiêm',
    thumbnail: '',
    kind: CatalogCollectionKind.album,
    externalUrl: '',
  ),
  CatalogCollection(
    id: 'docs-chart-album-25',
    title: '25',
    artist: 'Hoàng Dũng',
    thumbnail: '',
    kind: CatalogCollectionKind.album,
    externalUrl: '',
  ),
  CatalogCollection(
    id: 'docs-chart-album-sky-decade',
    title: 'Sky Decade',
    artist: 'Sơn Tùng M-TP',
    thumbnail: '',
    kind: CatalogCollectionKind.album,
    externalUrl: '',
  ),
  CatalogCollection(
    id: 'docs-chart-album-mot-van-nam',
    title: 'Một Vạn Năm',
    artist: 'Vũ.',
    thumbnail: '',
    kind: CatalogCollectionKind.album,
    externalUrl: '',
  ),
  CatalogCollection(
    id: 'docs-chart-album-see-tinh',
    title: 'See Tình (Single)',
    artist: 'Hoàng Thùy Linh',
    thumbnail: '',
    kind: CatalogCollectionKind.album,
    externalUrl: '',
  ),
  CatalogCollection(
    id: 'docs-chart-album-waiting-for-you',
    title: 'Waiting For You (Single)',
    artist: 'MONO',
    thumbnail: '',
    kind: CatalogCollectionKind.album,
    externalUrl: '',
  ),
  CatalogCollection(
    id: 'docs-chart-album-co-hen-voi-thanh-xuan',
    title: 'Có Hẹn Với Thanh Xuân (Single)',
    artist: 'MONSTAR',
    thumbnail: '',
    kind: CatalogCollectionKind.album,
    externalUrl: '',
  ),
  CatalogCollection(
    id: 'docs-chart-album-thich-em-hoi-nhieu',
    title: 'Thích Em Hơi Nhiều (Single)',
    artist: 'Wren Evans',
    thumbnail: '',
    kind: CatalogCollectionKind.album,
    externalUrl: '',
  ),
];

const _docsChartExtraSongs = [
  Song(
    id: 'cho-em-gan-anh-them-chut-nua',
    name: 'cho-em-gan-anh-them-chut-nua',
    title: 'Cho Em Gần Anh Thêm Chút Nữa',
    thumbnail: '',
    artistsNames: 'Hương Tràm',
    code: 'cho-em-gan-anh-them-chut-nua',
  ),
  Song(
    id: 'la-lung',
    name: 'la-lung',
    title: 'Lạ Lùng',
    thumbnail: '',
    artistsNames: 'Vũ.',
    code: 'la-lung',
  ),
  Song(
    id: 'chuyen-doi-ta',
    name: 'chuyen-doi-ta',
    title: 'Chuyện Đôi Ta',
    thumbnail: '',
    artistsNames: 'Emcee L, Muộii',
    code: 'chuyen-doi-ta',
  ),
  Song(
    id: 'co-em',
    name: 'co-em',
    title: 'Có Em',
    thumbnail: '',
    artistsNames: 'Madihu, Low G',
    code: 'co-em',
  ),
];

const _docsChartFeaturedSongs = [..._songs, ..._docsChartExtraSongs];

final _docsChartSongs = List<Song>.generate(
  100,
  (index) => index < _docsChartFeaturedSongs.length
      ? _docsChartFeaturedSongs[index]
      : Song(
          id: 'docs-chart-${index + 1}',
          name: 'docs-chart-${index + 1}',
          title: 'Bài Hát Trong Top ${index + 1}',
          thumbnail: '',
          artistsNames: 'Nghệ Sĩ Zing ${index + 1}',
          code: 'docs-chart-code-${index + 1}',
        ),
  growable: false,
);

const _docsChartSuggestionSong = Song(
  id: 'docs-chart-suggestion',
  name: 'buoc-qua-nhau',
  title: 'Bước Qua Nhau',
  thumbnail: '',
  artistsNames: 'Vũ.',
  code: 'docs-chart-suggestion',
);

const _docsChartSuggestionArtist = CatalogArtist(
  id: 'docs-chart-suggestion-artist-vu',
  name: 'Vũ.',
  aliasName: 'Vu',
  avatar: '',
);

const _docsChartSuggestionAlbum = CatalogCollection(
  id: 'docs-chart-suggestion-album-buoc-qua-nhau',
  title: 'Bước Qua Nhau (Single)',
  artist: 'Vũ.',
  thumbnail: '',
  kind: CatalogCollectionKind.album,
  externalUrl: '',
);

const _docsChartSuggestion = DiscoveryRecommendations(
  updatedAt: null,
  entries: [
    CatalogSong(
      song: _docsChartSuggestionSong,
      duration: Duration(minutes: 4, seconds: 2),
      externalUrl: '',
      playable: true,
      artists: [_docsChartSuggestionArtist],
      album: _docsChartSuggestionAlbum,
    ),
  ],
  catalogPlaybackEnabled: true,
);

final _docsChartSnapshot = ChartSnapshot(
  songs: _docsChartSongs,
  songMetadata: {
    for (var index = 0; index < _docsChartSongs.length; index++)
      _docsChartSongs[index].id: ChartSongMetadata(
        albumTitle: index < 4
            ? '${_docsChartSongs[index].displayTitle} (Single)'
            : '',
        duration: Duration(seconds: 198 + index * 11),
        rankChange: index == 0
            ? 3
            : index == 1
            ? -1
            : 0,
      ),
  },
  series: {
    for (var songIndex = 0; songIndex < 3; songIndex++)
      _songs[songIndex].id: [
        for (var hour = 0; hour < 8; hour++)
          ChartPoint(
            time: DateTime(2026, 8, 21, hour * 3),
            hour: (hour * 3).toString().padLeft(2, '0'),
            counter: 28 + songIndex * 14 + ((hour * 17 + songIndex * 9) % 48),
          ),
      ],
  },
  minScore: 20,
  maxScore: 100,
  updatedAt: DateTime(2026, 8, 21, 21),
);

final _docsRadio = SongRadio(
  seedId: _songs.first.code,
  recommendations: _songs
      .skip(1)
      .take(6)
      .map(
        (song) => CatalogSong(
          song: song,
          duration: const Duration(minutes: 3, seconds: 36),
          externalUrl: 'https://zingmp3.vn/bai-hat/${song.id}',
          playable: true,
        ),
      )
      .toList(growable: false),
);

const _liveRadio = LiveRadioSnapshot(
  updatedAt: null,
  rooms: [
    LiveRadioRoom(
      id: 'vpop',
      title: 'V-POP',
      description: 'Nhạc Việt đang thịnh hành',
      thumbnail: '',
      listenerCount: 12500,
      hostName: 'Zing MP3',
      hostThumbnail: '',
      program: LiveRadioProgram(
        id: 'vpop-today',
        title: 'Nhạc Việt hôm nay',
        thumbnail: '',
        description: 'Chương trình tuyển chọn V-Pop',
        startTime: null,
        endTime: null,
      ),
    ),
    LiveRadioRoom(
      id: 'cham',
      title: 'Chạm',
      description: 'Những cảm xúc dịu dàng',
      thumbnail: '',
      listenerCount: 9800,
      hostName: 'Zing MP3',
      hostThumbnail: '',
    ),
    LiveRadioRoom(
      id: 'bolero',
      title: 'Bolero',
      description: 'Tình khúc vượt thời gian',
      thumbnail: '',
      listenerCount: 8700,
      hostName: 'Zing MP3',
      hostThumbnail: '',
    ),
    LiveRadioRoom(
      id: 'usuk',
      title: 'US-UK',
      description: 'Pop quốc tế nổi bật',
      thumbnail: '',
      listenerCount: 7100,
      hostName: 'Zing MP3',
      hostThumbnail: '',
    ),
    LiveRadioRoom(
      id: 'kpop',
      title: 'K-POP',
      description: 'K-Pop không ngừng nghỉ',
      thumbnail: '',
      listenerCount: 6400,
      hostName: 'Zing MP3',
      hostThumbnail: '',
    ),
    LiveRadioRoom(
      id: 'acoustic',
      title: 'Acoustic',
      description: 'Giai điệu mộc cho ngày mới',
      thumbnail: '',
      listenerCount: 4200,
      hostName: 'Zing MP3',
      hostThumbnail: '',
    ),
  ],
);

const _docsLyrics = SongLyrics(
  songId: 'mot-doi',
  synced: true,
  lines: [
    LyricLine(
      start: Duration(seconds: 6),
      end: Duration(seconds: 14),
      text: 'Có những ngày thành phố chậm hơn một nhịp',
    ),
    LyricLine(
      start: Duration(seconds: 15),
      end: Duration(seconds: 23),
      text: 'Mình nghe thanh xuân đi qua ô cửa nhỏ',
    ),
    LyricLine(
      start: Duration(seconds: 24),
      end: Duration(seconds: 32),
      text: 'Giữ một giai điệu ở lại giữa bàn tay',
    ),
    LyricLine(
      start: Duration(seconds: 33),
      end: Duration(seconds: 41),
      text: 'Và hát cho đêm nay sáng lên',
    ),
    LyricLine(
      start: Duration(seconds: 42),
      end: Duration(seconds: 50),
      text: 'Từng nhịp tim vẫn đang ngân vang',
    ),
    LyricLine(
      start: Duration(seconds: 51),
      end: Duration(seconds: 59),
      text: 'Đưa mình về gần nhau hơn',
    ),
    LyricLine(
      start: Duration(seconds: 60),
      end: Duration(seconds: 68),
      text: 'Dẫu mai này đường xa đến đâu',
    ),
    LyricLine(
      start: Duration(seconds: 69),
      end: Duration(seconds: 82),
      text: 'Khoảnh khắc này vẫn còn ở đây',
      words: [
        LyricWord(
          start: Duration(seconds: 69),
          end: Duration(seconds: 71),
          text: 'Khoảnh',
        ),
        LyricWord(
          start: Duration(seconds: 71),
          end: Duration(seconds: 73),
          text: 'khắc',
        ),
        LyricWord(
          start: Duration(seconds: 73),
          end: Duration(seconds: 75),
          text: 'này',
        ),
        LyricWord(
          start: Duration(seconds: 75),
          end: Duration(seconds: 77),
          text: 'vẫn',
        ),
        LyricWord(
          start: Duration(seconds: 77),
          end: Duration(seconds: 79),
          text: 'còn',
        ),
        LyricWord(
          start: Duration(seconds: 79),
          end: Duration(seconds: 80),
          text: 'ở',
        ),
        LyricWord(
          start: Duration(seconds: 80),
          end: Duration(seconds: 82),
          text: 'đây',
        ),
      ],
    ),
    LyricLine(
      start: Duration(seconds: 83),
      end: Duration(seconds: 91),
      text: 'Mỗi câu hát nối liền những giấc mơ',
    ),
    LyricLine(
      start: Duration(seconds: 92),
      end: Duration(seconds: 102),
      text: 'Cho một đời luôn nhớ về nhau',
    ),
  ],
);

const _artist = CatalogArtist(
  id: 'docs-son-tung',
  name: 'Sơn Tùng M-TP',
  aliasName: 'Son-Tung-M-TP',
  avatar: '',
  totalFollow: 2655838,
);

const _docsCollectionArtists = [
  _artist,
  CatalogArtist(
    id: 'mono',
    name: 'MONO',
    aliasName: 'MONO-Nguyen-Viet-Hoang',
    avatar: '',
    totalFollow: 1084200,
  ),
  CatalogArtist(
    id: 'soobin',
    name: 'SOOBIN',
    aliasName: 'SOOBIN',
    avatar: '',
    totalFollow: 782400,
  ),
  CatalogArtist(
    id: 'hieuthuhai',
    name: 'HIEUTHUHAI',
    aliasName: 'HIEUTHUHAI',
    avatar: '',
    totalFollow: 936700,
  ),
  CatalogArtist(
    id: 'touliver',
    name: 'Touliver',
    aliasName: 'Touliver',
    avatar: '',
    totalFollow: 342800,
  ),
  CatalogArtist(
    id: 'onionn',
    name: 'Onionn.',
    aliasName: 'Onionn',
    avatar: '',
    totalFollow: 185600,
  ),
];

const _artistSongs = [
  Song(
    id: 'noi-nay-co-anh',
    name: 'noi-nay-co-anh',
    title: 'Nơi Này Có Anh',
    thumbnail: '',
    artistsNames: 'Sơn Tùng M-TP',
    code: 'noi-nay-co-anh',
  ),
  Song(
    id: 'chay-ngay-di',
    name: 'chay-ngay-di',
    title: 'Chạy Ngay Đi',
    thumbnail: '',
    artistsNames: 'Sơn Tùng M-TP',
    code: 'chay-ngay-di',
  ),
  Song(
    id: 'chung-ta-cua-hien-tai',
    name: 'chung-ta-cua-hien-tai',
    title: 'Chúng Ta Của Hiện Tại',
    thumbnail: '',
    artistsNames: 'Sơn Tùng M-TP',
    code: 'chung-ta-cua-hien-tai',
  ),
  Song(
    id: 'hay-trao-cho-anh',
    name: 'hay-trao-cho-anh',
    title: 'Hãy Trao Cho Anh',
    thumbnail: '',
    artistsNames: 'Sơn Tùng M-TP, Snoop Dogg',
    code: 'hay-trao-cho-anh',
  ),
];

const _artistTrackAlbum = CatalogCollection(
  id: 'chung-ta-cua-tuong-lai',
  title: 'Chúng Ta Của Tương Lai',
  artist: 'Sơn Tùng M-TP',
  thumbnail: 'docs-fixture-album-art.webp',
  kind: CatalogCollectionKind.album,
  externalUrl: '',
);

final _artistDetail = CatalogArtistDetail(
  artist: _artist,
  cover: '',
  biography:
      'Sơn Tùng M-TP là ca sĩ, nhạc sĩ và nhà sản xuất âm nhạc Việt Nam. '
      'Anh được biết đến qua phong cách biểu diễn hiện đại cùng nhiều ca khúc '
      'V-Pop nổi bật, tạo dấu ấn mạnh mẽ với khán giả trẻ.',
  realName: 'Nguyễn Thanh Tùng',
  national: 'Việt Nam',
  birthday: '05/07/1994',
  totalFollow: 2655838,
  awardCount: 12,
  featuredSongs: [
    for (final song in _artistSongs.take(3))
      CatalogSong(
        song: song,
        duration: Duration(minutes: 4),
        externalUrl: '',
        playable: true,
        artists: const [_artist],
        album: _artistTrackAlbum,
      ),
  ],
  songs: [
    for (final song in _artistSongs)
      CatalogSong(
        song: song,
        duration: Duration(minutes: 4),
        externalUrl: '',
        playable: true,
        artists: const [_artist],
        album: _artistTrackAlbum,
      ),
  ],
  videos: const [
    CatalogVideo(
      id: 'chung-ta-cua-tuong-lai-mv',
      title: 'Chúng Ta Của Tương Lai',
      artist: 'Sơn Tùng M-TP',
      thumbnail: '',
      duration: Duration(minutes: 4, seconds: 37),
      externalUrl:
          'https://zingmp3.vn/video-clip/chung-ta-cua-tuong-lai/chung-ta-cua-tuong-lai-mv.html',
    ),
    CatalogVideo(
      id: 'hay-trao-cho-anh-mv',
      title: 'Hãy Trao Cho Anh',
      artist: 'Sơn Tùng M-TP, Snoop Dogg',
      thumbnail: '',
      duration: Duration(minutes: 4, seconds: 5),
      externalUrl:
          'https://zingmp3.vn/video-clip/hay-trao-cho-anh/hay-trao-cho-anh-mv.html',
    ),
    CatalogVideo(
      id: 'noi-nay-co-anh-mv',
      title: 'Nơi Này Có Anh',
      artist: 'Sơn Tùng M-TP',
      thumbnail: '',
      duration: Duration(minutes: 4, seconds: 38),
      externalUrl:
          'https://zingmp3.vn/video-clip/noi-nay-co-anh/noi-nay-co-anh-mv.html',
    ),
  ],
  collectionSections: [
    CatalogArtistCollectionSection(
      id: 'single-ep',
      title: 'Single & EP',
      collections: [
        _artistTrackAlbum,
        CatalogCollection(
          id: 'making-my-way',
          title: 'Making My Way',
          artist: 'Sơn Tùng M-TP',
          thumbnail: '',
          kind: CatalogCollectionKind.album,
          externalUrl: '',
        ),
        CatalogCollection(
          id: 'muon-roi-ma-sao-con-single',
          title: 'Muộn Rồi Mà Sao Còn',
          artist: 'Sơn Tùng M-TP',
          thumbnail: '',
          kind: CatalogCollectionKind.album,
          externalUrl: '',
        ),
      ],
    ),
    CatalogArtistCollectionSection(
      id: 'appears-on',
      title: 'Xuất Hiện Trong',
      collections: [
        CatalogCollection(
          id: 'best-of-vpop',
          title: 'Best Of V-Pop',
          artist: 'Nhiều nghệ sĩ',
          thumbnail: '',
          kind: CatalogCollectionKind.playlist,
          externalUrl: '',
        ),
        CatalogCollection(
          id: 'vpop-hits',
          title: 'V-Pop Hits',
          artist: 'Nhiều nghệ sĩ',
          thumbnail: '',
          kind: CatalogCollectionKind.playlist,
          externalUrl: '',
        ),
      ],
    ),
  ],
  relatedArtists: [
    CatalogArtist(
      id: 'mono',
      name: 'MONO',
      aliasName: 'MONO-Nguyen-Viet-Hoang',
      avatar: '',
    ),
    CatalogArtist(
      id: 'soobin',
      name: 'SOOBIN',
      aliasName: 'SOOBIN',
      avatar: '',
    ),
    CatalogArtist(
      id: 'hieuthuhai',
      name: 'HIEUTHUHAI',
      aliasName: 'HIEUTHUHAI',
      avatar: '',
    ),
  ],
  catalogPlaybackEnabled: true,
);

final _docsCollectionDetail = CatalogCollectionDetail(
  collection: _artistDetail.collectionSections.first.collections.first,
  artists: _docsCollectionArtists,
  description:
      'Tuyển tập chính thức được lưu vào thư viện trên thiết bị, với metadata '
      'bài hát và điều hướng nghệ sĩ/album từ Zing MP3.',
  year: '2026',
  releasedAt: DateTime.utc(2026, 8, 3),
  distributor: 'VIVI ENM',
  likeCount: 2200000,
  genres: const ['V-Pop'],
  songs: [
    for (var index = 0; index < _artistSongs.length; index++)
      CatalogSong(
        song: _artistSongs[index],
        duration: Duration(seconds: 238 + index * 11),
        externalUrl: '',
        playable: index != 1,
        artists: const [_artist],
        album: _artistDetail.collectionSections.first.collections.first,
      ),
  ],
  sections: [
    CatalogCollectionSection(
      id: 'appears-in',
      title: 'Sơn Tùng M-TP Xuất Hiện Trong',
      collections: [
        ..._artistDetail.collectionSections.first.collections,
        const CatalogCollection(
          id: 'noi-nay-co-anh-collection',
          title: 'Nơi Này Có Anh',
          artist: 'Sơn Tùng M-TP',
          thumbnail: '',
          kind: CatalogCollectionKind.album,
          externalUrl: '',
        ),
        const CatalogCollection(
          id: 'hay-trao-cho-anh-collection',
          title: 'Hãy Trao Cho Anh',
          artist: 'Sơn Tùng M-TP, Snoop Dogg',
          thumbnail: '',
          kind: CatalogCollectionKind.album,
          externalUrl: '',
        ),
        const CatalogCollection(
          id: 'sky-tour-collection',
          title: 'Sky Tour Selection',
          artist: 'Sơn Tùng M-TP',
          thumbnail: '',
          kind: CatalogCollectionKind.playlist,
          externalUrl: '',
        ),
        const CatalogCollection(
          id: 'vpop-iconic-collection',
          title: 'V-Pop Iconic',
          artist: 'Nhiều nghệ sĩ',
          thumbnail: '',
          kind: CatalogCollectionKind.playlist,
          externalUrl: '',
        ),
        const CatalogCollection(
          id: 'chill-cung-son-tung',
          title: 'Chill Cùng Sơn Tùng M-TP',
          artist: 'Sơn Tùng M-TP',
          thumbnail: '',
          kind: CatalogCollectionKind.playlist,
          externalUrl: '',
        ),
      ],
    ),
    CatalogCollectionSection(
      id: 'you-may-care',
      title: 'Có Thể Bạn Quan Tâm',
      collections: _artistDetail.collectionSections[1].collections,
    ),
  ],
  catalogPlaybackEnabled: true,
);

final _newReleaseChart = NewReleaseChart(
  title: 'BXH Nhạc Mới',
  updatedAt: DateTime.utc(2026, 8, 21, 12),
  catalogPlaybackEnabled: true,
  entries: [
    for (var index = 0; index < _songs.length; index++)
      NewReleaseEntry(
        catalogSong: CatalogSong(
          song: _songs[index],
          duration: Duration(seconds: 196 + index * 9),
          externalUrl: 'https://zingmp3.vn/bai-hat/${_songs[index].id}',
          playable: index != 5,
          artists: [_docsChartArtists[index]],
          album: _docsChartAlbums[index],
        ),
        albumTitle: switch (index) {
          0 => 'Một Đời',
          1 => '25',
          2 => 'Sky Decade',
          3 => 'Một Vạn Năm',
          _ => 'Zing MP3 Selection',
        },
        rank: index + 1,
        rankChange: switch (index) {
          0 => 2,
          1 => -1,
          2 => 0,
          _ => index.isEven ? 1 : -2,
        },
        releasedAt: DateTime.utc(2026, 8, 21 - index),
      ),
  ],
);

final _docsNewReleaseChartSpotlightEntries = [
  _newReleaseChart.entries[0],
  NewReleaseEntry(
    catalogSong: CatalogSong(
      song: _newReleaseChart.entries[1].song,
      duration: _newReleaseChart.entries[1].catalogSong.duration,
      externalUrl: _newReleaseChart.entries[1].catalogSong.externalUrl,
      playable: false,
      artists: _newReleaseChart.entries[1].catalogSong.artists,
      album: _newReleaseChart.entries[1].catalogSong.album,
    ),
    albumTitle: _newReleaseChart.entries[1].albumTitle,
    rank: 2,
    rankChange: -1,
    releasedAt: _newReleaseChart.entries[1].releasedAt,
  ),
  _newReleaseChart.entries[2],
];

final _weeklyChart = WeeklyChart(
  region: WeeklyChartRegion.vietnam,
  title: 'Bảng Xếp Hạng Tuần',
  week: 33,
  year: 2026,
  latestWeek: 33,
  startDate: '10/08',
  endDate: '16/08',
  updatedAt: DateTime.utc(2026, 8, 16, 17),
  catalogPlaybackEnabled: true,
  entries: [
    for (var index = 0; index < _songs.length; index++)
      WeeklyChartEntry(
        catalogSong: CatalogSong(
          song: _songs[index],
          duration: Duration(seconds: 196 + index * 9),
          externalUrl: 'https://zingmp3.vn/bai-hat/${_songs[index].id}',
          playable: index != 5,
          artists: [_docsChartArtists[index]],
          album: _docsChartAlbums[index],
        ),
        albumTitle: switch (index) {
          0 => 'Một Đời',
          1 => '25',
          2 => 'Sky Decade',
          3 => 'Một Vạn Năm',
          _ => 'Zing MP3 Selection',
        },
        rank: index + 1,
        rankChange: switch (index) {
          0 => 2,
          1 => -1,
          2 => 0,
          _ => index.isEven ? 1 : -2,
        },
        score: 2600 - index * 175,
      ),
  ],
);

const _docsReleaseArtist = CatalogArtist(
  id: 'docs-release-artist',
  name: '14 Casper & Bon Nghiêm',
  aliasName: '14-Casper-Bon-Nghiem',
  avatar: '',
);

const _docsReleaseTrackAlbum = CatalogCollection(
  id: 'docs-release-track-album',
  title: 'Một Đời (Album)',
  artist: '14 Casper & Bon Nghiêm',
  thumbnail: '',
  kind: CatalogCollectionKind.album,
  externalUrl: '',
);

final _releaseCatalog = ReleaseCatalog(
  updatedAt: DateTime.utc(2026, 8, 21, 12),
  catalogPlaybackEnabled: true,
  songs: [
    for (var index = 0; index < _songs.length; index++)
      ReleaseSong(
        catalogSong: CatalogSong(
          song: _songs[index],
          duration: Duration(seconds: 196 + index * 9),
          externalUrl: 'https://zingmp3.vn/bai-hat/${_songs[index].id}',
          playable: index != 5,
          artists: const [_docsReleaseArtist],
          album: _docsReleaseTrackAlbum,
        ),
        releasedAt: DateTime.utc(2026, 8, 21 - index),
        region: switch (index) {
          0 || 1 || 2 || 3 => ReleaseRegion.vietnam,
          4 => ReleaseRegion.korea,
          5 || 6 => ReleaseRegion.usuk,
          _ => ReleaseRegion.other,
        },
      ),
  ],
  albums: [
    ReleaseAlbum(
      collection: const CatalogCollection(
        id: 'docs-release-album-one',
        title: 'Một Đời (Album)',
        artist: '14 Casper & Bon Nghiêm',
        thumbnail: '',
        kind: CatalogCollectionKind.album,
        externalUrl: '',
      ),
      releasedAt: DateTime.utc(2026, 8, 21),
      region: ReleaseRegion.vietnam,
    ),
    ReleaseAlbum(
      collection: const CatalogCollection(
        id: 'docs-release-album-two',
        title: '25',
        artist: 'Hoàng Dũng',
        thumbnail: '',
        kind: CatalogCollectionKind.album,
        externalUrl: '',
      ),
      releasedAt: DateTime.utc(2026, 8, 20),
      region: ReleaseRegion.vietnam,
    ),
    ReleaseAlbum(
      collection: const CatalogCollection(
        id: 'docs-release-album-three',
        title: 'Seoul After Midnight',
        artist: 'K Artist',
        thumbnail: '',
        kind: CatalogCollectionKind.album,
        externalUrl: '',
      ),
      releasedAt: DateTime.utc(2026, 8, 19),
      region: ReleaseRegion.korea,
    ),
  ],
);

final List<ReleaseSong> _docsHomeReleaseSongs = List.generate(12, (index) {
  final base = _songs[index % _songs.length];
  return ReleaseSong(
    catalogSong: CatalogSong(
      song: Song(
        id: 'docs-home-release-$index',
        name: 'docs-home-release-$index',
        title: base.displayTitle,
        thumbnail: base.thumbnail,
        artistsNames: base.artistsNames,
        code: 'docs-home-release-code-$index',
      ),
      duration: Duration(seconds: 196 + index * 7),
      externalUrl: '',
      playable: index != 7,
    ),
    releasedAt: null,
    region: index < 6
        ? ReleaseRegion.vietnam
        : index < 10
        ? ReleaseRegion.usuk
        : ReleaseRegion.korea,
  );
}, growable: false);

const _topCollection = CatalogCollection(
  id: 'docs-top-100',
  title: 'Top 100 Nhạc V-Pop Hay Nhất',
  artist: 'Dương Domic, Quang Hùng MasterD',
  thumbnail: '',
  kind: CatalogCollectionKind.playlist,
  externalUrl: '',
);

const _discoveryHome = DiscoveryHome(
  updatedAt: null,
  quickPlay: [
    DiscoveryCollection(
      collection: _topCollection,
      description: 'BXH V-Pop được mở nhiều nhất hôm nay.',
    ),
    DiscoveryCollection(
      collection: CatalogCollection(
        id: 'docs-remix-trending',
        title: 'Remix Thịnh Hành',
        artist: 'Du Uyên, Linh Hương Luz, Oanh Tạ',
        thumbnail: '',
        kind: CatalogCollectionKind.playlist,
        externalUrl: '',
      ),
      description: 'Những bản remix đang gây chú ý.',
    ),
    DiscoveryCollection(
      collection: CatalogCollection(
        id: 'docs-ballad-light',
        title: 'Nhạc Ballad Nhẹ Nhàng Gây Nghiện',
        artist: 'Khả Hiệp, Mochiii, Thanh Hưng',
        thumbnail: '',
        kind: CatalogCollectionKind.playlist,
        externalUrl: '',
      ),
      description: 'Ballad nhẹ nhàng cho một ngày thư thái.',
    ),
  ],
  banners: [
    DiscoveryBanner(id: 'docs-featured', image: '', collection: _topCollection),
  ],
  videos: [
    CatalogVideo(
      id: 'docs-discovery-video-one',
      title: 'Chúng Ta Của Tương Lai (Official MV)',
      artist: 'Sơn Tùng M-TP',
      thumbnail: '',
      duration: Duration(minutes: 4, seconds: 32),
      externalUrl:
          'https://zingmp3.vn/video-clip/chung-ta-cua-tuong-lai/docs-discovery-video-one.html',
    ),
    CatalogVideo(
      id: 'docs-discovery-video-two',
      title: 'Hãy Trao Cho Anh (Official MV)',
      artist: 'Sơn Tùng M-TP, Snoop Dogg',
      thumbnail: '',
      duration: Duration(minutes: 4, seconds: 5),
      externalUrl:
          'https://zingmp3.vn/video-clip/hay-trao-cho-anh/docs-discovery-video-two.html',
    ),
    CatalogVideo(
      id: 'docs-discovery-video-three',
      title: 'Nơi Này Có Anh (Official MV)',
      artist: 'Sơn Tùng M-TP',
      thumbnail: '',
      duration: Duration(minutes: 4, seconds: 38),
      externalUrl:
          'https://zingmp3.vn/video-clip/noi-nay-co-anh/docs-discovery-video-three.html',
    ),
    CatalogVideo(
      id: 'docs-discovery-video-four',
      title: 'Có Chắc Yêu Là Đây (Official MV)',
      artist: 'Sơn Tùng M-TP',
      thumbnail: '',
      duration: Duration(minutes: 3, seconds: 22),
      externalUrl:
          'https://zingmp3.vn/video-clip/co-chac-yeu-la-day/docs-discovery-video-four.html',
    ),
  ],
  sections: [
    DiscoverySection(
      id: 'top-100',
      title: 'Top 100',
      collections: [
        DiscoveryCollection(
          collection: _topCollection,
          description: 'Những ca khúc được nghe nhiều nhất hiện tại.',
        ),
        DiscoveryCollection(
          collection: CatalogCollection(
            id: 'docs-top-usuk',
            title: 'Top 100 Pop Âu Mỹ Hay Nhất',
            artist: 'Taylor Swift, Sabrina Carpenter',
            thumbnail: '',
            kind: CatalogCollectionKind.playlist,
            externalUrl: '',
          ),
          description: 'Các giai điệu quốc tế nổi bật.',
        ),
        DiscoveryCollection(
          collection: CatalogCollection(
            id: 'docs-top-kpop',
            title: 'Top 100 Nhạc Hàn Quốc',
            artist: 'aespa, BLACKPINK',
            thumbnail: '',
            kind: CatalogCollectionKind.playlist,
            externalUrl: '',
          ),
          description: 'K-Pop được yêu thích nhất.',
        ),
      ],
    ),
    DiscoverySection(
      id: 'chill',
      title: 'Chill',
      collections: [
        DiscoveryCollection(
          collection: CatalogCollection(
            id: 'docs-chill-one',
            title: 'Ngắm Nhìn Những Suy Tư',
            artist: 'Nhiều nghệ sĩ',
            thumbnail: '',
            kind: CatalogCollectionKind.playlist,
            externalUrl: '',
          ),
          description: 'Về với chính mình trong phiên bản mộc mạc nhất.',
        ),
        DiscoveryCollection(
          collection: CatalogCollection(
            id: 'docs-chill-two',
            title: 'Lắng Đọng Cùng Acoustic Việt',
            artist: 'Nhiều nghệ sĩ',
            thumbnail: '',
            kind: CatalogCollectionKind.playlist,
            externalUrl: '',
          ),
          description: 'Lắng đọng cảm xúc sau một ngày dài.',
        ),
      ],
    ),
    DiscoverySection(
      id: 'album-hot',
      title: 'Album Hot',
      collections: [
        DiscoveryCollection(
          collection: CatalogCollection(
            id: 'docs-album-one',
            title: 'Về Nhà Em Nhé (Single)',
            artist: 'Thoại Nghi, Nguyễn Trung Đức, ICM',
            thumbnail: '',
            kind: CatalogCollectionKind.album,
            externalUrl: '',
          ),
          description: '',
        ),
      ],
    ),
  ],
);

const _discoveryCategories = DiscoveryCategories(
  updatedAt: null,
  items: [
    DiscoveryCategory(id: '14', name: 'Thư giãn'),
    DiscoveryCategory(id: '13', name: 'Làm việc'),
    DiscoveryCategory(id: '21', name: 'Trending'),
    DiscoveryCategory(id: '18', name: 'Ngủ ngon'),
    DiscoveryCategory(id: '15', name: 'Tập luyện'),
  ],
);

const _hubHome = CatalogHubHome(
  updatedAt: null,
  featured: [
    CatalogHub(
      id: 'docs-top100-hub',
      title: 'Top 100',
      description: 'Playlist được nghe nhiều nhất.',
      image: '',
      externalUrl: '',
    ),
    CatalogHub(
      id: 'docs-new-release-hub',
      title: 'BXH Nhạc Mới',
      description: 'Ca khúc mới đang thịnh hành.',
      image: '',
      externalUrl: '',
    ),
    CatalogHub(
      id: 'docs-best-of-hub',
      title: 'Best Of 2026',
      description: 'Dấu ấn âm nhạc của năm.',
      image: '',
      externalUrl: '',
    ),
  ],
  nations: [
    CatalogHub(
      id: 'docs-vietnam',
      title: 'Việt Nam',
      description: '',
      image: '',
      externalUrl: '',
    ),
    CatalogHub(
      id: 'docs-usuk',
      title: 'Âu Mỹ',
      description: '',
      image: '',
      externalUrl: '',
    ),
    CatalogHub(
      id: 'docs-korea',
      title: 'Hàn Quốc',
      description: '',
      image: '',
      externalUrl: '',
    ),
    CatalogHub(
      id: 'docs-china',
      title: 'Hoa Ngữ',
      description: '',
      image: '',
      externalUrl: '',
    ),
  ],
  topics: [
    CatalogHub(
      id: 'docs-sleep',
      title: 'Ngủ ngon',
      description: 'Thả lỏng và nghỉ ngơi.',
      image: '',
      externalUrl: '',
    ),
    CatalogHub(
      id: 'docs-workout',
      title: 'Workout',
      description: 'Năng lượng cho từng chuyển động.',
      image: '',
      externalUrl: '',
    ),
    CatalogHub(
      id: 'docs-focus',
      title: 'Tập trung',
      description: 'Không gian cho công việc.',
      image: '',
      externalUrl: '',
    ),
    CatalogHub(
      id: 'docs-chill',
      title: 'Chill',
      description: 'Chậm lại một chút.',
      image: '',
      externalUrl: '',
    ),
  ],
  genres: [
    CatalogHub(
      id: 'docs-vpop',
      title: 'V-Pop',
      description: 'Nhạc Việt nổi bật.',
      image: '',
      externalUrl: '',
      collections: [
        DiscoveryCollection(
          collection: _topCollection,
          description: 'Các ca khúc Việt được yêu thích nhất.',
        ),
        DiscoveryCollection(
          collection: CatalogCollection(
            id: 'docs-vpop-acoustic',
            title: 'Acoustic Việt Cho Ngày Dịu Dàng',
            artist: 'Nhiều nghệ sĩ',
            thumbnail: '',
            kind: CatalogCollectionKind.playlist,
            externalUrl: '',
          ),
          description: 'Thanh âm mộc mạc, gần gũi.',
        ),
      ],
    ),
  ],
);

const _top100Catalog = Top100Catalog(
  updatedAt: null,
  sections: [
    DiscoverySection(
      id: 'docs-top100-featured',
      title: 'Nổi bật',
      collections: [
        DiscoveryCollection(
          collection: _topCollection,
          description: 'Những ca khúc được nghe nhiều nhất hiện tại.',
        ),
        DiscoveryCollection(
          collection: CatalogCollection(
            id: 'docs-top100-usuk-card',
            title: 'Top 100 Pop Âu Mỹ Hay Nhất',
            artist: 'Taylor Swift, Sabrina Carpenter',
            thumbnail: '',
            kind: CatalogCollectionKind.playlist,
            externalUrl: '',
          ),
          description: 'Các giai điệu quốc tế nổi bật.',
        ),
      ],
    ),
    DiscoverySection(
      id: 'docs-top100-vietnam',
      title: 'Nhạc Việt Nam',
      collections: [
        DiscoveryCollection(
          collection: _topCollection,
          description: '100 ca khúc V-Pop được yêu thích nhất.',
        ),
        DiscoveryCollection(
          collection: CatalogCollection(
            id: 'docs-top100-tru-tinh',
            title: 'Top 100 Nhạc Trữ Tình Hay Nhất',
            artist: 'Nhiều nghệ sĩ',
            thumbnail: '',
            kind: CatalogCollectionKind.playlist,
            externalUrl: '',
          ),
          description: 'Những tình khúc đi cùng năm tháng.',
        ),
      ],
    ),
    DiscoverySection(
      id: 'docs-top100-asia',
      title: 'Nhạc Châu Á',
      collections: [
        DiscoveryCollection(
          collection: CatalogCollection(
            id: 'docs-top100-korea',
            title: 'Top 100 Nhạc Hàn Quốc Hay Nhất',
            artist: 'aespa, BLACKPINK',
            thumbnail: '',
            kind: CatalogCollectionKind.playlist,
            externalUrl: '',
          ),
          description: 'K-Pop nổi bật hiện tại.',
        ),
      ],
    ),
  ],
);

PlayerSnapshot _librarySnapshot() {
  final now = DateTime.now().toUtc();
  final history = <ListeningRecord>[
    for (var index = 0; index < 12; index++)
      ListeningRecord(
        id: 'docs-history-$index',
        song: _songs[index % _songs.length],
        playedAt: now.subtract(Duration(days: index ~/ 2, hours: index)),
        listened: Duration(minutes: 3 + index),
      ),
  ];
  return PlayerSnapshot(
    likedSongs: _songs.take(4).toList(),
    followedArtists: const [_artist],
    savedCollections: [
      _artistDetail.collectionSections.first.collections.first,
    ],
    queue: _songs,
    currentSong: _songs.first,
    currentIndex: 0,
    position: const Duration(minutes: 1, seconds: 18),
    playlists: [
      LocalPlaylist(
        id: 'docs-chill',
        name: 'Chill cuối ngày',
        songs: _songs.take(4).toList(),
        createdAt: now.subtract(const Duration(days: 18)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      LocalPlaylist(
        id: 'docs-focus',
        name: 'Tập trung',
        songs: _songs.skip(2).take(4).toList(),
        createdAt: now.subtract(const Duration(days: 12)),
        updatedAt: now,
      ),
    ],
    history: history,
    recentSearches: const ['Hoàng Dũng', 'Chill', 'V-Pop'],
    themePreferenceIndex: AppThemePreference.dark.index,
  );
}

ListeningAnalyticsSnapshot _analyticsSnapshot() {
  final now = DateTime.now();
  final sourceId = 'docs-installation';
  final dailyBuckets = <DailyListeningBucket>[];
  final dailyTotals = <DailyListeningTotal>[];
  for (var day = 0; day < 12; day++) {
    final date = now.subtract(Duration(days: day));
    final dateKey = _dateKey(date);
    final aggregates = <String, SongAnalyticsAggregate>{};
    for (var index = 0; index < 5; index++) {
      final song = _songs[(day + index) % _songs.length];
      aggregates[song.id] = SongAnalyticsAggregate(
        song: song,
        starts: 3 + index,
        qualifiedPlays: 2 + index,
        completions: 1 + index,
        earlySkips: index == 4 ? 1 : 0,
        listened: Duration(minutes: 12 + day + index * 4),
        lastPlayedAt: date,
      );
    }
    dailyBuckets.add(
      DailyListeningBucket(
        sourceId: sourceId,
        date: dateKey,
        songs: aggregates,
      ),
    );
    dailyTotals.add(
      DailyListeningTotal(
        sourceId: sourceId,
        date: dateKey,
        starts: 24 + day,
        qualifiedPlays: 18 + day,
        completions: 14 + day,
        earlySkips: 2,
        listened: Duration(minutes: 74 + day * 5),
      ),
    );
  }
  final month = _dateKey(now).substring(0, 7);
  return ListeningAnalyticsSnapshot(
    installationId: sourceId,
    dailyBuckets: dailyBuckets,
    dailyTotals: dailyTotals,
    monthlyBuckets: [
      MonthlySongAggregate(
        sourceId: sourceId,
        month: month,
        songs: {
          for (var index = 0; index < _songs.length; index++)
            _songs[index].id: SongAnalyticsAggregate(
              song: _songs[index],
              starts: 18 - index,
              qualifiedPlays: 15 - index,
              completions: 11 - (index ~/ 2),
              earlySkips: index ~/ 3,
              listened: Duration(minutes: 96 - index * 7),
              lastPlayedAt: now.subtract(Duration(days: index)),
            ),
        },
      ),
    ],
    moodAssignments: {
      _songs[0].id: MoodAssignment(
        song: _songs[0],
        tags: const {MoodTag.chill},
      ),
      _songs[1].id: MoodAssignment(
        song: _songs[1],
        tags: const {MoodTag.chill},
      ),
      _songs[2].id: MoodAssignment(song: _songs[2], tags: const {MoodTag.gym}),
      _songs[3].id: MoodAssignment(
        song: _songs[3],
        tags: const {MoodTag.focus},
      ),
      _songs[4].id: MoodAssignment(
        song: _songs[4],
        tags: const {MoodTag.gym, MoodTag.focus},
      ),
    },
  );
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class _DocsAudioPlayer implements PlaybackAudioPlayer {
  final _states = StreamController<PlayerState>.broadcast(sync: true);
  final _durations = StreamController<Duration>.broadcast(sync: true);
  final _positions = StreamController<Duration>.broadcast(sync: true);
  final _completions = StreamController<void>.broadcast(sync: true);

  @override
  Stream<PlayerState> get onPlayerStateChanged => _states.stream;

  @override
  Stream<Duration> get onDurationChanged => _durations.stream;

  @override
  Stream<Duration> get onPositionChanged => _positions.stream;

  @override
  Stream<void> get onPlayerComplete => _completions.stream;

  @override
  Future<void> setAudioContext(AudioContext context) async {}

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> play(Source source) async => _states.add(PlayerState.playing);

  @override
  Future<void> pause() async => _states.add(PlayerState.paused);

  @override
  Future<void> stop() async {
    _states.add(PlayerState.stopped);
    _positions.add(Duration.zero);
  }

  @override
  Future<void> resume() async => _states.add(PlayerState.playing);

  @override
  Future<void> seek(Duration position) async => _positions.add(position);

  void emitDuration(Duration duration) => _durations.add(duration);

  void emitPosition(Duration position) => _positions.add(position);

  @override
  Future<void> dispose() async {
    await Future.wait([
      _states.close(),
      _durations.close(),
      _positions.close(),
      _completions.close(),
    ]);
  }
}
