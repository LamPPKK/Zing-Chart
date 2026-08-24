import 'package:flutter/material.dart';

import '../models/catalog_search.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';
import 'artwork_backdrop.dart';

enum CollectionDetailHeroLayout { standard, sidebar }

class CollectionDetailHero extends StatelessWidget {
  const CollectionDetailHero({
    super.key,
    required this.collection,
    required this.detail,
    required this.loading,
    required this.onPlay,
    this.onArtistTap,
    this.onShare,
    this.onToggleSave,
    this.isSaved = false,
    this.tvMode = false,
    this.layout = CollectionDetailHeroLayout.standard,
    this.shufflePlay = false,
  });

  final CatalogCollection collection;
  final CatalogCollectionDetail? detail;
  final bool loading;
  final VoidCallback? onPlay;
  final ValueChanged<CatalogArtist>? onArtistTap;
  final VoidCallback? onShare;
  final VoidCallback? onToggleSave;
  final bool isSaved;
  final bool tvMode;
  final CollectionDetailHeroLayout layout;
  final bool shufflePlay;

  @override
  Widget build(BuildContext context) {
    final metadata = detail;
    final effectiveCollection = metadata?.collection ?? collection;
    final songs = metadata?.songs ?? const <CatalogSong>[];
    final duration = metadata?.totalDuration ?? Duration.zero;
    if (layout == CollectionDetailHeroLayout.sidebar) {
      return _buildSidebar(
        context,
        effectiveCollection: effectiveCollection,
        metadata: metadata,
        songCount: songs.length,
        duration: duration,
      );
    }
    return Container(
      key: const ValueKey('collection-detail-hero'),
      margin: EdgeInsets.fromLTRB(
        tvMode ? 32 : 20,
        0,
        tvMode ? 32 : 20,
        tvMode ? 32 : 24,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B327D), Color(0xFF3B244B), Color(0xFF201225)],
        ),
        borderRadius: BorderRadius.circular(tvMode ? 28 : 22),
        border: Border.all(
          color: ZingColors.purpleBright.withValues(alpha: 0.24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: ArtworkBackdrop(
              key: const ValueKey('collection-artwork-atmosphere'),
              imageUrl: effectiveCollection.thumbnail,
              opacity: 0.28,
              blurSigma: 34,
            ),
          ),
          if (effectiveCollection.thumbnail.isNotEmpty)
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0x735B327D),
                      Color(0xD93B244B),
                      Color(0xF2201225),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(tvMode ? 34 : 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 600;
                final artworkSize = tvMode
                    ? 210.0
                    : compact
                    ? 188.0
                    : 190.0;
                final details = _CollectionDetails(
                  collection: effectiveCollection,
                  detail: metadata,
                  songCount: songs.length,
                  duration: duration,
                  loading: loading,
                  onPlay: onPlay,
                  onArtistTap: onArtistTap,
                  onShare: onShare,
                  onToggleSave: onToggleSave,
                  isSaved: isSaved,
                  compact: compact,
                  tvMode: tvMode,
                  sidebar: false,
                  shufflePlay: shufflePlay,
                );
                if (compact) {
                  return Column(
                    children: [
                      AlbumArt(
                        imageUrl: effectiveCollection.thumbnail,
                        semanticLabel: 'Ảnh ${effectiveCollection.title}',
                        size: artworkSize,
                        borderRadius: 16,
                      ),
                      const SizedBox(height: 22),
                      details,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AlbumArt(
                      imageUrl: effectiveCollection.thumbnail,
                      semanticLabel: 'Ảnh ${effectiveCollection.title}',
                      size: artworkSize,
                      borderRadius: 16,
                    ),
                    SizedBox(width: tvMode ? 38 : 30),
                    Expanded(child: details),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(
    BuildContext context, {
    required CatalogCollection effectiveCollection,
    required CatalogCollectionDetail? metadata,
    required int songCount,
    required Duration duration,
  }) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      key: const ValueKey('collection-detail-hero'),
      margin: EdgeInsets.only(right: light ? 18 : 0),
      padding: light
          ? const EdgeInsets.fromLTRB(18, 18, 18, 26)
          : const EdgeInsets.only(right: 30, bottom: 30),
      decoration: light
          ? BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF5B327D), Color(0xFF2A1736)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final artworkSize = constraints.maxWidth.clamp(220.0, 300.0);
              return Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.32),
                        blurRadius: 30,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AlbumArt(
                        imageUrl: effectiveCollection.thumbnail,
                        semanticLabel: 'Ảnh ${effectiveCollection.title}',
                        size: artworkSize,
                        borderRadius: 8,
                      ),
                      if (onPlay != null)
                        Semantics(
                          button: true,
                          label: shufflePlay
                              ? 'Phát ngẫu nhiên ${effectiveCollection.title}'
                              : 'Phát ${effectiveCollection.title}',
                          onTap: onPlay,
                          child: ExcludeSemantics(
                            child: IconButton.filled(
                              key: const ValueKey(
                                'collection-artwork-play-button',
                              ),
                              tooltip: shufflePlay
                                  ? 'Phát ngẫu nhiên'
                                  : 'Phát tuyển tập',
                              onPressed: onPlay,
                              style: IconButton.styleFrom(
                                minimumSize: const Size.square(58),
                                backgroundColor: Colors.black.withValues(
                                  alpha: 0.58,
                                ),
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  width: 2,
                                ),
                              ),
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                size: 34,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          _CollectionDetails(
            collection: effectiveCollection,
            detail: metadata,
            songCount: songCount,
            duration: duration,
            loading: loading,
            onPlay: onPlay,
            onArtistTap: onArtistTap,
            onShare: onShare,
            onToggleSave: onToggleSave,
            isSaved: isSaved,
            compact: true,
            tvMode: false,
            sidebar: true,
            shufflePlay: shufflePlay,
          ),
        ],
      ),
    );
  }
}

