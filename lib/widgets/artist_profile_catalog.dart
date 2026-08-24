import 'package:flutter/material.dart';

import '../models/catalog_artist_detail.dart';
import '../models/catalog_search.dart';
import '../theme/app_theme.dart';
import 'catalog_artist_rail.dart';

enum ArtistProfileCatalogView { profile, singles, videos }

class ArtistProfileCatalog extends StatelessWidget {
  const ArtistProfileCatalog({
    super.key,
    required this.detail,
    required this.onCollectionTap,
    required this.onArtistTap,
    required this.onVideoTap,
    this.view = ArtistProfileCatalogView.profile,
    this.onShowAllSingles,
    this.onShowAllVideos,
    this.tvMode = false,
  });

  final CatalogArtistDetail detail;
  final ValueChanged<CatalogCollection> onCollectionTap;
  final ValueChanged<CatalogArtist> onArtistTap;
  final ValueChanged<CatalogVideo> onVideoTap;
  final ArtistProfileCatalogView view;
  final VoidCallback? onShowAllSingles;
  final VoidCallback? onShowAllVideos;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final horizontal = tvMode ? 32.0 : 20.0;
    final collectionSections = switch (view) {
      ArtistProfileCatalogView.profile => detail.collectionSections,
      ArtistProfileCatalogView.singles =>
        detail.collectionSections
            .where(_isSingleSection)
            .toList(growable: false),
      ArtistProfileCatalogView.videos =>
        const <CatalogArtistCollectionSection>[],
    };
    final showVideos = view != ArtistProfileCatalogView.singles;
    final showProfileExtras = view == ArtistProfileCatalogView.profile;
    return Padding(
      key: const ValueKey('artist-profile-catalog'),
      padding: EdgeInsets.fromLTRB(
        horizontal,
        tvMode ? 12 : 4,
        horizontal,
        tvMode ? 54 : 34,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final section in collectionSections) ...[
            _ArtistCollectionRail(
              key: ValueKey('artist-section-${section.id}'),
              section: section,
              onTap: onCollectionTap,
              onShowAll:
                  view == ArtistProfileCatalogView.profile &&
                      _isSingleSection(section)
                  ? onShowAllSingles
                  : null,
              tvMode: tvMode,
            ),
            SizedBox(height: tvMode ? 40 : 30),
          ],
          if (showVideos && detail.videos.isNotEmpty) ...[
            _ArtistVideoRail(
              videos: detail.videos,
              onTap: onVideoTap,
              onShowAll: view == ArtistProfileCatalogView.profile
                  ? onShowAllVideos
                  : null,
              tvMode: tvMode,
            ),
            SizedBox(height: tvMode ? 40 : 30),
          ],
          if (showProfileExtras && detail.relatedArtists.isNotEmpty) ...[
            CatalogArtistRail(
              title: 'Bạn Có Thể Thích',
              artists: detail.relatedArtists,
              onArtistTap: onArtistTap,
              keyPrefix: 'related-artist',
              tvMode: tvMode,
            ),
            SizedBox(height: tvMode ? 40 : 30),
          ],
          if (showProfileExtras && detail.biography.isNotEmpty)
            _ArtistBiography(detail: detail, tvMode: tvMode),
        ],
      ),
    );
  }
}

bool _isSingleSection(CatalogArtistCollectionSection section) {
  final identity = '${section.id} ${section.title}'.toLowerCase();
  return identity.contains('single');
}

class _ArtistCollectionRail extends StatelessWidget {
  const _ArtistCollectionRail({
    super.key,
    required this.section,
    required this.onTap,
    this.onShowAll,
    required this.tvMode,
  });

  final CatalogArtistCollectionSection section;
  final ValueChanged<CatalogCollection> onTap;
  final VoidCallback? onShowAll;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionTitle(
        title: section.title,
        trailing: '${section.collections.length} nội dung',
        actionKey: ValueKey('artist-section-show-all-${section.id}'),
        onAction: onShowAll,
        tvMode: tvMode,
      ),
      SizedBox(height: tvMode ? 17 : 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = tvMode
              ? 224.0
              : constraints.maxWidth >= 900
              ? 190.0
              : 154.0;
          return SizedBox(
            height: width + (tvMode ? 104 : 88),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: section.collections.length,
              separatorBuilder: (_, __) => SizedBox(width: tvMode ? 20 : 14),
              itemBuilder: (context, index) {
                final collection = section.collections[index];
                return SizedBox(
                  width: width,
                  child: _ArtistCollectionCard(
                    key: ValueKey('artist-collection-${collection.id}'),
                    collection: collection,
                    onTap: () => onTap(collection),
                    tvMode: tvMode,
                  ),
                );
              },
            ),
          );
        },
      ),
    ],
  );
}

