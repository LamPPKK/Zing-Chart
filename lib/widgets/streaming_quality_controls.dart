import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/local_library.dart';
import '../music_player_controller.dart';
import '../theme/app_theme.dart';

Future<void> showStreamingQualityPicker(
  BuildContext context, {
  required MusicPlayerController controller,
}) async {
  final width = MediaQuery.sizeOf(context).width;
  final panel = StreamingQualityPickerPanel(controller: controller);
  if (width < 720) {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => panel,
    );
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 690),
        child: panel,
      ),
    ),
  );
}

class StreamingQualitySelector extends StatelessWidget {
  const StreamingQualitySelector({
    super.key,
    required this.controller,
    this.closeOnSelect = false,
  });

  final MusicPlayerController controller;
  final bool closeOnSelect;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 540;
        final options = StreamingQualityPreference.values
            .map(
              (preference) => SizedBox(
                width: horizontal
                    ? (constraints.maxWidth - 20) / 3
                    : constraints.maxWidth,
                child: _QualityOption(
                  preference: preference,
                  selected: controller.streamingQualityPreference == preference,
                  onTap: () {
                    controller.setStreamingQualityPreference(preference);
                    if (closeOnSelect) Navigator.of(context).pop();
                  },
                ),
              ),
            )
            .toList(growable: false);
        return Wrap(spacing: 10, runSpacing: 10, children: options);
      },
    ),
  );
}

class StreamingQualityPickerPanel extends StatelessWidget {
  const StreamingQualityPickerPanel({
    super.key,
    required this.controller,
    this.showCloseButton = true,
  });

  final MusicPlayerController controller;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('streaming-quality-picker'),
    color: Theme.of(context).scaffoldBackgroundColor,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: ZingColors.coral.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.high_quality_rounded,
                    color: ZingColors.coral,
                  ),
                ),
                const SizedBox(width: 13),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CHẤT LƯỢNG NHẠC',
                        style: TextStyle(
                          color: ZingColors.coral,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Chọn bitrate phát trực tuyến',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showCloseButton)
                  IconButton(
                    key: const ValueKey('streaming-quality-close'),
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tùy chọn được lưu trên thiết bị và áp dụng khi app nạp nguồn bài hát tiếp theo.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            StreamingQualitySelector(
              controller: controller,
              closeOnSelect: true,
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: ZingColors.lime,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nguồn vẫn đi qua relay đã ký; app không tải offline hoặc cache URL stream dài hạn.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.35,
                    ),
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

class _QualityOption extends StatefulWidget {
  const _QualityOption({
    required this.preference,
    required this.selected,
    required this.onTap,
  });

  final StreamingQualityPreference preference;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_QualityOption> createState() => _QualityOptionState();
}

class _QualityOptionState extends State<_QualityOption> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = widget.selected || _hovered || _focused;
    final (icon, title, description) = switch (widget.preference) {
      StreamingQualityPreference.automatic => (
        Icons.auto_awesome_rounded,
        'Tự động',
        'Ưu tiên 320, tự về 128 khi cần',
      ),
      StreamingQualityPreference.standard => (
        Icons.data_saver_on_rounded,
        '128 kbps',
        'Ổn định, tiết kiệm dữ liệu',
      ),
      StreamingQualityPreference.high => (
        Icons.high_quality_rounded,
        '320 kbps',
        'Chỉ phát khi nguồn 320 có sẵn',
      ),
    };
    return Semantics(
      selected: widget.selected,
      button: true,
      label: '$title, $description',
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: Focus(
          onFocusChange: (value) => setState(() => _focused = value),
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.select ||
                    event.logicalKey == LogicalKeyboardKey.space)) {
              widget.onTap();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: AnimatedContainer(
              key: ValueKey('quality-option-${widget.preference.apiValue}'),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: widget.selected
                    ? ZingColors.coral.withValues(alpha: 0.13)
                    : active
                    ? scheme.surfaceContainerHighest
                    : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.selected
                      ? ZingColors.coral
                      : _focused
                      ? ZingColors.lime
                      : scheme.outlineVariant,
                  width: _focused || widget.selected ? 2 : 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: widget.onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 96),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          icon,
                          color: widget.selected
                              ? ZingColors.coral
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  if (widget.selected)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 18,
                                      color: ZingColors.coral,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                description,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 12,
                                  height: 1.3,
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
          ),
        ),
      ),
    );
  }
}
