import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/models/catalog_artist_detail.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/widgets/artist_biography_section.dart';

import 'support/artwork_http_client.dart';

const _cover = 'https://images.test/artist-cover.png';
const _avatar = 'https://images.test/artist-avatar.png';
final _fallback = find.byKey(
  const ValueKey('artist-biography-artwork-fallback'),
);

void main() {
  for (final width in [360.0, 768.0, 1440.0, 1920.0]) {
    testWidgets(
      'failed artist cover decodes its avatar at ${width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = Size(width, 1080);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _withClient((client) async {
          await _show(tester, tvMode: width == 1920);
          expect(client.requests, [_cover]);
          await _respond(tester, client, _cover, status: HttpStatus.notFound);
          expect(client.requests, [_cover, _avatar]);
          await _respond(tester, client, _avatar);
          expect(
            tester.widget<RawImage>(find.byType(RawImage)).image,
            isNotNull,
          );
          expect(_fallback, findsNothing);
          expect(tester.takeException(), isNull);
        });
      },
    );
  }

  testWidgets('successful artist cover does not request the avatar', (
    tester,
  ) async {
    await _withClient((client) async {
      await _show(tester);
      await _respond(tester, client, _cover);
      expect(client.requests, [_cover]);
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(_fallback, findsNothing);
    });
  });

  testWidgets('missing cover loads the supplied avatar directly', (
    tester,
  ) async {
    await _withClient((client) async {
      await _show(tester, cover: ' ');
      await _respond(tester, client, _avatar);
      expect(client.requests, [_avatar]);
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    });
  });

  testWidgets('both failed images end at the artist placeholder', (
    tester,
  ) async {
    await _withClient((client) async {
      await _show(tester);
      await _respond(tester, client, _cover, status: HttpStatus.notFound);
      await _respond(tester, client, _avatar, status: HttpStatus.notFound);
      expect(client.requests, [_cover, _avatar]);
      expect(_fallback, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('identical cover and avatar are not requested twice', (
    tester,
  ) async {
    await _withClient((client) async {
      await _show(tester, avatar: _cover);
      await _respond(tester, client, _cover, status: HttpStatus.notFound);
      expect(client.requests, [_cover]);
      expect(_fallback, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('empty artist images do not issue a network request', (
    tester,
  ) async {
    await _withClient((client) async {
      await _show(tester, cover: ' ', avatar: ' ');
      expect(client.requests, isEmpty);
      expect(_fallback, findsOneWidget);
    });
  });

  testWidgets('changing artist clears the previously decoded fallback', (
    tester,
  ) async {
    await _withClient((client) async {
      await _show(tester);
      await _respond(tester, client, _cover, status: HttpStatus.notFound);
      await _respond(tester, client, _avatar);
      const nextCover = 'https://images.test/next-cover.png';
      await _show(tester, cover: nextCover, name: 'Nghệ sĩ tiếp theo');
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNull);
      await _respond(tester, client, nextCover);
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(client.requests, [_cover, _avatar, nextCover]);
      expect(_fallback, findsNothing);
    });
  });
}

Future<void> _withClient(Future<void> Function(ArtworkHttpClient) body) async {
  final previous = debugNetworkImageHttpClientProvider;
  final client = ArtworkHttpClient();
  debugNetworkImageHttpClientProvider = () => client;
  try {
    await body(client);
  } finally {
    debugNetworkImageHttpClientProvider = previous;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
}

Future<void> _show(
  WidgetTester tester, {
  String cover = _cover,
  String avatar = _avatar,
  String name = 'Nghệ sĩ kiểm thử',
  bool tvMode = false,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ArtistBiographySection(
          tvMode: tvMode,
          detail: CatalogArtistDetail(
            artist: CatalogArtist(
              id: name,
              name: name,
              aliasName: 'Artist',
              avatar: avatar,
            ),
            cover: cover,
            biography: 'Tiểu sử kiểm thử.',
            realName: '',
            national: '',
            birthday: '',
            totalFollow: 0,
            awardCount: 0,
            songs: const [],
            collectionSections: const [],
            relatedArtists: const [],
            catalogPlaybackEnabled: true,
          ),
        ),
      ),
    ),
  ),
);

Future<void> _respond(
  WidgetTester tester,
  ArtworkHttpClient client,
  String url, {
  int status = HttpStatus.ok,
}) async {
  final imageWidget = tester.widget<Image>(
    find.byWidgetPredicate((widget) {
      if (widget is! Image) return false;
      final provider = widget.image is ResizeImage
          ? (widget.image as ResizeImage).imageProvider
          : widget.image;
      return provider is NetworkImage && provider.url == url;
    }),
  );
  await tester.runAsync(() async {
    final completed = Completer<void>();
    final stream = imageWidget.image.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (_, _) => completed.complete(),
      onError: (error, stack) => status == HttpStatus.ok
          ? completed.completeError(error, stack)
          : completed.complete(),
    );
    stream.addListener(listener);
    try {
      client.respond(url, statusCode: status);
      await completed.future.timeout(const Duration(seconds: 5));
    } finally {
      stream.removeListener(listener);
    }
  });
  await tester.pump();
}
