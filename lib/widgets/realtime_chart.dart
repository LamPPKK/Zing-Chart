import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/chart_snapshot.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';

class RealtimeChart extends StatefulWidget {
  const RealtimeChart({
    super.key,
    required this.snapshot,
    required this.onPlay,
    this.autofocus = false,
    this.compact = false,
    this.refreshing = false,
    this.refreshFailed = false,
    this.onRetry,
  });

  final ChartSnapshot snapshot;
  final void Function(Song song, List<Song> queue) onPlay;
  final bool autofocus;
  final bool compact;
  final bool refreshing;
  final bool refreshFailed;
  final VoidCallback? onRetry;

  static const lineColors = [
    Color(0xFF4A90E2),
    Color(0xFF27C9A0),
    Color(0xFFE35050),
  ];

  static List<Song> visibleSongs(ChartSnapshot snapshot) =>
      _ChartData.fromSnapshot(snapshot).songs;

  @override
  State<RealtimeChart> createState() => _RealtimeChartState();

  static String _clock(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _RealtimeChartState extends State<RealtimeChart> {
  late final FocusNode _plotFocusNode = FocusNode(
    debugLabel: 'realtime-chart-focus',
  );
  int? _activeTimeIndex;
  int _activeSongIndex = 0;
  bool _hovering = false;
  bool _pinned = false;
  late _ChartData _data;

  List<Song> get _songs => _data.songs;

  int get _timelineLength => _data.timeline.length;

  @override
  void initState() {
    super.initState();
    _data = _ChartData.fromSnapshot(widget.snapshot);
  }

  @override
  void didUpdateWidget(covariant RealtimeChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.snapshot, widget.snapshot)) {
      _data = _ChartData.fromSnapshot(widget.snapshot);
    }
    final length = _timelineLength;
    if (length == 0) {
      _activeTimeIndex = null;
      _activeSongIndex = 0;
      return;
    }
    if (_activeTimeIndex case final active?) {
      _activeTimeIndex = active.clamp(0, length - 1);
      _activeSongIndex = _songIndexAvailableAt(
        _activeSongIndex,
        _activeTimeIndex!,
      );
    }
    if (_activeSongIndex >= _songs.length) _activeSongIndex = 0;
  }

