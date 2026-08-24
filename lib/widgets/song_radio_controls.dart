import 'package:flutter/material.dart';

import '../models/song.dart';
import '../music_player_controller.dart';
import '../theme/app_theme.dart';

Future<void> startSongRadioWithFeedback(
  BuildContext context,
  MusicPlayerController controller, [
  Song? seed,
]) async {
  final count = await controller.startSongRadio(seed);
  if (!context.mounted) return;
  final error = controller.radioErrorMessage;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        count > 0
            ? 'Đã tạo Song Radio · $count bài tương tự'
            : error ?? 'Chưa tìm thấy bài tương tự phù hợp.',
      ),
    ),
  );
}

class SongRadioControlCard extends StatelessWidget {
  const SongRadioControlCard({
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
    return Semantics(
      container: true,
      label: 'Tự động phát bài hát tương tự',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 15,
          vertical: compact ? 10 : 12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              ZingColors.purple.withValues(alpha: 0.22),
              ZingColors.coral.withValues(alpha: 0.09),
            ],
          ),
          borderRadius: BorderRadius.circular(tvMode ? 18 : 14),
          border: Border.all(
            color: controller.autoplayRecommendationsEnabled
                ? ZingColors.purpleBright.withValues(alpha: 0.58)
                : scheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: tvMode ? 52 : 42,
              height: tvMode ? 52 : 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [ZingColors.purpleBright, ZingColors.coral],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: controller.isRadioLoading
                  ? Padding(
                      padding: EdgeInsets.all(tvMode ? 15 : 12),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      Icons.radio_rounded,
                      size: tvMode ? 29 : 23,
                      color: Colors.white,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tự động phát',
                    style: TextStyle(
                      fontSize: tvMode ? 18 : 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    controller.isRadioLoading
                        ? 'Đang tìm bài hợp gu…'
                        : 'Thêm bài tương tự khi hàng đợi kết thúc',
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
            Switch.adaptive(
              key: const ValueKey('song-radio-autoplay-toggle'),
              value: controller.autoplayRecommendationsEnabled,
              onChanged: controller.songRadioAvailable
                  ? controller.setAutoplayRecommendations
                  : null,
              activeTrackColor: ZingColors.purpleBright,
            ),
          ],
        ),
      ),
    );
  }
}

class SongRadioBadge extends StatelessWidget {
  const SongRadioBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 6 : 8,
      vertical: compact ? 2 : 3,
    ),
    decoration: BoxDecoration(
      color: ZingColors.purpleBright.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: ZingColors.purpleBright.withValues(alpha: 0.52),
      ),
    ),
    child: Text(
      'RADIO',
      style: TextStyle(
        color: ZingColors.purpleBright,
        fontSize: compact ? 8 : 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    ),
  );
}
