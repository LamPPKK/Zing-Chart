import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';

import '../models/catalog_artist_detail.dart';
import '../models/catalog_search.dart';
import '../models/official_zing_link.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';
import 'catalog_artist_rail.dart';
import 'catalog_collection_action_deck.dart';

enum ArtistProfileCatalogView { profile, singles, albums, videos }

/// Compact navigation for the public sections of an official artist profile.
///
/// Unavailable sections stay out of the traversal order, except for the
/// currently selected section. Keeping that selected route visible makes an
/// empty deep link understandable instead of silently returning to Overview.
class ArtistProfileSectionTabs extends StatelessWidget {
  const ArtistProfileSectionTabs({
    super.key,
    required this.detail,
    required this.selected,
    required this.onSelected,
    this.tvMode = false,
  });

  final CatalogArtistDetail detail;
  final OfficialArtistSection selected;
  final ValueChanged<OfficialArtistSection> onSelected;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final available = <OfficialArtistSection>{
      OfficialArtistSection.profile,
      if (detail.totalSongCount > 0 || detail.featuredSongs.isNotEmpty)
        OfficialArtistSection.songs,
      if (_collectionsForKind(
        detail,
        _ArtistCollectionSectionKind.singles,
      ).isNotEmpty)
        OfficialArtistSection.singles,
      if (_collectionsForKind(
        detail,
        _ArtistCollectionSectionKind.albums,
      ).isNotEmpty)
        OfficialArtistSection.albums,
      if (_uniqueVideos(detail.videos).isNotEmpty) OfficialArtistSection.videos,
      selected,
    };
    final sections = OfficialArtistSection.values
        .where(available.contains)
        .toList(growable: false);
    final horizontal = tvMode ? 32.0 : 20.0;

    return Semantics(
      key: const ValueKey('artist-profile-section-tabs'),
      container: true,
      label: 'Danh mục nghệ sĩ',
      child: SizedBox(
        height: tvMode ? 72 : 52,
        child: ListView.separated(
          key: const ValueKey('artist-profile-section-tab-list'),
          primary: false,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 4),
          itemCount: sections.length,
          separatorBuilder: (_, __) => SizedBox(width: tvMode ? 12 : 6),
          itemBuilder: (context, index) {
            final section = sections[index];
            return _ArtistProfileSectionTab(
              key: ValueKey('artist-profile-section-tab-${section.name}'),
              section: section,
              selected: section == selected,
              onPressed: () => onSelected(section),
              tvMode: tvMode,
            );
          },
        ),
      ),
    );
  }
}

class _ArtistProfileSectionTab extends StatefulWidget {
  const _ArtistProfileSectionTab({
    super.key,
    required this.section,
    required this.selected,
    required this.onPressed,
    required this.tvMode,
  });

  final OfficialArtistSection section;
  final bool selected;
  final VoidCallback onPressed;
  final bool tvMode;

  @override
  State<_ArtistProfileSectionTab> createState() =>
      _ArtistProfileSectionTabState();
}

class _ArtistProfileSectionTabState extends State<_ArtistProfileSectionTab> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.selected) _revealAfterLayout();
  }

  @override
  void didUpdateWidget(covariant _ArtistProfileSectionTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) _revealAfterLayout();
  }

  void _revealAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scrollable = Scrollable.maybeOf(context, axis: Axis.horizontal);
      final renderObject = context.findRenderObject();
      if (scrollable == null || renderObject == null) return;
      scrollable.position.ensureVisible(
        renderObject,
        alignment: 0.5,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: widget.selected,
      button: true,
      label: _artistSectionLabel(widget.section),
      onTap: widget.onPressed,
      child: TextButton(
        focusNode: _focusNode,
        onFocusChange: (focused) {
          if (!focused) return;
          _revealAfterLayout();
        },
        onPressed: widget.onPressed,
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(
            Size(widget.tvMode ? 124 : 0, widget.tvMode ? 56 : 44),
          ),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: widget.tvMode ? 22 : 15),
          ),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) return ZingColors.lime;
            return widget.selected ? colors.onSurface : colors.onSurfaceVariant;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (widget.selected) {
              return ZingColors.purple.withValues(alpha: 0.34);
            }
            if (states.contains(WidgetState.focused) ||
                states.contains(WidgetState.hovered)) {
              return colors.onSurface.withValues(alpha: 0.08);
            }
            return Colors.transparent;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            final focused = states.contains(WidgetState.focused);
            return BorderSide(
              color: focused
                  ? ZingColors.lime
                  : widget.selected
                  ? ZingColors.purpleBright.withValues(alpha: 0.68)
                  : colors.outlineVariant.withValues(alpha: 0.4),
              width: focused ? 2.5 : 1,
            );
          }),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontSize: widget.tvMode ? 16 : 12,
              fontWeight: FontWeight.w900,
              letterSpacing: widget.tvMode ? 0.55 : 0.75,
            ),
          ),
        ),
        child: Text(_artistSectionLabel(widget.section)),
      ),
    );
  }
}

