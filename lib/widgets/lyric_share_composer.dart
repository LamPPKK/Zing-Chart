import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/lyric_share_card.dart';
import '../models/song.dart';
import '../models/song_lyrics.dart';
import '../services/lyric_share_image_renderer.dart';
import '../services/wrapped_export_service.dart';
import '../theme/app_theme.dart';

Future<void> showLyricShareComposer(
  BuildContext context, {
  required Song song,
  required SongLyrics lyrics,
  required int initialLineIndex,
  bool tvMode = false,
  WrappedExportService? exportService,
  LyricShareImageRenderer? imageRenderer,
}) {
  if (MediaQuery.sizeOf(context).width < 700 && !tvMode) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.94,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: LyricShareComposer(
            song: song,
            lyrics: lyrics,
            initialLineIndex: initialLineIndex,
            exportService: exportService,
            imageRenderer: imageRenderer,
            onClose: () => Navigator.pop(sheetContext),
          ),
        ),
      ),
    );
  }
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.76),
    builder: (dialogContext) => Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.all(tvMode ? 34 : 24),
      child: SizedBox(
        width: tvMode ? 1460 : 1040,
        height: tvMode ? 900 : 780,
        child: LyricShareComposer(
          song: song,
          lyrics: lyrics,
          initialLineIndex: initialLineIndex,
          tvMode: tvMode,
          exportService: exportService,
          imageRenderer: imageRenderer,
          onClose: () => Navigator.pop(dialogContext),
        ),
      ),
    ),
  );
}

class LyricShareComposer extends StatefulWidget {
  const LyricShareComposer({
    super.key,
    required this.song,
    required this.lyrics,
    required this.initialLineIndex,
    required this.onClose,
    this.tvMode = false,
    this.exportService,
    this.imageRenderer,
  });

  final Song song;
  final SongLyrics lyrics;
  final int initialLineIndex;
  final VoidCallback onClose;
  final bool tvMode;
  final WrappedExportService? exportService;
  final LyricShareImageRenderer? imageRenderer;

  @override
  State<LyricShareComposer> createState() => _LyricShareComposerState();
}

class _LyricShareComposerState extends State<LyricShareComposer> {
  late final WrappedExportService _exportService;
  late final LyricShareImageRenderer _imageRenderer;
  late final Set<int> _selectedLines;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _exportService = widget.exportService ?? createWrappedExportService();
    _imageRenderer =
        widget.imageRenderer ?? const CanvasLyricShareImageRenderer();
    final initial =
        widget.initialLineIndex >= 0 &&
            widget.initialLineIndex < widget.lyrics.lines.length
        ? widget.initialLineIndex
        : 0;
    _selectedLines = widget.lyrics.lines.isEmpty ? <int>{} : {initial};
  }

  LyricShareCardData? get _cardData {
    if (_selectedLines.isEmpty) return null;
    final indices = _selectedLines.toList()..sort();
    return LyricShareCardData(
      song: widget.song,
      lines: indices.map((index) => widget.lyrics.lines[index].text),
    );
  }

  void _toggleLine(int index) {
    if (_selectedLines.contains(index)) {
      if (_selectedLines.length == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Giữ lại ít nhất một câu để chia sẻ.')),
        );
        return;
      }
      setState(() => _selectedLines.remove(index));
      return;
    }
    if (_selectedLines.length >= LyricShareCardData.maxLines) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn có thể chọn tối đa 4 câu.')),
      );
      return;
    }
    setState(() => _selectedLines.add(index));
  }

  Future<void> _export() async {
    final data = _cardData;
    if (data == null || _isExporting) return;
    if (widget.tvMode) {
      await _showQrFallback(data);
      return;
    }
    setState(() => _isExporting = true);
    try {
      final bytes = await _imageRenderer.render(data);
      final result = await _exportService.exportPng(
        bytes,
        fileName: 'zingchart-lyrics-${_safeFilePart(widget.song.id)}.png',
        title: '#zingChart · ${widget.song.displayTitle}',
      );
      if (!mounted) return;
      if (result == WrappedExportResult.unavailable) {
        await _showQrFallback(data);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result == WrappedExportResult.saved
                  ? 'Đã lưu Lyric Card'
                  : 'Đã mở chia sẻ Lyric Card',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) await _showQrFallback(data);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _showQrFallback(LyricShareCardData data) => showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 440,
        height: widget.tvMode ? 620 : 550,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              const Text(
                'Mã Lyric Card',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(12),
                      child: QrImageView(
                        key: const ValueKey('lyric-share-qr'),
                        data: data.payload.encode(),
                        version: QrVersions.auto,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: ZingColors.ink,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: ZingColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                data.excerpt,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'QR chỉ chứa đoạn lời và tên bài đã chọn; không gửi dữ liệu lên máy chủ.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Đóng'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    key: const ValueKey('lyric-share-copy'),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: data.payload.encode()),
                      );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Sao chép'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('lyric-share-composer'),
      color: scheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            _ComposerHeader(song: widget.song, onClose: widget.onClose),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 760;
                  final preview = _LyricCardPreview(data: _cardData);
                  final selector = _LineSelector(
                    lyrics: widget.lyrics,
                    selectedLines: _selectedLines,
                    tvMode: widget.tvMode,
                    onToggle: _toggleLine,
                  );
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Padding(
                            padding: EdgeInsets.all(widget.tvMode ? 36 : 24),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 390,
                                  maxHeight: 488,
                                ),
                                child: AspectRatio(
                                  aspectRatio: 0.8,
                                  child: preview,
                                ),
                              ),
                            ),
                          ),
                        ),
                        VerticalDivider(width: 1, color: scheme.outlineVariant),
                        Expanded(flex: 6, child: selector),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      SizedBox(
                        height: (constraints.maxHeight * 0.42)
                            .clamp(220.0, 300.0)
                            .toDouble(),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 1.7,
                              child: preview,
                            ),
                          ),
                        ),
                      ),
                      Expanded(child: selector),
                    ],
                  );
                },
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              padding: EdgeInsets.fromLTRB(
                widget.tvMode ? 30 : 18,
                13,
                widget.tvMode ? 30 : 18,
                16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_selectedLines.length}/4 câu · ảnh được dựng hoàn toàn trên thiết bị',
                      maxLines: 2,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: widget.tvMode ? 17 : 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    key: const ValueKey('lyric-share-export'),
                    onPressed: _cardData == null || _isExporting
                        ? null
                        : _export,
                    style: FilledButton.styleFrom(
                      backgroundColor: ZingColors.lime,
                      foregroundColor: ZingColors.ink,
                      minimumSize: Size(widget.tvMode ? 200 : 150, 52),
                    ),
                    icon: _isExporting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            widget.tvMode
                                ? Icons.qr_code_2_rounded
                                : Icons.ios_share_rounded,
                          ),
                    label: Text(widget.tvMode ? 'MÃ CHIA SẺ' : 'XUẤT ẢNH'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerHeader extends StatelessWidget {
  const _ComposerHeader({required this.song, required this.onClose});

  final Song song;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 12, 13),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [ZingColors.purple, ZingColors.coral],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.format_quote_rounded, color: Colors.white),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TẠO LYRIC CARD',
                style: TextStyle(
                  color: ZingColors.lime,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${song.displayTitle} · ${song.artistsNames}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          key: const ValueKey('lyric-share-close'),
          tooltip: 'Đóng Lyric Card',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );
}

