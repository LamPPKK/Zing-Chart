import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/listening_analytics.dart';

abstract interface class WrappedImageRenderer {
  Future<Uint8List> render(WrappedSummary summary, int slideIndex);
}

class CanvasWrappedImageRenderer implements WrappedImageRenderer {
  const CanvasWrappedImageRenderer();

  static const double _width = 1080;
  static const double _height = 1350;

  @override
  Future<Uint8List> render(WrappedSummary summary, int slideIndex) async {
    final index = slideIndex.clamp(0, 5);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final colors = _gradients[index];
    final background = ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset.zero,
        const ui.Offset(_width, _height),
        colors,
      );
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, _width, _height), background);
    _drawSignalMark(canvas);
    _drawText(
      canvas,
      '#zingChart',
      x: 82,
      y: 76,
      width: 600,
      size: 34,
      weight: ui.FontWeight.w900,
    );
    _drawText(
      canvas,
      '${summary.year} / 0${index + 1}',
      x: 760,
      y: 86,
      width: 240,
      size: 25,
      weight: ui.FontWeight.w700,
      align: ui.TextAlign.right,
      color: const ui.Color(0xCCFFFFFF),
    );

    final content = _content(index, summary);
    if (content.eyebrow.isNotEmpty) {
      _drawText(
        canvas,
        content.eyebrow,
        x: 82,
        y: 670,
        width: 900,
        size: 26,
        weight: ui.FontWeight.w900,
        color: const ui.Color(0xFFB8F43D),
        letterSpacing: 3,
      );
    }
    _drawText(
      canvas,
      content.headline,
      x: 82,
      y: content.eyebrow.isEmpty ? 650 : 735,
      width: 900,
      size: content.compact ? 62 : 104,
      weight: ui.FontWeight.w900,
      height: 0.96,
    );
    _drawText(
      canvas,
      content.caption,
      x: 82,
      y: content.compact ? 1050 : 975,
      width: 860,
      size: 37,
      weight: ui.FontWeight.w700,
      height: 1.18,
    );
    _drawText(
      canvas,
      'LOCAL-FIRST · CHỈ TRÊN THIẾT BỊ NÀY',
      x: 82,
      y: 1260,
      width: 900,
      size: 22,
      weight: ui.FontWeight.w800,
      color: const ui.Color(0xCCFFFFFF),
      letterSpacing: 2.2,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(_width.toInt(), _height.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (data == null) throw StateError('Không thể mã hóa ảnh Wrapped.');
    return data.buffer.asUint8List();
  }

  void _drawSignalMark(ui.Canvas canvas) {
    final paint = ui.Paint()..color = const ui.Color(0x18FFFFFF);
    canvas.drawCircle(const ui.Offset(940, 270), 230, paint);
    final bar = ui.Paint()
      ..color = const ui.Color(0x24FFFFFF)
      ..strokeCap = ui.StrokeCap.round
      ..strokeWidth = 28;
    for (var index = 0; index < 5; index++) {
      final x = 820.0 + index * 54;
      final height = 90.0 + (index.isEven ? 130 : 40);
      canvas.drawLine(
        ui.Offset(x, 270 - height / 2),
        ui.Offset(x, 270 + height / 2),
        bar,
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
  }) {
    final builder =
        ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: align, maxLines: 6))
          ..pushStyle(
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

  _WrappedImageContent _content(int index, WrappedSummary summary) {
    final topSong = summary.topSongs.firstOrNull?.song;
    final topArtist = summary.topArtists.firstOrNull;
    return switch (index) {
      0 => _WrappedImageContent(
        headline: '${summary.listened.inMinutes}',
        caption: 'phút âm nhạc đã ở bên bạn.',
      ),
      1 => _WrappedImageContent(
        headline: '${summary.qualifiedPlays}',
        caption:
            'lượt nghe hợp lệ · ${(summary.completionRate * 100).round()}% đi đến cuối bài.',
      ),
      2 => _WrappedImageContent(
        eyebrow: 'BÀI HÁT SỐ 1',
        headline: topSong?.displayTitle ?? 'Chưa có',
        caption: topSong?.artistsNames ?? '',
        compact: true,
      ),
      3 => _WrappedImageContent(
        eyebrow: 'NGHỆ SĨ CỦA NĂM',
        headline: topArtist?.artist ?? 'Chưa có',
        caption: '${topArtist?.listened.inMinutes ?? 0} phút đã nghe',
        compact: true,
      ),
      4 => _WrappedImageContent(
        eyebrow: 'TOP 5 CỦA BẠN',
        headline: summary.topSongs.isEmpty
            ? 'Chưa có'
            : summary.topSongs.indexed
                  .map(
                    (entry) => '${entry.$1 + 1}. ${entry.$2.song.displayTitle}',
                  )
                  .join('\n'),
        caption: 'Năm bài hát tạo nên dấu ấn của bạn.',
        compact: true,
      ),
      _ => _WrappedImageContent(
        eyebrow: 'DẤU ẤN LOCAL',
        headline: summary.busiestDay == null
            ? 'Gu riêng.'
            : '${summary.busiestDay!.day}.${summary.busiestDay!.month}',
        caption: summary.busiestDay == null
            ? 'Không cần tài khoản để âm nhạc mang dấu ấn của bạn.'
            : 'Ngày bạn nghe nhiều nhất. Không server nào cần biết điều đó.',
        compact: true,
      ),
    };
  }
}

class _WrappedImageContent {
  const _WrappedImageContent({
    this.eyebrow = '',
    required this.headline,
    required this.caption,
    this.compact = false,
  });

  final String eyebrow;
  final String headline;
  final String caption;
  final bool compact;
}

const _gradients = <List<ui.Color>>[
  [ui.Color(0xFFFF6B4A), ui.Color(0xFF7A251F)],
  [ui.Color(0xFF355D85), ui.Color(0xFF17263A)],
  [ui.Color(0xFF476500), ui.Color(0xFF17230C)],
  [ui.Color(0xFF8B3E78), ui.Color(0xFF30172B)],
  [ui.Color(0xFFBA4C20), ui.Color(0xFF32160E)],
  [ui.Color(0xFF323531), ui.Color(0xFF101113)],
];
