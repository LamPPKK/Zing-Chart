import 'package:flutter/material.dart';

import '../models/catalog_hub.dart';
import '../models/catalog_search.dart';
import '../models/discovery_home.dart';
import '../theme/app_theme.dart';
import 'catalog_artist_links.dart';
import 'catalog_collection_action_deck.dart';

class CatalogHubHomeView extends StatelessWidget {
  const CatalogHubHomeView({
    super.key,
    required this.home,
    required this.loading,
    required this.errorMessage,
    required this.onBack,
    required this.onRetry,
    required this.onHubTap,
    required this.onCollectionTap,
    this.onCollectionPlay,
    this.onCollectionToggleSaved,
    this.onCollectionShare,
    this.onArtistTap,
    this.savedCollectionIds = const {},
    this.quickPlayingCollectionId,
    this.tvMode = false,
  });

  final CatalogHubHome home;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onBack;
  final VoidCallback onRetry;
  final ValueChanged<CatalogHub> onHubTap;
  final ValueChanged<CatalogCollection> onCollectionTap;
  final ValueChanged<CatalogCollection>? onCollectionPlay;
  final ValueChanged<CatalogCollection>? onCollectionToggleSaved;
  final ValueChanged<CatalogCollection>? onCollectionShare;
  final ValueChanged<CatalogArtist>? onArtistTap;
  final Set<String> savedCollectionIds;
  final String? quickPlayingCollectionId;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final horizontal = tvMode ? 32.0 : 20.0;
    if (loading && home.isEmpty) {
      return _CatalogLoading(
        key: const ValueKey('hub-home-loading'),
        horizontal: horizontal,
        title: 'Đang tải Chủ đề & Thể loại…',
      );
    }
    if (home.isEmpty) {
      return _CatalogError(
        key: const ValueKey('hub-home-error'),
        horizontal: horizontal,
        title: 'Chưa tải được Chủ đề & Thể loại.',
        onBack: onBack,
        onRetry: onRetry,
      );
    }
    return Padding(
      key: const ValueKey('hub-home'),
      padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, tvMode ? 52 : 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CatalogHeading(
            icon: Icons.grid_view_rounded,
            eyebrow: 'KHÁM PHÁ THEO GU CỦA BẠN',
            title: 'Chủ đề & Thể loại',
            description:
                'Quốc gia, tâm trạng, hoạt động và những playlist đang nổi bật.',
            onBack: onBack,
            tvMode: tvMode,
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            _StaleNotice(onRetry: onRetry),
          ],
          if (home.featured.isNotEmpty) ...[
            SizedBox(height: tvMode ? 34 : 26),
            _HubRail(
              title: 'Nổi bật',
              hubs: home.featured,
              onTap: onHubTap,
              large: true,
              tvMode: tvMode,
            ),
          ],
          if (home.nations.isNotEmpty) ...[
            SizedBox(height: tvMode ? 38 : 30),
            _HubRail(
              title: 'Quốc gia',
              hubs: home.nations,
              onTap: onHubTap,
              tvMode: tvMode,
            ),
          ],
          if (home.topics.isNotEmpty) ...[
            SizedBox(height: tvMode ? 38 : 30),
            _HubRail(
              title: 'Tâm trạng và hoạt động',
              hubs: home.topics,
              onTap: onHubTap,
              tvMode: tvMode,
            ),
          ],
          for (final genre in home.genres) ...[
            SizedBox(height: tvMode ? 38 : 30),
            _GenrePreview(
              hub: genre,
              onHubTap: () => onHubTap(genre),
              onCollectionTap: onCollectionTap,
              onCollectionPlay: onCollectionPlay,
              onCollectionToggleSaved: onCollectionToggleSaved,
              onCollectionShare: onCollectionShare,
              onArtistTap: onArtistTap,
              savedCollectionIds: savedCollectionIds,
              quickPlayingCollectionId: quickPlayingCollectionId,
              tvMode: tvMode,
            ),
          ],
        ],
      ),
    );
  }
}

class CatalogHubDetailView extends StatelessWidget {
  const CatalogHubDetailView({
    super.key,
    required this.detail,
    required this.loading,
    required this.errorMessage,
    required this.onBack,
    required this.onRetry,
    required this.onCollectionTap,
    this.onCollectionPlay,
    this.onCollectionToggleSaved,
    this.onCollectionShare,
    this.onArtistTap,
    this.savedCollectionIds = const {},
    this.quickPlayingCollectionId,
    this.tvMode = false,
  });

