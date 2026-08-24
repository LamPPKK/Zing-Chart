import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/catalog_search.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';

/// The metadata and recommendation area shown after a collection's track list.
///
/// Its hierarchy mirrors the public Zing MP3 album page while keeping every
/// navigation target inside the validated first-party catalog.
class CollectionDetailCatalog extends StatelessWidget {
  const CollectionDetailCatalog({
    super.key,
    required this.detail,
    required this.onCollectionTap,
    this.tvMode = false,
  });

  final CatalogCollectionDetail detail;
  final ValueChanged<CatalogCollection> onCollectionTap;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final information = <_InformationItem>[
      _InformationItem(
        icon: Icons.queue_music_rounded,
        label: 'SỐ BÀI HÁT',
        value: '${detail.songs.length}',
      ),
      if (detail.releasedAt case final releasedAt?)
        _InformationItem(
          icon: Icons.calendar_today_rounded,
          label: 'NGÀY PHÁT HÀNH',
          value: _dateLabel(releasedAt),
        )
      else if (detail.year.trim().isNotEmpty)
        _InformationItem(
          icon: Icons.calendar_today_rounded,
          label: 'NĂM PHÁT HÀNH',
          value: detail.year.trim(),
        ),
      if (detail.distributor.trim().isNotEmpty)
        _InformationItem(
          icon: Icons.apartment_rounded,
          label: 'CUNG CẤP BỞI',
          value: detail.distributor.trim(),
        ),
      if (detail.genres.isNotEmpty)
        _InformationItem(
          icon: Icons.sell_rounded,
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
          for (final section in detail.sections) ...[
            SizedBox(height: tvMode ? 42 : 32),
            _SectionHeading(title: section.title, tvMode: tvMode),
            SizedBox(height: tvMode ? 18 : 14),
            _CollectionRail(
              key: ValueKey('collection-related-section-${section.id}'),
              collections: section.collections,
              onTap: onCollectionTap,
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
  const _InformationItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
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
      final columns = constraints.maxWidth >= 980
          ? 4
          : constraints.maxWidth >= 560
          ? 3
          : 2;
      final gap = tvMode ? 16.0 : 12.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final item in items)
            SizedBox(
              width: width,
              child: Semantics(
                label: '${item.label}: ${item.value}',
                child: ExcludeSemantics(
                  child: Container(
                    constraints: BoxConstraints(minHeight: tvMode ? 116 : 94),
                    padding: EdgeInsets.all(tvMode ? 18 : 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.56),
                      borderRadius: BorderRadius.circular(tvMode ? 20 : 16),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.42),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: tvMode ? 44 : 36,
                          height: tvMode ? 44 : 36,
                          decoration: BoxDecoration(
                            color: ZingColors.purpleBright.withValues(
                              alpha: 0.16,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            item.icon,
                            size: tvMode ? 25 : 20,
                            color: ZingColors.purpleBright,
                          ),
                        ),
                        SizedBox(width: tvMode ? 14 : 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                              const SizedBox(height: 7),
                              Text(
                                item.value,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontSize: tvMode ? 18 : 14,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
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

class _CollectionRail extends StatelessWidget {
  const _CollectionRail({
    super.key,
    required this.collections,
    required this.onTap,
    required this.tvMode,
  });

  final List<CatalogCollection> collections;
  final ValueChanged<CatalogCollection> onTap;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;
    final cardWidth = tvMode
        ? 226.0
        : compact
        ? 156.0
        : 184.0;
    final height = tvMode
        ? 320.0
        : compact
        ? 230.0
        : 260.0;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: collections.length,
        separatorBuilder: (_, __) => SizedBox(width: tvMode ? 18 : 14),
        itemBuilder: (context, index) {
          final collection = collections[index];
          return SizedBox(
            width: cardWidth,
            child: _CollectionCard(
              key: ValueKey('collection-related-${collection.id}'),
              collection: collection,
              onTap: () => onTap(collection),
              tvMode: tvMode,
            ),
          );
        },
      ),
    );
  }
}

class _CollectionCard extends StatefulWidget {
  const _CollectionCard({
    super.key,
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

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _focused;
    return Semantics(
      button: true,
      onTap: widget.onTap,
      label: 'Mở ${widget.collection.kindLabel} ${widget.collection.title}',
      child: ExcludeSemantics(
        child: FocusableActionDetector(
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
          onShowHoverHighlight: (value) {
            if (mounted) setState(() => _hovered = value);
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
                    duration: const Duration(milliseconds: 180),
                  );
                }
              });
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: active
                  ? ZingColors.purpleBright.withValues(alpha: 0.13)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(widget.tvMode ? 20 : 16),
              border: Border.all(
                color: active
                    ? ZingColors.purpleBright.withValues(alpha: 0.74)
                    : Colors.transparent,
                width: active ? 2 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(widget.tvMode ? 20 : 16),
              onTap: widget.onTap,
              child: Padding(
                padding: EdgeInsets.all(widget.tvMode ? 10 : 8),
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
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 140),
                            opacity: active ? 1 : 0,
                            child: Container(
                              width: widget.tvMode ? 58 : 48,
                              height: widget.tvMode ? 58 : 48,
                              decoration: BoxDecoration(
                                color: ZingColors.purpleBright,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 18,
                                  ),
                                ],
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
