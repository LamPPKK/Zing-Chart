import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/catalog_search.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';

class SearchDiscoverySummary extends StatelessWidget {
  const SearchDiscoverySummary({
    super.key,
    required this.query,
    required this.isLoading,
    required this.result,
    required this.errorMessage,
    required this.section,
    required this.onSuggestion,
    required this.onArtistTap,
    required this.onSongTap,
    required this.onCollectionTap,
    required this.onVideoTap,
    required this.onRetry,
    this.tvMode = false,
  });

  final String query;
  final bool isLoading;
  final CatalogSearchResult? result;
  final String? errorMessage;
  final CatalogSearchSection section;
  final ValueChanged<String> onSuggestion;
  final ValueChanged<CatalogArtist> onArtistTap;
  final ValueChanged<CatalogSong> onSongTap;
  final ValueChanged<CatalogCollection> onCollectionTap;
  final ValueChanged<CatalogVideo> onVideoTap;
  final VoidCallback onRetry;
  final bool tvMode;

  static const _suggestions = ['Sơn Tùng M-TP', 'V-Pop', 'Chill', 'Nhạc mới'];

  @override
  Widget build(BuildContext context) {
    final horizontal = tvMode ? 32.0 : 20.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 18),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        child: _content(context),
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (query.isEmpty) return _SearchInvitation(onSuggestion: onSuggestion);
    if (isLoading) {
      return _CatalogSearchLoadingState(tvMode: tvMode);
    }
    if (errorMessage != null) {
      return Container(
        key: const ValueKey('catalog-search-error'),
        padding: const EdgeInsets.all(20),
        decoration: _panelDecoration(context),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: ZingColors.coral),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chưa kết nối được tìm kiếm toàn catalog',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Đang hiển thị kết quả gần nhất từ #zingchart.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      );
    }

