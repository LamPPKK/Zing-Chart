import 'package:flutter/material.dart';

import '../models/catalog_artist_detail.dart';
import '../models/catalog_search.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';

class ArtistProfileHero extends StatelessWidget {
  const ArtistProfileHero({
    super.key,
    required this.artist,
    required this.songs,
    required this.onPlay,
    this.onShare,
    this.onToggleFollow,
    this.isFollowed = false,
    this.detail,
    this.errorMessage,
    this.onRetry,
    this.loading = false,
    this.tvMode = false,
  });

  final CatalogArtist artist;
  final List<CatalogSong> songs;
  final VoidCallback? onPlay;
  final VoidCallback? onShare;
  final VoidCallback? onToggleFollow;
  final bool isFollowed;
  final CatalogArtistDetail? detail;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool loading;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final playableCount = songs.where((song) => song.playable).length;
    final effectiveArtist = detail?.artist ?? artist;
    final officialDesktop = !tvMode && MediaQuery.sizeOf(context).width >= 1180;
    return Container(
      key: const ValueKey('artist-profile-hero'),
      margin: officialDesktop
          ? const EdgeInsets.only(bottom: 32)
          : EdgeInsets.fromLTRB(
              tvMode ? 32 : 20,
              0,
              tvMode ? 32 : 20,
              tvMode ? 32 : 24,
            ),
      padding: officialDesktop
          ? const EdgeInsets.fromLTRB(60, 42, 60, 40)
          : EdgeInsets.all(tvMode ? 34 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: officialDesktop ? Alignment.centerLeft : Alignment.topLeft,
          end: officialDesktop ? Alignment.centerRight : Alignment.bottomRight,
          colors: officialDesktop
              ? const [Color(0xFF3A1B59), Color(0xFF28142F), Color(0xFF1B1021)]
              : const [Color(0xFF62457D), Color(0xFF382044), Color(0xFF201125)],
        ),
        borderRadius: officialDesktop
            ? BorderRadius.zero
            : BorderRadius.circular(tvMode ? 28 : 22),
        border: officialDesktop
            ? null
            : Border.all(
                color: ZingColors.purpleBright.withValues(alpha: 0.22),
              ),
        boxShadow: officialDesktop
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (detail?.cover.isNotEmpty == true)
            Positioned.fill(
              child: Opacity(
                opacity: 0.12,
                child: Image.network(
                  detail!.cover,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 580;
              final artSize = officialDesktop
                  ? 164.0
                  : tvMode
                  ? 190.0
                  : compact
                  ? 132.0
                  : 164.0;
              final details = _ArtistDetails(
                artist: effectiveArtist,
                detail: detail,
                songCount: songs.length,
                playableCount: playableCount,
                onPlay: onPlay,
                onShare: onShare,
                onToggleFollow: onToggleFollow,
                isFollowed: isFollowed,
                loading: loading,
                compact: compact,
                tvMode: tvMode,
                officialDesktop: officialDesktop,
                errorMessage: errorMessage,
                onRetry: onRetry,
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AlbumArt(
                      imageUrl: effectiveArtist.avatar,
                      semanticLabel: 'Ảnh nghệ sĩ ${effectiveArtist.name}',
                      size: artSize,
                      borderRadius: 999,
                    ),
                    const SizedBox(height: 20),
                    details,
                  ],
                );
              }
              return Row(
                children: [
                  AlbumArt(
                    imageUrl: effectiveArtist.avatar,
                    semanticLabel: 'Ảnh nghệ sĩ ${effectiveArtist.name}',
                    size: artSize,
                    borderRadius: 999,
                  ),
                  SizedBox(
                    width: officialDesktop
                        ? 34
                        : tvMode
                        ? 38
                        : 30,
                  ),
                  Expanded(child: details),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ArtistDetails extends StatelessWidget {
  const _ArtistDetails({
    required this.artist,
    required this.detail,
    required this.songCount,
    required this.playableCount,
    required this.onPlay,
    required this.onShare,
    required this.onToggleFollow,
    required this.isFollowed,
    required this.loading,
    required this.compact,
    required this.tvMode,
    required this.officialDesktop,
    required this.errorMessage,
    required this.onRetry,
  });

  final CatalogArtist artist;
  final CatalogArtistDetail? detail;
  final int songCount;
  final int playableCount;
  final VoidCallback? onPlay;
  final VoidCallback? onShare;
  final VoidCallback? onToggleFollow;
  final bool isFollowed;
  final bool loading;
  final bool compact;
  final bool tvMode;
  final bool officialDesktop;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (officialDesktop) return _buildOfficialDesktop(context);
    final alignment = compact
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          'NGHỆ SĨ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: tvMode ? 14 : 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.7,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          artist.name,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: Colors.white,
            fontSize: tvMode
                ? 58
                : compact
                ? 34
                : 48,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.6,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _summary,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: tvMode ? 15 : 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        if (_metadata.isNotEmpty) ...[
          const SizedBox(height: 9),
          Text(
            _metadata.join('  ·  '),
            textAlign: compact ? TextAlign.center : TextAlign.start,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: tvMode ? 14 : 11,
              height: 1.4,
            ),
          ),
        ],
        if (loading) ...[
          const SizedBox(height: 14),
          const LinearProgressIndicator(minHeight: 3),
        ] else if (errorMessage != null) ...[
          const SizedBox(height: 14),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Text(
                'Đang hiển thị dữ liệu tìm kiếm gần nhất.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: tvMode ? 14 : 11,
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('THỬ LẠI')),
            ],
          ),
        ],
        SizedBox(height: tvMode ? 26 : 20),
        Wrap(
          alignment: compact ? WrapAlignment.center : WrapAlignment.start,
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              key: const ValueKey('artist-play-button'),
              onPressed: onPlay,
              style: FilledButton.styleFrom(
                backgroundColor: ZingColors.purpleBright,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: tvMode ? 26 : 20,
                  vertical: tvMode ? 18 : 14,
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(
                'PHÁT NHẠC',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
            ),
            if (onToggleFollow != null)
              Semantics(
                toggled: isFollowed,
                button: true,
                onTap: onToggleFollow,
                label: isFollowed
                    ? 'Bỏ quan tâm ${artist.name}'
                    : 'Quan tâm ${artist.name}',
                child: ExcludeSemantics(
                  child: isFollowed
                      ? FilledButton.tonalIcon(
                          key: const ValueKey('artist-follow-button'),
                          onPressed: onToggleFollow,
                          style: FilledButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.2,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: tvMode ? 24 : 18,
                              vertical: tvMode ? 18 : 14,
                            ),
                          ),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text(
                            'ĐANG QUAN TÂM',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        )
                      : OutlinedButton.icon(
                          key: const ValueKey('artist-follow-button'),
                          onPressed: onToggleFollow,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.58),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: tvMode ? 24 : 18,
                              vertical: tvMode ? 18 : 14,
                            ),
                          ),
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text(
                            'QUAN TÂM',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                ),
              ),
            if (onShare != null)
              OutlinedButton.icon(
                key: const ValueKey('artist-share-button'),
                onPressed: onShare,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.42)),
                  padding: EdgeInsets.symmetric(
                    horizontal: tvMode ? 24 : 18,
                    vertical: tvMode ? 18 : 14,
                  ),
                ),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text(
                  'CHIA SẺ',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildOfficialDesktop(BuildContext context) {
    final followers = detail?.totalFollow ?? 0;
    final disabledMotion = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          key: const ValueKey('artist-desktop-title-row'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                artist.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 58,
                  height: 0.98,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2.2,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Tooltip(
              message: 'Phát nhạc của ${artist.name}',
              child: FilledButton(
                key: const ValueKey('artist-play-button'),
                onPressed: onPlay,
                style: FilledButton.styleFrom(
                  fixedSize: const Size.square(56),
                  minimumSize: const Size.square(56),
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                  backgroundColor: ZingColors.purpleBright,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.18),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.45),
                ),
                child: const Icon(Icons.play_arrow_rounded, size: 34),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (followers > 0)
              Text(
                '${_compactNumber(followers)} người quan tâm',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (onToggleFollow != null)
              Semantics(
                toggled: isFollowed,
                button: true,
                onTap: onToggleFollow,
                label: isFollowed
                    ? 'Bỏ quan tâm ${artist.name}'
                    : 'Quan tâm ${artist.name}',
                child: ExcludeSemantics(
                  child: OutlinedButton.icon(
                    key: const ValueKey('artist-follow-button'),
                    onPressed: onToggleFollow,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.34),
                      ),
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(
                      isFollowed
                          ? Icons.check_rounded
                          : Icons.person_add_alt_1_rounded,
                      size: 17,
                    ),
                    label: Text(
                      isFollowed ? 'ĐANG QUAN TÂM' : 'QUAN TÂM',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.35,
                      ),
                    ),
                  ),
                ),
              ),
            if (onShare != null)
              IconButton.outlined(
                key: const ValueKey('artist-share-button'),
                tooltip: 'Chia sẻ ${artist.name}',
                onPressed: onShare,
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.34)),
                  minimumSize: const Size.square(36),
                  maximumSize: const Size.square(36),
                ),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
              ),
          ],
        ),
        if (loading) ...[
          const SizedBox(height: 18),
          SizedBox(
            width: 280,
            child: LinearProgressIndicator(
              minHeight: 3,
              value: disabledMotion ? 0.42 : null,
            ),
          ),
        ] else if (errorMessage != null) ...[
          const SizedBox(height: 16),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                'Đang hiển thị dữ liệu tìm kiếm gần nhất.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('THỬ LẠI')),
            ],
          ),
        ],
      ],
    );
  }

  String get _summary {
    if (loading && detail == null) return 'ĐANG CẬP NHẬT HỒ SƠ CHÍNH THỨC…';
    final followers = detail?.totalFollow ?? 0;
    final followerText = followers <= 0
        ? ''
        : '${_compactNumber(followers)} NGƯỜI QUAN TÂM · ';
    return '$followerText$songCount BÀI HÁT · $playableCount CÓ THỂ PHÁT';
  }

  List<String> get _metadata => [
    if (detail?.realName.isNotEmpty == true) detail!.realName,
    if (detail?.national.isNotEmpty == true) detail!.national,
    if (detail?.birthday.isNotEmpty == true) detail!.birthday,
    if ((detail?.awardCount ?? 0) > 0) '${detail!.awardCount} giải thưởng',
  ];

  static String _compactNumber(int value) {
    if (value >= 1000000) {
      final number = value / 1000000;
      return '${number.toStringAsFixed(number >= 10 ? 0 : 1)} TR';
    }
    if (value >= 1000) {
      final number = value / 1000;
      return '${number.toStringAsFixed(number >= 10 ? 0 : 1)} N';
    }
    return '$value';
  }
}
