import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/catalog_search.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';
import 'catalog_artist_rail.dart';
import 'catalog_collection_action_deck.dart';

/// The metadata and recommendation area shown after a collection's track list.
///
/// Its hierarchy mirrors the public Zing MP3 album page while keeping every
/// navigation target inside the validated first-party catalog.
class CollectionDetailCatalog extends StatelessWidget {
  const CollectionDetailCatalog({
    super.key,
    required this.detail,
    required this.onCollectionTap,
    required this.onArtistTap,
    this.onArtistToggleFollow,
    this.followedArtistIds = const {},
    this.onCollectionPlay,
    this.onCollectionToggleSaved,
    this.onCollectionShare,
    this.savedCollectionIds = const {},
    this.quickPlayingCollectionId,
    this.tvMode = false,
  });

  final CatalogCollectionDetail detail;
  final ValueChanged<CatalogCollection> onCollectionTap;
  final ValueChanged<CatalogArtist> onArtistTap;
  final ValueChanged<CatalogArtist>? onArtistToggleFollow;
  final Set<String> followedArtistIds;
  final ValueChanged<CatalogCollection>? onCollectionPlay;
  final ValueChanged<CatalogCollection>? onCollectionToggleSaved;
  final ValueChanged<CatalogCollection>? onCollectionShare;
  final Set<String> savedCollectionIds;
  final String? quickPlayingCollectionId;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final participantArtists = detail.participatingArtists
        .take(20)
        .toList(growable: false);
    final information = <_InformationItem>[
      _InformationItem(label: 'SỐ BÀI HÁT', value: '${detail.songs.length}'),
      if (detail.releasedAt case final releasedAt?)
        _InformationItem(label: 'NGÀY PHÁT HÀNH', value: _dateLabel(releasedAt))
      else if (detail.year.trim().isNotEmpty)
        _InformationItem(label: 'NĂM PHÁT HÀNH', value: detail.year.trim()),
      if (detail.distributor.trim().isNotEmpty)
        _InformationItem(
          label: 'CUNG CẤP BỞI',
          value: detail.distributor.trim(),
        ),
      if (detail.genres.isNotEmpty)
        _InformationItem(
          label: 'THỂ LOẠI',
          value: detail.genres.take(3).join(' · '),
        ),
    ];
    return Padding(
      key: const ValueKey('collection-detail-catalog'),
      padding: EdgeInsets.fromLTRB(
        tvMode ? 32 : 20,
        tvMode ? 24 : 14,
        tvMode ? 32 : 20,
        tvMode ? 52 : 34,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(title: 'THÔNG TIN', tvMode: tvMode),
          SizedBox(height: tvMode ? 18 : 12),
          _InformationGrid(items: information, tvMode: tvMode),
          if (participantArtists.isNotEmpty) ...[
            SizedBox(height: tvMode ? 42 : 32),
            CatalogArtistRail(
              key: const ValueKey('collection-participants'),
              title: 'NGHỆ SĨ THAM GIA',
              artists: participantArtists,
              onArtistTap: onArtistTap,
              onToggleFollow: onArtistToggleFollow,
              followedArtistIds: followedArtistIds,
              keyPrefix: 'collection-participant',
              tvMode: tvMode,
            ),
          ],
          for (final section in detail.sections) ...[
            SizedBox(height: tvMode ? 42 : 32),
            _RelatedCollectionSection(
              key: ValueKey('collection-related-section-${section.id}'),
              section: section,
              onOpen: onCollectionTap,
              onPlay: onCollectionPlay,
              onToggleSaved: onCollectionToggleSaved,
              onShare: onCollectionShare,
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.tvMode});

  final String title;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Text(
    title,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: tvMode ? 27 : 20,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.35,
    ),
  );
}

class _InformationItem {
  const _InformationItem({required this.label, required this.value});

  final String label;
  final String value;
}

class _InformationGrid extends StatelessWidget {
  const _InformationGrid({required this.items, required this.tvMode});