  @override
  void dispose() {
    _plotFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songs = _songs;
    if (songs.isEmpty) return const SizedBox.shrink();

    if (widget.compact) {
      return Semantics(
        container: true,
        label: 'Biểu đồ #zingchart 24 giờ của ${songs.length} bài dẫn đầu',
        child: LayoutBuilder(
          builder: (context, constraints) => _buildPlot(
            constraints,
            songs,
            heightOverride: constraints.maxWidth < 620 ? 176 : 224,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
      child: Semantics(
        container: true,
        label: 'Biểu đồ #zingchart realtime của ${songs.length} bài dẫn đầu',
        child: Container(
          key: const ValueKey('realtime-chart'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: _ChartAtmosphere()),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.show_chart_rounded,
                          color: ZingColors.purple,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'NHỊP BXH 24 GIỜ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        if (widget.refreshing) ...[
                          const SizedBox.square(
                            key: ValueKey('chart-refreshing'),
                            dimension: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              semanticsLabel: 'Đang cập nhật bảng xếp hạng',
                            ),
                          ),
                          const SizedBox(width: 8),
                        ] else if (widget.refreshFailed) ...[
                          IconButton(
                            key: const ValueKey('chart-refresh-retry'),
                            tooltip: 'Cập nhật gián đoạn · thử lại',
                            onPressed: widget.onRetry,
                            iconSize: 18,
                            color: ZingColors.coral,
                            icon: const Icon(Icons.sync_problem_rounded),
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (widget.snapshot.updatedAt case final updatedAt?)
                          Text(
                            'Cập nhật ${RealtimeChart._clock(updatedAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ChartLegend(
                      songs: songs,
                      data: _data,
                      colors: RealtimeChart.lineColors,
                      onPlay: (song) =>
                          widget.onPlay(song, widget.snapshot.songs),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) =>
                          _buildPlot(constraints, songs),
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

  Widget _buildPlot(
    BoxConstraints constraints,
    List<Song> songs, {
    double? heightOverride,
  }) {
    final height =
        heightOverride ?? (constraints.maxWidth < 620 ? 190.0 : 250.0);
    final activeIndex = _activeTimeIndex;
    final selection = activeIndex == null
        ? null
        : _selectionFor(songs, activeIndex);
    return SizedBox(
      key: const ValueKey('realtime-chart-plot'),
      height: height,
      width: double.infinity,
      child: Semantics(
        focusable: true,
        focused: _plotFocusNode.hasFocus,
        button: true,
        label: 'Khám phá biểu đồ 24 giờ',
        value: selection?.semanticValue ?? 'Chưa chọn mốc thời gian',
        increasedValue: _timelineLength <= 1 ? null : 'Mốc thời gian kế tiếp',
        decreasedValue: _timelineLength <= 1 ? null : 'Mốc thời gian trước đó',
        hint: 'Dùng phím mũi tên để chọn thời gian và bài hát, Enter để phát',
        onTap: selection == null ? null : _playSelection,
        onIncrease: _timelineLength <= 1 ? null : () => _moveTime(1),
        onDecrease: _timelineLength <= 1 ? null : () => _moveTime(-1),
        child: Focus(
          focusNode: _plotFocusNode,
          autofocus: widget.autofocus,
          onFocusChange: (focused) {
            if (!mounted) return;
            setState(() {
              if (focused) {
                _activeTimeIndex ??= math.max(0, _timelineLength - 1);
                _activeSongIndex = _songIndexAvailableAt(
                  _activeSongIndex,
                  _activeTimeIndex!,
                );
              } else if (!_hovering && !_pinned) {
                _activeTimeIndex = null;
              }
            });
          },
          onKeyEvent: _handleKeyEvent,
          child: MouseRegion(
            onEnter: (_) => _hovering = true,
            onExit: (_) {
              if (!mounted) return;
              setState(() {
                _hovering = false;
                if (!_plotFocusNode.hasFocus && !_pinned) {
                  _activeTimeIndex = null;
                }
              });
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.precise,
                    onHover: (event) {
                      _selectAt(
                        event.localPosition,
                        constraints.biggest,
                        songs,
                      );
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        _plotFocusNode.requestFocus();
                        _pinned = true;
                        _selectAt(
                          details.localPosition,
                          constraints.biggest,
                          songs,
                        );
                      },
                      onHorizontalDragStart: (details) {
                        _plotFocusNode.requestFocus();
                        _pinned = true;
                        _selectAt(
                          details.localPosition,
                          constraints.biggest,
                          songs,
                        );
                      },
                      onHorizontalDragUpdate: (details) => _selectAt(
                        details.localPosition,
                        constraints.biggest,
                        songs,
                      ),
                      child: CustomPaint(
                        painter: _RealtimeChartPainter(
                          series: _data.series,
                          timeline: _data.timeline,
                          colors: RealtimeChart.lineColors,
                          minScore: widget.snapshot.minScore,
                          maxScore: widget.snapshot.maxScore,
                          activeTimeIndex: activeIndex,
                          activeSongIndex: _activeSongIndex,
                        ),
                      ),
                    ),
                  ),
                ),
                if (selection != null)
                  _positionedTooltip(constraints.maxWidth, selection),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _positionedTooltip(double maxWidth, _ChartSelection selection) {
    final tooltipWidth = math.min(264.0, math.max(196.0, maxWidth - 8));
    final timelineX = _timelineLength <= 1
        ? maxWidth / 2
        : maxWidth * _timeRatio(selection.timeIndex);
    final maxLeft = math.max(4.0, maxWidth - tooltipWidth - 4);
    final left = (timelineX - tooltipWidth / 2).clamp(4.0, maxLeft);
    return Positioned(
      left: left,
      top: 6,
      width: tooltipWidth,
      child: _ChartTooltip(
        selection: selection,
        color: RealtimeChart
            .lineColors[_activeSongIndex % RealtimeChart.lineColors.length],
        onPlay: _playSelection,
      ),
    );
  }

  void _selectAt(Offset localPosition, Size size, List<Song> songs) {
    if (_timelineLength <= 0 || size.width <= 0 || size.height <= 0) return;
    final timeRatio = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final firstHour = _data.timeline.first;
    final targetHour =
        firstHour + ((_data.timeline.last - firstHour) * timeRatio);
    var timeIndex = 0;
    var timeDistance = double.infinity;
    for (var index = 0; index < _data.timeline.length; index++) {
      final candidate = (_data.timeline[index] - targetHour).abs();
      if (candidate < timeDistance) {
        timeDistance = candidate;
        timeIndex = index;
      }
    }
    final chartHeight = math.max(1.0, size.height - 26);
    final songIndex = _nearestSongIndex(
      songs,
      timeIndex,
      localPosition.dy.clamp(4.0, chartHeight),
      chartHeight,
    );
    if (_activeTimeIndex == timeIndex && _activeSongIndex == songIndex) return;
    setState(() {
      _activeTimeIndex = timeIndex;
      _activeSongIndex = songIndex;
    });
  }

  int _nearestSongIndex(
    List<Song> songs,
    int timeIndex,
    double pointerY,
    double chartHeight,
  ) {
    var nearest = 0;
    var distance = double.infinity;
    for (var index = 0; index < songs.length; index++) {
      final point = _pointAt(songs[index], timeIndex);
      if (point == null) continue;
      final y = 4 + (chartHeight - 4) * (1 - _normalized(point.counter));
      final candidate = (y - pointerY).abs();
      if (candidate < distance) {
        distance = candidate;
        nearest = index;
      }
    }
    return nearest;
  }

  double _normalized(double counter) {
    final highest = math.max(
      widget.snapshot.maxScore,
      _data.series
          .expand((points) => points)
          .fold<double>(0, (value, point) => math.max(value, point.counter)),
    );
    final lowest =
        widget.snapshot.minScore > 0 && widget.snapshot.minScore < highest
        ? widget.snapshot.minScore
        : 0.0;
    return ((counter - lowest) / math.max(1, highest - lowest)).clamp(0, 1);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveTime(-1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _moveTime(1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _moveSong(-1);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _moveSong(1);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select) {
      _playSelection();
    } else if (key == LogicalKeyboardKey.escape) {
      setState(() {
        _pinned = false;
        if (!_hovering) _activeTimeIndex = null;
      });
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _moveTime(int delta) {
    if (_timelineLength <= 0) return;
    setState(() {
      _pinned = true;
      _activeTimeIndex = ((_activeTimeIndex ?? _timelineLength - 1) + delta)
          .clamp(0, _timelineLength - 1);
      _activeSongIndex = _songIndexAvailableAt(
        _activeSongIndex,
        _activeTimeIndex!,
      );
    });
  }

  void _moveSong(int delta) {
    if (_songs.isEmpty || _activeTimeIndex == null) return;
    setState(() {
      _pinned = true;
      final step = delta.isNegative ? -1 : 1;
      var candidate = _activeSongIndex + step;
      while (candidate >= 0 && candidate < _songs.length) {
        if (_pointAt(_songs[candidate], _activeTimeIndex!) != null) {
          _activeSongIndex = candidate;
          break;
        }
        candidate += step;
      }
    });
  }

  void _playSelection() {
    if (_songs.isEmpty || _activeTimeIndex == null) return;
    widget.onPlay(_songs[_activeSongIndex], widget.snapshot.songs);
  }

  _ChartSelection? _selectionFor(List<Song> songs, int timeIndex) {
    final selectedSong = songs[_activeSongIndex];
    final point = _pointAt(selectedSong, timeIndex);
    if (point == null) return null;
    final total = songs.fold<double>(
      0,
      (value, song) => value + (_pointAt(song, timeIndex)?.counter ?? 0),
    );
    final percentage = total <= 0 ? 0 : (point.counter / total * 100).round();
    return _ChartSelection(
      song: selectedSong,
      point: point,
      timeIndex: timeIndex,
      percentage: percentage,
    );
  }

  ChartPoint? _pointAt(Song song, int timeIndex) =>
      _data.pointAt(song.id, timeIndex);

  double _timeRatio(int timeIndex) {
    return _chartTimeRatio(_data.timeline, _data.timeline[timeIndex]);
  }

  int _songIndexAvailableAt(int preferred, int timeIndex) {
    if (_songs.isEmpty) return 0;
    if (preferred >= 0 &&
        preferred < _songs.length &&
        _pointAt(_songs[preferred], timeIndex) != null) {
      return preferred;
    }
    return _songs.indexWhere((song) => _pointAt(song, timeIndex) != null);
  }
}

const _millisecondsPerHour = Duration.millisecondsPerHour;

int _chartHourKey(ChartPoint point) =>
    point.time.millisecondsSinceEpoch ~/ _millisecondsPerHour;

String _chartHourLabel(int hourKey) {
  final time = DateTime.fromMillisecondsSinceEpoch(
    hourKey * _millisecondsPerHour,
  ).toLocal();
  return '${time.hour.toString().padLeft(2, '0')}:00';
}

double _chartTimeRatio(List<int> timeline, int hourKey) {
  if (timeline.length <= 1) return 0.5;
  final first = timeline.first;
  final range = timeline.last - first;
  if (range <= 0) return 0.5;
  return (hourKey - first) / range;
}

class _ChartData {
  const _ChartData({
    required this.songs,
    required this.series,
    required this.timeline,
    required this.pointsBySong,
    required this.comparisonHour,
  });

  factory _ChartData.fromSnapshot(ChartSnapshot snapshot) {
    final songs = <Song>[];
    final series = <List<ChartPoint>>[];
    final pointsBySong = <String, Map<int, ChartPoint>>{};
    for (final song in snapshot.songs) {
      final byHour = <int, ChartPoint>{};
      for (final point in snapshot.series[song.id] ?? const <ChartPoint>[]) {
        byHour[_chartHourKey(point)] = point;
      }
      if (byHour.length <= 1) continue;
      final hours = byHour.keys.toList()..sort();
      songs.add(song);
      series.add(
        List<ChartPoint>.unmodifiable([
          for (final hour in hours) byHour[hour]!,
        ]),
      );
      pointsBySong[song.id] = Map<int, ChartPoint>.unmodifiable(byHour);
      if (songs.length == 3) break;
    }

    final frequency = <int, int>{};
    for (final points in pointsBySong.values) {
      for (final hour in points.keys) {
        frequency.update(hour, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final timeline = frequency.keys.toList()..sort();
    int? comparisonHour;
    var comparisonCount = -1;
    for (final hour in timeline) {
      final count = frequency[hour]!;
      if (count >= comparisonCount) {
        comparisonCount = count;
        comparisonHour = hour;
      }
    }
    return _ChartData(
      songs: List<Song>.unmodifiable(songs),
      series: List<List<ChartPoint>>.unmodifiable(series),
      timeline: List<int>.unmodifiable(timeline),
      pointsBySong: Map<String, Map<int, ChartPoint>>.unmodifiable(
        pointsBySong,
      ),
      comparisonHour: comparisonHour,
    );
  }

  final List<Song> songs;
  final List<List<ChartPoint>> series;
  final List<int> timeline;
  final Map<String, Map<int, ChartPoint>> pointsBySong;
  final int? comparisonHour;

  ChartPoint? pointAt(String songId, int timeIndex) {
    if (timeIndex < 0 || timeIndex >= timeline.length) return null;
    return pointsBySong[songId]?[timeline[timeIndex]];
  }
}

class _ChartSelection {
  const _ChartSelection({
    required this.song,
    required this.point,
    required this.timeIndex,
    required this.percentage,
  });

  final Song song;
  final ChartPoint point;
  final int timeIndex;
  final int percentage;

  String get semanticValue =>
      '${song.displayTitle}, ${point.hour}:00, $percentage phần trăm';
}

class _ChartTooltip extends StatelessWidget {
  const _ChartTooltip({
    required this.selection,
    required this.color,
    required this.onPlay,
  });

  final _ChartSelection selection;
  final Color color;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('realtime-chart-tooltip'),
    elevation: 12,
    color: const Color(0xFF21182A).withValues(alpha: 0.96),
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          AlbumArt(
            imageUrl: selection.song.thumbnail,
            semanticLabel: 'Bìa album ${selection.song.displayTitle}',
            size: 40,
            borderRadius: 9,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selection.song.displayTitle,
                  key: const ValueKey('realtime-chart-tooltip-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${selection.point.hour}:00 · ${selection.percentage}%',
                  key: const ValueKey('realtime-chart-tooltip-time'),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('realtime-chart-tooltip-play'),
            tooltip: 'Phát ${selection.song.displayTitle}',
            visualDensity: VisualDensity.compact,
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
    ),
  );
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({
    required this.songs,
    required this.data,
    required this.colors,
    required this.onPlay,
  });

  final List<Song> songs;
  final _ChartData data;
  final List<Color> colors;
  final ValueChanged<Song> onPlay;

  @override
  Widget build(BuildContext context) {
    final comparisonHour = data.comparisonHour;
    double counterFor(Song song) => comparisonHour == null
        ? 0
        : data.pointsBySong[song.id]?[comparisonHour]?.counter ?? 0;
    final latestTotal = songs.fold<double>(
      0,
      (total, song) => total + counterFor(song),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var index = 0; index < songs.length; index++)
              SizedBox(
                width: compact
                    ? (constraints.maxWidth - 10) / 2
                    : (constraints.maxWidth - 20) / 3,
                child: Material(
                  color: colors[index].withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onPlay(songs[index]),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          AlbumArt(
                            imageUrl: songs[index].thumbnail,
                            semanticLabel:
                                'Bìa album ${songs[index].displayTitle}',
                            size: compact ? 36 : 42,
                            borderRadius: 8,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  songs[index].displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  latestTotal <= 0
                                      ? '#${index + 1}'
                                      : '${((counterFor(songs[index]) / latestTotal) * 100).round()}%',
                                  style: TextStyle(
                                    color: colors[index],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
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
              ),
          ],
        );
      },
    );
  }
}

class _RealtimeChartPainter extends CustomPainter {
  const _RealtimeChartPainter({
    required this.series,
    required this.timeline,
    required this.colors,
    required this.minScore,
    required this.maxScore,
    required this.activeTimeIndex,
    required this.activeSongIndex,
  });

  final List<List<ChartPoint>> series;
  final List<int> timeline;
  final List<Color> colors;
  final double minScore;
  final double maxScore;
  final int? activeTimeIndex;
  final int activeSongIndex;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 2.0;
    const top = 4.0;
    const bottom = 26.0;
    final chartRect = Rect.fromLTRB(
      left,
      top,
      size.width - 2,
      size.height - bottom,
    );
    final gridPaint = Paint()
      ..color = const Color(0xFF8B8297).withValues(alpha: 0.26)
      ..strokeWidth = 1;
    for (var row = 0; row <= 4; row++) {
      final y = chartRect.top + chartRect.height * row / 4;
      for (double x = chartRect.left; x < chartRect.right; x += 9) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 3, chartRect.right), y),
          gridPaint,
        );
      }
    }

    final allPoints = series.expand((points) => points).toList(growable: false);
    if (allPoints.isEmpty) return;
    final highest = math.max(
      maxScore,
      allPoints.map((point) => point.counter).reduce(math.max),
    );
    final lowest = minScore > 0 && minScore < highest ? minScore : 0.0;
    final scoreRange = math.max(1.0, highest - lowest);
    if (timeline.isEmpty) return;
    final timelineLength = timeline.length;

    if (activeTimeIndex case final active?) {
      final x =
          chartRect.left +
          chartRect.width *
              _chartTimeRatio(
                timeline,
                timeline[active.clamp(0, timelineLength - 1)],
              );
      final guidePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.42)
        ..strokeWidth = 1;
      for (double y = chartRect.top; y < chartRect.bottom; y += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, math.min(y + 4, chartRect.bottom)),
          guidePaint,
        );
      }
    }

    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final points = series[seriesIndex];
      if (points.length < 2) continue;
      final offsets = <Offset>[
        for (final point in points)
          Offset(
            chartRect.left +
                chartRect.width *
                    _chartTimeRatio(timeline, _chartHourKey(point)),
            chartRect.bottom -
                chartRect.height *
                    ((point.counter - lowest) / scoreRange).clamp(0, 1),
          ),
      ];
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (var index = 1; index < offsets.length; index++) {
        final previous = offsets[index - 1];
        final current = offsets[index];
        final middleX = (previous.dx + current.dx) / 2;
        path.cubicTo(
          middleX,
          previous.dy,
          middleX,
          current.dy,
          current.dx,
          current.dy,
        );
      }
      final color = colors[seriesIndex % colors.length];
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      for (final point in offsets) {
        canvas.drawCircle(point, 4.2, Paint()..color = color);
        canvas.drawCircle(point, 2.1, Paint()..color = Colors.white);
      }
      if (activeTimeIndex case final active?) {
        final activeHour = timeline[active.clamp(0, timelineLength - 1)];
        final pointIndex = points.indexWhere(
          (point) => _chartHourKey(point) == activeHour,
        );
        if (pointIndex < 0) continue;
        final activeOffset = offsets[pointIndex];
        final selected = seriesIndex == activeSongIndex;
        canvas.drawCircle(
          activeOffset,
          selected ? 10 : 7,
          Paint()..color = color.withValues(alpha: selected ? 0.2 : 0.12),
        );
        canvas.drawCircle(
          activeOffset,
          selected ? 6 : 4.8,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected ? 2.4 : 1.5,
        );
        canvas.drawCircle(activeOffset, 2.5, Paint()..color = Colors.white);
      }
    }

    final labelStyle = const TextStyle(color: Color(0xFF958C9F), fontSize: 10);
    for (var index = 0; index < timeline.length; index += 3) {
      final label = TextPainter(
        text: TextSpan(
          text: _chartHourLabel(timeline[index]),
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x =
          chartRect.left +
          chartRect.width * _chartTimeRatio(timeline, timeline[index]);
      label.paint(
        canvas,
        Offset(
          (x - label.width / 2).clamp(0, size.width - label.width),
          size.height - label.height,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RealtimeChartPainter oldDelegate) =>
      !identical(oldDelegate.series, series) ||
      !identical(oldDelegate.timeline, timeline) ||
      oldDelegate.minScore != minScore ||
      oldDelegate.maxScore != maxScore ||
      oldDelegate.activeTimeIndex != activeTimeIndex ||
      oldDelegate.activeSongIndex != activeSongIndex;
}

class _ChartAtmosphere extends StatelessWidget {
  const _ChartAtmosphere();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: const Alignment(-0.75, -0.9),
        radius: 1.15,
        colors: [ZingColors.purple.withValues(alpha: 0.16), Colors.transparent],
      ),
    ),
  );
}
