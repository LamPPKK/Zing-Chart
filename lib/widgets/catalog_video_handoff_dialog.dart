import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/catalog_search.dart';
import '../theme/app_theme.dart';

typedef CatalogVideoExternalLauncher = Future<bool> Function(Uri uri);

Future<void> showCatalogVideoHandoffDialog(
  BuildContext context,
  CatalogVideo video, {
  CatalogVideoExternalLauncher? externalLauncher,
}) => showDialog<void>(
  context: context,
  builder: (context) => _CatalogVideoHandoffDialog(
    video: video,
    externalLauncher: externalLauncher,
  ),
);

class _CatalogVideoHandoffDialog extends StatefulWidget {
  const _CatalogVideoHandoffDialog({
    required this.video,
    required this.externalLauncher,
  });

  final CatalogVideo video;
  final CatalogVideoExternalLauncher? externalLauncher;

  @override
  State<_CatalogVideoHandoffDialog> createState() =>
      _CatalogVideoHandoffDialogState();
}

class _CatalogVideoHandoffDialogState
    extends State<_CatalogVideoHandoffDialog> {
  bool _isOpening = false;

  Future<void> _openExternal() async {
    final launcher = widget.externalLauncher;
    if (launcher == null || _isOpening) return;
    setState(() => _isOpening = true);
    try {
      final opened = await launcher(Uri.parse(widget.video.externalUrl));
      if (!mounted) return;
      if (opened) {
        Navigator.of(context).pop();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không mở được Zing MP3. Hãy quét hoặc sao chép link.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không mở được Zing MP3. Hãy quét hoặc sao chép link.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('catalog-video-handoff-dialog'),
    insetPadding: const EdgeInsets.all(20),
    titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
    contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
    actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
    title: Row(
      children: [
        const Icon(Icons.ondemand_video_rounded, color: ZingColors.coral),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                key: const ValueKey('catalog-video-qr'),
                data: widget.video.externalUrl,
                size: 188,
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
            const SizedBox(height: 16),
            Text(
              widget.video.artist.isEmpty
                  ? 'MV trên Zing MP3'
                  : widget.video.artist,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              widget.externalLauncher == null
                  ? 'Quét mã để mở MV trên Zing MP3. #zingChart chỉ bàn giao liên kết chính thức, không tải hoặc lưu video.'
                  : 'Chọn Mở Zing MP3 hoặc quét mã. #zingChart chỉ bàn giao liên kết chính thức, không tự phát, tải hoặc lưu video.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              widget.video.externalUrl,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton.icon(
        key: const ValueKey('catalog-video-copy-link'),
        onPressed: () async {
          await Clipboard.setData(
            ClipboardData(text: widget.video.externalUrl),
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã sao chép liên kết MV.')),
          );
        },
        icon: const Icon(Icons.copy_rounded),
        label: const Text('Sao chép'),
      ),
      if (widget.externalLauncher != null)
        TextButton(
          key: const ValueKey('catalog-video-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      if (widget.externalLauncher != null)
        FilledButton.icon(
          key: const ValueKey('catalog-video-open-external'),
          autofocus: true,
          onPressed: _isOpening ? null : _openExternal,
          icon: _isOpening
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.open_in_new_rounded),
          label: Text(_isOpening ? 'ĐANG MỞ…' : 'MỞ ZING MP3'),
        ),
      if (widget.externalLauncher == null)
        FilledButton(
          key: const ValueKey('catalog-video-close'),
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
    ],
  );
}
