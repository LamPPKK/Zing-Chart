import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/song.dart';
import '../models/song_lyrics.dart';
import '../music_player_controller.dart';
import '../services/lyric_share_image_renderer.dart';
import '../services/wrapped_export_service.dart';
import '../zing_mp3_api.dart';
import 'album_art.dart';
import 'lyric_share_composer.dart';

typedef SongLyricsLoader = Future<SongLyrics> Function(String code);

enum _LyricsViewMode { karaoke, lyrics }

Future<void> showSongLyrics(
  BuildContext context, {
  required MusicPlayerController controller,
  SongLyricsLoader? lyricsLoader,
  bool tvMode = false,
}) {
  final loader = lyricsLoader ?? ZingMP3API.getSongLyrics;
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 900 || tvMode) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogContext) => Dialog.fullscreen(
        child: SongLyricsPanel(
          controller: controller,
          lyricsLoader: loader,
          tvMode: tvMode,
          onClose: () => Navigator.pop(dialogContext),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.94,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: SongLyricsPanel(
          controller: controller,
          lyricsLoader: loader,
          onClose: () => Navigator.pop(sheetContext),
        ),
      ),
    ),
  );
}

class SongLyricsPanel extends StatefulWidget {
  const SongLyricsPanel({
    super.key,
    required this.controller,
    required this.lyricsLoader,
    required this.onClose,
    this.tvMode = false,
    this.initialKaraoke = false,
    this.embedded = false,
    this.onExpand,
    this.shareExportService,
    this.shareImageRenderer,
  });

  final MusicPlayerController controller;
  final SongLyricsLoader lyricsLoader;
  final VoidCallback onClose;
  final bool tvMode;
  final bool initialKaraoke;
  final bool embedded;
  final VoidCallback? onExpand;
  final WrappedExportService? shareExportService;
  final LyricShareImageRenderer? shareImageRenderer;

  @override
  State<SongLyricsPanel> createState() => _SongLyricsPanelState();
}