class _ArtistCollectionCard extends StatefulWidget {
  const _ArtistCollectionCard({
    super.key,
    required this.collection,
    required this.onTap,
    required this.tvMode,
  });

  final CatalogCollection collection;
  final VoidCallback onTap;
  final bool tvMode;

  @override
  State<_ArtistCollectionCard> createState() => _ArtistCollectionCardState();
}

class _ArtistCollectionCardState extends State<_ArtistCollectionCard> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final collection = widget.collection;
    return Semantics(
      button: true,
      label: 'Mở ${collection.title}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(widget.tvMode ? 18 : 14),
          onHover: (value) => setState(() => _active = value),
          onFocusChange: (value) {
            setState(() => _active = value);
            if (value) {
              Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 220),
                alignment: 0.14,
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 170),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        widget.tvMode ? 18 : 14,
                      ),
                      border: Border.all(
                        color: _active ? ZingColors.lime : Colors.transparent,
                        width: _active ? 3 : 0,
                      ),
                      boxShadow: _active
                          ? [
                              BoxShadow(
                                color: ZingColors.purple.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 9),
                              ),
                            ]
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (collection.thumbnail.isEmpty)
                          const ColoredBox(
                            color: Color(0xFF292A2E),
                            child: Center(
                              child: Icon(
                                Icons.album_rounded,
                                color: ZingColors.coral,
                                size: 42,
                              ),
                            ),
                          )
                        else
                          Image.network(
                            collection.thumbnail,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                              color: Color(0xFF292A2E),
                              child: Center(
                                child: Icon(
                                  Icons.album_rounded,
                                  color: ZingColors.coral,
                                  size: 42,
                                ),
                              ),
                            ),
                          ),
                        AnimatedOpacity(
                          opacity: _active ? 1 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: const ColoredBox(
                            color: Color(0x880D0813),
                            child: Center(
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: widget.tvMode ? 12 : 9),
                Text(
                  collection.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: widget.tvMode ? 17 : 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  collection.artist.isEmpty
                      ? collection.kindLabel
                      : collection.artist,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: widget.tvMode ? 14 : 11,
                    height: 1.25,
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

class _ArtistVideoRail extends StatelessWidget {
  const _ArtistVideoRail({
    required this.videos,
    required this.onTap,
    this.onShowAll,
    required this.tvMode,
  });

  final List<CatalogVideo> videos;
  final ValueChanged<CatalogVideo> onTap;
  final VoidCallback? onShowAll;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('artist-video-rail'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionTitle(
        title: 'MV',
        trailing: '${videos.length} video',
        actionKey: const ValueKey('artist-videos-show-all'),
        onAction: onShowAll,
        tvMode: tvMode,
      ),
      SizedBox(height: tvMode ? 18 : 13),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = tvMode
              ? 332.0
              : constraints.maxWidth >= 900
              ? 278.0
              : constraints.maxWidth >= 560
              ? 252.0
              : 224.0;
          return SizedBox(
            height: width * 9 / 16 + (tvMode ? 88 : 72),
            child: ListView.separated(
              key: const ValueKey('artist-video-list'),
              scrollDirection: Axis.horizontal,
              itemCount: videos.length,
              separatorBuilder: (_, __) => SizedBox(width: tvMode ? 22 : 15),
              itemBuilder: (context, index) {
                final video = videos[index];
                return SizedBox(
                  width: width,
                  child: _ArtistVideoCard(
                    key: ValueKey('artist-video-${video.id}'),
                    video: video,
                    onTap: () => onTap(video),
                    tvMode: tvMode,
                  ),
                );
              },
            ),
          );
        },
      ),
    ],
  );
}

class _ArtistVideoCard extends StatefulWidget {
  const _ArtistVideoCard({
    super.key,
    required this.video,
    required this.onTap,
    required this.tvMode,
  });

  final CatalogVideo video;
  final VoidCallback onTap;
  final bool tvMode;

  @override
  State<_ArtistVideoCard> createState() => _ArtistVideoCardState();
}

