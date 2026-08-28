import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/catalog_artist_detail.dart';
import '../theme/app_theme.dart';

/// Editorial "About" section for an official Zing MP3 artist profile.
///
/// The overview intentionally stays compact even when the upstream biography
/// is long. The complete, selectable copy lives in a modal so mobile and TV
/// users do not have to traverse an unexpectedly tall profile page.
class ArtistBiographySection extends StatelessWidget {
  const ArtistBiographySection({
    super.key,
    required this.detail,
    this.tvMode = false,
  });

  final CatalogArtistDetail detail;
  final bool tvMode;

  static bool hasContent(CatalogArtistDetail detail) =>
      detail.biography.trim().isNotEmpty ||
      detail.cover.trim().isNotEmpty ||
      detail.artist.avatar.trim().isNotEmpty ||
      detail.realName.trim().isNotEmpty ||
      detail.national.trim().isNotEmpty ||
      detail.birthday.trim().isNotEmpty ||
      detail.totalFollow > 0 ||
      detail.awardCount > 0;

  Future<void> _showBiography(BuildContext context) => showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (dialogContext) =>
        _ArtistBiographyDialog(detail: detail, tvMode: tvMode),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      key: const ValueKey('artist-biography'),
      container: true,
      label: 'Về ${detail.artist.name}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= (tvMode ? 980 : 820);
          final artSize = (constraints.maxWidth * (tvMode ? 0.31 : 0.34))
              .clamp(tvMode ? 360.0 : 260.0, tvMode ? 460.0 : 360.0)
              .toDouble();
          final artwork = _ArtistAboutArtwork(
            detail: detail,
            size: wide
                ? artSize
                : constraints.maxWidth.clamp(0.0, 420.0).toDouble(),
            borderRadius: tvMode ? 26 : 18,
          );
          final copy = _ArtistAboutCopy(
            detail: detail,
            tvMode: tvMode,
            maxBiographyLines: tvMode
                ? 7
                : wide
                ? 6
                : 5,
            onShowMore: () => _showBiography(context),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Về ${detail.artist.name}',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: tvMode ? 32 : 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.55,
                ),
              ),
              SizedBox(height: tvMode ? 24 : 18),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    artwork,
                    SizedBox(width: tvMode ? 44 : 32),
                    Expanded(child: copy),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(alignment: Alignment.center, child: artwork),
                    SizedBox(height: tvMode ? 30 : 22),
                    copy,
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ArtistAboutCopy extends StatelessWidget {
  const _ArtistAboutCopy({
    required this.detail,
    required this.tvMode,
    required this.maxBiographyLines,
    required this.onShowMore,
  });

  final CatalogArtistDetail detail;
  final bool tvMode;
  final int maxBiographyLines;
  final VoidCallback onShowMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final biography = detail.biography.trim();
    final metadata = _artistMetadata(detail);
    return LayoutBuilder(
      builder: (context, constraints) {
        final biographyStyle = TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: tvMode ? 19 : 15,
          height: 1.62,
        );
        final effectiveBiographyStyle = DefaultTextStyle.of(
          context,
        ).style.merge(biographyStyle);
        final contentPadding = EdgeInsets.all(tvMode ? 30 : 22);
        final biographyWidth = constraints.maxWidth - contentPadding.horizontal;
        final painter = TextPainter(
          text: TextSpan(text: biography, style: effectiveBiographyStyle),
          maxLines: maxBiographyLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: biographyWidth > 0 ? biographyWidth : 0);
        final biographyOverflows =
            biography.isNotEmpty && painter.didExceedMaxLines;
        painter.dispose();
        final focusColor = scheme.brightness == Brightness.dark
            ? ZingColors.lime
            : scheme.primary;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainer.withValues(
              alpha: scheme.brightness == Brightness.dark ? 0.48 : 0.82,
            ),
            borderRadius: BorderRadius.circular(tvMode ? 26 : 18),
            border: Border.all(
              color: scheme.outlineVariant.withValues(
                alpha: scheme.brightness == Brightness.dark ? 0.28 : 0.62,
              ),
            ),
          ),
          child: Padding(
            padding: contentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (biography.isNotEmpty) ...[
                  Text(
                    biography,
                    key: const ValueKey('artist-biography-preview'),
                    maxLines: maxBiographyLines,
                    overflow: TextOverflow.ellipsis,
                    style: effectiveBiographyStyle,
                  ),
                  if (biographyOverflows) ...[
                    SizedBox(height: tvMode ? 10 : 4),
                    TextButton.icon(
                      key: const ValueKey('artist-biography-show-more'),
                      onPressed: onShowMore,
                      style: ButtonStyle(
                        foregroundColor: WidgetStatePropertyAll(
                          scheme.onSurface,
                        ),
                        minimumSize: WidgetStatePropertyAll(
                          Size(0, tvMode ? 56 : 48),
                        ),
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 14),
                        ),
                        shape: const WidgetStatePropertyAll(StadiumBorder()),
                        side: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.focused)) {
                            return BorderSide(color: focusColor, width: 2.5);
                          }
                          if (states.contains(WidgetState.hovered)) {
                            return BorderSide(
                              color: ZingColors.purpleBright.withValues(
                                alpha: 0.64,
                              ),
                            );
                          }
                          return BorderSide(
                            color: scheme.outlineVariant.withValues(alpha: 0.3),
                          );
                        }),
                        textStyle: WidgetStatePropertyAll(
                          TextStyle(
                            fontSize: tvMode ? 15 : 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.85,
                          ),
                        ),
                      ),
                      iconAlignment: IconAlignment.end,
                      icon: Icon(
                        Icons.arrow_outward_rounded,
                        size: tvMode ? 23 : 18,
                      ),
                      label: const Text('XEM THÊM'),
                    ),
                  ],
                ] else
                  Text(
                    'Thông tin giới thiệu sẽ được cập nhật khi hồ sơ Zing MP3 cung cấp.',
                    key: const ValueKey('artist-biography-empty-copy'),
                    style: effectiveBiographyStyle.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                SizedBox(height: tvMode ? 30 : 24),
                Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.36),
                ),
                SizedBox(height: tvMode ? 25 : 20),
                _ArtistStats(detail: detail, tvMode: tvMode),
                if (metadata.isNotEmpty) ...[
                  SizedBox(height: tvMode ? 24 : 18),
                  Wrap(
                    key: const ValueKey('artist-biography-metadata'),
                    spacing: tvMode ? 12 : 8,
                    runSpacing: tvMode ? 12 : 8,
                    children: [
                      for (final item in metadata)
                        _MetadataChip(label: item, tvMode: tvMode),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ArtistStats extends StatelessWidget {
  const _ArtistStats({required this.detail, required this.tvMode});

  final CatalogArtistDetail detail;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final stats = <({String value, String label, IconData icon})>[
      if (detail.totalFollow > 0)
        (
          value: _formatCount(detail.totalFollow),
          label: 'Người quan tâm',
          icon: Icons.people_alt_rounded,
        ),
      if (detail.awardCount > 0)
        (
          value: '${detail.awardCount}',
          label: 'Thành tích',
          icon: Icons.workspace_premium_rounded,
        ),
    ];
    if (stats.isEmpty) return const SizedBox.shrink();

    return Wrap(
      key: const ValueKey('artist-biography-stats'),
      spacing: tvMode ? 44 : 30,
      runSpacing: tvMode ? 20 : 14,
      children: [
        for (final stat in stats)
          _ArtistStat(
            value: stat.value,
            label: stat.label,
            icon: stat.icon,
            tvMode: tvMode,
          ),
      ],
    );
  }
}

class _ArtistStat extends StatelessWidget {
  const _ArtistStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.tvMode,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: ZingColors.purple.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: EdgeInsets.all(tvMode ? 13 : 10),
            child: Icon(
              icon,
              color: ZingColors.purpleBright,
              size: tvMode ? 27 : 21,
            ),
          ),
        ),
        SizedBox(width: tvMode ? 14 : 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: tvMode ? 28 : 22,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: tvMode ? 14 : 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({required this.label, required this.tvMode});

  final String label;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tvMode ? 16 : 12,
          vertical: tvMode ? 10 : 7,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: tvMode ? 14 : 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ArtistAboutArtwork extends StatelessWidget {
  const _ArtistAboutArtwork({
    required this.detail,
    required this.size,
    required this.borderRadius,
  });

  final CatalogArtistDetail detail;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final imageUrl = detail.cover.trim().isNotEmpty
        ? detail.cover.trim()
        : detail.artist.avatar.trim();
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return Semantics(
      image: true,
      label: 'Ảnh giới thiệu ${detail.artist.name}',
      child: RepaintBoundary(
        child: Container(
          key: const ValueKey('artist-biography-artwork'),
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl.isEmpty)
                _ArtistArtworkFallback(name: detail.artist.name)
              else
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  cacheWidth: (size * ratio).round(),
                  errorBuilder: (_, __, ___) =>
                      _ArtistArtworkFallback(name: detail.artist.name),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xA6170F23)],
                    stops: [0.58, 1],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 16,
                child: Text(
                  detail.artist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtistArtworkFallback extends StatelessWidget {
  const _ArtistArtworkFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '#' : name.trim().characters.first;
    return DecoratedBox(
      key: const ValueKey('artist-biography-artwork-fallback'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF563477), Color(0xFF2D1B3F), Color(0xFF1C1428)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -28,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ZingColors.purpleBright.withValues(alpha: 0.24),
                  width: 24,
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              initial.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 88,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistBiographyDialog extends StatefulWidget {
  const _ArtistBiographyDialog({required this.detail, required this.tvMode});

  final CatalogArtistDetail detail;
  final bool tvMode;

  @override
  State<_ArtistBiographyDialog> createState() => _ArtistBiographyDialogState();
}

class _ArtistBiographyDialogState extends State<_ArtistBiographyDialog> {
  final ScrollController _scrollController = ScrollController();

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = (position.pixels + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollByPage(double direction) {
    if (!_scrollController.hasClients) return;
    _scrollBy(_scrollController.position.viewportDimension * 0.8 * direction);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 720;
    final detail = widget.detail;
    final tvMode = widget.tvMode;
    final metadata = _artistMetadata(detail);
    final biography = detail.biography.trim();
    final artworkSize = compact ? 220.0 : (tvMode ? 330.0 : 270.0);
    final body = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: _ArtistAboutArtwork(
                  detail: detail,
                  size: artworkSize,
                  borderRadius: tvMode ? 24 : 18,
                ),
              ),
              SizedBox(height: tvMode ? 28 : 22),
              _BiographyDialogCopy(
                detail: detail,
                biography: biography,
                metadata: metadata,
                tvMode: tvMode,
              ),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ArtistAboutArtwork(
                detail: detail,
                size: artworkSize,
                borderRadius: tvMode ? 24 : 18,
              ),
              SizedBox(width: tvMode ? 38 : 30),
              Expanded(
                child: _BiographyDialogCopy(
                  detail: detail,
                  biography: biography,
                  metadata: metadata,
                  tvMode: tvMode,
                ),
              ),
            ],
          );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
        if (tvMode) ...{
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              _scrollBy(96),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              _scrollBy(-96),
          const SingleActivator(LogicalKeyboardKey.pageDown): () =>
              _scrollByPage(1),
          const SingleActivator(LogicalKeyboardKey.pageUp): () =>
              _scrollByPage(-1),
        },
      },
      child: Semantics(
        namesRoute: true,
        scopesRoute: true,
        explicitChildNodes: true,
        label: 'Giới thiệu đầy đủ về ${detail.artist.name}',
        child: Dialog(
          key: const ValueKey('artist-biography-dialog'),
          insetPadding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 36,
            vertical: compact ? 18 : 36,
          ),
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tvMode ? 30 : 24),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: tvMode ? 1180 : 940,
              maxHeight: MediaQuery.sizeOf(context).height * 0.88,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.fromLTRB(
                    tvMode ? 30 : 22,
                    tvMode ? 24 : 18,
                    tvMode ? 22 : 14,
                    tvMode ? 20 : 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        ZingColors.purple.withValues(alpha: 0.28),
                        scheme.surface,
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.34),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NGHỆ SĨ',
                              style: TextStyle(
                                color: scheme.brightness == Brightness.dark
                                    ? ZingColors.purpleBright
                                    : scheme.primary,
                                fontSize: tvMode ? 14 : 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              detail.artist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: tvMode ? 34 : 25,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.outlined(
                        key: const ValueKey('artist-biography-dialog-close'),
                        autofocus: true,
                        tooltip: 'Đóng giới thiệu nghệ sĩ',
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          minimumSize: Size.square(tvMode ? 58 : 48),
                          foregroundColor: scheme.onSurface,
                          side: BorderSide(
                            color: scheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        icon: Icon(Icons.close_rounded, size: tvMode ? 30 : 24),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: tvMode,
                    child: SingleChildScrollView(
                      key: const ValueKey('artist-biography-dialog-scroll'),
                      controller: _scrollController,
                      padding: EdgeInsets.all(
                        tvMode
                            ? 34
                            : compact
                            ? 20
                            : 28,
                      ),
                      child: body,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BiographyDialogCopy extends StatelessWidget {
  const _BiographyDialogCopy({
    required this.detail,
    required this.biography,
    required this.metadata,
    required this.tvMode,
  });

  final CatalogArtistDetail detail;
  final String biography;
  final List<String> metadata;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ArtistStats(detail: detail, tvMode: tvMode),
        if (metadata.isNotEmpty) ...[
          SizedBox(height: tvMode ? 24 : 18),
          Wrap(
            spacing: tvMode ? 12 : 8,
            runSpacing: tvMode ? 12 : 8,
            children: [
              for (final item in metadata)
                _MetadataChip(label: item, tvMode: tvMode),
            ],
          ),
        ],
        SizedBox(height: tvMode ? 30 : 24),
        Text(
          'Tiểu sử',
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: tvMode ? 25 : 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: tvMode ? 14 : 10),
        SelectableText(
          biography.isEmpty
              ? 'Thông tin giới thiệu sẽ được cập nhật khi hồ sơ Zing MP3 cung cấp.'
              : biography,
          key: const ValueKey('artist-biography-full-text'),
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: tvMode ? 19 : 15,
            height: 1.68,
          ),
        ),
      ],
    );
  }
}

List<String> _artistMetadata(CatalogArtistDetail detail) => [
  if (detail.realName.trim().isNotEmpty) 'Tên thật · ${detail.realName.trim()}',
  if (detail.national.trim().isNotEmpty) 'Quốc gia · ${detail.national.trim()}',
  if (detail.birthday.trim().isNotEmpty)
    'Sinh nhật · ${detail.birthday.trim()}',
];

String _formatCount(int value) {
  final digits = value.toString().split('').reversed.toList();
  final groups = <String>[];
  for (var index = 0; index < digits.length; index += 3) {
    groups.add(digits.skip(index).take(3).toList().reversed.join());
  }
  return groups.reversed.join('.');
}