  final List<_InformationItem> items;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 920 ? 4 : 2;
      final gap = tvMode ? 24.0 : 18.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: tvMode ? 10 : 6,
        children: [
          for (final item in items)
            SizedBox(
              width: width,
              child: Semantics(
                label: '${item.label}: ${item.value}',
                child: ExcludeSemantics(
                  child: Container(
                    constraints: BoxConstraints(minHeight: tvMode ? 72 : 56),
                    padding: EdgeInsets.fromLTRB(
                      tvMode ? 4 : 2,
                      tvMode ? 13 : 10,
                      tvMode ? 4 : 2,
                      tvMode ? 12 : 9,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: tvMode ? 12 : 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.05,
                          ),
                        ),
                        SizedBox(height: tvMode ? 8 : 6),
                        Text(
                          item.value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: tvMode ? 18 : 14,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _RelatedCollectionSection extends StatefulWidget {
  const _RelatedCollectionSection({
    super.key,
    required this.section,
    required this.onOpen,
    required this.onPlay,
    required this.onToggleSaved,
    required this.onShare,
    required this.savedCollectionIds,
    required this.quickPlayingCollectionId,
    required this.tvMode,
  });

  final CatalogCollectionSection section;
  final ValueChanged<CatalogCollection> onOpen;
  final ValueChanged<CatalogCollection>? onPlay;
  final ValueChanged<CatalogCollection>? onToggleSaved;
  final ValueChanged<CatalogCollection>? onShare;
  final Set<String> savedCollectionIds;
  final String? quickPlayingCollectionId;
  final bool tvMode;

  @override
  State<_RelatedCollectionSection> createState() =>
      _RelatedCollectionSectionState();
}

class _RelatedCollectionSectionState extends State<_RelatedCollectionSection> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollBack = false;
  bool _canScrollForward = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncScrollActions);
  }

  @override
  void didUpdateWidget(covariant _RelatedCollectionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameCollectionOrder(
      oldWidget.section.collections,
      widget.section.collections,
    )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.minScrollExtent);
        _syncScrollActions();
      });
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_syncScrollActions)
      ..dispose();
    super.dispose();
  }

