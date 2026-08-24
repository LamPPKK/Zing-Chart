import 'package:flutter/material.dart';

import '../models/catalog_search.dart';
import '../models/release_catalog.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';
import 'catalog_artist_links.dart';
import 'catalog_collection_action_deck.dart';

class ReleaseCatalogView extends StatelessWidget {
  const ReleaseCatalogView({
    super.key,
    required this.catalog,
    required this.loading,
    required this.errorMessage,
    required this.contentType,
    required this.region,
    required this.onBack,
    required this.onRetry,
    required this.onContentTypeChanged,
    required this.onRegionChanged,
    required this.onCollectionTap,
    this.onCollectionPlay,
    this.onCollectionToggleSaved,
    this.onCollectionShare,
    this.onArtistTap,
    this.savedCollectionIds = const {},
    this.quickPlayingCollectionId,
    required this.songCount,
    required this.playableSongCount,
    required this.onPlayAll,
    this.tvMode = false,
  });

  final ReleaseCatalog catalog;
  final bool loading;
  final String? errorMessage;
  final ReleaseContentType contentType;
  final ReleaseRegion region;
  final VoidCallback onBack;
  final VoidCallback onRetry;
  final ValueChanged<ReleaseContentType> onContentTypeChanged;
  final ValueChanged<ReleaseRegion> onRegionChanged;
  final ValueChanged<CatalogCollection> onCollectionTap;
  final ValueChanged<CatalogCollection>? onCollectionPlay;
  final ValueChanged<CatalogCollection>? onCollectionToggleSaved;
  final ValueChanged<CatalogCollection>? onCollectionShare;
  final ValueChanged<CatalogArtist>? onArtistTap;
  final Set<String> savedCollectionIds;
  final String? quickPlayingCollectionId;
  final int songCount;
  final int playableSongCount;
  final VoidCallback? onPlayAll;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final horizontal = tvMode ? 32.0 : 20.0;
    if (loading && catalog.isEmpty) {
      return Padding(
        key: const ValueKey('release-catalog-loading'),
        padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 56),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang tải nhạc mới phát hành…'),
            ],
          ),
        ),
      );
    }
    if (catalog.isEmpty) {
      return Padding(
        key: const ValueKey('release-catalog-error'),
        padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 56),
        child: _ReleaseError(onBack: onBack, onRetry: onRetry),
      );
    }

    final albums = catalog.albumsFor(region);
    return Padding(
      key: const ValueKey('release-catalog'),
      padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, tvMode ? 42 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReleaseHero(onBack: onBack, tvMode: tvMode),
          if (errorMessage != null) ...[
            const SizedBox(height: 14),
            _ReleaseStaleNotice(onRetry: onRetry),
          ] else if (loading) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(minHeight: 3),
          ],
          SizedBox(height: tvMode ? 30 : 22),
          _ReleaseTabs(
            selected: contentType,
            onChanged: onContentTypeChanged,
            tvMode: tvMode,
          ),
          SizedBox(height: tvMode ? 24 : 18),
          _RegionFilters(
            selected: region,
            onChanged: onRegionChanged,
            tvMode: tvMode,
          ),
          SizedBox(height: tvMode ? 28 : 22),
          if (contentType == ReleaseContentType.songs)
            _SongSectionHeading(
              songCount: songCount,
              playableSongCount: playableSongCount,
              onPlayAll: onPlayAll,
              tvMode: tvMode,
            )
          else if (albums.isEmpty)
            const _ReleaseEmpty(
              key: ValueKey('release-albums-empty'),
              message: 'Chưa có album mới trong khu vực này.',
            )
          else
            _ReleaseAlbumGrid(
              albums: albums,
              onTap: onCollectionTap,
              onPlay: onCollectionPlay,
              onToggleSaved: onCollectionToggleSaved,
              onShare: onCollectionShare,
              onArtistTap: onArtistTap,
              savedCollectionIds: savedCollectionIds,
              quickPlayingCollectionId: quickPlayingCollectionId,
              tvMode: tvMode,
            ),
        ],
      ),
    );
  }
}

class _ReleaseHero extends StatelessWidget {
  const _ReleaseHero({required this.onBack, required this.tvMode});

