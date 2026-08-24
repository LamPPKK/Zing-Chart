import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A low-resolution, blurred copy of existing artwork for atmospheric UI.
///
/// The image stays decorative, ignores input and uses Flutter's shared image
/// cache. Failure is intentionally invisible so every surface keeps its local
/// gradient fallback without depending on artwork availability or CORS.
class ArtworkBackdrop extends StatelessWidget {
  const ArtworkBackdrop({
    super.key,
    required this.imageUrl,
    this.opacity = 0.2,
    this.blurSigma = 30,
    this.cacheWidth = 144,
  });

  final String imageUrl;
  final double opacity;
  final double blurSigma;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: imageUrl.isEmpty
            ? const SizedBox.expand(key: ValueKey('artwork-backdrop-empty'))
            : RepaintBoundary(
                key: ValueKey('artwork-backdrop-$imageUrl'),
                child: Opacity(
                  opacity: opacity.clamp(0, 1),
                  child: ImageFiltered(
                    imageFilter: _blurFilter(blurSigma),
                    child: Transform.scale(
                      scale: 1.14,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        cacheWidth: cacheWidth,
                        filterQuality: FilterQuality.low,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    ),
  );
}

ui.ImageFilter _blurFilter(double sigma) => ui.ImageFilter.blur(
  sigmaX: sigma.clamp(0, 64),
  sigmaY: sigma.clamp(0, 64),
  tileMode: ui.TileMode.decal,
);