  final CatalogHubDetail? detail;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onBack;
  final VoidCallback onRetry;
  final ValueChanged<CatalogCollection> onCollectionTap;
  final ValueChanged<CatalogCollection>? onCollectionPlay;
  final ValueChanged<CatalogCollection>? onCollectionToggleSaved;
  final ValueChanged<CatalogCollection>? onCollectionShare;
  final ValueChanged<CatalogArtist>? onArtistTap;
  final Set<String> savedCollectionIds;
  final String? quickPlayingCollectionId;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final horizontal = tvMode ? 32.0 : 20.0;
    final value = detail;
    if (loading && value == null) {
      return _CatalogLoading(
        key: const ValueKey('hub-detail-loading'),
        horizontal: horizontal,
        title: 'Đang mở chủ đề…',
      );
    }
    if (value == null) {
      return _CatalogError(
        key: const ValueKey('hub-detail-error'),
        horizontal: horizontal,
        title: 'Chưa tải được nội dung chủ đề.',
        onBack: onBack,
        onRetry: onRetry,
      );
    }
    return Padding(
      key: const ValueKey('hub-detail'),
      padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, tvMode ? 52 : 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HubDetailHero(hub: value.hub, onBack: onBack, tvMode: tvMode),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            _StaleNotice(onRetry: onRetry),
          ] else if (loading) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(minHeight: 3),
          ],
          for (final section in value.sections) ...[
            SizedBox(height: tvMode ? 38 : 30),
            _CollectionSectionRail(
              key: ValueKey('hub-section-${section.id}'),
              section: section,
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
        ],
      ),
    );
  }
}

class Top100CatalogView extends StatelessWidget {
  const Top100CatalogView({
    super.key,
    required this.catalog,
    required this.loading,
    required this.errorMessage,
    required this.onBack,
    required this.onRetry,
    required this.onCollectionTap,
    this.onCollectionPlay,
    this.onCollectionToggleSaved,
    this.onCollectionShare,
    this.onArtistTap,
    this.savedCollectionIds = const {},
    this.quickPlayingCollectionId,
    this.tvMode = false,
  });

  final Top100Catalog catalog;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onBack;
  final VoidCallback onRetry;
  final ValueChanged<CatalogCollection> onCollectionTap;
  final ValueChanged<CatalogCollection>? onCollectionPlay;
  final ValueChanged<CatalogCollection>? onCollectionToggleSaved;
  final ValueChanged<CatalogCollection>? onCollectionShare;
  final ValueChanged<CatalogArtist>? onArtistTap;
  final Set<String> savedCollectionIds;
  final String? quickPlayingCollectionId;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final horizontal = tvMode ? 32.0 : 20.0;
    if (loading && catalog.isEmpty) {
      return _CatalogLoading(
        key: const ValueKey('top-100-loading'),
        horizontal: horizontal,
        title: 'Đang tải Top 100…',
      );
    }
    if (catalog.isEmpty) {
      return _CatalogError(
        key: const ValueKey('top-100-error'),
        horizontal: horizontal,
        title: 'Chưa tải được Top 100.',
        onBack: onBack,
        onRetry: onRetry,
      );
    }
    return Padding(
      key: const ValueKey('top-100-catalog'),
      padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, tvMode ? 52 : 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CatalogHeading(
            icon: Icons.star_rounded,
            eyebrow: 'CẬP NHẬT TỪ ZING MP3',
            title: 'Top 100',
            description:
                'Những playlist được nghe nhiều theo Việt Nam, Châu Á, Âu Mỹ và Hòa Tấu.',
            onBack: onBack,
            tvMode: tvMode,
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            _StaleNotice(onRetry: onRetry),
          ] else if (loading) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(minHeight: 3),
          ],
          for (final section in catalog.sections) ...[
            SizedBox(height: tvMode ? 38 : 30),
            _CollectionSectionRail(
              key: ValueKey('top-100-section-${section.id}'),
              section: section,
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
        ],
      ),
    );
  }
}

