import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_navigation_route.dart';
import '../models/catalog_search.dart';
import '../models/local_library.dart';
import '../models/playback_origin.dart';
import '../models/song.dart';
import '../music_player_controller.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';

export '../models/app_navigation_route.dart' show LibrarySection;

class LibraryHub extends StatefulWidget {
  const LibraryHub({
    super.key,
    required this.controller,
    required this.selectedPlaylistId,
    required this.onSelectPlaylist,
    required this.onCreatePlaylist,
    required this.onRenamePlaylist,
    required this.onDeletePlaylist,
    required this.onPlaySongs,
    required this.onExportBackup,
    required this.onImportBackup,
    required this.onOpenAnalytics,
    required this.onOpenWrapped,
    required this.onArtistTap,
    required this.onCollectionTap,
    this.section = LibrarySection.overview,
    this.onSectionChanged,
    this.tvMode = false,
  });

  final MusicPlayerController controller;
  final String? selectedPlaylistId;
  final ValueChanged<String?> onSelectPlaylist;
  final VoidCallback onCreatePlaylist;
  final ValueChanged<LocalPlaylist> onRenamePlaylist;
  final ValueChanged<LocalPlaylist> onDeletePlaylist;
  final ValueChanged<List<Song>> onPlaySongs;
  final VoidCallback onExportBackup;
  final VoidCallback onImportBackup;
  final VoidCallback onOpenAnalytics;
  final VoidCallback onOpenWrapped;
  final ValueChanged<CatalogArtist> onArtistTap;
  final ValueChanged<CatalogCollection> onCollectionTap;
  final LibrarySection section;
  final ValueChanged<LibrarySection>? onSectionChanged;
  final bool tvMode;

  @override
  State<LibraryHub> createState() => _LibraryHubState();
}

class _LibraryHubState extends State<LibraryHub> {
  late LibrarySection _section = widget.section;

  MusicPlayerController get controller => widget.controller;
  String? get selectedPlaylistId => widget.selectedPlaylistId;
  ValueChanged<String?> get onSelectPlaylist => widget.onSelectPlaylist;
  VoidCallback get onCreatePlaylist => widget.onCreatePlaylist;
  ValueChanged<LocalPlaylist> get onRenamePlaylist => widget.onRenamePlaylist;
  ValueChanged<LocalPlaylist> get onDeletePlaylist => widget.onDeletePlaylist;
  ValueChanged<List<Song>> get onPlaySongs => widget.onPlaySongs;
  VoidCallback get onExportBackup => widget.onExportBackup;
  VoidCallback get onImportBackup => widget.onImportBackup;
  VoidCallback get onOpenAnalytics => widget.onOpenAnalytics;
  VoidCallback get onOpenWrapped => widget.onOpenWrapped;
  ValueChanged<CatalogArtist> get onArtistTap => widget.onArtistTap;
  ValueChanged<CatalogCollection> get onCollectionTap => widget.onCollectionTap;
  bool get tvMode => widget.tvMode;

