import 'dart:async';

import 'package:flutter/material.dart';

import '../models/local_library.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';
import 'song_action_menu.dart';

typedef HistorySongActionResolver =
    SongActionMenuConfiguration Function(Song song);

@immutable
class LocalHistoryDayGroup {
  const LocalHistoryDayGroup({
    required this.day,
    required this.label,
    required this.records,
  });

  final DateTime day;
  final String label;
  final List<ListeningRecord> records;
}

/// Returns the newest occurrence of every song for a stable playback queue.
/// The input is copied because starting playback immediately adds a new record.
List<Song> buildRecentPlaybackQueue(Iterable<ListeningRecord> records) {
  final ordered = normalizeListeningHistory(records);
  final seen = <String>{};
  return List<Song>.unmodifiable(
    ordered
        .map((record) => record.song)
        .where((song) => song.id.isNotEmpty && seen.add(song.id)),
  );
}

/// Applies the same newest-first and record-ID validation used by every
/// history surface. Imported snapshots can contain arbitrary ordering or a
/// duplicated record ID, so playback and visible history must share this view.
List<ListeningRecord> normalizeListeningHistory(
  Iterable<ListeningRecord> records,
) {
  final ordered = records.toList(growable: false)
    ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
  final seenRecordIds = <String>{};
  return List<ListeningRecord>.unmodifiable(
    ordered.where(
      (record) => record.id.isNotEmpty && seenRecordIds.add(record.id),
    ),
  );
}

/// Groups persisted UTC timestamps by the device's local calendar day.
List<LocalHistoryDayGroup> groupListeningHistory(
  Iterable<ListeningRecord> records, {
  DateTime? now,
}) {
  final ordered = normalizeListeningHistory(records);
  final localNow = (now ?? DateTime.now()).toLocal();
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  final grouped = <DateTime, List<ListeningRecord>>{};
  for (final record in ordered) {
    final local = record.playedAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    grouped.putIfAbsent(day, () => <ListeningRecord>[]).add(record);
  }
  return List<LocalHistoryDayGroup>.unmodifiable(
    grouped.entries.map(
      (entry) => LocalHistoryDayGroup(
        day: entry.key,
        label: entry.key == today
            ? 'Hôm nay'
            : entry.key == yesterday
            ? 'Hôm qua'
            : _longDateLabel(entry.key),
        records: List<ListeningRecord>.unmodifiable(entry.value),
      ),
    ),
  );
}

/// A private, on-device history surface shared by touch, desktop and TV.
class LocalHistoryWorkspace extends StatelessWidget {
  const LocalHistoryWorkspace({
    super.key,
    required this.records,
    required this.tvMode,
    this.showBack = true,
    required this.currentSongId,
    required this.isPlaying,
    required this.onBack,
    required this.onPlayAll,
    required this.onShuffle,
    required this.onClear,
    required this.onRecordTap,
    required this.actionResolver,
    this.now,
  });