    final searchResult = result;
    if (searchResult == null || searchResult.isEmpty) {
      return Container(
        key: const ValueKey('catalog-search-empty'),
        padding: const EdgeInsets.all(24),
        decoration: _panelDecoration(context),
        child: Row(
          children: [
            const Icon(Icons.manage_search_rounded, size: 38),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Không tìm thấy kết quả cho “$query”',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final artist = searchResult.artists.firstOrNull;
    final highlightedSongs = searchResult.songs.take(2).toList(growable: false);
    return Column(
      key: const ValueKey('catalog-search-result-summary'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section == CatalogSearchSection.artists) ...[
          const _SectionLabel('NGHỆ SĨ/OA'),
          const SizedBox(height: 10),
          _ArtistResults(
            artists: searchResult.artists,
            onArtistTap: onArtistTap,
            tvMode: tvMode,
          ),
          const SizedBox(height: 18),
        ] else if (section == CatalogSearchSection.collections) ...[
          const _SectionLabel('PLAYLIST/ALBUM'),
          const SizedBox(height: 10),
          _CollectionResults(
            collections: searchResult.collections,
            onCollectionTap: onCollectionTap,
            tvMode: tvMode,
          ),
          const SizedBox(height: 18),
        ] else if (section == CatalogSearchSection.videos) ...[
          const _SectionLabel('MV'),
          const SizedBox(height: 10),
          _VideoResults(
            videos: searchResult.videos,
            onVideoTap: onVideoTap,
            tvMode: tvMode,
          ),
          const SizedBox(height: 18),
        ] else if (section == CatalogSearchSection.all &&
            (artist != null || highlightedSongs.isNotEmpty)) ...[
          const _SectionLabel('NỔI BẬT'),
          const SizedBox(height: 10),
          _Highlights(
            artist: artist,
            songs: highlightedSongs,
            onArtistTap: onArtistTap,
            onSongTap: onSongTap,
            tvMode: tvMode,
          ),
          const SizedBox(height: 18),
        ],
        if (section == CatalogSearchSection.all &&
            searchResult.collections.isNotEmpty) ...[
          const _SectionLabel('PLAYLIST NỔI BẬT'),
          const SizedBox(height: 10),
          _CollectionResults(
            collections: searchResult.collections
                .take(4)
                .toList(growable: false),
            onCollectionTap: onCollectionTap,
            tvMode: tvMode,
          ),
          const SizedBox(height: 18),
        ],
        if (section != CatalogSearchSection.artists &&
            section != CatalogSearchSection.collections &&
            section != CatalogSearchSection.videos &&
            searchResult.songs.any((item) => !item.playable))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: ZingColors.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ZingColors.purpleBright.withValues(alpha: 0.22),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 19),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Một số bài chỉ có thể phát khi nguồn Zing cho phép tại khu vực của bạn.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  BoxDecoration _panelDecoration(
    BuildContext context, {
    bool highlighted = false,
  }) => BoxDecoration(
    gradient: highlighted
        ? LinearGradient(
            colors: [
              ZingColors.purple.withValues(alpha: 0.32),
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
            ],
          )
        : null,
    color: highlighted
        ? null
        : Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
    borderRadius: BorderRadius.circular(tvMode ? 20 : 16),
    border: Border.all(
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.3),
    ),
  );
}

class SearchDiscoverySecondarySections extends StatelessWidget {
  const SearchDiscoverySecondarySections({
    super.key,
    required this.result,
    required this.onArtistTap,
    required this.onCollectionTap,
    required this.onVideoTap,
    this.onSectionSelected,
    this.tvMode = false,
  });

  final CatalogSearchResult result;
  final ValueChanged<CatalogArtist> onArtistTap;
  final ValueChanged<CatalogCollection> onCollectionTap;
  final ValueChanged<CatalogVideo> onVideoTap;
  final ValueChanged<CatalogSearchSection>? onSectionSelected;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final collections = result.collections.take(8).toList(growable: false);
    final videos = result.videos.take(8).toList(growable: false);
    final artists = result.artists.take(6).toList(growable: false);
    if (collections.isEmpty && videos.isEmpty && artists.isEmpty) {
      return const SizedBox.shrink();
    }
    final horizontal = tvMode ? 32.0 : 20.0;
    return Padding(
      key: const ValueKey('catalog-search-secondary-sections'),
      padding: EdgeInsets.fromLTRB(
        horizontal,
        tvMode ? 14 : 8,
        horizontal,
        tvMode ? 52 : 30,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (collections.isNotEmpty) ...[
            _SearchResultSectionHeader(
              label: 'PLAYLIST/ALBUM',
              onSeeAll: onSectionSelected == null
                  ? null
                  : () => onSectionSelected!(CatalogSearchSection.collections),
              tvMode: tvMode,
            ),
            SizedBox(height: tvMode ? 16 : 10),
            _CollectionResults(
              collections: collections,
              onCollectionTap: onCollectionTap,
              tvMode: tvMode,
            ),
          ],
          if (collections.isNotEmpty && videos.isNotEmpty)
            SizedBox(height: tvMode ? 38 : 28),
          if (videos.isNotEmpty) ...[
            _SearchResultSectionHeader(
              label: 'MV',
              onSeeAll: onSectionSelected == null
                  ? null
                  : () => onSectionSelected!(CatalogSearchSection.videos),
              tvMode: tvMode,
            ),
            SizedBox(height: tvMode ? 16 : 10),
            _VideoResults(
              videos: videos,
              onVideoTap: onVideoTap,
              tvMode: tvMode,
            ),
          ],
          if (artists.isNotEmpty &&
              (collections.isNotEmpty || videos.isNotEmpty))
            SizedBox(height: tvMode ? 38 : 28),
          if (artists.isNotEmpty) ...[
            _SearchResultSectionHeader(
              label: 'NGHỆ SĨ/OA',
              onSeeAll: onSectionSelected == null
                  ? null
                  : () => onSectionSelected!(CatalogSearchSection.artists),
              tvMode: tvMode,
            ),
            SizedBox(height: tvMode ? 16 : 10),
            _ArtistResults(
              artists: artists,
              onArtistTap: onArtistTap,
              tvMode: tvMode,
            ),
          ],
        ],
      ),
    );
  }
}

class _Highlights extends StatelessWidget {
  const _Highlights({
    required this.artist,
    required this.songs,
    required this.onArtistTap,
    required this.onSongTap,
    required this.tvMode,
  });

  final CatalogArtist? artist;
  final List<CatalogSong> songs;
  final ValueChanged<CatalogArtist> onArtistTap;
  final ValueChanged<CatalogSong> onSongTap;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (artist case final value?)
        _ArtistHighlightCard(
          artist: value,
          onTap: () => onArtistTap(value),
          tvMode: tvMode,
        ),
      ...songs.map(
        (song) => _SongHighlightCard(
          catalogSong: song,
          onTap: () => onSongTap(song),
          onArtistTap: onArtistTap,
          tvMode: tvMode,
        ),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? cards.length.clamp(1, 3)
            : constraints.maxWidth >= 600
            ? 2
            : 1;
        final gap = tvMode ? 20.0 : 18.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(growable: false),
        );
      },
    );
  }
}

