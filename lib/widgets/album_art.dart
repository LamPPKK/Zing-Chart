import 'package:flutter/material.dart';

import '../utils/image_url.dart';

class AlbumArt extends StatelessWidget {
  const AlbumArt({
    super.key,
    required this.imageUrl,
    required this.semanticLabel,
    this.size = 64,
    this.borderRadius = 16,
  });

  final String imageUrl;
  final String semanticLabel;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final normalizedImageUrl = normalizeImageUrl(imageUrl);
    return Semantics(
      image: true,
      label: semanticLabel,
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: SizedBox.square(
            dimension: size,
            child: normalizedImageUrl.isEmpty
                ? const _AlbumPlaceholder()
                : Image.network(
                    normalizedImageUrl,
                    webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                    // Keep a frame during a rendition refresh, but never show
                    // the previous track's cover under a new semantic label.
                    key: ValueKey(semanticLabel),
                    fit: BoxFit.cover,
                    cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                        .round(),
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => const _AlbumPlaceholder(),
                  ),
          ),
        ),
      ),
    );
  }
}

class _AlbumPlaceholder extends StatelessWidget {
  const _AlbumPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF292A2E),
      child: Center(
        child: Icon(Icons.graphic_eq_rounded, color: Color(0xFFFF6B4A)),
      ),
    );
  }
}
