import 'package:flutter/material.dart';

import '../music_player_controller.dart';
import '../theme/app_theme.dart';

void setSmartShuffleWithFeedback(
  BuildContext context,
  MusicPlayerController controller,
  bool enabled,
) {
  final succeeded = controller.setSmartShuffleEnabled(enabled);
  if (!context.mounted) return;
  final message = controller.smartShuffleMessage;
  if (!succeeded || message != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message ??
              (enabled
                  ? 'Chưa thể bật Smart Shuffle.'
                  : 'Đã tắt Smart Shuffle.'),
        ),
      ),
    );
  }
}

class SmartShuffleControlCard extends StatelessWidget {
  const SmartShuffleControlCard({
    super.key,
    required this.controller,
    this.compact = false,
    this.tvMode = false,
  });

  final MusicPlayerController controller;
  final bool compact;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = controller.smartShuffleEnabled;
    final unavailable = controller.isLiveRadio || controller.queue.isEmpty;
    final subtitle = enabled
        ? '${controller.smartShuffleSongCount} bài được tự động thêm · chỉ dùng dữ liệu tại máy'
        : controller.smartShuffleMessage ??
              'Trộn hàng đợi và xen bài hợp gu từ catalog hiện tại';
    return Semantics(
      container: true,
      label: 'Smart Shuffle local-first',
      child: AnimatedContainer(
        key: const ValueKey('smart-shuffle-control-card'),
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 15,
          vertical: compact ? 10 : 13,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: enabled
                ? [
                    ZingColors.lime.withValues(alpha: 0.18),
                    ZingColors.purpleBright.withValues(alpha: 0.16),
                  ]
                : [
                    ZingColors.purple.withValues(alpha: 0.18),
                    ZingColors.coral.withValues(alpha: 0.07),
                  ],
          ),
          borderRadius: BorderRadius.circular(tvMode ? 18 : 14),
          border: Border.all(
            color: enabled
                ? ZingColors.lime.withValues(alpha: 0.72)
                : scheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: tvMode ? 52 : 42,
              height: tvMode ? 52 : 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: enabled
                      ? [ZingColors.lime, ZingColors.purpleBright]
                      : [ZingColors.purpleBright, ZingColors.coral],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: tvMode ? 29 : 23,
                color: enabled ? ZingColors.ink : Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart Shuffle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: tvMode ? 18 : 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    unavailable
                        ? 'Chọn một hàng đợi nhạc để sử dụng'
                        : subtitle,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: tvMode ? 14 : 11.5,
                    ),
                  ),
                ],
              ),
            ),
            if (enabled)
              IconButton(
                key: const ValueKey('smart-shuffle-refresh'),
                tooltip: 'Làm mới bài Smart Shuffle',
                onPressed: unavailable
                    ? null
                    : () {
                        final succeeded = controller.refreshSmartShuffle();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              controller.smartShuffleMessage ??
                                  (succeeded
                                      ? 'Đã làm mới Smart Shuffle.'
                                      : 'Chưa thể làm mới Smart Shuffle.'),
                            ),
                          ),
                        );
                      },
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.refresh_rounded),
              ),
            Switch.adaptive(
              key: const ValueKey('smart-shuffle-toggle'),
              value: enabled,
              onChanged: unavailable
                  ? null
                  : (value) =>
                        setSmartShuffleWithFeedback(context, controller, value),
              activeTrackColor: ZingColors.lime,
              activeThumbColor: ZingColors.ink,
            ),
          ],
        ),
      ),
    );
  }
}

class SmartShuffleBadge extends StatelessWidget {
  const SmartShuffleBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Bài do Smart Shuffle thêm',
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: ZingColors.lime.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ZingColors.lime.withValues(alpha: 0.62)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: ZingColors.lime,
            size: compact ? 9 : 11,
          ),
          const SizedBox(width: 3),
          Text(
            'SMART',
            style: TextStyle(
              color: ZingColors.lime,
              fontSize: compact ? 8 : 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    ),
  );
}
