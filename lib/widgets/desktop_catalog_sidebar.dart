import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum DesktopCatalogDestination {
  library,
  discovery,
  chart,
  liveRadio,
  newReleaseChart,
  hubs,
  top100,
  forYou,
}

class DesktopCatalogSidebar extends StatelessWidget {
  const DesktopCatalogSidebar({
    super.key,
    required this.selected,
    required this.onDestinationSelected,
    required this.likedSongs,
    required this.playlists,
    required this.listeningMinutes,
    required this.onOpenLocalProfile,
    required this.onCreatePlaylist,
    required this.onShowQueue,
  });

  final DesktopCatalogDestination selected;
  final ValueChanged<DesktopCatalogDestination> onDestinationSelected;
  final int likedSongs;
  final int playlists;
  final int listeningMinutes;
  final VoidCallback onOpenLocalProfile;
  final VoidCallback onCreatePlaylist;
  final VoidCallback onShowQueue;

  static const width = 238.0;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).brightness == Brightness.dark
        ? ZingColors.sidebar
        : Theme.of(context).colorScheme.surface;
    return SizedBox(
      key: const ValueKey('desktop-catalog-sidebar'),
      width: width,
      child: ColoredBox(
        color: surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SidebarBrand(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  children: [
                    _SidebarDestinationTile(
                      destination: DesktopCatalogDestination.library,
                      selected: selected,
                      icon: Icons.library_music_outlined,
                      selectedIcon: Icons.library_music_rounded,
                      label: 'Thư viện',
                      onSelected: onDestinationSelected,
                    ),
                    _SidebarDestinationTile(
                      destination: DesktopCatalogDestination.discovery,
                      selected: selected,
                      icon: Icons.explore_outlined,
                      selectedIcon: Icons.explore_rounded,
                      label: 'Khám phá',
                      onSelected: onDestinationSelected,
                    ),
                    _SidebarDestinationTile(
                      destination: DesktopCatalogDestination.chart,
                      selected: selected,
                      icon: Icons.insights_outlined,
                      selectedIcon: Icons.insights_rounded,
                      label: '#zingchart',
                      onSelected: onDestinationSelected,
                    ),
                    _SidebarDestinationTile(
                      destination: DesktopCatalogDestination.liveRadio,
                      selected: selected,
                      icon: Icons.radio_outlined,
                      selectedIcon: Icons.radio_rounded,
                      label: 'Phòng Nhạc',
                      badge: 'LIVE',
                      onSelected: onDestinationSelected,
                    ),
                    const _SidebarDivider(),
                    _SidebarDestinationTile(
                      destination: DesktopCatalogDestination.newReleaseChart,
                      selected: selected,
                      icon: Icons.new_releases_outlined,
                      selectedIcon: Icons.new_releases_rounded,
                      label: 'BXH Nhạc Mới',
                      onSelected: onDestinationSelected,
                    ),
                    _SidebarDestinationTile(
                      destination: DesktopCatalogDestination.hubs,
                      selected: selected,
                      icon: Icons.category_outlined,
                      selectedIcon: Icons.category_rounded,
                      label: 'Chủ Đề & Thể Loại',
                      onSelected: onDestinationSelected,
                    ),
                    _SidebarDestinationTile(
                      destination: DesktopCatalogDestination.top100,
                      selected: selected,
                      icon: Icons.star_outline_rounded,
                      selectedIcon: Icons.star_rounded,
                      label: 'Top 100',
                      onSelected: onDestinationSelected,
                    ),
                    const _SidebarDivider(),
                    _SidebarDestinationTile(
                      destination: DesktopCatalogDestination.forYou,
                      selected: selected,
                      icon: Icons.auto_awesome_outlined,
                      selectedIcon: Icons.auto_awesome_rounded,
                      label: 'Dành cho bạn',
                      onSelected: onDestinationSelected,
                    ),
                  ],
                ),
              ),
              _SidebarLocalProfileCard(
                selected: selected == DesktopCatalogDestination.forYou,
                likedSongs: likedSongs,
                playlists: playlists,
                listeningMinutes: listeningMinutes,
                onPressed: onOpenLocalProfile,
              ),
              const Divider(height: 1),
              _SidebarFooterAction(
                key: const ValueKey('desktop-create-playlist'),
                icon: Icons.add_rounded,
                label: 'Tạo playlist mới',
                onPressed: onCreatePlaylist,
              ),
              _SidebarFooterAction(
                key: const ValueKey('desktop-open-player-panel'),
                icon: Icons.queue_music_rounded,
                label: 'Danh sách phát',
                onPressed: onShowQueue,
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarLocalProfileCard extends StatefulWidget {
  const _SidebarLocalProfileCard({
    required this.selected,
    required this.likedSongs,
    required this.playlists,
    required this.listeningMinutes,
    required this.onPressed,
  });

  final bool selected;
  final int likedSongs;
  final int playlists;
  final int listeningMinutes;
  final VoidCallback onPressed;

  @override
  State<_SidebarLocalProfileCard> createState() =>
      _SidebarLocalProfileCardState();
}

class _SidebarLocalProfileCardState extends State<_SidebarLocalProfileCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final highlighted = widget.selected || _hovered || _focused;
    final radius = BorderRadius.circular(10);
    final listeningLabel = widget.listeningMinutes == 0
        ? 'Bắt đầu hành trình nghe nhạc'
        : '${widget.listeningMinutes} phút trong 30 ngày';
    return Semantics(
      button: true,
      selected: widget.selected,
      label:
          'Cá nhân local, ${widget.likedSongs} bài thích, '
          '${widget.playlists} playlist, $listeningLabel. Mở hồ sơ.',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: AnimatedContainer(
          key: const ValueKey('desktop-local-profile-card'),
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ZingColors.purple.withValues(alpha: highlighted ? 0.38 : 0.26),
                ZingColors.coral.withValues(alpha: highlighted ? 0.23 : 0.13),
              ],
            ),
            borderRadius: radius,
            border: Border.all(
              color: _focused
                  ? ZingColors.lime
                  : widget.selected
                  ? ZingColors.purpleBright.withValues(alpha: 0.8)
                  : colorScheme.outlineVariant.withValues(alpha: 0.42),
              width: _focused ? 2 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              key: const ValueKey('desktop-open-local-profile'),
              borderRadius: radius,
              mouseCursor: SystemMouseCursors.click,
              onTap: widget.onPressed,
              onHover: (value) => setState(() => _hovered = value),
              onFocusChange: (value) => setState(() => _focused = value),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                ZingColors.purpleBright,
                                ZingColors.coral,
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 21,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CÁ NHÂN LOCAL',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: ZingColors.lime,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.15,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Không cần đăng nhập',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '${widget.likedSongs} bài thích · '
                      '${widget.playlists} playlist',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      listeningLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
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

class _SidebarBrand extends StatelessWidget {
  const _SidebarBrand();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 24, 16, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '#zingChart',
          style: TextStyle(
            color: ZingColors.purpleBright,
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'MUSIC CLIENT',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.1,
          ),
        ),
      ],
    ),
  );
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Divider(
      height: 1,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.35),
    ),
  );
}

