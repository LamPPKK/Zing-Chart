import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/models/listening_analytics.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/theme/app_theme.dart';
import 'package:zmp3chart/widgets/local_mix_workspace.dart';
import 'package:zmp3chart/widgets/song_action_menu.dart';

void main() {
  const songs = [
    Song(
      id: 'mix-one',
      name: 'mot-ngay-xanh',
      title: 'Một Ngày Xanh',
      thumbnail: '',
      artistsNames: 'Mây Lang Thang',
      code: 'mix-code-one',
    ),
    Song(
      id: 'mix-two',
      name: 'dem-lung-linh',
      title: 'Đêm Lung Linh',
      thumbnail: '',
      artistsNames: 'Lam',
      code: 'mix-code-two',
    ),
    Song(
      id: 'mix-three',
      name: 'nhip-rieng',
      title: 'Nhịp Riêng',
      thumbnail: '',
      artistsNames: 'An Nhiên',
      code: 'mix-code-three',
    ),
  ];

  MixCollection mix({
    List<Song> tracks = songs,
    MoodTag? mood,
    bool coldStart = false,
  }) => MixCollection(
    id: mood == null ? 'daily-local' : 'mood-${mood.name}',
    title: mood == null ? 'Daily Mix' : 'Chill Mix',
    subtitle: mood == null
        ? 'Xếp hạng từ lượt nghe và yêu thích trên thiết bị.'
        : 'Những bài bạn đã chọn cho một nhịp thật chậm.',
    songs: tracks,
    mood: mood,
    isColdStart: coldStart,
  );

  Widget harness({
    required Size size,
    required bool tvMode,
    MixCollection? value,
    bool showBack = true,
    VoidCallback? onBack,
    VoidCallback? onPlayAll,
    VoidCallback? onShuffle,
    ValueChanged<Song>? onSongTap,
    LocalMixSongActionResolver? actionResolver,
  }) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildZingDarkTheme(tvMode: tvMode),
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            LocalMixWorkspace(
              mix: value ?? mix(),
              tvMode: tvMode,
              showBack: showBack,
              currentSongId: songs.first.id,
              isPlaying: true,
              onBack: onBack ?? () {},
              onPlayAll: onPlayAll ?? () {},
              onShuffle: onShuffle ?? () {},
              onSongTap: onSongTap ?? (_) {},
              actionResolver:
                  actionResolver ??
                  (_) => const SongActionMenuConfiguration(
                    handlers: SongActionHandlers(),
                  ),
            ),
          ],
        ),
      ),
    ),
  );

  for (final configuration in [
    (size: const Size(360, 844), tvMode: false),
    (size: const Size(768, 1024), tvMode: false),
    (size: const Size(1440, 900), tvMode: false),
    (size: const Size(1920, 1080), tvMode: true),
  ]) {
    testWidgets(
      'mix workspace is adaptive at ${configuration.size.width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = configuration.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          harness(size: configuration.size, tvMode: configuration.tvMode),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('local-mix-workspace')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('local-mix-hero')), findsOneWidget);
        expect(find.byKey(const ValueKey('local-mix-play')), findsOneWidget);
        expect(find.byKey(const ValueKey('local-mix-shuffle')), findsOneWidget);
        expect(find.text('Daily Mix'), findsOneWidget);
        expect(find.text('Chỉ xử lý trên thiết bị'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('playback, row and canonical overflow actions stay separate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var playCount = 0;
    var shuffleCount = 0;
    Song? selected;
    Song? queued;

    await tester.pumpWidget(
      harness(
        size: const Size(1440, 900),
        tvMode: false,
        onPlayAll: () => playCount++,
        onShuffle: () => shuffleCount++,
        onSongTap: (song) => selected = song,
        actionResolver: (song) => SongActionMenuConfiguration(
          handlers: SongActionHandlers(onAddToQueue: () => queued = song),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('local-mix-play')));
    await tester.tap(find.byKey(const ValueKey('local-mix-shuffle')));
    expect(playCount, 1);
    expect(shuffleCount, 1);

    final firstRow = find.byKey(const ValueKey('local-mix-song-mix-one'));
    await tester.ensureVisible(firstRow);
    await tester.pumpAndSettle();
    await tester.tap(firstRow);
    expect(selected, songs.first);
    expect(queued, isNull);

    final action = find.byKey(const ValueKey('local-mix-action-menu-mix-one'));
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('local-mix-action-menu-item-queue-mix-one')),
    );
    await tester.pumpAndSettle();

    expect(queued, songs.first);
    expect(playCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty cold-start mix explains recovery and disables playback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      harness(
        size: const Size(360, 844),
        tvMode: false,
        value: mix(tracks: const [], mood: MoodTag.chill, coldStart: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('local-mix-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('local-mix-cold-start')), findsOneWidget);
    expect(find.text('Đang học gu của bạn'), findsOneWidget);
    expect(find.textContaining('Gắn mood cho bài hát'), findsWidgets);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('local-mix-play')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('local-mix-shuffle')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked rows expose only safe metadata actions', (tester) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const locked = Song(
      id: 'mix-locked',
      name: 'mix-locked',
      title: 'Bài Bị Giới Hạn',
      thumbnail: '',
      artistsNames: 'Nghệ sĩ khóa',
      code: 'real-but-locked-code',
      playable: false,
    );
    Song? selected;

    await tester.pumpWidget(
      harness(
        size: const Size(768, 1024),
        tvMode: false,
        value: mix(tracks: const [locked]),
        onSongTap: (song) => selected = song,
        actionResolver: (_) => const SongActionMenuConfiguration(
          handlers: SongActionHandlers(
            onPlay: _noop,
            onOpenDetail: _noop,
            onAddToQueue: _noop,
            onStartRadio: _noop,
            onAddToPlaylist: _noop,
            onShare: _noop,
            onToggleLike: _noop,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('local-mix-play')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('local-mix-song-mix-locked')));
    expect(selected, isNull);
    final lockedRow = find.byKey(const ValueKey('local-mix-song-mix-locked'));
    final lockedInkWell = tester.widget<InkWell>(
      find.descendant(of: lockedRow, matching: find.byType(InkWell)).first,
    );
    expect(lockedInkWell.canRequestFocus, isFalse);
    expect(lockedInkWell.mouseCursor, SystemMouseCursors.forbidden);

    await tester.tap(
      find.byKey(const ValueKey('local-mix-action-menu-mix-locked')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('local-mix-action-menu-item-play-mix-locked')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('local-mix-action-menu-item-queue-mix-locked')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('local-mix-action-menu-item-radio-mix-locked')),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey('local-mix-action-menu-item-detail-mix-locked'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('back affordance follows showBack and invokes its callback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var backCount = 0;

    await tester.pumpWidget(
      harness(
        size: const Size(768, 1024),
        tvMode: false,
        onBack: () => backCount++,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('local-mix-back')));
    expect(backCount, 1);

    await tester.pumpWidget(
      harness(size: const Size(768, 1024), tvMode: false, showBack: false),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('local-mix-back')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV focus highlights a row and Enter activates that song', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Song? selected;

    await tester.pumpWidget(
      harness(
        size: const Size(1920, 1080),
        tvMode: true,
        onSongTap: (song) => selected = song,
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey('local-mix-song-mix-one'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    final inkWell = tester.widget<InkWell>(
      find.descendant(of: row, matching: find.byType(InkWell)).first,
    );
    inkWell.focusNode!.requestFocus();
    await tester.pumpAndSettle();

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'local-mix-focus-mix-one',
    );
    final animated = tester.widget<AnimatedContainer>(
      find.descendant(of: row, matching: find.byType(AnimatedContainer)).first,
    );
    final decoration = animated.decoration! as BoxDecoration;
    expect((decoration.border! as Border).top.width, 3);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected, songs.first);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
