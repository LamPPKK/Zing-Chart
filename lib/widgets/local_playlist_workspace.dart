import 'dart:async';

import 'package:flutter/material.dart';

import '../models/local_library.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';
import 'song_action_menu.dart';

typedef PlaylistSongActionResolver =
    SongActionMenuConfiguration Function(Song song);
typedef PlaylistSongMoveCallback = void Function(int oldIndex, int targetIndex);

/// A dedicated, Local-First playlist detail surface that stays inside the
/// catalog scroll view on touch, desktop and TV layouts.
class LocalPlaylistWorkspace extends StatefulWidget {
  const LocalPlaylistWorkspace({
    super.key,
    required this.playlist,
    required this.tvMode,
    this.showBack = true,
    required this.currentSongId,
    required this.isPlaying,
    required this.onBack,
    required this.onPlayAll,
    required this.onShuffle,
    required this.onRename,
    required this.onDelete,
    required this.onSongTap,
    required this.onReorderItem,
    required this.onMoveItem,
    required this.onRemove,
    required this.actionResolver,
  });

  final LocalPlaylist playlist;
  final bool tvMode;
  final bool showBack;
  final String? currentSongId;
  final bool isPlaying;
  final VoidCallback onBack;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final ValueChanged<Song> onSongTap;
  final ReorderCallback onReorderItem;
  final PlaylistSongMoveCallback onMoveItem;
  final ValueChanged<Song> onRemove;
  final PlaylistSongActionResolver actionResolver;

  @override
  State<LocalPlaylistWorkspace> createState() => _LocalPlaylistWorkspaceState();
}

class LocalPlaylistMissingState extends StatelessWidget {
  const LocalPlaylistMissingState({super.key, required this.onBackToPlaylists});