  final VoidCallback onBack;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(tvMode ? 28 : 20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          ZingColors.purpleBright.withValues(alpha: 0.42),
          ZingColors.coral.withValues(alpha: 0.2),
          ZingColors.lime.withValues(alpha: 0.08),
        ],
      ),
      borderRadius: BorderRadius.circular(tvMode ? 24 : 18),
      border: Border.all(color: ZingColors.purpleBright.withValues(alpha: 0.4)),
    ),
    child: Row(
      children: [
        IconButton.filledTonal(
          key: const ValueKey('release-catalog-back'),
          tooltip: 'Quay lại Khám phá',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        SizedBox(width: tvMode ? 22 : 16),
        Container(
          width: tvMode ? 82 : 60,
          height: tvMode ? 82 : 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ZingColors.coral, ZingColors.purpleBright],
            ),
            borderRadius: BorderRadius.circular(tvMode ? 22 : 17),
            boxShadow: [
              BoxShadow(
                color: ZingColors.coral.withValues(alpha: 0.28),
                blurRadius: 24,
              ),
            ],
          ),
          child: Icon(
            Icons.fiber_new_rounded,
            color: Colors.white,
            size: tvMode ? 44 : 32,
          ),
        ),
        SizedBox(width: tvMode ? 22 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CẬP NHẬT TỪ ZING MP3',
                style: TextStyle(
                  color: ZingColors.lime,
                  fontSize: tvMode ? 14 : 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Mới Phát Hành',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: tvMode ? 38 : 27,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Những bài hát và album vừa ra mắt, phân loại theo thị trường.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: tvMode ? 15 : 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ReleaseTabs extends StatelessWidget {
  const _ReleaseTabs({
    required this.selected,
    required this.onChanged,
    required this.tvMode,
  });

  final ReleaseContentType selected;
  final ValueChanged<ReleaseContentType> onChanged;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Row(
    children: ReleaseContentType.values
        .map(
          (type) => Padding(
            padding: EdgeInsets.only(right: tvMode ? 32 : 24),
            child: _ReleaseTab(
              type: type,
              selected: selected == type,
              onTap: () => onChanged(type),
              tvMode: tvMode,
            ),
          ),
        )
        .toList(growable: false),
  );
}

class _ReleaseTab extends StatefulWidget {
  const _ReleaseTab({
    required this.type,
    required this.selected,
    required this.onTap,
    required this.tvMode,
  });

  final ReleaseContentType type;
  final bool selected;
  final VoidCallback onTap;
  final bool tvMode;

  @override
  State<_ReleaseTab> createState() => _ReleaseTabState();
}

class _ReleaseTabState extends State<_ReleaseTab> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: widget.selected,
    child: InkWell(
      key: ValueKey('release-tab-${widget.type.name}'),
      borderRadius: BorderRadius.circular(8),
      onFocusChange: (value) => setState(() => _focused = value),
      onTap: widget.onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(4, 10, 4, widget.tvMode ? 13 : 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: widget.selected
                  ? ZingColors.purpleBright
                  : _focused
                  ? ZingColors.lime
                  : Colors.transparent,
              width: widget.tvMode ? 4 : 3,
            ),
          ),
        ),
        child: Text(
          widget.type.label,
          style: TextStyle(
            color: widget.selected
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: widget.tvMode ? 18 : 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
      ),
    ),
  );
}

class _RegionFilters extends StatelessWidget {
  const _RegionFilters({
    required this.selected,
    required this.onChanged,
    required this.tvMode,
  });

  final ReleaseRegion selected;
  final ValueChanged<ReleaseRegion> onChanged;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: ReleaseRegion.values
          .map(
            (region) => Padding(
              padding: EdgeInsets.only(right: tvMode ? 14 : 9),
              child: ChoiceChip(
                key: ValueKey('release-region-${region.wireValue}'),
                label: Text(region.label),
                selected: selected == region,
                onSelected: (_) => onChanged(region),
                avatar: selected == region
                    ? const Icon(Icons.check_rounded, size: 17)
                    : null,
                labelStyle: TextStyle(
                  fontSize: tvMode ? 15 : 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.35,
                ),
                side: BorderSide(
                  color: selected == region
                      ? ZingColors.purpleBright
                      : Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
            ),
          )
          .toList(growable: false),
    ),
  );
}

class _SongSectionHeading extends StatelessWidget {
  const _SongSectionHeading({
    required this.songCount,
    required this.playableSongCount,
    required this.onPlayAll,
    required this.tvMode,
  });

