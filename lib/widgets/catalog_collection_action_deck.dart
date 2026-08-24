import 'package:flutter/material.dart';

import '../models/catalog_search.dart';
import '../theme/app_theme.dart';

enum _CatalogCollectionAction { play, open, toggleSaved, share }

/// Opens the same Zing-style action menu used by the artwork overflow button.
///
/// Desktop collection cards call this from [InkWell.onSecondaryTapDown] so a
/// right-click never has a different set of actions from the visible card UI.
Future<void> showCatalogCollectionContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required String keyPrefix,
  required CatalogCollection collection,
  required bool saved,
  required bool playing,
  required VoidCallback onOpen,
  VoidCallback? onPlay,
  VoidCallback? onToggleSaved,
  VoidCallback? onShare,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject();
  if (overlay is! RenderBox || !overlay.hasSize) return;
  final localPosition = overlay.globalToLocal(globalPosition);
  final left = localPosition.dx.clamp(0.0, overlay.size.width);
  final top = localPosition.dy.clamp(0.0, overlay.size.height);
  final action = await showMenu<_CatalogCollectionAction>(
    context: context,
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    position: RelativeRect.fromLTRB(
      left,
      top,
      overlay.size.width - left,
      overlay.size.height - top,
    ),
    items: _collectionMenuItems(
      keyPrefix: keyPrefix,
      collection: collection,
      saved: saved,
      playing: playing,
      includeOpen: true,
      onPlay: onPlay,
      onToggleSaved: onToggleSaved,
      onShare: onShare,
    ),
  );
  if (action == null || !context.mounted) return;
  _handleCollectionAction(
    action,
    onOpen: onOpen,
    onPlay: onPlay,
    onToggleSaved: onToggleSaved,
    onShare: onShare,
  );
}

/// Zing-style artwork actions shared by every official collection card.
class CatalogCollectionActionDeck extends StatelessWidget {
  const CatalogCollectionActionDeck({
    super.key,
    required this.keyPrefix,
    required this.collection,
    required this.tvMode,
    this.touchMode = false,
    required this.active,
    required this.saved,
    required this.playing,
    required this.onOpen,
    required this.onPlay,
    required this.onToggleSaved,
    required this.onShare,
  });