class _SidebarDestinationTile extends StatefulWidget {
  const _SidebarDestinationTile({
    required this.destination,
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onSelected,
    this.badge,
  });

  final DesktopCatalogDestination destination;
  final DesktopCatalogDestination selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? badge;
  final ValueChanged<DesktopCatalogDestination> onSelected;

  @override
  State<_SidebarDestinationTile> createState() =>
      _SidebarDestinationTileState();
}

class _SidebarDestinationTileState extends State<_SidebarDestinationTile> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.destination == widget.selected;
    final emphasized = selected || _hovered || _focused;
    final foreground = selected
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final radius = BorderRadius.circular(8);
    return Semantics(
      button: true,
      selected: selected,
      label: widget.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: selected
                ? ZingColors.purple.withValues(alpha: 0.28)
                : _hovered
                ? Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55)
                : Colors.transparent,
            borderRadius: radius,
            border: Border.all(
              color: _focused ? ZingColors.lime : Colors.transparent,
              width: 2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              key: ValueKey('desktop-nav-${widget.destination.name}'),
              borderRadius: radius,
              mouseCursor: SystemMouseCursors.click,
              onTap: () => widget.onSelected(widget.destination),
              onHover: (value) => setState(() => _hovered = value),
              onFocusChange: (value) {
                setState(() => _focused = value);
                if (value) {
                  Scrollable.ensureVisible(
                    context,
                    duration: const Duration(milliseconds: 180),
                    alignment: 0.25,
                  );
                }
              },
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 3,
                      height: selected ? 25 : 0,
                      decoration: BoxDecoration(
                        color: ZingColors.purpleBright,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Icon(
                      selected ? widget.selectedIcon : widget.icon,
                      size: 22,
                      color: emphasized
                          ? foreground
                          : foreground.withValues(alpha: 0.82),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.badge != null)
                      Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ZingColors.coral,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
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

class _SidebarFooterAction extends StatelessWidget {
  const _SidebarFooterAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 22),
    label: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    style: TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      alignment: Alignment.centerLeft,
      minimumSize: const Size.fromHeight(46),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shape: const RoundedRectangleBorder(),
    ),
  );
}
