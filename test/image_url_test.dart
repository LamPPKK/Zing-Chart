import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/utils/image_url.dart';

void main() {
  test('normalizes protocol-relative and legacy HTTP artwork URLs', () {
    expect(
      normalizeImageUrl('//photo-resize-zmp3.zmdcdn.me/cover.jpg'),
      'https://photo-resize-zmp3.zmdcdn.me/cover.jpg',
    );
    expect(
      normalizeImageUrl('HTTP://cdn.example.test/cover.jpg'),
      'https://cdn.example.test/cover.jpg',
    );
  });

  test('preserves secure URLs and handles empty artwork', () {
    const url = 'https://cdn.example.test/cover.jpg';
    expect(normalizeImageUrl(url), url);
    expect(normalizeImageUrl('  '), isEmpty);
  });
}
