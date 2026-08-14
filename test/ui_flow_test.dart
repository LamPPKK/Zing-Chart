import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/services/library_backup_file_service.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/zing_chart_screen.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const songs = [
    Song(
      id: 'one',
      name: 'mot-bai-hat',
      title: 'Một Bài Hát',
      thumbnail: '',
      artistsNames: 'Ca Sĩ A',
      code: 'code-one',
    ),
    Song(
      id: 'two',
      name: 'nang-tho',
      title: 'Nàng Thơ',
      thumbnail: '',
      artistsNames: 'Hoàng Dũng',
      code: 'code-two',
    ),
  ];

  testWidgets('shows chart load failure and retries successfully', (
    tester,
  ) async {
    var attempts = 0;
    final controller = await _createController();
    addTearDown(controller.dispose);

    await _pumpChart(
      tester,
      controller,
      loader: () async {
        attempts++;
        if (attempts == 1) throw Exception('proxy offline');
        return songs;
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa tải được bảng xếp hạng'), findsOneWidget);
    expect(find.textContaining('proxy offline'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Một Bài Hát'), findsOneWidget);
    expect(find.text('Nàng Thơ'), findsOneWidget);
  });

  testWidgets('shows loading and empty states', (tester) async {
    final result = Completer<List<Song>>();
    final controller = await _createController();
    addTearDown(controller.dispose);

    await _pumpChart(tester, controller, loader: () => result.future);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    result.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy bài hát phù hợp'), findsOneWidget);
  });

  testWidgets('selects a song and controls playback from Now Playing', (
    tester,
  ) async {
    final audio = FakePlaybackAudioPlayer();
    final controller = await _createController(audio);
    addTearDown(controller.dispose);

    await _pumpChart(tester, controller, loader: () async => songs);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Một Bài Hát'));
    await tester.pumpAndSettle();

    expect(controller.currentSong, songs.first);
    expect(controller.isPlaying, isTrue);
    expect(find.text('ĐANG PHÁT TỪ'), findsOneWidget);
    expect(find.text('Ca Sĩ A'), findsWidgets);
    expect(
      find.byKey(const ValueKey('player-progress-slider')),
      findsOneWidget,
    );
    expect(find.byTooltip('Dừng phát'), findsOneWidget);

    final playButton = find.byKey(const ValueKey('primary-play-pause-button'));
    await tester.ensureVisible(playButton);
    await tester.pumpAndSettle();
    await tester.tap(playButton);
    await tester.pump();
    expect(audio.pauseCalls, 1);
    expect(find.bySemanticsLabel('Phát'), findsOneWidget);

    await tester.tap(find.byTooltip('Yêu thích'));
    await tester.pump();
    expect(controller.isLiked(songs.first), isTrue);
    expect(find.byTooltip('Bỏ yêu thích'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sleep-timer-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sau khi phát xong bài này'));
    await tester.pumpAndSettle();
    expect(controller.sleepAfterCurrentSong, isTrue);
    expect(find.text('Tắt sau bài này'), findsOneWidget);

    final queueButton = find.text('Hàng đợi · 2 bài');
    await tester.ensureVisible(queueButton);
    await tester.pumpAndSettle();
    await tester.tap(queueButton);
    await tester.pumpAndSettle();
    expect(find.text('Hàng đợi phát'), findsOneWidget);
    expect(find.text('Đang phát'), findsOneWidget);

    await tester.tap(find.byTooltip('Xóa khỏi hàng đợi'));
    await tester.pump();
    expect(controller.queue, [songs.first]);

    Navigator.of(tester.element(find.text('Hàng đợi phát'))).pop();
    await tester.pumpAndSettle();
    final stopButton = find.byTooltip('Dừng phát');
    await tester.ensureVisible(stopButton);
    await tester.pumpAndSettle();
    await tester.tap(stopButton);
    await tester.pump();
    expect(controller.state, PlayerState.stopped);
    expect(controller.position, Duration.zero);
  });

  testWidgets('desktop keyboard shortcuts control search, playback and panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = FakePlaybackAudioPlayer();
    final controller = await _createController(audio);
    addTearDown(controller.dispose);

    await _pumpChart(tester, controller, loader: () async => songs);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Một Bài Hát').first);
    await tester.pumpAndSettle();
    expect(controller.currentSong, songs.first);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(audio.pauseCalls, 1);

    await _sendModifiedKey(
      tester,
      modifier: LogicalKeyboardKey.controlLeft,
      key: LogicalKeyboardKey.arrowRight,
    );
    await tester.pumpAndSettle();
    expect(controller.currentSong, songs[1]);

    await _sendModifiedKey(
      tester,
      modifier: LogicalKeyboardKey.controlLeft,
      key: LogicalKeyboardKey.keyF,
    );
    await tester.pump();
    final searchField = tester.widget<TextField>(
      find.byKey(const ValueKey('chart-search-field')),
    );
    expect(searchField.focusNode?.hasFocus, isTrue);
    expect(find.text('Tìm kiếm'), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byTooltip('Dừng phát'), findsNothing);
    expect(find.byTooltip('Hiện bảng đang phát'), findsOneWidget);
  });

  testWidgets('creates a local playlist and exports a JSON backup', (
    tester,
  ) async {
    final backupFiles = _FakeBackupFileService();
    final controller = await _createController();
    addTearDown(controller.dispose);

    await _pumpChart(
      tester,
      controller,
      loader: () async => songs,
      backupFileService: backupFiles,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.library_music_outlined));
    await tester.pumpAndSettle();

    final createButton = find.byKey(const ValueKey('create-playlist-button'));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -360));
    await tester.pumpAndSettle();
    expect(createButton, findsOneWidget);
    await tester.tap(createButton);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('playlist-name-field')),
      'Buổi sáng',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(controller.playlists.single.name, 'Buổi sáng');

    final exportButton = find.byKey(const ValueKey('export-backup-button'));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(exportButton, findsOneWidget);
    await tester.tap(exportButton);
    await tester.pumpAndSettle();
    expect(backupFiles.exportedJson, contains('zingchart-library'));
    expect(find.text('Đã xuất backup thư viện'), findsOneWidget);
  });

  testWidgets('keeps backup restore usable after malformed nested JSON', (
    tester,
  ) async {
    final backupFiles = _FakeBackupFileService(
      importedJson:
          '{"schema":"zingchart-library","version":1,'
          '"library":{"likedSongs":[{"id":1}]}}',
    );
    final controller = await _createController();
    addTearDown(controller.dispose);

    await _pumpChart(
      tester,
      controller,
      loader: () async => songs,
      backupFileService: backupFiles,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.library_music_outlined));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('import-backup-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm-import-backup-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('File backup #zingChart có dữ liệu không hợp lệ.'),
      findsOneWidget,
    );
    final restoreButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('confirm-import-backup-button')),
    );
    expect(restoreButton.onPressed, isNotNull);
  });

  testWidgets('TV layout supports D-pad focus and remote media keys', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = FakePlaybackAudioPlayer();
    final controller = await _createController(audio);
    addTearDown(controller.dispose);

    await _pumpChart(
      tester,
      controller,
      loader: () async => songs,
      tvMode: true,
    );
    await tester.pumpAndSettle();

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.text('Chọn một bài để bắt đầu'), findsOneWidget);
    expect(find.byKey(const ValueKey('one')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.currentSong, songs.first);
    expect(find.text('ĐANG PHÁT'), findsOneWidget);
    expect(find.text('ĐANG PHÁT TỪ'), findsNothing);

    audio.emitDuration(const Duration(minutes: 3));
    audio.emitPosition(const Duration(seconds: 30));
    await tester.pump();
    final seeksBeforeDpad = audio.seekTargets.length;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(audio.seekTargets, hasLength(seeksBeforeDpad));

    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
    await tester.pump();
    expect(audio.pauseCalls, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.mediaFastForward);
    await tester.pump();
    expect(audio.seekTargets.last, const Duration(seconds: 40));

    await tester.sendKeyEvent(LogicalKeyboardKey.mediaTrackNext);
    await tester.pumpAndSettle();
    expect(controller.currentSong, songs[1]);

    await tester.tap(find.text('Tìm kiếm').first);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('chart-search-field')))
          .focusNode
          ?.hasFocus,
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('chart-search-field')))
          .focusNode
          ?.hasFocus,
      isFalse,
    );
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      1,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      0,
    );

    await tester.tap(find.text('Thư viện').first);
    await tester.pump();
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      2,
    );
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      0,
    );
  });
}

