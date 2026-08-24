import 'package:flutter/material.dart';

import '../models/weekly_chart.dart';
import '../theme/app_theme.dart';

typedef WeeklyPeriodChanged = void Function(int week, int year);

class WeeklyChartView extends StatelessWidget {
  const WeeklyChartView({
    super.key,
    required this.chart,
    required this.loading,
    required this.errorMessage,
    required this.region,
    required this.onBack,
    required this.onRetry,
    required this.onRegionChanged,
    required this.onPeriodChanged,
    required this.songCount,
    required this.playableSongCount,
    required this.onPlayAll,
    this.tvMode = false,
  });

  final WeeklyChart chart;
  final bool loading;
  final String? errorMessage;
  final WeeklyChartRegion region;
  final VoidCallback onBack;
  final VoidCallback onRetry;
  final ValueChanged<WeeklyChartRegion> onRegionChanged;
  final WeeklyPeriodChanged onPeriodChanged;
  final int songCount;
  final int playableSongCount;
  final VoidCallback? onPlayAll;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final horizontal = tvMode ? 32.0 : 20.0;
    if (loading && chart.isEmpty) {
      return Padding(
        key: const ValueKey('weekly-chart-loading'),
        padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 52),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang tải bảng xếp hạng tuần…'),
            ],
          ),
        ),
      );
    }
    if (chart.isEmpty) {
      return Padding(
        key: const ValueKey('weekly-chart-error'),
        padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 50),
        child: _WeeklyError(onBack: onBack, onRetry: onRetry),
      );
    }
    return Padding(
      key: const ValueKey('weekly-chart'),
      padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, tvMode ? 22 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WeeklyHeading(
            title: chart.title,
            onBack: onBack,
            onPlayAll: onPlayAll,
            tvMode: tvMode,
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 14),
            _WeeklyStaleNotice(onRetry: onRetry),
          ] else if (loading) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(minHeight: 3),
          ],
          SizedBox(height: tvMode ? 28 : 20),
          _WeeklyRegionTabs(
            selected: region,
            onChanged: onRegionChanged,
            tvMode: tvMode,
          ),
          SizedBox(height: tvMode ? 24 : 18),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            runSpacing: 10,
            children: [
              _WeeklyPeriodMenu(
                chart: chart,
                onChanged: onPeriodChanged,
                tvMode: tvMode,
              ),
              Text(
                '$songCount bài · $playableSongCount có thể phát',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: tvMode ? 14 : 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: tvMode ? 22 : 16),
          Row(
            children: [
              Text(
                'THỨ HẠNG',
                style: TextStyle(
                  color: ZingColors.lime,
                  fontSize: tvMode ? 14 : 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              Text(
                'ALBUM · THỜI LƯỢNG',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: tvMode ? 13 : 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyHeading extends StatelessWidget {
  const _WeeklyHeading({
    required this.title,
    required this.onBack,
    required this.onPlayAll,
    required this.tvMode,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onPlayAll;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return Row(
      children: [
        if (!wide) ...[
          IconButton.filledTonal(
            key: const ValueKey('weekly-chart-back'),
            tooltip: 'Quay lại Khám phá',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          SizedBox(width: tvMode ? 18 : 13),
        ],
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: tvMode ? 46 : 34,
              height: 1.02,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.4,
            ),
          ),
        ),
        SizedBox(width: tvMode ? 18 : 12),
        IconButton.filled(
          key: const ValueKey('weekly-chart-play-all'),
          tooltip: 'Phát bảng xếp hạng tuần',
          onPressed: onPlayAll,
          style: IconButton.styleFrom(
            backgroundColor: ZingColors.purpleBright,
            foregroundColor: Colors.white,
            minimumSize: Size.square(tvMode ? 68 : 52),
          ),
          icon: Icon(Icons.play_arrow_rounded, size: tvMode ? 38 : 28),
        ),
      ],
    );
  }
}

class _WeeklyRegionTabs extends StatelessWidget {
  const _WeeklyRegionTabs({
    required this.selected,
    required this.onChanged,
    required this.tvMode,
  });

  final WeeklyChartRegion selected;
  final ValueChanged<WeeklyChartRegion> onChanged;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: WeeklyChartRegion.values
          .map(
            (region) => Padding(
              padding: EdgeInsets.only(right: tvMode ? 38 : 28),
              child: _WeeklyRegionTab(
                key: ValueKey('weekly-region-${region.name}'),
                region: region,
                selected: region == selected,
                onTap: () => onChanged(region),
                tvMode: tvMode,
              ),
            ),
          )
          .toList(growable: false),
    ),
  );
}

class _WeeklyRegionTab extends StatefulWidget {
  const _WeeklyRegionTab({
    super.key,
    required this.region,
    required this.selected,
    required this.onTap,
    required this.tvMode,
  });

  final WeeklyChartRegion region;
  final bool selected;
  final VoidCallback onTap;
  final bool tvMode;

  @override
  State<_WeeklyRegionTab> createState() => _WeeklyRegionTabState();
}

class _WeeklyRegionTabState extends State<_WeeklyRegionTab> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = _focused || _hovered;
    return Semantics(
      selected: widget.selected,
      button: true,
      label: 'Bảng xếp hạng tuần ${widget.region.label}',
      child: InkWell(
        onTap: widget.onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(8),
        onHover: (value) => setState(() => _hovered = value),
        onFocusChange: (value) {
          setState(() => _focused = value);
          if (value) {
            Scrollable.ensureVisible(
              context,
              duration: const Duration(milliseconds: 200),
              alignment: 0.2,
            );
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: BoxConstraints(minHeight: widget.tvMode ? 58 : 48),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.selected
                    ? ZingColors.purpleBright
                    : Colors.transparent,
                width: widget.tvMode ? 4 : 3,
              ),
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: ZingColors.purpleBright.withValues(alpha: 0.24),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.region.label,
            style: TextStyle(
              color: widget.selected || active
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: widget.tvMode ? 22 : 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _WeeklyPeriodMenu extends StatelessWidget {
  const _WeeklyPeriodMenu({
    required this.chart,
    required this.onChanged,
    required this.tvMode,
  });

  final WeeklyChart chart;
  final WeeklyPeriodChanged onChanged;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: _recentPeriods(chart.week, chart.year)
        .map(
          (period) => MenuItemButton(
            key: ValueKey('weekly-period-${period.$2}-${period.$1}'),
            onPressed: () => onChanged(period.$1, period.$2),
            leadingIcon: period.$1 == chart.week && period.$2 == chart.year
                ? const Icon(Icons.check_rounded)
                : const SizedBox(width: 24),
            child: Text('Tuần ${period.$1} · ${period.$2}'),
          ),
        )
        .toList(growable: false),
    builder: (context, controller, _) => FilledButton.tonalIcon(
      key: const ValueKey('weekly-period-menu'),
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
      icon: const Icon(Icons.calendar_month_rounded),
      label: Text(
        chart.periodLabel,
        style: TextStyle(fontSize: tvMode ? 16 : 13),
      ),
      style: FilledButton.styleFrom(minimumSize: Size(0, tvMode ? 56 : 46)),
    ),
  );
}

List<(int, int)> _recentPeriods(int week, int year) {
  final periods = <(int, int)>[];
  var currentWeek = week;
  var currentYear = year;
  for (var index = 0; index < 8; index++) {
    periods.add((currentWeek, currentYear));
    if (currentWeek > 1) {
      currentWeek--;
    } else {
      currentYear--;
      currentWeek = _weeksInIsoYear(currentYear);
    }
  }
  return periods;
}

int _weeksInIsoYear(int year) {
  final december28 = DateTime.utc(year, 12, 28);
  final firstThursday = december28.add(Duration(days: 4 - december28.weekday));
  final firstDayOfYear = DateTime.utc(firstThursday.year, 1, 1);
  return 1 + firstThursday.difference(firstDayOfYear).inDays ~/ 7;
}

class _WeeklyStaleNotice extends StatelessWidget {
  const _WeeklyStaleNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Material(
    color: ZingColors.coral.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: ZingColors.coral),
          const SizedBox(width: 10),
          const Expanded(child: Text('Đang hiển thị dữ liệu tuần gần nhất.')),
          TextButton(onPressed: onRetry, child: const Text('THỬ LẠI')),
        ],
      ),
    ),
  );
}

class _WeeklyError extends StatelessWidget {
  const _WeeklyError({required this.onBack, required this.onRetry});

  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.show_chart_rounded, size: 54, color: ZingColors.coral),
        const SizedBox(height: 14),
        const Text(
          'Chưa tải được bảng xếp hạng tuần',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          children: [
            OutlinedButton(onPressed: onBack, child: const Text('QUAY LẠI')),
            FilledButton(onPressed: onRetry, child: const Text('THỬ LẠI')),
          ],
        ),
      ],
    ),
  );
}