class _ArtistResults extends StatelessWidget {
  const _ArtistResults({
    required this.artists,
    required this.onArtistTap,
    required this.tvMode,
  });

  final List<CatalogArtist> artists;
  final ValueChanged<CatalogArtist> onArtistTap;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: _resultPanelDecoration(context),
        child: const Text(
          'Không tìm thấy nghệ sĩ phù hợp.',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = tvMode
            ? (constraints.maxWidth >= 1500 ? 5 : 4)
            : constraints.maxWidth >= 1180
            ? 5
            : constraints.maxWidth >= 880
            ? 4
            : constraints.maxWidth >= 620
            ? 3
            : constraints.maxWidth >= 280
            ? 2
            : 1;
        final gap = tvMode ? 24.0 : 18.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: tvMode ? 30 : 24,
          children: artists
              .map(
                (artist) => SizedBox(
                  width: width,
                  child: _ArtistCatalogCard(
                    artist: artist,
                    onTap: () => onArtistTap(artist),
                    tvMode: tvMode,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _ArtistCatalogCard extends StatefulWidget {
  const _ArtistCatalogCard({
    required this.artist,
    required this.onTap,
    required this.tvMode,
  });

  final CatalogArtist artist;
  final VoidCallback onTap;
  final bool tvMode;

  @override
  State<_ArtistCatalogCard> createState() => _ArtistCatalogCardState();
}

class _ArtistCatalogCardState extends State<_ArtistCatalogCard> {
  late final FocusNode _focusNode;
  bool _focused = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      debugLabel: 'catalog-search-artist-${widget.artist.id}',
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _focused || _hovered;
    final followerLabel = _artistFollowerLabel(widget.artist.totalFollow);
    final semanticLabel = widget.artist.totalFollow > 0
        ? 'Mở nghệ sĩ ${widget.artist.name}, $followerLabel'
        : 'Mở nghệ sĩ ${widget.artist.name}';
    return Semantics(
      key: ValueKey('catalog-artist-${widget.artist.id}'),
      button: true,
      label: semanticLabel,
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: InkWell(
          focusNode: _focusNode,
          onTap: widget.onTap,
          onHover: (value) => setState(() => _hovered = value),
          onFocusChange: (value) {
            setState(() => _focused = value);
            if (value) {
              Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 220),
                alignment: 0.16,
              );
            }
          },
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(widget.tvMode ? 24 : 18),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              widget.tvMode ? 10 : 6,
              widget.tvMode ? 10 : 6,
              widget.tvMode ? 10 : 6,
              widget.tvMode ? 14 : 10,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final avatarSize = math.min(
                      constraints.maxWidth,
                      widget.tvMode ? 238.0 : 220.0,
                    );
                    return Center(
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        scale: active ? 1.025 : 1,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: active
                                  ? ZingColors.lime
                                  : Theme.of(context).colorScheme.outlineVariant
                                        .withValues(alpha: 0.24),
                              width: active ? 3 : 1,
                            ),
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                      color: ZingColors.purple.withValues(
                                        alpha: 0.32,
                                      ),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                  ]
                                : null,
                          ),
                          child: ClipOval(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                AlbumArt(
                                  imageUrl: widget.artist.avatar,
                                  semanticLabel:
                                      'Ảnh nghệ sĩ ${widget.artist.name}',
                                  size: avatarSize,
                                  borderRadius: 0,
                                ),
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 160),
                                  opacity: active ? 1 : 0,
                                  child: ColoredBox(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    child: Center(
                                      child: Container(
                                        width: widget.tvMode ? 62 : 48,
                                        height: widget.tvMode ? 62 : 48,
                                        decoration: const BoxDecoration(
                                          color: ZingColors.purpleBright,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white,
                                          size: widget.tvMode ? 34 : 27,
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
                    );
                  },
                ),
                SizedBox(height: widget.tvMode ? 15 : 11),
                Text(
                  widget.artist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: widget.tvMode ? 20 : 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: widget.tvMode ? 6 : 4),
                Text(
                  followerLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: widget.tvMode ? 15 : 12,
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

String _artistFollowerLabel(int totalFollow) {
  if (totalFollow <= 0) return 'Mở hồ sơ nghệ sĩ';
  if (totalFollow >= 1000000) {
    final value = totalFollow / 1000000;
    return '${_trimCompactDecimal(value)}M quan tâm';
  }
  if (totalFollow >= 1000) {
    final value = totalFollow / 1000;
    return '${_trimCompactDecimal(value)}K quan tâm';
  }
  return '$totalFollow quan tâm';
}

String _trimCompactDecimal(double value) {
  final fixed = value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}

class _CollectionResults extends StatelessWidget {
  const _CollectionResults({
    required this.collections,
    required this.onCollectionTap,
    required this.tvMode,
  });

  final List<CatalogCollection> collections;
  final ValueChanged<CatalogCollection> onCollectionTap;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    if (collections.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: _resultPanelDecoration(context),
        child: const Text(
          'Không tìm thấy playlist hoặc album phù hợp.',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1120
            ? 5
            : constraints.maxWidth >= 840
            ? 4
            : constraints.maxWidth >= 560
            ? 3
            : constraints.maxWidth >= 250
            ? 2
            : 1;
        final spacing = tvMode
            ? 20.0
            : constraints.maxWidth >= 840
            ? 24.0
            : constraints.maxWidth >= 560
            ? 18.0
            : 12.0;
        final width =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: tvMode ? 28 : 24,
          children: collections
              .map(
                (collection) => SizedBox(
                  width: width,
                  child: _CollectionCard(
                    collection: collection,
                    onTap: () => onCollectionTap(collection),
                    tvMode: tvMode,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _VideoResults extends StatelessWidget {
  const _VideoResults({
    required this.videos,
    required this.onVideoTap,
    required this.tvMode,
  });

  final List<CatalogVideo> videos;
  final ValueChanged<CatalogVideo> onVideoTap;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return Container(
        key: const ValueKey('catalog-video-empty'),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: _resultPanelDecoration(context),
        child: const Text(
          'Không tìm thấy MV phù hợp.',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 820
            ? 3
            : constraints.maxWidth >= 420
            ? 2
            : 1;
        final spacing = tvMode
            ? 20.0
            : constraints.maxWidth >= 820
            ? 24.0
            : constraints.maxWidth >= 420
            ? 18.0
            : 12.0;
        final width =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: tvMode ? 30 : 24,
          children: videos
              .map(
                (video) => SizedBox(
                  width: width,
                  child: _VideoCard(
                    video: video,
                    onTap: () => onVideoTap(video),
                    tvMode: tvMode,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _VideoCard extends StatefulWidget {
  const _VideoCard({
    required this.video,
    required this.onTap,
    required this.tvMode,
  });

  final CatalogVideo video;
  final VoidCallback onTap;
  final bool tvMode;

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  bool _hovered = false;
  bool _focused = false;

  bool get _showAction => _hovered || _focused;

  Duration _motionDuration(BuildContext context, int milliseconds) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: milliseconds);

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      key: ValueKey('catalog-video-${widget.video.id}'),
      onTap: widget.onTap,
      onHover: (value) {
        if (_hovered == value) return;
        setState(() => _hovered = value);
      },
      onFocusChange: (value) {
        if (_focused == value) return;
        setState(() => _focused = value);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedScale(
                        scale: _showAction ? 1.035 : 1,
                        duration: _motionDuration(context, 180),
                        curve: Curves.easeOutCubic,
                        child: AlbumArt(
                          key: ValueKey(
                            'catalog-video-cover-${widget.video.id}',
                          ),
                          imageUrl: widget.video.thumbnail,
                          semanticLabel: 'Ảnh MV ${widget.video.title}',
                          size: constraints.maxWidth,
                          borderRadius: 6,
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            key: ValueKey(
                              'catalog-video-overlay-${widget.video.id}',
                            ),
                            opacity: _showAction ? 1 : 0,
                            duration: _motionDuration(context, 160),
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.42),
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            key: ValueKey(
                              'catalog-video-action-${widget.video.id}',
                            ),
                            opacity: _showAction ? 1 : 0,
                            duration: _motionDuration(context, 160),
                            child: AnimatedScale(
                              scale: _showAction ? 1 : 0.84,
                              duration: _motionDuration(context, 180),
                              curve: Curves.easeOutBack,
                              child: Container(
                                width: widget.tvMode ? 58 : 46,
                                height: widget.tvMode ? 58 : 46,
                                decoration: BoxDecoration(
                                  color: ZingColors.purpleBright,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: widget.tvMode ? 34 : 28,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 6,
                        bottom: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            _durationLabel(
                              widget.video.duration,
                              padMinutes: true,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AlbumArt(
                  key: ValueKey('catalog-video-artist-${widget.video.id}'),
                  imageUrl: widget.video.primaryArtist?.avatar ?? '',
                  semanticLabel: widget.video.artist.isEmpty
                      ? 'Nghệ sĩ của ${widget.video.title}'
                      : 'Ảnh nghệ sĩ ${widget.video.artist}',
                  size: widget.tvMode ? 48 : 40,
                  borderRadius: 999,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.video.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: widget.tvMode ? 18 : 14,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.video.artist.isEmpty
                            ? 'Mở trên Zing MP3'
                            : widget.video.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: widget.tvMode ? 14 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _CollectionCard extends StatefulWidget {
  const _CollectionCard({
    required this.collection,
    required this.onTap,
    required this.tvMode,
  });

  final CatalogCollection collection;
  final VoidCallback onTap;
  final bool tvMode;

  @override
  State<_CollectionCard> createState() => _CollectionCardState();
}

class _CollectionCardState extends State<_CollectionCard> {
  bool _hovered = false;
  bool _focused = false;

  bool get _showAction => _hovered || _focused;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      key: ValueKey('catalog-collection-${widget.collection.id}'),
      onTap: widget.onTap,
      onHover: (value) {
        if (_hovered == value) return;
        setState(() => _hovered = value);
      },
      onFocusChange: (value) {
        if (_focused == value) return;
        setState(() => _focused = value);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    AnimatedScale(
                      scale: _showAction ? 1.035 : 1,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: AlbumArt(
                        key: ValueKey(
                          'catalog-collection-cover-${widget.collection.id}',
                        ),
                        imageUrl: widget.collection.thumbnail,
                        semanticLabel: 'Ảnh ${widget.collection.title}',
                        size: constraints.maxWidth,
                        borderRadius: 6,
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          key: ValueKey(
                            'catalog-collection-overlay-${widget.collection.id}',
                          ),
                          opacity: _showAction ? 1 : 0,
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 160),
                          child: ColoredBox(
                            color: Colors.black.withValues(alpha: 0.42),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: AnimatedOpacity(
                            key: ValueKey(
                              'catalog-collection-action-${widget.collection.id}',
                            ),
                            opacity: _showAction ? 1 : 0,
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 160),
                            child: AnimatedScale(
                              scale: _showAction ? 1 : 0.84,
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 180),
                              curve: Curves.easeOutBack,
                              child: Container(
                                width: widget.tvMode ? 58 : 46,
                                height: widget.tvMode ? 58 : 46,
                                decoration: BoxDecoration(
                                  color: ZingColors.purpleBright,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: widget.tvMode ? 34 : 28,
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
            const SizedBox(height: 10),
            Text(
              widget.collection.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: widget.tvMode ? 18 : 14,
                height: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              widget.collection.artist.isEmpty
                  ? widget.collection.kindLabel
                  : widget.collection.artist,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: widget.tvMode ? 14 : 12,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HighlightCardFrame extends StatefulWidget {
  const _HighlightCardFrame({
    super.key,
    required this.semanticLabel,
    required this.onTap,
    required this.tvMode,
    required this.child,
  });

  final String semanticLabel;
  final VoidCallback onTap;
  final bool tvMode;
  final Widget child;

  @override
  State<_HighlightCardFrame> createState() => _HighlightCardFrameState();
}

class _HighlightCardFrameState extends State<_HighlightCardFrame> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _focused;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      onTap: widget.onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (value) {
            if (_hovered == value) return;
            setState(() => _hovered = value);
          },
          onFocusChange: (value) {
            if (_focused == value) return;
            setState(() => _focused = value);
            if (value) {
              Scrollable.ensureVisible(
                context,
                duration: duration,
                alignment: 0.18,
              );
            }
          },
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(widget.tvMode ? 10 : 6),
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            height: widget.tvMode ? 132 : 104,
            padding: EdgeInsets.all(widget.tvMode ? 16 : 10),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: active ? 0.92 : 0.78),
              borderRadius: BorderRadius.circular(widget.tvMode ? 10 : 6),
              border: Border.all(
                color: active
                    ? ZingColors.lime.withValues(alpha: 0.88)
                    : scheme.outlineVariant.withValues(alpha: 0.18),
                width: _focused
                    ? 3
                    : active
                    ? 2
                    : 1,
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _ArtistHighlightCard extends StatelessWidget {
  const _ArtistHighlightCard({
    required this.artist,
    required this.onTap,
    required this.tvMode,
  });

  final CatalogArtist artist;
  final VoidCallback onTap;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => _HighlightCardFrame(
    key: ValueKey('catalog-artist-${artist.id}'),
    semanticLabel: artist.totalFollow > 0
        ? 'Mở nghệ sĩ ${artist.name}, ${_artistFollowerLabel(artist.totalFollow)}'
        : 'Mở nghệ sĩ ${artist.name}',
    onTap: onTap,
    tvMode: tvMode,
    child: Row(
      children: [
        AlbumArt(
          imageUrl: artist.avatar,
          semanticLabel: 'Ảnh nghệ sĩ ${artist.name}',
          size: tvMode ? 98 : 84,
          borderRadius: 999,
        ),
        SizedBox(width: tvMode ? 16 : 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nghệ sĩ',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: tvMode ? 14 : 12,
                ),
              ),
              SizedBox(height: tvMode ? 7 : 5),
              Text(
                artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: tvMode ? 20 : 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (artist.totalFollow > 0) ...[
                SizedBox(height: tvMode ? 6 : 4),
                Text(
                  _artistFollowerLabel(artist.totalFollow),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: tvMode ? 14 : 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _SongHighlightCard extends StatelessWidget {
  const _SongHighlightCard({
    required this.catalogSong,
    required this.onTap,
    required this.onArtistTap,
    required this.tvMode,
  });

  final CatalogSong catalogSong;
  final VoidCallback onTap;
  final ValueChanged<CatalogArtist> onArtistTap;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final song = catalogSong.song;
    return _HighlightCardFrame(
      key: ValueKey('catalog-highlight-song-${song.id}'),
      semanticLabel: catalogSong.playable
          ? 'Mở bài hát ${song.displayTitle}, ${song.artistsNames}'
          : 'Mở thông tin bài hát bị giới hạn ${song.displayTitle}',
      onTap: onTap,
      tvMode: tvMode,
      child: Row(
        children: [
          AlbumArt(
            imageUrl: song.thumbnail,
            semanticLabel: 'Ảnh bìa ${song.displayTitle}',
            size: tvMode ? 98 : 84,
            borderRadius: 6,
          ),
          SizedBox(width: tvMode ? 16 : 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  catalogSong.playable ? 'Bài hát' : 'Bài hát · Bị giới hạn',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: tvMode ? 14 : 12,
                  ),
                ),
                SizedBox(height: tvMode ? 7 : 5),
                Text(
                  song.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: tvMode ? 20 : 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: tvMode ? 6 : 4),
                _SearchArtistLinks(
                  fallbackText: song.artistsNames,
                  artists: catalogSong.artists,
                  onArtistTap: onArtistTap,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: tvMode ? 14 : 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchArtistLinks extends StatelessWidget {
  const _SearchArtistLinks({
    required this.fallbackText,
    required this.artists,
    required this.onArtistTap,
    required this.style,
  });

  final String fallbackText;
  final List<CatalogArtist> artists;
  final ValueChanged<CatalogArtist> onArtistTap;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) {
      return Text(
        fallbackText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    final children = <Widget>[];
    for (var index = 0; index < artists.length; index++) {
      final artist = artists[index];
      if (index > 0) children.add(Text(', ', style: style));
      children.add(
        Flexible(
          child: _SearchMetadataLink(
            key: ValueKey('search-artist-link-${artist.id}'),
            text: artist.name,
            semanticLabel: 'Mở nghệ sĩ ${artist.name}',
            onTap: () => onArtistTap(artist),
            style: style,
          ),
        ),
      );
    }
    return Row(children: children);
  }
}

class _SearchMetadataLink extends StatefulWidget {
  const _SearchMetadataLink({
    super.key,
    required this.text,
    required this.semanticLabel,
    required this.onTap,
    required this.style,
  });

  final String text;
  final String semanticLabel;
  final VoidCallback onTap;
  final TextStyle style;

  @override
  State<_SearchMetadataLink> createState() => _SearchMetadataLinkState();
}

class _SearchMetadataLinkState extends State<_SearchMetadataLink> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.semanticLabel,
    child: TextButton(
      onPressed: widget.onTap,
      onHover: (value) => setState(() => _highlighted = value),
      onFocusChange: (value) => setState(() => _highlighted = value),
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.centerLeft,
        foregroundColor: widget.style.color,
      ),
      child: Semantics(
        label: widget.semanticLabel,
        excludeSemantics: true,
        child: Text(
          widget.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: widget.style.copyWith(
            color: _highlighted ? ZingColors.purpleBright : widget.style.color,
            decoration: _highlighted ? TextDecoration.underline : null,
            decorationColor: ZingColors.purpleBright,
          ),
        ),
      ),
    ),
  );
}

BoxDecoration _resultPanelDecoration(
  BuildContext context, {
  bool highlighted = false,
}) => BoxDecoration(
  gradient: highlighted
      ? LinearGradient(
          colors: [
            ZingColors.purple.withValues(alpha: 0.35),
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.86),
          ],
        )
      : null,
  color: highlighted
      ? null
      : Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
  borderRadius: BorderRadius.circular(16),
  border: Border.all(
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
  ),
);

class _CatalogSearchLoadingState extends StatelessWidget {
  const _CatalogSearchLoadingState({required this.tvMode});

  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      key: const ValueKey('catalog-search-loading'),
      container: true,
      liveRegion: true,
      label: 'Đang tìm trên Zing MP3',
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsets.all(tvMode ? 28 : 20),
          decoration: _resultPanelDecoration(context),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final highlightCount = tvMode
                  ? 3
                  : width >= 900
                  ? 3
                  : width >= 540
                  ? 2
                  : 1;
              final collectionCount = tvMode
                  ? 5
                  : width >= 1040
                  ? 5
                  : width >= 760
                  ? 4
                  : width >= 480
                  ? 3
                  : 2;
              final highlightGap = tvMode ? 18.0 : 12.0;
              final highlightWidth =
                  (width - highlightGap * (highlightCount - 1)) /
                  highlightCount;
              final collectionGap = tvMode ? 20.0 : 14.0;
              final collectionWidth =
                  ((width - collectionGap * (collectionCount - 1)) /
                          collectionCount)
                      .clamp(104.0, tvMode ? 224.0 : 196.0);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      key: const ValueKey('catalog-search-loading-progress'),
                      value: reducedMotion ? 0.42 : null,
                      minHeight: 3,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  SizedBox(height: tvMode ? 20 : 15),
                  Row(
                    children: [
                      Icon(
                        Icons.manage_search_rounded,
                        color: ZingColors.coral,
                        size: tvMode ? 28 : 22,
                      ),
                      SizedBox(width: tvMode ? 12 : 9),
                      Expanded(
                        child: Text(
                          'Đang tìm trên Zing MP3…',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: tvMode ? 18 : 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: tvMode ? 28 : 22),
                  _SearchLoadingBlock(
                    key: const ValueKey(
                      'catalog-search-loading-highlight-title',
                    ),
                    width: tvMode ? 156 : 120,
                    height: tvMode ? 23 : 18,
                    radius: 6,
                  ),
                  SizedBox(height: tvMode ? 16 : 12),
                  Wrap(
                    key: const ValueKey('catalog-search-loading-highlights'),
                    spacing: highlightGap,
                    runSpacing: highlightGap,
                    children: [
                      for (var index = 0; index < highlightCount; index++)
                        _SearchLoadingHighlightCard(
                          key: ValueKey(
                            'catalog-search-loading-highlight-$index',
                          ),
                          width: highlightWidth,
                          tvMode: tvMode,
                        ),
                    ],
                  ),
                  SizedBox(height: tvMode ? 32 : 24),
                  _SearchLoadingBlock(
                    key: const ValueKey(
                      'catalog-search-loading-collection-title',
                    ),
                    width: tvMode ? 210 : 164,
                    height: tvMode ? 23 : 18,
                    radius: 6,
                  ),
                  SizedBox(height: tvMode ? 16 : 12),
                  SingleChildScrollView(
                    key: const ValueKey('catalog-search-loading-collections'),
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Row(
                      children: [
                        for (
                          var index = 0;
                          index < collectionCount;
                          index++
                        ) ...[
                          if (index > 0) SizedBox(width: collectionGap),
                          _SearchLoadingCollectionCard(
                            key: ValueKey(
                              'catalog-search-loading-collection-$index',
                            ),
                            width: collectionWidth,
                            tvMode: tvMode,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SearchLoadingHighlightCard extends StatelessWidget {
  const _SearchLoadingHighlightCard({
    super.key,
    required this.width,
    required this.tvMode,
  });

  final double width;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final artSize = tvMode ? 92.0 : 72.0;
    return Container(
      width: width,
      height: tvMode ? 132 : 106,
      padding: EdgeInsets.all(tvMode ? 18 : 14),
      decoration: _resultPanelDecoration(context, highlighted: true),
      child: Row(
        children: [
          _SearchLoadingBlock(
            width: artSize,
            height: artSize,
            radius: tvMode ? 20 : 16,
          ),
          SizedBox(width: tvMode ? 16 : 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SearchLoadingBlock(
                  width: double.infinity,
                  height: tvMode ? 18 : 14,
                  radius: 5,
                ),
                SizedBox(height: tvMode ? 11 : 8),
                FractionallySizedBox(
                  widthFactor: 0.68,
                  child: _SearchLoadingBlock(
                    width: double.infinity,
                    height: tvMode ? 14 : 11,
                    radius: 5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchLoadingCollectionCard extends StatelessWidget {
  const _SearchLoadingCollectionCard({
    super.key,
    required this.width,
    required this.tvMode,
  });

  final double width;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SearchLoadingBlock(
          width: width,
          height: width,
          radius: tvMode ? 20 : 14,
        ),
        SizedBox(height: tvMode ? 12 : 9),
        _SearchLoadingBlock(
          width: width * 0.82,
          height: tvMode ? 17 : 13,
          radius: 5,
        ),
        SizedBox(height: tvMode ? 9 : 7),
        _SearchLoadingBlock(
          width: width * 0.58,
          height: tvMode ? 13 : 10,
          radius: 5,
        ),
      ],
    ),
  );
}

class _SearchLoadingBlock extends StatelessWidget {
  const _SearchLoadingBlock({
    super.key,
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.14),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceContainerHighest.withValues(alpha: 0.74),
            colors.onSurface.withValues(alpha: 0.075),
            colors.surfaceContainerHighest.withValues(alpha: 0.5),
          ],
          stops: const [0, 0.54, 1],
        ),
      ),
    );
  }
}

class _SearchInvitation extends StatelessWidget {
  const _SearchInvitation({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('catalog-search-invitation'),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ZingColors.purple.withValues(alpha: 0.34),
            ZingColors.coral.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ZingColors.purpleBright.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.travel_explore_rounded, color: ZingColors.lime),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tìm trên toàn bộ catalog Zing MP3',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Khám phá bài hát, nghệ sĩ, lời bài hát, playlist/album và MV ngoài bảng xếp hạng realtime.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SearchDiscoverySummary._suggestions
                .map(
                  (suggestion) => ActionChip(
                    avatar: const Icon(Icons.north_west_rounded, size: 15),
                    label: Text(suggestion),
                    onPressed: () => onSuggestion(suggestion),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

String _durationLabel(Duration duration, {bool padMinutes = false}) {
  final rawMinutes = duration.inMinutes.toString();
  final minutes = padMinutes ? rawMinutes.padLeft(2, '0') : rawMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.4,
    ),
  );
}

class _SearchResultSectionHeader extends StatelessWidget {
  const _SearchResultSectionHeader({
    required this.label,
    required this.onSeeAll,
    required this.tvMode,
  });

  final String label;
  final VoidCallback? onSeeAll;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: tvMode ? 15 : 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.35,
          ),
        ),
      ),
      if (onSeeAll != null)
        TextButton(
          onPressed: onSeeAll,
          style: TextButton.styleFrom(
            minimumSize: Size(tvMode ? 108 : 80, tvMode ? 48 : 44),
            padding: EdgeInsets.symmetric(horizontal: tvMode ? 16 : 12),
          ),
          child: Text(
            'TẤT CẢ',
            style: TextStyle(
              fontSize: tvMode ? 14 : 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ),
    ],
  );
}