Future<PlaybackService> _createController([
  FakePlaybackAudioPlayer? audio,
]) async {
  final controller = PlaybackService(
    playbackAudioPlayer: audio ?? FakePlaybackAudioPlayer(),
    sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
    libraryRepository: MemoryLibraryRepository(),
    systemMediaBridge: NoopSystemMediaBridge(),
  );
  await controller.initialize();
  return controller;
}

Future<void> _pumpChart(
  WidgetTester tester,
  PlaybackService controller, {
  required Future<List<Song>> Function() loader,
  bool tvMode = false,
  LibraryBackupFileService? backupFileService,
}) => tester.pumpWidget(
  MusicPlayerScope(
    controller: controller,
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: ZingChartScreen(
        loadSongs: loader,
        tvMode: tvMode,
        backupFileService: backupFileService,
      ),
    ),
  ),
);

class _FakeBackupFileService implements LibraryBackupFileService {
  _FakeBackupFileService({this.importedJson});

  String? exportedJson;
  final String? importedJson;

  @override
  Future<bool> exportJson(String json, {required String fileName}) async {
    exportedJson = json;
    return true;
  }

  @override
  Future<String?> importJson() async => importedJson;
}

Future<void> _sendModifiedKey(
  WidgetTester tester, {
  required LogicalKeyboardKey modifier,
  required LogicalKeyboardKey key,
}) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
}
