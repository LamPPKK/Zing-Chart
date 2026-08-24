import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/widgets/artwork_backdrop.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('artwork atmosphere stays decorative and fail-safe', (
    tester,
  ) async {
    const imageUrl = 'https://image.example.com/album.jpg';
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.expand(child: ArtworkBackdrop(imageUrl: imageUrl)),
      ),
    );

    final active = find.byKey(const ValueKey('artwork-backdrop-$imageUrl'));
    expect(active, findsOneWidget);
    expect(
      find.ancestor(of: active, matching: find.byType(ExcludeSemantics)),
      findsOneWidget,
    );
    final pointerAncestors = find
        .ancestor(of: active, matching: find.byType(IgnorePointer))
        .evaluate()
        .map((element) => element.widget)
        .whereType<IgnorePointer>();
    expect(pointerAncestors.any((widget) => widget.ignoring), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('artwork atmosphere keeps a local fallback when art is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.expand(child: ArtworkBackdrop(imageUrl: '')),
      ),
    );

    expect(
      find.byKey(const ValueKey('artwork-backdrop-empty')),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