String _artistSectionLabel(OfficialArtistSection section) => switch (section) {
  OfficialArtistSection.profile => 'TỔNG QUAN',
  OfficialArtistSection.songs => 'BÀI HÁT',
  OfficialArtistSection.singles => 'SINGLE & EP',
  OfficialArtistSection.albums => 'ALBUM',
  OfficialArtistSection.videos => 'MV',
};

class ArtistProfileCatalog extends StatelessWidget {
  const ArtistProfileCatalog({
    super.key,
    required this.detail,
    required this.onCollectionTap,
    required this.onArtistTap,
    required this.onVideoTap,
    this.onCollectionPlay,
    this.onCollectionToggleSaved,
    this.onCollectionShare,
    this.savedCollectionIds = const <String>{},
    this.quickPlayingCollectionId,
    this.onArtistToggleFollow,
    this.followedArtistIds = const <String>{},
    this.view = ArtistProfileCatalogView.profile,
    this.onShowAllSingles,
    this.onShowAllAlbums,
    this.onShowAllVideos,
    this.tvMode = false,
  });

  final CatalogArtistDetail detail;
  final ValueChanged<CatalogCollection> onCollectionTap;
  final ValueChanged<CatalogArtist> onArtistTap;
  final ValueChanged<CatalogVideo> onVideoTap;
  final ValueChanged<CatalogCollection>? onCollectionPlay;
  final ValueChanged<CatalogCollection>? onCollectionToggleSaved;
  final ValueChanged<CatalogCollection>? onCollectionShare;
  final Set<String> savedCollectionIds;
  final String? quickPlayingCollectionId;
  final ValueChanged<CatalogArtist>? onArtistToggleFollow;
  final Set<String> followedArtistIds;
  final ArtistProfileCatalogView view;
  final VoidCallback? onShowAllSingles;
  final VoidCallback? onShowAllAlbums;
  final VoidCallback? onShowAllVideos;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final horizontal = tvMode ? 32.0 : 20.0;
    final profileSections = _uniqueProfileSections(detail.collectionSections);
    final singles = _collectionsForKind(
      detail,
      _ArtistCollectionSectionKind.singles,
    );
    final albums = _collectionsForKind(
      detail,
      _ArtistCollectionSectionKind.albums,
    );
    final videos = _uniqueVideos(detail.videos);
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
          if (view == ArtistProfileCatalogView.profile) ...[
            for (final section in profileSections) ...[
              _ArtistCollectionRail(
                key: ValueKey('artist-section-${section.id}'),
                section: section,
                onTap: onCollectionTap,
                onPlay: onCollectionPlay,
                onToggleSaved: onCollectionToggleSaved,
                onShare: onCollectionShare,
                savedCollectionIds: savedCollectionIds,
                quickPlayingCollectionId: quickPlayingCollectionId,
                onShowAll: switch (_collectionSectionKind(section)) {
                  _ArtistCollectionSectionKind.singles =>
                    singles.isEmpty ? null : onShowAllSingles,
                  _ArtistCollectionSectionKind.albums =>
                    albums.isEmpty ? null : onShowAllAlbums,
                  _ArtistCollectionSectionKind.other => null,
                },
                tvMode: tvMode,
              ),
              SizedBox(height: tvMode ? 40 : 30),
            ],
            if (videos.isNotEmpty) ...[
              _ArtistVideoRail(
                videos: videos,
                onTap: onVideoTap,
                onShowAll: onShowAllVideos,
                tvMode: tvMode,
              ),
              SizedBox(height: tvMode ? 40 : 30),
            ],
            if (detail.relatedArtists.isNotEmpty) ...[
              CatalogArtistRail(
                title: 'Bạn Có Thể Thích',
                artists: detail.relatedArtists,
                onArtistTap: onArtistTap,
                onToggleFollow: onArtistToggleFollow,
                followedArtistIds: followedArtistIds,
                keyPrefix: 'related-artist',
                tvMode: tvMode,
              ),
              SizedBox(height: tvMode ? 40 : 30),
            ],
            if (detail.biography.isNotEmpty)
              _ArtistBiography(detail: detail, tvMode: tvMode),
          ] else if (view == ArtistProfileCatalogView.singles)
            _ArtistCollectionGrid(
              key: const ValueKey('artist-singles-grid'),
              sectionKey: 'singles',
              title: 'Single & EP',
              emptyMessage: 'Nghệ sĩ chưa có Single & EP công khai',
              collections: singles,
              onTap: onCollectionTap,
              onPlay: onCollectionPlay,
              onToggleSaved: onCollectionToggleSaved,
              onShare: onCollectionShare,
              savedCollectionIds: savedCollectionIds,
              quickPlayingCollectionId: quickPlayingCollectionId,
              tvMode: tvMode,
            )
          else if (view == ArtistProfileCatalogView.albums)
            _ArtistCollectionGrid(
              key: const ValueKey('artist-albums-grid'),
              sectionKey: 'albums',
              title: 'Album',
              emptyMessage: 'Nghệ sĩ chưa có album công khai',
              collections: albums,
              onTap: onCollectionTap,
              onPlay: onCollectionPlay,
              onToggleSaved: onCollectionToggleSaved,
              onShare: onCollectionShare,
              savedCollectionIds: savedCollectionIds,
              quickPlayingCollectionId: quickPlayingCollectionId,
              tvMode: tvMode,
            )
          else
            _ArtistVideoGrid(videos: videos, onTap: onVideoTap, tvMode: tvMode),
        ],
      ),
    );
  }
}

