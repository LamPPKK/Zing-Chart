import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/lyric_share_card.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/models/song_lyrics.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/services/lyric_share_image_renderer.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/services/wrapped_export_service.dart';
import 'package:zmp3chart/theme/app_theme.dart';
import 'package:zmp3chart/widgets/lyric_share_composer.dart';
import 'package:zmp3chart/widgets/song_lyrics_panel.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Lyric Share payload is bounded and versioned', () {
    final data = LyricShareCardData(
      song: _song,
      lines: [
        '  Câu   thứ nhất  ',
        List.filled(260, 'a').join(),
        'Câu thứ ba',
        'Câu thứ tư',
        'Câu thứ năm không được lấy',
      ],
    );

    expect(data.lines, hasLength(4));
    expect(data.lines.first, 'Câu thứ nhất');
    expect(data.lines[1].length, LyricShareCardData.maxLineCharacters);
    final payload = jsonDecode(data.payload.encode()) as Map<String, dynamic>;
    expect(payload['v'], 1);
    expect(payload['type'], 'zingchart-lyrics');
    expect(payload['title'], _song.displayTitle);
    expect(payload['lines'], hasLength(4));
  });

  testWidgets('Canvas renderer creates a standalone Lyric Card PNG', (
    tester,
  ) async {
    final bytes = await tester.runAsync(
      () => const CanvasLyricShareImageRenderer().render(
        LyricShareCardData(
          song: _song,
          lines: const ['Mình từng đi qua những ngày mưa', 'Để thấy trời xanh'],
        ),
      ),
    );

    expect(bytes, isNotNull);
    expect(bytes!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(bytes.length, greaterThan(1000));
  });

  for (final viewport in const [
    (size: Size(360, 844), tvMode: false),
    (size: Size(768, 1024), tvMode: false),
    (size: Size(1440, 900), tvMode: false),
    (size: Size(1920, 1080), tvMode: true),
  ]) {
    testWidgets(
      'Lyric Share composer stays adaptive at ${viewport.size.width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = viewport.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildZingDarkTheme(tvMode: viewport.tvMode),
            home: Scaffold(
              body: LyricShareComposer(
                song: _song,
                lyrics: _lyrics,
                initialLineIndex: 1,
                tvMode: viewport.tvMode,
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        expect(
          find.byKey(const ValueKey('lyric-share-composer')),
          findsOneWidget,
        );
        expect(find.text('TẠO LYRIC CARD'), findsOneWidget);
        expect(
          find.text('1/4 câu · ảnh được dựng hoàn toàn trên thiết bị'),
          findsOneWidget,
        );
        expect(FocusManager.instance.primaryFocus, isNotNull);
        expect(tester.takeException(), isNull, reason: '${viewport.size}');
      },
    );
  }

  testWidgets('selects lyric lines and exports the exact local card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final exporter = _FakeExporter();
    final renderer = _FakeRenderer();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          body: LyricShareComposer(
            song: _song,
            lyrics: _lyrics,
            initialLineIndex: 1,
            exportService: exporter,
            imageRenderer: renderer,
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('lyric-share-line-2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('lyric-share-export')));
    await _pumpUntil(tester, () => exporter.bytes != null);
    await tester.pumpAndSettle();

    expect(renderer.data?.lines, ['Dòng thứ hai', 'Dòng thứ ba']);
    expect(exporter.bytes, Uint8List.fromList(_pngHeader));
    expect(exporter.fileName, 'zingchart-lyrics-song-one.png');
    expect(find.text('Đã lưu Lyric Card'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV uses a local QR handoff without invoking file export', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final exporter = _FakeExporter();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildZingDarkTheme(tvMode: true),
        home: Scaffold(
          body: LyricShareComposer(
            song: _song,
            lyrics: _lyrics,
            initialLineIndex: 0,
            tvMode: true,
            exportService: exporter,
            imageRenderer: _FakeRenderer(),
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lyric-share-export')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lyric-share-qr')), findsOneWidget);
    expect(find.textContaining('không gửi dữ liệu'), findsOneWidget);
    expect(exporter.calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Lyrics header opens the composer on the active line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = FakePlaybackAudioPlayer();
    final controller = PlaybackService(
      playbackAudioPlayer: audio,
      sourceResolver: (_) async => 'https://audio.example/song.mp3',
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    await controller.playSong(_song);
    audio
      ..emitDuration(const Duration(minutes: 3))
      ..emitPosition(const Duration(milliseconds: 2500));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          body: SongLyricsPanel(
            controller: controller,
            lyricsLoader: (_) async => _lyrics,
            shareExportService: _FakeExporter(),
            shareImageRenderer: _FakeRenderer(),
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('song-lyrics-share')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lyric-share-composer')), findsOneWidget);
    final selected = tester.widget<Checkbox>(
      find
          .descendant(
            of: find.byKey(const ValueKey('lyric-share-line-1')),
            matching: find.byType(Checkbox),
          )
          .first,
    );
    expect(selected.value, isTrue);
    expect(tester.takeException(), isNull);
  });
}

const _song = Song(
  id: 'song-one',
  name: 'mot-doi',
  title: 'Một Đời',
  thumbnail: '',
  artistsNames: '14 Casper & Bon Nghiêm',
  code: 'code-one',
);

const _lyrics = SongLyrics(
  songId: 'code-one',
  synced: true,
  lines: [
    LyricLine(
      start: Duration.zero,
      end: Duration(seconds: 2),
      text: 'Dòng thứ nhất',
    ),
    LyricLine(
      start: Duration(seconds: 2),
      end: Duration(seconds: 4),
      text: 'Dòng thứ hai',
    ),
    LyricLine(
      start: Duration(seconds: 4),
      end: Duration(seconds: 6),
      text: 'Dòng thứ ba',
    ),
    LyricLine(
      start: Duration(seconds: 6),
      end: Duration(seconds: 8),
      text: 'Dòng thứ tư',
    ),
    LyricLine(
      start: Duration(seconds: 8),
      end: Duration(seconds: 10),
      text: 'Dòng thứ năm',
    ),
  ],
);

const _pngHeader = [137, 80, 78, 71, 13, 10, 26, 10];

class _FakeExporter implements WrappedExportService {
  int calls = 0;
  Uint8List? bytes;
  String? fileName;

  @override
  Future<WrappedExportResult> exportPng(
    Uint8List bytes, {
    required String fileName,
    required String title,
  }) async {
    calls++;
    this.bytes = bytes;
    this.fileName = fileName;
    return WrappedExportResult.saved;
  }
}

class _FakeRenderer implements LyricShareImageRenderer {
  LyricShareCardData? data;

  @override
  Future<Uint8List> render(LyricShareCardData data) async {
    this.data = data;
    return Uint8List.fromList(_pngHeader);
  }
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 50 && !condition(); attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}