class _LyricCardPreview extends StatelessWidget {
  const _LyricCardPreview({required this.data});

  final LyricShareCardData? data;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 260;
      return Container(
        key: const ValueKey('lyric-share-preview'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 18 : 26),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8B2BC1), Color(0xFF531E76), ZingColors.ink],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 28,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -42,
              top: -36,
              child: Icon(
                Icons.graphic_eq_rounded,
                size: compact ? 140 : 210,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(compact ? 14 : 24),
              child: compact
                  ? _CompactPreviewContent(data: data)
                  : _PortraitPreviewContent(data: data),
            ),
          ],
        ),
      );
    },
  );
}

class _CompactPreviewContent extends StatelessWidget {
  const _CompactPreviewContent({required this.data});

  final LyricShareCardData? data;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Row(
        children: [
          Text(
            '#zingChart',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          Spacer(),
          Text(
            'LYRIC CARD',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
      const SizedBox(height: 9),
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            data?.excerpt ?? 'Chọn một câu lời bài hát',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
      Text(
        data == null
            ? ''
            : '${data!.song.displayTitle} · ${data!.song.artistsNames}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: ZingColors.coral,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _PortraitPreviewContent extends StatelessWidget {
  const _PortraitPreviewContent({required this.data});

  final LyricShareCardData? data;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Row(
        children: [
          Text(
            '#zingChart',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          Spacer(),
          Text(
            'LYRIC CARD',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
      const Spacer(),
      const Text(
        '“',
        style: TextStyle(
          color: ZingColors.lime,
          fontSize: 58,
          height: 0.5,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        data?.excerpt ?? 'Chọn một câu lời bài hát',
        maxLines: 6,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 21,
          height: 1.08,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.6,
        ),
      ),
      const Spacer(),
      Container(height: 1, color: Colors.white24),
      const SizedBox(height: 12),
      Text(
        data?.song.displayTitle ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        data?.song.artistsNames ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: ZingColors.coral,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _LineSelector extends StatelessWidget {
  const _LineSelector({
    required this.lyrics,
    required this.selectedLines,
    required this.tvMode,
    required this.onToggle,
  });

  final SongLyrics lyrics;
  final Set<int> selectedLines;
  final bool tvMode;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(tvMode ? 30 : 20, 20, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chọn tối đa 4 câu',
              style: TextStyle(
                fontSize: tvMode ? 24 : 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ảnh không dùng artwork nên luôn xuất được trên Web và desktop.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: tvMode ? 16 : 12,
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView.builder(
          key: const ValueKey('lyric-share-lines'),
          padding: EdgeInsets.fromLTRB(tvMode ? 22 : 12, 0, 12, 16),
          itemCount: lyrics.lines.length,
          itemBuilder: (context, index) {
            final selected = selectedLines.contains(index);
            final line = lyrics.lines[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Semantics(
                button: true,
                selected: selected,
                label: '${selected ? 'Đã chọn' : 'Chưa chọn'}: ${line.text}',
                child: Material(
                  color: selected
                      ? ZingColors.purple.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    key: ValueKey('lyric-share-line-$index'),
                    onTap: () => onToggle(index),
                    borderRadius: BorderRadius.circular(14),
                    focusColor: ZingColors.lime.withValues(alpha: 0.22),
                    hoverColor: ZingColors.coral.withValues(alpha: 0.1),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: tvMode ? 15 : 11,
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: selected,
                            onChanged: (_) => onToggle(index),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              line.text,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: tvMode ? 20 : 15,
                                height: 1.25,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

String _safeFilePart(String value) {
  final normalized = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-');
  if (normalized.isEmpty) return 'song';
  return normalized.substring(0, normalized.length.clamp(0, 80).toInt());
}