enum _ArtistCollectionSectionKind { singles, albums, other }

_ArtistCollectionSectionKind _collectionSectionKind(
  CatalogArtistCollectionSection section,
) {
  final idTokens = _sectionTokens(section.id);
  final titleTokens = _sectionTokens(section.title);
  final tokens = <String>{...idTokens, ...titleTokens};
  final normalizedTitle = titleTokens.join(' ');
  final mentionsSingles =
      tokens.contains('single') ||
      tokens.contains('singles') ||
      tokens.contains('ep') ||
      normalizedTitle == 'dia don' ||
      normalizedTitle.startsWith('dia don ');
  final mentionsAlbums =
      tokens.contains('album') ||
      tokens.contains('albums') ||
      tokens.contains('lp');

  // Ambiguous metadata never gets guessed into a public deep-link section.
  if (mentionsSingles == mentionsAlbums) {
    return _ArtistCollectionSectionKind.other;
  }
  return mentionsSingles
      ? _ArtistCollectionSectionKind.singles
      : _ArtistCollectionSectionKind.albums;
}

List<String> _sectionTokens(String input) {
  final camelSeparated = input.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  var normalized = camelSeparated.toLowerCase();
  const replacements = <String, String>{
    'à': 'a',
    'á': 'a',
    'ạ': 'a',
    'ả': 'a',
    'ã': 'a',
    'â': 'a',
    'ầ': 'a',
    'ấ': 'a',
    'ậ': 'a',
    'ẩ': 'a',
    'ẫ': 'a',
    'ă': 'a',
    'ằ': 'a',
    'ắ': 'a',
    'ặ': 'a',
    'ẳ': 'a',
    'ẵ': 'a',
    'è': 'e',
    'é': 'e',
    'ẹ': 'e',
    'ẻ': 'e',
    'ẽ': 'e',
    'ê': 'e',
    'ề': 'e',
    'ế': 'e',
    'ệ': 'e',
    'ể': 'e',
    'ễ': 'e',
    'ì': 'i',
    'í': 'i',
    'ị': 'i',
    'ỉ': 'i',
    'ĩ': 'i',
    'ò': 'o',
    'ó': 'o',
    'ọ': 'o',
    'ỏ': 'o',
    'õ': 'o',
    'ô': 'o',
    'ồ': 'o',
    'ố': 'o',
    'ộ': 'o',
    'ổ': 'o',
    'ỗ': 'o',
    'ơ': 'o',
    'ờ': 'o',
    'ớ': 'o',
    'ợ': 'o',
    'ở': 'o',
    'ỡ': 'o',
    'ù': 'u',
    'ú': 'u',
    'ụ': 'u',
    'ủ': 'u',
    'ũ': 'u',
    'ư': 'u',
    'ừ': 'u',
    'ứ': 'u',
    'ự': 'u',
    'ử': 'u',
    'ữ': 'u',
    'ỳ': 'y',
    'ý': 'y',
    'ỵ': 'y',
    'ỷ': 'y',
    'ỹ': 'y',
    'đ': 'd',
  };
  for (final replacement in replacements.entries) {
    normalized = normalized.replaceAll(replacement.key, replacement.value);
  }
  return normalized
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.isNotEmpty && !RegExp(r'^\d+$').hasMatch(token))
      .toList(growable: false);
}