class _CatalogHeading extends StatelessWidget {
  const _CatalogHeading({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.onBack,
    required this.tvMode,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;
  final VoidCallback onBack;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(tvMode ? 28 : 20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          ZingColors.purpleBright.withValues(alpha: 0.34),
          ZingColors.coral.withValues(alpha: 0.12),
        ],
      ),
      borderRadius: BorderRadius.circular(tvMode ? 24 : 18),
      border: Border.all(color: ZingColors.purpleBright.withValues(alpha: 0.4)),
    ),
    child: Row(
      children: [
        IconButton.filledTonal(
          key: const ValueKey('catalog-hub-back'),
          tooltip: 'Quay lại Khám phá',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        SizedBox(width: tvMode ? 22 : 16),
        Container(
          width: tvMode ? 78 : 58,
          height: tvMode ? 78 : 58,
          decoration: const BoxDecoration(
            color: ZingColors.purpleBright,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: tvMode ? 38 : 28),
        ),
        SizedBox(width: tvMode ? 22 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: TextStyle(
                  color: ZingColors.lime,
                  fontSize: tvMode ? 14 : 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: TextStyle(
                  fontSize: tvMode ? 34 : 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
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

class _HubDetailHero extends StatelessWidget {
  const _HubDetailHero({
    required this.hub,
    required this.onBack,
    required this.tvMode,
  });

  final CatalogHub hub;
  final VoidCallback onBack;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: tvMode ? 300 : 230,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(tvMode ? 24 : 18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _NetworkArtwork(url: hub.image, icon: Icons.category_rounded),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x330D0713), Color(0xF013091B)],
              ),
            ),
          ),
          Positioned(
            left: tvMode ? 28 : 20,
            top: tvMode ? 24 : 18,
            child: IconButton.filledTonal(
              key: const ValueKey('hub-detail-back'),
              tooltip: 'Quay lại Chủ đề & Thể loại',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          Positioned(
            left: tvMode ? 30 : 22,
            right: tvMode ? 30 : 22,
            bottom: tvMode ? 28 : 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CHỦ ĐỀ',
                  style: TextStyle(
                    color: ZingColors.lime,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  hub.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: tvMode ? 42 : 31,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                if (hub.description.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    hub.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: tvMode ? 15 : 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _HubRail extends StatelessWidget {
  const _HubRail({
    required this.title,
    required this.hubs,
    required this.onTap,
    required this.tvMode,
    this.large = false,
  });

  final String title;
  final List<CatalogHub> hubs;
  final ValueChanged<CatalogHub> onTap;
  final bool tvMode;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final width = large ? (tvMode ? 440.0 : 320.0) : (tvMode ? 260.0 : 190.0);
    final height = large ? (tvMode ? 220.0 : 160.0) : (tvMode ? 150.0 : 112.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: title, tvMode: tvMode),
        SizedBox(height: tvMode ? 16 : 12),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: hubs.length,
            separatorBuilder: (_, __) => SizedBox(width: tvMode ? 18 : 14),
            itemBuilder: (context, index) {
              final hub = hubs[index];
              return SizedBox(
                width: width,
                child: _HubCard(
                  key: ValueKey('catalog-hub-${hub.id}'),
                  hub: hub,
                  onTap: () => onTap(hub),
                  tvMode: tvMode,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GenrePreview extends StatelessWidget {
  const _GenrePreview({
    required this.hub,
    required this.onHubTap,
    required this.onCollectionTap,
    required this.onCollectionPlay,
    required this.onCollectionToggleSaved,
    required this.onCollectionShare,
    required this.onArtistTap,
    required this.savedCollectionIds,
    required this.quickPlayingCollectionId,
    required this.tvMode,
  });

  final CatalogHub hub;
  final VoidCallback onHubTap;
  final ValueChanged<CatalogCollection> onCollectionTap;
  final ValueChanged<CatalogCollection>? onCollectionPlay;
  final ValueChanged<CatalogCollection>? onCollectionToggleSaved;
  final ValueChanged<CatalogCollection>? onCollectionShare;
  final ValueChanged<CatalogArtist>? onArtistTap;
  final Set<String> savedCollectionIds;
  final String? quickPlayingCollectionId;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    if (hub.collections.isEmpty) {
      return _HubRail(
        title: hub.title,
        hubs: [hub],
        onTap: (_) => onHubTap(),
        tvMode: tvMode,
      );
    }
    return _CollectionSectionRail(
      section: DiscoverySection(
        id: hub.id,
        title: hub.title,
        collections: hub.collections,
      ),
      onTap: onCollectionTap,
      onPlay: onCollectionPlay,
      onToggleSaved: onCollectionToggleSaved,
      onShare: onCollectionShare,
      onArtistTap: onArtistTap,
      savedCollectionIds: savedCollectionIds,
      quickPlayingCollectionId: quickPlayingCollectionId,
      onOpenAll: onHubTap,
      tvMode: tvMode,
    );
  }
}

class _CollectionSectionRail extends StatelessWidget {
  const _CollectionSectionRail({
    super.key,
    required this.section,
    required this.onTap,
    required this.tvMode,
    this.onPlay,
    this.onToggleSaved,
    this.onShare,
    this.onArtistTap,
    this.savedCollectionIds = const {},
    this.quickPlayingCollectionId,
    this.onOpenAll,
  });

  final DiscoverySection section;
  final ValueChanged<CatalogCollection> onTap;
  final ValueChanged<CatalogCollection>? onPlay;
  final ValueChanged<CatalogCollection>? onToggleSaved;
  final ValueChanged<CatalogCollection>? onShare;
  final ValueChanged<CatalogArtist>? onArtistTap;
  final Set<String> savedCollectionIds;
  final String? quickPlayingCollectionId;
  final VoidCallback? onOpenAll;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final width = tvMode ? 220.0 : 158.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _SectionTitle(title: section.title, tvMode: tvMode),
            ),
            if (onOpenAll != null)
              TextButton.icon(
                onPressed: onOpenAll,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('TẤT CẢ'),
              ),
          ],
        ),
        SizedBox(height: tvMode ? 16 : 12),
        SizedBox(
          height: width + (tvMode ? 95 : 84),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: section.collections.length,
            separatorBuilder: (_, __) => SizedBox(width: tvMode ? 18 : 14),
            itemBuilder: (context, index) {
              final item = section.collections[index];
              return SizedBox(
                width: width,
                child: _CollectionCard(
                  key: ValueKey('hub-collection-${item.collection.id}'),
                  item: item,
                  onTap: () => onTap(item.collection),
                  onPlay: onPlay == null
                      ? null
                      : () => onPlay!(item.collection),
                  onToggleSaved: onToggleSaved == null
                      ? null
                      : () => onToggleSaved!(item.collection),
                  onShare:
                      onShare == null || item.collection.externalUrl.isEmpty
                      ? null
                      : () => onShare!(item.collection),
                  onArtistTap: onArtistTap,
                  saved: savedCollectionIds.contains(item.collection.id),
                  playing: quickPlayingCollectionId == item.collection.id,
                  tvMode: tvMode,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.tvMode});

  final String title;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Text(
    title,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: tvMode ? 27 : 21,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.45,
    ),
  );
}

class _HubCard extends StatefulWidget {
  const _HubCard({
    super.key,
    required this.hub,
    required this.onTap,
    required this.tvMode,
  });

  final CatalogHub hub;
  final VoidCallback onTap;
  final bool tvMode;

  @override
  State<_HubCard> createState() => _HubCardState();
}

class _HubCardState extends State<_HubCard> {
  bool _active = false;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Mở chủ đề ${widget.hub.title}',
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.tvMode ? 20 : 15),
        border: Border.all(
          color: _active ? ZingColors.lime : Colors.transparent,
          width: _active ? 3 : 0,
        ),
        boxShadow: _active
            ? [
                BoxShadow(
                  color: ZingColors.purple.withValues(alpha: 0.32),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(widget.tvMode ? 17 : 13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          mouseCursor: SystemMouseCursors.click,
          onHover: (value) => setState(() => _active = value),
          onFocusChange: (value) {
            setState(() => _active = value);
            if (value) {
              Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 220),
                alignment: 0.15,
              );
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              _NetworkArtwork(url: widget.hub.image, icon: Icons.category),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xE513091B)],
                  ),
                ),
              ),
              Positioned(
                left: widget.tvMode ? 18 : 13,
                right: widget.tvMode ? 18 : 13,
                bottom: widget.tvMode ? 16 : 11,
                child: Text(
                  widget.hub.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.tvMode ? 20 : 15,
                    fontWeight: FontWeight.w900,
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

class _CollectionCard extends StatefulWidget {
  const _CollectionCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onPlay,
    required this.onToggleSaved,
    required this.onShare,
    required this.onArtistTap,
    required this.saved,
    required this.playing,
    required this.tvMode,
  });

  final DiscoveryCollection item;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onToggleSaved;
  final VoidCallback? onShare;
  final ValueChanged<CatalogArtist>? onArtistTap;
  final bool saved;
  final bool playing;
  final bool tvMode;

  @override
  State<_CollectionCard> createState() => _CollectionCardState();
}

class _CollectionCardState extends State<_CollectionCard> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final collection = widget.item.collection;
    final hasActionDeck =
        widget.onPlay != null ||
        widget.onToggleSaved != null ||
        widget.onShare != null;
    return Semantics(
      button: true,
      label: 'Mở ${collection.title}',
      child: InkWell(
        onTap: widget.onTap,
        onSecondaryTapDown: (details) async {
          await showCatalogCollectionContextMenu(
            context: context,
            globalPosition: details.globalPosition,
            keyPrefix: 'hub-collection',
            collection: collection,
            saved: widget.saved,
            playing: widget.playing,
            onOpen: widget.onTap,
            onPlay: widget.onPlay,
            onToggleSaved: widget.onToggleSaved,
            onShare: widget.onShare,
          );
        },
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(widget.tvMode ? 18 : 14),
        onHover: (value) => setState(() => _active = value),
        onFocusChange: (value) {
          setState(() => _active = value);
          if (value) {
            Scrollable.ensureVisible(
              context,
              duration: const Duration(milliseconds: 220),
              alignment: 0.15,
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
                      widget.tvMode ? 17 : 13,
                    ),
                    border: Border.all(
                      color: _active ? ZingColors.lime : Colors.transparent,
                      width: _active ? 3 : 0,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _NetworkArtwork(
                        url: collection.thumbnail,
                        icon: collection.kind == CatalogCollectionKind.album
                            ? Icons.album_rounded
                            : Icons.queue_music_rounded,
                      ),
                      if (_active) const ColoredBox(color: Color(0x880D0813)),
                      if (hasActionDeck)
                        Positioned(
                          left: widget.tvMode ? 12 : 2,
                          right: widget.tvMode ? 12 : 2,
                          bottom: widget.tvMode ? 12 : 8,
                          child: CatalogCollectionActionDeck(
                            keyPrefix: 'hub-collection',
                            collection: collection,
                            tvMode: widget.tvMode,
                            active: _active,
                            saved: widget.saved,
                            playing: widget.playing,
                            onOpen: widget.onTap,
                            onPlay: widget.onPlay,
                            onToggleSaved: widget.onToggleSaved,
                            onShare: widget.onShare,
                          ),
                        ),
                      if (_active && !hasActionDeck)
                        const Center(
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: widget.tvMode ? 10 : 8),
              Text(
                collection.title,
                key: ValueKey('hub-collection-title-${collection.id}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: widget.tvMode ? 17 : 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              if (collection.artists.isNotEmpty && widget.onArtistTap != null)
                CatalogArtistLinks(
                  artists: collection.artists,
                  onArtistTap: widget.onArtistTap!,
                  keyPrefix: 'hub-collection-artist-${collection.id}',
                  tvMode: widget.tvMode,
                  touchLayout: MediaQuery.sizeOf(context).width < 720,
                )
              else
                Text(
                  widget.item.description.isNotEmpty
                      ? widget.item.description
                      : collection.artist,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: widget.tvMode ? 13 : 11,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkArtwork extends StatelessWidget {
  const _NetworkArtwork({required this.url, required this.icon});

  final String url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(child: Icon(icon, color: ZingColors.coral, size: 34)),
    );
    if (url.isEmpty) return fallback;
    return Image.network(
      url,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _CatalogLoading extends StatelessWidget {
  const _CatalogLoading({
    super.key,
    required this.horizontal,
    required this.title,
  });

  final double horizontal;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LinearProgressIndicator(minHeight: 4),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({
    super.key,
    required this.horizontal,
    required this.title,
    required this.onBack,
    required this.onRetry,
  });

  final double horizontal;
  final String title;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 30),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Quay lại',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}

class _StaleNotice extends StatelessWidget {
  const _StaleNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: ZingColors.coral.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.cloud_off_rounded, size: 18, color: ZingColors.coral),
        const SizedBox(width: 9),
        const Expanded(
          child: Text(
            'Đang hiển thị nội dung gần nhất.',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Cập nhật')),
      ],
    ),
  );
}