class CollectionDetailDesktopOverview extends StatefulWidget {
  const CollectionDetailDesktopOverview({
    super.key,
    required this.detail,
    required this.loading,
  });

  final CatalogCollectionDetail? detail;
  final bool loading;

  @override
  State<CollectionDetailDesktopOverview> createState() =>
      _CollectionDetailDesktopOverviewState();
}

class _CollectionDetailDesktopOverviewState
    extends State<CollectionDetailDesktopOverview> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant CollectionDetailDesktopOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail?.collection.id != widget.detail?.collection.id) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final description = widget.detail?.description.trim() ?? '';
    return Container(
      key: const ValueKey('collection-desktop-overview'),
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.fromLTRB(10, 2, 8, 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.34),
          ),
        ),
      ),
      child: widget.loading && widget.detail == null
          ? const _CollectionOverviewSkeleton()
          : LayoutBuilder(
              builder: (context, constraints) {
                final text = description.isEmpty
                    ? 'Thông tin chính thức của tuyển tập sẽ được cập nhật khi nguồn Zing MP3 cung cấp.'
                    : description;
                final style = TextStyle(
                  color: scheme.onSurface.withValues(
                    alpha: description.isEmpty ? 0.62 : 0.88,
                  ),
                  fontSize: 14,
                  height: 1.55,
                );
                final painter = TextPainter(
                  text: TextSpan(text: text, style: style),
                  maxLines: 4,
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout(maxWidth: constraints.maxWidth);
                final expandable = painter.didExceedMaxLines || _expanded;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      maxLines: _expanded ? null : 4,
                      overflow: _expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: style,
                    ),
                    if (expandable) ...[
                      const SizedBox(height: 2),
                      TextButton(
                        key: const ValueKey('collection-description-toggle'),
                        onPressed: () => setState(() => _expanded = !_expanded),
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.onSurface,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 6,
                          ),
                          minimumSize: const Size(72, 40),
                          alignment: Alignment.centerLeft,
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                        child: Text(_expanded ? 'RÚT GỌN' : 'XEM THÊM'),
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _CollectionOverviewSkeleton extends StatelessWidget {
  const _CollectionOverviewSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.1);
    return Semantics(
      label: 'Đang tải lời tựa playlist hoặc album',
      liveRegion: true,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final width in <double>[1, 0.92, 0.68]) ...[
              FractionallySizedBox(
                widthFactor: width,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpandableHeroDescription extends StatefulWidget {
  const _ExpandableHeroDescription({
    required this.text,
    required this.textAlign,
    required this.fontSize,
  });

  final String text;
  final TextAlign textAlign;
  final double fontSize;

  @override
  State<_ExpandableHeroDescription> createState() =>
      _ExpandableHeroDescriptionState();
}

class _ExpandableHeroDescriptionState
    extends State<_ExpandableHeroDescription> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant _ExpandableHeroDescription oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Colors.white.withValues(alpha: 0.7),
      fontSize: widget.fontSize,
      height: 1.4,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 2,
          textAlign: widget.textAlign,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final expandable = painter.didExceedMaxLines || _expanded;
        return Column(
          crossAxisAlignment: widget.textAlign == TextAlign.center
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              maxLines: _expanded ? null : 2,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              textAlign: widget.textAlign,
              style: style,
            ),
            if (expandable)
              TextButton(
                key: const ValueKey('collection-hero-description-toggle'),
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  minimumSize: const Size(72, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.65,
                  ),
                ),
                child: Text(_expanded ? 'RÚT GỌN' : 'XEM THÊM'),
              ),
          ],
        );
      },
    );
  }
}

