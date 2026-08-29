import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/chart_snapshot.dart';
import 'package:zmp3chart/models/discovery_home.dart';
import 'package:zmp3chart/models/new_release_chart.dart';
import 'package:zmp3chart/models/release_catalog.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/models/weekly_chart.dart';
import 'package:zmp3chart/widgets/discovery_home_hub.dart';
import 'package:zmp3chart/widgets/song_action_menu.dart';

void main() {
  const collectionArtist = CatalogArtist(
    id: 'artist-one',
    name: 'Sơn Tùng M-TP',
    aliasName: 'Son-Tung-M-TP',
    avatar: '',
    externalUrl: 'https://zingmp3.vn/nghe-si/Son-Tung-M-TP',
  );
  const collectionOne = CatalogCollection(
    id: 'banner-one-collection',
    title: 'Nhạc Ballad Nhẹ Nhàng',
    artist: 'Nhiều nghệ sĩ',
    artists: [collectionArtist],
    thumbnail: '',
    kind: CatalogCollectionKind.playlist,
    externalUrl:
        'https://zingmp3.vn/playlist/nhac-ballad/banner-one-collection.html',
  );
  const collectionTwo = CatalogCollection(
    id: 'banner-two-collection',
    title: 'Remix Thịnh Hành',
    artist: 'Nhiều nghệ sĩ',
    thumbnail: '',
    kind: CatalogCollectionKind.playlist,
    externalUrl: '',
  );
  const collectionThree = CatalogCollection(
    id: 'banner-three-collection',
    title: 'V-Pop Gây Bão',
    artist: 'Nhiều nghệ sĩ',
    thumbnail: '',
    kind: CatalogCollectionKind.playlist,
    externalUrl: '',
  );
  const home = DiscoveryHome(
    updatedAt: null,
    banners: [
      DiscoveryBanner(
        id: 'responsive-one',
        image: '',
        collection: collectionOne,
      ),
      DiscoveryBanner(
        id: 'responsive-two',
        image: '',
        collection: collectionTwo,
      ),
      DiscoveryBanner(
        id: 'responsive-three',
        image: '',
        collection: collectionThree,
      ),
    ],
    sections: [],
  );

  const quickPlayHome = DiscoveryHome(
    updatedAt: null,
    quickPlay: [
      DiscoveryCollection(
        collection: collectionOne,
        description: 'Ballad dịu dàng cho buổi tối.',
      ),
      DiscoveryCollection(
        collection: collectionTwo,
        description: 'Remix đang được nghe nhiều.',
      ),
      DiscoveryCollection(
        collection: collectionThree,
        description: 'V-Pop nổi bật hôm nay.',
      ),
    ],
    banners: [],
    sections: [],
  );

  const collectionSectionHome = DiscoveryHome(
    updatedAt: null,
    banners: [],
    sections: [
      DiscoverySection(
        id: 'collection-section',
        title: 'Tuyển tập cho bạn',
        collections: [
          DiscoveryCollection(
            collection: collectionOne,
            description: 'Ballad dịu dàng cho buổi tối.',
          ),
          DiscoveryCollection(
            collection: collectionTwo,
            description: 'Remix đang được nghe nhiều.',
          ),
        ],
      ),
    ],
  );

  const videoHome = DiscoveryHome(
    updatedAt: null,
    banners: [],
    videos: [
      CatalogVideo(
        id: 'mv-one',
        title: 'Chúng Ta Của Tương Lai',
        artist: 'Sơn Tùng M-TP',
        thumbnail: '',
        duration: Duration(minutes: 4, seconds: 37),
        externalUrl:
            'https://zingmp3.vn/video-clip/chung-ta-cua-tuong-lai/mv-one.html',
      ),
      CatalogVideo(
        id: 'mv-two',
        title: 'Nàng Thơ',
        artist: 'Hoàng Dũng',
        thumbnail: '',
        duration: Duration(minutes: 4, seconds: 15),
        externalUrl: 'https://zingmp3.vn/video-clip/nang-tho/mv-two.html',
      ),
      CatalogVideo(
        id: 'mv-three',
        title: 'Vạn Niên',
        artist: 'Chung Thanh Duy',
        thumbnail: '',
        duration: Duration(minutes: 3, seconds: 51),
        externalUrl: 'https://zingmp3.vn/video-clip/van-nien/mv-three.html',
      ),
    ],
    sections: [],
  );

  const recentSongs = [
    Song(
      id: 'recent-one',
      name: 'recent-one',
      title: 'Một Đời',
      thumbnail: '',
      artistsNames: '14 Casper & Bon Nghiêm',
      code: 'recent-code-one',
    ),
    Song(
      id: 'recent-two',
      name: 'recent-two',
      title: 'Nàng Thơ',
      thumbnail: '',
      artistsNames: 'Hoàng Dũng',
      code: 'recent-code-two',
    ),
  ];

  const chartEntries = [
    NewReleaseEntry(
      catalogSong: CatalogSong(
        song: Song(
          id: 'chart-one',
          name: 'chart-one',
          title: 'Thiên Đường Với Người Thương',
          thumbnail: '',
          artistsNames: 'Phương Mỹ Chi, DTAP',
          code: 'chart-code-one',
        ),
        duration: Duration(minutes: 3, seconds: 38),
        externalUrl: '',
        playable: true,
      ),
      albumTitle: 'Thiên Đường Với Người Thương (Single)',
      rank: 1,
      rankChange: 2,
      releasedAt: null,
    ),
    NewReleaseEntry(
      catalogSong: CatalogSong(
        song: Song(
          id: 'chart-locked',
          name: 'chart-locked',
          title: 'Bài Hát Giới Hạn',
          thumbnail: '',
          artistsNames: 'Nghệ sĩ giới hạn',
          code: 'chart-code-locked',
        ),
        duration: Duration(minutes: 4),
        externalUrl: '',
        playable: false,
      ),
      albumTitle: 'Album giới hạn',
      rank: 2,
      rankChange: -1,
      releasedAt: null,
    ),
    NewReleaseEntry(
      catalogSong: CatalogSong(
        song: Song(
          id: 'chart-three',
          name: 'chart-three',
          title: 'Vạn Niên',
          thumbnail: '',
          artistsNames: 'Chung Thanh Duy',
          code: 'chart-code-three',
        ),
        duration: Duration(minutes: 3, seconds: 51),
        externalUrl: '',
        playable: true,
      ),
      albumTitle: 'Vạn Niên (Single)',
      rank: 3,
      rankChange: 0,
      releasedAt: null,
    ),
    NewReleaseEntry(
      catalogSong: CatalogSong(
        song: Song(
          id: 'chart-four',
          name: 'chart-four',
          title: 'Ngoài Top Ba',
          thumbnail: '',
          artistsNames: 'Nghệ sĩ bốn',
          code: 'chart-code-four',
        ),
        duration: Duration(minutes: 3),
        externalUrl: '',
        playable: true,
      ),
      albumTitle: 'Ngoài Top Ba',
      rank: 4,
      rankChange: 1,
      releasedAt: null,
    ),
  ];

  for (final viewport in const [
    (size: Size(320, 760), tvMode: false, quick: 1, banners: 1, songs: 2),
    (size: Size(360, 844), tvMode: false, quick: 1, banners: 1, songs: 2),
    (size: Size(768, 1024), tvMode: false, quick: 2, banners: 1, songs: 3),
    (size: Size(1440, 900), tvMode: false, quick: 2, banners: 1, songs: 5),
    (size: Size(1920, 1080), tvMode: true, quick: 3, banners: 1, songs: 6),
  ]) {
    testWidgets('Discovery loading skeleton mirrors the content rhythm at '
        '${viewport.size.width}px', (tester) async {
      await _pumpRail(
        tester,
        viewport.size,
        const DiscoveryHome.empty(),
        tvMode: viewport.tvMode,
        loading: true,
      );

      expect(
        find.byKey(const ValueKey('discovery-loading-state')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('discovery-loading-quick-play')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('discovery-loading-banners')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('discovery-loading-songs')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('discovery-loading-quick-card-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey('discovery-loading-quick-card-${viewport.quick - 1}'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey('discovery-loading-banner-${viewport.banners - 1}'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('discovery-loading-song-${viewport.songs - 1}')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Discovery loading skeleton honors reduced motion', (
    tester,
  ) async {
    await _pumpRail(
      tester,
      const Size(360, 844),
      const DiscoveryHome.empty(),
      loading: true,
      disableAnimations: true,
    );

    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('discovery-loading-progress')),
    );
    expect(progress.value, 0.42);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('discovery-loading-state')))
          .label,
      'Đang cập nhật nội dung Khám phá từ Zing MP3',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('local recent shelf opens songs and the full Library', (
    tester,
  ) async {
    Song? selected;
    Song? queued;
    var libraryOpened = false;
    await _pumpRail(
      tester,
      const Size(360, 844),
      quickPlayHome,
      recentlyPlayed: recentSongs,
      onRecentSongTap: (song) => selected = song,
      recentSongActionResolver: (song) => SongActionMenuConfiguration(
        handlers: SongActionHandlers(
          onPlay: () => selected = song,
          onAddToQueue: () => queued = song,
          onOpenDetail: () {},
        ),
      ),
      onOpenLibrary: () => libraryOpened = true,
    );

    expect(
      find.byKey(const ValueKey('discovery-recently-played')),
      findsOneWidget,
    );
    expect(find.textContaining('không gửi lên proxy'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('discovery-recent-song-recent-two')),
    );
    await tester.tap(
      find.byKey(const ValueKey('discovery-recent-song-recent-two')),
    );
    final menu = find.byKey(const ValueKey('discovery-recent-menu-recent-two'));
    expect(menu, findsOneWidget);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('discovery-recent-menu-item-play-recent-two')),
      findsOneWidget,
    );
    await tester.tap(find.text('Thêm vào hàng đợi'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-recent-library')));
    await tester.pump();

    expect(selected?.id, 'recent-two');
    expect(queued?.id, 'recent-two');
    expect(libraryOpened, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final viewport in const [
    Size(360, 844),
    Size(768, 1024),
    Size(1440, 900),
    Size(1920, 1080),
  ]) {
    testWidgets('official MV shelf stays adaptive at ${viewport.width}px', (
      tester,
    ) async {
      CatalogVideo? opened;
      await _pumpRail(
        tester,
        viewport,
        videoHome,
        tvMode: viewport.width == 1920,
        onVideoTap: (video) => opened = video,
      );

      expect(
        find.byKey(const ValueKey('discovery-video-shelf')),
        findsOneWidget,
      );
      expect(find.text('MV Nổi Bật'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('discovery-video-mv-one')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      if (viewport.width != 1920) {
        await tester.tap(find.byKey(const ValueKey('discovery-video-mv-one')));
        await tester.pump();
        expect(opened?.id, 'mv-one');
      }
    });
  }

  testWidgets('TV remote focuses and opens an official Discovery MV', (
    tester,
  ) async {
    CatalogVideo? opened;
    await _pumpRail(
      tester,
      const Size(1920, 1080),
      videoHome,
      tvMode: true,
      onVideoTap: (video) => opened = video,
    );

    for (var index = 0; index < 32; index++) {
      if (FocusManager.instance.primaryFocus?.debugLabel ==
          'discovery-video-focus-mv-one') {
        break;
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'discovery-video-focus-mv-one',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(opened?.id, 'mv-one');
    expect(tester.takeException(), isNull);
  });

  testWidgets('local recent shelf survives an empty Discovery response', (
    tester,
  ) async {
    await _pumpRail(
      tester,
      const Size(360, 844),
      const DiscoveryHome.empty(),
      recentlyPlayed: recentSongs,
      onRecentSongTap: (_) {},
    );

    expect(
      find.byKey(const ValueKey('discovery-recently-played')),
      findsOneWidget,
    );
    expect(find.text('Chưa có nội dung Khám phá để hiển thị.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final viewport in const [
    Size(360, 844),
    Size(768, 1024),
    Size(1440, 900),
    Size(1920, 1080),
  ]) {
    testWidgets('local recent shelf stays adaptive at ${viewport.width}px', (
      tester,
    ) async {
      await _pumpRail(
        tester,
        viewport,
        quickPlayHome,
        tvMode: viewport.width == 1920,
        recentlyPlayed: recentSongs,
        onRecentSongTap: (_) {},
      );

      expect(
        find.byKey(const ValueKey('discovery-recently-played')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('discovery-recent-song-recent-one')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('TV remote focuses and opens a recently played song', (
    tester,
  ) async {
    Song? selected;
    Song? queued;
    await _pumpRail(
      tester,
      const Size(1920, 1080),
      quickPlayHome,
      tvMode: true,
      recentlyPlayed: recentSongs,
      onRecentSongTap: (song) => selected = song,
      recentSongActionResolver: (song) => SongActionMenuConfiguration(
        handlers: SongActionHandlers(
          onPlay: () => selected = song,
          onAddToQueue: () => queued = song,
        ),
      ),
    );

    for (var index = 0; index < 32; index++) {
      if (FocusManager.instance.primaryFocus?.debugLabel ==
          'discovery-recent-focus-recent-one') {
        break;
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'discovery-recent-focus-recent-one',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected?.id, 'recent-one');

    final menu = find.byKey(const ValueKey('discovery-recent-menu-recent-one'));
    final menuIcon = find.descendant(
      of: menu,
      matching: find.byIcon(Icons.more_horiz_rounded),
    );
    expect(menuIcon, findsOneWidget);
    for (var index = 0; index < 8; index++) {
      if (Focus.of(menuIcon.evaluate().single).hasFocus) break;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(Focus.of(menuIcon.evaluate().single).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    final queueAction = find.byKey(
      const ValueKey('discovery-recent-menu-item-queue-recent-one'),
    );
    expect(queueAction, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(queued?.id, 'recent-one');
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop recent history exposes the canonical context menu', (
    tester,
  ) async {
    Song? shared;
    await _pumpRail(
      tester,
      const Size(1440, 900),
      quickPlayHome,
      recentlyPlayed: recentSongs,
      onRecentSongTap: (_) {},
      recentSongActionResolver: (song) => SongActionMenuConfiguration(
        handlers: SongActionHandlers(
          onPlay: () {},
          onOpenDetail: () {},
          onAddToQueue: () {},
          onShare: () => shared = song,
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('discovery-recent-song-recent-one')),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('discovery-recent-menu-item-play-recent-one')),
      findsOneWidget,
    );
    final share = find.byKey(
      const ValueKey('discovery-recent-menu-item-share-recent-one'),
    );
    expect(share, findsOneWidget);
    await tester.tap(share);
    await tester.pumpAndSettle();
    expect(shared?.id, 'recent-one');
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop New Release Chart spotlight opens only playable songs', (
    tester,
  ) async {
    NewReleaseEntry? selected;
    NewReleaseEntry? openedDetail;
    var openedAll = false;
    await _pumpRail(
      tester,
      const Size(1440, 900),
      quickPlayHome,
      chartEntries: chartEntries,
      onChartEntryTap: (entry) => selected = entry,
      newReleaseChartActionResolver: (entry) => SongActionMenuConfiguration(
        handlers: SongActionHandlers(
          onPlay: entry.playable ? () => selected = entry : null,
          onOpenDetail: () => openedDetail = entry,
          onAddToQueue: entry.playable ? () {} : null,
        ),
      ),
      onOpenChart: () => openedAll = true,
    );

    expect(
      find.byKey(const ValueKey('discovery-new-release-chart')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('discovery-new-release-chart-chart-four')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey('discovery-new-release-chart-chart-one')),
    );
    expect(selected?.song.id, 'chart-one');

    selected = null;
    await tester.tap(
      find.byKey(const ValueKey('discovery-new-release-chart-chart-locked')),
      warnIfMissed: false,
    );
    expect(selected, isNull);
    await tester.tap(
      find.byKey(const ValueKey('discovery-new-release-chart-chart-locked')),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey(
          'discovery-new-release-chart-menu-item-play-chart-locked',
        ),
      ),
      findsNothing,
    );
    final lockedDetail = find.byKey(
      const ValueKey(
        'discovery-new-release-chart-menu-item-detail-chart-locked',
      ),
    );
    expect(lockedDetail, findsOneWidget);
    await tester.tap(lockedDetail);
    await tester.pumpAndSettle();
    expect(openedDetail?.song.id, 'chart-locked');
    await tester.tap(find.byKey(const ValueKey('open-new-release-chart')));
    expect(openedAll, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final viewport in const [
    Size(360, 844),
    Size(768, 1024),
    Size(1440, 900),
    Size(1920, 1080),
  ]) {
    testWidgets(
      'New Release Chart spotlight stays adaptive at ${viewport.width}px',
      (tester) async {
        await _pumpRail(
          tester,
          viewport,
          quickPlayHome,
          tvMode: viewport.width == 1920,
          chartEntries: chartEntries,
          onChartEntryTap: (_) {},
        );

        expect(
          find.byKey(const ValueKey('discovery-new-release-chart')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('discovery-new-release-chart-chart-one')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('TV remote opens a playable New Release Chart card', (
    tester,
  ) async {
    NewReleaseEntry? selected;
    await _pumpRail(
      tester,
      const Size(1920, 1080),
      quickPlayHome,
      tvMode: true,
      chartEntries: chartEntries,
      onChartEntryTap: (entry) => selected = entry,
    );

    for (var index = 0; index < 48; index++) {
      if (FocusManager.instance.primaryFocus?.debugLabel ==
          'discovery-new-release-chart-focus-chart-one') {
        break;
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'discovery-new-release-chart-focus-chart-one',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected?.song.id, 'chart-one');
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop renders two Zing hero cards and pages the carousel', (
    tester,
  ) async {
    CatalogCollection? selected;
    await _pumpRail(
      tester,
      const Size(1440, 900),
      quickPlayHome,
      onCollectionTap: (collection) => selected = collection,
    );

    final rail = find.byKey(const ValueKey('discovery-quick-play-rail'));
    expect(rail, findsOneWidget);
    final first = tester.getRect(
      find.byKey(const ValueKey('discovery-quick-play-banner-one-collection')),
    );
    final second = tester.getRect(
      find.byKey(const ValueKey('discovery-quick-play-banner-two-collection')),
    );
    expect(first.top, second.top);
    expect(first.right, lessThan(second.left));
    expect(second.right, lessThanOrEqualTo(tester.getRect(rail).right + 0.5));
    expect(find.text('CÓ THỂ BẠN THÍCH'), findsNWidgets(2));
    final firstArtwork = tester.getRect(
      find.byKey(
        const ValueKey('discovery-quick-play-artwork-banner-one-collection'),
      ),
    );
    final firstCopy = tester.getRect(
      find.byKey(
        const ValueKey('discovery-quick-play-copy-banner-one-collection'),
      ),
    );
    expect(firstArtwork.width, closeTo(firstArtwork.height, 0.1));
    expect(firstArtwork.right, lessThan(firstCopy.left));
    expect(
      find.byKey(const ValueKey('discovery-quick-play-next')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('discovery-quick-play-banner-two-collection')),
    );
    await tester.pump();
    expect(selected?.id, collectionTwo.id);

    await tester.tap(find.byKey(const ValueKey('discovery-quick-play-next')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('discovery-quick-play-previous')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('discovery-quick-play-banner-three-collection'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
        const ValueKey('discovery-quick-play-banner-three-collection'),
      ),
    );
    await tester.pump();
    expect(selected?.id, collectionThree.id);
    expect(tester.takeException(), isNull);
  });

  for (final viewport in [
    (size: const Size(360, 844), tvMode: false),
    (size: const Size(768, 1024), tvMode: false),
    (size: const Size(1920, 1080), tvMode: true),
  ]) {
    testWidgets(
      'Quick Play stays adaptive at ${viewport.size.width.toInt()}px',
      (tester) async {
        await _pumpRail(
          tester,
          viewport.size,
          quickPlayHome,
          tvMode: viewport.tvMode,
        );

        final rail = tester.getRect(
          find.byKey(const ValueKey('discovery-quick-play-rail')),
        );
        final first = tester.getRect(
          find.byKey(
            const ValueKey('discovery-quick-play-banner-one-collection'),
          ),
        );
        expect(first.left, closeTo(rail.left, 0.5));
        expect(first.width, lessThanOrEqualTo(rail.width));
        expect(first.bottom, lessThanOrEqualTo(rail.bottom + 0.5));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('TV remote focuses and opens a Quick Play collection', (
    tester,
  ) async {
    CatalogCollection? selected;
    await _pumpRail(
      tester,
      const Size(1920, 1080),
      quickPlayHome,
      tvMode: true,
      onCollectionTap: (collection) => selected = collection,
    );

    for (var index = 0; index < 16; index++) {
      if (FocusManager.instance.primaryFocus?.debugLabel ==
          'discovery-quick-play-focus-banner-one-collection') {
        break;
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'discovery-quick-play-focus-banner-one-collection',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected?.id, collectionOne.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collection cards separate quick play from opening details', (
    tester,
  ) async {
    CatalogCollection? opened;
    CatalogCollection? played;
    CatalogCollection? saved;
    CatalogCollection? shared;
    CatalogArtist? openedArtist;
    await _pumpRail(
      tester,
      const Size(360, 844),
      collectionSectionHome,
      onCollectionTap: (collection) => opened = collection,
      onCollectionPlay: (collection) => played = collection,
      onCollectionToggleSaved: (collection) => saved = collection,
      onCollectionShare: (collection) => shared = collection,
      onCollectionArtistTap: (artist) => openedArtist = artist,
    );

    final playButton = find.byKey(
      const ValueKey('discovery-collection-play-banner-one-collection'),
    );
    await tester.ensureVisible(playButton);
    await tester.tap(playButton);
    await tester.pump();
    expect(played?.id, collectionOne.id);
    expect(opened, isNull);

    final artistLink = find.byKey(
      const ValueKey(
        'discovery-collection-artist-banner-one-collection-artist-one',
      ),
    );
    await tester.ensureVisible(artistLink);
    await tester.tap(artistLink);
    await tester.pump();
    expect(openedArtist?.id, collectionArtist.id);
    expect(opened, isNull);

    final saveButton = find.byKey(
      const ValueKey('discovery-collection-save-banner-one-collection'),
    );
    await tester.tap(saveButton);
    await tester.pump();
    expect(saved?.id, collectionOne.id);
    expect(opened, isNull);

    await tester.pumpWidget(
      _railApp(
        collectionSectionHome,
        onCollectionTap: (collection) => opened = collection,
        onCollectionPlay: (collection) => played = collection,
        onCollectionToggleSaved: (collection) => saved = collection,
        onCollectionShare: (collection) => shared = collection,
        savedCollectionIds: {collectionOne.id},
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: saveButton,
        matching: find.byIcon(Icons.favorite_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        const ValueKey('discovery-collection-more-banner-one-collection'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('discovery-collection-menu-share-banner-one-collection'),
      ),
    );
    await tester.pumpAndSettle();
    expect(shared?.id, collectionOne.id);
    expect(opened, isNull);

    final secondMoreButton = find.byKey(
      const ValueKey('discovery-collection-more-banner-two-collection'),
    );
    await tester.ensureVisible(secondMoreButton);
    await tester.pumpAndSettle();
    await tester.tap(secondMoreButton);
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey('discovery-collection-menu-share-banner-two-collection'),
      ),
      findsNothing,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    final card = find.byKey(
      const ValueKey('discovery-collection-banner-one-collection'),
    );
    final cardRect = tester.getRect(card);
    await tester.tapAt(Offset(cardRect.center.dx, cardRect.bottom - 20));
    await tester.pump();
    expect(opened?.id, collectionOne.id);

    await tester.pumpWidget(
      _railApp(
        collectionSectionHome,
        onCollectionPlay: (collection) => played = collection,
        onCollectionToggleSaved: (collection) => saved = collection,
        onCollectionShare: (collection) => shared = collection,
        savedCollectionIds: {collectionOne.id},
        quickPlayingCollectionId: collectionOne.id,
      ),
    );
    await tester.pump();
    final loadingButton = tester.widget<IconButton>(playButton);
    expect(loadingButton.onPressed, isNull);
    expect(
      find.descendant(
        of: playButton,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop Discovery collection exposes the shared context menu', (
    tester,
  ) async {
    CatalogCollection? opened;
    CatalogCollection? shared;
    await _pumpRail(
      tester,
      const Size(1440, 900),
      collectionSectionHome,
      onCollectionTap: (collection) => opened = collection,
      onCollectionPlay: (_) {},
      onCollectionToggleSaved: (_) {},
      onCollectionShare: (collection) => shared = collection,
    );

    await tester.tap(
      find.byKey(const ValueKey('discovery-collection-banner-one-collection')),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey('discovery-collection-menu-play-banner-one-collection'),
      ),
      findsOneWidget,
    );
    final contextShare = find.byKey(
      const ValueKey('discovery-collection-menu-share-banner-one-collection'),
    );
    expect(contextShare, findsOneWidget);
    await tester.tap(contextShare);
    await tester.pumpAndSettle();
    expect(shared?.id, collectionOne.id);
    expect(opened, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV remote focuses the collection quick-play action', (
    tester,
  ) async {
    CatalogCollection? played;
    await _pumpRail(
      tester,
      const Size(1920, 1080),
      collectionSectionHome,
      tvMode: true,
      onCollectionPlay: (collection) => played = collection,
    );

    final playButton = find.byKey(
      const ValueKey('discovery-collection-play-banner-one-collection'),
    );
    final playIcon = find.descendant(
      of: playButton,
      matching: find.byIcon(Icons.play_arrow_rounded),
    );
    for (var index = 0; index < 30; index++) {
      if (Focus.of(tester.element(playIcon)).hasPrimaryFocus) break;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(Focus.of(tester.element(playIcon)).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(played?.id, collectionOne.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collection carousel pages and resets when its catalog changes', (
    tester,
  ) async {
    final firstHome = _collectionCarouselHome();
    await _pumpRail(tester, const Size(768, 1024), firstHome);

    final nextButton = find.byKey(
      const ValueKey('discovery-section-next-carousel-section'),
    );
    final previousButton = find.byKey(
      const ValueKey('discovery-section-previous-carousel-section'),
    );
    final secondCard = find.byKey(
      const ValueKey('discovery-collection-carousel-1'),
    );
    expect(nextButton, findsOneWidget);
    expect(previousButton, findsNothing);
    final secondLeftBefore = tester.getRect(secondCard).left;

    await tester.tap(nextButton);
    await tester.pumpAndSettle();
    expect(tester.getRect(secondCard).left, lessThan(secondLeftBefore));
    expect(previousButton, findsOneWidget);

    final updatedHome = _collectionCarouselHome(offset: 20);
    await tester.pumpWidget(_railApp(updatedHome));
    await tester.pumpAndSettle();

    final rail = tester.getRect(
      find.byKey(const ValueKey('discovery-section-rail-carousel-section')),
    );
    final updatedFirst = tester.getRect(
      find.byKey(const ValueKey('discovery-collection-carousel-20')),
    );
    expect(updatedFirst.left, closeTo(rail.left, 0.5));
    expect(previousButton, findsNothing);
    expect(nextButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collection carousel keeps swipe on phones and Enter on TV', (
    tester,
  ) async {
    final carouselHome = _collectionCarouselHome();
    await _pumpRail(tester, const Size(360, 844), carouselHome);

    final list = find.byKey(
      const ValueKey('discovery-section-list-carousel-section'),
    );
    final mobileList = tester.widget<ListView>(list);
    expect(mobileList.controller?.offset, 0);
    expect(
      find.byKey(const ValueKey('discovery-section-next-carousel-section')),
      findsNothing,
    );
    await tester.drag(list, const Offset(-220, 0));
    await tester.pumpAndSettle();
    expect(mobileList.controller?.offset, greaterThan(0));

    await _pumpRail(tester, const Size(1920, 1080), carouselHome, tvMode: true);
    final tvNextButton = find.byKey(
      const ValueKey('discovery-section-next-carousel-section'),
    );
    final tvNextControl = tester.widget<IconButton>(
      find.descendant(of: tvNextButton, matching: find.byType(IconButton)),
    );
    tvNextControl.focusNode?.requestFocus();
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'discovery-section-next-carousel-section',
    );
    final tvList = tester.widget<ListView>(
      find.byKey(const ValueKey('discovery-section-list-carousel-section')),
    );
    final tvOffsetBefore = tvList.controller!.offset;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(tvList.controller!.offset, greaterThan(tvOffsetBefore));
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'discovery-section-next-carousel-section',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV remote pages Quick Play and keeps arrow focus visible', (
    tester,
  ) async {
    final tvHome = DiscoveryHome(
      categoryId: '-1',
      updatedAt: null,
      quickPlay: [
        ...quickPlayHome.quickPlay,
        const DiscoveryCollection(
          collection: CatalogCollection(
            id: 'banner-four-collection',
            title: 'Nhạc Trẻ Ballad Cực Thấm',
            artist: 'Thanh Hưng, Thành Đạt',
            thumbnail: '',
            kind: CatalogCollectionKind.playlist,
            externalUrl: '',
          ),
          description: 'Những bản ballad nhẹ nhàng.',
        ),
      ],
      banners: const [],
      sections: const [],
    );
    await _pumpRail(tester, const Size(1920, 1080), tvHome, tvMode: true);

    for (var index = 0; index < 16; index++) {
      if (FocusManager.instance.primaryFocus?.debugLabel ==
          'discovery-quick-play-next-focus') {
        break;
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'discovery-quick-play-next-focus',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('discovery-quick-play-previous')),
      findsOneWidget,
    );
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'discovery-quick-play-previous-focus',
    );
    expect(
      find.byKey(const ValueKey('discovery-quick-play-banner-four-collection')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quick Play resets when the Discovery category changes', (
    tester,
  ) async {
    const nextHome = DiscoveryHome(
      categoryId: '14',
      updatedAt: null,
      quickPlay: [
        DiscoveryCollection(
          collection: CatalogCollection(
            id: 'relax-quick-one',
            title: 'Thư giãn buổi tối',
            artist: 'Nhiều nghệ sĩ',
            thumbnail: '',
            kind: CatalogCollectionKind.playlist,
            externalUrl: '',
          ),
          description: 'Nhạc nhẹ cho buổi tối.',
        ),
        DiscoveryCollection(
          collection: CatalogCollection(
            id: 'relax-quick-two',
            title: 'Acoustic yên bình',
            artist: 'Nhiều nghệ sĩ',
            thumbnail: '',
            kind: CatalogCollectionKind.playlist,
            externalUrl: '',
          ),
          description: 'Acoustic thư thái.',
        ),
      ],
      banners: [],
      sections: [],
    );
    await _pumpRail(tester, const Size(360, 844), quickPlayHome);

    final list = find.byKey(const ValueKey('discovery-quick-play-list'));
    await tester.drag(list, const Offset(-320, 0));
    await tester.pumpAndSettle();
    final rail = tester.getRect(
      find.byKey(const ValueKey('discovery-quick-play-rail')),
    );
    expect(
      find.byKey(const ValueKey('discovery-quick-play-banner-one-collection')),
      findsNothing,
    );

    await tester.pumpWidget(_railApp(nextHome));
    await tester.pumpAndSettle();
    final first = tester.getRect(
      find.byKey(const ValueKey('discovery-quick-play-relax-quick-one')),
    );
    expect(first.left, closeTo(rail.left, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tablet prioritizes compact Quick Play without duplicate sidebar shortcuts',
    (tester) async {
      await _pumpRail(tester, const Size(768, 1024), quickPlayHome);

      final quickPlay = tester.getRect(
        find.byKey(const ValueKey('discovery-quick-play-rail')),
      );
      final firstCard = tester.getRect(
        find.byKey(
          const ValueKey('discovery-quick-play-banner-one-collection'),
        ),
      );

      expect(quickPlay.top, greaterThanOrEqualTo(0));
      expect(find.byKey(const ValueKey('open-weekly-chart')), findsNothing);
      expect(find.byKey(const ValueKey('open-hub-home')), findsNothing);
      expect(find.byKey(const ValueKey('open-top-100')), findsNothing);
      expect(find.byKey(const ValueKey('open-new-releases')), findsNothing);
      expect(firstCard.height, inInclusiveRange(152, 168));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wide desktop removes duplicate shortcuts and opens the full Top 100',
    (tester) async {
      var openTop100Calls = 0;
      const top100Home = DiscoveryHome(
        updatedAt: null,
        banners: [],
        sections: [
          DiscoverySection(
            id: 'desktop-top-100',
            title: 'Top 100',
            collections: [
              DiscoveryCollection(
                collection: CatalogCollection(
                  id: 'desktop-top-100-collection',
                  title: 'Top 100 Việt Nam',
                  artist: 'Nhiều nghệ sĩ',
                  thumbnail: '',
                  kind: CatalogCollectionKind.playlist,
                  externalUrl: '',
                ),
                description: 'Tuyển tập chính thức từ Zing MP3.',
              ),
            ],
          ),
        ],
      );
      await _pumpRail(
        tester,
        const Size(1440, 900),
        top100Home,
        onOpenTop100: () => openTop100Calls++,
      );

      expect(find.byKey(const ValueKey('open-top-100')), findsNothing);
      final openAll = find.byKey(
        const ValueKey('discovery-section-open-all-desktop-top-100'),
      );
      expect(openAll, findsOneWidget);
      expect(find.text('TẤT CẢ'), findsOneWidget);

      await tester.tap(openAll);
      await tester.pump();
      expect(openTop100Calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile keeps touch shortcuts before the Quick Play rail', (
    tester,
  ) async {
    await _pumpRail(tester, const Size(360, 844), quickPlayHome);

    final shortcut = tester.getRect(
      find.byKey(const ValueKey('open-weekly-chart')),
    );
    final quickPlay = tester.getRect(
      find.byKey(const ValueKey('discovery-quick-play-rail')),
    );
    final firstCard = tester.getRect(
      find.byKey(const ValueKey('discovery-quick-play-banner-one-collection')),
    );

    expect(shortcut.bottom, lessThan(quickPlay.top));
    expect(firstCard.height, inInclusiveRange(166, 190));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile banner rail shows one card with a next-card peek', (
    tester,
  ) async {
    await _pumpRail(tester, const Size(360, 844), home);

    final rail = tester.getRect(
      find.byKey(const ValueKey('discovery-banner-rail')),
    );
    final first = tester.getRect(
      find.byKey(const ValueKey('discovery-banner-responsive-one')),
    );
    final second = tester.getRect(
      find.byKey(const ValueKey('discovery-banner-responsive-two')),
    );

    expect(first.right, lessThan(rail.right));
    expect(second.left, lessThan(rail.right));
    expect(second.right, greaterThan(rail.right));
    expect(find.byKey(const ValueKey('discovery-banner-next')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('banner carousel auto-advances and pauses while hovered', (
    tester,
  ) async {
    await _pumpRail(tester, const Size(1440, 900), home);

    final firstFinder = find.byKey(
      const ValueKey('discovery-banner-responsive-one'),
    );
    final position = _bannerScrollPosition(tester);
    final offsetBefore = position.pixels;
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 430));
    expect(position.pixels, greaterThan(offsetBefore));

    await tester.tap(find.byKey(const ValueKey('discovery-banner-previous')));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(firstFinder));
    await tester.pump();
    final pausedOffset = position.pixels;
    await tester.pump(const Duration(seconds: 7));
    expect(position.pixels, closeTo(pausedOffset, 0.5));

    await mouse.moveTo(const Offset(1436, 896));
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 430));
    expect(position.pixels, greaterThan(pausedOffset));
    expect(tester.takeException(), isNull);
  });

  testWidgets('banner carousel remains still while a touch drag is active', (
    tester,
  ) async {
    await _pumpRail(tester, const Size(360, 844), home);

    final rail = find.byKey(const ValueKey('discovery-banner-list'));
    final position = _bannerScrollPosition(tester);
    final gesture = await tester.startGesture(tester.getCenter(rail));
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();
    final pausedOffset = position.pixels;
    await tester.pump(const Duration(seconds: 7));
    expect(position.pixels, closeTo(pausedOffset, 0.5));

    await gesture.up();
    await tester.pumpAndSettle();
    final resumedOffset = position.pixels;
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 430));
    expect(position.pixels, greaterThan(resumedOffset));
    expect(tester.takeException(), isNull);
  });

  testWidgets('banner carousel honors reduced-motion preferences', (
    tester,
  ) async {
    await _pumpRail(
      tester,
      const Size(1440, 900),
      home,
      disableAnimations: true,
    );

    final position = _bannerScrollPosition(tester);
    final offsetBefore = position.pixels;
    await tester.pump(const Duration(seconds: 7));
    expect(position.pixels, closeTo(offsetBefore, 0.5));
    expect(tester.takeException(), isNull);
  });

  for (final viewport in [
    (size: const Size(768, 1024), tvMode: false),
    (size: const Size(1440, 900), tvMode: false),
    (size: const Size(1920, 1080), tvMode: true),
  ]) {
    testWidgets(
      'wide banner rail shows one panorama and pages at ${viewport.size.width.toInt()}px',
      (tester) async {
        await _pumpRail(tester, viewport.size, home, tvMode: viewport.tvMode);

        final rail = tester.getRect(
          find.byKey(const ValueKey('discovery-banner-rail')),
        );
        final first = tester.getRect(
          find.byKey(const ValueKey('discovery-banner-responsive-one')),
        );
        expect(first.width, closeTo(rail.width, 0.5));
        expect(first.right, closeTo(rail.right, 0.5));
        expect(first.width / first.height, greaterThanOrEqualTo(7));

        final nextButton = find.byKey(const ValueKey('discovery-banner-next'));
        expect(nextButton, findsOneWidget);
        final position = _bannerScrollPosition(tester);
        final offsetBefore = position.pixels;
        await tester.tap(nextButton);
        await tester.pumpAndSettle();
        expect(position.pixels, greaterThan(offsetBefore));
        expect(
          find.byKey(const ValueKey('discovery-banner-previous')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'resets to the first banner when a category keeps the same count',
    (tester) async {
      const nextCategoryHome = DiscoveryHome(
        categoryId: '14',
        updatedAt: null,
        banners: [
          DiscoveryBanner(
            id: 'relax-one',
            image: '',
            collection: collectionOne,
          ),
          DiscoveryBanner(
            id: 'relax-two',
            image: '',
            collection: collectionTwo,
          ),
          DiscoveryBanner(
            id: 'relax-three',
            image: '',
            collection: collectionThree,
          ),
        ],
        sections: [],
      );
      await _pumpRail(tester, const Size(768, 1024), home);

      await tester.tap(find.byKey(const ValueKey('discovery-banner-next')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('discovery-banner-previous')),
        findsOneWidget,
      );

      await tester.pumpWidget(_railApp(nextCategoryHome));
      await tester.pumpAndSettle();

      final rail = tester.getRect(
        find.byKey(const ValueKey('discovery-banner-rail')),
      );
      final first = tester.getRect(
        find.byKey(const ValueKey('discovery-banner-relax-one')),
      );
      expect(first.left, closeTo(rail.left, 0.5));
      expect(
        find.byKey(const ValueKey('discovery-banner-previous')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('discovery-banner-next')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('banner carousel pauses while a TV control owns focus', (
    tester,
  ) async {
    await _pumpRail(tester, const Size(1920, 1080), home, tvMode: true);

    final nextControl = find.byKey(const ValueKey('discovery-banner-next'));
    final iconButton = tester.widget<IconButton>(
      find.descendant(of: nextControl, matching: find.byType(IconButton)),
    );
    iconButton.focusNode!.requestFocus();
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'discovery-banner-next-focus',
    );

    final position = _bannerScrollPosition(tester);
    final offsetBefore = position.pixels;
    await tester.pump(const Duration(seconds: 7));
    expect(position.pixels, closeTo(offsetBefore, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV remote pages banners and keeps focus on a visible arrow', (
    tester,
  ) async {
    await _pumpRail(tester, const Size(1920, 1080), home, tvMode: true);

    for (var index = 0; index < 16; index++) {
      if (FocusManager.instance.primaryFocus?.debugLabel ==
          'discovery-banner-next-focus') {
        break;
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'discovery-banner-next-focus',
    );

    final position = _bannerScrollPosition(tester);
    final offsetBefore = position.pixels;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(offsetBefore));
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'discovery-banner-next-focus',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(position.maxScrollExtent, 0.5));
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'discovery-banner-previous-focus',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(position.minScrollExtent));
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'discovery-banner-previous-focus',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(position.minScrollExtent, 0.5));
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'discovery-banner-next-focus',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop recommendations mirror the three-by-three Zing grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final songs = List<Song>.generate(
      9,
      (index) => Song(
        id: 'matrix-$index',
        name: 'matrix-$index',
        title: 'Gợi Ý ${index + 1}',
        thumbnail: '',
        artistsNames: 'Nghệ sĩ $index',
        code: 'matrix-code-$index',
      ),
      growable: false,
    );
    Song? selected;
    Song? liked;
    Song? queued;
    CatalogArtist? openedArtist;
    const officialArtist = CatalogArtist(
      id: 'matrix-artist',
      name: 'Nghệ sĩ chính thức',
      aliasName: 'Nghe-Si-Chinh-Thuc',
      avatar: '',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: 1200,
                child: DiscoveryRecommendationShelf(
                  songs: songs,
                  official: true,
                  catalogBySongId: {
                    songs.first.id: CatalogSong(
                      song: songs.first,
                      duration: const Duration(minutes: 3),
                      externalUrl: '',
                      playable: true,
                      artists: const [officialArtist],
                    ),
                  },
                  canRefresh: true,
                  onSongTap: (song) => selected = song,
                  onRefresh: _noop,
                  onToggleLike: (song) => liked = song,
                  onAddToQueue: (song) => queued = song,
                  onOpenDetail: (_) {},
                  onStartRadio: (_) {},
                  onAddToPlaylist: (_) {},
                  onShare: (_) {},
                  onArtistTap: (artist) => openedArtist = artist,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('discovery-recommendations-grid')),
      findsOneWidget,
    );
    for (var index = 0; index < songs.length; index++) {
      expect(
        find.byKey(ValueKey('discovery-recommendation-matrix-$index')),
        findsOneWidget,
      );
    }
    final first = tester.getRect(
      find.byKey(const ValueKey('discovery-recommendation-matrix-0')),
    );
    final third = tester.getRect(
      find.byKey(const ValueKey('discovery-recommendation-matrix-2')),
    );
    final fourth = tester.getRect(
      find.byKey(const ValueKey('discovery-recommendation-matrix-3')),
    );
    expect(third.top, closeTo(first.top, 0.5));
    expect(third.left, greaterThan(first.left));
    expect(fourth.left, closeTo(first.left, 0.5));
    expect(fourth.top, greaterThan(first.top));

    await tester.tap(
      find.byKey(
        const ValueKey('discovery-recommendation-artist-matrix-artist'),
      ),
    );
    await tester.pump();
    expect(openedArtist, officialArtist);
    expect(selected, isNull);

    final firstCard = find.byKey(
      const ValueKey('discovery-recommendation-matrix-0'),
    );
    final playIcon = find.descendant(
      of: firstCard,
      matching: find.byIcon(Icons.play_circle_fill_rounded),
    );
    final playOpacity = find.ancestor(
      of: playIcon,
      matching: find.byType(AnimatedOpacity),
    );
    expect(tester.widget<AnimatedOpacity>(playOpacity).opacity, 0);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(1, 1));
    await mouse.moveTo(tester.getCenter(firstCard));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(playOpacity).opacity, 1);
    await tester.tap(
      find.byKey(const ValueKey('discovery-recommendation-like-matrix-0')),
    );
    await tester.pump();
    expect(liked?.id, 'matrix-0');
    await tester.tap(
      find.byKey(const ValueKey('discovery-recommendation-menu-matrix-0')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thông tin bài hát'), findsOneWidget);
    expect(find.text('Bắt đầu Song Radio'), findsOneWidget);
    expect(find.text('Thêm vào playlist'), findsOneWidget);
    expect(find.text('Chia sẻ liên kết'), findsOneWidget);
    await tester.tap(find.text('Thêm vào hàng đợi'));
    await tester.pumpAndSettle();
    expect(queued?.id, 'matrix-0');

    selected = null;
    await tester.tap(
      firstCard,
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    final contextPlay = find.byKey(
      const ValueKey('discovery-recommendation-menu-item-play-matrix-0'),
    );
    expect(contextPlay, findsOneWidget);
    await tester.tap(contextPlay);
    await tester.pumpAndSettle();
    expect(selected?.id, 'matrix-0');

    selected = null;
    final firstCardRect = tester.getRect(firstCard);
    final titlePoint = Offset(firstCardRect.center.dx, firstCardRect.top + 14);
    await mouse.down(titlePoint);
    await mouse.up();
    await tester.pump();
    expect(selected?.id, 'matrix-0');
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV remote focuses and plays an item in the suggestion matrix', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const songs = [
      Song(
        id: 'tv-matrix-one',
        name: 'tv-matrix-one',
        title: 'Gợi Ý Trên TV',
        thumbnail: '',
        artistsNames: 'Nghệ sĩ TV',
        code: 'tv-matrix-one-code',
      ),
      Song(
        id: 'tv-matrix-two',
        name: 'tv-matrix-two',
        title: 'Gợi Ý Tiếp Theo',
        thumbnail: '',
        artistsNames: 'Nghệ sĩ TV',
        code: 'tv-matrix-two-code',
      ),
    ];
    const tvArtist = CatalogArtist(
      id: 'tv-matrix-artist',
      name: 'Nghệ sĩ TV',
      aliasName: 'Nghe-Si-TV',
      avatar: '',
    );
    Song? selected;
    Song? liked;
    CatalogArtist? openedArtist;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(48),
            child: DiscoveryRecommendationShelf(
              songs: songs,
              official: true,
              catalogBySongId: {
                'tv-matrix-one': CatalogSong(
                  song: songs.first,
                  duration: Duration(minutes: 3),
                  externalUrl: '',
                  playable: true,
                  artists: [tvArtist],
                ),
              },
              canRefresh: false,
              onSongTap: (song) => selected = song,
              onRefresh: _noop,
              onToggleLike: (song) => liked = song,
              onArtistTap: (artist) => openedArtist = artist,
              tvMode: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstCard = find.byKey(
      const ValueKey('discovery-recommendation-tv-matrix-one'),
    );
    final firstPlayIcon = find.descendant(
      of: firstCard,
      matching: find.byIcon(Icons.play_circle_fill_rounded),
    );
    for (var index = 0; index < 6; index++) {
      if (Focus.of(tester.element(firstPlayIcon)).hasPrimaryFocus) break;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(Focus.of(tester.element(firstPlayIcon)).hasPrimaryFocus, isTrue);
    final playOpacity = find.ancestor(
      of: firstPlayIcon,
      matching: find.byType(AnimatedOpacity),
    );
    expect(tester.widget<AnimatedOpacity>(playOpacity).opacity, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected?.id, 'tv-matrix-one');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final artistButton = find.byKey(
      const ValueKey('discovery-recommendation-artist-tv-matrix-artist'),
    );
    final artistLabel = find.descendant(
      of: artistButton,
      matching: find.text('Nghệ sĩ TV'),
    );
    for (var index = 0; index < 6; index++) {
      if (Focus.of(tester.element(artistLabel)).hasPrimaryFocus) break;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(Focus.of(tester.element(artistLabel)).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(openedArtist, tvArtist);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final likeIcon = find.descendant(
      of: find.byKey(
        const ValueKey('discovery-recommendation-like-tv-matrix-one'),
      ),
      matching: find.byIcon(Icons.favorite_border_rounded),
    );
    for (var index = 0; index < 6; index++) {
      if (Focus.of(tester.element(likeIcon)).hasPrimaryFocus) break;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(Focus.of(tester.element(likeIcon)).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(liked?.id, 'tv-matrix-one');
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile recommendations keep the full action menu reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const song = Song(
      id: 'mobile-matrix',
      name: 'mobile-matrix',
      title: 'Gợi Ý Trên Điện Thoại',
      thumbnail: '',
      artistsNames: 'Nghệ sĩ Mobile',
      code: 'mobile-matrix-code',
    );
    Song? queued;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: DiscoveryRecommendationShelf(
              songs: const [song],
              official: true,
              canRefresh: false,
              onSongTap: (_) {},
              onRefresh: _noop,
              onAddToQueue: (value) => queued = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final menu = find.byKey(
      const ValueKey('discovery-recommendation-menu-mobile-matrix'),
    );
    expect(menu, findsOneWidget);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm vào hàng đợi'));
    await tester.pumpAndSettle();
    expect(queued?.id, song.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile New Release songs expose the canonical action menu without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const song = Song(
        id: 'release-action-playable',
        name: 'release-action-playable',
        title: 'Bài Mới Có Menu',
        thumbnail: '',
        artistsNames: 'Nghệ sĩ Release',
        code: 'release-action-code',
      );
      const release = ReleaseSong(
        catalogSong: CatalogSong(
          song: song,
          duration: Duration(minutes: 3),
          externalUrl: '',
          playable: true,
        ),
        releasedAt: null,
        region: ReleaseRegion.vietnam,
      );
      ReleaseSong? queued;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: DiscoveryNewReleaseShelf(
                songs: const [release],
                loading: false,
                errorMessage: null,
                region: DiscoveryReleaseRegion.all,
                onRegionChanged: (_) {},
                onSongTap: (_) {},
                onAddToQueue: (value) => queued = value,
                onOpenAll: _noop,
                onRetry: _noop,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final menu = find.byKey(
        const ValueKey('discovery-release-menu-release-action-playable'),
      );
      expect(menu, findsOneWidget);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey(
            'discovery-release-menu-item-play-release-action-playable',
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Thêm vào hàng đợi'));
      await tester.pumpAndSettle();
      expect(queued, release);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('locked New Release songs keep safe actions but never Play', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const lockedSong = Song(
      id: 'release-action-locked',
      name: 'release-action-locked',
      title: 'Bài Mới Bị Khóa',
      thumbnail: '',
      artistsNames: 'Nghệ sĩ Release',
      code: 'release-locked-code',
    );
    const lockedRelease = ReleaseSong(
      catalogSong: CatalogSong(
        song: lockedSong,
        duration: Duration(minutes: 3),
        externalUrl: '',
        playable: false,
      ),
      releasedAt: null,
      region: ReleaseRegion.vietnam,
    );
    ReleaseSong? openedDetail;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: DiscoveryNewReleaseShelf(
              songs: const [lockedRelease],
              loading: false,
              errorMessage: null,
              region: DiscoveryReleaseRegion.all,
              onRegionChanged: (_) {},
              onSongTap: (_) {},
              onOpenDetail: (value) => openedDetail = value,
              onToggleLike: (_) {},
              onOpenAll: _noop,
              onRetry: _noop,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('discovery-release-release-action-locked')),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey(
          'discovery-release-menu-item-play-release-action-locked',
        ),
      ),
      findsNothing,
    );
    final detail = find.byKey(
      const ValueKey(
        'discovery-release-menu-item-detail-release-action-locked',
      ),
    );
    expect(detail, findsOneWidget);
    await tester.tap(detail);
    await tester.pumpAndSettle();
    expect(openedDetail, lockedRelease);
    expect(tester.takeException(), isNull);
  });

  for (final viewport in const [
    Size(360, 844),
    Size(768, 1024),
    Size(1440, 900),
    Size(1920, 1080),
  ]) {
    testWidgets(
      'embedded #zingchart stays adaptive and plays the exact queue at '
      '${viewport.width}px',
      (tester) async {
        Song? played;
        List<Song>? queue;
        var opened = 0;
        final snapshot = _discoveryChartSnapshot();
        await _pumpRail(
          tester,
          viewport,
          const DiscoveryHome.empty(),
          tvMode: viewport.width == 1920,
          realtimeChartSnapshot: snapshot,
          onRealtimeChartPlay: (song, songs) {
            played = song;
            queue = songs;
          },
          onOpenRealtimeChart: () => opened++,
        );

        expect(
          find.byKey(const ValueKey('discovery-zingchart-preview')),
          findsOneWidget,
        );
        expect(find.text('#zingchart'), findsOneWidget);

        final second = find.byKey(
          const ValueKey('discovery-zingchart-song-live-two'),
        );
        expect(second, findsOneWidget);
        await tester.ensureVisible(second);
        await tester.tap(second);
        await tester.pump();
        expect(played?.id, 'live-two');
        expect(queue?.map((song) => song.id), [
          'live-one',
          'live-two',
          'live-three',
        ]);

        final openAll = find.byKey(
          const ValueKey('discovery-zingchart-open-all'),
        );
        await tester.ensureVisible(openAll);
        await tester.tap(openAll);
        await tester.pump();
        expect(opened, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('TV remote focuses and plays an embedded #zingchart row', (
    tester,
  ) async {
    Song? played;
    await _pumpRail(
      tester,
      const Size(1920, 1080),
      const DiscoveryHome.empty(),
      tvMode: true,
      realtimeChartSnapshot: _discoveryChartSnapshot(),
      onRealtimeChartPlay: (song, _) => played = song,
      onOpenRealtimeChart: _noop,
    );

    final target = find.byKey(
      const ValueKey('discovery-zingchart-song-live-one'),
    );
    await tester.ensureVisible(target);
    for (var index = 0; index < 24; index++) {
      if (Focus.of(tester.element(target)).hasPrimaryFocus) break;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(Focus.of(tester.element(target)).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(played?.id, 'live-one');
    expect(tester.takeException(), isNull);
  });

  for (final viewport in const [
    Size(360, 844),
    Size(768, 1024),
    Size(1440, 900),
    Size(1920, 1080),
  ]) {
    testWidgets('weekly-region rail stays adaptive at ${viewport.width}px', (
      tester,
    ) async {
      WeeklyChartRegion? opened;
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: DiscoveryWeeklyChartRegionRail(
                onOpenRegion: (region) => opened = region,
                tvMode: viewport.width == 1920,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('discovery-weekly-region-vietnam')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('discovery-weekly-region-usuk')),
        findsOneWidget,
      );
      final korea = find.byKey(const ValueKey('discovery-weekly-region-korea'));
      if (viewport.width < 720) {
        await tester.scrollUntilVisible(
          korea,
          220,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('discovery-weekly-region-list')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
      }
      expect(korea, findsOneWidget);
      await tester.ensureVisible(korea);
      await tester.tap(korea);
      await tester.pump();
      expect(opened, WeeklyChartRegion.korea);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('TV remote focuses and opens the K-Pop weekly chart', (
    tester,
  ) async {
    WeeklyChartRegion? opened;
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(32),
            child: DiscoveryWeeklyChartRegionRail(
              onOpenRegion: (region) => opened = region,
              tvMode: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final target = find.byKey(const ValueKey('discovery-weekly-region-korea'));
    for (var index = 0; index < 8; index++) {
      if (Focus.of(tester.element(target)).hasPrimaryFocus) break;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(Focus.of(tester.element(target)).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(opened, WeeklyChartRegion.korea);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}

ChartSnapshot _discoveryChartSnapshot() {
  const songs = [
    Song(
      id: 'live-one',
      name: 'live-one',
      title: 'Bật Tình Yêu Lên',
      thumbnail: '',
      artistsNames: 'Tăng Duy Tân, Hòa Minzy',
      code: 'live-code-one',
    ),
    Song(
      id: 'live-two',
      name: 'live-two',
      title: 'Chúng Ta Của Tương Lai',
      thumbnail: '',
      artistsNames: 'Sơn Tùng M-TP',
      code: 'live-code-two',
    ),
    Song(
      id: 'live-three',
      name: 'live-three',
      title: 'Nàng Thơ',
      thumbnail: '',
      artistsNames: 'Hoàng Dũng',
      code: 'live-code-three',
    ),
  ];
  return ChartSnapshot(
    songs: songs,
    series: {
      for (var songIndex = 0; songIndex < songs.length; songIndex++)
        songs[songIndex].id: [
          for (var hour = 0; hour < 8; hour++)
            ChartPoint(
              time: DateTime(2026, 8, 24, hour * 3),
              hour: (hour * 3).toString().padLeft(2, '0'),
              counter: 24 + songIndex * 16 + ((hour * 13) % 39),
            ),
        ],
    },
    songMetadata: const {
      'live-one': ChartSongMetadata(rankChange: 2),
      'live-two': ChartSongMetadata(rankChange: -1),
      'live-three': ChartSongMetadata(rankChange: 0),
    },
    minScore: 20,
    maxScore: 100,
    updatedAt: DateTime(2026, 8, 24, 21),
  );
}

DiscoveryHome _collectionCarouselHome({int offset = 0}) => DiscoveryHome(
  updatedAt: null,
  banners: const [],
  sections: [
    DiscoverySection(
      id: 'carousel-section',
      title: 'Album Hot',
      collections: List.generate(10, (index) {
        final item = index + offset;
        return DiscoveryCollection(
          collection: CatalogCollection(
            id: 'carousel-$item',
            title: 'Album nổi bật ${item + 1}',
            artist: 'Nghệ sĩ ${item + 1}',
            thumbnail: '',
            kind: CatalogCollectionKind.album,
            externalUrl: '',
          ),
          description: 'Tuyển tập chính thức từ Zing MP3.',
        );
      }),
    ),
  ],
);

ScrollPosition _bannerScrollPosition(WidgetTester tester) {
  final list = find.byKey(const ValueKey('discovery-banner-list'));
  final scrollable = find.descendant(
    of: list,
    matching: find.byType(Scrollable),
  );
  expect(scrollable, findsOneWidget);
  return tester.state<ScrollableState>(scrollable).position;
}

Future<void> _pumpRail(
  WidgetTester tester,
  Size viewport,
  DiscoveryHome home, {
  bool tvMode = false,
  bool loading = false,
  bool disableAnimations = false,
  ValueChanged<CatalogCollection>? onCollectionTap,
  ValueChanged<CatalogCollection>? onCollectionPlay,
  ValueChanged<CatalogCollection>? onCollectionToggleSaved,
  ValueChanged<CatalogCollection>? onCollectionShare,
  ValueChanged<CatalogArtist>? onCollectionArtistTap,
  Set<String> savedCollectionIds = const {},
  String? quickPlayingCollectionId,
  ValueChanged<CatalogVideo>? onVideoTap,
  VoidCallback? onOpenTop100,
  List<Song> recentlyPlayed = const [],
  ValueChanged<Song>? onRecentSongTap,
  SongActionMenuConfiguration Function(Song)? recentSongActionResolver,
  VoidCallback? onOpenLibrary,
  List<NewReleaseEntry> chartEntries = const [],
  ValueChanged<NewReleaseEntry>? onChartEntryTap,
  SongActionMenuConfiguration Function(NewReleaseEntry)?
  newReleaseChartActionResolver,
  VoidCallback? onOpenChart,
  ChartSnapshot realtimeChartSnapshot = const ChartSnapshot(songs: []),
  void Function(Song song, List<Song> queue)? onRealtimeChartPlay,
  VoidCallback? onOpenRealtimeChart,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    _railApp(
      home,
      tvMode: tvMode,
      loading: loading,
      disableAnimations: disableAnimations,
      onCollectionTap: onCollectionTap,
      onCollectionPlay: onCollectionPlay,
      onCollectionToggleSaved: onCollectionToggleSaved,
      onCollectionShare: onCollectionShare,
      onCollectionArtistTap: onCollectionArtistTap,
      savedCollectionIds: savedCollectionIds,
      quickPlayingCollectionId: quickPlayingCollectionId,
      onVideoTap: onVideoTap,
      onOpenTop100: onOpenTop100,
      recentlyPlayed: recentlyPlayed,
      onRecentSongTap: onRecentSongTap,
      recentSongActionResolver: recentSongActionResolver,
      onOpenLibrary: onOpenLibrary,
      chartEntries: chartEntries,
      onChartEntryTap: onChartEntryTap,
      newReleaseChartActionResolver: newReleaseChartActionResolver,
      onOpenChart: onOpenChart,
      realtimeChartSnapshot: realtimeChartSnapshot,
      onRealtimeChartPlay: onRealtimeChartPlay,
      onOpenRealtimeChart: onOpenRealtimeChart,
    ),
  );
  if (loading) {
    await tester.pump(const Duration(milliseconds: 100));
  } else {
    await tester.pumpAndSettle();
  }
}

Widget _railApp(
  DiscoveryHome home, {
  bool tvMode = false,
  bool loading = false,
  bool disableAnimations = false,
  ValueChanged<CatalogCollection>? onCollectionTap,
  ValueChanged<CatalogCollection>? onCollectionPlay,
  ValueChanged<CatalogCollection>? onCollectionToggleSaved,
  ValueChanged<CatalogCollection>? onCollectionShare,
  ValueChanged<CatalogArtist>? onCollectionArtistTap,
  Set<String> savedCollectionIds = const {},
  String? quickPlayingCollectionId,
  ValueChanged<CatalogVideo>? onVideoTap,
  VoidCallback? onOpenTop100,
  List<Song> recentlyPlayed = const [],
  ValueChanged<Song>? onRecentSongTap,
  SongActionMenuConfiguration Function(Song)? recentSongActionResolver,
  VoidCallback? onOpenLibrary,
  List<NewReleaseEntry> chartEntries = const [],
  ValueChanged<NewReleaseEntry>? onChartEntryTap,
  SongActionMenuConfiguration Function(NewReleaseEntry)?
  newReleaseChartActionResolver,
  VoidCallback? onOpenChart,
  ChartSnapshot realtimeChartSnapshot = const ChartSnapshot(songs: []),
  void Function(Song song, List<Song> queue)? onRealtimeChartPlay,
  VoidCallback? onOpenRealtimeChart,
}) => MaterialApp(
  theme: ThemeData.dark(useMaterial3: true),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      child: DiscoveryHomeHub(
        home: home,
        loading: loading,
        errorMessage: null,
        onRetry: _noop,
        categories: const [],
        categoriesLoading: false,
        categoriesErrorMessage: null,
        selectedCategoryId: home.categoryId,
        onCategorySelected: (_) {},
        onRetryCategories: _noop,
        onCollectionTap: onCollectionTap ?? (_) {},
        onCollectionPlay: onCollectionPlay,
        onCollectionToggleSaved: onCollectionToggleSaved,
        onCollectionShare: onCollectionShare,
        onCollectionArtistTap: onCollectionArtistTap,
        savedCollectionIds: savedCollectionIds,
        quickPlayingCollectionId: quickPlayingCollectionId,
        onVideoTap: onVideoTap ?? (_) {},
        recentlyPlayed: recentlyPlayed,
        onRecentSongTap: onRecentSongTap,
        recentSongActionResolver: recentSongActionResolver,
        onOpenLibrary: onOpenLibrary,
        newReleaseChartEntries: chartEntries,
        onNewReleaseChartEntryTap: onChartEntryTap,
        newReleaseChartActionResolver: newReleaseChartActionResolver,
        onOpenNewReleaseChart: onOpenChart,
        realtimeChartSnapshot: realtimeChartSnapshot,
        onRealtimeChartPlay: onRealtimeChartPlay,
        onOpenRealtimeChart: onOpenRealtimeChart,
        onOpenHubHome: _noop,
        onOpenTop100: onOpenTop100 ?? _noop,
        onOpenReleases: _noop,
        onOpenWeeklyChart: _noop,
        recommendations: const [],
        canRefreshRecommendations: false,
        onRecommendationTap: (_) {},
        onRefreshRecommendations: _noop,
        releaseSongs: const [],
        releaseLoading: false,
        releaseErrorMessage: null,
        releaseRegion: DiscoveryReleaseRegion.all,
        onReleaseRegionChanged: (_) {},
        onReleaseTap: (_) {},
        onRetryReleases: _noop,
        tvMode: tvMode,
      ),
    ),
  ),
);