  @override
  void didUpdateWidget(covariant LibraryHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section && _section != widget.section) {
      _section = widget.section;
    }
  }

  void _selectSection(LibrarySection section) {
    if (_section == section) return;
    setState(() => _section = section);
    widget.onSectionChanged?.call(section);
  }

  void _openSongCollection(String? playlistId) {
    _selectSection(
      playlistId == null ? LibrarySection.songs : LibrarySection.playlists,
    );
    onSelectPlaylist(playlistId);
  }

  @override
  Widget build(BuildContext context) {
    final topSong = controller.topSongStats.firstOrNull;
    final topArtist = controller.topArtistStats.firstOrNull;
    final minutes = controller.totalListeningTime.inMinutes;
    final recentSongs = controller.recentlyPlayed.take(10).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LibrarySectionTabs(
            selected: _section,
            tvMode: tvMode,
            onSelected: _selectSection,
          ),
          const SizedBox(height: 22),
          AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey('library-section-${_section.name}'),
              child: switch (_section) {
                LibrarySection.overview => _buildOverview(
                  context,
                  topSong: topSong,
                  topArtist: topArtist,
                  minutes: minutes,
                  recentSongs: recentSongs,
                ),
                LibrarySection.songs => _buildSongs(context),
                LibrarySection.playlists => _buildPlaylists(
                  context,
                  includeLikedSongs: false,
                ),
                LibrarySection.albums => _buildSavedCollections(
                  context,
                  showEmptyState: true,
                ),
                LibrarySection.artists => _buildFollowedArtists(context),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(
    BuildContext context, {
    required SongListeningStat? topSong,
    required ArtistListeningStat? topArtist,
    required int minutes,
    required List<Song> recentSongs,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildStats(context, minutes),
      const SizedBox(height: 28),
      _SectionTitle(
        eyebrow: 'MADE ON THIS DEVICE',
        title: 'Mix của bạn',
        trailing: controller.dailyMix.isEmpty
            ? null
            : TextButton.icon(
                onPressed: () => onPlaySongs(controller.dailyMix),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Phát tất cả'),
              ),
      ),
      const SizedBox(height: 12),
      _LocalMixCard(
        topSong: topSong,
        topArtist: topArtist,
        songs: controller.dailyMix,
        onPlay: controller.dailyMix.isEmpty
            ? null
            : () => onPlaySongs(controller.dailyMix),
      ),
      const SizedBox(height: 30),
      _buildPlaylists(context, includeLikedSongs: true),
      if (controller.savedCollections.isNotEmpty) ...[
        const SizedBox(height: 30),
        _buildSavedCollections(context, showEmptyState: false),
      ],
      const SizedBox(height: 30),
      _buildFollowedArtists(context),
      if (recentSongs.isNotEmpty) ...[
        const SizedBox(height: 28),
        _buildRecentSongs(context, recentSongs),
      ],
      const SizedBox(height: 30),
      _buildWrapped(context),
      const SizedBox(height: 30),
      _buildDataTools(context),
    ],
  );

  Widget _buildStats(BuildContext context, int minutes) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 620;
      final cards = [
        _StatCard(
          key: const ValueKey('library-stat-minutes'),
          value: _compactNumber(minutes),
          label: 'phút đã nghe',
          icon: Icons.schedule_rounded,
          accent: ZingColors.coral,
          onTap: onOpenAnalytics,
        ),
        _StatCard(
          value: '${controller.history.length}',
          label: 'lượt phát local',
          icon: Icons.graphic_eq_rounded,
          accent: ZingColors.lime,
          onTap: onOpenAnalytics,
        ),
        _StatCard(
          value: '${controller.likedSongs.length}',
          label: 'bài đã thích',
          icon: Icons.favorite_rounded,
          accent: ZingColors.blue,
          onTap: onOpenAnalytics,
        ),
      ];
      if (compact) {
        return SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, index) =>
                SizedBox(width: 150, child: cards[index]),
          ),
        );
      }
      return Row(
        children: cards
            .map(
              (card) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: card,
                ),
              ),
            )
            .toList(),
      );
    },
  );

  Widget _buildSongs(BuildContext context) => Container(
    key: const ValueKey('library-liked-songs-hero'),
    constraints: const BoxConstraints(minHeight: 146),
    padding: EdgeInsets.all(tvMode ? 24 : 18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(tvMode ? 28 : 22),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          ZingColors.coral.withValues(alpha: 0.28),
          ZingColors.purple.withValues(alpha: 0.18),
        ],
      ),
      border: Border.all(color: ZingColors.coral.withValues(alpha: 0.28)),
    ),
    child: Row(
      children: [
        Container(
          width: tvMode ? 92 : 72,
          height: tvMode ? 92 : 72,
          decoration: BoxDecoration(
            color: ZingColors.coral.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(tvMode ? 26 : 20),
          ),
          child: Icon(
            Icons.favorite_rounded,
            size: tvMode ? 46 : 36,
            color: ZingColors.coral,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'BÀI HÁT · LƯU LOCAL',
                style: TextStyle(
                  color: ZingColors.lime,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Bài hát đã thích',
                style: TextStyle(
                  fontSize: tvMode ? 28 : 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${controller.likedSongs.length} bài · chỉ lưu trên thiết bị này',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        if (controller.likedSongs.isNotEmpty)
          FilledButton.icon(
            key: const ValueKey('library-play-liked-songs'),
            onPressed: () => onPlaySongs(controller.likedSongs),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(tvMode ? 'Phát tất cả' : 'Phát'),
          ),
      ],
    ),
  );

  Widget _buildPlaylists(
    BuildContext context, {
    required bool includeLikedSongs,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionTitle(
        eyebrow: 'BỘ SƯU TẬP',
        title: 'Playlist cá nhân',
        trailing: FilledButton.tonalIcon(
          key: const ValueKey('create-playlist-button'),
          onPressed: onCreatePlaylist,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Tạo mới'),
        ),
      ),
      const SizedBox(height: 12),
      if (!includeLikedSongs && controller.playlists.isEmpty)
        const _LibraryEmptyCard(
          key: ValueKey('library-playlists-empty'),
          icon: Icons.playlist_add_rounded,
          title: 'Chưa có playlist cá nhân',
          message: 'Tạo playlist để gom bài hát theo cách riêng của bạn.',
        )
      else
        SizedBox(
          key: const ValueKey('library-playlists-rail'),
          height: 176,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              if (includeLikedSongs)
                _PlaylistCard(
                  title: 'Đã thích',
                  subtitle: '${controller.likedSongs.length} bài hát',
                  accent: ZingColors.coral,
                  selected: _section == LibrarySection.songs,
                  icon: Icons.favorite_rounded,
                  onTap: () => _openSongCollection(null),
                ),
              ...controller.playlists.map(
                (playlist) => _PlaylistCard(
                  key: ValueKey('playlist-${playlist.id}'),
                  title: playlist.name,
                  subtitle: '${playlist.songs.length} bài hát',
                  accent: ZingColors.blue,
                  selected: selectedPlaylistId == playlist.id,
                  artwork: playlist.songs.firstOrNull?.thumbnail,
                  onTap: () => _openSongCollection(playlist.id),
                  onRename: () => onRenamePlaylist(playlist),
                  onDelete: () => onDeletePlaylist(playlist),
                ),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _buildSavedCollections(
    BuildContext context, {
    required bool showEmptyState,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionTitle(
        eyebrow: 'TỪ ZING MP3 · LƯU LOCAL',
        title: 'Album & playlist đã lưu',
        trailing: controller.savedCollections.isEmpty
            ? null
            : Text(
                '${controller.savedCollections.length} nội dung',
                style: Theme.of(context).textTheme.labelLarge,
              ),
      ),
      const SizedBox(height: 12),
      if (controller.savedCollections.isEmpty)
        if (showEmptyState)
          const _LibraryEmptyCard(
            key: ValueKey('library-albums-empty'),
            icon: Icons.album_outlined,
            title: 'Chưa lưu album hoặc playlist',
            message:
                'Mở nội dung chính thức từ Zing MP3 rồi chọn Lưu thư viện.',
          )
        else
          const SizedBox.shrink()
      else
        SizedBox(
          key: const ValueKey('saved-collections-rail'),
          height: 176,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: controller.savedCollections.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final collection = controller.savedCollections[index];
              return _PlaylistCard(
                key: ValueKey('saved-collection-${collection.id}'),
                title: collection.title,
                subtitle:
                    '${collection.kindLabel} · ${collection.artist.isEmpty ? 'Zing MP3' : collection.artist}',
                accent: ZingColors.purpleBright,
                selected: false,
                artwork: collection.thumbnail,
                onTap: () => onCollectionTap(collection),
              );
            },
          ),
        ),
    ],
  );

  Widget _buildFollowedArtists(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionTitle(
        eyebrow: 'LƯU TRÊN THIẾT BỊ',
        title: 'Nghệ sĩ đã quan tâm',
        trailing: controller.followedArtists.isEmpty
            ? null
            : Text(
                '${controller.followedArtists.length} nghệ sĩ',
                style: Theme.of(context).textTheme.labelLarge,
              ),
      ),
      const SizedBox(height: 12),
      if (controller.followedArtists.isEmpty)
        const _LibraryEmptyCard(
          key: ValueKey('followed-artists-empty'),
          icon: Icons.person_add_alt_1_rounded,
          title: 'Chưa quan tâm nghệ sĩ nào',
          message:
              'Mở hồ sơ nghệ sĩ/OA và chọn Quan tâm. Danh sách chỉ lưu trên thiết bị này.',
        )
      else
        SizedBox(
          key: const ValueKey('followed-artists-rail'),
          height: tvMode ? 224 : 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: controller.followedArtists.length,
            separatorBuilder: (_, __) => SizedBox(width: tvMode ? 18 : 12),
            itemBuilder: (context, index) {
              final artist = controller.followedArtists[index];
              return _FollowedArtistCard(
                artist: artist,
                tvMode: tvMode,
                onTap: () => onArtistTap(artist),
              );
            },
          ),
        ),
    ],
  );

  Widget _buildRecentSongs(BuildContext context, List<Song> recentSongs) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(eyebrow: 'LỊCH SỬ LOCAL', title: 'Nghe gần đây'),
          const SizedBox(height: 12),
          SizedBox(
            height: 146,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recentSongs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final song = recentSongs[index];
                return SizedBox(
                  width: 118,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => controller.playSong(
                      song,
                      queue: recentSongs,
                      origin: const PlaybackOrigin(
                        kind: PlaybackOriginKind.recentlyPlayed,
                        label: 'Nghe gần đây',
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AlbumArt(
                          imageUrl: song.thumbnail,
                          semanticLabel: 'Bìa album ${song.displayTitle}',
                          size: 96,
                          borderRadius: 18,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          song.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );

  Widget _buildWrapped(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionTitle(
        eyebrow: 'YEAR IN SOUND',
        title: 'Mini Wrapped',
        trailing: FilledButton.tonalIcon(
          onPressed: onOpenWrapped,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Mở Wrapped'),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 10,
          ),
          leading: const Icon(
            Icons.local_fire_department_rounded,
            color: ZingColors.coral,
          ),
          title: const Text(
            'Dấu ấn nghe nhạc quanh năm',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: const Text(
            '6 slide được dựng hoàn toàn từ dữ liệu trên thiết bị.',
          ),
          trailing: const Icon(Icons.arrow_forward_rounded),
          onTap: onOpenWrapped,
        ),
      ),
    ],
  );

  Widget _buildDataTools(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionTitle(eyebrow: 'LOCAL-FIRST', title: 'Dữ liệu của bạn'),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('export-backup-button'),
                onPressed: onExportBackup,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Xuất backup JSON'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('import-backup-button'),
                onPressed: onImportBackup,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Khôi phục JSON'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('theme-mode-button'),
                onPressed: controller.cycleThemePreference,
                icon: Icon(_themeIcon(controller.themePreference)),
                label: Text(_themeLabel(controller.themePreference)),
              ),
              Text(
                'Không cần tài khoản · lưu trên thiết bị',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ],
  );

  static String _compactNumber(int value) => value >= 1000
      ? '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}k'
      : '$value';

  static IconData _themeIcon(AppThemePreference preference) =>
      switch (preference) {
        AppThemePreference.system => Icons.brightness_auto_rounded,
        AppThemePreference.light => Icons.light_mode_rounded,
        AppThemePreference.dark => Icons.dark_mode_rounded,
      };

  static String _themeLabel(AppThemePreference preference) =>
      switch (preference) {
        AppThemePreference.system => 'Theme: hệ thống',
        AppThemePreference.light => 'Theme: sáng',
        AppThemePreference.dark => 'Theme: tối',
      };
}

class _LibrarySectionTabs extends StatelessWidget {
  const _LibrarySectionTabs({
    required this.selected,
    required this.tvMode,
    required this.onSelected,
  });

  final LibrarySection selected;
  final bool tvMode;
  final ValueChanged<LibrarySection> onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Phân mục thư viện',
    child: SingleChildScrollView(
      key: const ValueKey('library-section-tabs'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final section in LibrarySection.values) ...[
            _LibrarySectionButton(
              section: section,
              label: switch (section) {
                LibrarySection.overview => 'TỔNG QUAN',
                LibrarySection.songs => 'BÀI HÁT',
                LibrarySection.playlists => 'PLAYLIST',
                LibrarySection.albums => 'ALBUM',
                LibrarySection.artists => 'NGHỆ SĨ',
              },
              selected: section == selected,
              tvMode: tvMode,
              onTap: () => onSelected(section),
            ),
            if (section != LibrarySection.values.last)
              SizedBox(width: tvMode ? 28 : 18),
          ],
        ],
      ),
    ),
  );
}

class _LibrarySectionButton extends StatefulWidget {
  const _LibrarySectionButton({
    required this.section,
    required this.label,
    required this.selected,
    required this.tvMode,
    required this.onTap,
  });

  final LibrarySection section;
  final String label;
  final bool selected;
  final bool tvMode;
  final VoidCallback onTap;

  @override
  State<_LibrarySectionButton> createState() => _LibrarySectionButtonState();
}

class _LibrarySectionButtonState extends State<_LibrarySectionButton> {
  bool _hovered = false;
  bool _focused = false;

  void _handleFocus(bool focused) {
    if (_focused != focused) setState(() => _focused = focused);
    if (!focused) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.selected || _hovered || _focused;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: widget.selected,
      button: true,
      label: '${widget.label}, phân mục thư viện',
      onTap: widget.onTap,
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: TextButton(
          key: ValueKey('library-tab-${widget.section.name}'),
          onPressed: widget.onTap,
          onFocusChange: _handleFocus,
          style: TextButton.styleFrom(
            minimumSize: Size(0, widget.tvMode ? 58 : 46),
            padding: EdgeInsets.symmetric(horizontal: widget.tvMode ? 8 : 2),
            foregroundColor: highlighted
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
            shape: const RoundedRectangleBorder(),
          ),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 160),
            padding: EdgeInsets.only(
              top: widget.tvMode ? 14 : 11,
              bottom: widget.tvMode ? 11 : 8,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: widget.selected
                      ? ZingColors.purpleBright
                      : _focused
                      ? ZingColors.lime
                      : Colors.transparent,
                  width: widget.tvMode ? 4 : 3,
                ),
              ),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: widget.tvMode ? 17 : 13,
                fontWeight: FontWeight.w900,
                letterSpacing: widget.tvMode ? 1.1 : 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryEmptyCard extends StatelessWidget {
  const _LibraryEmptyCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      leading: Icon(icon, color: ZingColors.purpleBright),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(message),
    ),
  );
}