  final VoidCallback onBackToPlaylists;

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('local-playlist-missing'),
    padding: const EdgeInsets.fromLTRB(24, 72, 24, 80),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.playlist_remove_rounded,
              size: 64,
              color: Theme.of(context).brightness == Brightness.dark
                  ? ZingColors.purpleBright
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              'Không tìm thấy playlist',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 9),
            Text(
              'Playlist có thể đã bị xóa hoặc liên kết này thuộc một thiết bị khác.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              key: const ValueKey('local-playlist-missing-back'),
              onPressed: onBackToPlaylists,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Về danh sách playlist'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LocalPlaylistWorkspaceState extends State<LocalPlaylistWorkspace> {
  var _editing = false;

  @override
  void didUpdateWidget(covariant LocalPlaylistWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playlist.id != widget.playlist.id ||
        widget.playlist.songs.isEmpty) {
      _editing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final songs = widget.playlist.songs;
    final horizontalPadding = widget.tvMode ? 34.0 : 20.0;
    return SliverMainAxisGroup(
      key: ValueKey('local-playlist-workspace-${widget.playlist.id}'),
      slivers: [
        SliverToBoxAdapter(child: _buildHero(context)),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              widget.tvMode ? 34 : 26,
              horizontalPadding,
              14,
            ),
            child: _PlaylistSectionHeading(
              songCount: songs.length,
              editing: _editing,
              tvMode: widget.tvMode,
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
              child: const _EmptyPlaylistState(),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              widget.tvMode ? 64 : 42,
            ),
            sliver: _editing && !widget.tvMode
                ? SliverReorderableList(
                    key: const ValueKey('local-playlist-track-list'),
                    itemCount: songs.length,
                    findChildIndexCallback: (key) =>
                        _songIndexForKey(songs, key),
                    onReorderItem: widget.onReorderItem,
                    itemBuilder: (context, index) => _PlaylistSongRow(
                      key: ValueKey('local-playlist-song-${songs[index].id}'),
                      song: songs[index],
                      index: index,
                      songCount: songs.length,
                      editing: true,
                      tvMode: false,
                      current: widget.currentSongId == songs[index].id,
                      playing: widget.isPlaying,
                      onTap: () => widget.onSongTap(songs[index]),
                      onRemove: () => widget.onRemove(songs[index]),
                      onMoveUp: null,
                      onMoveDown: null,
                      actions: widget.actionResolver(songs[index]),
                    ),
                  )
                : SliverList.builder(
                    key: const ValueKey('local-playlist-track-list'),
                    itemCount: songs.length,
                    findChildIndexCallback: (key) =>
                        _songIndexForKey(songs, key),
                    itemBuilder: (context, index) => _PlaylistSongRow(
                      key: ValueKey('local-playlist-song-${songs[index].id}'),
                      song: songs[index],
                      index: index,
                      songCount: songs.length,
                      editing: _editing,
                      tvMode: widget.tvMode,
                      current: widget.currentSongId == songs[index].id,
                      playing: widget.isPlaying,
                      onTap: () => widget.onSongTap(songs[index]),
                      onRemove: () => widget.onRemove(songs[index]),
                      onMoveUp: index == 0
                          ? null
                          : () => widget.onMoveItem(index, index - 1),
                      onMoveDown: index == songs.length - 1
                          ? null
                          : () => widget.onMoveItem(index, index + 1),
                      actions: widget.actionResolver(songs[index]),
                    ),
                  ),
          ),
      ],
    );
  }

  int? _songIndexForKey(List<Song> songs, Key key) {
    for (var index = 0; index < songs.length; index++) {
      if (key == ValueKey('local-playlist-song-${songs[index].id}')) {
        return index;
      }
    }
    return null;
  }

  Widget _buildHero(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: const ValueKey('local-playlist-hero'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF4A1D69), Color(0xFF251231), ZingColors.ink]
              : const [Color(0xFFE7D1F7), Color(0xFFF3E8F8), ZingColors.paper],
          stops: const [0, 0.58, 1],
        ),
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.38),
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          widget.tvMode ? 34 : 20,
          widget.tvMode ? 24 : 14,
          widget.tvMode ? 34 : 20,
          widget.tvMode ? 40 : 30,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = !widget.tvMode && constraints.maxWidth < 720;
            final coverSize = widget.tvMode
                ? 270.0
                : compact
                ? 188.0
                : 224.0;
            final details = _PlaylistHeroDetails(
              playlist: widget.playlist,
              tvMode: widget.tvMode,
              compact: compact,
              editing: _editing,
              onPlayAll: widget.playlist.songs.isEmpty
                  ? null
                  : widget.onPlayAll,
              onShuffle: widget.playlist.songs.length < 2
                  ? null
                  : widget.onShuffle,
              onEdit: widget.playlist.songs.isEmpty
                  ? null
                  : () => setState(() => _editing = !_editing),
              onRename: widget.onRename,
              onDelete: widget.onDelete,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showBack) ...[
                  IconButton.filledTonal(
                    key: const ValueKey('local-playlist-back'),
                    tooltip: 'Quay lại danh sách playlist',
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  SizedBox(height: widget.tvMode ? 28 : 20),
                ],
                if (compact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: _PlaylistCoverMosaic(
                          songs: widget.playlist.songs,
                          size: coverSize,
                        ),
                      ),
                      const SizedBox(height: 24),
                      details,
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _PlaylistCoverMosaic(
                        songs: widget.playlist.songs,
                        size: coverSize,
                      ),
                      SizedBox(width: widget.tvMode ? 38 : 30),
                      Expanded(child: details),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlaylistHeroDetails extends StatelessWidget {
  const _PlaylistHeroDetails({
    required this.playlist,
    required this.tvMode,
    required this.compact,
    required this.editing,
    required this.onPlayAll,
    required this.onShuffle,
    required this.onEdit,
    required this.onRename,
    required this.onDelete,
  });

  final LocalPlaylist playlist;
  final bool tvMode;
  final bool compact;
  final bool editing;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffle;
  final VoidCallback? onEdit;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = Theme.of(context).brightness == Brightness.dark
        ? ZingColors.purpleBright
        : scheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PLAYLIST CÁ NHÂN · LOCAL-FIRST',
          style: TextStyle(
            color: accent,
            fontSize: tvMode ? 15 : 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: tvMode ? 14 : 9),
        Text(
          playlist.name,
          key: const ValueKey('local-playlist-title'),
          maxLines: compact ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: tvMode
                ? 52
                : compact
                ? 34
                : 44,
            height: 1.02,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.3,
          ),
        ),
        SizedBox(height: tvMode ? 16 : 12),
        Text(
          '${playlist.songs.length} bài hát · chỉ lưu trên thiết bị này',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: tvMode ? 18 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: tvMode ? 28 : 22),
        Wrap(
          spacing: tvMode ? 14 : 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              key: const ValueKey('local-playlist-play'),
              onPressed: onPlayAll,
              style: FilledButton.styleFrom(
                minimumSize: Size(tvMode ? 164 : 128, tvMode ? 58 : 48),
                backgroundColor: ZingColors.purple,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Phát tất cả'),
            ),
            FilledButton.tonalIcon(
              key: const ValueKey('local-playlist-shuffle'),
              onPressed: onShuffle,
              style: FilledButton.styleFrom(
                minimumSize: Size(tvMode ? 150 : 116, tvMode ? 58 : 48),
              ),
              icon: const Icon(Icons.shuffle_rounded),
              label: const Text('Trộn bài'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('local-playlist-edit'),
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                minimumSize: Size(tvMode ? 132 : 104, tvMode ? 58 : 48),
              ),
              icon: Icon(
                editing ? Icons.check_rounded : Icons.edit_note_rounded,
              ),
              label: Text(editing ? 'Xong' : 'Sắp xếp'),
            ),
            IconButton.outlined(
              key: const ValueKey('local-playlist-rename'),
              tooltip: 'Đổi tên playlist',
              onPressed: onRename,
              style: IconButton.styleFrom(
                minimumSize: Size.square(tvMode ? 58 : 48),
              ),
              icon: const Icon(Icons.drive_file_rename_outline_rounded),
            ),
            IconButton.outlined(
              key: const ValueKey('local-playlist-delete'),
              tooltip: 'Xóa playlist',
              onPressed: onDelete,
              style: IconButton.styleFrom(
                minimumSize: Size.square(tvMode ? 58 : 48),
                foregroundColor: ZingColors.coral,
              ),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlaylistCoverMosaic extends StatelessWidget {
  const _PlaylistCoverMosaic({required this.songs, required this.size});

  final List<Song> songs;
  final double size;

  @override
  Widget build(BuildContext context) {
    final visibleSongs = songs.take(4).toList(growable: false);
    return Container(
      key: const ValueKey('local-playlist-cover'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.11),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 34,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.11),
        child: visibleSongs.isEmpty
            ? const _PlaylistCoverFallback()
            : GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                itemCount: 4,
                itemBuilder: (context, index) {
                  if (index >= visibleSongs.length) {
                    return _PlaylistCoverFallback(
                      compact: true,
                      paletteIndex: index,
                    );
                  }
                  final song = visibleSongs[index];
                  if (song.thumbnail.trim().isEmpty) {
                    return _PlaylistCoverFallback(
                      compact: true,
                      paletteIndex: index,
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
    );
  }
}

class _PlaylistCoverFallback extends StatelessWidget {
  const _PlaylistCoverFallback({this.compact = false, this.paletteIndex = 0});

  final bool compact;
  final int paletteIndex;

  @override
  Widget build(BuildContext context) {
    final colors = switch (paletteIndex % 4) {
      0 => const [Color(0xFF9B4DE0), Color(0xFFED2B91)],
      1 => const [Color(0xFF4A90E2), Color(0xFF7D4CE0)],
      2 => const [Color(0xFF27C9A0), Color(0xFF167A96)],
      _ => const [Color(0xFFF06A50), Color(0xFFB83280)],
    };
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
          Icons.library_music_rounded,
          size: compact ? 34 : 78,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _PlaylistSectionHeading extends StatelessWidget {
  const _PlaylistSectionHeading({
    required this.songCount,
    required this.editing,
    required this.tvMode,
  });

  final int songCount;
  final bool editing;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bài hát trong playlist',
              style: TextStyle(
                fontSize: tvMode ? 30 : 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              editing
                  ? tvMode
                        ? 'Dùng nút Lên/Xuống để đổi thứ tự · Xóa không ảnh hưởng bài gốc'
                        : 'Kéo tay nắm để đổi thứ tự · Xóa có thể hoàn tác'
                  : '$songCount bài · thứ tự được lưu tự động trên máy',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: tvMode ? 16 : 13,
              ),
            ),
          ],
        ),
      ),
      if (editing)
        const Padding(
          padding: EdgeInsets.only(left: 12, bottom: 2),
          child: Icon(Icons.sync_rounded, color: ZingColors.lime),
        ),
    ],
  );
}

class _EmptyPlaylistState extends StatelessWidget {
  const _EmptyPlaylistState();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('local-playlist-empty'),
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
        const Icon(
          Icons.playlist_add_rounded,
          size: 54,
          color: ZingColors.purpleBright,
        ),
        const SizedBox(height: 14),
        Text(
          'Playlist này chưa có bài hát',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        Text(
          'Mở menu của một bài hát rồi chọn “Thêm vào playlist”.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _PlaylistSongRow extends StatefulWidget {
  const _PlaylistSongRow({
    super.key,
    required this.song,
    required this.index,
    required this.songCount,
    required this.editing,
    required this.tvMode,
    required this.current,
    required this.playing,
    required this.onTap,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.actions,
  });

  final Song song;
  final int index;
  final int songCount;
  final bool editing;
  final bool tvMode;
  final bool current;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final SongActionMenuConfiguration actions;

  @override
  State<_PlaylistSongRow> createState() => _PlaylistSongRowState();
}

class _PlaylistSongRowState extends State<_PlaylistSongRow> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final activeColor = Theme.of(context).brightness == Brightness.dark
        ? ZingColors.purpleBright
        : scheme.primary;
    final compact = !widget.tvMode && MediaQuery.sizeOf(context).width < 560;
    final highlighted = widget.current || _hovered || _focused;
    final radius = BorderRadius.circular(widget.tvMode ? 16 : 12);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: highlighted
                ? ZingColors.purple.withValues(
                    alpha: widget.current ? 0.17 : 0.09,
                  )
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
            child: InkWell(
              onFocusChange: (value) => setState(() => _focused = value),
              onTap: widget.editing ? null : widget.onTap,
              onSecondaryTapDown: widget.editing
                  ? null
                  : (details) => unawaited(
                      showSongActionContextMenu(
                        context: context,
                        globalPosition: details.globalPosition,
                        keyPrefix: 'local-playlist-action',
                        song: widget.song,
                        handlers: widget.actions.handlers,
                        isLiked: widget.actions.isLiked,
                        moods: widget.actions.moods,
                      ),
                    ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.tvMode ? 16 : 10,
                  vertical: widget.tvMode ? 12 : 8,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: widget.tvMode ? 50 : 36,
                      child: widget.current
                          ? Icon(
                              widget.playing
                                  ? Icons.graphic_eq_rounded
                                  : Icons.pause_circle_outline_rounded,
                              color: activeColor,
                            )
                          : Text(
                              '${widget.index + 1}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                    AlbumArt(
                      imageUrl: widget.song.thumbnail,
                      semanticLabel: 'Bìa ${widget.song.displayTitle}',
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
                            widget.song.artistsNames.isEmpty
                                ? 'Nghệ sĩ chưa xác định'
                                : widget.song.artistsNames,
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
                    if (!compact && !widget.editing) ...[
                      const SizedBox(width: 12),
                      Text(
                        'LOCAL',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                    SizedBox(width: widget.tvMode ? 16 : 6),
                    if (widget.editing) ...[
                      if (widget.tvMode) ...[
                        IconButton.outlined(
                          key: ValueKey(
                            'local-playlist-move-up-${widget.song.id}',
                          ),
                          tooltip: 'Di chuyển lên',
                          onPressed: widget.onMoveUp,
                          icon: const Icon(Icons.keyboard_arrow_up_rounded),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          key: ValueKey(
                            'local-playlist-move-down-${widget.song.id}',
                          ),
                          tooltip: 'Di chuyển xuống',
                          onPressed: widget.onMoveDown,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                        const SizedBox(width: 8),
                      ],
                      IconButton(
                        key: ValueKey(
                          'local-playlist-remove-${widget.song.id}',
                        ),
                        tooltip: 'Xóa khỏi playlist',
                        onPressed: widget.onRemove,
                        color: ZingColors.coral,
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
                      if (!widget.tvMode)
                        ReorderableDragStartListener(
                          key: ValueKey(
                            'local-playlist-handle-${widget.song.id}',
                          ),
                          index: widget.index,
                          child: Tooltip(
                            message: 'Kéo để sắp xếp',
                            child: SizedBox.square(
                              dimension: 48,
                              child: Icon(
                                Icons.drag_handle_rounded,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                    ] else
                      SongActionOverflowButton(
                        keyPrefix: 'local-playlist-action',
                        song: widget.song,
                        handlers: widget.actions.handlers,
                        isLiked: widget.actions.isLiked,
                        moods: widget.actions.moods,
                        iconSize: widget.tvMode ? 30 : 24,
                        iconColor: scheme.onSurfaceVariant,
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
