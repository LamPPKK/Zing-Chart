import 'dart:async';

import 'package:flutter/material.dart';

import '../models/listening_analytics.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';
import 'song_action_menu.dart';

typedef LocalMixSongActionResolver =
    SongActionMenuConfiguration Function(Song song);

/// A Local-First detail surface for Daily Mix and user-labelled Mood Mixes.
///
/// The widget deliberately exposes only local callbacks. Opening and browsing
/// a mix never needs a catalog request; the parent owns playback and menus.
class LocalMixWorkspace extends StatelessWidget {
  const LocalMixWorkspace({
    super.key,
    required this.mix,
    required this.tvMode,
    this.showBack = true,
    required this.currentSongId,
    required this.isPlaying,
    required this.onBack,
    required this.onPlayAll,
    required this.onShuffle,
    required this.onSongTap,
    required this.actionResolver,
  });

  final MixCollection mix;
  final bool tvMode;
  final bool showBack;
  final String? currentSongId;
  final bool isPlaying;
  final VoidCallback onBack;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;
  final ValueChanged<Song> onSongTap;
  final LocalMixSongActionResolver actionResolver;

  @override
  Widget build(BuildContext context) {
    final songs = mix.songs;
    final playableSongCount = songs
        .where((song) => song.isPlaybackEligible)
        .length;
    final horizontalPadding = tvMode ? 34.0 : 20.0;
    return SliverMainAxisGroup(
      key: const ValueKey('local-mix-workspace'),
      slivers: [
        SliverToBoxAdapter(
          child: _MixHero(
            mix: mix,
            tvMode: tvMode,
            showBack: showBack,
            onBack: onBack,
            onPlayAll: playableSongCount == 0 ? null : onPlayAll,
            onShuffle: playableSongCount < 2 ? null : onShuffle,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              tvMode ? 34 : 26,
              horizontalPadding,
              14,
            ),
            child: _MixSectionHeading(
              mix: mix,
              songCount: songs.length,
              tvMode: tvMode,
            ),
          ),
        ),
        if (songs.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                52,
              ),
              child: _EmptyMixState(mix: mix),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              tvMode ? 64 : 42,
            ),
            sliver: SliverList.builder(
              key: const ValueKey('local-mix-action'),
              itemCount: songs.length,
              findChildIndexCallback: (key) => _songIndexForKey(songs, key),
              itemBuilder: (context, index) {
                final song = songs[index];
                final rawActions = actionResolver(song);
                final actions = song.isPlaybackEligible
                    ? rawActions
                    : SongActionMenuConfiguration(
                        isLiked: rawActions.isLiked,
                        moods: rawActions.moods,
                        handlers: SongActionHandlers(
                          onOpenDetail: rawActions.handlers.onOpenDetail,
                          onAddToPlaylist: rawActions.handlers.onAddToPlaylist,
                          onShare: rawActions.handlers.onShare,
                          onToggleLike: rawActions.handlers.onToggleLike,
                          onToggleMood: rawActions.handlers.onToggleMood,
                        ),
                      );
                return _MixSongRow(
                  key: ValueKey('local-mix-song-${song.id}'),
                  song: song,
                  index: index,
                  mix: mix,
                  tvMode: tvMode,
                  current: currentSongId == song.id,
                  playing: isPlaying,
                  canPlay: song.isPlaybackEligible,
                  onTap: song.isPlaybackEligible ? () => onSongTap(song) : null,
                  actions: actions,
                );
              },
            ),
          ),
      ],
    );
  }

  int? _songIndexForKey(List<Song> songs, Key key) {
    for (var index = 0; index < songs.length; index++) {
      if (key == ValueKey('local-mix-song-${songs[index].id}')) return index;
    }
    return null;
  }
}

class _MixHero extends StatelessWidget {
  const _MixHero({
    required this.mix,
    required this.tvMode,
    required this.showBack,
    required this.onBack,
    required this.onPlayAll,
    required this.onShuffle,
  });