class _CollectionDetails extends StatelessWidget {
  const _CollectionDetails({
    required this.collection,
    required this.detail,
    required this.songCount,
    required this.duration,
    required this.loading,
    required this.onPlay,
    required this.onArtistTap,
    required this.onShare,
    required this.onToggleSave,
    required this.isSaved,
    required this.compact,
    required this.tvMode,
    required this.sidebar,
    required this.shufflePlay,
  });

  final CatalogCollection collection;
  final CatalogCollectionDetail? detail;
  final int songCount;
  final Duration duration;
  final bool loading;
  final VoidCallback? onPlay;
  final ValueChanged<CatalogArtist>? onArtistTap;
  final VoidCallback? onShare;
  final VoidCallback? onToggleSave;
  final bool isSaved;
  final bool compact;
  final bool tvMode;
  final bool sidebar;
  final bool shufflePlay;

  @override
  Widget build(BuildContext context) {
    final alignment = compact
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final description = detail?.description.trim() ?? '';
    final meta = <String>[
      if (sidebar && detail?.releasedAt != null)
        'Cập nhật: ${_dateLabel(detail!.releasedAt!)}'
      else if (detail?.year.isNotEmpty == true)
        detail!.year,
      if (songCount > 0) '$songCount bài hát',
      if (duration > Duration.zero) _durationLabel(duration),
      if ((detail?.likeCount ?? 0) > 0)
        '${_compactNumber(detail!.likeCount)} người yêu thích',
    ].join(' · ');
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          collection.kindLabel,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: tvMode ? 14 : 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.7,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          collection.title,
          maxLines: compact ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: Colors.white,
            fontSize: tvMode
                ? 48
                : compact
                ? sidebar
                      ? 25
                      : 30
                : 42,
            height: 1.04,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.3,
          ),
        ),
        if (detail?.artists.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          _CollectionArtistLinks(
            artists: detail!.artists,
            onTap: onArtistTap,
            centered: compact,
            tvMode: tvMode,
          ),
        ] else if (collection.artist.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            collection.artist,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: tvMode ? 18 : 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        if (!sidebar && description.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ExpandableHeroDescription(
            text: description,
            textAlign: compact ? TextAlign.center : TextAlign.start,
            fontSize: tvMode ? 15 : 12,
          ),
        ],
        const SizedBox(height: 12),
        Text(
          loading
              ? 'ĐANG TẢI DANH SÁCH BÀI HÁT…'
              : sidebar
              ? meta
              : meta.toUpperCase(),
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.68),
            fontSize: tvMode
                ? 14
                : sidebar
                ? 11
                : 10,
            fontWeight: FontWeight.w900,
            letterSpacing: sidebar ? 0.25 : 1.1,
          ),
        ),
        SizedBox(height: tvMode ? 26 : 20),
        if (sidebar) ...[
          Center(
            child: SizedBox(
              width: 228,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('collection-play-button'),
                    onPressed: onPlay,
                    style: FilledButton.styleFrom(
                      backgroundColor: ZingColors.purpleBright,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: tvMode ? 26 : 20,
                        vertical: tvMode ? 18 : 14,
                      ),
                    ),
                    icon: Icon(
                      shufflePlay
                          ? Icons.shuffle_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      shufflePlay ? 'PHÁT NGẪU NHIÊN' : 'PHÁT TẤT CẢ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  if (onToggleSave != null || onShare != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (onToggleSave != null)
                          Semantics(
                            toggled: isSaved,
                            button: true,
                            onTap: onToggleSave,
                            label: isSaved
                                ? 'Bỏ lưu ${collection.title}'
                                : 'Lưu ${collection.title} vào thư viện',
                            child: ExcludeSemantics(
                              child: IconButton.outlined(
                                key: const ValueKey('collection-save-button'),
                                tooltip: isSaved ? 'Bỏ lưu' : 'Lưu thư viện',
                                onPressed: onToggleSave,
                                style: IconButton.styleFrom(
                                  minimumSize: const Size.square(44),
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.42),
                                  ),
                                ),
                                icon: Icon(
                                  isSaved
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                ),
                              ),
                            ),
                          ),
                        if (onToggleSave != null && onShare != null)
                          const SizedBox(width: 10),
                        if (onShare != null)
                          IconButton.outlined(
                            key: const ValueKey('collection-share-button'),
                            tooltip: 'Chia sẻ',
                            onPressed: onShare,
                            style: IconButton.styleFrom(
                              minimumSize: const Size.square(44),
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.42),
                              ),
                            ),
                            icon: const Icon(Icons.ios_share_rounded),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ] else
          Wrap(
            alignment: compact ? WrapAlignment.center : WrapAlignment.start,
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const ValueKey('collection-play-button'),
                onPressed: onPlay,
                style: FilledButton.styleFrom(
                  backgroundColor: ZingColors.purpleBright,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: tvMode ? 26 : 20,
                    vertical: tvMode ? 18 : 14,
                  ),
                ),
                icon: Icon(
                  shufflePlay
                      ? Icons.shuffle_rounded
                      : Icons.play_arrow_rounded,
                ),
                label: Text(
                  shufflePlay ? 'PHÁT NGẪU NHIÊN' : 'PHÁT TẤT CẢ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              if (onToggleSave != null)
                Semantics(
                  toggled: isSaved,
                  button: true,
                  onTap: onToggleSave,
                  label: isSaved
                      ? 'Bỏ lưu ${collection.title}'
                      : 'Lưu ${collection.title} vào thư viện',
                  child: ExcludeSemantics(
                    child: isSaved
                        ? FilledButton.tonalIcon(
                            key: const ValueKey('collection-save-button'),
                            onPressed: onToggleSave,
                            style: FilledButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: tvMode ? 24 : 18,
                                vertical: tvMode ? 18 : 14,
                              ),
                            ),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text(
                              'ĐÃ LƯU',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          )
                        : OutlinedButton.icon(
                            key: const ValueKey('collection-save-button'),
                            onPressed: onToggleSave,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.58),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: tvMode ? 24 : 18,
                                vertical: tvMode ? 18 : 14,
                              ),
                            ),
                            icon: const Icon(Icons.library_add_rounded),
                            label: const Text(
                              'LƯU THƯ VIỆN',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                  ),
                ),
              if (onShare != null)
                OutlinedButton.icon(
                  key: const ValueKey('collection-share-button'),
                  onPressed: onShare,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.42),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: tvMode ? 24 : 18,
                      vertical: tvMode ? 18 : 14,
                    ),
                  ),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text(
                    'CHIA SẺ',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  String _durationLabel(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) return '$hours giờ $minutes phút';
    return '${duration.inMinutes} phút';
  }

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  String _compactNumber(int value) {
    if (value >= 1000000) {
      return '${_trimDecimal(value / 1000000)}M';
    }
    if (value >= 1000) return '${_trimDecimal(value / 1000)}K';
    return '$value';
  }

  String _trimDecimal(double value) {
    final fixed = value >= 10
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }
}

