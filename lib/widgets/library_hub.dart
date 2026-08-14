import 'package:flutter/material.dart';

import '../models/local_library.dart';
import '../models/song.dart';
import '../music_player_controller.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';

class LibraryHub extends StatelessWidget {
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
          LayoutBuilder(
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
              return compact
                  ? SizedBox(
                      height: 116,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: cards.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, index) =>
                            SizedBox(width: 150, child: cards[index]),
                      ),
                    )
                  : Row(
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
          ),
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
          SizedBox(
            height: 176,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _PlaylistCard(
                  title: 'Đã thích',
                  subtitle: '${controller.likedSongs.length} bài hát',
                  accent: ZingColors.coral,
                  selected: selectedPlaylistId == null,
                  icon: Icons.favorite_rounded,
                  onTap: () => onSelectPlaylist(null),
                ),
                ...controller.playlists.map(
                  (playlist) => _PlaylistCard(
                    key: ValueKey('playlist-${playlist.id}'),
                    title: playlist.name,
                    subtitle: '${playlist.songs.length} bài hát',
                    accent: ZingColors.blue,
                    selected: selectedPlaylistId == playlist.id,
                    artwork: playlist.songs.firstOrNull?.thumbnail,
                    onTap: () => onSelectPlaylist(playlist.id),
                    onRename: () => onRenamePlaylist(playlist),
                    onDelete: () => onDeletePlaylist(playlist),
                  ),
                ),
              ],
            ),
          ),
          if (recentSongs.isNotEmpty) ...[
            const SizedBox(height: 28),
            const _SectionTitle(
              eyebrow: 'LỊCH SỬ LOCAL',
              title: 'Nghe gần đây',
            ),
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
                      onTap: () =>
                          controller.playSong(song, queue: recentSongs),
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
          const SizedBox(height: 30),
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
          const SizedBox(height: 30),
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
      ),
    );
  }

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