class _SongLyricsPanelState extends State<SongLyricsPanel> {
  final ScrollController _scrollController = ScrollController();
  SongLyrics? _lyrics;
  String? _errorMessage;
  String? _loadedSongId;
  bool _isLoading = false;
  int _requestId = 0;
  int _activeLine = -1;
  int _activeWord = -1;
  late _LyricsViewMode _viewMode;
  List<GlobalKey> _lineKeys = const [];

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialKaraoke
        ? _LyricsViewMode.karaoke
        : _LyricsViewMode.lyrics;
    widget.controller.addListener(_handlePlaybackChanged);
    unawaited(_loadCurrentLyrics());
  }

  @override
  void didUpdateWidget(covariant SongLyricsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handlePlaybackChanged);
      widget.controller.addListener(_handlePlaybackChanged);
      _loadedSongId = null;
      unawaited(_loadCurrentLyrics());
    }
  }

  void _handlePlaybackChanged() {
    final song = widget.controller.currentSong;
    if (song?.id != _loadedSongId) {
      unawaited(_loadCurrentLyrics());
      return;
    }
    final lyrics = _lyrics;
    final nextLine = lyrics?.activeLineIndex(widget.controller.position) ?? -1;
    final nextWord = nextLine >= 0 && lyrics != null
        ? lyrics.lines[nextLine].activeWordIndex(widget.controller.position)
        : -1;
    if ((nextLine == _activeLine && nextWord == _activeWord) || !mounted) {
      return;
    }
    final lineChanged = nextLine != _activeLine;
    setState(() {
      _activeLine = nextLine;
      _activeWord = nextWord;
    });
    if (lineChanged && _viewMode == _LyricsViewMode.lyrics) {
      _scrollToActiveLine();
    }
  }

  Future<void> _loadCurrentLyrics() async {
    final song = widget.controller.currentSong;
    final requestId = ++_requestId;
    if (song == null) {
      if (!mounted) return;
      setState(() {
        _loadedSongId = null;
        _lyrics = null;
        _isLoading = false;
        _errorMessage = null;
        _activeLine = -1;
        _activeWord = -1;
        _lineKeys = const [];
      });
      return;
    }
    if (song.id == _loadedSongId && (_isLoading || _lyrics != null)) return;
    setState(() {
      _loadedSongId = song.id;
      _lyrics = null;
      _isLoading = true;
      _errorMessage = null;
      _activeLine = -1;
      _activeWord = -1;
      _lineKeys = const [];
    });
    try {
      final lyrics = await widget.lyricsLoader(song.code);
      if (!mounted || requestId != _requestId || song.id != _loadedSongId) {
        return;
      }
      final activeLine = lyrics.activeLineIndex(widget.controller.position);
      final activeWord = activeLine >= 0
          ? lyrics.lines[activeLine].activeWordIndex(widget.controller.position)
          : -1;
      setState(() {
        _lyrics = lyrics;
        _isLoading = false;
        _activeLine = activeLine;
        _activeWord = activeWord;
        _lineKeys = List.generate(lyrics.lines.length, (_) => GlobalKey());
      });
      _scrollToActiveLine(jump: true);
    } catch (error) {
      if (!mounted || requestId != _requestId || song.id != _loadedSongId) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _scrollToActiveLine({bool jump = false, bool approximate = true}) {
    if (_activeLine < 0 || _activeLine >= _lineKeys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lineContext = _lineKeys[_activeLine].currentContext;
      if (lineContext != null) {
        Scrollable.ensureVisible(
          lineContext,
          alignment: 0.38,
          duration: jump || MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
        );
        return;
      }
      if (!approximate || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      final denominator = _lineKeys.length > 1 ? _lineKeys.length - 1 : 1;
      final target =
          position.maxScrollExtent *
          (_activeLine / denominator).clamp(0.0, 1.0).toDouble();
      final duration = jump || MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 360);
      final movement = duration == Duration.zero
          ? Future<void>.sync(() => _scrollController.jumpTo(target))
          : _scrollController.animateTo(
              target,
              duration: duration,
              curve: Curves.easeOutCubic,
            );
      unawaited(
        movement.then((_) {
          if (mounted) {
            _scrollToActiveLine(jump: true, approximate: false);
          }
        }),
      );
    });
  }

  Future<void> _shareLyrics() async {
    final song = widget.controller.currentSong;
    final lyrics = _lyrics;
    if (song == null || lyrics == null || lyrics.isEmpty) return;
    await showLyricShareComposer(
      context,
      song: song,
      lyrics: lyrics,
      initialLineIndex: _activeLine,
      tvMode: widget.tvMode,
      exportService: widget.shareExportService,
      imageRenderer: widget.shareImageRenderer,
    );
  }

  @override
  void dispose() {
    _requestId++;
    widget.controller.removeListener(_handlePlaybackChanged);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.controller.currentSong;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (widget.embedded) {
      return Material(
        key: const ValueKey('desktop-embedded-lyrics'),
        color: Colors.transparent,
        child: Column(
          children: [
            _EmbeddedLyricsHeader(
              song: song,
              synced: _lyrics?.synced == true,
              wordSynced: _lyrics?.wordSynced == true,
              loading: _isLoading,
              onShare: _lyrics?.isEmpty == false ? _shareLyrics : null,
              onExpand: widget.onExpand,
            ),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            Expanded(child: _buildBody(song, immersive: false)),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final immersive = constraints.maxWidth >= 820;
        return Material(
          color: Colors.transparent,
          child: DecoratedBox(
            key: const ValueKey('song-lyrics-panel'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? const [
                        Color(0xFF35231F),
                        Color(0xFF17191B),
                        Color(0xFF101113),
                      ]
                    : const [
                        Color(0xFFFFD6C8),
                        Color(0xFFF7F0E6),
                        Color(0xFFF2EEE8),
                      ],
                stops: const [0, 0.48, 1],
              ),
            ),
            child: Column(
              children: [
                _LyricsHeader(
                  song: song,
                  synced: _lyrics?.synced == true,
                  wordSynced: _lyrics?.wordSynced == true,
                  mode: _viewMode,
                  immersive: immersive,
                  tvMode: widget.tvMode,
                  onModeChanged: (mode) => setState(() => _viewMode = mode),
                  onShare: _lyrics?.isEmpty == false ? _shareLyrics : null,
                  onClose: widget.onClose,
                ),
                Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
                Expanded(child: _buildBody(song, immersive: immersive)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(Song? song, {required bool immersive}) {
    if (song == null) {
      return const _LyricsMessage(
        icon: Icons.music_off_rounded,
        title: 'Chưa có bài hát đang phát',
        message: 'Chọn một bài hát để xem lời.',
      );
    }
    if (_isLoading) {
      return const _LyricsLoading();
    }
    if (_errorMessage != null) {
      return _LyricsMessage(
        key: const ValueKey('song-lyrics-error'),
        icon: Icons.cloud_off_rounded,
        title: 'Không tải được lời bài hát',
        message: _errorMessage!,
        action: FilledButton.icon(
          onPressed: () {
            _loadedSongId = null;
            unawaited(_loadCurrentLyrics());
          },
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Thử lại'),
        ),
      );
    }
    final lyrics = _lyrics;
    if (lyrics == null || lyrics.isEmpty) {
      return const _LyricsMessage(
        key: ValueKey('song-lyrics-empty'),
        icon: Icons.lyrics_outlined,
        title: 'Chưa có lời bài hát',
        message: 'Zing MP3 chưa cung cấp lời cho bài hát này.',
      );
    }
    final lyricsList = _LyricsList(
      controller: widget.controller,
      lyrics: lyrics,
      activeLine: _activeLine,
      lineKeys: _lineKeys,
      scrollController: _scrollController,
      tvMode: widget.tvMode,
      compact: widget.embedded,
    );
    final karaoke = _KaraokeStage(
      controller: widget.controller,
      lyrics: lyrics,
      activeLine: _activeLine,
      activeWord: _activeWord,
      tvMode: widget.tvMode,
    );
    if (!immersive) {
      return _viewMode == _LyricsViewMode.karaoke ? karaoke : lyricsList;
    }
    return Row(
      children: [
        SizedBox(
          width: MediaQuery.sizeOf(
            context,
          ).width.clamp(340.0, 520.0).toDouble(),
          child: _LyricsArtworkPane(
            controller: widget.controller,
            song: song,
            synced: lyrics.synced,
            wordSynced: lyrics.wordSynced,
            tvMode: widget.tvMode,
          ),
        ),
        VerticalDivider(
          width: 1,
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
        Expanded(
          child: _viewMode == _LyricsViewMode.karaoke ? karaoke : lyricsList,
        ),
      ],
    );
  }
}

class _EmbeddedLyricsHeader extends StatelessWidget {
  const _EmbeddedLyricsHeader({
    required this.song,
    required this.synced,
    required this.wordSynced,
    required this.loading,
    required this.onShare,
    required this.onExpand,
  });

  final Song? song;
  final bool synced;
  final bool wordSynced;
  final bool loading;
  final VoidCallback? onShare;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = loading
        ? 'ĐANG TẢI LỜI'
        : wordSynced
        ? 'KARAOKE TỪNG TỪ'
        : synced
        ? 'LỜI ĐỒNG BỘ'
        : 'LỜI BÀI HÁT';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 10, 14),
      child: Row(
        children: [
          if (song != null) ...[
            AlbumArt(
              imageUrl: song!.thumbnail,
              semanticLabel: 'Bìa album ${song!.displayTitle}',
              size: 48,
              borderRadius: 11,
            ),
            const SizedBox(width: 12),
          ] else ...[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.lyrics_outlined),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB8F43D),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  song?.displayTitle ?? 'Chưa chọn bài hát',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  song?.artistsNames ?? 'Chọn một bài để xem lời',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onExpand != null)
            IconButton(
              key: const ValueKey('desktop-expand-lyrics'),
              tooltip: 'Mở Karaoke toàn màn hình',
              onPressed: onExpand,
              icon: const Icon(Icons.open_in_full_rounded, size: 20),
            ),
          if (onShare != null)
            IconButton(
              key: const ValueKey('desktop-share-lyrics'),
              tooltip: 'Chia sẻ đoạn lời',
              onPressed: onShare,
              icon: const Icon(Icons.ios_share_rounded, size: 20),
            ),
        ],
      ),
    );
  }
}

class _LyricsHeader extends StatelessWidget {
  const _LyricsHeader({
    required this.song,
    required this.synced,
    required this.wordSynced,
    required this.mode,
    required this.immersive,
    required this.tvMode,
    required this.onModeChanged,
    required this.onShare,
    required this.onClose,
  });

  final Song? song;
  final bool synced;
  final bool wordSynced;
  final _LyricsViewMode mode;
  final bool immersive;
  final bool tvMode;
  final ValueChanged<_LyricsViewMode> onModeChanged;
  final VoidCallback? onShare;
  final VoidCallback onClose;

  Widget _metadata(BuildContext context, {required bool showArtwork}) => Row(
    children: [
      if (showArtwork && song != null) ...[
        AlbumArt(
          imageUrl: song!.thumbnail,
          semanticLabel: 'Bìa album ${song!.displayTitle}',
          size: tvMode ? 68 : 52,
          borderRadius: 12,
        ),
        const SizedBox(width: 13),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '#zingChart · ${wordSynced
                  ? 'KARAOKE TỪNG TỪ'
                  : synced
                  ? 'LỜI ĐỒNG BỘ'
                  : 'LỜI TĨNH'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFB8F43D),
                fontSize: tvMode ? 14 : 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            if (song != null) ...[
              const SizedBox(height: 4),
              Text(
                song!.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: tvMode ? 22 : 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      ),
      if (synced && !immersive)
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Icon(
            wordSynced ? Icons.graphic_eq_rounded : Icons.sync_rounded,
            semanticLabel: wordSynced ? 'Đồng bộ từng từ' : 'Đồng bộ theo dòng',
            color: const Color(0xFFB8F43D),
            size: 22,
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(tvMode ? 34 : 20, 14, tvMode ? 28 : 14, 13),
      child: immersive
          ? Row(
              children: [
                Expanded(child: _metadata(context, showArtwork: false)),
                const SizedBox(width: 24),
                SizedBox(
                  width: tvMode ? 430 : 360,
                  child: _LyricsModeSwitch(
                    mode: mode,
                    tvMode: tvMode,
                    onChanged: onModeChanged,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onShare != null)
                          IconButton.filledTonal(
                            key: const ValueKey('song-lyrics-share'),
                            tooltip: 'Chia sẻ đoạn lời',
                            onPressed: onShare,
                            icon: const Icon(Icons.ios_share_rounded),
                          ),
                        if (onShare != null) const SizedBox(width: 8),
                        IconButton.filledTonal(
                          key: const ValueKey('song-lyrics-close'),
                          tooltip: 'Đóng lời bài hát',
                          onPressed: onClose,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _metadata(context, showArtwork: true)),
                    const SizedBox(width: 8),
                    if (onShare != null) ...[
                      IconButton.filledTonal(
                        key: const ValueKey('song-lyrics-share'),
                        tooltip: 'Chia sẻ đoạn lời',
                        onPressed: onShare,
                        icon: const Icon(Icons.ios_share_rounded),
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton.filledTonal(
                      key: const ValueKey('song-lyrics-close'),
                      tooltip: 'Đóng lời bài hát',
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _LyricsModeSwitch(
                  mode: mode,
                  tvMode: tvMode,
                  onChanged: onModeChanged,
                ),
              ],
            ),
    ),
  );
}

class _LyricsModeSwitch extends StatelessWidget {
  const _LyricsModeSwitch({
    required this.mode,
    required this.tvMode,
    required this.onChanged,
  });

  final _LyricsViewMode mode;
  final bool tvMode;
  final ValueChanged<_LyricsViewMode> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: tvMode ? 54 : 46,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.35),
      ),
    ),
    child: Row(
      children: _LyricsViewMode.values
          .map(
            (value) => Expanded(
              child: Semantics(
                button: true,
                selected: mode == value,
                child: Material(
                  color: mode == value
                      ? Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    key: ValueKey('lyrics-mode-${value.name}'),
                    onTap: () => onChanged(value),
                    borderRadius: BorderRadius.circular(999),
                    focusColor: const Color(0x40B8F43D),
                    hoverColor: Colors.white.withValues(alpha: 0.06),
                    child: Center(
                      child: Text(
                        value == _LyricsViewMode.karaoke
                            ? 'Karaoke'
                            : 'Lời bài hát',
                        style: TextStyle(
                          color: mode == value
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: tvMode ? 18 : 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    ),
  );
}

class _LyricsArtworkPane extends StatelessWidget {
  const _LyricsArtworkPane({
    required this.controller,
    required this.song,
    required this.synced,
    required this.wordSynced,
    required this.tvMode,
  });

  final MusicPlayerController controller;
  final Song song;
  final bool synced;
  final bool wordSynced;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final artSize = (constraints.maxWidth - (tvMode ? 80 : 64))
          .clamp(210.0, tvMode ? 430.0 : 360.0)
          .toDouble();
      return SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: tvMode ? 40 : 32,
          vertical: tvMode ? 42 : 28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: AlbumArt(
                imageUrl: song.thumbnail,
                semanticLabel: 'Bìa album ${song.displayTitle}',
                size: artSize,
                borderRadius: tvMode ? 20 : 16,
              ),
            ),
            SizedBox(height: tvMode ? 28 : 22),
            Text(
              song.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: tvMode ? 34 : 26,
                height: 1.08,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              song.artistsNames,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: tvMode ? 20 : 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Chip(
              avatar: Icon(
                wordSynced
                    ? Icons.graphic_eq_rounded
                    : synced
                    ? Icons.sync_rounded
                    : Icons.subject_rounded,
                size: 17,
              ),
              label: Text(
                wordSynced
                    ? 'Đồng bộ từng từ'
                    : synced
                    ? 'Đồng bộ theo dòng'
                    : 'Lời tĩnh',
              ),
              visualDensity: VisualDensity.compact,
            ),
            SizedBox(height: tvMode ? 22 : 14),
            _LyricsTransport(controller: controller, tvMode: tvMode),
          ],
        ),
      );
    },
  );
}

class _LyricsTransport extends StatelessWidget {
  const _LyricsTransport({required this.controller, required this.tvMode});

  final MusicPlayerController controller;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final durationMs = controller.duration.inMilliseconds;
      final positionMs = controller.position.inMilliseconds.clamp(
        0,
        durationMs > 0 ? durationMs : 0,
      );
      return Column(
        children: [
          Slider(
            value: durationMs <= 0 ? 0 : positionMs.toDouble(),
            max: durationMs <= 0 ? 1 : durationMs.toDouble(),
            onChanged: durationMs <= 0
                ? null
                : (value) =>
                      controller.seek(Duration(milliseconds: value.round())),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_lyricsDurationLabel(controller.position)),
                Text(_lyricsDurationLabel(controller.duration)),
              ],
            ),
          ),
          SizedBox(height: tvMode ? 14 : 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Bài trước',
                iconSize: tvMode ? 34 : 28,
                onPressed: controller.canGoPrevious
                    ? controller.previous
                    : null,
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              SizedBox(width: tvMode ? 22 : 14),
              IconButton.filled(
                key: const ValueKey('lyrics-play-pause'),
                tooltip: controller.isPlaying ? 'Tạm dừng' : 'Phát',
                iconSize: tvMode ? 38 : 30,
                onPressed: controller.togglePlayPause,
                icon: Icon(
                  controller.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
              ),
              SizedBox(width: tvMode ? 22 : 14),
              IconButton(
                tooltip: 'Bài tiếp theo',
                iconSize: tvMode ? 34 : 28,
                onPressed: controller.canGoNext ? controller.next : null,
                icon: const Icon(Icons.skip_next_rounded),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class _KaraokeStage extends StatefulWidget {
  const _KaraokeStage({
    required this.controller,
    required this.lyrics,
    required this.activeLine,
    required this.activeWord,
    required this.tvMode,
  });

  final MusicPlayerController controller;
  final SongLyrics lyrics;
  final int activeLine;
  final int activeWord;
  final bool tvMode;

  @override
  State<_KaraokeStage> createState() => _KaraokeStageState();
}

class _KaraokeStageState extends State<_KaraokeStage> {
  late List<FocusNode> _lineFocusNodes;

  @override
  void initState() {
    super.initState();
    _lineFocusNodes = _makeFocusNodes();
  }

  @override
  void didUpdateWidget(covariant _KaraokeStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.lyrics, widget.lyrics) ||
        oldWidget.lyrics.lines.length != widget.lyrics.lines.length) {
      for (final node in _lineFocusNodes) {
        node.dispose();
      }
      _lineFocusNodes = _makeFocusNodes();
      return;
    }
    final focusedIndex = _lineFocusNodes.indexWhere((node) => node.hasFocus);
    if (focusedIndex >= 0) {
      final currentIndex = _contextLineIndex();
      if ((focusedIndex - currentIndex).abs() > 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && currentIndex < _lineFocusNodes.length) {
            _lineFocusNodes[currentIndex].requestFocus();
          }
        });
      }
    }
  }

  List<FocusNode> _makeFocusNodes() => List.generate(
    widget.lyrics.lines.length,
    (index) => FocusNode(debugLabel: 'Karaoke line $index'),
    growable: false,
  );

  @override
  void dispose() {
    for (final node in _lineFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  int _contextLineIndex() {
    if (widget.activeLine >= 0) return widget.activeLine;
    final position = widget.controller.position;
    var low = 0;
    var high = widget.lyrics.lines.length - 1;
    var result = 0;
    while (low <= high) {
      final middle = low + ((high - low) >> 1);
      if (widget.lyrics.lines[middle].start <= position) {
        result = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return result;
  }

  Widget _lineAt(
    int index, {
    required bool active,
    required int activeWord,
    required double opacity,
  }) {
    final line = widget.lyrics.lines[index];
    return _KaraokeLine(
      key: ValueKey('karaoke-line-$index'),
      line: line,
      active: active,
      activeWord: activeWord,
      tvMode: widget.tvMode,
      opacity: opacity,
      focusNode: _lineFocusNodes[index],
      onTap: widget.lyrics.synced
          ? () => widget.controller.seek(line.start)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _contextLineIndex();
    final previousIndex = currentIndex > 0 ? currentIndex - 1 : null;
    final nextIndex = currentIndex + 1 < widget.lyrics.lines.length
        ? currentIndex + 1
        : null;
    return Container(
      key: const ValueKey('song-karaoke-stage'),
      padding: EdgeInsets.symmetric(
        horizontal: widget.tvMode ? 70 : 28,
        vertical: widget.tvMode ? 50 : 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.graphic_eq_rounded, color: Color(0xFFFF6B4A)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.lyrics.wordSynced
                      ? 'KARAOKE · CHẠY THEO TỪ'
                      : widget.lyrics.synced
                      ? 'KARAOKE · CHẠY THEO DÒNG'
                      : 'KARAOKE · LỜI TĨNH',
                  style: TextStyle(
                    color: const Color(0xFFFF6B4A),
                    fontSize: widget.tvMode ? 17 : 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                key: const ValueKey('song-karaoke-scroll'),
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (previousIndex != null)
                          _lineAt(
                            previousIndex,
                            active: false,
                            activeWord: -1,
                            opacity: 0.2,
                          ),
                        _lineAt(
                          currentIndex,
                          active: widget.activeLine >= 0,
                          activeWord: widget.activeLine >= 0
                              ? widget.activeWord
                              : -1,
                          opacity: 1,
                        ),
                        if (nextIndex != null)
                          _lineAt(
                            nextIndex,
                            active: false,
                            activeWord: -1,
                            opacity: 0.42,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Text(
            widget.lyrics.synced
                ? 'Chạm một câu để tua đến đúng thời điểm'
                : 'Lời tĩnh không hỗ trợ chạm để tua',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: widget.tvMode ? 16 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _KaraokeLine extends StatelessWidget {
  const _KaraokeLine({
    super.key,
    required this.line,
    required this.active,
    required this.activeWord,
    required this.tvMode,
    required this.opacity,
    required this.focusNode,
    required this.onTap,
  });

  final LyricLine line;
  final bool active;
  final int activeWord;
  final bool tvMode;
  final double opacity;
  final FocusNode focusNode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: opacity),
      fontSize: tvMode ? 48 : 34,
      height: 1.1,
      fontWeight: FontWeight.w900,
      letterSpacing: -1,
    );
    final spans = <InlineSpan>[];
    for (var index = 0; index < line.words.length; index++) {
      if (index > 0) spans.add(const TextSpan(text: ' '));
      final completed = active && index < activeWord;
      final current = active && index == activeWord;
      spans.add(
        TextSpan(
          text: line.words[index].text,
          style: baseStyle.copyWith(
            color: completed
                ? const Color(0xFFB8F43D)
                : current
                ? const Color(0xFFFF6B4A)
                : baseStyle.color,
          ),
        ),
      );
    }
    final text = line.words.isEmpty
        ? TextSpan(
            text: line.text,
            style: baseStyle.copyWith(
              color: active ? const Color(0xFFB8F43D) : baseStyle.color,
            ),
          )
        : TextSpan(children: spans);
    final interactive = Focus(
      focusNode: focusNode,
      canRequestFocus: onTap != null,
      onKeyEvent: (_, event) {
        if (onTap != null &&
            event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          onTap!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: focused ? const Color(0x40B8F43D) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              onTap: onTap,
              canRequestFocus: false,
              borderRadius: BorderRadius.circular(16),
              hoverColor: Colors.white.withValues(alpha: 0.05),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: tvMode ? 18 : 13),
                child: Text.rich(text),
              ),
            ),
          );
        },
      ),
    );
    return Semantics(
      liveRegion: active,
      button: onTap != null,
      label: active ? 'Đang hát: ${line.text}' : line.text,
      onTap: onTap,
      child: ExcludeSemantics(child: interactive),
    );
  }
}

String _lyricsDurationLabel(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class _LyricsList extends StatelessWidget {
  const _LyricsList({
    required this.controller,
    required this.lyrics,
    required this.activeLine,
    required this.lineKeys,
    required this.scrollController,
    required this.tvMode,
    this.compact = false,
  });

  final MusicPlayerController controller;
  final SongLyrics lyrics;
  final int activeLine;
  final List<GlobalKey> lineKeys;
  final ScrollController scrollController;
  final bool tvMode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return ListView.builder(
      key: const ValueKey('song-lyrics-list'),
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        tvMode
            ? 56
            : compact
            ? 16
            : 26,
        tvMode
            ? 120
            : compact
            ? 30
            : 84,
        tvMode
            ? 56
            : compact
            ? 16
            : 26,
        tvMode
            ? 260
            : compact
            ? 110
            : 180,
      ),
      itemCount: lyrics.lines.length,
      itemBuilder: (context, index) {
        final line = lyrics.lines[index];
        final active = index == activeLine;
        final color = active
            ? const Color(0xFFB8F43D)
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.48);
        final style = TextStyle(
          color: color,
          fontSize: tvMode
              ? 40
              : compact
              ? 19
              : 27,
          height: compact ? 1.28 : 1.2,
          fontWeight: active ? FontWeight.w900 : FontWeight.w800,
          letterSpacing: active ? -0.7 : -0.4,
        );
        return Semantics(
          selected: active,
          button: lyrics.synced,
          label: active ? 'Đang hát: ${line.text}' : line.text,
          child: InkWell(
            key: lineKeys[index],
            canRequestFocus: lyrics.synced,
            borderRadius: BorderRadius.circular(14),
            focusColor: const Color(0x2EB8F43D),
            hoverColor: const Color(0x12FFFFFF),
            onTap: lyrics.synced ? () => controller.seek(line.start) : null,
            child: AnimatedDefaultTextStyle(
              duration: reducedMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              style: style,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 10,
                  vertical: tvMode
                      ? 16
                      : compact
                      ? 10
                      : 12,
                ),
                child: Text(line.text),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LyricsLoading extends StatelessWidget {
  const _LyricsLoading();

  @override
  Widget build(BuildContext context) => ListView.separated(
    key: const ValueKey('song-lyrics-loading'),
    padding: const EdgeInsets.fromLTRB(34, 88, 34, 80),
    itemCount: 7,
    separatorBuilder: (_, __) => const SizedBox(height: 22),
    itemBuilder: (context, index) => Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: index.isEven ? 0.76 : 0.56,
        child: Container(
          height: 28,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(9),
          ),
        ),
      ),
    ),
  );
}

class _LyricsMessage extends StatelessWidget {
  const _LyricsMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 58, color: const Color(0xFFFF6B4A)),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}