class _CollectionArtistLinks extends StatelessWidget {
  const _CollectionArtistLinks({
    required this.artists,
    required this.onTap,
    required this.centered,
    required this.tvMode,
  });

  final List<CatalogArtist> artists;
  final ValueChanged<CatalogArtist>? onTap;
  final bool centered;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: centered ? WrapAlignment.center : WrapAlignment.start,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 4,
    runSpacing: 4,
    children: [
      for (var index = 0; index < artists.length; index++) ...[
        if (index > 0)
          Text(
            '•',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: tvMode ? 18 : 14,
            ),
          ),
        _CollectionArtistLink(
          artist: artists[index],
          onTap: onTap == null ? null : () => onTap!(artists[index]),
          tvMode: tvMode,
        ),
      ],
    ],
  );
}

class _CollectionArtistLink extends StatelessWidget {
  const _CollectionArtistLink({
    required this.artist,
    required this.onTap,
    required this.tvMode,
  });

  final CatalogArtist artist;
  final VoidCallback? onTap;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final compactDesktopTarget = MediaQuery.sizeOf(context).width >= 720;
    final label = onTap == null
        ? artist.name
        : 'Mở trang nghệ sĩ ${artist.name}';
    return Semantics(
      button: onTap != null,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: TextButton(
          key: ValueKey('collection-artist-${artist.id}'),
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.86),
            minimumSize: Size(
              0,
              tvMode
                  ? 52
                  : compactDesktopTarget
                  ? 32
                  : 44,
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.symmetric(
              horizontal: tvMode ? 8 : 4,
              vertical: tvMode ? 6 : 3,
            ),
            textStyle: TextStyle(
              fontSize: tvMode ? 18 : 14,
              fontWeight: FontWeight.w800,
              decoration: onTap == null ? null : TextDecoration.underline,
              decorationColor: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          child: Text(artist.name),
        ),
      ),
    );
  }
}
