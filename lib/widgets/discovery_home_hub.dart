import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/catalog_search.dart';
import '../models/chart_snapshot.dart';
import '../models/discovery_home.dart';
import '../models/new_release_chart.dart';
import '../models/release_catalog.dart';
import '../models/song.dart';
import '../models/weekly_chart.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';
import 'catalog_artist_links.dart';
import 'catalog_collection_action_deck.dart';
import 'release_catalog_view.dart';
import 'realtime_chart.dart';
import 'song_action_menu.dart';

enum DiscoveryReleaseRegion { all, vietnam, international }

extension DiscoveryReleaseRegionLabel on DiscoveryReleaseRegion {
  String get label => switch (this) {
    DiscoveryReleaseRegion.all => 'TẤT CẢ',
    DiscoveryReleaseRegion.vietnam => 'VIỆT NAM',
    DiscoveryReleaseRegion.international => 'QUỐC TẾ',
  };
}

class DiscoveryHomeHub extends StatelessWidget {
  const DiscoveryHomeHub({
    super.key,
    required this.home,
    required this.loading,
    required this.errorMessage,
    required this.onRetry,
    required this.categories,
    required this.categoriesLoading,
    required this.categoriesErrorMessage,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    required this.onRetryCategories,
    this.showCategoryRail = true,
    required this.onCollectionTap,
    this.onCollectionPlay,
    this.onCollectionToggleSaved,
    this.onCollectionShare,
    this.onCollectionArtistTap,
    this.savedCollectionIds = const {},
    this.quickPlayingCollectionId,
    required this.onVideoTap,
    required this.onOpenHubHome,
    required this.onOpenTop100,
    required this.onOpenReleases,
    required this.onOpenWeeklyChart,
    this.onOpenWeeklyChartRegion,
    required this.recommendations,
    this.recommendationsOfficial = false,
    this.recommendationCatalogBySongId = const {},
    required this.canRefreshRecommendations,
    required this.onRecommendationTap,
    required this.onRefreshRecommendations,
    this.likedRecommendationIds = const {},
    this.onRecommendationToggleLike,
    this.onRecommendationAddToQueue,
    this.onRecommendationOpenDetail,
    this.onRecommendationStartRadio,
    this.onRecommendationAddToPlaylist,
    this.onRecommendationShare,
    this.onRecommendationArtistTap,
    this.recentlyPlayed = const [],
    this.onRecentSongTap,
    this.recentSongActionResolver,
    this.onOpenLibrary,
    this.newReleaseChartEntries = const [],
    this.newReleaseChartLoading = false,
    this.newReleaseChartErrorMessage,
    this.onNewReleaseChartEntryTap,
    this.newReleaseChartActionResolver,
    this.onOpenNewReleaseChart,
    this.onRetryNewReleaseChart,
    this.realtimeChartSnapshot = const ChartSnapshot(songs: []),
    this.onRealtimeChartPlay,
    this.onOpenRealtimeChart,
    required this.releaseSongs,
    required this.releaseLoading,
    required this.releaseErrorMessage,
    required this.releaseRegion,
    required this.onReleaseRegionChanged,
    required this.onReleaseTap,
    this.likedReleaseSongIds = const {},
    this.onReleaseToggleLike,
    this.onReleaseAddToQueue,
    this.onReleaseOpenDetail,
    this.onReleaseStartRadio,
    this.onReleaseAddToPlaylist,
    this.onReleaseShare,
    required this.onRetryReleases,
    this.tvMode = false,
  });