  final int songCount;
  final int playableSongCount;
  final VoidCallback? onPlayAll;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    if (songCount == 0) {
      return const _ReleaseEmpty(
        key: ValueKey('release-songs-empty'),
        message: 'Chưa có bài hát mới trong khu vực này.',
      );
    }
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$songCount BÀI HÁT',
                key: const ValueKey('release-song-count'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: tvMode ? 14 : 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$playableSongCount bài có thể phát ngay',
                style: TextStyle(
                  fontSize: tvMode ? 20 : 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          key: const ValueKey('release-play-all'),
          onPressed: onPlayAll,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(tvMode ? 'PHÁT TẤT CẢ' : 'PHÁT'),
        ),
      ],
    );
  }
}

class _ReleaseAlbumGrid extends StatelessWidget {
  const _ReleaseAlbumGrid({
    required this.albums,
    required this.onTap,
    required this.onPlay,
    required this.onToggleSaved,
    required this.onShare,
    required this.onArtistTap,
    required this.savedCollectionIds,
    required this.quickPlayingCollectionId,
    required this.tvMode,
  });

  final List<ReleaseAlbum> albums;
  final ValueChanged<CatalogCollection> onTap;
  final ValueChanged<CatalogCollection>? onPlay;
  final ValueChanged<CatalogCollection>? onToggleSaved;
  final ValueChanged<CatalogCollection>? onShare;
  final ValueChanged<CatalogArtist>? onArtistTap;
  final Set<String> savedCollectionIds;
  final String? quickPlayingCollectionId;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columns = tvMode
          ? (width >= 1450 ? 6 : 5)
          : width >= 1180
          ? 6
          : width >= 880
          ? 5
          : width >= 620
          ? 4
          : 2;
      final spacing = tvMode ? 20.0 : 14.0;
      final itemWidth = (width - spacing * (columns - 1)) / columns;
      final showsArtistLinks =
          onArtistTap != null &&
          albums.any((album) => album.collection.artists.isNotEmpty);
      final itemHeight =
          itemWidth +
          (showsArtistLinks ? (tvMode ? 146 : 126) : (tvMode ? 112 : 94));
      return GridView.builder(
        key: const ValueKey('release-album-grid'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: albums.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          mainAxisExtent: itemHeight,
        ),
        itemBuilder: (context, index) {
          final album = albums[index];
          return _ReleaseAlbumCard(
            key: ValueKey('release-album-${album.collection.id}'),
            album: album,
            onTap: () => onTap(album.collection),
            onPlay: onPlay == null ? null : () => onPlay!(album.collection),
            onToggleSaved: onToggleSaved == null
                ? null
                : () => onToggleSaved!(album.collection),
            onShare: onShare == null || album.collection.externalUrl.isEmpty
                ? null
                : () => onShare!(album.collection),
            onArtistTap: onArtistTap,
            saved: savedCollectionIds.contains(album.collection.id),
            playing: quickPlayingCollectionId == album.collection.id,
            tvMode: tvMode,
          );
        },
      );
    },
  );
}

class _ReleaseAlbumCard extends StatefulWidget {
  const _ReleaseAlbumCard({
    super.key,
    required this.album,
    required this.onTap,
    required this.onPlay,
    required this.onToggleSaved,
    required this.onShare,
    required this.onArtistTap,
    required this.saved,
    required this.playing,
    required this.tvMode,
  });

  final ReleaseAlbum album;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onToggleSaved;
  final VoidCallback? onShare;
  final ValueChanged<CatalogArtist>? onArtistTap;
  final bool saved;
  final bool playing;
  final bool tvMode;

  @override
  State<_ReleaseAlbumCard> createState() => _ReleaseAlbumCardState();
}