List<CatalogArtistCollectionSection> _uniqueProfileSections(
  List<CatalogArtistCollectionSection> sections,
) {
  final seen = <String>{};
  final result = <CatalogArtistCollectionSection>[];
  for (final section in sections) {
    final collections = _uniqueCollections(
      section.collections,
      seen: seen,
      albumsOnly: false,
    );
    if (collections.isEmpty) continue;
    result.add(
      CatalogArtistCollectionSection(
        id: section.id,
        title: section.title,
        collections: collections,
      ),
    );
  }
  return List<CatalogArtistCollectionSection>.unmodifiable(result);
}

List<CatalogCollection> _collectionsForKind(
  CatalogArtistDetail detail,
  _ArtistCollectionSectionKind kind,
) {
  final seen = <String>{};
  final result = <CatalogCollection>[];
  for (final section in detail.collectionSections) {
    if (_collectionSectionKind(section) != kind) continue;
    result.addAll(
      _uniqueCollections(section.collections, seen: seen, albumsOnly: true),
    );
  }
  return List<CatalogCollection>.unmodifiable(result);
}

List<CatalogCollection> _uniqueCollections(
  Iterable<CatalogCollection> collections, {
  required Set<String> seen,
  required bool albumsOnly,
}) {
  final result = <CatalogCollection>[];
  for (final collection in collections) {
    final id = collection.id.trim();
    if (!_publicCatalogId.hasMatch(id) ||
        (albumsOnly && collection.kind != CatalogCollectionKind.album)) {
      continue;
    }
    if (seen.add(id)) result.add(collection);
  }
  return result;
}

List<CatalogVideo> _uniqueVideos(Iterable<CatalogVideo> videos) {
  final seen = <String>{};
  final result = <CatalogVideo>[];
  for (final video in videos) {
    final id = video.id.trim();
    if (_publicCatalogId.hasMatch(id) && seen.add(id)) result.add(video);
  }
  return List<CatalogVideo>.unmodifiable(result);
}

final RegExp _publicCatalogId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

class _ArtistCollectionGrid extends StatelessWidget {
  const _ArtistCollectionGrid({
    super.key,
    required this.sectionKey,
    required this.title,
    required this.emptyMessage,
    required this.collections,
    required this.onTap,
    required this.onPlay,
    required this.onToggleSaved,
    required this.onShare,
    required this.savedCollectionIds,
    required this.quickPlayingCollectionId,
    required this.tvMode,
  });