  final DiscoveryHome home;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final List<DiscoveryCategory> categories;
  final bool categoriesLoading;
  final String? categoriesErrorMessage;
  final String selectedCategoryId;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onRetryCategories;
  final bool showCategoryRail;
  final ValueChanged<CatalogCollection> onCollectionTap;
  final ValueChanged<CatalogCollection>? onCollectionPlay;
  final ValueChanged<CatalogCollection>? onCollectionToggleSaved;
  final ValueChanged<CatalogCollection>? onCollectionShare;
  final ValueChanged<CatalogArtist>? onCollectionArtistTap;
  final Set<String> savedCollectionIds;
  final String? quickPlayingCollectionId;
  final ValueChanged<CatalogVideo> onVideoTap;
  final VoidCallback onOpenHubHome;
  final VoidCallback onOpenTop100;
  final VoidCallback onOpenReleases;
  final VoidCallback onOpenWeeklyChart;
  final ValueChanged<WeeklyChartRegion>? onOpenWeeklyChartRegion;
  final List<Song> recommendations;
  final bool recommendationsOfficial;
  final Map<String, CatalogSong> recommendationCatalogBySongId;
  final bool canRefreshRecommendations;
  final ValueChanged<Song> onRecommendationTap;
  final VoidCallback onRefreshRecommendations;
  final Set<String> likedRecommendationIds;
  final ValueChanged<Song>? onRecommendationToggleLike;
  final ValueChanged<Song>? onRecommendationAddToQueue;
  final ValueChanged<Song>? onRecommendationOpenDetail;
  final ValueChanged<Song>? onRecommendationStartRadio;
  final ValueChanged<Song>? onRecommendationAddToPlaylist;
  final ValueChanged<Song>? onRecommendationShare;
  final ValueChanged<CatalogArtist>? onRecommendationArtistTap;
  final List<Song> recentlyPlayed;
  final ValueChanged<Song>? onRecentSongTap;
  final SongActionMenuConfiguration Function(Song)? recentSongActionResolver;
  final VoidCallback? onOpenLibrary;
  final List<NewReleaseEntry> newReleaseChartEntries;
  final bool newReleaseChartLoading;
  final String? newReleaseChartErrorMessage;
  final ValueChanged<NewReleaseEntry>? onNewReleaseChartEntryTap;
  final SongActionMenuConfiguration Function(NewReleaseEntry)?
  newReleaseChartActionResolver;
  final VoidCallback? onOpenNewReleaseChart;
  final VoidCallback? onRetryNewReleaseChart;
  final ChartSnapshot realtimeChartSnapshot;
  final void Function(Song song, List<Song> queue)? onRealtimeChartPlay;
  final VoidCallback? onOpenRealtimeChart;
  final List<ReleaseSong> releaseSongs;
  final bool releaseLoading;
  final String? releaseErrorMessage;
  final DiscoveryReleaseRegion releaseRegion;
  final ValueChanged<DiscoveryReleaseRegion> onReleaseRegionChanged;
  final ValueChanged<ReleaseSong> onReleaseTap;
  final Set<String> likedReleaseSongIds;
  final ValueChanged<ReleaseSong>? onReleaseToggleLike;
  final ValueChanged<ReleaseSong>? onReleaseAddToQueue;
  final ValueChanged<ReleaseSong>? onReleaseOpenDetail;
  final ValueChanged<ReleaseSong>? onReleaseStartRadio;
  final ValueChanged<ReleaseSong>? onReleaseAddToPlaylist;
  final ValueChanged<ReleaseSong>? onReleaseShare;
  final VoidCallback onRetryReleases;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final horizontal = tvMode ? 32.0 : 20.0;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final compactDesktop = !tvMode && viewportWidth >= 720;
    final hasDesktopCatalogSidebar = !tvMode && viewportWidth >= 1320;
    final switchingCategory =
        loading && !home.isEmpty && selectedCategoryId != home.categoryId;
    var selectedCategoryName = 'danh mục đã chọn';
    if (selectedCategoryId == '-1') {
      selectedCategoryName = 'Cho bạn';
    } else {
      for (final category in categories) {
        if (category.id == selectedCategoryId) {
          selectedCategoryName = category.name;
          break;
        }
      }
    }
    return Padding(
      key: ValueKey(
        loading && home.isEmpty
            ? 'discovery-home-loading'
            : errorMessage != null && home.isEmpty
            ? 'discovery-home-error'
            : home.isEmpty
            ? 'discovery-home-empty'
            : 'discovery-home',
      ),
      padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, tvMode ? 52 : 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showCategoryRail) ...[
            DiscoveryCategoryRail(
              categories: categories,
              loading: categoriesLoading,
              errorMessage: categoriesErrorMessage,
              selectedCategoryId: selectedCategoryId,
              onSelected: onCategorySelected,
              onRetry: onRetryCategories,
              tvMode: tvMode,
            ),
            SizedBox(height: tvMode ? 24 : 18),
          ],
          if (home.isEmpty && recommendations.isNotEmpty) ...[
            DiscoveryRecommendationShelf(
              songs: recommendations,
              official: recommendationsOfficial,
              catalogBySongId: recommendationCatalogBySongId,
              canRefresh: canRefreshRecommendations,
              onSongTap: onRecommendationTap,
              onRefresh: onRefreshRecommendations,
              likedSongIds: likedRecommendationIds,
              onToggleLike: onRecommendationToggleLike,
              onAddToQueue: onRecommendationAddToQueue,
              onOpenDetail: onRecommendationOpenDetail,
              onStartRadio: onRecommendationStartRadio,
              onAddToPlaylist: onRecommendationAddToPlaylist,
              onShare: onRecommendationShare,
              onArtistTap: onRecommendationArtistTap,
              tvMode: tvMode,
            ),
            SizedBox(height: tvMode ? 28 : 22),
          ],
          if (home.isEmpty &&
              selectedCategoryId == '-1' &&
              recentlyPlayed.isNotEmpty &&
              onRecentSongTap != null) ...[
            DiscoveryRecentlyPlayedShelf(
              songs: recentlyPlayed,
              onSongTap: onRecentSongTap!,
              actionResolver: recentSongActionResolver,
              onOpenLibrary: onOpenLibrary,
              tvMode: tvMode,
            ),
            SizedBox(height: tvMode ? 28 : 22),
          ],
          if (home.isEmpty &&
              selectedCategoryId == '-1' &&
              realtimeChartSnapshot.hasRealtimeSeries &&
              onRealtimeChartPlay != null) ...[
            DiscoveryZingChartPreview(
              snapshot: realtimeChartSnapshot,
              onPlay: onRealtimeChartPlay!,
              onOpenAll: onOpenRealtimeChart,
              tvMode: tvMode,
            ),
            SizedBox(height: tvMode ? 28 : 22),
          ],
          if (home.isEmpty &&
              selectedCategoryId == '-1' &&
              onOpenWeeklyChartRegion != null) ...[
            DiscoveryWeeklyChartRegionRail(
              onOpenRegion: onOpenWeeklyChartRegion!,
              tvMode: tvMode,
            ),
            SizedBox(height: tvMode ? 28 : 22),
          ],
          if (home.isEmpty &&
              selectedCategoryId == '-1' &&
              (releaseLoading ||
                  releaseErrorMessage != null ||
                  releaseSongs.isNotEmpty)) ...[
            DiscoveryNewReleaseShelf(
              songs: releaseSongs,
              loading: releaseLoading,
              errorMessage: releaseErrorMessage,
              region: releaseRegion,
              onRegionChanged: onReleaseRegionChanged,
              onSongTap: onReleaseTap,
              likedSongIds: likedReleaseSongIds,
              onToggleLike: onReleaseToggleLike,
              onAddToQueue: onReleaseAddToQueue,
              onOpenDetail: onReleaseOpenDetail,
              onStartRadio: onReleaseStartRadio,
              onAddToPlaylist: onReleaseAddToPlaylist,
              onShare: onReleaseShare,
              onOpenAll: onOpenReleases,
              onRetry: onRetryReleases,
              tvMode: tvMode,
            ),
            SizedBox(height: tvMode ? 28 : 22),
          ],
          if (home.isEmpty &&
              selectedCategoryId == '-1' &&
              (newReleaseChartLoading ||
                  newReleaseChartErrorMessage != null ||
                  newReleaseChartEntries.isNotEmpty)) ...[
            DiscoveryNewReleaseChartSpotlight(
              entries: newReleaseChartEntries,
              loading: newReleaseChartLoading,
              errorMessage: newReleaseChartErrorMessage,
              onEntryTap: onNewReleaseChartEntryTap,
              actionResolver: newReleaseChartActionResolver,
              onOpenAll: onOpenNewReleaseChart,
              onRetry: onRetryNewReleaseChart,
              tvMode: tvMode,
            ),
            SizedBox(height: tvMode ? 28 : 22),
          ],
          if (loading && home.isEmpty)
            _DiscoveryLoadingState(tvMode: tvMode)
          else if (errorMessage != null && home.isEmpty)
            _DiscoveryErrorState(onRetry: onRetry)
          else if (home.isEmpty)
            _DiscoveryErrorState(onRetry: onRetry, empty: true)
          else ...[
            if (switchingCategory) ...[
              _DiscoveryCategorySwitchNotice(
                categoryName: selectedCategoryName,
                tvMode: tvMode,
              ),
              SizedBox(height: tvMode ? 20 : 14),
            ],
            ExcludeSemantics(
              excluding: switchingCategory,
              child: ExcludeFocus(
                key: const ValueKey('discovery-home-stale-focus'),
                excluding: switchingCategory,
                child: IgnorePointer(
                  key: const ValueKey('discovery-home-stale-content'),
                  ignoring: switchingCategory,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: switchingCategory ? 0.48 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (errorMessage != null) ...[
                          _StaleDiscoveryNotice(onRetry: onRetry),
                          const SizedBox(height: 18),
                        ],
                        if (!compactDesktop) ...[
                          _DiscoveryQuickLinks(
                            onOpenHubHome: onOpenHubHome,
                            onOpenTop100: onOpenTop100,
                            onOpenReleases: onOpenReleases,
                            onOpenWeeklyChart: onOpenWeeklyChart,
                            tvMode: tvMode,
                          ),
                          SizedBox(height: tvMode ? 28 : 22),
                        ],
                        if (home.quickPlay.isNotEmpty) ...[
                          _DiscoveryQuickPlayRail(
                            key: ValueKey(
                              'discovery-quick-play-${home.categoryId}-'
                              '${home.quickPlay.map((entry) => entry.collection.id).join(',')}',
                            ),
                            entries: home.quickPlay,
                            tvMode: tvMode,
                            onCollectionTap: onCollectionTap,
                          ),
                          SizedBox(height: tvMode ? 32 : 24),
                        ],
                        if (home.banners.isNotEmpty) ...[
                          _BannerRail(
                            key: ValueKey(
                              'discovery-banner-category-${home.categoryId}',
                            ),
                            banners: home.banners,
                            tvMode: tvMode,
                            onCollectionTap: onCollectionTap,
                          ),
                          SizedBox(height: tvMode ? 38 : 30),
                        ],
                        if (home.videos.isNotEmpty) ...[
                          DiscoveryVideoShelf(
                            videos: home.videos,
                            onVideoTap: onVideoTap,
                            tvMode: tvMode,
                          ),
                          SizedBox(height: tvMode ? 38 : 30),
                        ],
                        if (recommendations.isNotEmpty) ...[
                          DiscoveryRecommendationShelf(
                            songs: recommendations,
                            official: recommendationsOfficial,
                            catalogBySongId: recommendationCatalogBySongId,
                            canRefresh: canRefreshRecommendations,
                            onSongTap: onRecommendationTap,
                            onRefresh: onRefreshRecommendations,
                            likedSongIds: likedRecommendationIds,
                            onToggleLike: onRecommendationToggleLike,
                            onAddToQueue: onRecommendationAddToQueue,
                            onOpenDetail: onRecommendationOpenDetail,
                            onStartRadio: onRecommendationStartRadio,
                            onAddToPlaylist: onRecommendationAddToPlaylist,
                            onShare: onRecommendationShare,
                            onArtistTap: onRecommendationArtistTap,
                            tvMode: tvMode,
                          ),
                          SizedBox(height: tvMode ? 38 : 30),
                        ],
                        if (selectedCategoryId == '-1' &&
                            recentlyPlayed.isNotEmpty &&
                            onRecentSongTap != null) ...[
                          DiscoveryRecentlyPlayedShelf(
                            songs: recentlyPlayed,
                            onSongTap: onRecentSongTap!,
                            actionResolver: recentSongActionResolver,
                            onOpenLibrary: onOpenLibrary,
                            tvMode: tvMode,
                          ),
                          SizedBox(height: tvMode ? 38 : 30),
                        ],
                        if (compactDesktop && !hasDesktopCatalogSidebar) ...[
                          _DiscoveryQuickLinks(
                            onOpenHubHome: onOpenHubHome,
                            onOpenTop100: onOpenTop100,
                            onOpenReleases: onOpenReleases,
                            onOpenWeeklyChart: onOpenWeeklyChart,
                            tvMode: tvMode,
                          ),
                          const SizedBox(height: 30),
                        ],
                        for (
                          var sectionIndex = 0;
                          sectionIndex < home.sections.length;
                          sectionIndex++
                        ) ...[
                          _CollectionSection(
                            key: ValueKey(
                              'discovery-section-${home.sections[sectionIndex].id}',
                            ),
                            section: home.sections[sectionIndex],
                            tvMode: tvMode,
                            onOpenAll:
                                home.sections[sectionIndex].title
                                        .trim()
                                        .toLowerCase() ==
                                    'top 100'
                                ? onOpenTop100
                                : null,
                            onCollectionTap: onCollectionTap,
                            onCollectionPlay: onCollectionPlay,
                            onCollectionToggleSaved: onCollectionToggleSaved,
                            onCollectionShare: onCollectionShare,
                            onCollectionArtistTap: onCollectionArtistTap,
                            savedCollectionIds: savedCollectionIds,
                            quickPlayingCollectionId: quickPlayingCollectionId,
                          ),
                          SizedBox(height: tvMode ? 38 : 30),
                          if (selectedCategoryId == '-1' &&
                              sectionIndex ==
                                  (home.sections.length > 1 ? 1 : 0)) ...[
                            if (releaseLoading ||
                                releaseErrorMessage != null ||
                                releaseSongs.isNotEmpty) ...[
                              DiscoveryNewReleaseShelf(
                                songs: releaseSongs,
                                loading: releaseLoading,
                                errorMessage: releaseErrorMessage,
                                region: releaseRegion,
                                onRegionChanged: onReleaseRegionChanged,
                                onSongTap: onReleaseTap,
                                likedSongIds: likedReleaseSongIds,
                                onToggleLike: onReleaseToggleLike,
                                onAddToQueue: onReleaseAddToQueue,
                                onOpenDetail: onReleaseOpenDetail,
                                onStartRadio: onReleaseStartRadio,
                                onAddToPlaylist: onReleaseAddToPlaylist,
                                onShare: onReleaseShare,
                                onOpenAll: onOpenReleases,
                                onRetry: onRetryReleases,
                                tvMode: tvMode,
                              ),
                              SizedBox(height: tvMode ? 38 : 30),
                            ],
                            if (newReleaseChartLoading ||
                                newReleaseChartErrorMessage != null ||
                                newReleaseChartEntries.isNotEmpty) ...[
                              DiscoveryNewReleaseChartSpotlight(
                                entries: newReleaseChartEntries,
                                loading: newReleaseChartLoading,
                                errorMessage: newReleaseChartErrorMessage,
                                onEntryTap: onNewReleaseChartEntryTap,
                                actionResolver: newReleaseChartActionResolver,
                                onOpenAll: onOpenNewReleaseChart,
                                onRetry: onRetryNewReleaseChart,
                                tvMode: tvMode,
                              ),
                              SizedBox(height: tvMode ? 38 : 30),
                            ],
                            if (realtimeChartSnapshot.hasRealtimeSeries &&
                                onRealtimeChartPlay != null) ...[
                              DiscoveryZingChartPreview(
                                snapshot: realtimeChartSnapshot,
                                onPlay: onRealtimeChartPlay!,
                                onOpenAll: onOpenRealtimeChart,
                                tvMode: tvMode,
                              ),
                              SizedBox(height: tvMode ? 38 : 30),
                            ],
                            if (onOpenWeeklyChartRegion != null) ...[
                              DiscoveryWeeklyChartRegionRail(
                                onOpenRegion: onOpenWeeklyChartRegion!,
                                tvMode: tvMode,
                              ),
                              SizedBox(height: tvMode ? 38 : 30),
                            ],
                          ],
                        ],
                        if (selectedCategoryId == '-1' &&
                            home.sections.isEmpty) ...[
                          if (releaseLoading ||
                              releaseErrorMessage != null ||
                              releaseSongs.isNotEmpty) ...[
                            DiscoveryNewReleaseShelf(
                              songs: releaseSongs,
                              loading: releaseLoading,
                              errorMessage: releaseErrorMessage,
                              region: releaseRegion,
                              onRegionChanged: onReleaseRegionChanged,
                              onSongTap: onReleaseTap,
                              likedSongIds: likedReleaseSongIds,
                              onToggleLike: onReleaseToggleLike,
                              onAddToQueue: onReleaseAddToQueue,
                              onOpenDetail: onReleaseOpenDetail,
                              onStartRadio: onReleaseStartRadio,
                              onAddToPlaylist: onReleaseAddToPlaylist,
                              onShare: onReleaseShare,
                              onOpenAll: onOpenReleases,
                              onRetry: onRetryReleases,
                              tvMode: tvMode,
                            ),
                            SizedBox(height: tvMode ? 38 : 30),
                          ],
                          if (newReleaseChartLoading ||
                              newReleaseChartErrorMessage != null ||
                              newReleaseChartEntries.isNotEmpty) ...[
                            DiscoveryNewReleaseChartSpotlight(
                              entries: newReleaseChartEntries,
                              loading: newReleaseChartLoading,
                              errorMessage: newReleaseChartErrorMessage,
                              onEntryTap: onNewReleaseChartEntryTap,
                              actionResolver: newReleaseChartActionResolver,
                              onOpenAll: onOpenNewReleaseChart,
                              onRetry: onRetryNewReleaseChart,
                              tvMode: tvMode,
                            ),
                            SizedBox(height: tvMode ? 38 : 30),
                          ],
                          if (realtimeChartSnapshot.hasRealtimeSeries &&
                              onRealtimeChartPlay != null) ...[
                            DiscoveryZingChartPreview(
                              snapshot: realtimeChartSnapshot,
                              onPlay: onRealtimeChartPlay!,
                              onOpenAll: onOpenRealtimeChart,
                              tvMode: tvMode,
                            ),
                            SizedBox(height: tvMode ? 38 : 30),
                          ],
                          if (onOpenWeeklyChartRegion != null) ...[
                            DiscoveryWeeklyChartRegionRail(
                              onOpenRegion: onOpenWeeklyChartRegion!,
                              tvMode: tvMode,
                            ),
                            SizedBox(height: tvMode ? 38 : 30),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DiscoveryWeeklyChartRegionRail extends StatelessWidget {
  const DiscoveryWeeklyChartRegionRail({
    super.key,
    required this.onOpenRegion,
    required this.tvMode,
  });

  final ValueChanged<WeeklyChartRegion> onOpenRegion;
  final bool tvMode;

  static const _cards = [
    (
      region: WeeklyChartRegion.vietnam,
      title: 'Việt Nam',
      subtitle: 'V-Pop dẫn đầu tuần',
      icon: Icons.local_fire_department_rounded,
      colors: [Color(0xFFE35050), Color(0xFF9B4DE0)],
    ),
    (
      region: WeeklyChartRegion.usuk,
      title: 'US-UK',
      subtitle: 'Âu Mỹ nổi bật',
      icon: Icons.public_rounded,
      colors: [Color(0xFF4A90E2), Color(0xFF6247D9)],
    ),
    (
      region: WeeklyChartRegion.korea,
      title: 'K-Pop',
      subtitle: 'Hàn Quốc thịnh hành',
      icon: Icons.auto_awesome_rounded,
      colors: [Color(0xFF27C9A0), Color(0xFF5966D9)],
    ),
  ];

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('discovery-weekly-chart-regions'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'BXH TUẦN',
        style: TextStyle(
          color: ZingColors.lime,
          fontSize: tvMode ? 14 : 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.35,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Bảng Xếp Hạng Tuần',
        style: TextStyle(
          fontSize: tvMode ? 29 : 23,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.65,
        ),
      ),
      SizedBox(height: tvMode ? 18 : 13),
      LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 720) {
            return SizedBox(
              height: tvMode ? 150 : 126,
              child: ListView.separated(
                key: const ValueKey('discovery-weekly-region-list'),
                scrollDirection: Axis.horizontal,
                itemCount: _cards.length,
                separatorBuilder: (_, __) => SizedBox(width: tvMode ? 16 : 11),
                itemBuilder: (context, index) => SizedBox(
                  width: math.min(
                    tvMode ? 430 : 286,
                    constraints.maxWidth * 0.84,
                  ),
                  child: _DiscoveryWeeklyRegionCard(
                    card: _cards[index],
                    index: index,
                    onTap: () => onOpenRegion(_cards[index].region),
                    tvMode: tvMode,
                  ),
                ),
              ),
            );
          }
          return Row(
            children: [
              for (var index = 0; index < _cards.length; index++) ...[
                Expanded(
                  child: SizedBox(
                    height: tvMode ? 150 : 126,
                    child: _DiscoveryWeeklyRegionCard(
                      card: _cards[index],
                      index: index,
                      onTap: () => onOpenRegion(_cards[index].region),
                      tvMode: tvMode,
                    ),
                  ),
                ),
                if (index != _cards.length - 1)
                  SizedBox(width: tvMode ? 18 : 13),
              ],
            ],
          );
        },
      ),
    ],
  );
}

class _DiscoveryWeeklyRegionCard extends StatefulWidget {
  const _DiscoveryWeeklyRegionCard({
    required this.card,
    required this.index,
    required this.onTap,
    required this.tvMode,
  });

  final ({
    WeeklyChartRegion region,
    String title,
    String subtitle,
    IconData icon,
    List<Color> colors,
  })
  card;
  final int index;
  final VoidCallback onTap;
  final bool tvMode;

  @override
  State<_DiscoveryWeeklyRegionCard> createState() =>
      _DiscoveryWeeklyRegionCardState();
}

class _DiscoveryWeeklyRegionCardState
    extends State<_DiscoveryWeeklyRegionCard> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = _focused || _hovered;
    final card = widget.card;
    return Semantics(
      excludeSemantics: true,
      button: true,
      label: 'Mở Bảng Xếp Hạng Tuần ${card.title}',
      onTap: widget.onTap,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: InkWell(
          key: ValueKey('discovery-weekly-region-${card.region.wireValue}'),
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(widget.tvMode ? 22 : 18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOut,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: card.colors,
              ),
              borderRadius: BorderRadius.circular(widget.tvMode ? 22 : 18),
              border: Border.all(
                color: active
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.14),
                width: active ? 3 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: card.colors.first.withValues(
                    alpha: active ? 0.34 : 0.2,
                  ),
                  blurRadius: active ? 24 : 15,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: widget.tvMode ? -30 : -24,
                  top: widget.tvMode ? -34 : -28,
                  child: Container(
                    width: widget.tvMode ? 138 : 112,
                    height: widget.tvMode ? 138 : 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                Positioned(
                  right: widget.tvMode ? 20 : 15,
                  bottom: widget.tvMode ? 13 : 9,
                  child: Text(
                    '0${widget.index + 1}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.16),
                      fontSize: widget.tvMode ? 72 : 58,
                      height: 0.9,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(widget.tvMode ? 20 : 16),
                  child: Row(
                    children: [
                      Container(
                        width: widget.tvMode ? 58 : 46,
                        height: widget.tvMode ? 58 : 46,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(
                            widget.tvMode ? 17 : 14,
                          ),
                        ),
                        child: Icon(
                          card.icon,
                          color: Colors.white,
                          size: widget.tvMode ? 31 : 25,
                        ),
                      ),
                      SizedBox(width: widget.tvMode ? 16 : 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              card.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: widget.tvMode ? 24 : 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              card.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: widget.tvMode ? 15 : 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white.withValues(
                          alpha: active ? 1 : 0.78,
                        ),
                        size: widget.tvMode ? 28 : 22,
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

class DiscoveryZingChartPreview extends StatelessWidget {
  const DiscoveryZingChartPreview({
    super.key,
    required this.snapshot,
    required this.onPlay,
    required this.onOpenAll,
    required this.tvMode,
  });

  final ChartSnapshot snapshot;
  final void Function(Song song, List<Song> queue) onPlay;
  final VoidCallback? onOpenAll;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final songs = RealtimeChart.visibleSongs(snapshot);
    if (songs.isEmpty || !snapshot.hasRealtimeSeries) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: 'Xem nhanh #zingchart realtime, ${songs.length} bài dẫn đầu',
      child: Container(
        key: const ValueKey('discovery-zingchart-preview'),
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.all(tvMode ? 24 : 18),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(tvMode ? 24 : 20),
          border: Border.all(
            color: ZingColors.purpleBright.withValues(alpha: 0.28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DiscoveryZingChartHeader(
              title: '#zingchart',
              eyebrow: 'REALTIME · 24 GIỜ',
              actionLabel: onOpenAll == null ? null : 'XEM THÊM',
              onAction: onOpenAll,
              tvMode: tvMode,
            ),
            SizedBox(height: tvMode ? 22 : 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final sideBySide = constraints.maxWidth >= 760;
                final chart = RealtimeChart(
                  snapshot: snapshot,
                  onPlay: onPlay,
                  compact: true,
                );
                final ranking = _DiscoveryZingChartRanking(
                  songs: songs,
                  snapshot: snapshot,
                  onPlay: onPlay,
                  tvMode: tvMode,
                );
                if (!sideBySide) {
                  return Column(
                    children: [
                      chart,
                      SizedBox(height: tvMode ? 24 : 16),
                      ranking,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: chart),
                    SizedBox(width: tvMode ? 28 : 22),
                    Expanded(flex: 5, child: ranking),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryZingChartHeader extends StatelessWidget {
  const _DiscoveryZingChartHeader({
    required this.title,
    required this.eyebrow,
    required this.actionLabel,
    required this.onAction,
    required this.tvMode,
  });

  final String title;
  final String eyebrow;
  final String? actionLabel;
  final VoidCallback? onAction;
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
              eyebrow,
              style: TextStyle(
                color: ZingColors.lime,
                fontSize: tvMode ? 14 : 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.35,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: TextStyle(
                fontSize: tvMode ? 34 : 27,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
      ),
      if (actionLabel != null && onAction != null)
        TextButton.icon(
          key: const ValueKey('discovery-zingchart-open-all'),
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            minimumSize: Size(0, tvMode ? 52 : 44),
            padding: EdgeInsets.symmetric(horizontal: tvMode ? 17 : 12),
          ),
          iconAlignment: IconAlignment.end,
          icon: Icon(Icons.arrow_forward_rounded, size: tvMode ? 24 : 19),
          label: Text(
            actionLabel!,
            style: TextStyle(
              fontSize: tvMode ? 15 : 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.65,
            ),
          ),
        ),
    ],
  );
}

class _DiscoveryZingChartRanking extends StatelessWidget {
  const _DiscoveryZingChartRanking({
    required this.songs,
    required this.snapshot,
    required this.onPlay,
    required this.tvMode,
  });

  final List<Song> songs;
  final ChartSnapshot snapshot;
  final void Function(Song song, List<Song> queue) onPlay;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < songs.length; index++) ...[
        _DiscoveryZingChartRow(
          song: songs[index],
          rank:
              snapshot.songs.indexWhere(
                (candidate) => candidate.id == songs[index].id,
              ) +
              1,
          seriesIndex: index,
          metadata: snapshot.songMetadata[songs[index].id],
          onTap: () => onPlay(songs[index], snapshot.songs),
          tvMode: tvMode,
        ),
        if (index != songs.length - 1)
          Divider(
            height: tvMode ? 14 : 10,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.28),
          ),
      ],
    ],
  );
}

class _DiscoveryZingChartRow extends StatefulWidget {
  const _DiscoveryZingChartRow({
    required this.song,
    required this.rank,
    required this.seriesIndex,
    required this.metadata,
    required this.onTap,
    required this.tvMode,
  });

  final Song song;
  final int rank;
  final int seriesIndex;
  final ChartSongMetadata? metadata;
  final VoidCallback onTap;
  final bool tvMode;

  @override
  State<_DiscoveryZingChartRow> createState() => _DiscoveryZingChartRowState();
}

class _DiscoveryZingChartRowState extends State<_DiscoveryZingChartRow> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = _focused || _hovered;
    final accent =
        RealtimeChart.lineColors[widget.seriesIndex
            .clamp(0, RealtimeChart.lineColors.length - 1)
            .toInt()];
    final rankChange = widget.metadata?.rankChange;
    return Semantics(
      excludeSemantics: true,
      button: true,
      label:
          'Phát hạng ${widget.rank}, ${widget.song.displayTitle}, '
          '${widget.song.artistsNames}',
      onTap: widget.onTap,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: InkWell(
          key: ValueKey('discovery-zingchart-song-${widget.song.id}'),
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(widget.tvMode ? 16 : 13),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: BoxConstraints(minHeight: widget.tvMode ? 88 : 72),
            padding: EdgeInsets.symmetric(
              horizontal: widget.tvMode ? 14 : 10,
              vertical: widget.tvMode ? 10 : 8,
            ),
            decoration: BoxDecoration(
              color: active
                  ? accent.withValues(alpha: 0.13)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(widget.tvMode ? 16 : 13),
              border: Border.all(
                color: active
                    ? accent.withValues(alpha: 0.72)
                    : Colors.transparent,
                width: 1.4,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: widget.tvMode ? 38 : 32,
                  child: Text(
                    '${widget.rank}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: accent,
                      fontSize: widget.tvMode ? 27 : 22,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                SizedBox(width: widget.tvMode ? 12 : 9),
                AlbumArt(
                  imageUrl: widget.song.thumbnail,
                  semanticLabel: 'Ảnh bìa ${widget.song.displayTitle}',
                  size: widget.tvMode ? 64 : 52,
                  borderRadius: widget.tvMode ? 12 : 10,
                ),
                SizedBox(width: widget.tvMode ? 14 : 11),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: widget.tvMode ? 18 : 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.song.artistsNames,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: widget.tvMode ? 15 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (rankChange != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    rankChange > 0
                        ? Icons.arrow_drop_up_rounded
                        : rankChange < 0
                        ? Icons.arrow_drop_down_rounded
                        : Icons.remove_rounded,
                    color: rankChange > 0
                        ? ZingColors.lime
                        : rankChange < 0
                        ? ZingColors.coral
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    size: widget.tvMode ? 28 : 22,
                  ),
                ],
                SizedBox(width: widget.tvMode ? 6 : 3),
                Icon(
                  active ? Icons.play_circle_fill_rounded : Icons.play_arrow,
                  color: active ? accent : Theme.of(context).hintColor,
                  size: widget.tvMode ? 32 : 25,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoveryCategorySwitchNotice extends StatelessWidget {
  const _DiscoveryCategorySwitchNotice({
    required this.categoryName,
    required this.tvMode,
  });

  final String categoryName;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Đang tải danh mục $categoryName',
    child: Container(
      key: const ValueKey('discovery-category-switching'),
      padding: EdgeInsets.symmetric(
        horizontal: tvMode ? 18 : 13,
        vertical: tvMode ? 13 : 9,
      ),
      decoration: BoxDecoration(
        color: ZingColors.purple.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(tvMode ? 15 : 12),
        border: Border.all(
          color: ZingColors.purpleBright.withValues(alpha: 0.52),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: tvMode ? 22 : 17,
            child: const CircularProgressIndicator(
              strokeWidth: 2.4,
              color: ZingColors.purpleBright,
            ),
          ),
          SizedBox(width: tvMode ? 13 : 9),
          Flexible(
            child: Text(
              'Đang tải $categoryName · nội dung cũ tạm khóa',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: tvMode ? 16 : 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class DiscoveryCategoryRail extends StatelessWidget {
  const DiscoveryCategoryRail({
    required this.categories,
    required this.loading,
    required this.errorMessage,
    required this.selectedCategoryId,
    required this.onSelected,
    required this.onRetry,
    required this.tvMode,
  });

  final List<DiscoveryCategory> categories;
  final bool loading;
  final String? errorMessage;
  final String selectedCategoryId;
  final ValueChanged<String> onSelected;
  final VoidCallback onRetry;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final items = <DiscoveryCategory>[
      const DiscoveryCategory(id: '-1', name: 'Cho bạn'),
      ...categories,
    ];
    final height = tvMode ? 58.0 : 48.0;
    return Column(
      key: const ValueKey('discovery-category-rail'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: ListView.separated(
            key: const ValueKey('discovery-category-list'),
            scrollDirection: Axis.horizontal,
            itemCount: items.length + (loading && categories.isEmpty ? 3 : 0),
            separatorBuilder: (_, __) => SizedBox(width: tvMode ? 13 : 9),
            itemBuilder: (context, index) {
              if (index >= items.length) {
                return _DiscoveryCategorySkeleton(
                  width: 88.0 + (index - items.length) * 16,
                  tvMode: tvMode,
                );
              }
              final category = items[index];
              return _DiscoveryCategoryChip(
                key: ValueKey('discovery-category-${category.id}'),
                category: category,
                selected: selectedCategoryId == category.id,
                onTap: () => onSelected(category.id),
                tvMode: tvMode,
              );
            },
          ),
        ),
        if (errorMessage != null && categories.isEmpty) ...[
          const SizedBox(height: 7),
          TextButton.icon(
            key: const ValueKey('retry-discovery-categories'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Tải lại danh mục'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            ),
          ),
        ],
      ],
    );
  }
}

class _DiscoveryCategorySkeleton extends StatelessWidget {
  const _DiscoveryCategorySkeleton({required this.width, required this.tvMode});

  final double width;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Container(
    width: tvMode ? width * 1.18 : width,
    margin: EdgeInsets.symmetric(vertical: tvMode ? 4 : 3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
    ),
  );
}

class _DiscoveryCategoryChip extends StatefulWidget {
  const _DiscoveryCategoryChip({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
    required this.tvMode,
  });

  final DiscoveryCategory category;
  final bool selected;
  final VoidCallback onTap;
  final bool tvMode;

  @override
  State<_DiscoveryCategoryChip> createState() => _DiscoveryCategoryChipState();
}

class _DiscoveryCategoryChipState extends State<_DiscoveryCategoryChip> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = _focused || _hovered;
    final selected = widget.selected;
    final radius = BorderRadius.circular(999);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Danh mục ${widget.category.name}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected
              ? ZingColors.purpleBright
              : Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
          borderRadius: radius,
          border: Border.all(
            color: active
                ? ZingColors.lime
                : selected
                ? ZingColors.purpleBright
                : Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.42),
            width: active ? 3 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: ZingColors.purple.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: radius,
            mouseCursor: SystemMouseCursors.click,
            onHover: (value) => setState(() => _hovered = value),
            onFocusChange: (value) {
              setState(() => _focused = value);
              if (value) {
                Scrollable.ensureVisible(
                  context,
                  duration: const Duration(milliseconds: 200),
                  alignment: 0.18,
                );
              }
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.tvMode ? 24 : 18,
                vertical: widget.tvMode ? 12 : 10,
              ),
              child: Center(
                child: Text(
                  widget.category.name,
                  maxLines: 1,
                  style: TextStyle(
                    color: selected ? Colors.white : null,
                    fontSize: widget.tvMode ? 17 : 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DiscoveryVideoShelf extends StatelessWidget {
  const DiscoveryVideoShelf({
    super.key,
    required this.videos,
    required this.onVideoTap,
    this.tvMode = false,
  });

  final List<CatalogVideo> videos;
  final ValueChanged<CatalogVideo> onVideoTap;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('discovery-video-shelf'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'VIDEO CHÍNH THỨC',
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontSize: tvMode ? 13 : 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'MV Nổi Bật',
        style: TextStyle(
          fontSize: tvMode ? 30 : 22,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
      SizedBox(height: tvMode ? 10 : 7),
      Text(
        'Mở trang MV đã kiểm tra trên Zing MP3; TV hiển thị mã QR để tiếp tục trên điện thoại.',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: tvMode ? 15 : 12,
          height: 1.35,
        ),
      ),
      SizedBox(height: tvMode ? 20 : 15),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = tvMode
              ? 360.0
              : constraints.maxWidth >= 1200
              ? 300.0
              : constraints.maxWidth >= 720
              ? 272.0
              : (constraints.maxWidth * 0.82).clamp(240.0, 300.0);
          return SizedBox(
            height: width * 9 / 16 + (tvMode ? 98 : 82),
            child: ListView.separated(
              key: const ValueKey('discovery-video-list'),
              scrollDirection: Axis.horizontal,
              itemCount: videos.length,
              separatorBuilder: (_, __) => SizedBox(width: tvMode ? 22 : 15),
              itemBuilder: (context, index) {
                final video = videos[index];
                return SizedBox(
                  width: width,
                  child: _DiscoveryVideoCard(
                    key: ValueKey('discovery-video-card-${video.id}'),
                    video: video,
                    onTap: () => onVideoTap(video),
                    tvMode: tvMode,
                  ),
                );
              },
            ),
          );
        },
      ),
    ],
  );
}

class _DiscoveryVideoCard extends StatefulWidget {
  const _DiscoveryVideoCard({
    super.key,
    required this.video,
    required this.onTap,
    required this.tvMode,
  });

  final CatalogVideo video;
  final VoidCallback onTap;
  final bool tvMode;

  @override
  State<_DiscoveryVideoCard> createState() => _DiscoveryVideoCardState();
}

class _DiscoveryVideoCardState extends State<_DiscoveryVideoCard> {
  late final FocusNode _focusNode = FocusNode(
    debugLabel: 'discovery-video-focus-${widget.video.id}',
  );
  bool _focused = false;
  bool _hovered = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _focused || _hovered;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final animationDuration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final video = widget.video;
    return Semantics(
      button: true,
      label:
          'Mở MV ${video.title}${video.artist.isEmpty ? '' : ' của ${video.artist}'} trên Zing MP3',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('discovery-video-${video.id}'),
          onTap: widget.onTap,
          focusNode: _focusNode,
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(widget.tvMode ? 19 : 15),
          onHover: (value) => setState(() => _hovered = value),
          onFocusChange: (value) {
            setState(() => _focused = value);
            if (value) {
              Scrollable.ensureVisible(
                context,
                duration: reducedMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                alignment: 0.12,
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: AnimatedContainer(
                    duration: animationDuration,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        widget.tvMode ? 18 : 14,
                      ),
                      border: Border.all(
                        color: active ? ZingColors.lime : Colors.transparent,
                        width: active ? 3 : 0,
                      ),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: ZingColors.purple.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 9),
                              ),
                            ]
                          : null,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) => AlbumArt(
                            imageUrl: video.thumbnail,
                            semanticLabel: 'Ảnh MV ${video.title}',
                            size: constraints.maxWidth,
                            borderRadius: 0,
                          ),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xB8000000)],
                            ),
                          ),
                        ),
                        Center(
                          child: AnimatedOpacity(
                            duration: animationDuration,
                            opacity: active ? 1 : 0.82,
                            child: Container(
                              width: widget.tvMode ? 62 : 48,
                              height: widget.tvMode ? 62 : 48,
                              decoration: const BoxDecoration(
                                color: ZingColors.purpleBright,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.open_in_new_rounded,
                                color: Colors.white,
                                size: widget.tvMode ? 30 : 23,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: widget.tvMode ? 12 : 9,
                          bottom: widget.tvMode ? 11 : 8,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: widget.tvMode ? 9 : 7,
                              vertical: widget.tvMode ? 5 : 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _discoveryDurationLabel(video.duration),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: widget.tvMode ? 13 : 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: widget.tvMode ? 12 : 9),
                Text(
                  video.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: widget.tvMode ? 19 : 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  video.artist.isEmpty ? 'Zing MP3' : video.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: widget.tvMode ? 14 : 11,
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

String _discoveryDurationLabel(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class DiscoveryRecommendationShelf extends StatelessWidget {
  const DiscoveryRecommendationShelf({
    super.key,
    required this.songs,
    required this.official,
    this.catalogBySongId = const {},
    required this.canRefresh,
    required this.onSongTap,
    required this.onRefresh,
    this.likedSongIds = const {},
    this.onToggleLike,
    this.onAddToQueue,
    this.onOpenDetail,
    this.onStartRadio,
    this.onAddToPlaylist,
    this.onShare,
    this.onArtistTap,
    this.tvMode = false,
  });

  final List<Song> songs;
  final bool official;
  final Map<String, CatalogSong> catalogBySongId;
  final bool canRefresh;
  final ValueChanged<Song> onSongTap;
  final VoidCallback onRefresh;
  final Set<String> likedSongIds;
  final ValueChanged<Song>? onToggleLike;
  final ValueChanged<Song>? onAddToQueue;
  final ValueChanged<Song>? onOpenDetail;
  final ValueChanged<Song>? onStartRadio;
  final ValueChanged<Song>? onAddToPlaylist;
  final ValueChanged<Song>? onShare;
  final ValueChanged<CatalogArtist>? onArtistTap;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('discovery-recommendations'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  official ? 'TỪ ZING MP3' : 'CHỌN TRÊN THIẾT BỊ',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: tvMode ? 13 : 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gợi Ý Bài Hát',
                  style: TextStyle(
                    fontSize: tvMode ? 30 : 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            key: const ValueKey('refresh-discovery-recommendations'),
            onPressed: canRefresh ? onRefresh : null,
            icon: Icon(Icons.refresh_rounded, size: tvMode ? 25 : 20),
            label: Text(
              'LÀM MỚI',
              style: TextStyle(
                fontSize: tvMode ? 15 : 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: tvMode ? 18 : 13),
      Text(
        official
            ? 'Danh sách phát được lấy từ cụm Gợi Ý Bài Hát chính thức; lịch sử nghe và dữ liệu cá nhân vẫn chỉ lưu trên thiết bị.'
            : 'Luân phiên từ bảng xếp hạng hiện tại trên thiết bị. Favorites và lịch sử nghe không được dùng hoặc gửi lên proxy.',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: tvMode ? 15 : 12,
          height: 1.35,
        ),
      ),
      SizedBox(height: tvMode ? 20 : 15),
      LayoutBuilder(
        builder: (context, constraints) {
          if (!tvMode && constraints.maxWidth < 620) {
            final cardWidth = (constraints.maxWidth * 0.86).clamp(250.0, 340.0);
            return SizedBox(
              height: 94,
              child: ListView.separated(
                key: const ValueKey('discovery-recommendations-mobile-rail'),
                scrollDirection: Axis.horizontal,
                itemCount: songs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => SizedBox(
                  width: cardWidth,
                  child: _RecommendationSongCard(
                    song: songs[index],
                    catalogSong: catalogBySongId[songs[index].id],
                    onTap: () => onSongTap(songs[index]),
                    isLiked: likedSongIds.contains(songs[index].id),
                    onToggleLike: onToggleLike == null
                        ? null
                        : () => onToggleLike!(songs[index]),
                    onAddToQueue: onAddToQueue == null
                        ? null
                        : () => onAddToQueue!(songs[index]),
                    onOpenDetail: onOpenDetail == null
                        ? null
                        : () => onOpenDetail!(songs[index]),
                    onStartRadio: onStartRadio == null
                        ? null
                        : () => onStartRadio!(songs[index]),
                    onAddToPlaylist: onAddToPlaylist == null
                        ? null
                        : () => onAddToPlaylist!(songs[index]),
                    onShare: onShare == null
                        ? null
                        : () => onShare!(songs[index]),
                    onArtistTap: onArtistTap,
                    alwaysShowMenu: true,
                    tvMode: false,
                  ),
                ),
              ),
            );
          }

          final columns = tvMode
              ? (constraints.maxWidth >= 1500 ? 3 : 2)
              : constraints.maxWidth >= 1040
              ? 3
              : 2;
          final gap = tvMode ? 16.0 : 12.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            key: const ValueKey('discovery-recommendations-grid'),
            spacing: gap,
            runSpacing: gap,
            children: songs
                .map(
                  (song) => SizedBox(
                    width: width,
                    height: tvMode ? 112 : 82,
                    child: _RecommendationSongCard(
                      song: song,
                      catalogSong: catalogBySongId[song.id],
                      onTap: () => onSongTap(song),
                      isLiked: likedSongIds.contains(song.id),
                      onToggleLike: onToggleLike == null
                          ? null
                          : () => onToggleLike!(song),
                      onAddToQueue: onAddToQueue == null
                          ? null
                          : () => onAddToQueue!(song),
                      onOpenDetail: onOpenDetail == null
                          ? null
                          : () => onOpenDetail!(song),
                      onStartRadio: onStartRadio == null
                          ? null
                          : () => onStartRadio!(song),
                      onAddToPlaylist: onAddToPlaylist == null
                          ? null
                          : () => onAddToPlaylist!(song),
                      onShare: onShare == null ? null : () => onShare!(song),
                      onArtistTap: onArtistTap,
                      alwaysShowMenu: false,
                      tvMode: tvMode,
                    ),
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
    ],
  );
}

class _RecommendationSongCard extends StatefulWidget {
  const _RecommendationSongCard({
    required this.song,
    this.catalogSong,
    required this.onTap,
    required this.isLiked,
    this.onToggleLike,
    this.onAddToQueue,
    this.onOpenDetail,
    this.onStartRadio,
    this.onAddToPlaylist,
    this.onShare,
    this.onArtistTap,
    required this.alwaysShowMenu,
    required this.tvMode,
  });

  final Song song;
  final CatalogSong? catalogSong;
  final VoidCallback onTap;
  final bool isLiked;
  final VoidCallback? onToggleLike;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onOpenDetail;
  final VoidCallback? onStartRadio;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onShare;
  final ValueChanged<CatalogArtist>? onArtistTap;
  final bool alwaysShowMenu;
  final bool tvMode;

  @override
  State<_RecommendationSongCard> createState() =>
      _RecommendationSongCardState();
}

class _RecommendationSongCardState extends State<_RecommendationSongCard> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = _focused || _hovered;
    final song = widget.song;
    final menuVisible = active || widget.alwaysShowMenu;
    return Focus(
      canRequestFocus: false,
      onFocusChange: (value) => setState(() => _focused = value),
      child: Semantics(
        container: true,
        button: true,
        label: 'Phát gợi ý ${song.displayTitle} của ${song.artistsNames}',
        child: AnimatedContainer(
          key: ValueKey('discovery-recommendation-${song.id}'),
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: active ? 0.82 : 0.34),
            borderRadius: BorderRadius.circular(widget.tvMode ? 18 : 15),
            border: Border.all(
              color: active ? ZingColors.lime : Colors.transparent,
              width: active ? 3 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: ZingColors.purple.withValues(alpha: 0.24),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(widget.tvMode ? 17 : 14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onSecondaryTapDown: (details) => showSongActionContextMenu(
                context: context,
                globalPosition: details.globalPosition,
                keyPrefix: 'discovery-recommendation',
                song: widget.song,
                handlers: _actionHandlers,
                isLiked: widget.isLiked,
              ),
              onHover: (value) => setState(() => _hovered = value),
              child: Padding(
                padding: EdgeInsets.all(widget.tvMode ? 11 : 9),
                child: Row(
                  children: [
                    AlbumArt(
                      imageUrl: song.thumbnail,
                      semanticLabel: 'Ảnh bìa ${song.displayTitle}',
                      size: widget.tvMode ? 86 : 64,
                      borderRadius: widget.tvMode ? 13 : 11,
                    ),
                    SizedBox(width: widget.tvMode ? 15 : 11),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: widget.tvMode ? 18 : 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (widget.catalogSong?.artists.isNotEmpty == true &&
                              widget.onArtistTap != null)
                            CatalogArtistLinks(
                              artists: widget.catalogSong!.artists,
                              onArtistTap: widget.onArtistTap!,
                              keyPrefix: 'discovery-recommendation-artist',
                              tvMode: widget.tvMode,
                              touchLayout: widget.alwaysShowMenu,
                            )
                          else
                            Text(
                              song.artistsNames,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: widget.tvMode ? 14 : 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(width: widget.tvMode ? 8 : 4),
                    _buildActionDeck(context, active, menuVisible),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionDeck(BuildContext context, bool active, bool menuVisible) {
    final iconSize = widget.tvMode ? 30.0 : 23.0;
    final buttonSize = widget.tvMode ? 44.0 : 34.0;
    final hasMenu = _actionHandlers.hasAny;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: const Duration(milliseconds: 140),
          child: Icon(
            Icons.play_circle_fill_rounded,
            color: ZingColors.lime,
            size: widget.tvMode ? 36 : 29,
          ),
        ),
        if (widget.onToggleLike != null)
          AnimatedOpacity(
            opacity: active || widget.isLiked ? 1 : 0,
            duration: const Duration(milliseconds: 140),
            child: IgnorePointer(
              ignoring: !active,
              child: SizedBox.square(
                dimension: buttonSize,
                child: IconButton(
                  key: ValueKey(
                    'discovery-recommendation-like-${widget.song.id}',
                  ),
                  padding: EdgeInsets.zero,
                  tooltip: widget.isLiked ? 'Bỏ yêu thích' : 'Yêu thích',
                  onPressed: widget.onToggleLike,
                  iconSize: iconSize,
                  icon: Icon(
                    widget.isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: widget.isLiked
                        ? ZingColors.coral
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        if (hasMenu)
          AnimatedOpacity(
            opacity: menuVisible ? 1 : 0,
            duration: const Duration(milliseconds: 140),
            child: IgnorePointer(
              ignoring: !menuVisible,
              child: SizedBox.square(
                dimension: buttonSize,
                child: SongActionOverflowButton(
                  keyPrefix: 'discovery-recommendation',
                  song: widget.song,
                  handlers: _actionHandlers,
                  isLiked: widget.isLiked,
                  iconSize: iconSize,
                ),
              ),
            ),
          ),
      ],
    );
  }

  SongActionHandlers get _actionHandlers => SongActionHandlers(
    onPlay: widget.onTap,
    onOpenDetail: widget.onOpenDetail,
    onAddToQueue: widget.onAddToQueue,
    onStartRadio: widget.onStartRadio,
    onAddToPlaylist: widget.onAddToPlaylist,
    onShare: widget.onShare,
    onToggleLike: widget.onToggleLike,
  );
}

class DiscoveryNewReleaseChartSpotlight extends StatelessWidget {
  const DiscoveryNewReleaseChartSpotlight({
    super.key,
    required this.entries,
    required this.loading,
    required this.errorMessage,
    this.onEntryTap,
    this.actionResolver,
    this.onOpenAll,
    this.onRetry,
    this.tvMode = false,
  });

  final List<NewReleaseEntry> entries;
  final bool loading;
  final String? errorMessage;
  final ValueChanged<NewReleaseEntry>? onEntryTap;
  final SongActionMenuConfiguration Function(NewReleaseEntry)? actionResolver;
  final VoidCallback? onOpenAll;
  final VoidCallback? onRetry;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final podium = entries.take(3).toList(growable: false);
    return Semantics(
      key: const ValueKey('discovery-new-release-chart'),
      container: true,
      label: 'Ba thứ hạng dẫn đầu Bảng Xếp Hạng Nhạc Mới',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: tvMode ? 48 : 38,
                height: tvMode ? 48 : 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [ZingColors.coral, ZingColors.purpleBright],
                  ),
                  borderRadius: BorderRadius.circular(tvMode ? 15 : 12),
                ),
                child: Icon(
                  Icons.trending_up_rounded,
                  color: Colors.white,
                  size: tvMode ? 29 : 23,
                ),
              ),
              SizedBox(width: tvMode ? 15 : 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BXH Nhạc Mới',
                      style: TextStyle(
                        fontSize: tvMode ? 30 : 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.35,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'TOP 3 · XẾP HẠNG MỚI NHẤT',
                      style: TextStyle(
                        color: ZingColors.lime,
                        fontSize: tvMode ? 13 : 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (onOpenAll != null)
                TextButton.icon(
                  key: const ValueKey('open-new-release-chart'),
                  onPressed: onOpenAll,
                  icon: Icon(
                    Icons.arrow_forward_rounded,
                    size: tvMode ? 24 : 18,
                  ),
                  iconAlignment: IconAlignment.end,
                  label: Text(
                    'TẤT CẢ',
                    style: TextStyle(
                      fontSize: tvMode ? 14 : 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.65,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: tvMode ? 20 : 14),
          if (podium.isEmpty)
            _NewReleaseChartEmptyState(
              loading: loading,
              errorMessage: errorMessage,
              onRetry: onRetry,
              tvMode: tvMode,
            )
          else ...[
            if (loading || errorMessage != null) ...[
              _NewReleaseChartStatus(
                loading: loading,
                onRetry: onRetry,
                tvMode: tvMode,
              ),
              SizedBox(height: tvMode ? 16 : 11),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final gap = tvMode ? 20.0 : 14.0;
                final visibleCount = constraints.maxWidth >= 920
                    ? 3
                    : constraints.maxWidth >= 560
                    ? 2
                    : 1;
                final cardWidth = visibleCount == 1
                    ? (constraints.maxWidth * 0.88).clamp(268.0, 420.0)
                    : (constraints.maxWidth - gap * (visibleCount - 1)) /
                          visibleCount;
                final cardHeight = tvMode ? 190.0 : 160.0;
                return SizedBox(
                  height: cardHeight,
                  child: ListView.separated(
                    key: const ValueKey('discovery-new-release-chart-list'),
                    clipBehavior: Clip.none,
                    scrollDirection: Axis.horizontal,
                    itemCount: podium.length,
                    separatorBuilder: (_, __) => SizedBox(width: gap),
                    itemBuilder: (context, index) {
                      final entry = podium[index];
                      return SizedBox(
                        width: cardWidth,
                        child: _NewReleaseChartCard(
                          key: ValueKey(
                            'discovery-new-release-chart-${entry.song.id}',
                          ),
                          entry: entry,
                          tvMode: tvMode,
                          actionConfiguration: actionResolver?.call(entry),
                          alwaysShowMenu: !tvMode && constraints.maxWidth < 620,
                          onTap: entry.playable && onEntryTap != null
                              ? () => onEntryTap!(entry)
                              : null,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _NewReleaseChartCard extends StatefulWidget {
  const _NewReleaseChartCard({
    super.key,
    required this.entry,
    required this.tvMode,
    required this.actionConfiguration,
    required this.alwaysShowMenu,
    this.onTap,
  });

  final NewReleaseEntry entry;
  final bool tvMode;
  final SongActionMenuConfiguration? actionConfiguration;
  final bool alwaysShowMenu;
  final VoidCallback? onTap;

  @override
  State<_NewReleaseChartCard> createState() => _NewReleaseChartCardState();
}

class _NewReleaseChartCardState extends State<_NewReleaseChartCard> {
  late final FocusNode _focusNode;
  bool _focused = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      debugLabel: 'discovery-new-release-chart-focus-${widget.entry.song.id}',
      canRequestFocus: widget.onTap != null,
      skipTraversal: widget.onTap == null,
    );
  }

  @override
  void didUpdateWidget(covariant _NewReleaseChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _focusNode
      ..canRequestFocus = widget.onTap != null
      ..skipTraversal = widget.onTap == null;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final song = entry.song;
    final active =
        (widget.onTap != null || _handlers?.hasAny == true) &&
        (_focused || _hovered);
    final menuVisible =
        widget.tvMode ||
        widget.alwaysShowMenu ||
        active ||
        widget.onTap == null;
    final radius = BorderRadius.circular(widget.tvMode ? 20 : 16);
    final artSize = widget.tvMode ? 166.0 : 136.0;
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: entry.playable
          ? 'Hạng ${entry.rank}, ${song.displayTitle}, ${song.artistsNames}'
          : 'Hạng ${entry.rank}, ${song.displayTitle}, chưa phát được',
      onTap: widget.onTap,
      child: ExcludeSemantics(
        excluding: _handlers?.hasAny != true,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 170),
          scale: active ? 1.015 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.88),
              borderRadius: radius,
              border: Border.all(
                color: active
                    ? ZingColors.lime
                    : Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.28),
                width: active ? 3 : 1,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: ZingColors.coral.withValues(alpha: 0.22),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                focusNode: _focusNode,
                onTap: widget.onTap,
                onSecondaryTapDown: _handlers?.hasAny == true
                    ? (details) => showSongActionContextMenu(
                        context: context,
                        globalPosition: details.globalPosition,
                        keyPrefix: 'discovery-new-release-chart',
                        song: song,
                        handlers: _handlers!,
                        isLiked: widget.actionConfiguration!.isLiked,
                        moods: widget.actionConfiguration!.moods,
                      )
                    : null,
                onHover: (value) => setState(() => _hovered = value),
                onFocusChange: (value) {
                  setState(() => _focused = value);
                  if (value) {
                    Scrollable.ensureVisible(
                      context,
                      duration: const Duration(milliseconds: 220),
                      alignment: 0.12,
                    );
                  }
                },
                mouseCursor: widget.onTap == null
                    ? SystemMouseCursors.basic
                    : SystemMouseCursors.click,
                child: Opacity(
                  opacity: entry.playable ? 1 : 0.58,
                  child: Padding(
                    padding: EdgeInsets.all(widget.tvMode ? 11 : 10),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                widget.tvMode ? 14 : 12,
                              ),
                              child: song.thumbnail.isEmpty
                                  ? _DiscoverySongPlaceholder(
                                      song: song,
                                      size: artSize,
                                    )
                                  : AlbumArt(
                                      imageUrl: song.thumbnail,
                                      semanticLabel:
                                          'Ảnh bìa ${song.displayTitle}',
                                      size: artSize,
                                      borderRadius: 0,
                                    ),
                            ),
                            if (menuVisible && _handlers?.hasAny == true)
                              Positioned(
                                top: 7,
                                right: 7,
                                child: _SongArtworkMenu(
                                  keyPrefix: 'discovery-new-release-chart',
                                  song: song,
                                  configuration: widget.actionConfiguration!,
                                  tvMode: widget.tvMode,
                                ),
                              ),
                          ],
                        ),
                        SizedBox(width: widget.tvMode ? 17 : 13),
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned(
                                right: 0,
                                bottom: -8,
                                child: Text(
                                  '#${entry.rank}',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.12),
                                    fontSize: widget.tvMode ? 52 : 42,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '#${entry.rank}',
                                        style: TextStyle(
                                          color: entry.rank == 1
                                              ? ZingColors.coral
                                              : ZingColors.purpleBright,
                                          fontSize: widget.tvMode ? 15 : 12,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      _RankTrend(
                                        change: entry.rankChange,
                                        tvMode: widget.tvMode,
                                      ),
                                      if (!entry.playable) ...[
                                        const Spacer(),
                                        Icon(
                                          Icons.lock_rounded,
                                          size: widget.tvMode ? 21 : 17,
                                          color: ZingColors.coral,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    song.displayTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: widget.tvMode ? 20 : 16,
                                      height: 1.13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    song.artistsNames,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: widget.tvMode ? 15 : 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _newReleaseDateLabel(entry.releasedAt),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: 0.74),
                                      fontSize: widget.tvMode ? 13 : 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
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
          ),
        ),
      ),
    );
  }

  SongActionHandlers? get _handlers => widget.actionConfiguration?.handlers;
}

class _RankTrend extends StatelessWidget {
  const _RankTrend({required this.change, required this.tvMode});

  final int change;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final icon = change > 0
        ? Icons.arrow_upward_rounded
        : change < 0
        ? Icons.arrow_downward_rounded
        : Icons.remove_rounded;
    final color = change > 0
        ? ZingColors.lime
        : change < 0
        ? ZingColors.coral
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: tvMode ? 18 : 14, color: color),
        if (change != 0) ...[
          const SizedBox(width: 2),
          Text(
            change.abs().toString(),
            style: TextStyle(
              color: color,
              fontSize: tvMode ? 13 : 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ],
    );
  }
}

class _NewReleaseChartStatus extends StatelessWidget {
  const _NewReleaseChartStatus({
    required this.loading,
    required this.onRetry,
    required this.tvMode,
  });

  final bool loading;
  final VoidCallback? onRetry;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('discovery-new-release-chart-stale'),
    padding: EdgeInsets.symmetric(
      horizontal: tvMode ? 16 : 12,
      vertical: tvMode ? 11 : 8,
    ),
    decoration: BoxDecoration(
      color: (loading ? ZingColors.purpleBright : ZingColors.coral).withValues(
        alpha: 0.12,
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        if (loading)
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          const Icon(Icons.cloud_off_rounded, size: 17),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            loading
                ? 'Đang cập nhật thứ hạng mới…'
                : 'Đang hiển thị thứ hạng gần nhất.',
            style: TextStyle(
              fontSize: tvMode ? 15 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (!loading && onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    ),
  );
}

class _NewReleaseChartEmptyState extends StatelessWidget {
  const _NewReleaseChartEmptyState({
    required this.loading,
    required this.errorMessage,
    required this.onRetry,
    required this.tvMode,
  });

  final bool loading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey(
      loading
          ? 'discovery-new-release-chart-loading'
          : 'discovery-new-release-chart-error',
    ),
    height: tvMode ? 168 : 132,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(tvMode ? 20 : 16),
      border: Border.all(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.28),
      ),
    ),
    child: loading
        ? const CircularProgressIndicator()
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.trending_down_rounded, color: ZingColors.coral),
              const SizedBox(height: 8),
              Text(
                errorMessage == null
                    ? 'Chưa có dữ liệu BXH Nhạc Mới.'
                    : 'Chưa tải được BXH Nhạc Mới.',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (onRetry != null)
                TextButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ),
  );
}

String _newReleaseDateLabel(DateTime? releasedAt) {
  if (releasedAt == null) return 'CẬP NHẬT MỚI';
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(releasedAt.day)}.${two(releasedAt.month)}.${releasedAt.year}';
}

class DiscoveryNewReleaseShelf extends StatelessWidget {
  const DiscoveryNewReleaseShelf({
    super.key,
    required this.songs,
    required this.loading,
    required this.errorMessage,
    required this.region,
    required this.onRegionChanged,
    required this.onSongTap,
    this.likedSongIds = const {},
    this.onToggleLike,
    this.onAddToQueue,
    this.onOpenDetail,
    this.onStartRadio,
    this.onAddToPlaylist,
    this.onShare,
    required this.onOpenAll,
    required this.onRetry,
    this.tvMode = false,
  });

  final List<ReleaseSong> songs;
  final bool loading;
  final String? errorMessage;
  final DiscoveryReleaseRegion region;
  final ValueChanged<DiscoveryReleaseRegion> onRegionChanged;
  final ValueChanged<ReleaseSong> onSongTap;
  final Set<String> likedSongIds;
  final ValueChanged<ReleaseSong>? onToggleLike;
  final ValueChanged<ReleaseSong>? onAddToQueue;
  final ValueChanged<ReleaseSong>? onOpenDetail;
  final ValueChanged<ReleaseSong>? onStartRadio;
  final ValueChanged<ReleaseSong>? onAddToPlaylist;
  final ValueChanged<ReleaseSong>? onShare;
  final VoidCallback onOpenAll;
  final VoidCallback onRetry;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('discovery-new-releases'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Mới Phát Hành',
              style: TextStyle(
                fontSize: tvMode ? 30 : 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.55,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('open-all-discovery-releases'),
            onPressed: onOpenAll,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'XEM TẤT CẢ',
                  style: TextStyle(
                    fontSize: tvMode ? 15 : 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: tvMode ? 28 : 21),
              ],
            ),
          ),
        ],
      ),
      SizedBox(height: tvMode ? 15 : 10),
      Wrap(
        key: const ValueKey('discovery-release-region-filters'),
        spacing: tvMode ? 13 : 9,
        runSpacing: 8,
        children: DiscoveryReleaseRegion.values
            .map(
              (item) => ChoiceChip(
                key: ValueKey('discovery-release-region-${item.name}'),
                selected: item == region,
                onSelected: (_) => onRegionChanged(item),
                label: Text(item.label),
                labelStyle: TextStyle(
                  fontSize: tvMode ? 15 : 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.45,
                ),
                side: BorderSide(
                  color: item == region
                      ? ZingColors.purpleBright
                      : Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.48),
                ),
              ),
            )
            .toList(growable: false),
      ),
      if (loading && songs.isNotEmpty) ...[
        SizedBox(height: tvMode ? 15 : 10),
        const LinearProgressIndicator(
          key: ValueKey('discovery-new-releases-refreshing'),
          minHeight: 3,
        ),
      ] else if (errorMessage != null && songs.isNotEmpty) ...[
        SizedBox(height: tvMode ? 15 : 10),
        _DiscoveryReleaseNotice(onRetry: onRetry, tvMode: tvMode),
      ],
      SizedBox(height: tvMode ? 20 : 15),
      if (loading && songs.isEmpty)
        _DiscoveryReleaseLoading(tvMode: tvMode)
      else if (errorMessage != null && songs.isEmpty)
        _DiscoveryReleaseError(onRetry: onRetry, tvMode: tvMode)
      else if (songs.isEmpty)
        _DiscoveryReleaseEmpty(tvMode: tvMode)
      else
        LayoutBuilder(
          builder: (context, constraints) {
            if (!tvMode && constraints.maxWidth < 620) {
              final cardWidth = (constraints.maxWidth * 0.86).clamp(
                268.0,
                338.0,
              );
              return SizedBox(
                height: 88,
                child: ListView.separated(
                  key: const ValueKey('discovery-new-releases-mobile-rail'),
                  scrollDirection: Axis.horizontal,
                  itemCount: songs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) => SizedBox(
                    width: cardWidth,
                    child: _DiscoveryReleaseSongCard(
                      release: songs[index],
                      onTap: songs[index].playable
                          ? () => onSongTap(songs[index])
                          : null,
                      isLiked: likedSongIds.contains(songs[index].song.id),
                      onToggleLike: onToggleLike == null
                          ? null
                          : () => onToggleLike!(songs[index]),
                      onAddToQueue:
                          onAddToQueue == null || !songs[index].playable
                          ? null
                          : () => onAddToQueue!(songs[index]),
                      onOpenDetail: onOpenDetail == null
                          ? null
                          : () => onOpenDetail!(songs[index]),
                      onStartRadio:
                          onStartRadio == null || !songs[index].playable
                          ? null
                          : () => onStartRadio!(songs[index]),
                      onAddToPlaylist: onAddToPlaylist == null
                          ? null
                          : () => onAddToPlaylist!(songs[index]),
                      onShare: onShare == null
                          ? null
                          : () => onShare!(songs[index]),
                      alwaysShowMenu: true,
                      tvMode: false,
                    ),
                  ),
                ),
              );
            }

            final columns = tvMode
                ? (constraints.maxWidth >= 1500 ? 3 : 2)
                : constraints.maxWidth >= 1040
                ? 3
                : 2;
            final gap = tvMode ? 16.0 : 12.0;
            final itemWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              key: const ValueKey('discovery-new-releases-grid'),
              spacing: gap,
              runSpacing: gap,
              children: songs
                  .map(
                    (release) => SizedBox(
                      width: itemWidth,
                      height: tvMode ? 112 : 90,
                      child: _DiscoveryReleaseSongCard(
                        release: release,
                        onTap: release.playable
                            ? () => onSongTap(release)
                            : null,
                        isLiked: likedSongIds.contains(release.song.id),
                        onToggleLike: onToggleLike == null
                            ? null
                            : () => onToggleLike!(release),
                        onAddToQueue: onAddToQueue == null || !release.playable
                            ? null
                            : () => onAddToQueue!(release),
                        onOpenDetail: onOpenDetail == null
                            ? null
                            : () => onOpenDetail!(release),
                        onStartRadio: onStartRadio == null || !release.playable
                            ? null
                            : () => onStartRadio!(release),
                        onAddToPlaylist: onAddToPlaylist == null
                            ? null
                            : () => onAddToPlaylist!(release),
                        onShare: onShare == null
                            ? null
                            : () => onShare!(release),
                        alwaysShowMenu: false,
                        tvMode: tvMode,
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
    ],
  );
}

class _DiscoveryReleaseSongCard extends StatefulWidget {
  const _DiscoveryReleaseSongCard({
    required this.release,
    required this.onTap,
    required this.isLiked,
    this.onToggleLike,
    this.onAddToQueue,
    this.onOpenDetail,
    this.onStartRadio,
    this.onAddToPlaylist,
    this.onShare,
    required this.alwaysShowMenu,
    required this.tvMode,
  });

  final ReleaseSong release;
  final VoidCallback? onTap;
  final bool isLiked;
  final VoidCallback? onToggleLike;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onOpenDetail;
  final VoidCallback? onStartRadio;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onShare;
  final bool alwaysShowMenu;
  final bool tvMode;

  @override
  State<_DiscoveryReleaseSongCard> createState() =>
      _DiscoveryReleaseSongCardState();
}

class _DiscoveryReleaseSongCardState extends State<_DiscoveryReleaseSongCard> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final interactive = enabled || _actionHandlers.hasAny;
    final active = interactive && (_focused || _hovered);
    final menuVisible = widget.alwaysShowMenu || active || !enabled;
    final song = widget.release.song;
    final radius = BorderRadius.circular(widget.tvMode ? 18 : 14);
    return Semantics(
      button: true,
      enabled: interactive,
      label: enabled
          ? 'Phát bài mới ${song.displayTitle} của ${song.artistsNames}'
          : '${song.displayTitle} hiện chưa thể phát, có tùy chọn bài hát',
      child: AnimatedContainer(
        key: ValueKey('discovery-release-${song.id}'),
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
          borderRadius: radius,
          border: Border.all(
            color: active
                ? ZingColors.lime
                : Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: active ? 3 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: ZingColors.purpleBright.withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            canRequestFocus: interactive,
            onSecondaryTapDown: _actionHandlers.hasAny
                ? (details) => showSongActionContextMenu(
                    context: context,
                    globalPosition: details.globalPosition,
                    keyPrefix: 'discovery-release',
                    song: song,
                    handlers: _actionHandlers,
                    isLiked: widget.isLiked,
                  )
                : null,
            mouseCursor: enabled
                ? SystemMouseCursors.click
                : interactive
                ? SystemMouseCursors.basic
                : SystemMouseCursors.forbidden,
            onHover: interactive
                ? (value) => setState(() => _hovered = value)
                : null,
            onFocusChange: interactive
                ? (value) {
                    setState(() => _focused = value);
                    if (value) {
                      Scrollable.ensureVisible(
                        context,
                        duration: const Duration(milliseconds: 200),
                        alignment: 0.3,
                      );
                    }
                  }
                : null,
            child: Padding(
              padding: EdgeInsets.all(widget.tvMode ? 11 : 9),
              child: Row(
                children: [
                  AlbumArt(
                    imageUrl: song.thumbnail,
                    semanticLabel: 'Ảnh bìa ${song.displayTitle}',
                    size: widget.tvMode ? 86 : 70,
                    borderRadius: widget.tvMode ? 13 : 10,
                  ),
                  SizedBox(width: widget.tvMode ? 15 : 11),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                song.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: widget.tvMode ? 18 : 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (!enabled) ...[
                              const SizedBox(width: 5),
                              Icon(
                                Icons.lock_rounded,
                                color: ZingColors.coral,
                                size: widget.tvMode ? 21 : 16,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song.artistsNames,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: widget.tvMode ? 14 : 11,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          releaseAgeLabel(widget.release.releasedAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: enabled
                                ? ZingColors.coral
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            fontSize: widget.tvMode ? 12 : 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (active && enabled) ...[
                    SizedBox(width: widget.tvMode ? 9 : 6),
                    Icon(
                      Icons.play_circle_fill_rounded,
                      color: ZingColors.lime,
                      size: widget.tvMode ? 34 : 27,
                    ),
                  ],
                  if (menuVisible && _actionHandlers.hasAny) ...[
                    SizedBox(width: widget.tvMode ? 7 : 3),
                    SizedBox.square(
                      dimension: widget.tvMode ? 46 : 44,
                      child: SongActionOverflowButton(
                        keyPrefix: 'discovery-release',
                        song: song,
                        handlers: _actionHandlers,
                        isLiked: widget.isLiked,
                        iconSize: widget.tvMode ? 28 : 23,
                        iconColor: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant,
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

  SongActionHandlers get _actionHandlers => SongActionHandlers(
    onPlay: widget.onTap,
    onOpenDetail: widget.onOpenDetail,
    onAddToQueue: widget.onAddToQueue,
    onStartRadio: widget.onStartRadio,
    onAddToPlaylist: widget.onAddToPlaylist,
    onShare: widget.onShare,
    onToggleLike: widget.onToggleLike,
  );
}

class _DiscoveryReleaseLoading extends StatelessWidget {
  const _DiscoveryReleaseLoading({required this.tvMode});

  final bool tvMode;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('discovery-new-releases-loading'),
    height: tvMode ? 112 : 90,
    child: Row(
      children: List.generate(
        3,
        (index) => Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == 2 ? 0 : 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(tvMode ? 18 : 14),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DiscoveryReleaseError extends StatelessWidget {
  const _DiscoveryReleaseError({required this.onRetry, required this.tvMode});

  final VoidCallback onRetry;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('discovery-new-releases-error'),
    width: double.infinity,
    padding: EdgeInsets.all(tvMode ? 20 : 15),
    decoration: BoxDecoration(
      color: ZingColors.coral.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(tvMode ? 18 : 14),
      border: Border.all(color: ZingColors.coral.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: [
        Icon(
          Icons.cloud_off_rounded,
          color: ZingColors.coral,
          size: tvMode ? 30 : 23,
        ),
        SizedBox(width: tvMode ? 14 : 10),
        const Expanded(child: Text('Chưa tải được danh sách mới phát hành.')),
        TextButton(onPressed: onRetry, child: const Text('THỬ LẠI')),
      ],
    ),
  );
}

class _DiscoveryReleaseNotice extends StatelessWidget {
  const _DiscoveryReleaseNotice({required this.onRetry, required this.tvMode});

  final VoidCallback onRetry;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('discovery-new-releases-stale'),
    children: [
      Icon(
        Icons.cloud_off_rounded,
        color: ZingColors.coral,
        size: tvMode ? 24 : 19,
      ),
      SizedBox(width: tvMode ? 10 : 7),
      const Expanded(child: Text('Đang hiển thị dữ liệu gần nhất.')),
      TextButton(onPressed: onRetry, child: const Text('THỬ LẠI')),
    ],
  );
}

class _DiscoveryReleaseEmpty extends StatelessWidget {
  const _DiscoveryReleaseEmpty({required this.tvMode});

  final bool tvMode;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('discovery-new-releases-empty'),
    width: double.infinity,
    padding: EdgeInsets.symmetric(vertical: tvMode ? 28 : 20, horizontal: 16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(tvMode ? 18 : 14),
    ),
    child: const Text(
      'Chưa có bài hát mới trong khu vực này.',
      textAlign: TextAlign.center,
    ),
  );
}

class DiscoveryRecentlyPlayedShelf extends StatelessWidget {
  const DiscoveryRecentlyPlayedShelf({
    super.key,
    required this.songs,
    required this.onSongTap,
    this.actionResolver,
    this.onOpenLibrary,
    this.tvMode = false,
  });

  final List<Song> songs;
  final ValueChanged<Song> onSongTap;
  final SongActionMenuConfiguration Function(Song)? actionResolver;
  final VoidCallback? onOpenLibrary;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final visibleSongs = songs.take(10).toList(growable: false);
    if (visibleSongs.isEmpty) return const SizedBox.shrink();
    return Semantics(
      key: const ValueKey('discovery-recently-played'),
      container: true,
      label: 'Nghe Gần Đây, lịch sử riêng tư trên thiết bị',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LỊCH SỬ TRÊN THIẾT BỊ',
                      style: TextStyle(
                        color: ZingColors.lime,
                        fontSize: tvMode ? 14 : 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.45,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Nghe Gần Đây',
                      style: TextStyle(
                        fontSize: tvMode ? 30 : 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.45,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Danh sách này chỉ lưu trên thiết bị và không gửi lên proxy.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: tvMode ? 15 : 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (onOpenLibrary != null) ...[
                SizedBox(width: tvMode ? 18 : 10),
                TextButton.icon(
                  key: const ValueKey('open-recent-library'),
                  onPressed: onOpenLibrary,
                  icon: Icon(
                    Icons.arrow_forward_rounded,
                    size: tvMode ? 24 : 18,
                  ),
                  iconAlignment: IconAlignment.end,
                  label: Text(
                    'MỞ LỊCH SỬ',
                    style: TextStyle(
                      fontSize: tvMode ? 14 : 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.65,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: tvMode ? 20 : 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = tvMode
                  ? 190.0
                  : constraints.maxWidth >= 1100
                  ? 154.0
                  : constraints.maxWidth >= 620
                  ? 144.0
                  : 132.0;
              final artSize = cardWidth;
              return SizedBox(
                height: artSize + (tvMode ? 78 : 64),
                child: ListView.separated(
                  key: const ValueKey('discovery-recent-list'),
                  clipBehavior: Clip.none,
                  scrollDirection: Axis.horizontal,
                  itemCount: visibleSongs.length,
                  separatorBuilder: (_, __) =>
                      SizedBox(width: tvMode ? 20 : 14),
                  itemBuilder: (context, index) {
                    final song = visibleSongs[index];
                    return SizedBox(
                      width: cardWidth,
                      child: _DiscoveryRecentSongCard(
                        key: ValueKey('discovery-recent-song-${song.id}'),
                        song: song,
                        artSize: artSize,
                        tvMode: tvMode,
                        onTap: () => onSongTap(song),
                        actionConfiguration: actionResolver?.call(song),
                        alwaysShowMenu: !tvMode && constraints.maxWidth < 620,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DiscoveryRecentSongCard extends StatefulWidget {
  const _DiscoveryRecentSongCard({
    super.key,
    required this.song,
    required this.artSize,
    required this.tvMode,
    required this.onTap,
    required this.actionConfiguration,
    required this.alwaysShowMenu,
  });

  final Song song;
  final double artSize;
  final bool tvMode;
  final VoidCallback onTap;
  final SongActionMenuConfiguration? actionConfiguration;
  final bool alwaysShowMenu;

  @override
  State<_DiscoveryRecentSongCard> createState() =>
      _DiscoveryRecentSongCardState();
}

class _DiscoveryRecentSongCardState extends State<_DiscoveryRecentSongCard> {
  late final FocusNode _focusNode;
  bool _focused = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      debugLabel: 'discovery-recent-focus-${widget.song.id}',
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _focused || _hovered;
    final menuVisible = widget.tvMode || widget.alwaysShowMenu || active;
    final radius = BorderRadius.circular(widget.tvMode ? 18 : 14);
    return Semantics(
      button: true,
      label:
          'Phát lại ${widget.song.displayTitle}, ${widget.song.artistsNames}',
      onTap: widget.onTap,
      child: ExcludeSemantics(
        excluding: _handlers?.hasAny != true,
        child: InkWell(
          focusNode: _focusNode,
          borderRadius: radius,
          mouseCursor: SystemMouseCursors.click,
          onTap: widget.onTap,
          onSecondaryTapDown: _handlers?.hasAny == true
              ? (details) => showSongActionContextMenu(
                  context: context,
                  globalPosition: details.globalPosition,
                  keyPrefix: 'discovery-recent',
                  song: widget.song,
                  handlers: _handlers!,
                  isLiked: widget.actionConfiguration!.isLiked,
                  moods: widget.actionConfiguration!.moods,
                )
              : null,
          onHover: (value) => setState(() => _hovered = value),
          onFocusChange: (value) {
            setState(() => _focused = value);
            if (value) {
              Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 220),
                alignment: 0.12,
              );
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 180),
                scale: active ? 1.025 : 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: active
                          ? ZingColors.lime
                          : Theme.of(context).colorScheme.outlineVariant
                                .withValues(alpha: 0.25),
                      width: active ? 3 : 1,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: ZingColors.coral.withValues(alpha: 0.25),
                              blurRadius: 22,
                              offset: const Offset(0, 9),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Stack(
                      children: [
                        if (widget.song.thumbnail.isEmpty)
                          _DiscoverySongPlaceholder(
                            song: widget.song,
                            size: widget.artSize,
                          )
                        else
                          AlbumArt(
                            imageUrl: widget.song.thumbnail,
                            semanticLabel:
                                'Ảnh bìa ${widget.song.displayTitle}',
                            size: widget.artSize,
                            borderRadius: 0,
                          ),
                        Positioned.fill(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 180),
                            opacity: active ? 1 : 0,
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.22),
                              child: Center(
                                child: Container(
                                  width: widget.tvMode ? 58 : 44,
                                  height: widget.tvMode ? 58 : 44,
                                  decoration: const BoxDecoration(
                                    color: ZingColors.coral,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: widget.tvMode ? 38 : 30,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (menuVisible && _handlers?.hasAny == true)
                          Positioned(
                            top: 7,
                            right: 7,
                            child: _SongArtworkMenu(
                              keyPrefix: 'discovery-recent',
                              song: widget.song,
                              configuration: widget.actionConfiguration!,
                              tvMode: widget.tvMode,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: widget.tvMode ? 12 : 9),
              Text(
                widget.song.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: widget.tvMode ? 18 : 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.song.artistsNames,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: widget.tvMode ? 15 : 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SongActionHandlers? get _handlers => widget.actionConfiguration?.handlers;
}

class _SongArtworkMenu extends StatelessWidget {
  const _SongArtworkMenu({
    required this.keyPrefix,
    required this.song,
    required this.configuration,
    required this.tvMode,
  });

  final String keyPrefix;
  final Song song;
  final SongActionMenuConfiguration configuration;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final size = tvMode ? 48.0 : 44.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.74),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 10)],
      ),
      child: SizedBox.square(
        dimension: size,
        child: SongActionOverflowButton(
          keyPrefix: keyPrefix,
          song: song,
          handlers: configuration.handlers,
          isLiked: configuration.isLiked,
          moods: configuration.moods,
          iconSize: tvMode ? 28 : 23,
          iconColor: Colors.white,
        ),
      ),
    );
  }
}

class _DiscoverySongPlaceholder extends StatelessWidget {
  const _DiscoverySongPlaceholder({required this.song, required this.size});

  static const _palettes = <List<Color>>[
    [Color(0xFF5C2B7A), Color(0xFFFF6B4A)],
    [Color(0xFF145B66), Color(0xFF9FE870)],
    [Color(0xFF233E8B), Color(0xFFA85CF9)],
    [Color(0xFF7A294B), Color(0xFFFFA552)],
    [Color(0xFF1F6B4F), Color(0xFF5DD6C0)],
    [Color(0xFF4B315F), Color(0xFFFF7D9C)],
  ];

  final Song song;
  final double size;

  @override
  Widget build(BuildContext context) {
    final paletteIndex =
        song.id.codeUnits.fold<int>(0, (a, b) => a + b) % _palettes.length;
    final palette = _palettes[paletteIndex];
    final firstRune = song.displayTitle.runes.firstOrNull;
    final initial = firstRune == null ? '#' : String.fromCharCode(firstRune);
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -size * 0.2,
              top: -size * 0.22,
              child: Container(
                width: size * 0.72,
                height: size * 0.72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Center(
              child: Text(
                initial.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
            Positioned(
              right: size * 0.1,
              bottom: size * 0.09,
              child: Icon(
                Icons.graphic_eq_rounded,
                color: Colors.white.withValues(alpha: 0.78),
                size: size * 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryQuickLinks extends StatelessWidget {
  const _DiscoveryQuickLinks({
    required this.onOpenHubHome,
    required this.onOpenTop100,
    required this.onOpenReleases,
    required this.onOpenWeeklyChart,
    required this.tvMode,
  });

  final VoidCallback onOpenHubHome;
  final VoidCallback onOpenTop100;
  final VoidCallback onOpenReleases;
  final VoidCallback onOpenWeeklyChart;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: tvMode ? 16 : 10,
    runSpacing: 10,
    children: [
      FilledButton.tonalIcon(
        key: const ValueKey('open-weekly-chart'),
        onPressed: onOpenWeeklyChart,
        icon: const Icon(Icons.leaderboard_rounded),
        label: Text('BXH Tuần', style: TextStyle(fontSize: tvMode ? 16 : 13)),
      ),
      FilledButton.tonalIcon(
        key: const ValueKey('open-hub-home'),
        onPressed: onOpenHubHome,
        icon: const Icon(Icons.grid_view_rounded),
        label: Text(
          'Chủ đề & Thể loại',
          style: TextStyle(fontSize: tvMode ? 16 : 13),
        ),
      ),
      FilledButton.tonalIcon(
        key: const ValueKey('open-top-100'),
        onPressed: onOpenTop100,
        icon: const Icon(Icons.star_rounded),
        label: Text('Top 100', style: TextStyle(fontSize: tvMode ? 16 : 13)),
      ),
      FilledButton.tonalIcon(
        key: const ValueKey('open-new-releases'),
        onPressed: onOpenReleases,
        icon: const Icon(Icons.fiber_new_rounded),
        label: Text(
          'Mới Phát Hành',
          style: TextStyle(fontSize: tvMode ? 16 : 13),
        ),
      ),
    ],
  );
}

class _DiscoveryQuickPlayRail extends StatefulWidget {
  const _DiscoveryQuickPlayRail({
    super.key,
    required this.entries,
    required this.tvMode,
    required this.onCollectionTap,
  });

  final List<DiscoveryCollection> entries;
  final bool tvMode;
  final ValueChanged<CatalogCollection> onCollectionTap;

  @override
  State<_DiscoveryQuickPlayRail> createState() =>
      _DiscoveryQuickPlayRailState();
}

class _DiscoveryQuickPlayRailState extends State<_DiscoveryQuickPlayRail> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _previousFocusNode = FocusNode(
    debugLabel: 'discovery-quick-play-previous-focus',
  );
  final FocusNode _nextFocusNode = FocusNode(
    debugLabel: 'discovery-quick-play-next-focus',
  );
  bool _canScrollBack = false;
  bool _canScrollForward = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateNavigationState);
    _scheduleNavigationUpdate();
  }

  @override
  void didUpdateWidget(covariant _DiscoveryQuickPlayRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final entriesChanged =
        oldWidget.entries.length != widget.entries.length ||
        List.generate(
          widget.entries.length,
          (index) =>
              oldWidget.entries[index].collection.id !=
              widget.entries[index].collection.id,
        ).any((changed) => changed);
    if (entriesChanged) {
      _canScrollBack = false;
      _canScrollForward = false;
      _scheduleNavigationUpdate(resetToStart: true);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updateNavigationState)
      ..dispose();
    _previousFocusNode.dispose();
    _nextFocusNode.dispose();
    super.dispose();
  }

  void _scheduleNavigationUpdate({bool resetToStart = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (resetToStart) {
        _scrollController.jumpTo(_scrollController.position.minScrollExtent);
      }
      _updateNavigationState();
    });
  }

  void _updateNavigationState() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final canScrollBack = position.pixels > position.minScrollExtent + 1;
    final canScrollForward = position.pixels < position.maxScrollExtent - 1;
    if (canScrollBack == _canScrollBack &&
        canScrollForward == _canScrollForward) {
      return;
    }
    final moveFocusBack = _nextFocusNode.hasFocus && !canScrollForward;
    final moveFocusForward = _previousFocusNode.hasFocus && !canScrollBack;
    setState(() {
      _canScrollBack = canScrollBack;
      _canScrollForward = canScrollForward;
    });
    if (moveFocusBack || moveFocusForward) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (moveFocusBack && _canScrollBack) {
          _previousFocusNode.requestFocus();
        } else if (moveFocusForward && _canScrollForward) {
          _nextFocusNode.requestFocus();
        }
      });
    }
  }

  Future<void> _scrollBy(double delta) async {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    await _scrollController.animateTo(
      (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final gap = widget.tvMode ? 18.0 : 14.0;
      final visibleCount = widget.tvMode && constraints.maxWidth >= 1200
          ? 3
          : constraints.maxWidth >= 520
          ? 2
          : 1;
      final cardWidth = visibleCount == 1
          ? (constraints.maxWidth * 0.9).clamp(272.0, 480.0)
          : (constraints.maxWidth - gap * (visibleCount - 1)) / visibleCount;
      final denseDesktop = !widget.tvMode && constraints.maxWidth >= 720;
      final cardHeight = widget.tvMode
          ? 210.0
          : denseDesktop
          ? (cardWidth / 3.2).clamp(152.0, 168.0)
          : (cardWidth / 1.85).clamp(166.0, 190.0);
      final showNavigation = widget.entries.length > visibleCount;
      final scrollAmount = cardWidth + gap;
      return Semantics(
        container: true,
        label: 'Có thể bạn thích từ Zing MP3',
        child: Stack(
          key: const ValueKey('discovery-quick-play-rail'),
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: cardHeight,
              child: ListView.separated(
                key: const ValueKey('discovery-quick-play-list'),
                controller: _scrollController,
                clipBehavior: Clip.none,
                scrollDirection: Axis.horizontal,
                itemCount: widget.entries.length,
                separatorBuilder: (_, __) => SizedBox(width: gap),
                itemBuilder: (context, index) {
                  final entry = widget.entries[index];
                  return SizedBox(
                    width: cardWidth,
                    child: _DiscoveryQuickPlayCard(
                      key: ValueKey(
                        'discovery-quick-play-${entry.collection.id}',
                      ),
                      entry: entry,
                      paletteIndex: index,
                      tvMode: widget.tvMode,
                      onTap: () => widget.onCollectionTap(entry.collection),
                    ),
                  );
                },
              ),
            ),
            if (showNavigation && _canScrollBack)
              Positioned(
                left: widget.tvMode ? -14 : -10,
                top: (cardHeight - (widget.tvMode ? 56 : 44)) / 2,
                child: _BannerNavigationButton(
                  key: const ValueKey('discovery-quick-play-previous'),
                  icon: Icons.chevron_left_rounded,
                  label: 'Gợi ý trước',
                  tvMode: widget.tvMode,
                  focusNode: _previousFocusNode,
                  onPressed: () => _scrollBy(-scrollAmount),
                ),
              ),
            if (showNavigation && _canScrollForward)
              Positioned(
                right: widget.tvMode ? -14 : -10,
                top: (cardHeight - (widget.tvMode ? 56 : 44)) / 2,
                child: _BannerNavigationButton(
                  key: const ValueKey('discovery-quick-play-next'),
                  icon: Icons.chevron_right_rounded,
                  label: 'Gợi ý tiếp theo',
                  tvMode: widget.tvMode,
                  focusNode: _nextFocusNode,
                  onPressed: () => _scrollBy(scrollAmount),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _DiscoveryQuickPlayCard extends StatefulWidget {
  const _DiscoveryQuickPlayCard({
    super.key,
    required this.entry,
    required this.paletteIndex,
    required this.tvMode,
    required this.onTap,
  });

  final DiscoveryCollection entry;
  final int paletteIndex;
  final bool tvMode;
  final VoidCallback onTap;

  @override
  State<_DiscoveryQuickPlayCard> createState() =>
      _DiscoveryQuickPlayCardState();
}

class _DiscoveryQuickPlayCardState extends State<_DiscoveryQuickPlayCard> {
  late final FocusNode _focusNode;
  bool _focused = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      debugLabel: 'discovery-quick-play-focus-${widget.entry.collection.id}',
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _focused || _hovered;
    final collection = widget.entry.collection;
    final subtitle = collection.artist.isNotEmpty
        ? collection.artist
        : widget.entry.description;
    final radius = BorderRadius.circular(widget.tvMode ? 18 : 10);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    const palettes = [
      [Color(0xFF9A3F49), Color(0xFF5A263A), Color(0xFF241426)],
      [Color(0xFFA24B55), Color(0xFF633044), Color(0xFF28172B)],
      [Color(0xFF8C3B5D), Color(0xFF522747), Color(0xFF221528)],
    ];
    final palette = palettes[widget.paletteIndex % palettes.length];
    return Semantics(
      button: true,
      label: 'Có thể bạn thích, mở ${collection.title}',
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: active
                ? ZingColors.lime
                : Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.18),
            width: _focused
                ? 3
                : active
                ? 2
                : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: ZingColors.coral.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: palette,
              ),
            ),
            child: InkWell(
              focusNode: _focusNode,
              onTap: widget.onTap,
              mouseCursor: SystemMouseCursors.click,
              onHover: (value) => setState(() => _hovered = value),
              onFocusChange: (value) {
                setState(() => _focused = value);
                if (value) {
                  Scrollable.ensureVisible(
                    context,
                    duration: duration,
                    alignment: 0.12,
                  );
                }
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final padding = widget.tvMode ? 14.0 : 10.0;
                  final artworkSize = constraints.maxHeight - padding * 2;
                  return Padding(
                    padding: EdgeInsets.all(padding),
                    child: Row(
                      children: [
                        ClipRRect(
                          key: ValueKey(
                            'discovery-quick-play-artwork-${collection.id}',
                          ),
                          borderRadius: BorderRadius.circular(
                            widget.tvMode ? 12 : 7,
                          ),
                          child: SizedBox.square(
                            dimension: artworkSize,
                            child: _DiscoveryImage(
                              url: collection.thumbnail,
                              fallbackIcon: Icons.bolt_rounded,
                            ),
                          ),
                        ),
                        SizedBox(width: widget.tvMode ? 20 : 14),
                        Expanded(
                          key: ValueKey(
                            'discovery-quick-play-copy-${collection.id}',
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.11),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: widget.tvMode ? 10 : 8,
                                    vertical: widget.tvMode ? 5 : 4,
                                  ),
                                  child: Text(
                                    'CÓ THỂ BẠN THÍCH',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontSize: widget.tvMode ? 12 : 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.75,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: widget.tvMode ? 10 : 7),
                              Text(
                                collection.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: widget.tvMode ? 22 : 18,
                                  height: 1.08,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.25,
                                ),
                              ),
                              if (subtitle.isNotEmpty) ...[
                                SizedBox(height: widget.tvMode ? 7 : 5),
                                Text(
                                  subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: widget.tvMode ? 14 : 11,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerRail extends StatefulWidget {
  const _BannerRail({
    super.key,
    required this.banners,
    required this.tvMode,
    required this.onCollectionTap,
  });

  final List<DiscoveryBanner> banners;
  final bool tvMode;
  final ValueChanged<CatalogCollection> onCollectionTap;

  @override
  State<_BannerRail> createState() => _BannerRailState();
}

class _BannerRailState extends State<_BannerRail> {
  static const _autoAdvanceDelay = Duration(seconds: 6);

  final ScrollController _scrollController = ScrollController();
  final FocusNode _previousFocusNode = FocusNode(
    debugLabel: 'discovery-banner-previous-focus',
  );
  final FocusNode _nextFocusNode = FocusNode(
    debugLabel: 'discovery-banner-next-focus',
  );
  bool _canScrollBack = false;
  bool _canScrollForward = false;
  bool _autoAdvanceAllowed = false;
  bool _hovering = false;
  bool _focusWithin = false;
  bool _bannerCardFocused = false;
  bool _isAutoAnimating = false;
  bool _disposing = false;
  double _pageExtent = 0;
  int _autoAdvanceGeneration = 0;
  Timer? _autoAdvanceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateNavigationState);
    _previousFocusNode.addListener(_handleNavigationFocusChange);
    _nextFocusNode.addListener(_handleNavigationFocusChange);
    _scheduleNavigationUpdate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final allowed =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (allowed == _autoAdvanceAllowed) return;
    _autoAdvanceAllowed = allowed;
    if (allowed) {
      _scheduleAutoAdvance();
    } else {
      _cancelAutoAdvance();
    }
  }

  @override
  void didUpdateWidget(covariant _BannerRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bannerSetChanged =
        oldWidget.banners.length != widget.banners.length ||
        List.generate(
          widget.banners.length,
          (index) => oldWidget.banners[index].id != widget.banners[index].id,
        ).any((changed) => changed);
    if (bannerSetChanged) {
      _canScrollBack = false;
      _canScrollForward = false;
      _scheduleNavigationUpdate(resetToStart: true);
      _scheduleAutoAdvance();
    }
  }

  @override
  void dispose() {
    _disposing = true;
    _cancelAutoAdvance();
    _scrollController
      ..removeListener(_updateNavigationState)
      ..dispose();
    _previousFocusNode
      ..removeListener(_handleNavigationFocusChange)
      ..dispose();
    _nextFocusNode
      ..removeListener(_handleNavigationFocusChange)
      ..dispose();
    super.dispose();
  }

  bool get _shouldAutoAdvance =>
      _autoAdvanceAllowed &&
      !_disposing &&
      !_hovering &&
      !_focusWithin &&
      widget.banners.length > 1;

  void _cancelAutoAdvance() {
    _autoAdvanceGeneration++;
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
    if (_isAutoAnimating && _scrollController.hasClients) {
      final pixels = _scrollController.position.pixels;
      _isAutoAnimating = false;
      _scrollController.jumpTo(pixels);
    }
  }

  void _scheduleAutoAdvance() {
    _cancelAutoAdvance();
    if (!_shouldAutoAdvance) return;
    _autoAdvanceTimer = Timer(_autoAdvanceDelay, _autoAdvance);
  }

  void _autoAdvance() {
    if (!mounted || !_shouldAutoAdvance) return;
    if (!_scrollController.hasClients || _isAutoAnimating || _pageExtent <= 0) {
      _scheduleAutoAdvance();
      return;
    }
    final position = _scrollController.position;
    if (position.maxScrollExtent <= position.minScrollExtent + 1) return;
    final target = position.pixels < position.maxScrollExtent - 1
        ? math.min(position.pixels + _pageExtent, position.maxScrollExtent)
        : position.minScrollExtent;
    final generation = _autoAdvanceGeneration;
    _isAutoAnimating = true;
    _scrollController
        .animateTo(
          target,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOutCubic,
        )
        .whenComplete(() {
          if (!mounted || generation != _autoAdvanceGeneration) return;
          _isAutoAnimating = false;
          _scheduleAutoAdvance();
        });
  }

  void _setHovering(bool value) {
    if (_hovering == value) return;
    _hovering = value;
    if (value) {
      _cancelAutoAdvance();
    } else {
      _scheduleAutoAdvance();
    }
  }

  void _setFocusWithin(bool value) {
    if (_focusWithin == value) return;
    _focusWithin = value;
    if (value) {
      _cancelAutoAdvance();
    } else {
      _scheduleAutoAdvance();
    }
  }

  void _handleNavigationFocusChange() {
    // Focus callbacks for the old and new descendants can arrive in either
    // order. Cancel synchronously, then reconcile after the focus tree has
    // committed so a card -> arrow transition never restarts the timer.
    _cancelAutoAdvance();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _setFocusWithin(
        _bannerCardFocused ||
            _previousFocusNode.hasFocus ||
            _nextFocusNode.hasFocus,
      );
    });
  }

  void _handleBannerFocusChange(bool value) {
    _bannerCardFocused = value;
    _handleNavigationFocusChange();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _cancelAutoAdvance();
    } else if (notification is ScrollEndNotification && !_isAutoAnimating) {
      _scheduleAutoAdvance();
    }
    return false;
  }

  void _scheduleNavigationUpdate({bool resetToStart = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (resetToStart) {
        _scrollController.jumpTo(_scrollController.position.minScrollExtent);
      }
      _updateNavigationState();
    });
  }

  void _updateNavigationState() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final canScrollBack = position.pixels > position.minScrollExtent + 1;
    final canScrollForward = position.pixels < position.maxScrollExtent - 1;
    if (canScrollBack == _canScrollBack &&
        canScrollForward == _canScrollForward) {
      return;
    }
    final moveFocusBack = _nextFocusNode.hasFocus && !canScrollForward;
    final moveFocusForward = _previousFocusNode.hasFocus && !canScrollBack;
    setState(() {
      _canScrollBack = canScrollBack;
      _canScrollForward = canScrollForward;
    });
    if (moveFocusBack || moveFocusForward) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (moveFocusBack && _canScrollBack) {
          _previousFocusNode.requestFocus();
        } else if (moveFocusForward && _canScrollForward) {
          _nextFocusNode.requestFocus();
        }
      });
    }
  }

  Future<void> _scrollBy(double delta) async {
    if (!_scrollController.hasClients) return;
    _cancelAutoAdvance();
    final position = _scrollController.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
    _scheduleAutoAdvance();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 520;
      final gap = widget.tvMode ? 18.0 : 14.0;
      final height = widget.tvMode
          ? (constraints.maxWidth / 7).clamp(160.0, 210.0)
          : wide
          ? (constraints.maxWidth / 10).clamp(92.0, 132.0)
          : ((constraints.maxWidth * 0.92) / 3.6).clamp(96.0, 132.0);
      final cardWidth = widget.banners.length == 1
          ? constraints.maxWidth
          : wide
          ? constraints.maxWidth
          : (constraints.maxWidth * 0.92).clamp(280.0, 560.0);
      final showNavigation = wide && widget.banners.length > 1;
      final scrollAmount = cardWidth + gap;
      _pageExtent = scrollAmount;
      return MouseRegion(
        onEnter: (_) => _setHovering(true),
        onExit: (_) => _setHovering(false),
        child: SizedBox(
          key: const ValueKey('discovery-banner-rail'),
          height: height,
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: ListView(
                  key: const ValueKey('discovery-banner-list'),
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (
                      var index = 0;
                      index < widget.banners.length;
                      index++
                    ) ...[
                      if (index > 0) SizedBox(width: gap),
                      Builder(
                        builder: (context) {
                          final banner = widget.banners[index];
                          return SizedBox(
                            width: cardWidth,
                            child: _DiscoveryBannerCard(
                              key: ValueKey('discovery-banner-${banner.id}'),
                              banner: banner,
                              tvMode: widget.tvMode,
                              onFocusChange: _handleBannerFocusChange,
                              onTap: banner.collection == null
                                  ? null
                                  : () => widget.onCollectionTap(
                                      banner.collection!,
                                    ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              if (showNavigation && _canScrollBack)
                Positioned(
                  left: widget.tvMode ? 12 : 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _BannerNavigationButton(
                      key: const ValueKey('discovery-banner-previous'),
                      icon: Icons.chevron_left_rounded,
                      label: 'Banner nổi bật trước',
                      tvMode: widget.tvMode,
                      focusNode: _previousFocusNode,
                      onPressed: () => _scrollBy(-scrollAmount),
                    ),
                  ),
                ),
              if (showNavigation && _canScrollForward)
                Positioned(
                  right: widget.tvMode ? 12 : 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _BannerNavigationButton(
                      key: const ValueKey('discovery-banner-next'),
                      icon: Icons.chevron_right_rounded,
                      label: 'Banner nổi bật tiếp theo',
                      tvMode: widget.tvMode,
                      focusNode: _nextFocusNode,
                      onPressed: () => _scrollBy(scrollAmount),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _BannerNavigationButton extends StatelessWidget {
  const _BannerNavigationButton({
    super.key,
    required this.icon,
    required this.label,
    required this.tvMode,
    required this.focusNode,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool tvMode;
  final FocusNode focusNode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: IconButton.filled(
      tooltip: label,
      focusNode: focusNode,
      onPressed: onPressed,
      icon: Icon(icon, size: tvMode ? 34 : 26),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xD9181022),
        foregroundColor: Colors.white,
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.52),
        ),
        minimumSize: Size.square(tvMode ? 58 : 46),
      ),
    ),
  );
}

class _DiscoveryBannerCard extends StatefulWidget {
  const _DiscoveryBannerCard({
    super.key,
    required this.banner,
    required this.tvMode,
    required this.onFocusChange,
    required this.onTap,
  });

  final DiscoveryBanner banner;
  final bool tvMode;
  final ValueChanged<bool> onFocusChange;
  final VoidCallback? onTap;

  @override
  State<_DiscoveryBannerCard> createState() => _DiscoveryBannerCardState();
}

class _DiscoveryBannerCardState extends State<_DiscoveryBannerCard> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = _focused || _hovered;
    final collection = widget.banner.collection;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final radius = BorderRadius.circular(widget.tvMode ? 10 : 6);
    return Semantics(
      button: widget.onTap != null,
      label: collection == null ? 'Nội dung nổi bật' : 'Mở ${collection.title}',
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: active
                ? ZingColors.lime
                : Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.22),
            width: _focused
                ? 3
                : active
                ? 2
                : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: ZingColors.coral.withValues(alpha: 0.2),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            mouseCursor: widget.onTap == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            onHover: (value) => setState(() => _hovered = value),
            onFocusChange: (value) {
              widget.onFocusChange(value);
              setState(() => _focused = value);
              if (value) {
                Scrollable.ensureVisible(
                  context,
                  duration: duration,
                  alignment: 0.14,
                );
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                _DiscoveryImage(
                  url: widget.banner.image,
                  fallbackIcon: Icons.auto_awesome_rounded,
                ),
                if (widget.banner.image.isEmpty && collection != null) ...[
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFF713449), Color(0xFF26172D)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: widget.tvMode ? 28 : 20,
                    right: widget.tvMode ? 28 : 20,
                    top: 0,
                    bottom: 0,
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: ZingColors.coral,
                          size: widget.tvMode ? 36 : 25,
                        ),
                        SizedBox(width: widget.tvMode ? 18 : 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NỔI BẬT HÔM NAY',
                                style: TextStyle(
                                  color: ZingColors.lime,
                                  fontSize: widget.tvMode ? 12 : 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              SizedBox(height: widget.tvMode ? 7 : 4),
                              Text(
                                collection.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: widget.tvMode ? 24 : 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CollectionSection extends StatefulWidget {
  const _CollectionSection({
    super.key,
    required this.section,
    required this.tvMode,
    this.onOpenAll,
    required this.onCollectionTap,
    required this.onCollectionPlay,
    required this.onCollectionToggleSaved,
    required this.onCollectionShare,
    required this.onCollectionArtistTap,
    required this.savedCollectionIds,
    required this.quickPlayingCollectionId,
  });

  final DiscoverySection section;
  final bool tvMode;
  final VoidCallback? onOpenAll;
  final ValueChanged<CatalogCollection> onCollectionTap;
  final ValueChanged<CatalogCollection>? onCollectionPlay;
  final ValueChanged<CatalogCollection>? onCollectionToggleSaved;
  final ValueChanged<CatalogCollection>? onCollectionShare;
  final ValueChanged<CatalogArtist>? onCollectionArtistTap;
  final Set<String> savedCollectionIds;
  final String? quickPlayingCollectionId;

  @override
  State<_CollectionSection> createState() => _CollectionSectionState();
}

class _CollectionSectionState extends State<_CollectionSection> {
  final ScrollController _scrollController = ScrollController();
  late final FocusNode _previousFocusNode = FocusNode(
    debugLabel: 'discovery-section-previous-${widget.section.id}',
  );
  late final FocusNode _nextFocusNode = FocusNode(
    debugLabel: 'discovery-section-next-${widget.section.id}',
  );
  bool _canScrollBack = false;
  bool _canScrollForward = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateNavigationState);
    _scheduleNavigationUpdate();
  }

  @override
  void didUpdateWidget(covariant _CollectionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.section.collections
        .map((entry) => entry.collection.id)
        .toList(growable: false);
    final newIds = widget.section.collections
        .map((entry) => entry.collection.id)
        .toList(growable: false);
    if (!listEquals(oldIds, newIds)) {
      _canScrollBack = false;
      _canScrollForward = false;
      _scheduleNavigationUpdate(resetToStart: true);
    } else {
      _scheduleNavigationUpdate();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updateNavigationState)
      ..dispose();
    _previousFocusNode.dispose();
    _nextFocusNode.dispose();
    super.dispose();
  }

  void _scheduleNavigationUpdate({bool resetToStart = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (resetToStart) {
        _scrollController.jumpTo(_scrollController.position.minScrollExtent);
      }
      _updateNavigationState();
    });
  }

  void _updateNavigationState() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final canScrollBack = position.pixels > position.minScrollExtent + 1;
    final canScrollForward = position.pixels < position.maxScrollExtent - 1;
    if (canScrollBack == _canScrollBack &&
        canScrollForward == _canScrollForward) {
      return;
    }
    final moveFocusBack = _nextFocusNode.hasFocus && !canScrollForward;
    final moveFocusForward = _previousFocusNode.hasFocus && !canScrollBack;
    setState(() {
      _canScrollBack = canScrollBack;
      _canScrollForward = canScrollForward;
    });
    if (moveFocusBack || moveFocusForward) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (moveFocusBack && _canScrollBack) {
          _previousFocusNode.requestFocus();
        } else if (moveFocusForward && _canScrollForward) {
          _nextFocusNode.requestFocus();
        }
      });
    }
  }

  Future<void> _scrollBy(double delta) async {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              widget.section.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: widget.tvMode ? 26 : 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
          ),
          if (widget.onOpenAll != null)
            Tooltip(
              message: 'Mở tất cả ${widget.section.title}',
              child: TextButton(
                key: ValueKey(
                  'discovery-section-open-all-${widget.section.id}',
                ),
                onPressed: widget.onOpenAll,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  minimumSize: Size(
                    widget.tvMode ? 112 : 72,
                    widget.tvMode ? 52 : 44,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.tvMode ? 16 : 10,
                  ),
                  visualDensity: VisualDensity.compact,
                  textStyle: TextStyle(
                    fontSize: widget.tvMode ? 14 : 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                child: const Text('TẤT CẢ'),
              ),
            )
          else
            Text(
              '${widget.section.collections.length} tuyển tập',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: widget.tvMode ? 14 : 11,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
      SizedBox(height: widget.tvMode ? 16 : 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = widget.tvMode
              ? 220.0
              : constraints.maxWidth >= 900
              ? 188.0
              : 154.0;
          final gap = widget.tvMode ? 20.0 : 14.0;
          final cardHeight = cardWidth + (widget.tvMode ? 104 : 92);
          final contentWidth =
              widget.section.collections.length * cardWidth +
              (widget.section.collections.length - 1).clamp(0, 100000) * gap;
          final showNavigation =
              constraints.maxWidth >= 620 &&
              contentWidth > constraints.maxWidth + 1;
          final scrollAmount = cardWidth + gap;
          return SizedBox(
            key: ValueKey('discovery-section-rail-${widget.section.id}'),
            height: cardHeight,
            child: Stack(
              children: [
                ListView.separated(
                  key: ValueKey('discovery-section-list-${widget.section.id}'),
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.section.collections.length,
                  separatorBuilder: (_, __) => SizedBox(width: gap),
                  itemBuilder: (context, index) {
                    final item = widget.section.collections[index];
                    return SizedBox(
                      width: cardWidth,
                      child: _DiscoveryCollectionCard(
                        key: ValueKey(
                          'discovery-collection-${item.collection.id}',
                        ),
                        item: item,
                        tvMode: widget.tvMode,
                        onTap: () => widget.onCollectionTap(item.collection),
                        onPlay: widget.onCollectionPlay == null
                            ? null
                            : () => widget.onCollectionPlay!(item.collection),
                        onToggleSaved: widget.onCollectionToggleSaved == null
                            ? null
                            : () => widget.onCollectionToggleSaved!(
                                item.collection,
                              ),
                        onShare:
                            widget.onCollectionShare == null ||
                                item.collection.externalUrl.isEmpty
                            ? null
                            : () => widget.onCollectionShare!(item.collection),
                        onArtistTap: widget.onCollectionArtistTap,
                        saved: widget.savedCollectionIds.contains(
                          item.collection.id,
                        ),
                        playing:
                            widget.quickPlayingCollectionId ==
                            item.collection.id,
                      ),
                    );
                  },
                ),
                if (showNavigation && _canScrollBack)
                  Positioned(
                    left: widget.tvMode ? 10 : 6,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _BannerNavigationButton(
                        key: ValueKey(
                          'discovery-section-previous-${widget.section.id}',
                        ),
                        icon: Icons.chevron_left_rounded,
                        label: 'Tuyển tập trước trong ${widget.section.title}',
                        tvMode: widget.tvMode,
                        focusNode: _previousFocusNode,
                        onPressed: () => _scrollBy(-scrollAmount),
                      ),
                    ),
                  ),
                if (showNavigation && _canScrollForward)
                  Positioned(
                    right: widget.tvMode ? 10 : 6,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _BannerNavigationButton(
                        key: ValueKey(
                          'discovery-section-next-${widget.section.id}',
                        ),
                        icon: Icons.chevron_right_rounded,
                        label:
                            'Tuyển tập tiếp theo trong ${widget.section.title}',
                        tvMode: widget.tvMode,
                        focusNode: _nextFocusNode,
                        onPressed: () => _scrollBy(scrollAmount),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ],
  );
}

class _DiscoveryCollectionCard extends StatefulWidget {
  const _DiscoveryCollectionCard({
    super.key,
    required this.item,
    required this.tvMode,
    required this.onTap,
    required this.onPlay,
    required this.onToggleSaved,
    required this.onShare,
    required this.onArtistTap,
    required this.saved,
    required this.playing,
  });

  final DiscoveryCollection item;
  final bool tvMode;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onToggleSaved;
  final VoidCallback? onShare;
  final ValueChanged<CatalogArtist>? onArtistTap;
  final bool saved;
  final bool playing;

  @override
  State<_DiscoveryCollectionCard> createState() =>
      _DiscoveryCollectionCardState();
}

class _DiscoveryCollectionCardState extends State<_DiscoveryCollectionCard> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final collection = widget.item.collection;
    final active = _focused || _hovered;
    return Semantics(
      button: true,
      label: 'Mở ${collection.title}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onSecondaryTapDown: (details) async {
            await showCatalogCollectionContextMenu(
              context: context,
              globalPosition: details.globalPosition,
              keyPrefix: 'discovery-collection',
              collection: collection,
              saved: widget.saved,
              playing: widget.playing,
              onOpen: widget.onTap,
              onPlay: widget.onPlay,
              onToggleSaved: widget.onToggleSaved,
              onShare: widget.onShare,
            );
          },
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(widget.tvMode ? 18 : 14),
          onHover: (value) => setState(() => _hovered = value),
          onFocusChange: (value) {
            setState(() => _focused = value);
            if (value) {
              Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 220),
                alignment: 0.14,
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        widget.tvMode ? 17 : 13,
                      ),
                      border: Border.all(
                        color: active ? ZingColors.lime : Colors.transparent,
                        width: active ? 3 : 0,
                      ),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: ZingColors.purple.withValues(alpha: 0.3),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _DiscoveryImage(
                          url: collection.thumbnail,
                          fallbackIcon:
                              collection.kind == CatalogCollectionKind.album
                              ? Icons.album_rounded
                              : Icons.queue_music_rounded,
                        ),
                        AnimatedOpacity(
                          opacity: active ? 1 : 0,
                          duration: const Duration(milliseconds: 160),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0x990D0813),
                              borderRadius: BorderRadius.circular(
                                widget.tvMode ? 14 : 11,
                              ),
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        Positioned(
                          left: widget.tvMode ? 12 : 2,
                          right: widget.tvMode ? 12 : 2,
                          bottom: widget.tvMode ? 12 : 8,
                          child: CatalogCollectionActionDeck(
                            keyPrefix: 'discovery-collection',
                            collection: collection,
                            tvMode: widget.tvMode,
                            active: active,
                            saved: widget.saved,
                            playing: widget.playing,
                            onOpen: widget.onTap,
                            onPlay: widget.onPlay,
                            onToggleSaved: widget.onToggleSaved,
                            onShare: widget.onShare,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: widget.tvMode ? 11 : 9),
                Text(
                  collection.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: widget.tvMode ? 17 : 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                if (collection.artists.isNotEmpty && widget.onArtistTap != null)
                  CatalogArtistLinks(
                    artists: collection.artists,
                    onArtistTap: widget.onArtistTap!,
                    keyPrefix: 'discovery-collection-artist-${collection.id}',
                    tvMode: widget.tvMode,
                    touchLayout: MediaQuery.sizeOf(context).width < 720,
                  )
                else
                  Text(
                    widget.item.description.isNotEmpty
                        ? widget.item.description
                        : collection.artist,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: widget.tvMode ? 13 : 11,
                      height: 1.25,
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

class _DiscoveryImage extends StatelessWidget {
  const _DiscoveryImage({required this.url, required this.fallbackIcon});

  final String url;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(fallbackIcon, color: ZingColors.coral, size: 34),
      ),
    );
    if (url.isEmpty) return fallback;
    return Image.network(
      url,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      frameBuilder: (context, child, frame, _) => AnimatedOpacity(
        opacity: frame == null ? 0 : 1,
        duration: const Duration(milliseconds: 220),
        child: child,
      ),
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _DiscoveryLoadingState extends StatelessWidget {
  const _DiscoveryLoadingState({required this.tvMode});

  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      key: const ValueKey('discovery-loading-state'),
      container: true,
      liveRegion: true,
      label: 'Đang cập nhật nội dung Khám phá từ Zing MP3',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final quickColumns = tvMode
                ? 3
                : width >= 520
                ? 2
                : 1;
            const bannerColumns = 1;
            final quickGap = tvMode ? 20.0 : 14.0;
            final quickWidth =
                (width - quickGap * (quickColumns - 1)) / quickColumns;
            final bannerGap = tvMode ? 22.0 : 16.0;
            final bannerWidth = width;
            final denseQuickPlay = !tvMode && width >= 720;
            final quickHeight = tvMode
                ? 210.0
                : denseQuickPlay
                ? (quickWidth / 3.2).clamp(152.0, 168.0)
                : (quickWidth / 1.85).clamp(166.0, 190.0);
            final bannerHeight = tvMode
                ? (width / 7).clamp(160.0, 210.0)
                : width >= 520
                ? (width / 10).clamp(92.0, 132.0)
                : ((width * 0.92) / 3.6).clamp(96.0, 132.0);
            final songGap = tvMode ? 20.0 : 14.0;
            final preferredSongWidth = tvMode ? 220.0 : 174.0;
            final songCount =
                ((width + songGap) / (preferredSongWidth + songGap))
                    .floor()
                    .clamp(2, tvMode ? 6 : 5);
            final songWidth = ((width - songGap * (songCount - 1)) / songCount)
                .clamp(132.0, tvMode ? 220.0 : 196.0);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    key: const ValueKey('discovery-loading-progress'),
                    value: reducedMotion ? 0.42 : null,
                    minHeight: 4,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                  ),
                ),
                SizedBox(height: tvMode ? 22 : 16),
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_mosaic_rounded,
                      color: ZingColors.coral,
                      size: tvMode ? 26 : 20,
                    ),
                    SizedBox(width: tvMode ? 12 : 9),
                    Expanded(
                      child: Text(
                        'Đang cập nhật nội dung nổi bật từ Zing MP3…',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: tvMode ? 18 : 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tvMode ? 26 : 20),
                Wrap(
                  key: const ValueKey('discovery-loading-quick-play'),
                  spacing: quickGap,
                  runSpacing: quickGap,
                  children: [
                    for (var index = 0; index < quickColumns; index++)
                      _DiscoverySkeletonBlock(
                        key: ValueKey('discovery-loading-quick-card-$index'),
                        width: quickWidth,
                        height: quickHeight,
                        radius: tvMode ? 22 : 16,
                      ),
                  ],
                ),
                SizedBox(height: tvMode ? 38 : 28),
                Wrap(
                  key: const ValueKey('discovery-loading-banners'),
                  spacing: bannerGap,
                  runSpacing: bannerGap,
                  children: [
                    for (var index = 0; index < bannerColumns; index++)
                      _DiscoverySkeletonBlock(
                        key: ValueKey('discovery-loading-banner-$index'),
                        width: bannerWidth,
                        height: bannerHeight,
                        radius: tvMode ? 24 : 18,
                      ),
                  ],
                ),
                SizedBox(height: tvMode ? 38 : 28),
                _DiscoveryLoadingHeading(
                  key: const ValueKey('discovery-loading-song-heading'),
                  width: tvMode ? 180 : 140,
                  tvMode: tvMode,
                ),
                SizedBox(height: tvMode ? 16 : 12),
                SingleChildScrollView(
                  key: const ValueKey('discovery-loading-songs'),
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Row(
                    children: [
                      for (var index = 0; index < songCount; index++) ...[
                        if (index > 0) SizedBox(width: songGap),
                        _DiscoveryLoadingSongCard(
                          key: ValueKey('discovery-loading-song-$index'),
                          width: songWidth,
                          tvMode: tvMode,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DiscoveryLoadingHeading extends StatelessWidget {
  const _DiscoveryLoadingHeading({
    super.key,
    required this.width,
    required this.tvMode,
  });

  final double width;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => _DiscoverySkeletonBlock(
    width: width,
    height: tvMode ? 26 : 20,
    radius: 7,
  );
}

class _DiscoveryLoadingSongCard extends StatelessWidget {
  const _DiscoveryLoadingSongCard({
    super.key,
    required this.width,
    required this.tvMode,
  });

  final double width;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DiscoverySkeletonBlock(
          width: width,
          height: width,
          radius: tvMode ? 20 : 14,
        ),
        SizedBox(height: tvMode ? 12 : 9),
        _DiscoverySkeletonBlock(
          width: width * 0.82,
          height: tvMode ? 18 : 14,
          radius: 6,
        ),
        SizedBox(height: tvMode ? 9 : 7),
        _DiscoverySkeletonBlock(
          width: width * 0.58,
          height: tvMode ? 14 : 11,
          radius: 5,
        ),
      ],
    ),
  );
}

class _DiscoverySkeletonBlock extends StatelessWidget {
  const _DiscoverySkeletonBlock({
    super.key,
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.16),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceContainerHighest.withValues(alpha: 0.72),
            colors.onSurface.withValues(alpha: 0.075),
            colors.surfaceContainerHighest.withValues(alpha: 0.48),
          ],
          stops: const [0, 0.54, 1],
        ),
      ),
    );
  }
}

class _DiscoveryErrorState extends StatelessWidget {
  const _DiscoveryErrorState({required this.onRetry, this.empty = false});

  final VoidCallback onRetry;
  final bool empty;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.76),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.34),
      ),
    ),
    child: Row(
      children: [
        const Icon(Icons.explore_off_rounded, color: ZingColors.coral),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            empty
                ? 'Chưa có nội dung Khám phá để hiển thị.'
                : 'Chưa tải được Top 100, Chill và Album Hot.',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    ),
  );
}

class _StaleDiscoveryNotice extends StatelessWidget {
  const _StaleDiscoveryNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: ZingColors.coral.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.cloud_off_rounded, size: 18, color: ZingColors.coral),
        const SizedBox(width: 9),
        const Expanded(
          child: Text(
            'Đang hiển thị nội dung gần nhất.',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Cập nhật')),
      ],
    ),
  );
}
