import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/music_repository.dart';
import '../models/catalog_search.dart';
import '../models/song.dart';
import '../models/song_detail.dart';
import '../music_player_controller.dart';
import '../services/official_content_share_service.dart';
import '../zing_mp3_api.dart';
import 'album_art.dart';
import 'catalog_video_handoff_dialog.dart';
import 'official_content_share_dialog.dart';

typedef SongDetailLoader = Future<SongDetail> Function(String songId);
typedef SongDetailExternalLauncher = Future<bool> Function(Uri uri);

Future<bool> launchSongDetailExternalPage(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

Future<void> showSongDetail(
  BuildContext context, {
  required MusicPlayerController controller,
  SongDetailLoader? detailLoader,
  SongDetail? initialDetail,
  Song? initialSong,
  VoidCallback? onPlay,
  ValueChanged<CatalogArtist>? onOpenArtist,
  ValueChanged<CatalogCollection>? onOpenAlbum,
  SongDetailExternalLauncher externalLauncher = launchSongDetailExternalPage,
  OfficialContentShareService shareService =
      const SharePlusOfficialContentShareService(),
  bool tvMode = false,
}) {
  final loader = detailLoader ?? ZingMP3API.getSongDetail;
  final width = MediaQuery.sizeOf(context).width;
  if (width < 700 && !tvMode) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.94,
        child: SongDetailPanel(
          controller: controller,
          detailLoader: loader,
          initialDetail: initialDetail,
          initialSong: initialSong,
          onPlay: onPlay,
          onOpenArtist: onOpenArtist,
          onOpenAlbum: onOpenAlbum,
          externalLauncher: externalLauncher,
          shareService: shareService,
        ),
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: EdgeInsets.all(tvMode ? 42 : 28),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: tvMode ? 1120 : 940,
        height: tvMode ? 760 : 700,
        child: SongDetailPanel(
          controller: controller,
          detailLoader: loader,
          initialDetail: initialDetail,
          initialSong: initialSong,
          onPlay: onPlay,
          onOpenArtist: onOpenArtist,
          onOpenAlbum: onOpenAlbum,
          externalLauncher: externalLauncher,
          shareService: shareService,
          tvMode: tvMode,
        ),
      ),
    ),
  );
}

class SongDetailPanel extends StatefulWidget {
  const SongDetailPanel({
    super.key,
    required this.controller,
    required this.detailLoader,
    this.initialDetail,
    this.initialSong,
    this.onPlay,
    this.onOpenArtist,
    this.onOpenAlbum,
    this.externalLauncher = launchSongDetailExternalPage,
    this.shareService = const SharePlusOfficialContentShareService(),
    this.tvMode = false,
  });

  final MusicPlayerController controller;
  final SongDetailLoader detailLoader;
  final SongDetail? initialDetail;
  final Song? initialSong;
  final VoidCallback? onPlay;
  final ValueChanged<CatalogArtist>? onOpenArtist;
  final ValueChanged<CatalogCollection>? onOpenAlbum;
  final SongDetailExternalLauncher externalLauncher;
  final OfficialContentShareService shareService;
  final bool tvMode;

  @override
  State<SongDetailPanel> createState() => _SongDetailPanelState();
}

class _SongDetailPanelState extends State<SongDetailPanel> {
  SongDetail? _detail;
  String? _error;
  String _loadedSongKey = '';
  int _requestId = 0;
  bool _loading = false;
  String? _pinnedSongId;

  @override
  void initState() {
    super.initState();
    final initialDetail = widget.initialDetail;
    if (initialDetail != null) {
      _detail = initialDetail;
      final song = initialDetail.catalogSong.song;
      _loadedSongKey = '${song.id}:${song.code}';
      _pinnedSongId = song.id;
    } else if (widget.initialSong case final song?) {
      _loadedSongKey = '${song.id}:${song.code}';
      _pinnedSongId = song.id;
      scheduleMicrotask(() => _load(song));
    }
    widget.controller.addListener(_handlePlaybackChange);
    scheduleMicrotask(_handlePlaybackChange);
  }