class _ReleaseAlbumCardState extends State<_ReleaseAlbumCard> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = _focused || _hovered;
    final collection = widget.album.collection;
    final hasActionDeck =
        widget.onPlay != null ||
        widget.onToggleSaved != null ||
        widget.onShare != null;
    return Semantics(
      button: true,
      label: 'Mở album ${collection.title}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          scale: active ? 1.025 : 1,
          child: Card(
            margin: EdgeInsets.zero,
            elevation: active ? 8 : 0,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.tvMode ? 20 : 14),
              side: BorderSide(
                color: _focused
                    ? ZingColors.lime
                    : ZingColors.purpleBright.withValues(alpha: 0.16),
                width: _focused ? 3 : 1,
              ),
            ),
            child: InkWell(
              onTap: widget.onTap,
              onSecondaryTapDown: (details) async {
                await showCatalogCollectionContextMenu(
                  context: context,
                  globalPosition: details.globalPosition,
                  keyPrefix: 'release-album',
                  collection: collection,
                  saved: widget.saved,
                  playing: widget.playing,
                  onOpen: widget.onTap,
                  onPlay: widget.onPlay,
                  onToggleSaved: widget.onToggleSaved,
                  onShare: widget.onShare,
                );
              },
              onFocusChange: (value) {
                setState(() => _focused = value);
                if (value) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      Scrollable.ensureVisible(
                        context,
                        alignment: 0.32,
                        duration: const Duration(milliseconds: 180),
                      );
                    }
                  });
                }
              },
              child: Padding(
                padding: EdgeInsets.all(widget.tvMode ? 13 : 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) => Stack(
                        children: [
                          AlbumArt(
                            imageUrl: collection.thumbnail,
                            semanticLabel: 'Bìa album ${collection.title}',
                            size: constraints.maxWidth,
                            borderRadius: widget.tvMode ? 15 : 10,
                          ),
                          if (active)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: ColoredBox(
                                  color: const Color(0x770D0813),
                                ),
                              ),
                            ),
                          if (hasActionDeck)
                            Positioned(
                              left: widget.tvMode ? 10 : 2,
                              right: widget.tvMode ? 10 : 2,
                              bottom: widget.tvMode ? 10 : 6,
                              child: CatalogCollectionActionDeck(
                                keyPrefix: 'release-album',
                                collection: collection,
                                tvMode: widget.tvMode,
                                active: active,
                                saved: widget.saved,
                                playing: widget.playing,
                                onOpen: widget.onTap,
                                onPlay: widget.onPlay,
                                onToggleSaved: widget.onToggleSaved,
                                onShare: widget.onShare,
                              ),
                            )
                          else if (active)
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Container(
                                width: widget.tvMode ? 50 : 38,
                                height: widget.tvMode ? 50 : 38,
                                decoration: const BoxDecoration(
                                  color: ZingColors.purpleBright,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: widget.tvMode ? 13 : 10),
                    Text(
                      collection.title,
                      key: ValueKey('release-album-title-${collection.id}'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: widget.tvMode ? 18 : 14,
                        fontWeight: FontWeight.w800,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (collection.artists.isNotEmpty &&
                        widget.onArtistTap != null)
                      CatalogArtistLinks(
                        artists: collection.artists,
                        onArtistTap: widget.onArtistTap!,
                        keyPrefix: 'release-album-artist-${collection.id}',
                        tvMode: widget.tvMode,
                        touchLayout: MediaQuery.sizeOf(context).width < 720,
                      )
                    else
                      Text(
                        collection.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: widget.tvMode ? 14 : 12,
                        ),
                      ),
                    const Spacer(),
                    Text(
                      releaseAgeLabel(widget.album.releasedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ZingColors.coral,
                        fontSize: widget.tvMode ? 13 : 10,
                        fontWeight: FontWeight.w800,
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

class _ReleaseStaleNotice extends StatelessWidget {
  const _ReleaseStaleNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Material(
    color: ZingColors.coral.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(12),
    child: ListTile(
      leading: const Icon(Icons.cloud_off_rounded, color: ZingColors.coral),
      title: const Text('Đang hiển thị dữ liệu gần nhất.'),
      trailing: TextButton(onPressed: onRetry, child: const Text('THỬ LẠI')),
    ),
  );
}

class _ReleaseError extends StatelessWidget {
  const _ReleaseError({required this.onBack, required this.onRetry});

  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_rounded, color: ZingColors.coral, size: 42),
        const SizedBox(height: 12),
        const Text(
          'Chưa tải được Mới Phát Hành.',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('QUAY LẠI'),
            ),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('THỬ LẠI'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ReleaseEmpty extends StatelessWidget {
  const _ReleaseEmpty({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 18),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Icon(
          Icons.album_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 36,
        ),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

String releaseAgeLabel(DateTime? releasedAt, {DateTime? now}) {
  if (releasedAt == null) return 'Mới phát hành';
  final current = now ?? DateTime.now();
  final currentDay = DateTime(current.year, current.month, current.day);
  final releaseDay = DateTime(
    releasedAt.toLocal().year,
    releasedAt.toLocal().month,
    releasedAt.toLocal().day,
  );
  final days = currentDay.difference(releaseDay).inDays;
  if (days <= 0) return 'Hôm nay';
  if (days == 1) return 'Hôm qua';
  if (days < 7) return '$days ngày trước';
  if (days < 30) return '${days ~/ 7} tuần trước';
  final day = releaseDay.day.toString().padLeft(2, '0');
  final month = releaseDay.month.toString().padLeft(2, '0');
  return '$day/$month/${releaseDay.year}';
}
