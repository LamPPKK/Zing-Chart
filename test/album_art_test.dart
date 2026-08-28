import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/widgets/album_art.dart';

import 'support/artwork_http_client.dart';

void main() {
  testWidgets('album art configures a resized network image', (tester) async {
    const artworkUrl = 'https://photo-resize-zmp3.zmdcdn.me/w240/cover.jpg';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AlbumArt(
            imageUrl: artworkUrl,
            semanticLabel: 'Ảnh bìa kiểm thử',
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final resized = image.image as ResizeImage;
    expect(image.gaplessPlayback, isTrue);
    expect((resized.imageProvider as NetworkImage).url, artworkUrl);
  });

  testWidgets(
    'loads artwork, retains refresh frames and resets on song change',
    (tester) async {
      final client = ArtworkHttpClient();
      debugNetworkImageHttpClientProvider = () => client;
      addTearDown(() {
        debugNetworkImageHttpClientProvider = null;
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      });

      Future<void> show(String url, String label) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlbumArt(imageUrl: url, semanticLabel: label),
          ),
        ),
      );

      Future<void> deliver(String url, {int statusCode = HttpStatus.ok}) async {
        final provider = tester.widget<Image>(find.byType(Image)).image;
        await tester.runAsync(() async {
          final decoded = Completer<void>();
          final stream = provider.resolve(ImageConfiguration.empty);
          final listener = ImageStreamListener(
            (_, _) => decoded.complete(),
            onError: (error, stack) {
              if (statusCode == HttpStatus.ok) {
                decoded.completeError(error, stack);
              } else {
                decoded.complete();
              }
            },
          );
          stream.addListener(listener);
          try {
            client.respond(url, statusCode: statusCode);
            await decoded.future.timeout(const Duration(seconds: 5));
          } finally {
            stream.removeListener(listener);
          }
        });
        await tester.pump();
      }

      const first = 'https://images.test/first.png';
      const refresh = 'https://images.test/first.png?revision=2';
      const second = 'https://images.test/second.png';
      await show(first, 'Bài thứ nhất');
      await deliver(first);
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(find.byIcon(Icons.graphic_eq_rounded), findsNothing);

      await show(refresh, 'Bài thứ nhất');
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      await deliver(refresh);
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);

      await show(second, 'Bài thứ hai');
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNull);
      await deliver(second, statusCode: HttpStatus.notFound);
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(client.responses.keys, [first, refresh, second]);
      // Flutter checks painting globals before package:test tearDown callbacks.
      debugNetworkImageHttpClientProvider = null;
    },
  );

  testWidgets('album art uses a local fallback for missing URLs', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AlbumArt(imageUrl: '', semanticLabel: 'Ảnh bìa trống'),
        ),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