  final String keyPrefix;
  final CatalogCollection collection;
  final bool tvMode;
  final bool touchMode;
  final bool active;
  final bool saved;
  final bool playing;
  final VoidCallback onOpen;
  final VoidCallback? onPlay;
  final VoidCallback? onToggleSaved;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = !tvMode && constraints.maxWidth < 122;
      final sideSize = tvMode
          ? 46.0
          : touchMode
          ? 44.0
          : compact
          ? 44.0
          : 36.0;
      final playSize = tvMode
          ? 58.0
          : touchMode
          ? 48.0
          : compact
          ? 44.0
          : 46.0;
      final sideIconSize = tvMode
          ? 25.0
          : compact
          ? 20.0
          : 20.0;
      final playIconSize = tvMode
          ? 34.0
          : compact
          ? 28.0
          : 28.0;
      return AnimatedOpacity(
        opacity: active ? 1 : 0.9,
        duration: const Duration(milliseconds: 160),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!compact)
              _ActionCircle(
                color: const Color(0xB30D0813),
                elevation: active ? 6 : 2,
                child: IconButton(
                  key: ValueKey('$keyPrefix-save-${collection.id}'),
                  tooltip: saved
                      ? 'Bỏ lưu ${collection.title}'
                      : 'Lưu ${collection.title}',
                  constraints: BoxConstraints.tightFor(
                    width: sideSize,
                    height: sideSize,
                  ),
                  padding: EdgeInsets.zero,
                  iconSize: sideIconSize,
                  onPressed: onToggleSaved,
                  color: saved ? ZingColors.coral : Colors.white,
                  icon: Icon(
                    saved
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                  ),
                ),
              ),
            _ActionCircle(
              color: ZingColors.purpleBright,
              elevation: active ? 10 : 4,
              child: IconButton(
                key: ValueKey('$keyPrefix-play-${collection.id}'),
                tooltip: 'Phát ngay ${collection.title}',
                constraints: BoxConstraints.tightFor(
                  width: playSize,
                  height: playSize,
                ),
                padding: EdgeInsets.zero,
                onPressed: playing ? null : onPlay,
                iconSize: playIconSize,
                color: Colors.white,
                disabledColor: Colors.white,
                icon: playing
                    ? SizedBox.square(
                        dimension: tvMode
                            ? 27
                            : compact
                            ? 21
                            : 21,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded),
              ),
            ),
            _ActionCircle(
              color: const Color(0xB30D0813),
              elevation: active ? 6 : 2,
              child: SizedBox.square(
                dimension: sideSize,
                child: PopupMenuButton<_CatalogCollectionAction>(
                  key: ValueKey('$keyPrefix-more-${collection.id}'),
                  tooltip: 'Thêm lựa chọn cho ${collection.title}',
                  padding: EdgeInsets.zero,
                  iconSize: sideIconSize,
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white,
                  ),
                  onSelected: (action) => _handleCollectionAction(
                    action,
                    onOpen: onOpen,
                    onPlay: onPlay,
                    onToggleSaved: onToggleSaved,
                    onShare: onShare,
                  ),
                  itemBuilder: (context) => _collectionMenuItems(
                    keyPrefix: keyPrefix,
                    collection: collection,
                    saved: saved,
                    playing: playing,
                    includeOpen: true,
                    onPlay: onPlay,
                    onToggleSaved: onToggleSaved,
                    onShare: onShare,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Compact collection overflow used by touch-first detail surfaces.
///
/// The current collection is already open, so this menu deliberately omits
/// the redundant "Open info" action while reusing the same Play/Save/Share
/// contract as collection cards.
class CatalogCollectionOverflowButton extends StatelessWidget {
  const CatalogCollectionOverflowButton({
    super.key,
    required this.buttonKey,
    required this.keyPrefix,
    required this.collection,
    required this.saved,
    required this.playing,
    this.onPlay,
    this.onToggleSaved,
    this.onShare,
    this.size = 48,
    this.foregroundColor = Colors.white,
  });

  final Key buttonKey;
  final String keyPrefix;
  final CatalogCollection collection;
  final bool saved;
  final bool playing;
  final VoidCallback? onPlay;
  final VoidCallback? onToggleSaved;
  final VoidCallback? onShare;
  final double size;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.08),
    shape: CircleBorder(
      side: BorderSide(color: Colors.white.withValues(alpha: 0.42)),
    ),
    clipBehavior: Clip.antiAlias,
    child: SizedBox.square(
      dimension: size,
      child: PopupMenuButton<_CatalogCollectionAction>(
        key: buttonKey,
        tooltip: 'Thêm lựa chọn cho ${collection.title}',
        padding: EdgeInsets.zero,
        iconSize: 23,
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        icon: Icon(Icons.more_horiz_rounded, color: foregroundColor),
        onSelected: (action) => _handleCollectionAction(
          action,
          onOpen: null,
          onPlay: onPlay,
          onToggleSaved: onToggleSaved,
          onShare: onShare,
        ),
        itemBuilder: (context) => _collectionMenuItems(
          keyPrefix: keyPrefix,
          collection: collection,
          saved: saved,
          playing: playing,
          includeOpen: false,
          onPlay: onPlay,
          onToggleSaved: onToggleSaved,
          onShare: onShare,
        ),
      ),
    ),
  );
}

List<PopupMenuEntry<_CatalogCollectionAction>> _collectionMenuItems({
  required String keyPrefix,
  required CatalogCollection collection,
  required bool saved,
  required bool playing,
  required bool includeOpen,
  required VoidCallback? onPlay,
  required VoidCallback? onToggleSaved,
  required VoidCallback? onShare,
}) => [
  if (onPlay != null)
    PopupMenuItem(
      key: ValueKey('$keyPrefix-menu-play-${collection.id}'),
      value: _CatalogCollectionAction.play,
      enabled: !playing,
      child: _MenuLabel(
        icon: playing ? Icons.sync_rounded : Icons.play_arrow_rounded,
        label: playing ? 'Đang chuẩn bị phát…' : 'Phát ngay',
      ),
    ),
  if (includeOpen)
    PopupMenuItem(
      key: ValueKey('$keyPrefix-menu-open-${collection.id}'),
      value: _CatalogCollectionAction.open,
      child: const _MenuLabel(
        icon: Icons.info_outline_rounded,
        label: 'Mở thông tin',
      ),
    ),
  if (onToggleSaved != null)
    PopupMenuItem(
      key: ValueKey('$keyPrefix-menu-save-${collection.id}'),
      value: _CatalogCollectionAction.toggleSaved,
      child: _MenuLabel(
        icon: saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        label: saved ? 'Bỏ khỏi thư viện' : 'Lưu vào thư viện',
      ),
    ),
  if (onShare != null)
    PopupMenuItem(
      key: ValueKey('$keyPrefix-menu-share-${collection.id}'),
      value: _CatalogCollectionAction.share,
      child: const _MenuLabel(icon: Icons.ios_share_rounded, label: 'Chia sẻ'),
    ),
];

void _handleCollectionAction(
  _CatalogCollectionAction action, {
  required VoidCallback? onOpen,
  required VoidCallback? onPlay,
  required VoidCallback? onToggleSaved,
  required VoidCallback? onShare,
}) {
  switch (action) {
    case _CatalogCollectionAction.play:
      onPlay?.call();
      break;
    case _CatalogCollectionAction.open:
      onOpen?.call();
      break;
    case _CatalogCollectionAction.toggleSaved:
      onToggleSaved?.call();
      break;
    case _CatalogCollectionAction.share:
      onShare?.call();
      break;
  }
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({
    required this.color,
    required this.elevation,
    required this.child,
  });

  final Color color;
  final double elevation;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    elevation: elevation,
    shadowColor: Colors.black54,
    shape: const CircleBorder(),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [Icon(icon, size: 20), const SizedBox(width: 10), Text(label)],
  );
}
