import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/official_content_share_service.dart';
import '../theme/app_theme.dart';

bool isTrustedOfficialContentUrl(OfficialContentShare content) {
  final uri = Uri.tryParse(content.externalUrl);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.host.isEmpty ||
      uri.port != 443) {
    return false;
  }
  final host = uri.host.toLowerCase();
  if (host != 'zingmp3.vn' && !host.endsWith('.zingmp3.vn')) return false;
  return switch (content.kind) {
    OfficialContentKind.song =>
      uri.path.startsWith('/bai-hat/') || uri.path.startsWith('/link/song/'),
    OfficialContentKind.artist => uri.path.startsWith('/nghe-si/'),
    OfficialContentKind.collection =>
      uri.path.startsWith('/album/') ||
          uri.path.startsWith('/playlist/') ||
          _isLegacyCollectionLink(uri),
  };
}

bool _isLegacyCollectionLink(Uri uri) {
  final segments = uri.pathSegments;
  return segments.length == 3 &&
      segments[0] == 'link' &&
      segments[1] == 'album' &&
      RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(segments[2]);
}

Future<void> shareOfficialContent(
  BuildContext context,
  OfficialContentShare content, {
  OfficialContentShareService service =
      const SharePlusOfficialContentShareService(),
  bool forceHandoff = false,
}) async {
  if (!isTrustedOfficialContentUrl(content)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Liên kết Zing MP3 không hợp lệ.')),
    );
    return;
  }
  if (!forceHandoff) {
    try {
      final renderObject = context.findRenderObject();
      final origin = renderObject is RenderBox && renderObject.hasSize
          ? renderObject.localToGlobal(Offset.zero) & renderObject.size
          : null;
      final result = await service.share(content, origin: origin);
      if (result == OfficialContentShareResult.shared) return;
    } catch (_) {
      // Unsupported desktop/Harmony adapters continue with QR and clipboard.
    }
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => _OfficialContentShareDialog(content: content),
  );
}

class _OfficialContentShareDialog extends StatelessWidget {
  const _OfficialContentShareDialog({required this.content});

  final OfficialContentShare content;

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('official-content-share-dialog'),
    insetPadding: const EdgeInsets.all(20),
    titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
    contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
    actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
    title: Row(
      children: [
        const Icon(Icons.ios_share_rounded, color: ZingColors.coral),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Chia sẻ ${content.kindLabel}',
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
                key: const ValueKey('official-content-share-qr'),
                data: content.externalUrl,
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
              content.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            if (content.subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                content.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Quét mã để mở trên Zing MP3 chính thức. Không có lịch sử nghe '
              'hoặc dữ liệu cá nhân nào được đưa vào liên kết.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              content.externalUrl,
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
        key: const ValueKey('official-content-copy-link'),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: content.externalUrl));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã sao chép liên kết chính thức.')),
          );
        },
        icon: const Icon(Icons.copy_rounded),
        label: const Text('Sao chép'),
      ),
      FilledButton(
        autofocus: true,
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Đóng'),
      ),
    ],
  );
}