  final String sectionKey;
  final String title;
  final String emptyMessage;
  final List<CatalogCollection> collections;
  final ValueChanged<CatalogCollection> onTap;
  final ValueChanged<CatalogCollection>? onPlay;
  final ValueChanged<CatalogCollection>? onToggleSaved;
  final ValueChanged<CatalogCollection>? onShare;
  final Set<String> savedCollectionIds;
  final String? quickPlayingCollectionId;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    if (collections.isEmpty) {
      return _ArtistCatalogEmptyState(
        key: ValueKey('artist-$sectionKey-empty'),
        message: emptyMessage,
        icon: Icons.album_outlined,
        tvMode: tvMode,
      );
    }
    final touchPlatform = switch (Theme.of(context).platform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => true,
      _ => false,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _discographyColumnCount(
          constraints.maxWidth,
          tvMode: tvMode,
        );
        final gap = tvMode ? 22.0 : 16.0;
        final itemWidth =
            (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              title: title,
              trailing: '${collections.length} nội dung đã tải',
              tvMode: tvMode,
            ),
            SizedBox(height: tvMode ? 20 : 14),
            GridView.builder(
              key: ValueKey('artist-$sectionKey-grid-list'),
              primary: false,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: gap,
                mainAxisSpacing: tvMode ? 24 : 18,
                mainAxisExtent: itemWidth + (tvMode ? 104 : 88),
              ),
              itemCount: collections.length,
              itemBuilder: (context, index) {
                final collection = collections[index];
                return _ArtistCollectionCard(
                  key: ValueKey('artist-collection-${collection.id}'),
                  collection: collection,
                  onOpen: () => onTap(collection),
                  onPlay: onPlay == null ? null : () => onPlay!(collection),
                  onToggleSaved: onToggleSaved == null
                      ? null
                      : () => onToggleSaved!(collection),
                  onShare:
                      onShare == null || collection.externalUrl.trim().isEmpty
                      ? null
                      : () => onShare!(collection),
                  saved: savedCollectionIds.contains(collection.id),
                  playing: quickPlayingCollectionId == collection.id,
                  persistentActions: tvMode || touchPlatform,
                  tvMode: tvMode,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _ArtistVideoGrid extends StatelessWidget {
  const _ArtistVideoGrid({
    required this.videos,
    required this.onTap,
    required this.tvMode,
  });

  final List<CatalogVideo> videos;
  final ValueChanged<CatalogVideo> onTap;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return _ArtistCatalogEmptyState(
        key: const ValueKey('artist-videos-empty'),
        message: 'Nghệ sĩ chưa có MV công khai',
        icon: Icons.ondemand_video_outlined,
        tvMode: tvMode,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _discographyColumnCount(
          constraints.maxWidth,
          tvMode: tvMode,
        );
        final gap = tvMode ? 22.0 : 16.0;
        final itemWidth =
            (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Column(
          key: const ValueKey('artist-videos-grid'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              title: 'MV',
              trailing: '${videos.length} MV đã tải',
              tvMode: tvMode,
            ),
            SizedBox(height: tvMode ? 20 : 14),
            GridView.builder(
              key: const ValueKey('artist-videos-grid-list'),
              primary: false,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: gap,
                mainAxisSpacing: tvMode ? 24 : 18,
                mainAxisExtent: itemWidth * 9 / 16 + (tvMode ? 88 : 72),
              ),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                return _ArtistVideoCard(
                  key: ValueKey('artist-video-${video.id}'),
                  video: video,
                  onTap: () => onTap(video),
                  tvMode: tvMode,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

int _discographyColumnCount(double width, {required bool tvMode}) {
  if (tvMode) return width >= 1500 ? 5 : 4;
  if (width < 600) return 2;
  if (width < 1024) return 3;
  return width >= 1420 ? 5 : 4;
}

class _ArtistCatalogEmptyState extends StatelessWidget {
  const _ArtistCatalogEmptyState({
    super.key,
    required this.message,
    required this.icon,
    required this.tvMode,
  });

  final String message;
  final IconData icon;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: message,
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: tvMode ? 260 : 190),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: ZingColors.purple.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: ZingColors.purpleBright.withValues(alpha: 0.32),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(tvMode ? 22 : 17),
                child: Icon(
                  icon,
                  size: tvMode ? 42 : 32,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(height: tvMode ? 18 : 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: tvMode ? 20 : 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ArtistCollectionRail extends StatefulWidget {
  const _ArtistCollectionRail({
    super.key,
    required this.section,
    required this.onTap,
    required this.onPlay,
    required this.onToggleSaved,
    required this.onShare,
    required this.savedCollectionIds,
    required this.quickPlayingCollectionId,
    this.onShowAll,
    required this.tvMode,
  });

  final CatalogArtistCollectionSection section;
  final ValueChanged<CatalogCollection> onTap;
  final ValueChanged<CatalogCollection>? onPlay;
  final ValueChanged<CatalogCollection>? onToggleSaved;
  final ValueChanged<CatalogCollection>? onShare;
  final Set<String> savedCollectionIds;
  final String? quickPlayingCollectionId;
  final VoidCallback? onShowAll;
  final bool tvMode;

  @override
  State<_ArtistCollectionRail> createState() => _ArtistCollectionRailState();
}

class _ArtistCollectionRailState extends State<_ArtistCollectionRail> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollBack = false;
  bool _canScrollForward = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncNavigationState);
  }

  @override
  void didUpdateWidget(covariant _ArtistCollectionRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameCollectionOrder(
          oldWidget.section.collections,
          widget.section.collections,
        ) ||
        oldWidget.tvMode != widget.tvMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.minScrollExtent);
        _syncNavigationState();
      });
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_syncNavigationState)
      ..dispose();
    super.dispose();
  }

  void _scheduleNavigationSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncNavigationState();
    });
  }

  void _syncNavigationState() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final canScrollBack = position.pixels > position.minScrollExtent + 0.5;
    final canScrollForward = position.pixels < position.maxScrollExtent - 0.5;
    if (canScrollBack == _canScrollBack &&
        canScrollForward == _canScrollForward) {
      return;
    }
    setState(() {
      _canScrollBack = canScrollBack;
      _canScrollForward = canScrollForward;
    });
  }