class _FollowedArtistCard extends StatefulWidget {
  const _FollowedArtistCard({
    required this.artist,
    required this.tvMode,
    required this.onTap,
  });

  final CatalogArtist artist;
  final bool tvMode;
  final VoidCallback onTap;

  @override
  State<_FollowedArtistCard> createState() => _FollowedArtistCardState();
}

class _FollowedArtistCardState extends State<_FollowedArtistCard> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final artSize = widget.tvMode ? 132.0 : 108.0;
    return SizedBox(
      width: widget.tvMode ? 170 : 142,
      child: Focus(
        key: ValueKey('followed-artist-${widget.artist.id}'),
        focusNode: _focusNode,
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.select)) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        onFocusChange: (focused) {
          if (!focused) return;
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 180),
          );
        },
        child: Card(
          child: InkWell(
            canRequestFocus: false,
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: EdgeInsets.all(widget.tvMode ? 14 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AlbumArt(
                    imageUrl: widget.artist.avatar,
                    semanticLabel: 'Ảnh nghệ sĩ ${widget.artist.name}',
                    size: artSize,
                    borderRadius: 999,
                  ),
                  const SizedBox(height: 9),
                  Text(
                    widget.artist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: widget.tvMode ? 17 : 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Đang quan tâm',
                    maxLines: 1,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontSize: widget.tvMode ? 13 : 11,
                      fontWeight: FontWeight.w800,
                    ),
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 28,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.eyebrow,
    required this.title,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final Widget? trailing;

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
                color: Theme.of(context).colorScheme.secondary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
      if (trailing != null) trailing!,
    ],
  );
}

