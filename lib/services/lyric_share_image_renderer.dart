import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/lyric_share_card.dart';

abstract interface class LyricShareImageRenderer {
  Future<Uint8List> render(LyricShareCardData data);
}

class CanvasLyricShareImageRenderer implements LyricShareImageRenderer {
  const CanvasLyricShareImageRenderer();

  static const double _width = 1080;
  static const double _height = 1350;

  @override
  Future<Uint8List> render(LyricShareCardData data) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final background = ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset.zero,
        const ui.Offset(_width, _height),
        const [
          ui.Color(0xFF8B2BC1),
          ui.Color(0xFF531E76),
          ui.Color(0xFF170F23),
        ],
        const [0, 0.46, 1],
      );
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, _width, _height), background);
    _drawAtmosphere(canvas);

    _drawText(
      canvas,
      '#zingChart',
      x: 82,
      y: 74,
      width: 520,
      size: 34,
      weight: ui.FontWeight.w900,
    );
    _drawText(
      canvas,
      'LYRIC CARD · LOCAL-FIRST',
      x: 594,
      y: 85,
      width: 404,
      size: 21,
      weight: ui.FontWeight.w800,
      align: ui.TextAlign.right,
      color: const ui.Color(0xCCFFFFFF),
      letterSpacing: 2.1,
    );

    _drawText(
      canvas,
      '“',
      x: 72,
      y: 214,
      width: 180,
      size: 156,
      weight: ui.FontWeight.w900,
      color: const ui.Color(0xFF27C9A0),
    );
    final excerptLength = data.lines.fold<int>(
      0,
      (total, line) => total + line.length,
    );
    final lyricSize = excerptLength <= 110
        ? 70.0
        : excerptLength <= 220
        ? 56.0
        : 44.0;
    _drawText(
      canvas,
      data.excerpt,
      x: 84,
      y: 360,
      width: 912,
      size: lyricSize,
      weight: ui.FontWeight.w900,
      height: 1.12,
      maxLines: 10,
    );

    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(82, 1082, 916, 2),
        const ui.Radius.circular(2),
      ),
      ui.Paint()..color = const ui.Color(0x44FFFFFF),
    );
    _drawText(
      canvas,
      data.song.displayTitle,
      x: 82,
      y: 1120,
      width: 820,
      size: 38,
      weight: ui.FontWeight.w900,
      maxLines: 2,
    );
    _drawText(
      canvas,
      data.song.artistsNames,
      x: 82,
      y: 1190,
      width: 820,
      size: 27,
      weight: ui.FontWeight.w700,
      color: const ui.Color(0xFFED2B91),
      maxLines: 2,
    );
    _drawText(
      canvas,
      'ẢNH ĐƯỢC TẠO TRÊN THIẾT BỊ · KHÔNG TẢI ARTWORK',
      x: 82,
      y: 1282,
      width: 916,
      size: 18,
      weight: ui.FontWeight.w800,
      color: const ui.Color(0xBFFFFFFF),
      letterSpacing: 1.4,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(_width.toInt(), _height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (bytes == null) throw StateError('Không thể mã hóa Lyric Card.');
    return bytes.buffer.asUint8List();
  }

  void _drawAtmosphere(ui.Canvas canvas) {
    final halo = ui.Paint()
      ..shader = ui.Gradient.radial(const ui.Offset(900, 220), 360, const [
        ui.Color(0x5527C9A0),
        ui.Color(0x0027C9A0),
      ]);
    canvas.drawCircle(const ui.Offset(900, 220), 360, halo);
    final bars = ui.Paint()
      ..color = const ui.Color(0x24FFFFFF)
      ..strokeCap = ui.StrokeCap.round
      ..strokeWidth = 22;
    for (var index = 0; index < 7; index++) {
      final x = 760.0 + index * 45;
      final height = 44.0 + ((index * 37) % 116);
      canvas.drawLine(
        ui.Offset(x, 250 - height / 2),
        ui.Offset(x, 250 + height / 2),
        bars,
      );
    }
  }

  void _drawText(
    ui.Canvas canvas,
    String text, {
    required double x,
    required double y,
    required double width,
    required double size,
    required ui.FontWeight weight,
    ui.Color color = const ui.Color(0xFFFFFFFF),
    ui.TextAlign align = ui.TextAlign.left,
    double height = 1,
    double letterSpacing = 0,
    int maxLines = 6,
  }) {
    final builder =
        ui.ParagraphBuilder(
          ui.ParagraphStyle(
            textAlign: align,
            maxLines: maxLines,
            ellipsis: '…',
          ),
        )..pushStyle(
          ui.TextStyle(
            color: color,
            fontSize: size,
            fontWeight: weight,
            height: height,
            letterSpacing: letterSpacing,
          ),
        );
    builder.addText(text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: width));
    canvas.drawParagraph(paragraph, ui.Offset(x, y));
  }
}