  void _scrollBy(double direction) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = (position.pixels + position.viewportDimension * direction)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (MediaQuery.disableAnimationsOf(context)) {
      _scrollController.jumpTo(target);
    } else {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = widget.tvMode
          ? 224.0
          : constraints.maxWidth >= 900
          ? 190.0
          : 154.0;
      final gap = widget.tvMode ? 20.0 : 14.0;
      final itemCount = widget.section.collections.length;
      final contentWidth = itemCount == 0
          ? 0.0
          : itemCount * width + (itemCount - 1) * gap;
      final compact = !widget.tvMode && constraints.maxWidth < 620;
      final platform = Theme.of(context).platform;
      final desktopPointerPlatform = switch (platform) {
        TargetPlatform.macOS ||
        TargetPlatform.windows ||
        TargetPlatform.linux => true,
        _ => false,
      };
      final touchPlatform = switch (platform) {
        TargetPlatform.android ||
        TargetPlatform.iOS ||
        TargetPlatform.fuchsia => true,
        _ => false,
      };
      final showNavigation =
          contentWidth > constraints.maxWidth + 0.5 &&
          (widget.tvMode || !compact || desktopPointerPlatform);
      _scheduleNavigationSync();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: widget.section.title,
            trailing: '$itemCount nội dung',
            actionKey: ValueKey('artist-section-show-all-${widget.section.id}'),
            onAction: widget.onShowAll,
            previousKey: ValueKey(
              'artist-section-${widget.section.id}-previous',
            ),
            nextKey: ValueKey('artist-section-${widget.section.id}-next'),
            showNavigation: showNavigation,
            onPrevious: _canScrollBack ? () => _scrollBy(-0.82) : null,
            onNext: _canScrollForward ? () => _scrollBy(0.82) : null,
            tvMode: widget.tvMode,
          ),
          SizedBox(height: widget.tvMode ? 17 : 12),
          SizedBox(
            height: width + (widget.tvMode ? 104 : 88),
            child: ListView.separated(
              key: ValueKey('artist-section-${widget.section.id}-list'),
              controller: _scrollController,
              scrollCacheExtent: const ScrollCacheExtent.viewport(1),
              primary: false,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemCount: itemCount,
              separatorBuilder: (_, __) => SizedBox(width: gap),
              itemBuilder: (context, index) {
                final collection = widget.section.collections[index];
                return SizedBox(
                  width: width,
                  child: _ArtistCollectionCard(
                    key: ValueKey('artist-collection-${collection.id}'),
                    collection: collection,
                    onOpen: () => widget.onTap(collection),
                    onPlay: widget.onPlay == null
                        ? null
                        : () => widget.onPlay!(collection),
                    onToggleSaved: widget.onToggleSaved == null
                        ? null
                        : () => widget.onToggleSaved!(collection),
                    onShare:
                        widget.onShare == null ||
                            collection.externalUrl.trim().isEmpty
                        ? null
                        : () => widget.onShare!(collection),
                    saved: widget.savedCollectionIds.contains(collection.id),
                    playing: widget.quickPlayingCollectionId == collection.id,
                    persistentActions: widget.tvMode || touchPlatform,
                    tvMode: widget.tvMode,
                  ),
                );
              },
            ),
          ),
        ],
      );
    },
  );
}

bool _sameCollectionOrder(
  List<CatalogCollection> previous,
  List<CatalogCollection> current,
) {
  if (previous.length != current.length) return false;
  for (var index = 0; index < previous.length; index++) {
    if (previous[index].id != current[index].id) return false;
  }
  return true;
}

class _ArtistCollectionCard extends StatefulWidget {
  const _ArtistCollectionCard({
    super.key,
    required this.collection,
    required this.onOpen,
    required this.onPlay,
    required this.onToggleSaved,
    required this.onShare,
    required this.saved,
    required this.playing,
    required this.persistentActions,
    required this.tvMode,
  });

  final CatalogCollection collection;
  final VoidCallback onOpen;
  final VoidCallback? onPlay;
  final VoidCallback? onToggleSaved;
  final VoidCallback? onShare;
  final bool saved;
  final bool playing;
  final bool persistentActions;
  final bool tvMode;

  @override
  State<_ArtistCollectionCard> createState() => _ArtistCollectionCardState();
}