class _LocalMixCard extends StatelessWidget {
  const _LocalMixCard({
    required this.topSong,
    required this.topArtist,
    required this.songs,
    required this.onPlay,
  });

  final SongListeningStat? topSong;
  final ArtistListeningStat? topArtist;
  final List<Song> songs;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 170),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF313433), Color(0xFF202125)],
        ),
        border: Border.all(color: ZingColors.lime.withValues(alpha: 0.28)),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'DAILY / LOCAL MIX',
                  style: TextStyle(
                    color: ZingColors.lime,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  topSong == null ? 'Bắt đầu nghe để tạo mix' : 'Nhịp quen',
                  style: const TextStyle(
                    color: ZingColors.paper,
                    fontSize: 29,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  topSong == null
                      ? 'Mix được tạo hoàn toàn từ lịch sử trên máy này.'
                      : '${topSong!.song.displayTitle} · ${topArtist?.artist ?? topSong!.song.artistsNames}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFCACCC8)),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onPlay,
                  style: FilledButton.styleFrom(
                    backgroundColor: ZingColors.lime,
                    foregroundColor: ZingColors.ink,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text('${songs.length} bài'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Icon(
            Icons.blur_on_rounded,
            size: 76,
            color: scheme.primary.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.selected,
    required this.onTap,
    this.icon,
    this.artwork,
    this.onRename,
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? artwork;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 156,
    child: Card(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).cardColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (artwork != null)
                    AlbumArt(
                      imageUrl: artwork!,
                      semanticLabel: 'Ảnh playlist $title',
                      size: 62,
                      borderRadius: 17,
                    )
                  else
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Icon(
                        icon ?? Icons.music_note_rounded,
                        color: accent,
                      ),
                    ),
                  const Spacer(),
                  if (onRename != null || onDelete != null)
                    PopupMenuButton<String>(
                      tooltip: 'Tùy chọn playlist',
                      onSelected: (value) {
                        if (value == 'rename') onRename?.call();
                        if (value == 'delete') onDelete?.call();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('Đổi tên')),
                        PopupMenuItem(value: 'delete', child: Text('Xóa')),
                      ],
                    ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    ),
  );
}