  final MixCollection mix;
  final bool tvMode;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final palette = _paletteFor(mix.mood, dark: dark);
    return Container(
      key: const ValueKey('local-mix-hero'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.hero,
          stops: const [0, 0.58, 1],
        ),
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.38),
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: tvMode ? -54 : -36,
            top: tvMode ? -84 : -62,
            child: ExcludeSemantics(
              child: Icon(
                _moodIcon(mix.mood),
                size: tvMode ? 310 : 230,
                color: palette.accent.withValues(alpha: dark ? 0.09 : 0.12),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              tvMode ? 34 : 20,
              tvMode ? 24 : 14,
              tvMode ? 34 : 20,
              tvMode ? 42 : 30,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = !tvMode && constraints.maxWidth < 720;
                final coverSize = tvMode
                    ? 276.0
                    : compact
                    ? 178.0
                    : 226.0;
                final cover = _MixCoverMosaic(
                  mix: mix,
                  size: coverSize,
                  palette: palette,
                );
                final details = _MixHeroDetails(
                  mix: mix,
                  tvMode: tvMode,
                  compact: compact,
                  showBack: showBack,
                  palette: palette,
                  onBack: onBack,
                  onPlayAll: onPlayAll,
                  onShuffle: onShuffle,
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showBack) ...[
                        _MixBackButton(onPressed: onBack, autofocus: tvMode),
                        const SizedBox(height: 14),
                      ],
                      Center(child: cover),
                      const SizedBox(height: 24),
                      details,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    cover,
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
}

class _MixHeroDetails extends StatelessWidget {
  const _MixHeroDetails({
    required this.mix,
    required this.tvMode,
    required this.compact,
    required this.showBack,
    required this.palette,
    required this.onBack,
    required this.onPlayAll,
    required this.onShuffle,
  });

  final MixCollection mix;
  final bool tvMode;
  final bool compact;
  final bool showBack;
  final _MixPalette palette;
  final VoidCallback onBack;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final buttonHeight = tvMode ? 58.0 : 48.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBack && !compact) ...[
          _MixBackButton(onPressed: onBack, autofocus: tvMode),
          SizedBox(height: tvMode ? 22 : 16),
        ],
        Text(
          '${_mixKindLabel(mix.mood).toUpperCase()} · LOCAL INTELLIGENCE',
          style: TextStyle(
            color: dark ? palette.accent : palette.lightAccent,
            fontSize: tvMode ? 15 : 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.45,
          ),
        ),
        SizedBox(height: tvMode ? 12 : 8),
        Text(
          mix.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: tvMode
                ? 52
                : compact
                ? 36
                : 46,
            height: 1.01,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.6,
          ),
        ),
        SizedBox(height: tvMode ? 14 : 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            mix.subtitle,
            maxLines: compact ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: tvMode ? 18 : 14,
              height: 1.35,
            ),
          ),
        ),
        SizedBox(height: tvMode ? 18 : 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MixBadge(
              icon: Icons.lock_outline_rounded,
              label: 'Chỉ xử lý trên thiết bị',
              color: dark ? ZingColors.lime : const Color(0xFF176A58),
              tvMode: tvMode,
            ),
            if (mix.isColdStart)
              _MixBadge(
                key: const ValueKey('local-mix-cold-start'),
                icon: Icons.auto_awesome_rounded,
                label: 'Đang học gu của bạn',
                color: dark ? palette.accent : palette.lightAccent,
                tvMode: tvMode,
              ),
          ],
        ),
        SizedBox(height: tvMode ? 30 : 22),
        Wrap(
          spacing: tvMode ? 14 : 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              key: const ValueKey('local-mix-play'),
              onPressed: onPlayAll,
              style: FilledButton.styleFrom(
                minimumSize: Size(tvMode ? 164 : 132, buttonHeight),
                backgroundColor: dark ? palette.accent : palette.lightAccent,
                foregroundColor: dark ? ZingColors.ink : Colors.white,
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(mix.songs.isEmpty ? 'Chưa có bài' : 'Phát tất cả'),
            ),
            FilledButton.tonalIcon(
              key: const ValueKey('local-mix-shuffle'),
              onPressed: onShuffle,
              style: FilledButton.styleFrom(
                minimumSize: Size(tvMode ? 154 : 122, buttonHeight),
              ),
              icon: const Icon(Icons.shuffle_rounded),
              label: const Text('Trộn bài'),
            ),
          ],
        ),
      ],
    );
  }
}