  @override
  void didUpdateWidget(covariant SongDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handlePlaybackChange);
      widget.controller.addListener(_handlePlaybackChange);
      _loadedSongKey = '';
      _handlePlaybackChange();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handlePlaybackChange);
    _requestId++;
    super.dispose();
  }

  void _handlePlaybackChange() {
    if (!mounted) return;
    final song = widget.controller.currentSong;
    final pinnedSongId = _pinnedSongId;
    if (pinnedSongId != null) {
      if (song == null || song.id != pinnedSongId) return;
      _pinnedSongId = null;
    }
    final songKey = song == null ? '' : '${song.id}:${song.code}';
    if (song == null || songKey == _loadedSongKey) return;
    _loadedSongKey = songKey;
    unawaited(_load(song));
  }

  Future<void> _load(Song song) async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _detail = null;
      _error = null;
    });
    try {
      // The legacy realtime chart keeps a separate source key in `code`.
      // Current catalog metadata endpoints address songs by their public ID.
      final detail = await widget.detailLoader(song.id);
      if (!mounted || requestId != _requestId) return;
      if (detail.catalogSong.song.id != song.id &&
          detail.catalogSong.song.code != song.code) {
        throw const MusicRepositoryException(
          'Thông tin trả về không khớp bài đang phát.',
        );
      }
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = error is MusicRepositoryException
            ? error.message
            : 'Không thể tải thông tin bài hát.';
        _loading = false;
      });
    }
  }

  Future<void> _openMv(CatalogVideo video) async {
    if (!widget.tvMode) {
      try {
        if (await widget.externalLauncher(Uri.parse(video.externalUrl))) return;
      } catch (_) {
        // HarmonyOS and other platforms without a launcher use QR/copy.
      }
    }
    if (!mounted) return;
    await showCatalogVideoHandoffDialog(context, video);
  }

  Future<void> _shareSong(SongDetail detail) => shareOfficialContent(
    context,
    OfficialContentShare(
      kind: OfficialContentKind.song,
      title: detail.catalogSong.song.displayTitle,
      subtitle: detail.catalogSong.song.artistsNames,
      externalUrl: detail.catalogSong.externalUrl,
    ),
    service: widget.shareService,
    forceHandoff: widget.tvMode,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.surface,
              scheme.surfaceContainerLowest,
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _SongDetailHeader(tvMode: widget.tvMode),
              Divider(height: 1, color: scheme.outlineVariant),
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const _SongDetailLoading();
    final error = _error;
    final current = widget.controller.currentSong;
    if (error != null) {
      return _SongDetailError(
        message: error,
        onRetry: current == null ? null : () => _load(current),
      );
    }
    final detail = _detail;
    if (detail == null) return const _SongDetailLoading();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 780;
        final padding = EdgeInsets.fromLTRB(
          widget.tvMode
              ? 42
              : wide
              ? 34
              : 22,
          widget.tvMode ? 34 : 28,
          widget.tvMode
              ? 42
              : wide
              ? 34
              : 22,
          widget.tvMode ? 38 : 30,
        );
        final hero = _SongDetailHero(
          detail: detail,
          controller: widget.controller,
          tvMode: widget.tvMode,
          onShare: () => _shareSong(detail),
          onPlay: widget.onPlay,
          onOpenMv: detail.mv == null ? null : () => _openMv(detail.mv!),
        );
        final metadata = _SongDetailMetadata(
          detail: detail,
          tvMode: widget.tvMode,
          onOpenArtist: widget.onOpenArtist,
          onOpenAlbum: widget.onOpenAlbum,
          onOpenMv: detail.mv == null ? null : () => _openMv(detail.mv!),
        );
        return SingleChildScrollView(
          key: const ValueKey('song-detail-scroll'),
          padding: padding,
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: widget.tvMode ? 370 : 310, child: hero),
                    SizedBox(width: widget.tvMode ? 54 : 40),
                    Expanded(child: metadata),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [hero, const SizedBox(height: 32), metadata],
                ),
        );
      },
    );
  }
}

