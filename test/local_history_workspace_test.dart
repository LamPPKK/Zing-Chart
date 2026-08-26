import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/app_navigation_route.dart';
import 'package:zmp3chart/models/local_library.dart';
import 'package:zmp3chart/models/playback_origin.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/theme/app_theme.dart';
import 'package:zmp3chart/widgets/local_history_workspace.dart';
import 'package:zmp3chart/widgets/song_action_menu.dart';
import 'package:zmp3chart/zing_chart_screen.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const songs = [
    Song(
      id: 'history-one',
      name: 'history-one',
      title: 'Chạm Vào Ký Ức',
      thumbnail: '',
      artistsNames: 'Mây Lang Thang',
      code: 'history-code-one',
    ),
    Song(
      id: 'history-two',
      name: 'history-two',
      title: 'Một Ngày Rất Xanh',
      thumbnail: '',
      artistsNames: 'An Nhiên',
      code: 'history-code-two',
    ),
    Song(
      id: 'history-three',
      name: 'history-three',
      title: 'Phía Sau Mưa',
      thumbnail: '',
      artistsNames: 'Hạ Lam',
      code: 'history-code-three',
    ),
  ];

  final localNow = DateTime(2026, 8, 26, 15, 30);

  List<ListeningRecord> sampleRecords() => [
    ListeningRecord(
      id: 'record-latest',
      song: songs[0],
      playedAt: DateTime(2026, 8, 26, 14, 12).toUtc(),
      listened: const Duration(minutes: 2, seconds: 8),
    ),
    ListeningRecord(
      id: 'record-duplicate',
      song: songs[0],
      playedAt: DateTime(2026, 8, 26, 10, 5).toUtc(),
      listened: const Duration(seconds: 28),
    ),
    ListeningRecord(
      id: 'record-yesterday',
      song: songs[1],
      playedAt: DateTime(2026, 8, 25, 23, 54).toUtc(),
      listened: const Duration(minutes: 1),
    ),
    ListeningRecord(
      id: 'record-older',
      song: songs[2],
      playedAt: DateTime(2026, 8, 20, 8, 1).toUtc(),
      listened: const Duration(seconds: 45),
    ),
  ];

  ListeningRecord legacyLockedRecord({
    String recordId = 'record-legacy-locked',
    String songId = 'legacy-history',
    DateTime? playedAt,
  }) => ListeningRecord(
    id: recordId,
    song: Song.fromJson({
      'id': songId,
      'name': songId,
      'title': 'Bản ghi từ dữ liệu cũ',
      'thumbnail': '',
      'artists_names': 'Nghệ sĩ cũ',
      'code': '$songId-code',
    }),
    playedAt: (playedAt ?? DateTime(2026, 8, 26, 14)).toUtc(),
    listened: const Duration(seconds: 18),
  );

  SongActionMenuConfiguration actionsFor(Song song) =>
      SongActionMenuConfiguration(handlers: const SongActionHandlers());

  Widget workspaceHarness({
    required List<ListeningRecord> records,
    bool tvMode = false,
    String? currentSongId,
    ValueChanged<ListeningRecord>? onTap,
    VoidCallback? onPlay,
    VoidCallback? onShuffle,
    VoidCallback? onClear,
    HistorySongActionResolver? actionResolver,
  }) => MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(
      body: CustomScrollView(
        slivers: [
          LocalHistoryWorkspace(
            records: records,
            tvMode: tvMode,
            currentSongId: currentSongId,
            isPlaying: true,
            onBack: () {},
            onPlayAll: onPlay ?? () {},
            onShuffle: onShuffle ?? () {},
            onClear: onClear ?? () {},
            onRecordTap: onTap ?? (_) {},
            actionResolver: actionResolver ?? actionsFor,
            now: localNow,
          ),
        ],
      ),
    ),
  );

  test(
    'groups UTC records by local calendar day and removes bad duplicates',
    () {
      final records = sampleRecords();
      final groups = groupListeningHistory([
        ...records,
        records.first,
      ], now: localNow);

      expect(groups.map((group) => group.label), [
        'Hôm nay',
        'Hôm qua',
        'Thứ Năm, 20/08/2026',
      ]);
      expect(groups.first.records, hasLength(2));
      expect(groups.expand((group) => group.records), hasLength(4));
    },
  );

  test('builds a newest-first unique queue beyond the old 20-song limit', () {
    final now = DateTime.utc(2026, 8, 26, 12);
    final records = List<ListeningRecord>.generate(25, (index) {
      final song = Song(
        id: 'queue-$index',
        name: 'queue-$index',
        title: 'Bài $index',
        thumbnail: '',
        artistsNames: 'Nghệ sĩ $index',
        code: 'queue-code-$index',
      );
      return ListeningRecord(
        id: 'queue-record-$index',
        song: song,
        playedAt: now.subtract(Duration(minutes: index)),
      );
    });
    records.add(
      ListeningRecord(
        id: 'queue-duplicate',
        song: records[22].song,
        playedAt: now.subtract(const Duration(hours: 6)),
      ),
    );
    records.add(
      ListeningRecord(
        id: 'queue-record-0',
        song: const Song(
          id: 'hidden-by-duplicate-record-id',
          name: 'hidden-by-duplicate-record-id',
          title: 'Không được phát',
          thumbnail: '',
          artistsNames: 'Dữ liệu lỗi',
          code: 'hidden-code',
        ),
        playedAt: now.subtract(const Duration(hours: 8)),
      ),
    );

    final queue = buildRecentPlaybackQueue(records.reversed);

    expect(queue, hasLength(25));
    expect(queue.first.id, 'queue-0');
    expect(queue.last.id, 'queue-24');
    expect(queue.map((song) => song.id).toSet(), hasLength(25));
    expect(
      queue.map((song) => song.id),
      isNot(contains('hidden-by-duplicate-record-id')),
    );
  });

  for (final configuration in [
    (size: const Size(360, 844), tvMode: false),
    (size: const Size(768, 1024), tvMode: false),
    (size: const Size(1440, 900), tvMode: false),
    (size: const Size(1920, 1080), tvMode: true),
  ]) {
    testWidgets(
      'history workspace is adaptive at ${configuration.size.width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = configuration.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          workspaceHarness(
            records: sampleRecords(),
            tvMode: configuration.tvMode,
            currentSongId: songs[0].id,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('local-history-workspace')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('local-history-mosaic')),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Icon &&
                widget.icon == Icons.graphic_eq_rounded &&
                widget.color == ZingColors.purpleBright,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('hero actions and record activation use explicit callbacks', (
    tester,
  ) async {
    var played = false;
    var shuffled = false;
    var cleared = false;
    ListeningRecord? tapped;

    await tester.pumpWidget(
      workspaceHarness(
        records: sampleRecords(),
        onPlay: () => played = true,
        onShuffle: () => shuffled = true,
        onClear: () => cleared = true,
        onTap: (record) => tapped = record,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('local-history-play')));
    await tester.tap(find.byKey(const ValueKey('local-history-shuffle')));
    await tester.tap(find.byKey(const ValueKey('local-history-clear')));
    await tester.tap(
      find.byKey(const ValueKey('local-history-row-record-latest')),
    );

    expect(played, isTrue);
    expect(shuffled, isTrue);
    expect(cleared, isTrue);
    expect(tapped?.id, 'record-latest');
  });

  testWidgets('TV Enter activates a record and focus survives a prepend', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final records = ValueNotifier<List<ListeningRecord>>(sampleRecords());
    addTearDown(records.dispose);
    ListeningRecord? tapped;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: ValueListenableBuilder<List<ListeningRecord>>(
            valueListenable: records,
            builder: (context, value, _) => CustomScrollView(
              slivers: [
                LocalHistoryWorkspace(
                  records: value,
                  tvMode: true,
                  currentSongId: null,
                  isPlaying: false,
                  onBack: () {},
                  onPlayAll: () {},
                  onShuffle: () {},
                  onClear: () {},
                  onRecordTap: (record) => tapped = record,
                  actionResolver: actionsFor,
                  now: localNow,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder focusFinder() => find.byWidgetPredicate(
      (widget) =>
          widget is InkWell &&
          widget.focusNode?.debugLabel == 'local-history-focus-record-latest',
    );
    final focusNode = tester.widget<InkWell>(focusFinder()).focusNode!;
    focusNode.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(tapped?.id, 'record-latest');

    records.value = [
      ListeningRecord(
        id: 'record-prepended',
        song: songs[2],
        playedAt: DateTime(2026, 8, 26, 15).toUtc(),
      ),
      ...records.value,
    ];
    await tester.pumpAndSettle();

    final preserved = tester.widget<InkWell>(focusFinder()).focusNode!;
    expect(identical(preserved, focusNode), isTrue);
    expect(preserved.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty history disables destructive and playback actions', (
    tester,
  ) async {
    await tester.pumpWidget(workspaceHarness(records: const []));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('local-history-empty')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('local-history-play')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('local-history-clear')),
          )
          .onPressed,
      isNull,
    );
  });

  for (final configuration in [
    (name: 'mobile', size: const Size(360, 844), tvMode: false),
    (name: 'TV', size: const Size(1920, 1080), tvMode: true),
  ]) {
    testWidgets(
      'legacy locked history is fail-closed and adaptive on ${configuration.name}',
      (tester) async {
        tester.view.physicalSize = configuration.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final record = legacyLockedRecord();
        final secondRecord = legacyLockedRecord(
          recordId: 'record-legacy-locked-second',
          songId: 'legacy-history-second',
          playedAt: DateTime(2026, 8, 26, 13),
        );
        var playCalls = 0;
        var shuffleCalls = 0;
        var rowTapCalls = 0;
        var safeActionCalls = 0;

        await tester.pumpWidget(
          workspaceHarness(
            records: [record, secondRecord],
            tvMode: configuration.tvMode,
            currentSongId: record.song.id,
            onPlay: () => playCalls += 1,
            onShuffle: () => shuffleCalls += 1,
            onTap: (_) => rowTapCalls += 1,
            actionResolver: (_) => SongActionMenuConfiguration(
              handlers: SongActionHandlers(
                onToggleLike: () => safeActionCalls += 1,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(record.song.isPlaybackEligible, isFalse);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('local-history-play')),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('local-history-shuffle')),
              )
              .onPressed,
          isNull,
        );
        expect(find.textContaining('0/2 bài có thể phát'), findsOneWidget);

        final playbackTarget = find.byKey(
          const ValueKey('local-history-play-target-record-legacy-locked'),
        );
        await tester.ensureVisible(playbackTarget);
        await tester.pumpAndSettle();
        final semanticsHandle = tester.ensureSemantics();
        final semantics = tester
            .getSemantics(playbackTarget)
            .getSemanticsData();
        expect(semantics.label, contains('không thể phát từ lịch sử cũ'));
        expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
        expect(semantics.hasAction(SemanticsAction.tap), isFalse);
        semanticsHandle.dispose();
        expect(
          find.byKey(const ValueKey('local-history-lock-record-legacy-locked')),
          findsOneWidget,
        );

        final playbackInkWell = tester.widget<InkWell>(
          find.descendant(of: playbackTarget, matching: find.byType(InkWell)),
        );
        expect(playbackInkWell.onTap, isNull);
        expect(playbackInkWell.canRequestFocus, isFalse);
        expect(playbackInkWell.mouseCursor, SystemMouseCursors.forbidden);
        expect(playbackInkWell.focusNode?.canRequestFocus, isFalse);
        playbackInkWell.focusNode?.requestFocus();
        await tester.pump();
        expect(playbackInkWell.focusNode?.hasFocus, isFalse);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.tap(playbackTarget);
        await tester.pump();
        expect(rowTapCalls, 0);
        expect(playCalls, 0);
        expect(shuffleCalls, 0);

        await tester.tap(
          find.byKey(
            const ValueKey(
              'local-history-action-record-legacy-locked-menu-legacy-history',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            const ValueKey(
              'local-history-action-record-legacy-locked-menu-item-play-legacy-history',
            ),
          ),
          findsNothing,
        );
        final safeAction = find.byKey(
          const ValueKey(
            'local-history-action-record-legacy-locked-menu-item-like-legacy-history',
          ),
        );
        expect(safeAction, findsOneWidget);
        await tester.tap(safeAction);
        await tester.pumpAndSettle();
        expect(safeActionCalls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'screen plays and clears local history without touching library',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final playlist = LocalPlaylist(
        id: 'history-playlist',
        name: 'Vẫn được giữ',
        createdAt: localNow.toUtc(),
        updatedAt: localNow.toUtc(),
        songs: [songs[1]],
      );
      final controller = PlaybackService(
        playbackAudioPlayer: FakePlaybackAudioPlayer(),
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        libraryRepository: MemoryLibraryRepository(
          PlayerSnapshot(
            likedSongs: [songs[2]],
            playlists: [playlist],
            history: sampleRecords(),
          ),
        ),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              navigationRoute: const AppNavigationRoute.library(
                section: LibrarySection.recent,
              ),
              loadSongs: () async => songs,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('local-history-workspace')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('local-history-play')));
      await tester.pumpAndSettle();
      expect(controller.queue, songs);
      expect(controller.playbackOrigin.kind, PlaybackOriginKind.recentlyPlayed);
      expect(find.byType(ZingChartScreen), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('local-history-workspace')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('local-history-clear')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('local-history-clear-dialog')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('local-history-clear-cancel')),
      );
      await tester.pumpAndSettle();
      expect(controller.history, isNotEmpty);

      await tester.tap(find.byKey(const ValueKey('local-history-clear')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('local-history-clear-confirm')),
      );
      await tester.pumpAndSettle();

      expect(controller.history, isEmpty);
      expect(controller.likedSongs, [songs[2]]);
      expect(controller.playlists.single.name, 'Vẫn được giữ');
      expect(controller.queue, songs);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('local-history-clear')),
            )
            .onPressed,
        isNull,
      );
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -540),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('local-history-empty')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
