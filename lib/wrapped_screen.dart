import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'models/listening_analytics.dart';
import 'music_player_scope.dart';
import 'services/wrapped_export_service.dart';
import 'services/wrapped_image_renderer.dart';
import 'theme/app_theme.dart';

class WrappedScreen extends StatefulWidget {
  const WrappedScreen({
    super.key,
    this.tvMode = false,
    this.exportService,
    this.imageRenderer,
  });

  final bool tvMode;
  final WrappedExportService? exportService;
  final WrappedImageRenderer? imageRenderer;

  @override
  State<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends State<WrappedScreen> {
  late final PageController _pageController;
  late final WrappedExportService _exportService;
  late final WrappedImageRenderer _imageRenderer;
  int _year = DateTime.now().year;
  int _page = 0;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _exportService = widget.exportService ?? createWrappedExportService();
    _imageRenderer = widget.imageRenderer ?? const CanvasWrappedImageRenderer();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = MusicPlayerScope.of(context);
    final summary = controller.wrappedSummary(_year);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _previousPage,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _nextPage,
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: ZingColors.ink,
          appBar: AppBar(
            foregroundColor: ZingColors.paper,
            title: const Text('Mini Wrapped'),
            actions: [
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _year,
                  dropdownColor: ZingColors.panel,
                  style: const TextStyle(
                    color: ZingColors.paper,
                    fontWeight: FontWeight.w800,
                  ),
                  items: [DateTime.now().year, DateTime.now().year - 1]
                      .map(
                        (year) =>
                            DropdownMenuItem(value: year, child: Text('$year')),
                      )
                      .toList(),
                  onChanged: (year) {
                    if (year == null) return;
                    setState(() {
                      _year = year;
                      _page = 0;
                    });
                    _pageController.jumpToPage(0);
                  },
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: summary.hasData
              ? _buildWrapped(context, summary)
              : _WrappedEmpty(year: _year),
        ),
      ),
    );
  }

  Widget _buildWrapped(
    BuildContext context,
    WrappedSummary summary,
  ) => SafeArea(
    child: Column(
      children: [
        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 32).clamp(280.0, 620.0);
                final height = (constraints.maxHeight - 16).clamp(360.0, 760.0);
                final cardWidth = width < height * 0.8 ? width : height * 0.8;
                return SizedBox(
                  width: cardWidth,
                  height: cardWidth * 1.25,
                  child: PageView.builder(
                    key: const ValueKey('wrapped-page-view'),
                    controller: _pageController,
                    itemCount: 6,
                    onPageChanged: (page) => setState(() => _page = page),
                    itemBuilder: (_, index) => _WrappedSlide(
                      key: ValueKey('wrapped-slide-$index'),
                      index: index,
                      summary: summary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: 'Trang trước',
                onPressed: _page == 0 ? null : _previousPage,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 12),
              Text(
                '${_page + 1} / 6',
                style: const TextStyle(
                  color: ZingColors.paper,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: 'Trang sau',
                onPressed: _page == 5 ? null : _nextPage,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              const SizedBox(width: 20),
              FilledButton.icon(
                key: const ValueKey('wrapped-export-button'),
                onPressed: _isExporting
                    ? null
                    : widget.tvMode
                    ? () => _showShareCode(summary)
                    : () => _exportCurrentSlide(summary),
                style: FilledButton.styleFrom(
                  backgroundColor: ZingColors.lime,
                  foregroundColor: ZingColors.ink,
                  minimumSize: const Size(136, 48),
                ),
                icon: _isExporting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        widget.tvMode
                            ? Icons.qr_code_2_rounded
                            : Icons.share_rounded,
                      ),
                label: Text(widget.tvMode ? 'Mã chia sẻ' : 'Xuất ảnh'),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _exportCurrentSlide(WrappedSummary summary) async {
    setState(() => _isExporting = true);
    try {
      final bytes = await _imageRenderer.render(summary, _page);
      final result = await _exportService.exportPng(
        bytes,
        fileName: 'zingchart-wrapped-${summary.year}-${_page + 1}.png',
        title: '#zingChart Wrapped ${summary.year}',
      );
      if (!mounted) return;
      if (result == WrappedExportResult.unavailable) {
        await _showShareCode(summary);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result == WrappedExportResult.saved
                  ? 'Đã lưu ảnh Wrapped'
                  : 'Đã mở chia sẻ Wrapped',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) await _showShareCode(summary);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _showShareCode(WrappedSummary summary) async {
    final payload = _payload(summary);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Mã Wrapped ${summary.year}'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(
                  key: const ValueKey('wrapped-share-qr'),
                  data: payload.encode(),
                  version: QrVersions.auto,
                  size: 240,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: ZingColors.ink,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: ZingColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${payload.minutes} phút · ${payload.qualifiedPlays} lượt\n'
                '${payload.topSong} · ${payload.topArtist}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'QR chỉ chứa bản tóm tắt đã chọn, không tải dữ liệu lên máy chủ.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
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
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: payload.encode()));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Sao chép mã'),
          ),
        ],
      ),
    );
  }

  WrappedSharePayload _payload(WrappedSummary summary) => WrappedSharePayload(
    year: summary.year,
    minutes: summary.listened.inMinutes,
    qualifiedPlays: summary.qualifiedPlays,
    topSong: summary.topSongs.firstOrNull?.song.displayTitle ?? '',
    topArtist: summary.topArtists.firstOrNull?.artist ?? '',
  );

  void _previousPage() {
    if (_page == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _nextPage() {
    if (_page == 5) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }
}

class _WrappedSlide extends StatelessWidget {
  const _WrappedSlide({super.key, required this.index, required this.summary});

  final int index;
  final WrappedSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = _slideColors[index];
    return Semantics(
      label: 'Wrapped trang ${index + 1} trên 6',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: -50,
              bottom: -60,
              child: Icon(
                _slideIcon(index),
                size: 260,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '#zingChart',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${summary.year} / 0${index + 1}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ..._slideContent(index, summary),
                  const Spacer(),
                  const Text(
                    'LOCAL-FIRST · CHỈ TRÊN THIẾT BỊ NÀY',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<Widget> _slideContent(int index, WrappedSummary summary) {
  final headline = const TextStyle(
    color: Colors.white,
    fontSize: 54,
    height: 0.92,
    fontWeight: FontWeight.w900,
    letterSpacing: -3,
  );
  final label = const TextStyle(
    color: Colors.white,
    fontSize: 18,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );
  switch (index) {
    case 0:
      return [
        Text('${summary.listened.inMinutes}', style: headline),
        const SizedBox(height: 12),
        Text('phút âm nhạc đã ở bên bạn.', style: label),
      ];
    case 1:
      return [
        Text('${summary.qualifiedPlays}', style: headline),
        const SizedBox(height: 12),
        Text(
          'lượt nghe hợp lệ · ${(summary.completionRate * 100).round()}% đi đến cuối bài.',
          style: label,
        ),
      ];
    case 2:
      final song = summary.topSongs.firstOrNull?.song;
      return [
        const Text('BÀI HÁT SỐ 1', style: _eyebrowStyle),
        const SizedBox(height: 14),
        Text(song?.displayTitle ?? 'Chưa có', style: headline),
        const SizedBox(height: 12),
        Text(song?.artistsNames ?? '', style: label),
      ];
    case 3:
      final artist = summary.topArtists.firstOrNull;
      return [
        const Text('NGHỆ SĨ CỦA NĂM', style: _eyebrowStyle),
        const SizedBox(height: 14),
        Text(artist?.artist ?? 'Chưa có', style: headline),
        const SizedBox(height: 12),
        Text('${artist?.listened.inMinutes ?? 0} phút đã nghe', style: label),
      ];
    case 4:
      return [
        const Text('TOP 5 CỦA BẠN', style: _eyebrowStyle),
        const SizedBox(height: 16),
        ...summary.topSongs.indexed.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Text(
              '${entry.$1 + 1}. ${entry.$2.song.displayTitle}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ];
    default:
      final day = summary.busiestDay;
      return [
        const Text('DẤU ẤN LOCAL', style: _eyebrowStyle),
        const SizedBox(height: 14),
        Text(
          day == null ? 'Gu riêng.' : '${day.day}.${day.month}',
          style: headline,
        ),
        const SizedBox(height: 12),
        Text(
          day == null
              ? 'Không cần tài khoản để âm nhạc mang dấu ấn của bạn.'
              : 'Ngày bạn nghe nhiều nhất. Không server nào cần biết điều đó.',
          style: label,
        ),
      ];
  }
}

class _WrappedEmpty extends StatelessWidget {
  const _WrappedEmpty({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: ZingColors.lime,
            size: 76,
          ),
          const SizedBox(height: 18),
          Text(
            'Wrapped $year đang chờ bạn',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ZingColors.paper,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Hãy nghe nhạc thêm để tạo sáu khung hình hoàn toàn từ dữ liệu local.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    ),
  );
}

const _eyebrowStyle = TextStyle(
  color: ZingColors.lime,
  fontSize: 12,
  fontWeight: FontWeight.w900,
  letterSpacing: 1.8,
);

const _slideColors = <List<Color>>[
  [Color(0xFFFF6B4A), Color(0xFF7A251F)],
  [Color(0xFF355D85), Color(0xFF17263A)],
  [Color(0xFF476500), Color(0xFF17230C)],
  [Color(0xFF8B3E78), Color(0xFF30172B)],
  [Color(0xFFBA4C20), Color(0xFF32160E)],
  [Color(0xFF323531), Color(0xFF101113)],
];

IconData _slideIcon(int index) => switch (index) {
  0 => Icons.schedule_rounded,
  1 => Icons.graphic_eq_rounded,
  2 => Icons.music_note_rounded,
  3 => Icons.mic_external_on_rounded,
  4 => Icons.format_list_numbered_rounded,
  _ => Icons.fingerprint_rounded,
};