class _SongDetailHeader extends StatelessWidget {
  const _SongDetailHeader({required this.tvMode});

  final bool tvMode;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(tvMode ? 34 : 22, 16, 10, 14),
    child: Row(
      children: [
        const Icon(Icons.info_outline_rounded, color: Color(0xFFB8F43D)),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'THÔNG TIN BÀI HÁT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('song-detail-close'),
          autofocus: tvMode,
          tooltip: 'Đóng thông tin bài hát',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );
}

class _SongDetailHero extends StatelessWidget {
  const _SongDetailHero({
    required this.detail,
    required this.controller,
    required this.tvMode,
    required this.onShare,
    required this.onPlay,
    required this.onOpenMv,
  });

  final SongDetail detail;
  final MusicPlayerController controller;
  final bool tvMode;
  final VoidCallback onShare;
  final VoidCallback? onPlay;
  final VoidCallback? onOpenMv;

  @override
  Widget build(BuildContext context) {
    final song = detail.catalogSong.song;
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final artSize = math.min(constraints.maxWidth, tvMode ? 360.0 : 310.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: AlbumArt(
                imageUrl: song.thumbnail,
                semanticLabel: 'Bìa bài hát ${song.displayTitle}',
                size: artSize,
                borderRadius: tvMode ? 34 : 28,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              song.displayTitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: tvMode ? 32 : 27,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              song.artistsNames,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.secondary,
                fontSize: tvMode ? 18 : 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(
                  icon: detail.catalogSong.playable
                      ? Icons.graphic_eq_rounded
                      : Icons.lock_outline_rounded,
                  label: detail.catalogSong.playable
                      ? 'PHÁT ĐƯỢC'
                      : 'BỊ GIỚI HẠN',
                  color: detail.catalogSong.playable
                      ? const Color(0xFFB8F43D)
                      : scheme.error,
                ),
                if (detail.catalogSong.hasLyrics)
                  const _StatusChip(
                    icon: Icons.lyrics_rounded,
                    label: 'CÓ LỜI',
                    color: Color(0xFFFF6B4A),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (onPlay != null) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('song-detail-play'),
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('PHÁT BÀI HÁT'),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) => FilledButton.icon(
                      key: const ValueKey('song-detail-like'),
                      onPressed: () => controller.toggleLike(song),
                      icon: Icon(
                        controller.isLiked(song)
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                      ),
                      label: Text(
                        controller.isLiked(song) ? 'ĐÃ YÊU THÍCH' : 'YÊU THÍCH',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  key: const ValueKey('song-detail-share'),
                  tooltip: 'Chia sẻ liên kết chính thức',
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded),
                ),
                if (onOpenMv != null) ...[
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    key: const ValueKey('song-detail-open-mv-compact'),
                    tooltip: 'Mở MV chính thức',
                    onPressed: onOpenMv,
                    icon: const Icon(Icons.smart_display_rounded),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SongDetailMetadata extends StatelessWidget {
  const _SongDetailMetadata({
    required this.detail,
    required this.tvMode,
    required this.onOpenArtist,
    required this.onOpenAlbum,
    required this.onOpenMv,
  });

  final SongDetail detail;
  final bool tvMode;
  final ValueChanged<CatalogArtist>? onOpenArtist;
  final ValueChanged<CatalogCollection>? onOpenAlbum;
  final VoidCallback? onOpenMv;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final album = detail.album;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BÀI HÁT',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        _SongDetailStats(detail: detail, tvMode: tvMode),
        const SizedBox(height: 30),
        Text(
          'Thông Tin',
          style: TextStyle(
            fontSize: tvMode ? 28 : 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 14),
        _MetadataTable(
          detail: detail,
          tvMode: tvMode,
          onOpenArtist: onOpenArtist,
        ),
        if (album != null) ...[
          const SizedBox(height: 28),
          Text(
            'Xuất hiện trong',
            style: TextStyle(
              fontSize: tvMode ? 25 : 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _AlbumSummaryCard(
            album: album,
            tvMode: tvMode,
            onTap: onOpenAlbum == null ? null : () => onOpenAlbum!(album),
          ),
        ],
        if (onOpenMv != null) ...[
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const ValueKey('song-detail-open-mv'),
            onPressed: onOpenMv,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('MỞ MV CHÍNH THỨC'),
          ),
          const SizedBox(height: 8),
          Text(
            'MV được mở trên trang Zing MP3 chính thức; #zingChart không tải '
            'hoặc lưu nội dung video.',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _SongDetailStats extends StatelessWidget {
  const _SongDetailStats({required this.detail, required this.tvMode});

  final SongDetail detail;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[
      (
        Icons.schedule_rounded,
        _durationLabel(detail.catalogSong.duration),
        'THỜI LƯỢNG',
      ),
      (Icons.favorite_rounded, _compactNumber(detail.likeCount), 'LƯỢT THÍCH'),
      (
        Icons.headphones_rounded,
        _compactNumber(detail.listenCount),
        'LƯỢT NGHE',
      ),
      (
        Icons.chat_bubble_rounded,
        _compactNumber(detail.commentCount),
        'BÌNH LUẬN',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 430;
        final columns = narrow ? 2 : 4;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _StatTile(
                    icon: item.$1,
                    value: item.$2,
                    label: item.$3,
                    tvMode: tvMode,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.tvMode,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(tvMode ? 18 : 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: tvMode ? 25 : 20, color: const Color(0xFFFF6B4A)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: tvMode ? 18 : 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: tvMode ? 11 : 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataTable extends StatelessWidget {
  const _MetadataTable({
    required this.detail,
    required this.tvMode,
    required this.onOpenArtist,
  });

  final SongDetail detail;
  final bool tvMode;
  final ValueChanged<CatalogArtist>? onOpenArtist;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, Widget)>[
      if (detail.releasedAt != null)
        (
          'Ngày phát hành',
          _MetadataValue(text: _dateLabel(detail.releasedAt!), tvMode: tvMode),
        ),
      if (detail.distributor.isNotEmpty)
        (
          'Cung cấp bởi',
          _MetadataValue(text: detail.distributor, tvMode: tvMode),
        ),
      if (detail.artists.isNotEmpty)
        (
          'Nghệ sĩ',
          _SongDetailArtistLinks(
            artists: detail.artists,
            role: 'artist',
            tvMode: tvMode,
            onOpenArtist: onOpenArtist,
          ),
        ),
      if (detail.composers.isNotEmpty)
        (
          'Sáng tác',
          _SongDetailArtistLinks(
            artists: detail.composers,
            role: 'composer',
            tvMode: tvMode,
            onOpenArtist: onOpenArtist,
          ),
        ),
      if (detail.genres.isNotEmpty)
        (
          'Thể loại',
          _MetadataValue(text: detail.genres.join(' · '), tvMode: tvMode),
        ),
    ];
    if (rows.isEmpty) {
      return Text(
        'Chưa có thêm metadata được công bố cho bài hát này.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: rows.indexed
            .map((entry) {
              final index = entry.$1;
              final row = entry.$2;
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: tvMode ? 20 : 16,
                  vertical: tvMode ? 16 : 13,
                ),
                decoration: BoxDecoration(
                  border: index == rows.length - 1
                      ? null
                      : Border(
                          bottom: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: tvMode ? 150 : 118,
                      child: Text(
                        row.$1,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: tvMode ? 16 : 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: row.$2),
                  ],
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _MetadataValue extends StatelessWidget {
  const _MetadataValue({required this.text, required this.tvMode});

  final String text;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: tvMode ? 17 : 14, fontWeight: FontWeight.w800),
  );
}

class _SongDetailArtistLinks extends StatelessWidget {
  const _SongDetailArtistLinks({
    required this.artists,
    required this.role,
    required this.tvMode,
    required this.onOpenArtist,
  });

  final List<CatalogArtist> artists;
  final String role;
  final bool tvMode;
  final ValueChanged<CatalogArtist>? onOpenArtist;

  @override
  Widget build(BuildContext context) {
    if (onOpenArtist == null) {
      return _MetadataValue(
        text: artists.map((artist) => artist.name).join(', '),
        tvMode: tvMode,
      );
    }
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: artists
          .map(
            (artist) => ActionChip(
              key: ValueKey('song-detail-$role-${artist.id}'),
              tooltip: 'Mở hồ sơ ${artist.name}',
              avatar: Icon(
                role == 'composer'
                    ? Icons.edit_note_rounded
                    : Icons.person_outline_rounded,
                size: tvMode ? 21 : 17,
              ),
              label: Text(
                artist.name,
                style: TextStyle(
                  fontSize: tvMode ? 16 : 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: () => onOpenArtist!(artist),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _AlbumSummaryCard extends StatefulWidget {
  const _AlbumSummaryCard({
    required this.album,
    required this.tvMode,
    required this.onTap,
  });

  final CatalogCollection album;
  final bool tvMode;
  final VoidCallback? onTap;

  @override
  State<_AlbumSummaryCard> createState() => _AlbumSummaryCardState();
}

class _AlbumSummaryCardState extends State<_AlbumSummaryCard> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final album = widget.album;
    final tvMode = widget.tvMode;
    final interactive = widget.onTap != null;
    return Semantics(
      button: interactive,
      label: interactive
          ? 'Mở album ${album.title}, ${album.artist}'
          : 'Album ${album.title}, ${album.artist}',
      child: MouseRegion(
        onEnter: interactive ? (_) => setState(() => _hovered = true) : null,
        onExit: interactive ? (_) => setState(() => _hovered = false) : null,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('song-detail-open-album'),
            borderRadius: BorderRadius.circular(18),
            onFocusChange: interactive
                ? (focused) => setState(() => _focused = focused)
                : null,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.all(tvMode ? 16 : 12),
              decoration: BoxDecoration(
                color: _hovered || _focused
                    ? scheme.primary.withValues(alpha: 0.13)
                    : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _focused
                      ? scheme.primary
                      : _hovered
                      ? scheme.primary.withValues(alpha: 0.58)
                      : scheme.outlineVariant,
                  width: _focused ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  AlbumArt(
                    imageUrl: album.thumbnail,
                    semanticLabel: 'Bìa album ${album.title}',
                    size: tvMode ? 96 : 76,
                    borderRadius: 14,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ALBUM / SINGLE',
                          style: TextStyle(
                            color: Color(0xFFB8F43D),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          album.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: tvMode ? 19 : 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          album.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (interactive)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: _focused || _hovered
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.34)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
      ],
    ),
  );
}

class _SongDetailLoading extends StatelessWidget {
  const _SongDetailLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 34,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        SizedBox(height: 16),
        Text('Đang tải thông tin chính thức…'),
      ],
    ),
  );
}

class _SongDetailError extends StatelessWidget {
  const _SongDetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFFF6B4A),
            size: 42,
          ),
          const SizedBox(height: 14),
          const Text(
            'Chưa tải được thông tin bài hát',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('song-detail-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('THỬ LẠI'),
            ),
          ],
        ],
      ),
    ),
  );
}

String _durationLabel(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String _dateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';

String _compactNumber(int value) {
  if (value >= 1000000000) {
    return '${_decimal(value / 1000000000)} Tỷ';
  }
  if (value >= 1000000) return '${_decimal(value / 1000000)} Tr';
  if (value >= 1000) return '${_decimal(value / 1000)} N';
  return '$value';
}

String _decimal(double value) {
  final rounded = value.toStringAsFixed(value >= 100 ? 0 : 1);
  return rounded.endsWith('.0')
      ? rounded.substring(0, rounded.length - 2)
      : rounded;
}
