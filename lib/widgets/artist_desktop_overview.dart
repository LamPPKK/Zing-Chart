import 'package:flutter/material.dart';

import '../models/catalog_search.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';

class ArtistDesktopOverview extends StatelessWidget {
  const ArtistDesktopOverview({
    super.key,
    required this.latestRelease,
    required this.releaseLabel,
    required this.featuredSongs,
    required this.totalSongCount,
    required this.songBuilder,
    required this.onReleaseTap,
    required this.onShowAllSongs,
  });

  final CatalogCollection latestRelease;
  final String releaseLabel;
  final List<Song> featuredSongs;
  final int totalSongCount;
  final IndexedWidgetBuilder songBuilder;
  final VoidCallback onReleaseTap;
  final VoidCallback onShowAllSongs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('artist-desktop-overview'),
      padding: const EdgeInsets.fromLTRB(60, 32, 60, 22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final releaseSection = _buildReleaseSection();
          final stackSections = constraints.maxWidth < 1000;
          final songSection = _buildSongSection(context);
          if (stackSections) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                releaseSection,
                const SizedBox(height: 28),
                songSection,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: releaseSection),
              const SizedBox(width: 28),
              Expanded(flex: 6, child: songSection),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReleaseSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _DesktopSectionTitle(
        key: ValueKey('artist-latest-release-section-title'),
        title: 'Mới Phát Hành',
      ),
      const SizedBox(height: 18),
      _LatestReleaseCard(
        collection: latestRelease,
        releaseLabel: releaseLabel,
        onTap: onReleaseTap,
      ),
    ],
  );

  Widget _buildSongSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 32,
          child: Row(
            children: [
              const Expanded(
                child: _DesktopSectionTitle(
                  key: ValueKey('artist-featured-songs-section-title'),
                  title: 'Bài Hát Nổi Bật',
                ),
              ),
              if (totalSongCount > featuredSongs.length)
                TextButton.icon(
                  key: const ValueKey('artist-desktop-songs-show-all'),
                  onPressed: onShowAllSongs,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.05,
                    ),
                  ),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.chevron_right_rounded, size: 18),
                  label: const Text('TẤT CẢ'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              for (var index = 0; index < featuredSongs.length; index++) ...[
                songBuilder(context, index),
                if (index != featuredSongs.length - 1)
                  Divider(
                    height: 1,
                    indent: 64,
                    color: scheme.outlineVariant.withValues(alpha: 0.2),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopSectionTitle extends StatelessWidget {
  const _DesktopSectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: 20,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.25,
    ),
  );
}

class _LatestReleaseCard extends StatefulWidget {
  const _LatestReleaseCard({
    required this.collection,
    required this.releaseLabel,
    required this.onTap,
  });

  final CatalogCollection collection;
  final String releaseLabel;
  final VoidCallback onTap;

  @override
  State<_LatestReleaseCard> createState() => _LatestReleaseCardState();
}

class _LatestReleaseCardState extends State<_LatestReleaseCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final collection = widget.collection;
    final scheme = Theme.of(context).colorScheme;
    final active = _hovered || _focused;
    return Semantics(
      button: true,
      label: 'Mở ${collection.title}',
      child: Material(
        key: ValueKey('artist-latest-release-${collection.id}'),
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (value) => setState(() => _hovered = value),
          onFocusChange: (value) => setState(() => _focused = value),
          mouseCursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            key: ValueKey('artist-latest-release-surface-${collection.id}'),
            duration: const Duration(milliseconds: 170),
            height: 184,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(
                color: active
                    ? ZingColors.lime
                    : scheme.outlineVariant.withValues(alpha: 0.18),
                width: active ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 156,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: collection.thumbnail.isEmpty
                            ? const _ReleaseArtworkFallback()
                            : Image.network(
                                collection.thumbnail,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const _ReleaseArtworkFallback(),
                              ),
                      ),
                      AnimatedOpacity(
                        opacity: active ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.28),
                          child: const Center(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: ZingColors.purple,
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(10),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.releaseLabel,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        collection.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 17,
                          height: 1.18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        collection.artist,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Nội dung chính thức trên Zing MP3',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
    );
  }
}

class _ReleaseArtworkFallback extends StatelessWidget {
  const _ReleaseArtworkFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF30273B),
    child: Center(
      child: Icon(
        Icons.album_rounded,
        color: Theme.of(context).colorScheme.primary,
        size: 48,
      ),
    ),
  );
}
