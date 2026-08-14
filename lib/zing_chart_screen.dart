import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/song.dart';
import 'music_player_controller.dart';
import 'music_player_scope.dart';
import 'music_player_screen.dart';
import 'widgets/album_art.dart';
import 'widgets/desktop_now_playing_panel.dart';
import 'widgets/mini_player.dart';
import 'zing_mp3_api.dart';

typedef ChartLoader = Future<List<Song>> Function();

List<Song> filterSongs(List<Song> songs, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return List<Song>.unmodifiable(songs);
  return songs
      .where(
        (song) =>
            song.displayTitle.toLowerCase().contains(normalized) ||
            song.artistsNames.toLowerCase().contains(normalized),
      )
      .toList(growable: false);
}

class ZingChartScreen extends StatefulWidget {
  const ZingChartScreen({
    super.key,
    this.loadSongs = ZingMP3API.getZingChartSongs,
  });

  final ChartLoader loadSongs;

  @override
  State<ZingChartScreen> createState() => _ZingChartScreenState();
}

class _ZingChartScreenState extends State<ZingChartScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Song> _songs = const [];
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedTab = 0;
  bool _desktopPlayerVisible = true;

  List<Song> _visibleSongs(MusicPlayerController controller) {
    final source = _selectedTab == 2 ? controller.likedSongs : _songs;
    return filterSongs(source, _searchController.text);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadSongs());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSongs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final songs = await widget.loadSongs();
      if (!mounted) return;
      setState(() => _songs = songs);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectSong(Song song, List<Song> queue) {
    final controller = MusicPlayerScope.of(context);
    unawaited(controller.playSong(song, queue: queue));
    if (MediaQuery.sizeOf(context).width >= 1100) {
      if (!_desktopPlayerVisible) {
        setState(() => _desktopPlayerVisible = true);
      }
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MusicPlayerScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final controller = MusicPlayerScope.of(context);
    final visibleSongs = _visibleSongs(controller);
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= 720;
    final showPlayerPanel = width >= 1100 && _desktopPlayerVisible;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () {
          if (!_isEditingText()) unawaited(controller.togglePlayPause());
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _focusSearch,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _focusSearch,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (!_isEditingText()) {
            unawaited(
              controller.seek(
                controller.position - const Duration(seconds: 10),
              ),
            );
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (!_isEditingText()) {
            unawaited(
              controller.seek(
                controller.position + const Duration(seconds: 10),
              ),
            );
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
            controller.previous,
        const SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true):
            controller.previous,
        const SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
            controller.next,
        const SingleActivator(LogicalKeyboardKey.arrowRight, meta: true):
            controller.next,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (width >= 1100 && _desktopPlayerVisible) {
            setState(() => _desktopPlayerVisible = false);
          } else if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          bottomNavigationBar: useRail
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MiniPlayer(),
                    NavigationBar(
                      selectedIndex: _selectedTab,
                      onDestinationSelected: _selectTab,
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home_rounded),
                          label: 'Trang chủ',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.search_rounded),
                          label: 'Tìm kiếm',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.library_music_outlined),
                          selectedIcon: Icon(Icons.library_music_rounded),
                          label: 'Thư viện',
                        ),
                      ],
                    ),
                  ],
                ),
          body: Row(
            children: [
              if (useRail) _buildNavigationRail(),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: _buildContent(controller, visibleSongs)),
                    if (useRail && !showPlayerPanel) const MiniPlayer(),
                  ],
                ),
              ),
              if (showPlayerPanel) const DesktopNowPlayingPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    MusicPlayerController controller,
    List<Song> visibleSongs,
  ) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1B1E), Color(0xFF101113)],
          stops: [0, 0.42],
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSongs,
          color: const Color(0xFFFF6B4A),
          backgroundColor: const Color(0xFF242529),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorState(
                    message: _errorMessage!,
                    onRetry: _loadSongs,
                  ),
                )
              else if (visibleSongs.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
                  sliver: SliverList.separated(
                    itemCount: visibleSongs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 5),
                    itemBuilder: (context, index) {
                      final song = visibleSongs[index];
                      final rank =
                          _songs.indexWhere((item) => item.id == song.id) + 1;
                      return _SongTile(
                        key: ValueKey(song.id),
                        song: song,
                        rank: rank,
                        isLiked: controller.isLiked(song),
                        onLike: () => controller.toggleLike(song),
                        onAddToQueue: () {
                          final didAdd = controller.addToQueue(song);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                didAdd
                                    ? 'Đã thêm ${song.displayTitle} vào hàng đợi'
                                    : '${song.displayTitle} đã ở vị trí tiếp theo',
                              ),
                            ),
                          );
                        },
                        onTap: () => _selectSong(song, visibleSongs),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  NavigationRail _buildNavigationRail() => NavigationRail(
    selectedIndex: _selectedTab,
    onDestinationSelected: _selectTab,
    labelType: NavigationRailLabelType.all,
    backgroundColor: const Color(0xFF151619),
    leading: const Padding(
      padding: EdgeInsets.fromLTRB(8, 20, 8, 26),
      child: Text(
        '#Z',
        style: TextStyle(
          color: Color(0xFFFF6B4A),
          fontSize: 25,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.5,
        ),
      ),
    ),
    trailing: Expanded(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: IconButton(
            tooltip: 'Hiện bảng đang phát',
            onPressed: () => setState(() => _desktopPlayerVisible = true),
            icon: const Icon(Icons.queue_music_rounded),
          ),
        ),
      ),
    ),
    destinations: const [
      NavigationRailDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: Text('Trang chủ'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.search_rounded),
        label: Text('Tìm kiếm'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.library_music_outlined),
        selectedIcon: Icon(Icons.library_music_rounded),
        label: Text('Thư viện'),
      ),
    ],
  );

  void _selectTab(int index) {
    setState(() {
      _selectedTab = index;
      if (index != 1) _searchController.clear();
    });
    if (index == 1) _focusSearch();
  }

  void _focusSearch() {
    if (_selectedTab != 1) setState(() => _selectedTab = 1);
    _searchFocusNode.requestFocus();
  }

  bool _isEditingText() =>
      FocusManager.instance.primaryFocus?.context?.widget is EditableText;

  Widget _buildHeader() {
    final controller = MusicPlayerScope.of(context);
    final titles = ['#zingChart', 'Tìm kiếm', 'Thư viện'];
    final subtitles = [
      'NHỮNG GIAI ĐIỆU ĐANG DẪN ĐẦU',
      'TÌM THEO BÀI HÁT HOẶC NGHỆ SĨ',
      '${controller.likedSongs.length} BÀI HÁT ĐÃ YÊU THÍCH',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titles[_selectedTab],
                      style: const TextStyle(
                        fontSize: 38,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitles[_selectedTab],
                      style: const TextStyle(
                        color: Color(0xFFB8F43D),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedTab == 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x22FF6B4A),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0x66FF6B4A)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LiveDot(),
                      SizedBox(width: 7),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Color(0xFFFF8A70),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            key: const ValueKey('chart-search-field'),
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Tìm bài hát hoặc nghệ sĩ',
              hintText: 'Ví dụ: Quốc Thiên',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                _selectedTab == 2
                    ? 'BÀI HÁT ĐÃ THÍCH'
                    : _searchController.text.isEmpty
                    ? 'TOP 100'
                    : 'KẾT QUẢ',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              if (!_isLoading && _errorMessage == null)
                Text(
                  '${_visibleSongs(controller).length} bài hát',
                  style: const TextStyle(
                    color: Color(0xFF929296),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({
    super.key,
    required this.song,
    required this.rank,
    required this.onTap,
    required this.isLiked,
    required this.onLike,
    required this.onAddToQueue,
  });

  final Song song;
  final int rank;
  final VoidCallback onTap;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onAddToQueue;

  Color get rankColor {
    if (rank == 1) return const Color(0xFFFF6B4A);
    if (rank == 2) return const Color(0xFFB8F43D);
    if (rank == 3) return const Color(0xFF68A7FF);
    return const Color(0xFF6F7075);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: rank <= 3 ? const Color(0xFF1D1E21) : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onSecondaryTapDown: (details) =>
            _showContextMenu(context, details.globalPosition),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              SizedBox(
                width: 38,
                child: Text(
                  rank.toString().padLeft(2, '0'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: rankColor,
                    fontSize: rank <= 3 ? 20 : 15,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AlbumArt(
                imageUrl: song.thumbnail,
                semanticLabel: 'Bìa album ${song.displayTitle}',
                size: 58,
                borderRadius: 15,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      song.artistsNames,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFA4A5A9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: isLiked ? 'Bỏ yêu thích' : 'Yêu thích',
                onPressed: onLike,
                icon: Icon(
                  isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isLiked
                      ? const Color(0xFFFF6B4A)
                      : const Color(0xFFD7D7DA),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Tùy chọn bài hát',
                onSelected: (value) {
                  if (value == 'queue') onAddToQueue();
                  if (value == 'like') onLike();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'queue',
                    child: ListTile(
                      leading: Icon(Icons.playlist_add_rounded),
                      title: Text('Thêm vào hàng đợi'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'like',
                    child: ListTile(
                      leading: Icon(
                        isLiked
                            ? Icons.heart_broken_outlined
                            : Icons.favorite_border_rounded,
                      ),
                      title: Text(isLiked ? 'Bỏ yêu thích' : 'Yêu thích'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(position, position),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: 'play',
          child: ListTile(
            leading: Icon(Icons.play_arrow_rounded),
            title: Text('Phát ngay'),
          ),
        ),
        const PopupMenuItem(
          value: 'queue',
          child: ListTile(
            leading: Icon(Icons.playlist_add_rounded),
            title: Text('Thêm vào hàng đợi'),
          ),
        ),
        PopupMenuItem(
          value: 'like',
          child: ListTile(
            leading: Icon(
              isLiked ? Icons.heart_broken_outlined : Icons.favorite_border,
            ),
            title: Text(isLiked ? 'Bỏ yêu thích' : 'Yêu thích'),
          ),
        ),
      ],
    );
    if (selection == 'play') onTap();
    if (selection == 'queue') onAddToQueue();
    if (selection == 'like') onLike();
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: Color(0xFFFF6B4A),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Color(0xAAFF6B4A), blurRadius: 7)],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 54,
            color: Color(0xFFFF6B4A),
          ),
          const SizedBox(height: 18),
          const Text(
            'Chưa tải được bảng xếp hạng',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFB5B6BA)),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_search_rounded,
              size: 52,
              color: Color(0xFFB8F43D),
            ),
            SizedBox(height: 14),
            Text(
              'Không tìm thấy bài hát phù hợp',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