class _ArtistVideoCardState extends State<_ArtistVideoCard> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 170);
    final video = widget.video;
    return Semantics(
      button: true,
      label:
          'Mở MV ${video.title}${video.artist.isEmpty ? '' : ' của ${video.artist}'}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(widget.tvMode ? 18 : 14),
          onHover: (value) => setState(() => _active = value),
          onFocusChange: (value) {
            setState(() => _active = value);
            if (value) {
              Scrollable.ensureVisible(
                context,
                duration: reducedMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                alignment: 0.12,
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: AnimatedContainer(
                    duration: duration,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        widget.tvMode ? 18 : 14,
                      ),
                      border: Border.all(
                        color: _active ? ZingColors.lime : Colors.transparent,
                        width: _active ? 3 : 0,
                      ),
                      boxShadow: _active
                          ? [
                              BoxShadow(
                                color: ZingColors.purple.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 9),
                              ),
                            ]
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (video.thumbnail.isEmpty)
                          const ColoredBox(
                            color: Color(0xFF292A2E),
                            child: Icon(
                              Icons.music_video_rounded,
                              color: ZingColors.coral,
                              size: 48,
                            ),
                          )
                        else
                          Image.network(
                            video.thumbnail,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                              color: Color(0xFF292A2E),
                              child: Icon(
                                Icons.music_video_rounded,
                                color: ZingColors.coral,
                                size: 48,
                              ),
                            ),
                          ),
                        AnimatedContainer(
                          duration: duration,
                          color: _active
                              ? const Color(0x660D0813)
                              : Colors.transparent,
                          child: Center(
                            child: Container(
                              width: widget.tvMode ? 64 : 50,
                              height: widget.tvMode ? 64 : 50,
                              decoration: BoxDecoration(
                                color: _active
                                    ? ZingColors.coral
                                    : const Color(0xCC121015),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: widget.tvMode ? 42 : 34,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xDD0D0D0F),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              child: Text(
                                _formatVideoDuration(video.duration),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: widget.tvMode ? 13 : 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: widget.tvMode ? 11 : 8),
                Text(
                  video.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: widget.tvMode ? 18 : 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  video.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: widget.tvMode ? 14 : 11,
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

String _formatVideoDuration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '${value.inMinutes}:$seconds';
}

class _ArtistBiography extends StatelessWidget {
  const _ArtistBiography({required this.detail, required this.tvMode});

  final CatalogArtistDetail detail;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('artist-biography'),
    padding: EdgeInsets.all(tvMode ? 28 : 20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(tvMode ? 24 : 18),
      border: Border.all(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.35),
      ),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VỀ ${detail.artist.name.toUpperCase()}',
              style: TextStyle(
                color: ZingColors.lime,
                fontSize: tvMode ? 14 : 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _followText(detail.totalFollow),
              style: TextStyle(
                fontSize: tvMode ? 27 : 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (detail.awardCount > 0) ...[
              const SizedBox(height: 5),
              Text(
                '${detail.awardCount} giải thưởng được ghi nhận',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: tvMode ? 14 : 12,
                ),
              ),
            ],
          ],
        );
        final biography = SelectableText(
          detail.biography,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: tvMode ? 17 : 14,
            height: 1.65,
          ),
        );
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 18), biography],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 250, child: heading),
            const SizedBox(width: 36),
            Expanded(child: biography),
          ],
        );
      },
    ),
  );

  static String _followText(int value) {
    final digits = value.toString().split('').reversed.toList();
    final groups = <String>[];
    for (var index = 0; index < digits.length; index += 3) {
      groups.add(digits.skip(index).take(3).toList().reversed.join());
    }
    final formatted = groups.reversed.join('.');
    return '$formatted người quan tâm';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.trailing,
    this.actionKey,
    this.onAction,
    required this.tvMode,
  });

  final String title;
  final String trailing;
  final Key? actionKey;
  final VoidCallback? onAction;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: tvMode ? 27 : 21,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.45,
          ),
        ),
      ),
      const SizedBox(width: 12),
      if (onAction != null) ...[
        TextButton(
          key: actionKey,
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            minimumSize: Size(tvMode ? 108 : 76, tvMode ? 52 : 40),
            textStyle: TextStyle(
              fontSize: tvMode ? 14 : 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.05,
            ),
          ),
          child: const Text('TẤT CẢ'),
        ),
        const SizedBox(width: 4),
      ],
      Text(
        trailing,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: tvMode ? 14 : 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