  final List<ListeningRecord> records;
  final bool tvMode;
  final bool showBack;
  final String? currentSongId;
  final bool isPlaying;
  final VoidCallback onBack;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;
  final VoidCallback onClear;
  final ValueChanged<ListeningRecord> onRecordTap;
  final HistorySongActionResolver actionResolver;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final groups = groupListeningHistory(records, now: now);
    final normalizedRecords = groups
        .expand((group) => group.records)
        .toList(growable: false);
    final queue = buildRecentPlaybackQueue(normalizedRecords);
    final eligibleQueue = queue
        .where((song) => song.isPlaybackEligible)
        .toList(growable: false);
    final activeRecordId = _activeRecordId(normalizedRecords, currentSongId);
    final horizontalPadding = tvMode ? 34.0 : 20.0;
    return SliverMainAxisGroup(
      key: const ValueKey('local-history-workspace'),
      slivers: [
        SliverToBoxAdapter(
          child: _HistoryHero(
            records: normalizedRecords,
            queue: queue,
            eligibleSongCount: eligibleQueue.length,
            tvMode: tvMode,
            showBack: showBack,
            onBack: onBack,
            onPlayAll: eligibleQueue.isEmpty ? null : onPlayAll,
            onShuffle: eligibleQueue.length < 2 ? null : onShuffle,
            onClear: normalizedRecords.isEmpty ? null : onClear,
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
            child: _HistorySectionHeading(
              recordCount: normalizedRecords.length,
              songCount: queue.length,
              eligibleSongCount: eligibleQueue.length,
              tvMode: tvMode,
            ),
          ),
        ),
        if (normalizedRecords.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                52,
              ),
              child: const _EmptyHistoryState(),
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
              key: const ValueKey('local-history-record-list'),
              itemCount: normalizedRecords.length,
              findChildIndexCallback: (key) =>
                  _recordIndexForKey(normalizedRecords, key),
              itemBuilder: (context, index) {
                final record = normalizedRecords[index];
                final previous = index == 0
                    ? null
                    : normalizedRecords[index - 1];
                final showDay =
                    previous == null ||
                    !_sameLocalDay(previous.playedAt, record.playedAt);
                return KeyedSubtree(
                  key: ValueKey('local-history-record-${record.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showDay)
                        _HistoryDayHeading(
                          label: _labelForRecord(groups, record),
                          day: _localDay(record.playedAt),
                          tvMode: tvMode,
                        ),
                      _HistoryRecordRow(
                        key: ValueKey('local-history-row-${record.id}'),
                        record: record,
                        tvMode: tvMode,
                        current: activeRecordId == record.id,
                        playing: isPlaying,
                        onTap: record.song.isPlaybackEligible
                            ? () => onRecordTap(record)
                            : null,
                        actions: actionResolver(record.song),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  int? _recordIndexForKey(List<ListeningRecord> records, Key key) {
    for (var index = 0; index < records.length; index++) {
      if (key == ValueKey('local-history-record-${records[index].id}')) {
        return index;
      }
    }
    return null;
  }

  String _labelForRecord(
    List<LocalHistoryDayGroup> groups,
    ListeningRecord record,
  ) {
    final local = record.playedAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    return groups.firstWhere((group) => group.day == day).label;
  }
}

class _HistoryHero extends StatelessWidget {
  const _HistoryHero({
    required this.records,
    required this.queue,
    required this.eligibleSongCount,
    required this.tvMode,
    required this.showBack,
    required this.onBack,
    required this.onPlayAll,
    required this.onShuffle,
    required this.onClear,
  });

  final List<ListeningRecord> records;
  final List<Song> queue;
  final int eligibleSongCount;
  final bool tvMode;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffle;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final listened = records.fold(
      Duration.zero,
      (total, record) => total + record.listened,
    );
    return Container(
      key: const ValueKey('local-history-hero'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF124C58), Color(0xFF2C1A4B), ZingColors.ink]
              : const [Color(0xFFCDEFE8), Color(0xFFE8DDF5), ZingColors.paper],
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
          tvMode ? 34 : 20,
          tvMode ? 24 : 14,
          tvMode ? 34 : 20,
          tvMode ? 40 : 30,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = !tvMode && constraints.maxWidth < 720;
            final coverSize = tvMode
                ? 270.0
                : compact
                ? 176.0
                : 224.0;
            final cover = _HistoryMosaic(songs: queue, size: coverSize);
            final details = _HistoryHeroDetails(
              recordCount: records.length,
              songCount: queue.length,
              eligibleSongCount: eligibleSongCount,
              listened: listened,
              tvMode: tvMode,
              compact: compact,
              showBack: showBack,
              onBack: onBack,
              onPlayAll: onPlayAll,
              onShuffle: onShuffle,
              onClear: onClear,
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showBack) ...[
                    _BackButton(onPressed: onBack),
                    const SizedBox(height: 14),
                  ],
                  Center(child: cover),
                  const SizedBox(height: 22),
                  details,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                cover,
                SizedBox(width: tvMode ? 36 : 28),
                Expanded(child: details),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HistoryHeroDetails extends StatelessWidget {
  const _HistoryHeroDetails({
    required this.recordCount,
    required this.songCount,
    required this.eligibleSongCount,
    required this.listened,
    required this.tvMode,
    required this.compact,
    required this.showBack,
    required this.onBack,
    required this.onPlayAll,
    required this.onShuffle,
    required this.onClear,
  });

  final int recordCount;
  final int songCount;
  final int eligibleSongCount;
  final Duration listened;
  final bool tvMode;
  final bool compact;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffle;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final buttonHeight = tvMode ? 58.0 : 48.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBack && !compact) ...[
          _BackButton(onPressed: onBack),
          SizedBox(height: tvMode ? 22 : 16),
        ],
        Text(
          'LỊCH SỬ LOCAL · RIÊNG TƯ',
          style: TextStyle(
            color: dark ? ZingColors.lime : scheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.55,
          ),
        ),
        SizedBox(height: tvMode ? 10 : 7),
        Text(
          'Nghe gần đây',
          style: TextStyle(
            fontSize: tvMode
                ? 48
                : compact
                ? 34
                : 42,
            height: 1.02,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          '$recordCount lượt nghe · ${_heroSongCountLabel(songCount, eligibleSongCount)} · ${_durationLabel(listened)}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: tvMode ? 17 : 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: tvMode ? 14 : 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: ZingColors.lime.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: ZingColors.lime.withValues(alpha: 0.34)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(
              'Chỉ lưu trên thiết bị · không gửi lên proxy',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? ZingColors.lime
                    : const Color(0xFF176A58),
                fontSize: tvMode ? 14 : 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        SizedBox(height: tvMode ? 28 : 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              key: const ValueKey('local-history-play'),
              onPressed: onPlayAll,
              style: FilledButton.styleFrom(minimumSize: Size(0, buttonHeight)),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Phát tất cả'),
            ),
            FilledButton.tonalIcon(
              key: const ValueKey('local-history-shuffle'),
              onPressed: onShuffle,
              style: FilledButton.styleFrom(minimumSize: Size(0, buttonHeight)),
              icon: const Icon(Icons.shuffle_rounded),
              label: const Text('Trộn bài'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('local-history-clear'),
              onPressed: onClear,
              style: OutlinedButton.styleFrom(
                foregroundColor: dark ? ZingColors.coral : scheme.error,
                minimumSize: Size(0, buttonHeight),
              ),
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Xóa dữ liệu nghe'),
            ),
          ],
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: const ValueKey('local-history-back'),
    onPressed: onPressed,
    icon: const Icon(Icons.arrow_back_rounded),
    label: const Text('Thư viện'),
  );
}

class _HistoryMosaic extends StatelessWidget {
  const _HistoryMosaic({required this.songs, required this.size});

  final List<Song> songs;
  final double size;

  @override
  Widget build(BuildContext context) {
    final visible = songs.take(4).toList(growable: false);
    return Semantics(
      image: true,
      label: 'Ảnh ghép các bài nghe gần đây',
      child: Container(
        key: const ValueKey('local-history-mosaic'),
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.075),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ExcludeSemantics(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              final song = index < visible.length ? visible[index] : null;
              if (song == null || song.thumbnail.trim().isEmpty) {
                return _HistoryCoverFallback(index: index);
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

class _HistoryCoverFallback extends StatelessWidget {
  const _HistoryCoverFallback({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = switch (index % 4) {
      0 => const [Color(0xFF1DAA8A), Color(0xFF176A96)],
      1 => const [Color(0xFF9B4DE0), Color(0xFF4A5FE0)],
      2 => const [Color(0xFFF06A50), Color(0xFFB83280)],
      _ => const [Color(0xFF314E8F), Color(0xFF23183E)],
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: const Center(
        child: Icon(Icons.history_rounded, size: 44, color: Colors.white),
      ),
    );
  }
}

class _HistorySectionHeading extends StatelessWidget {
  const _HistorySectionHeading({
    required this.recordCount,
    required this.songCount,
    required this.eligibleSongCount,
    required this.tvMode,
  });

  final int recordCount;
  final int songCount;
  final int eligibleSongCount;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Lịch sử nghe',
        style: TextStyle(
          fontSize: tvMode ? 30 : 23,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        recordCount == 0
            ? 'Phát một bài để bắt đầu lịch sử riêng tư trên thiết bị.'
            : '$recordCount lượt · $songCount bài không trùng${eligibleSongCount == songCount ? '' : ' · $eligibleSongCount có thể phát'} · mới nhất trước',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: tvMode ? 16 : 13,
        ),
      ),
    ],
  );
}

class _HistoryDayHeading extends StatelessWidget {
  const _HistoryDayHeading({
    required this.label,
    required this.day,
    required this.tvMode,
  });

  final String label;
  final DateTime day;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      key: ValueKey(
        'local-history-day-${day.year}-${_twoDigits(day.month)}-${_twoDigits(day.day)}',
      ),
      padding: EdgeInsets.fromLTRB(4, tvMode ? 24 : 18, 4, tvMode ? 12 : 8),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? ZingColors.lime
              : Theme.of(context).colorScheme.primary,
          fontSize: tvMode ? 18 : 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.75,
        ),
      ),
    ),
  );
}

class _HistoryRecordRow extends StatefulWidget {
  const _HistoryRecordRow({
    super.key,
    required this.record,
    required this.tvMode,
    required this.current,
    required this.playing,
    required this.onTap,
    required this.actions,
  });

  final ListeningRecord record;
  final bool tvMode;
  final bool current;
  final bool playing;
  final VoidCallback? onTap;
  final SongActionMenuConfiguration actions;

  @override
  State<_HistoryRecordRow> createState() => _HistoryRecordRowState();
}

class _HistoryRecordRowState extends State<_HistoryRecordRow> {
  late final FocusNode _focusNode;
  var _hovered = false;
  var _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      debugLabel: 'local-history-focus-${widget.record.id}',
    );
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
      final activeColor = Theme.of(context).brightness == Brightness.dark
          ? ZingColors.purpleBright
          : scheme.primary;
      final highlighted = widget.current || _hovered || _focused;
      final radius = BorderRadius.circular(widget.tvMode ? 16 : 12);
      final song = widget.record.song;
      final canPlay = song.isPlaybackEligible;
      final localTime = widget.record.playedAt.toLocal();
      final artist = song.artistsNames.isEmpty
          ? 'Nghệ sĩ chưa xác định'
          : song.artistsNames;
      final semanticLabel =
          '${song.displayTitle}, $artist, lúc ${_timeLabel(localTime)}, ${_durationLabel(widget.record.listened)}'
          '${canPlay ? '' : ', không thể phát từ lịch sử cũ'}';
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: MouseRegion(
          cursor: canPlay
              ? SystemMouseCursors.click
              : SystemMouseCursors.forbidden,
          onEnter: canPlay ? (_) => setState(() => _hovered = true) : null,
          onExit: canPlay ? (_) => setState(() => _hovered = false) : null,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
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
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      key: ValueKey(
                        'local-history-play-target-${widget.record.id}',
                      ),
                      button: true,
                      enabled: canPlay,
                      selected: canPlay && widget.current,
                      label: semanticLabel,
                      onTap: canPlay ? widget.onTap : null,
                      excludeSemantics: true,
                      child: InkWell(
                        focusNode: _focusNode,
                        canRequestFocus: canPlay,
                        excludeFromSemantics: true,
                        onFocusChange: _handleFocusChange,
                        mouseCursor: canPlay
                            ? SystemMouseCursors.click
                            : SystemMouseCursors.forbidden,
                        onTap: canPlay ? widget.onTap : null,
                        onSecondaryTapDown: widget.actions.handlers.hasAny
                            ? (details) => unawaited(
                                showSongActionContextMenu(
                                  context: context,
                                  globalPosition: details.globalPosition,
                                  keyPrefix:
                                      'local-history-action-${widget.record.id}',
                                  song: song,
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
                                width: widget.tvMode ? 46 : 34,
                                child: !canPlay
                                    ? Tooltip(
                                        message: 'Không thể phát từ lịch sử cũ',
                                        child: Icon(
                                          Icons.lock_outline_rounded,
                                          key: ValueKey(
                                            'local-history-lock-${widget.record.id}',
                                          ),
                                          size: widget.tvMode ? 26 : 20,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      )
                                    : widget.current
                                    ? Icon(
                                        widget.playing
                                            ? Icons.graphic_eq_rounded
                                            : Icons
                                                  .pause_circle_outline_rounded,
                                        color: activeColor,
                                      )
                                    : Icon(
                                        Icons.history_rounded,
                                        size: widget.tvMode ? 26 : 20,
                                        color: scheme.onSurfaceVariant,
                                      ),
                              ),
                              AlbumArt(
                                imageUrl: song.thumbnail,
                                semanticLabel: 'Bìa ${song.displayTitle}',
                                size: widget.tvMode ? 68 : 50,
                                borderRadius: widget.tvMode ? 11 : 8,
                              ),
                              SizedBox(width: widget.tvMode ? 18 : 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song.displayTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: widget.current && canPlay
                                            ? activeColor
                                            : canPlay
                                            ? scheme.onSurface
                                            : scheme.onSurfaceVariant,
                                        fontSize: widget.tvMode ? 20 : 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      compact
                                          ? '$artist · ${_timeLabel(localTime)} · ${_durationLabel(widget.record.listened)}'
                                          : artist,
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
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: widget.tvMode ? 116 : 92,
                                  child: _HistoryMetadata(
                                    label: 'THỜI ĐIỂM',
                                    value: _timeLabel(localTime),
                                    tvMode: widget.tvMode,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                SizedBox(
                                  width: widget.tvMode ? 146 : 116,
                                  child: _HistoryMetadata(
                                    label: 'ĐÃ NGHE',
                                    value: _durationLabel(
                                      widget.record.listened,
                                    ),
                                    tvMode: widget.tvMode,
                                  ),
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
                      keyPrefix: 'local-history-action-${widget.record.id}',
                      song: song,
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

class _HistoryMetadata extends StatelessWidget {
  const _HistoryMetadata({
    required this.label,
    required this.value,
    required this.tvMode,
  });

  final String label;
  final String value;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: tvMode ? 10 : 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: tvMode ? 15 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('local-history-empty'),
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
        const Icon(Icons.history_toggle_off_rounded, size: 54),
        const SizedBox(height: 14),
        Text(
          'Chưa có lịch sử nghe',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        Text(
          'Chọn phát một bài hát. Lịch sử và thời gian nghe chỉ được lưu trên thiết bị này.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

bool _sameLocalDay(DateTime first, DateTime second) {
  final a = first.toLocal();
  final b = second.toLocal();
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime _localDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String? _activeRecordId(List<ListeningRecord> records, String? currentSongId) {
  if (currentSongId == null) return null;
  for (final record in records) {
    if (record.song.isPlaybackEligible && record.song.id == currentSongId) {
      return record.id;
    }
  }
  return null;
}

String _heroSongCountLabel(int songCount, int eligibleSongCount) {
  if (songCount == eligibleSongCount) return '$songCount bài';
  return '$eligibleSongCount/$songCount bài có thể phát';
}

String _longDateLabel(DateTime day) {
  const weekdays = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];
  return '${weekdays[day.weekday - 1]}, ${_twoDigits(day.day)}/${_twoDigits(day.month)}/${day.year}';
}

String _timeLabel(DateTime localTime) =>
    '${_twoDigits(localTime.hour)}:${_twoDigits(localTime.minute)}';

String _durationLabel(Duration duration) {
  if (duration < const Duration(seconds: 1)) return 'vừa mở';
  if (duration < const Duration(minutes: 1)) {
    return '${duration.inSeconds} giây';
  }
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  return seconds == 0 ? '$minutes phút' : '$minutes phút $seconds giây';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