  void _scheduleScrollActionSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncScrollActions();
    });
  }

  void _syncScrollActions() {
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
      return;
    }
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = !widget.tvMode && constraints.maxWidth < 620;
      final cardWidth = widget.tvMode
          ? 226.0
          : compact
          ? 156.0
          : 184.0;
      final gap = widget.tvMode ? 18.0 : 14.0;
      final itemCount = widget.section.collections.length;
      final contentWidth = itemCount == 0
          ? 0.0
          : itemCount * cardWidth + (itemCount - 1) * gap;
      final overflows = contentWidth > constraints.maxWidth + 0.5;
      final desktopPointerPlatform = switch (Theme.of(context).platform) {
        TargetPlatform.macOS ||
        TargetPlatform.windows ||
        TargetPlatform.linux => true,
        _ => false,
      };
      final showScrollActions =
          overflows && (widget.tvMode || !compact || desktopPointerPlatform);
      _scheduleScrollActionSync();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SectionHeading(
                  title: widget.section.title,
                  tvMode: widget.tvMode,
                ),
              ),
              if (showScrollActions) ...[
                _RailScrollButton(
                  key: ValueKey('collection-related-prev-${widget.section.id}'),
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Xem danh sách trước',
                  tvMode: widget.tvMode,
                  onPressed: _canScrollBack ? () => _scrollBy(-0.82) : null,
                ),
                SizedBox(width: widget.tvMode ? 10 : 7),
                _RailScrollButton(
                  key: ValueKey('collection-related-next-${widget.section.id}'),
                  icon: Icons.chevron_right_rounded,
                  tooltip: 'Xem danh sách tiếp theo',
                  tvMode: widget.tvMode,
                  onPressed: _canScrollForward ? () => _scrollBy(0.82) : null,
                ),
              ],
            ],
          ),
          SizedBox(height: widget.tvMode ? 18 : 14),
          SizedBox(
            height: widget.tvMode
                ? 320
                : compact
                ? 230
                : 260,
            child: ListView.separated(
              key: ValueKey('collection-related-list-${widget.section.id}'),
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: itemCount,
              separatorBuilder: (_, __) => SizedBox(width: gap),
              itemBuilder: (context, index) {
                final collection = widget.section.collections[index];
                return SizedBox(
                  width: cardWidth,
                  child: _CollectionCard(
                    key: ValueKey('collection-related-${collection.id}'),
                    collection: collection,
                    onOpen: () => widget.onOpen(collection),
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
                    persistentActions: compact || widget.tvMode,
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

class _RailScrollButton extends StatelessWidget {
  const _RailScrollButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.tvMode,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool tvMode;
  final VoidCallback? onPressed;

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

class _CollectionCard extends StatefulWidget {
  const _CollectionCard({
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
  State<_CollectionCard> createState() => _CollectionCardState();
}

class _CollectionCardState extends State<_CollectionCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _focused;
    final actionsVisible = widget.persistentActions || active;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final cardDuration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 160);
    final overlayDuration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 140);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      button: true,
      onTap: widget.onOpen,
      label: 'Mở ${widget.collection.kindLabel} ${widget.collection.title}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          if (mounted && !_hovered) setState(() => _hovered = true);
        },
        onExit: (_) {
          if (mounted && _hovered) setState(() => _hovered = false);
        },
        child: FocusableActionDetector(
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
          onShowFocusHighlight: (value) {
            if (!mounted) return;
            setState(() => _focused = value);
            if (value) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Scrollable.ensureVisible(
                    context,
                    alignment: 0.5,
                    duration: reducedMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                  );
                }
              });
            }
          },
          child: AnimatedContainer(
            duration: cardDuration,
            decoration: BoxDecoration(
              color: active
                  ? ZingColors.purpleBright.withValues(alpha: 0.13)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(widget.tvMode ? 20 : 16),
              border: Border.all(
                color: _focused
                    ? ZingColors.lime
                    : _hovered
                    ? ZingColors.purpleBright.withValues(alpha: 0.74)
                    : Colors.transparent,
                width: _focused
                    ? 3
                    : _hovered
                    ? 2
                    : 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(widget.tvMode ? 20 : 16),
              canRequestFocus: false,
              excludeFromSemantics: true,
              onTap: widget.onOpen,
              onSecondaryTapDown: (details) => showCatalogCollectionContextMenu(
                context: context,
                globalPosition: details.globalPosition,
                keyPrefix: 'collection-related',
                collection: widget.collection,
                saved: widget.saved,
                playing: widget.playing,
                onOpen: widget.onOpen,
                onPlay: widget.onPlay,
                onToggleSaved: widget.onToggleSaved,
                onShare: widget.onShare,
              ),
              child: Padding(
                padding: EdgeInsets.all(
                  widget.tvMode
                      ? 10
                      : widget.persistentActions
                      ? 4
                      : 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) => Stack(
                        alignment: Alignment.center,
                        children: [
                          AlbumArt(
                            imageUrl: widget.collection.thumbnail,
                            semanticLabel: 'Ảnh ${widget.collection.title}',
                            size: constraints.maxWidth,
                            borderRadius: widget.tvMode ? 16 : 13,
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: AnimatedContainer(
                                duration: overlayDuration,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    widget.tvMode ? 16 : 13,
                                  ),
                                  color: active
                                      ? Colors.black.withValues(alpha: 0.22)
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: widget.tvMode ? 12 : 2,
                            right: widget.tvMode ? 12 : 2,
                            bottom: widget.tvMode ? 12 : 9,
                            child: IgnorePointer(
                              ignoring: !actionsVisible,
                              child: AnimatedOpacity(
                                key: ValueKey(
                                  'collection-related-actions-${widget.collection.id}',
                                ),
                                duration: overlayDuration,
                                opacity: actionsVisible ? 1 : 0,
                                child: CatalogCollectionActionDeck(
                                  keyPrefix: 'collection-related',
                                  collection: widget.collection,
                                  tvMode: widget.tvMode,
                                  touchMode:
                                      widget.persistentActions &&
                                      !widget.tvMode,
                                  active: active,
                                  saved: widget.saved,
                                  playing: widget.playing,
                                  onOpen: widget.onOpen,
                                  onPlay: widget.onPlay,
                                  onToggleSaved: widget.onToggleSaved,
                                  onShare: widget.onShare,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: widget.tvMode ? 13 : 10),
                    Text(
                      widget.collection.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: widget.tvMode ? 17 : 14,
                        height: 1.16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.collection.artist.isEmpty
                          ? widget.collection.kindLabel
                          : widget.collection.artist,
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
            ),
          ),
        ),
      ),
    );
  }
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}