class _MixBadge extends StatelessWidget {
  const _MixBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.tvMode,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.11),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.34)),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tvMode ? 14 : 11,
        vertical: tvMode ? 8 : 6,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: tvMode ? 18 : 15, color: color),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: tvMode ? 14 : 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MixBackButton extends StatelessWidget {
  const _MixBackButton({required this.onPressed, required this.autofocus});

  final VoidCallback onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: const ValueKey('local-mix-back'),
    onPressed: onPressed,
    autofocus: autofocus,
    icon: const Icon(Icons.arrow_back_rounded),
    label: const Text('Dành cho bạn'),
  );
}

class _MixCoverMosaic extends StatelessWidget {
  const _MixCoverMosaic({
    required this.mix,
    required this.size,
    required this.palette,
  });

  final MixCollection mix;
  final double size;
  final _MixPalette palette;

  @override
  Widget build(BuildContext context) {
    final songs = mix.songs.take(4).toList(growable: false);
    return Semantics(
      image: true,
      label: 'Ảnh ghép ${mix.title}',
      child: Container(
        key: const ValueKey('local-mix-cover'),
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.09),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ExcludeSemantics(
          child: GridView.builder(
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              final song = index < songs.length ? songs[index] : null;
              if (song == null || song.thumbnail.trim().isEmpty) {
                return _MixCoverFallback(
                  index: index,
                  mood: mix.mood,
                  palette: palette,
                );
              }
              return AlbumArt(
                imageUrl: song.thumbnail,
                semanticLabel: 'Bìa ${song.displayTitle}',
                size: size / 2,
                borderRadius: 0,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MixCoverFallback extends StatelessWidget {
  const _MixCoverFallback({
    required this.index,
    required this.mood,
    required this.palette,
  });

  final int index;
  final MoodTag? mood;
  final _MixPalette palette;

  @override
  Widget build(BuildContext context) {
    final colors = index.isEven
        ? [palette.fallbackA, palette.fallbackB]
        : [palette.fallbackB, palette.fallbackC];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Icon(
          index == 3 ? Icons.auto_awesome_rounded : _moodIcon(mood),
          size: 42,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _MixSectionHeading extends StatelessWidget {
  const _MixSectionHeading({
    required this.mix,
    required this.songCount,
    required this.tvMode,
  });

  final MixCollection mix;
  final int songCount;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bài hát trong mix',
          style: TextStyle(
            fontSize: tvMode ? 30 : 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          songCount == 0
              ? _emptyHint(mix)
              : '$songCount bài · xếp hạng riêng tư từ tín hiệu trên máy',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: tvMode ? 16 : 13,
          ),
        ),
      ],
    ),
  );
}

class _EmptyMixState extends StatelessWidget {
  const _EmptyMixState({required this.mix});

  final MixCollection mix;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('local-mix-empty'),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainer.withValues(alpha: 0.76),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.55),
      ),
    ),
    child: Column(
      children: [
        Icon(
          _moodIcon(mix.mood),
          size: 54,
          color: Theme.of(context).brightness == Brightness.dark
              ? ZingColors.purpleBright
              : Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 14),
        Text(
          'Mix đang chờ tín hiệu của bạn',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        Text(
          _emptyHint(mix),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _MixSongRow extends StatefulWidget {
  const _MixSongRow({
    super.key,
    required this.song,
    required this.index,
    required this.mix,
    required this.tvMode,
    required this.current,
    required this.playing,
    required this.canPlay,
    required this.onTap,
    required this.actions,
  });

  final Song song;
  final int index;
  final MixCollection mix;
  final bool tvMode;
  final bool current;
  final bool playing;
  final bool canPlay;
  final VoidCallback? onTap;
  final SongActionMenuConfiguration actions;

  @override
  State<_MixSongRow> createState() => _MixSongRowState();
}

class _MixSongRowState extends State<_MixSongRow> {
  late final FocusNode _focusNode;
  var _hovered = false;
  var _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'local-mix-focus-${widget.song.id}');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool focused) {
    setState(() => _focused = focused);
    if (!focused) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focusNode.hasFocus) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = !widget.tvMode && constraints.maxWidth < 640;
      final scheme = Theme.of(context).colorScheme;
      final dark = Theme.of(context).brightness == Brightness.dark;
      final palette = _paletteFor(widget.mix.mood, dark: dark);
      final activeColor = dark ? palette.accent : palette.lightAccent;
      final highlighted = widget.current || _hovered || _focused;
      final radius = BorderRadius.circular(widget.tvMode ? 16 : 12);
      final artist = widget.song.artistsNames.trim().isEmpty
          ? 'Nghệ sĩ chưa xác định'
          : widget.song.artistsNames;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: MouseRegion(
          cursor: widget.canPlay
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: highlighted
                  ? activeColor.withValues(alpha: widget.current ? 0.17 : 0.09)
                  : Colors.transparent,
              borderRadius: radius,
              border: Border.all(
                color: _focused
                    ? activeColor
                    : scheme.outlineVariant.withValues(alpha: 0.18),
                width: _focused ? (widget.tvMode ? 3 : 2) : 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      enabled: widget.canPlay,
                      selected: widget.current,
                      label:
                          '${widget.song.displayTitle}, $artist, bài ${widget.index + 1} trong ${widget.mix.title}'
                          '${widget.canPlay ? '' : ', bị giới hạn phát'}'
                          '${widget.current ? (widget.playing ? ', đang phát' : ', đang tạm dừng') : ''}',
                      onTap: widget.onTap,
                      excludeSemantics: true,
                      child: InkWell(
                        focusNode: _focusNode,
                        canRequestFocus: widget.canPlay,
                        excludeFromSemantics: true,
                        onFocusChange: _handleFocusChange,
                        mouseCursor: widget.canPlay
                            ? SystemMouseCursors.click
                            : SystemMouseCursors.forbidden,
                        onTap: widget.onTap,
                        onSecondaryTapDown: widget.actions.handlers.hasAny
                            ? (details) => unawaited(
                                showSongActionContextMenu(
                                  context: context,
                                  globalPosition: details.globalPosition,
                                  keyPrefix: 'local-mix-action',
                                  song: widget.song,
                                  handlers: widget.actions.handlers,
                                  isLiked: widget.actions.isLiked,
                                  moods: widget.actions.moods,
                                ),
                              )
                            : null,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            widget.tvMode ? 16 : 10,
                            widget.tvMode ? 12 : 8,
                            widget.tvMode ? 12 : 6,
                            widget.tvMode ? 12 : 8,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: widget.tvMode ? 48 : 36,
                                child: widget.current
                                    ? Icon(
                                        widget.playing
                                            ? Icons.graphic_eq_rounded
                                            : Icons
                                                  .pause_circle_outline_rounded,
                                        color: activeColor,
                                      )
                                    : !widget.canPlay
                                    ? Icon(
                                        Icons.lock_outline_rounded,
                                        color: scheme.onSurfaceVariant,
                                        size: widget.tvMode ? 24 : 20,
                                      )
                                    : Text(
                                        '${widget.index + 1}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                              ),
                              AlbumArt(
                                imageUrl: widget.song.thumbnail,
                                semanticLabel:
                                    'Bìa ${widget.song.displayTitle}',
                                size: widget.tvMode ? 68 : 50,
                                borderRadius: widget.tvMode ? 11 : 8,
                              ),
                              SizedBox(width: widget.tvMode ? 18 : 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.song.displayTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: widget.current
                                            ? activeColor
                                            : scheme.onSurface,
                                        fontSize: widget.tvMode ? 20 : 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: widget.tvMode ? 16 : 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!compact) ...[
                                const SizedBox(width: 18),
                                _MixRowBadge(
                                  label: widget.canPlay
                                      ? _rowBadgeLabel(widget.mix)
                                      : 'BỊ GIỚI HẠN',
                                  icon: widget.canPlay
                                      ? _moodIcon(widget.mix.mood)
                                      : Icons.lock_outline_rounded,
                                  color: activeColor,
                                  tvMode: widget.tvMode,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: widget.tvMode ? 10 : 2),
                    child: SongActionOverflowButton(
                      keyPrefix: 'local-mix-action',
                      song: widget.song,
                      handlers: widget.actions.handlers,
                      isLiked: widget.actions.isLiked,
                      moods: widget.actions.moods,
                      iconSize: widget.tvMode ? 30 : 24,
                      iconColor: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _MixRowBadge extends StatelessWidget {
  const _MixRowBadge({
    required this.label,
    required this.icon,
    required this.color,
    required this.tvMode,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tvMode ? 12 : 9,
        vertical: tvMode ? 7 : 5,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: tvMode ? 17 : 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: tvMode ? 12 : 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.75,
            ),
          ),
        ],
      ),
    ),
  );
}

@immutable
class _MixPalette {
  const _MixPalette({
    required this.hero,
    required this.accent,
    required this.lightAccent,
    required this.fallbackA,
    required this.fallbackB,
    required this.fallbackC,
  });

  final List<Color> hero;
  final Color accent;
  final Color lightAccent;
  final Color fallbackA;
  final Color fallbackB;
  final Color fallbackC;
}

_MixPalette _paletteFor(MoodTag? mood, {required bool dark}) {
  final darkEnd = dark ? ZingColors.ink : ZingColors.paper;
  return switch (mood) {
    MoodTag.chill => _MixPalette(
      hero: [
        dark ? const Color(0xFF14566D) : const Color(0xFFC9EEF4),
        dark ? const Color(0xFF263969) : const Color(0xFFDDE6FA),
        darkEnd,
      ],
      accent: const Color(0xFF63D6E7),
      lightAccent: const Color(0xFF176A82),
      fallbackA: const Color(0xFF4A90E2),
      fallbackB: const Color(0xFF27C9A0),
      fallbackC: const Color(0xFF293F77),
    ),
    MoodTag.gym => _MixPalette(
      hero: [
        dark ? const Color(0xFF703240) : const Color(0xFFFFD6CC),
        dark ? const Color(0xFF54265D) : const Color(0xFFF4D8EA),
        darkEnd,
      ],
      accent: const Color(0xFFFF7B68),
      lightAccent: const Color(0xFFB43B36),
      fallbackA: const Color(0xFFF06A50),
      fallbackB: const Color(0xFFED2B91),
      fallbackC: const Color(0xFF7C315D),
    ),
    MoodTag.focus => _MixPalette(
      hero: [
        dark ? const Color(0xFF14584E) : const Color(0xFFCBEFE5),
        dark ? const Color(0xFF294343) : const Color(0xFFE0EADA),
        darkEnd,
      ],
      accent: ZingColors.lime,
      lightAccent: const Color(0xFF176A58),
      fallbackA: const Color(0xFF27C9A0),
      fallbackB: const Color(0xFF5A9E62),
      fallbackC: const Color(0xFF246A70),
    ),
    null => _MixPalette(
      hero: [
        dark ? const Color(0xFF67316E) : const Color(0xFFEAD2F5),
        dark ? const Color(0xFF5C274F) : const Color(0xFFF5D9E8),
        darkEnd,
      ],
      accent: ZingColors.purpleBright,
      lightAccent: const Color(0xFF7B2CBF),
      fallbackA: ZingColors.purple,
      fallbackB: ZingColors.coral,
      fallbackC: const Color(0xFF4A5FE0),
    ),
  };
}

IconData _moodIcon(MoodTag? mood) => switch (mood) {
  MoodTag.chill => Icons.water_rounded,
  MoodTag.gym => Icons.bolt_rounded,
  MoodTag.focus => Icons.center_focus_strong_rounded,
  null => Icons.auto_awesome_rounded,
};

String _mixKindLabel(MoodTag? mood) => switch (mood) {
  MoodTag.chill => 'Mood Chill',
  MoodTag.gym => 'Mood Gym',
  MoodTag.focus => 'Mood Tập trung',
  null => 'Daily Mix',
};

String _rowBadgeLabel(MixCollection mix) => switch (mix.mood) {
  MoodTag.chill => 'CHILL PICK',
  MoodTag.gym => 'GYM PICK',
  MoodTag.focus => 'FOCUS PICK',
  null => 'DAILY PICK',
};

String _emptyHint(MixCollection mix) => switch (mix.mood) {
  null => 'Nghe hoặc thả tim thêm bài để Daily Mix hiểu gu của bạn.',
  _ => 'Gắn mood cho bài hát từ menu hoặc Now Playing để bắt đầu mix này.',
};