class _ArtistCollectionCardState extends State<_ArtistCollectionCard> {
  final FocusNode _focusNode = FocusNode();
  bool _hovered = false;
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collection = widget.collection;
    final active = _hovered || _focused;
    final actionsVisible = widget.persistentActions || active;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 170);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      button: true,
      onTap: widget.onOpen,
      label: 'Mở ${collection.kindLabel} ${collection.title}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: FocusableActionDetector(
          focusNode: _focusNode,
          mouseCursor: SystemMouseCursors.click,
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onOpen();
                return null;
              },
            ),
          },
          onFocusChange: (value) {
            setState(() => _focused = value);
            if (value) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Scrollable.ensureVisible(
                  context,
                  duration: reducedMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  alignment: 0.14,
                );
              });
            }
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onOpen,
              onSecondaryTapDown: (details) => showCatalogCollectionContextMenu(
                context: context,
                globalPosition: details.globalPosition,
                keyPrefix: 'artist-collection',
                collection: collection,
                saved: widget.saved,
                playing: widget.playing,
                onOpen: widget.onOpen,
                onPlay: widget.onPlay,
                onToggleSaved: widget.onToggleSaved,
                onShare: widget.onShare,
              ),
              canRequestFocus: false,
              excludeFromSemantics: true,
              mouseCursor: SystemMouseCursors.click,
              borderRadius: BorderRadius.circular(widget.tvMode ? 18 : 14),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: LayoutBuilder(
                        builder: (context, artworkConstraints) => AnimatedContainer(
                          duration: duration,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              widget.tvMode ? 18 : 14,
                            ),
                            border: Border.all(
                              color: _focused
                                  ? ZingColors.lime
                                  : _hovered
                                  ? ZingColors.purpleBright.withValues(
                                      alpha: 0.75,
                                    )
                                  : Colors.transparent,
                              width: _focused
                                  ? 3
                                  : _hovered
                                  ? 2
                                  : 1,
                            ),
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                      color: ZingColors.purple.withValues(
                                        alpha: 0.3,
                                      ),
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
                              AlbumArt(
                                imageUrl: collection.thumbnail,
                                semanticLabel: 'Ảnh ${collection.title}',
                                size: artworkConstraints.maxWidth,
                                borderRadius: 0,
                              ),
                              AnimatedContainer(
                                duration: duration,
                                color: active
                                    ? const Color(0x550D0813)
                                    : Colors.transparent,
                              ),
                              Positioned.fill(
                                child: Align(
                                  alignment: Alignment.center,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: widget.tvMode ? 12 : 2,
                                    ),
                                    child: ExcludeSemantics(
                                      excluding: !actionsVisible,
                                      child: ExcludeFocus(
                                        excluding: !actionsVisible,
                                        child: IgnorePointer(
                                          ignoring: !actionsVisible,
                                          child: AnimatedOpacity(
                                            key: ValueKey(
                                              'artist-collection-actions-${collection.id}',
                                            ),
                                            opacity: actionsVisible ? 1 : 0,
                                            duration: duration,
                                            child: CatalogCollectionActionDeck(
                                              keyPrefix: 'artist-collection',
                                              collection: collection,
                                              tvMode: widget.tvMode,
                                              touchMode:
                                                  widget.persistentActions &&
                                                  !widget.tvMode,
                                              active: active,
                                              saved: widget.saved,
                                              playing: widget.playing,
                                              onOpen: widget.onOpen,
                                              onPlay: widget.onPlay,
                                              onToggleSaved:
                                                  widget.onToggleSaved,
                                              onShare: widget.onShare,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
        ),
      ),
    );
  }
}

class _ArtistVideoRail extends StatefulWidget {
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
  State<_ArtistVideoRail> createState() => _ArtistVideoRailState();
}

class _ArtistVideoRailState extends State<_ArtistVideoRail> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollBack = false;
  bool _canScrollForward = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncNavigationState);
  }

  @override
  void didUpdateWidget(covariant _ArtistVideoRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameVideoOrder(oldWidget.videos, widget.videos) ||
        oldWidget.tvMode != widget.tvMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.minScrollExtent);
        _syncNavigationState();
      });
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_syncNavigationState)
      ..dispose();
    super.dispose();
  }

  void _syncNavigationState() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final canScrollBack = position.pixels > position.minScrollExtent + 0.5;
    final canScrollForward = position.pixels < position.maxScrollExtent - 0.5;
    if (canScrollBack == _canScrollBack &&
        canScrollForward == _canScrollForward) {
      return;
    }
    setState(() {
      _canScrollBack = canScrollBack;
      _canScrollForward = canScrollForward;
    });
  }

  void _scrollBy(double direction) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = (position.pixels + position.viewportDimension * direction)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (MediaQuery.disableAnimationsOf(context)) {
      _scrollController.jumpTo(target);
    } else {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = widget.tvMode
          ? 332.0
          : constraints.maxWidth >= 900
          ? 278.0
          : constraints.maxWidth >= 560
          ? 252.0
          : 224.0;
      final gap = widget.tvMode ? 22.0 : 15.0;
      final contentWidth = widget.videos.isEmpty
          ? 0.0
          : widget.videos.length * width + (widget.videos.length - 1) * gap;
      final compact = !widget.tvMode && constraints.maxWidth < 620;
      final desktopPointerPlatform = switch (Theme.of(context).platform) {
        TargetPlatform.macOS ||
        TargetPlatform.windows ||
        TargetPlatform.linux => true,
        _ => false,
      };
      final showNavigation =
          contentWidth > constraints.maxWidth + 0.5 &&
          (widget.tvMode || !compact || desktopPointerPlatform);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncNavigationState();
      });
      return Column(
        key: const ValueKey('artist-video-rail'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'MV',
            trailing: '${widget.videos.length} video',
            actionKey: const ValueKey('artist-videos-show-all'),
            onAction: widget.onShowAll,
            previousKey: const ValueKey('artist-video-previous'),
            nextKey: const ValueKey('artist-video-next'),
            showNavigation: showNavigation,
            onPrevious: _canScrollBack ? () => _scrollBy(-0.82) : null,
            onNext: _canScrollForward ? () => _scrollBy(0.82) : null,
            tvMode: widget.tvMode,
          ),
          SizedBox(height: widget.tvMode ? 18 : 13),
          SizedBox(
            height: width * 9 / 16 + (widget.tvMode ? 88 : 72),
            child: ListView.separated(
              key: const ValueKey('artist-video-list'),
              controller: _scrollController,
              scrollCacheExtent: const ScrollCacheExtent.viewport(1),
              primary: false,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemCount: widget.videos.length,
              separatorBuilder: (_, __) => SizedBox(width: gap),
              itemBuilder: (context, index) {
                final video = widget.videos[index];
                return SizedBox(
                  width: width,
                  child: _ArtistVideoCard(
                    key: ValueKey('artist-video-${video.id}'),
                    video: video,
                    onTap: () => widget.onTap(video),
                    tvMode: widget.tvMode,
                  ),
                );
              },
            ),
          ),
        ],
      );
    },
  );
}

