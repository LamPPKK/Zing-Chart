import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/catalog_search.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';

/// A reusable, adaptive rail for first-party catalog artist profiles.
class CatalogArtistRail extends StatefulWidget {
  const CatalogArtistRail({
    super.key,
    required this.title,
    required this.artists,
    required this.onArtistTap,
    this.onToggleFollow,
    this.followedArtistIds = const <String>{},
    this.keyPrefix = 'catalog-artist',
    this.tvMode = false,
  });

  final String title;
  final List<CatalogArtist> artists;
  final ValueChanged<CatalogArtist> onArtistTap;
  final ValueChanged<CatalogArtist>? onToggleFollow;
  final Set<String> followedArtistIds;
  final String keyPrefix;
  final bool tvMode;

  @override
  State<CatalogArtistRail> createState() => _CatalogArtistRailState();
}

class _CatalogArtistRailState extends State<CatalogArtistRail> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollBackward = false;
  bool _canScrollForward = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncNavigationState);
  }

  @override
  void didUpdateWidget(covariant CatalogArtistRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameArtistOrder(oldWidget.artists, widget.artists) ||
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
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final canScrollBackward = position.pixels > position.minScrollExtent + 0.5;
    final canScrollForward = position.pixels < position.maxScrollExtent - 0.5;
    if (canScrollBackward == _canScrollBackward &&
        canScrollForward == _canScrollForward) {
      return;
    }
    setState(() {
      _canScrollBackward = canScrollBackward;
      _canScrollForward = canScrollForward;
    });
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = (position.pixels + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (MediaQuery.disableAnimationsOf(context)) {
      _scrollController.jumpTo(target);
      return;
    }
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final artistsById = <String, CatalogArtist>{};
    for (final artist in widget.artists) {
      if (artist.id.trim().isEmpty || artist.name.trim().isEmpty) continue;
      artistsById.putIfAbsent(artist.id, () => artist);
    }
    final artists = artistsById.values.toList(growable: false);
    if (artists.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = widget.tvMode
            ? 196.0
            : constraints.maxWidth >= 900
            ? 166.0
            : constraints.maxWidth >= 560
            ? 148.0
            : 138.0;
        final gap = widget.tvMode ? 22.0 : 16.0;
        final contentWidth =
            artists.length * itemWidth + (artists.length - 1) * gap;
        final desktopPointerPlatform = switch (Theme.of(context).platform) {
          TargetPlatform.macOS ||
          TargetPlatform.windows ||
          TargetPlatform.linux => true,
          _ => false,
        };
        final showNavigation =
            contentWidth > constraints.maxWidth &&
            (constraints.maxWidth >= 720 ||
                desktopPointerPlatform ||
                widget.tvMode);
        if (showNavigation) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _syncNavigationState(),
          );
        }
        final footerHeight = widget.onToggleFollow == null
            ? widget.tvMode
                  ? 72.0
                  : 62.0
            : widget.tvMode
            ? 124.0
            : 108.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ArtistRailHeader(
              title: widget.title,
              artistCount: artists.length,
              showNavigation: showNavigation,
              canScrollBackward: _canScrollBackward,
              canScrollForward: _canScrollForward,
              onPrevious: () => _scrollBy(
                -_scrollController.position.viewportDimension * 0.78,
              ),
              onNext: () => _scrollBy(
                _scrollController.position.viewportDimension * 0.78,
              ),
              keyPrefix: widget.keyPrefix,
              tvMode: widget.tvMode,
            ),
            SizedBox(height: widget.tvMode ? 18 : 13),
            SizedBox(
              height: itemWidth + footerHeight,
              child: ListView.separated(
                key: ValueKey('${widget.keyPrefix}-list'),
                controller: _scrollController,
                primary: false,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                itemCount: artists.length,
                separatorBuilder: (_, __) => SizedBox(width: gap),
                itemBuilder: (context, index) {
                  final artist = artists[index];
                  return SizedBox(
                    width: itemWidth,
                    child: _CatalogArtistCard(
                      key: ValueKey('${widget.keyPrefix}-${artist.id}'),
                      artist: artist,
                      onTap: () => widget.onArtistTap(artist),
                      onToggleFollow: widget.onToggleFollow == null
                          ? null
                          : () => widget.onToggleFollow!(artist),
                      followed: widget.followedArtistIds.contains(artist.id),
                      followKey: ValueKey(
                        '${widget.keyPrefix}-follow-${artist.id}',
                      ),
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
}

bool _sameArtistOrder(
  List<CatalogArtist> previous,
  List<CatalogArtist> current,
) {
  if (previous.length != current.length) return false;
  for (var index = 0; index < previous.length; index++) {
    if (previous[index].id != current[index].id) return false;
  }
  return true;
}

class _ArtistRailHeader extends StatelessWidget {
  const _ArtistRailHeader({
    required this.title,
    required this.artistCount,
    required this.showNavigation,
    required this.canScrollBackward,
    required this.canScrollForward,
    required this.onPrevious,
    required this.onNext,
    required this.keyPrefix,
    required this.tvMode,
  });

  final String title;
  final int artistCount;
  final bool showNavigation;
  final bool canScrollBackward;
  final bool canScrollForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final String keyPrefix;
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
      Text(
        '$artistCount nghệ sĩ',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: tvMode ? 14 : 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      if (showNavigation) ...[
        SizedBox(width: tvMode ? 14 : 9),
        _RailNavigationButton(
          key: ValueKey('$keyPrefix-previous'),
          tooltip: 'Nghệ sĩ trước',
          icon: Icons.chevron_left_rounded,
          onPressed: canScrollBackward ? onPrevious : null,
          tvMode: tvMode,
        ),
        SizedBox(width: tvMode ? 8 : 5),
        _RailNavigationButton(
          key: ValueKey('$keyPrefix-next'),
          tooltip: 'Nghệ sĩ tiếp theo',
          icon: Icons.chevron_right_rounded,
          onPressed: canScrollForward ? onNext : null,
          tvMode: tvMode,
        ),
      ],
    ],
  );
}

class _RailNavigationButton extends StatelessWidget {
  const _RailNavigationButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.tvMode,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => IconButton.outlined(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      minimumSize: Size.square(tvMode ? 52 : 40),
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      disabledForegroundColor: Theme.of(
        context,
      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
      side: BorderSide(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
    ),
    icon: Icon(icon, size: tvMode ? 30 : 23),
  );
}

class _CatalogArtistCard extends StatefulWidget {
  const _CatalogArtistCard({
    super.key,
    required this.artist,
    required this.onTap,
    required this.onToggleFollow,
    required this.followed,
    required this.followKey,
    required this.tvMode,
  });

  final CatalogArtist artist;
  final VoidCallback onTap;
  final VoidCallback? onToggleFollow;
  final bool followed;
  final Key followKey;
  final bool tvMode;

  @override
  State<_CatalogArtistCard> createState() => _CatalogArtistCardState();
}

class _CatalogArtistCardState extends State<_CatalogArtistCard> {
  final FocusNode _focusNode = FocusNode();
  bool _hovered = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (!mounted || _focused == _focusNode.hasFocus) return;
    setState(() => _focused = _focusNode.hasFocus);
    if (!_focused) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _focused;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 170);
    final borderColor = _focused
        ? ZingColors.lime
        : _hovered
        ? ZingColors.purpleBright
        : Colors.transparent;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      button: true,
      label: 'Mở nghệ sĩ ${widget.artist.name}',
      onTap: widget.onTap,
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
        onShowHoverHighlight: (value) {
          if (mounted && _hovered != value) setState(() => _hovered = value);
        },
        child: AnimatedContainer(
          duration: duration,
          decoration: BoxDecoration(
            color: active
                ? Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.38)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(widget.tvMode ? 22 : 18),
          ),
          padding: EdgeInsets.all(widget.tvMode ? 6 : 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              canRequestFocus: false,
              excludeFromSemantics: true,
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(widget.tvMode ? 20 : 16),
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final avatarSize = constraints.maxWidth;
                      return AnimatedContainer(
                        duration: duration,
                        width: avatarSize,
                        height: avatarSize,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor, width: 3),
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
                        child: AlbumArt(
                          imageUrl: widget.artist.avatar,
                          semanticLabel: 'Ảnh nghệ sĩ ${widget.artist.name}',
                          size: avatarSize - 8,
                          borderRadius: 999,
                        ),
                      );
                    },
                  ),
                  SizedBox(height: widget.tvMode ? 11 : 9),
                  Text(
                    widget.artist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: widget.tvMode ? 17 : 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (widget.artist.totalFollow > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatFollowerCount(widget.artist.totalFollow),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: widget.tvMode ? 13 : 11,
                      ),
                    ),
                  ],
                  if (widget.onToggleFollow != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: widget.followKey,
                      onPressed: widget.onToggleFollow,
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(
                          widget.tvMode ? 132 : 108,
                          widget.tvMode ? 44 : 36,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        foregroundColor: widget.followed
                            ? ZingColors.lime
                            : Theme.of(context).colorScheme.onSurface,
                        side: BorderSide(
                          color: widget.followed
                              ? ZingColors.lime.withValues(alpha: 0.78)
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                        textStyle: TextStyle(
                          fontSize: widget.tvMode ? 13 : 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      child: Text(
                        widget.followed ? 'Đang quan tâm' : 'Quan tâm',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatFollowerCount(int value) {
  final digits = value.toString().split('').reversed.toList();
  final groups = <String>[];
  for (var index = 0; index < digits.length; index += 3) {
    groups.add(digits.skip(index).take(3).toList().reversed.join());
  }
  return '${groups.reversed.join('.')} người quan tâm';
}
