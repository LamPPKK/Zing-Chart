import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'analytics_dashboard_screen.dart';
import 'models/local_library.dart';
import 'models/listening_analytics.dart';
import 'models/song.dart';
import 'music_player_controller.dart';
import 'music_player_scope.dart';
import 'music_player_screen.dart';
import 'platform/tv_exit.dart';
import 'services/library_backup_file_service.dart';
import 'theme/app_theme.dart';
import 'widgets/album_art.dart';
import 'widgets/desktop_now_playing_panel.dart';
import 'widgets/editorial_discovery.dart';
import 'widgets/for_you_hub.dart';
import 'widgets/library_hub.dart';
import 'widgets/mini_player.dart';
import 'wrapped_screen.dart';
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
    this.tvMode = false,
    this.backupFileService,
  });

  final ChartLoader loadSongs;
  final bool tvMode;
  final LibraryBackupFileService? backupFileService;

  @override
  State<ZingChartScreen> createState() => _ZingChartScreenState();
}

class _ZingChartScreenState extends State<ZingChartScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late final LibraryBackupFileService _backupFileService;
  List<Song> _songs = const [];
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedTab = 0;
  bool _desktopPlayerVisible = true;
  String? _selectedPlaylistId;

  List<Song> _visibleSongs(MusicPlayerController controller) {
    final source = _selectedTab == 3
        ? _selectedPlaylist(controller)?.songs ?? controller.likedSongs
        : _songs;
    return filterSongs(source, _searchController.text);
  }

  LocalPlaylist? _selectedPlaylist(MusicPlayerController controller) {
    final id = _selectedPlaylistId;
    if (id == null) return null;
    for (final playlist in controller.playlists) {
      if (playlist.id == id) return playlist;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _backupFileService =
        widget.backupFileService ?? createLibraryBackupFileService();
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
      MusicPlayerScope.of(context).updateCatalog(songs);
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
    if (widget.tvMode || MediaQuery.sizeOf(context).width >= 1100) {
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
    final useRail = widget.tvMode || width >= 720;
    final showPlayerPanel =
        widget.tvMode || (width >= 1100 && _desktopPlayerVisible);

    return CallbackShortcuts(
      bindings: _shortcutBindings(controller, width),
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Focus(
          autofocus: !widget.tvMode,
          child: PopScope<void>(
            canPop:
                !widget.tvMode ||
                (_selectedTab == 0 && !_searchFocusNode.hasFocus),
            onPopInvokedWithResult: (didPop, _) {
              if (widget.tvMode && !didPop) _handleBack(width);
            },
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
                              icon: Icon(Icons.auto_awesome_outlined),
                              selectedIcon: Icon(Icons.auto_awesome_rounded),
                              label: 'Dành cho bạn',
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
                  if (useRail) _buildNavigationRail(tvMode: widget.tvMode),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: _buildContent(controller, visibleSongs),
                        ),
                        if (useRail && !showPlayerPanel) const MiniPlayer(),
                      ],
                    ),
                  ),
                  if (showPlayerPanel)
                    DesktopNowPlayingPanel(tvMode: widget.tvMode),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _shortcutBindings(
    MusicPlayerController controller,
    double width,
  ) {
    final bindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.space): () {
        if (!_isEditingText()) unawaited(controller.togglePlayPause());
      },
      const SingleActivator(LogicalKeyboardKey.keyF, control: true):
          _focusSearch,
      const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _focusSearch,
      const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
          controller.previous,
      const SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true):
          controller.previous,
      const SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
          controller.next,
      const SingleActivator(LogicalKeyboardKey.arrowRight, meta: true):
          controller.next,
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          _handleBack(width),
      const SingleActivator(LogicalKeyboardKey.mediaPlayPause):
          controller.togglePlayPause,
      const SingleActivator(LogicalKeyboardKey.mediaPlay): () {
        if (!controller.isPlaying) unawaited(controller.togglePlayPause());
      },
      const SingleActivator(LogicalKeyboardKey.mediaPause): () {
        if (controller.isPlaying) unawaited(controller.togglePlayPause());
      },
      const SingleActivator(LogicalKeyboardKey.mediaStop): controller.stop,
      const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious):
          controller.previous,
      const SingleActivator(LogicalKeyboardKey.mediaTrackNext): controller.next,
      const SingleActivator(LogicalKeyboardKey.mediaRewind): () =>
          unawaited(_seekBy(controller, -10)),
      const SingleActivator(LogicalKeyboardKey.mediaFastForward): () =>
          unawaited(_seekBy(controller, 10)),
    };
    if (!widget.tvMode) {
      bindings
        ..[const SingleActivator(LogicalKeyboardKey.arrowLeft)] = () {
          if (!_isEditingText()) unawaited(_seekBy(controller, -10));
        }
        ..[const SingleActivator(LogicalKeyboardKey.arrowRight)] = () {
          if (!_isEditingText()) unawaited(_seekBy(controller, 10));
        };
    }
    return bindings;
  }

  void _handleBack(double width) {
    if (widget.tvMode) {
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus(
          disposition: UnfocusDisposition.previouslyFocusedChild,
        );
      } else if (_selectedTab != 0) {
        _selectTab(0);
      } else {
        if (!requestTvPlatformExit()) unawaited(SystemNavigator.pop());
      }
      return;
    }
    if (width >= 1100 && _desktopPlayerVisible) {
      setState(() => _desktopPlayerVisible = false);
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _seekBy(MusicPlayerController controller, int seconds) =>
      controller.seek(controller.position + Duration(seconds: seconds));

  Widget _buildContent(
    MusicPlayerController controller,
    List<Song> visibleSongs,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF1A1B1E), ZingColors.ink]
              : const [Color(0xFFFFFBF4), ZingColors.paper],
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
              if (_selectedTab == 2)
                SliverToBoxAdapter(
                  child: ForYouHub(
                    controller: controller,
                    onPlaySongs: (songs) {
                      if (songs.isNotEmpty) _selectSong(songs.first, songs);
                    },
                    onOpenAnalytics: _openAnalytics,
                    onOpenWrapped: _openWrapped,
                  ),
                )
              else if (_selectedTab == 3)
                SliverToBoxAdapter(
                  child: LibraryHub(
                    controller: controller,
                    selectedPlaylistId: _selectedPlaylistId,
                    onSelectPlaylist: (playlistId) => setState(() {
                      _selectedPlaylistId = playlistId;
                      _searchController.clear();
                    }),
                    onCreatePlaylist: () => _showCreatePlaylist(controller),
                    onRenamePlaylist: (playlist) =>
                        _showRenamePlaylist(controller, playlist),
                    onDeletePlaylist: (playlist) =>
                        _confirmDeletePlaylist(controller, playlist),
                    onPlaySongs: (songs) {
                      if (songs.isNotEmpty) _selectSong(songs.first, songs);
                    },
                    onExportBackup: () => _exportBackupFile(controller),
                    onImportBackup: () => _importBackupFile(controller),
                    onOpenAnalytics: _openAnalytics,
                    onOpenWrapped: _openWrapped,
                  ),
                )
              else if (!_isLoading &&
                  _errorMessage == null &&
                  _selectedTab == 0 &&
                  _searchController.text.isEmpty)
                SliverToBoxAdapter(
                  child: EditorialDiscovery(
                    songs: _songs,
                    controller: controller,
                    onPlay: _selectSong,
                  ),
                ),
              if (_selectedTab < 2 && _isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_selectedTab < 2 && _errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorState(
                    message: _errorMessage!,
                    onRetry: _loadSongs,
                  ),
                )
              else if (_selectedTab != 2 && visibleSongs.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 46),
                    child: _EmptyState(
                      message: _selectedTab == 3
                          ? _selectedPlaylist(controller) == null
                                ? 'Thư viện yêu thích đang trống'
                                : 'Playlist này chưa có bài hát'
                          : 'Không tìm thấy bài hát phù hợp',
                    ),
                  ),
                )
              else if (_selectedTab != 2)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    widget.tvMode ? 28 : 12,
                    4,
                    widget.tvMode ? 28 : 12,
                    widget.tvMode ? 48 : 28,
                  ),
                  sliver: widget.tvMode
                      ? SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount:
                                    MediaQuery.sizeOf(context).width >= 1500
                                    ? 2
                                    : 1,
                                mainAxisExtent: 104,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: visibleSongs.length,
                          itemBuilder: (context, index) => _buildSongTile(
                            controller,
                            visibleSongs,
                            index,
                            tvMode: true,
                          ),
                        )
                      : SliverList.separated(
                          itemCount: visibleSongs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 5),
                          itemBuilder: (context, index) =>
                              _buildSongTile(controller, visibleSongs, index),
                        ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.paddingOf(context).bottom + 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongTile(
    MusicPlayerController controller,
    List<Song> visibleSongs,
    int index, {
    bool tvMode = false,
  }) {
    final song = visibleSongs[index];
    final chartIndex = _songs.indexWhere((item) => item.id == song.id);
    final rank = chartIndex >= 0 ? chartIndex + 1 : index + 1;
    void addToQueue() {
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
    }

    final tile = _SongTile(
      key: ValueKey(song.id),
      song: song,
      rank: rank,
      isLiked: controller.isLiked(song),
      moods: controller.moodsFor(song),
      onLike: () => controller.toggleLike(song),
      onToggleMood: (mood) => controller.toggleMood(song, mood),
      onAddToQueue: addToQueue,
      onAddToPlaylist: () => _showPlaylistPicker(controller, song),
      onTap: () => _selectSong(song, visibleSongs),
      tvMode: tvMode,
      autofocus: tvMode && index == 0,
    );
    if (tvMode) return tile;
    return Dismissible(
      key: ValueKey('swipe-queue-${song.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        addToQueue();
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        decoration: BoxDecoration(
          color: ZingColors.lime.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            Icon(Icons.playlist_add_rounded, color: ZingColors.lime),
            SizedBox(width: 8),
            Text(
              'THÊM VÀO HÀNG ĐỢI',
              style: TextStyle(
                color: ZingColors.lime,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
      child: tile,
    );
  }

  NavigationRail _buildNavigationRail({required bool tvMode}) => NavigationRail(
    selectedIndex: _selectedTab,
    onDestinationSelected: _selectTab,
    extended: tvMode,
    minWidth: tvMode ? 96 : 72,
    minExtendedWidth: tvMode ? 220 : 256,
    labelType: tvMode
        ? NavigationRailLabelType.none
        : NavigationRailLabelType.all,
    backgroundColor: Theme.of(context).colorScheme.surface,
    leading: Padding(
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 26),
      child: Text(
        '#Z',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 25,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.5,
        ),
      ),
    ),
    trailing: tvMode
        ? null
        : Expanded(
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
        icon: Icon(Icons.auto_awesome_outlined),
        selectedIcon: Icon(Icons.auto_awesome_rounded),
        label: Text('Dành cho bạn'),
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

  void _openAnalytics() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AnalyticsDashboardScreen()),
    );
  }

  void _openWrapped() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WrappedScreen(tvMode: widget.tvMode),
      ),
    );
  }

  Future<void> _showCreatePlaylist(MusicPlayerController controller) async {
    final name = await _promptPlaylistName(title: 'Tạo playlist mới');
    if (name == null) return;
    try {
      final playlist = controller.createPlaylist(name);
      if (mounted) setState(() => _selectedPlaylistId = playlist.id);
    } on ArgumentError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    }
  }

  Future<void> _showRenamePlaylist(
    MusicPlayerController controller,
    LocalPlaylist playlist,
  ) async {
    final name = await _promptPlaylistName(
      title: 'Đổi tên playlist',
      initialValue: playlist.name,
    );
    if (name != null) controller.renamePlaylist(playlist.id, name);
  }

  Future<String?> _promptPlaylistName({
    required String title,
    String initialValue = '',
  }) => showDialog<String>(
    context: context,
    builder: (_) =>
        _PlaylistNameDialog(title: title, initialValue: initialValue),
  );

  Future<void> _confirmDeletePlaylist(
    MusicPlayerController controller,
    LocalPlaylist playlist,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa playlist?'),
        content: Text(
          '“${playlist.name}” sẽ bị xóa khỏi thiết bị. Bài hát gốc không bị ảnh hưởng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    controller.deletePlaylist(playlist.id);
    if (mounted && _selectedPlaylistId == playlist.id) {
      setState(() => _selectedPlaylistId = null);
    }
  }

  Future<void> _showPlaylistPicker(
    MusicPlayerController controller,
    Song song,
  ) async {
    if (controller.playlists.isEmpty) {
      await _showCreatePlaylist(controller);
    }
    if (!mounted || controller.playlists.isEmpty) return;
    final playlistId = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          children: [
            const ListTile(
              title: Text(
                'Thêm vào playlist',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ),
            ...controller.playlists.map(
              (playlist) => ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: Text(playlist.name),
                subtitle: Text('${playlist.songs.length} bài hát'),
                trailing: playlist.songs.any((item) => item.id == song.id)
                    ? const Icon(Icons.check_rounded, color: ZingColors.lime)
                    : null,
                onTap: () => Navigator.pop(sheetContext, playlist.id),
              ),
            ),
          ],
        ),
      ),
    );
    if (playlistId == null || !mounted) return;
    final added = controller.addSongToPlaylist(playlistId, song);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? 'Đã thêm ${song.displayTitle} vào playlist'
              : '${song.displayTitle} đã có trong playlist',
        ),
      ),
    );
  }

  Future<void> _showExportBackup(MusicPlayerController controller) async {
    final json = controller.exportLibraryJson();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Backup thư viện JSON'),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sao chép nội dung này vào file có đuôi .json. File không chứa nhạc hoặc URL stream.',
              ),
              const SizedBox(height: 14),
              Container(
                constraints: const BoxConstraints(maxHeight: 260),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    json,
                    key: const ValueKey('backup-json-content'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Đóng'),
          ),
          FilledButton.icon(
            key: const ValueKey('copy-backup-json-button'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép backup JSON')),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Sao chép JSON'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackupFile(MusicPlayerController controller) async {
    final json = controller.exportLibraryJson();
    final date = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    try {
      final exported = await _backupFileService.exportJson(
        json,
        fileName: 'zingchart-library-$date.json',
      );
      if (exported && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xuất backup thư viện')),
        );
      }
    } catch (_) {
      if (mounted) await _showExportBackup(controller);
    }
  }

  Future<void> _importBackupFile(MusicPlayerController controller) async {
    try {
      final json = await _backupFileService.importJson();
      if (json != null && mounted) {
        await _showImportBackup(controller, initialJson: json);
      }
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    } catch (_) {
      if (mounted) await _showImportBackup(controller);
    }
  }

  Future<void> _showImportBackup(
    MusicPlayerController controller, {
    String initialJson = '',
  }) async {
    final restored = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _ImportBackupDialog(controller: controller, initialJson: initialJson),
    );
    if (restored == true && mounted) {
      setState(() => _selectedPlaylistId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã khôi phục thư viện local')),
      );
    }
  }

  Widget _buildHeader() {
    final controller = MusicPlayerScope.of(context);
    final selectedPlaylist = _selectedPlaylist(controller);
    final titles = [
      '#zingChart',
      'Tìm kiếm',
      'Dành cho bạn',
      selectedPlaylist?.name ?? 'Thư viện',
    ];
    final subtitles = [
      'BẢNG XẾP HẠNG · CẬP NHẬT THEO THỜI GIAN THỰC',
      'TÊN BÀI HÁT · NGHỆ SĨ · TỪ KHÓA',
      'DAILY MIX · MOOD MIX · WRAPPED LOCAL',
      selectedPlaylist == null
          ? '${controller.likedSongs.length} BÀI THÍCH · ${controller.playlists.length} PLAYLIST'
          : '${selectedPlaylist.songs.length} BÀI HÁT · LƯU TRÊN THIẾT BỊ',
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.tvMode ? 32 : 20,
        widget.tvMode ? 34 : 20,
        widget.tvMode ? 32 : 20,
        widget.tvMode ? 24 : 18,
      ),
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
                      style: TextStyle(
                        fontSize: widget.tvMode ? 48 : 42,
                        height: 0.96,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitles[_selectedTab],
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontSize: widget.tvMode ? 14 : 11,
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
          if (_selectedTab != 2) ...[
            SizedBox(height: widget.tvMode ? 30 : 24),
            TextField(
              key: const ValueKey('chart-search-field'),
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (_) => setState(() {}),
              onSubmitted: controller.recordSearch,
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: widget.tvMode ? 20 : 16),
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
            if (_selectedTab == 1 &&
                _searchController.text.isEmpty &&
                controller.recentSearches.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: controller.recentSearches
                          .map(
                            (query) => ActionChip(
                              avatar: const Icon(
                                Icons.history_rounded,
                                size: 17,
                              ),
                              label: Text(query),
                              onPressed: () {
                                _searchController.text = query;
                                controller.recordSearch(query);
                                setState(() {});
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Xóa tìm kiếm gần đây',
                    onPressed: controller.clearRecentSearches,
                    icon: const Icon(Icons.delete_sweep_outlined),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  _selectedTab == 3
                      ? selectedPlaylist?.name.toUpperCase() ??
                            'BÀI HÁT ĐÃ THÍCH'
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SongTile extends StatefulWidget {
  const _SongTile({
    super.key,
    required this.song,
    required this.rank,
    required this.onTap,
    required this.isLiked,
    required this.moods,
    required this.onLike,
    required this.onToggleMood,
    required this.onAddToQueue,
    required this.onAddToPlaylist,
    this.tvMode = false,
    this.autofocus = false,
  });

  final Song song;
  final int rank;
  final VoidCallback onTap;
  final bool isLiked;
  final Set<MoodTag> moods;
  final VoidCallback onLike;
  final ValueChanged<MoodTag> onToggleMood;
  final VoidCallback onAddToQueue;
  final VoidCallback onAddToPlaylist;
  final bool tvMode;
  final bool autofocus;

  @override
  State<_SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<_SongTile> {
  bool _focused = false;

  Color get rankColor {
    if (widget.rank == 1) return const Color(0xFFFF6B4A);
    if (widget.rank == 2) return const Color(0xFFB8F43D);
    if (widget.rank == 3) return const Color(0xFF68A7FF);
    return const Color(0xFF6F7075);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.tvMode ? 20 : 18);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: _focused ? const Color(0xFFFF6B4A) : Colors.transparent,
          width: widget.tvMode ? 3 : 2,
        ),
        boxShadow: _focused
            ? const [
                BoxShadow(
                  color: Color(0x55FF6B4A),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: Material(
        color: _focused
            ? scheme.primaryContainer
            : widget.rank <= 3
            ? scheme.surfaceContainer
            : theme.cardColor,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          autofocus: widget.autofocus,
          onFocusChange: (focused) {
            if (_focused != focused) setState(() => _focused = focused);
          },
          onTap: widget.onTap,
          onSecondaryTapDown: (details) =>
              _showContextMenu(context, details.globalPosition),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.tvMode ? 14 : 10,
              vertical: widget.tvMode ? 11 : 9,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: widget.tvMode ? 46 : 38,
                  child: Text(
                    widget.rank.toString().padLeft(2, '0'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: rankColor,
                      fontSize: widget.tvMode
                          ? (widget.rank <= 3 ? 24 : 19)
                          : (widget.rank <= 3 ? 20 : 15),
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AlbumArt(
                  imageUrl: widget.song.thumbnail,
                  semanticLabel: 'Bìa album ${widget.song.displayTitle}',
                  size: widget.tvMode ? 76 : 58,
                  borderRadius: widget.tvMode ? 17 : 15,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.song.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: widget.tvMode ? 18 : 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.song.artistsNames,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: widget.tvMode ? 15 : 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: widget.isLiked ? 'Bỏ yêu thích' : 'Yêu thích',
                  onPressed: widget.onLike,
                  icon: Icon(
                    widget.isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: widget.isLiked
                        ? const Color(0xFFFF6B4A)
                        : scheme.onSurfaceVariant,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Tùy chọn bài hát',
                  onSelected: _handleSelection,
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'queue',
                      child: ListTile(
                        leading: Icon(Icons.playlist_add_rounded),
                        title: Text('Thêm vào hàng đợi'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'playlist',
                      child: ListTile(
                        leading: Icon(Icons.library_add_rounded),
                        title: Text('Thêm vào playlist'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'like',
                      child: ListTile(
                        leading: Icon(
                          widget.isLiked
                              ? Icons.heart_broken_outlined
                              : Icons.favorite_border_rounded,
                        ),
                        title: Text(
                          widget.isLiked ? 'Bỏ yêu thích' : 'Yêu thích',
                        ),
                      ),
                    ),
                    ...MoodTag.values.map(_moodMenuItem),
                  ],
                ),
              ],
            ),
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
        const PopupMenuItem(
          value: 'playlist',
          child: ListTile(
            leading: Icon(Icons.library_add_rounded),
            title: Text('Thêm vào playlist'),
          ),
        ),
        PopupMenuItem(
          value: 'like',
          child: ListTile(
            leading: Icon(
              widget.isLiked
                  ? Icons.heart_broken_outlined
                  : Icons.favorite_border,
            ),
            title: Text(widget.isLiked ? 'Bỏ yêu thích' : 'Yêu thích'),
          ),
        ),
        ...MoodTag.values.map(_moodMenuItem),
      ],
    );
    if (selection != null) _handleSelection(selection);
  }

  PopupMenuItem<String> _moodMenuItem(MoodTag mood) => PopupMenuItem(
    value: 'mood-${mood.name}',
    child: ListTile(
      leading: Icon(
        widget.moods.contains(mood)
            ? Icons.check_circle_rounded
            : _moodIcon(mood),
        color: widget.moods.contains(mood) ? ZingColors.lime : null,
      ),
      title: Text(
        '${widget.moods.contains(mood) ? 'Bỏ' : 'Gắn'} mood ${_moodLabel(mood)}',
      ),
    ),
  );

  void _handleSelection(String value) {
    if (value == 'play') widget.onTap();
    if (value == 'queue') widget.onAddToQueue();
    if (value == 'playlist') widget.onAddToPlaylist();
    if (value == 'like') widget.onLike();
    for (final mood in MoodTag.values) {
      if (value == 'mood-${mood.name}') widget.onToggleMood(mood);
    }
  }
}

String _moodLabel(MoodTag mood) => switch (mood) {
  MoodTag.chill => 'Chill',
  MoodTag.gym => 'Gym',
  MoodTag.focus => 'Tập trung',
};

IconData _moodIcon(MoodTag mood) => switch (mood) {
  MoodTag.chill => Icons.water_rounded,
  MoodTag.gym => Icons.bolt_rounded,
  MoodTag.focus => Icons.center_focus_strong_rounded,
};

class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog({required this.title, required this.initialValue});

  final String title;
  final String initialValue;

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _save() {
    final value = _textController.text.trim();
    if (value.isNotEmpty) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      key: const ValueKey('playlist-name-field'),
      controller: _textController,
      autofocus: true,
      maxLength: 60,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(labelText: 'Tên playlist'),
      onSubmitted: (_) => _save(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(onPressed: _save, child: const Text('Lưu')),
    ],
  );
}

class _ImportBackupDialog extends StatefulWidget {
  const _ImportBackupDialog({
    required this.controller,
    required this.initialJson,
  });

  final MusicPlayerController controller;
  final String initialJson;

  @override
  State<_ImportBackupDialog> createState() => _ImportBackupDialogState();
}

class _ImportBackupDialogState extends State<_ImportBackupDialog> {
  late final TextEditingController _textController;
  var _mode = BackupImportMode.merge;
  var _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialJson);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    if (_isRestoring) return;
    setState(() => _isRestoring = true);
    try {
      await widget.controller.importLibraryJson(_textController.text, _mode);
      if (mounted) Navigator.pop(context, true);
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _isRestoring = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isRestoring = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể khôi phục file này. Vui lòng thử lại.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Khôi phục thư viện'),
    content: SizedBox(
      width: 620,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<BackupImportMode>(
            segments: const [
              ButtonSegment(
                value: BackupImportMode.merge,
                icon: Icon(Icons.merge_rounded),
                label: Text('Hợp nhất'),
              ),
              ButtonSegment(
                value: BackupImportMode.overwrite,
                icon: Icon(Icons.sync_problem_rounded),
                label: Text('Ghi đè'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: _isRestoring
                ? null
                : (selection) => setState(() => _mode = selection.single),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('import-backup-json-field'),
            controller: _textController,
            enabled: !_isRestoring,
            minLines: 7,
            maxLines: 12,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            decoration: const InputDecoration(
              labelText: 'Dán nội dung file .json',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _isRestoring ? null : () => Navigator.pop(context, false),
        child: const Text('Hủy'),
      ),
      FilledButton(
        key: const ValueKey('confirm-import-backup-button'),
        onPressed: _isRestoring ? null : _restore,
        child: _isRestoring
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Khôi phục'),
      ),
    ],
  );
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
  const _EmptyState({this.message = 'Không tìm thấy bài hát phù hợp'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.manage_search_rounded,
              size: 52,
              color: Color(0xFFB8F43D),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