bool _sameVideoOrder(List<CatalogVideo> previous, List<CatalogVideo> current) {
  if (previous.length != current.length) return false;
  for (var index = 0; index < previous.length; index++) {
    if (previous[index].id != current[index].id) return false;
  }
  return true;
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
  final FocusNode _focusNode = FocusNode();
  bool _hovered = false;
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 170);
    final video = widget.video;
    final active = _hovered || _focused;
    return Semantics(
      button: true,
      onTap: widget.onTap,
      label:
          'Mở MV ${video.title}${video.artist.isEmpty ? '' : ' của ${video.artist}'}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: FocusableActionDetector(
          focusNode: _focusNode,
          mouseCursor: SystemMouseCursors.click,
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap();
                return null;
              },
            ),
          },
          onFocusChange: (value) {
            setState(() => _focused = value);
            if (value) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Scrollable.ensureVisible(
                  context,
                  duration: reducedMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  alignment: 0.12,
                );
              });
            }
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              canRequestFocus: false,
              excludeFromSemantics: true,
              mouseCursor: SystemMouseCursors.click,
              borderRadius: BorderRadius.circular(widget.tvMode ? 18 : 14),
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
                            color: _focused
                                ? ZingColors.lime
                                : _hovered
                                ? ZingColors.purpleBright.withValues(
                                    alpha: 0.75,
                                  )
                                : Colors.transparent,
                            width: _focused
                                ? 3
                                : _hovered
                                ? 2
                                : 1,
                          ),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: ZingColors.purple.withValues(
                                      alpha: 0.3,
                                    ),
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
                              color: active
                                  ? const Color(0x660D0813)
                                  : Colors.transparent,
                              child: Center(
                                child: Container(
                                  width: widget.tvMode ? 64 : 50,
                                  height: widget.tvMode ? 64 : 50,
                                  decoration: BoxDecoration(
                                    color: active
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
    this.previousKey,
    this.nextKey,
    this.showNavigation = false,
    this.onPrevious,
    this.onNext,
    required this.tvMode,
  });

  final String title;
  final String trailing;
  final Key? actionKey;
  final VoidCallback? onAction;
  final Key? previousKey;
  final Key? nextKey;
  final bool showNavigation;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
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
      if (showNavigation) ...[
        SizedBox(width: tvMode ? 14 : 9),
        _ArtistRailButton(
          key: previousKey,
          icon: Icons.chevron_left_rounded,
          tooltip: 'Xem danh sách trước',
          onPressed: onPrevious,
          tvMode: tvMode,
        ),
        SizedBox(width: tvMode ? 10 : 6),
        _ArtistRailButton(
          key: nextKey,
          icon: Icons.chevron_right_rounded,
          tooltip: 'Xem danh sách tiếp theo',
          onPressed: onNext,
          tvMode: tvMode,
        ),
      ],
    ],
  );
}

class _ArtistRailButton extends StatelessWidget {
  const _ArtistRailButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.tvMode,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: tooltip,
    constraints: BoxConstraints.tightFor(
      width: tvMode ? 52 : 38,
      height: tvMode ? 52 : 38,
    ),
    padding: EdgeInsets.zero,
    iconSize: tvMode ? 32 : 24,
    onPressed: onPressed,
    icon: Icon(icon),
  );
}
