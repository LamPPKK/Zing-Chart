import 'package:flutter/material.dart';

import '../models/local_library.dart';
import '../music_player_controller.dart';
import '../theme/app_theme.dart';
import 'smart_shuffle_controls.dart';
import 'streaming_quality_controls.dart';

Future<void> showAppSettings(
  BuildContext context, {
  required MusicPlayerController controller,
  bool tvMode = false,
}) async {
  final width = MediaQuery.sizeOf(context).width;
  if (width < 720 && !tvMode) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: AppSettingsPanel(
          controller: controller,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: tvMode ? 160 : 32,
        vertical: tvMode ? 80 : 32,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: tvMode ? 760 : 680,
          maxHeight: tvMode ? 820 : 760,
        ),
        child: AppSettingsPanel(
          controller: controller,
          tvMode: tvMode,
          showFullscreenPlayerPreference: !tvMode && width >= 1100,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    ),
  );
}

class AppSettingsPanel extends StatelessWidget {
  const AppSettingsPanel({
    super.key,
    required this.controller,
    this.tvMode = false,
    this.showFullscreenPlayerPreference = false,
    this.onClose,
  });

  final MusicPlayerController controller;
  final bool tvMode;
  final bool showFullscreenPlayerPreference;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return Material(
        key: const ValueKey('app-settings-panel'),
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            _SettingsHeader(tvMode: tvMode, onClose: onClose),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  tvMode ? 34 : 20,
                  tvMode ? 28 : 22,
                  tvMode ? 34 : 20,
                  tvMode ? 36 : 28,
                ),
                children: [
                  const _SectionHeading(
                    icon: Icons.palette_outlined,
                    eyebrow: 'GIAO DIỆN',
                    title: 'Theo cách bạn muốn',
                    description:
                        'Chọn giao diện hệ thống, sáng hoặc tối. Bảng màu #zingChart vẫn được giữ nguyên.',
                  ),
                  const SizedBox(height: 14),
                  _ChoiceRow<AppThemePreference>(
                    current: controller.themePreference,
                    options: const [
                      _ChoiceOption(
                        value: AppThemePreference.system,
                        label: 'Hệ thống',
                        icon: Icons.devices_rounded,
                        keyName: 'system',
                      ),
                      _ChoiceOption(
                        value: AppThemePreference.light,
                        label: 'Sáng',
                        icon: Icons.light_mode_outlined,
                        keyName: 'light',
                      ),
                      _ChoiceOption(
                        value: AppThemePreference.dark,
                        label: 'Tối',
                        icon: Icons.dark_mode_outlined,
                        keyName: 'dark',
                      ),
                    ],
                    keyPrefix: 'settings-theme',
                    onChanged: controller.setThemePreference,
                  ),
                  const SizedBox(height: 28),
                  const _SectionHeading(
                    icon: Icons.tune_rounded,
                    eyebrow: 'PHÁT NHẠC',
                    title: 'Điều khiển hàng đợi',
                    description:
                        'Các thay đổi áp dụng ngay và được lưu riêng trên thiết bị này.',
                  ),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    child: Column(
                      children: [
                        _SettingsSwitch(
                          key: const ValueKey('settings-shuffle'),
                          icon: Icons.shuffle_rounded,
                          title: 'Trộn bài',
                          subtitle: controller.isLiveRadio
                              ? 'Không áp dụng cho Phòng Nhạc trực tiếp'
                              : 'Phát hàng đợi theo thứ tự ngẫu nhiên',
                          value: controller.shuffleEnabled,
                          onChanged: controller.isLiveRadio
                              ? null
                              : controller.setShuffleEnabled,
                        ),
                        const _CardDivider(),
                        _SettingsSwitch(
                          key: const ValueKey('settings-smart-shuffle'),
                          icon: Icons.auto_awesome_rounded,
                          title: 'Smart Shuffle',
                          subtitle: controller.isLiveRadio
                              ? 'Không áp dụng cho Phòng Nhạc trực tiếp'
                              : controller.smartShuffleEnabled
                              ? '${controller.smartShuffleSongCount} bài local-first đang được xen vào hàng đợi'
                              : 'Gợi ý từ catalog hiện tại; không gửi gu nghe nhạc lên proxy',
                          value: controller.smartShuffleEnabled,
                          onChanged: controller.isLiveRadio
                              ? null
                              : (value) => setSmartShuffleWithFeedback(
                                  context,
                                  controller,
                                  value,
                                ),
                        ),
                        const _CardDivider(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _InlineLabel(
                                icon: Icons.repeat_rounded,
                                title: 'Lặp lại',
                              ),
                              const SizedBox(height: 12),
                              _ChoiceRow<PlayerRepeatMode>(
                                current: controller.repeatMode,
                                enabled: !controller.isLiveRadio,
                                options: const [
                                  _ChoiceOption(
                                    value: PlayerRepeatMode.off,
                                    label: 'Tắt',
                                    icon: Icons.block_rounded,
                                    keyName: 'off',
                                  ),
                                  _ChoiceOption(
                                    value: PlayerRepeatMode.all,
                                    label: 'Tất cả',
                                    icon: Icons.repeat_rounded,
                                    keyName: 'all',
                                  ),
                                  _ChoiceOption(
                                    value: PlayerRepeatMode.one,
                                    label: 'Một bài',
                                    icon: Icons.repeat_one_rounded,
                                    keyName: 'one',
                                  ),
                                ],
                                keyPrefix: 'settings-repeat',
                                onChanged: controller.setRepeatMode,
                              ),
                            ],
                          ),
                        ),
                        const _CardDivider(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _InlineLabel(
                                icon: Icons.multiple_stop_rounded,
                                title: 'Chuyển bài liền mạch',
                              ),
                              const SizedBox(height: 7),
                              Text(
                                controller.seamlessPlaybackSupported
                                    ? 'Tự động chuẩn bị đúng bài đầu của Tiếp theo trong 30 giây cuối; không lưu file hoặc cache offline.'
                                    : 'Backend phát nhạc này chưa hỗ trợ deck chờ; app tự dùng chuyển bài tiêu chuẩn.',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 12.5,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _ChoiceRow<SeamlessPlaybackPreference>(
                                current: controller.seamlessPlaybackPreference,
                                options: const [
                                  _ChoiceOption(
                                    value: SeamlessPlaybackPreference.automatic,
                                    label: 'Tự động',
                                    icon: Icons.bolt_rounded,
                                    keyName: 'auto',
                                  ),
                                  _ChoiceOption(
                                    value: SeamlessPlaybackPreference.off,
                                    label: 'Tắt',
                                    icon: Icons.block_rounded,
                                    keyName: 'off',
                                  ),
                                ],
                                keyPrefix: 'settings-seamless',
                                onChanged:
                                    controller.setSeamlessPlaybackPreference,
                              ),
                            ],
                          ),
                        ),
                        const _CardDivider(),
                        _SettingsSwitch(
                          key: const ValueKey('settings-autoplay'),
                          icon: Icons.auto_awesome_rounded,
                          title: 'Tự động phát Song Radio',
                          subtitle: controller.songRadioAvailable
                              ? 'Gợi ý thêm bài từ catalog công khai khi hàng đợi kết thúc'
                              : 'Proxy hiện tại chưa cung cấp Song Radio',
                          value: controller.autoplayRecommendationsEnabled,
                          onChanged: controller.songRadioAvailable
                              ? controller.setAutoplayRecommendations
                              : null,
                        ),
                        const _CardDivider(),
                        _SettingsSwitch(
                          key: const ValueKey('settings-car-mode'),
                          icon: Icons.directions_car_filled_rounded,
                          title: 'Chế độ lái xe',
                          subtitle:
                              'Now Playing tối giản với nút lớn và ít thao tác hơn',
                          value: controller.carModeEnabled,
                          onChanged: controller.setCarModeEnabled,
                        ),
                        if (showFullscreenPlayerPreference) ...[
                          const _CardDivider(),
                          _SettingsSwitch(
                            key: const ValueKey('settings-fullscreen-player'),
                            icon: Icons.fullscreen_rounded,
                            title: 'Luôn mở Now Playing toàn màn hình',
                            subtitle:
                                'Mở trình phát lớn khi chọn bài thay vì panel bên phải',
                            value: controller.alwaysOpenFullscreenPlayer,
                            onChanged: controller.setAlwaysOpenFullscreenPlayer,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  _SectionHeading(
                    icon: Icons.bedtime_outlined,
                    eyebrow: 'HẸN GIỜ TẮT',
                    title: 'Ngủ cùng âm nhạc',
                    description: _sleepStatus(controller),
                  ),
                  const SizedBox(height: 14),
                  _SettingsCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [15, 30, 45, 60]
                                .map(
                                  (minutes) => ActionChip(
                                    key: ValueKey('settings-sleep-$minutes'),
                                    avatar: const Icon(
                                      Icons.timer_outlined,
                                      size: 18,
                                    ),
                                    label: Text('$minutes phút'),
                                    onPressed: () => controller.setSleepTimer(
                                      Duration(minutes: minutes),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              ActionChip(
                                key: const ValueKey(
                                  'settings-sleep-after-song',
                                ),
                                avatar: const Icon(
                                  Icons.music_note_rounded,
                                  size: 18,
                                ),
                                label: const Text('Hết bài hiện tại'),
                                onPressed:
                                    controller.hasSong &&
                                        !controller.isLiveRadio
                                    ? controller.setSleepAfterCurrentSong
                                    : null,
                              ),
                              if (controller.hasSleepTimer)
                                ActionChip(
                                  key: const ValueKey('settings-sleep-cancel'),
                                  avatar: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Hủy hẹn giờ'),
                                  onPressed: controller.cancelSleepTimer,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _SectionHeading(
                    icon: Icons.high_quality_outlined,
                    eyebrow: 'NGUỒN PHÁT',
                    title:
                        'Chất lượng · ${controller.streamingQualityPreference.label}',
                    description:
                        'Chọn bitrate thật từ nguồn Zing được cấp cho bài hát; thay đổi áp dụng ở lần nạp nguồn tiếp theo.',
                  ),
                  const SizedBox(height: 14),
                  _SettingsCard(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: StreamingQualitySelector(controller: controller),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _InfoBanner(
                    icon: Icons.shield_outlined,
                    title: 'Relay có chữ ký · không cache audio',
                    subtitle:
                        'Auto ưu tiên 320 rồi mới về 128. Chế độ 320 không âm thầm hạ chất lượng; hãy chọn Auto hoặc 128 nếu bài không có nguồn tương ứng.',
                    accent: ZingColors.lime,
                  ),
                  const SizedBox(height: 28),
                  const _SectionHeading(
                    icon: Icons.shield_outlined,
                    eyebrow: 'LOCAL-FIRST',
                    title: 'Dữ liệu thuộc về bạn',
                    description:
                        'Yêu thích, playlist, lịch sử và thống kê chỉ lưu trên thiết bị; không gửi lên proxy.',
                  ),
                  const SizedBox(height: 14),
                  _LocalStats(controller: controller),
                  const SizedBox(height: 18),
                  _InfoBanner(
                    icon: Icons.cloud_off_outlined,
                    title: 'Không cần tài khoản',
                    subtitle:
                        'Dùng sao lưu JSON trong Thư viện để chuyển dữ liệu giữa các thiết bị.',
                    accent: ZingColors.lime,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.tvMode, this.onClose});

  final bool tvMode;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      tvMode ? 34 : 20,
      tvMode ? 26 : 18,
      tvMode ? 24 : 12,
      tvMode ? 22 : 14,
    ),
    child: Row(
      children: [
        Container(
          width: tvMode ? 54 : 46,
          height: tvMode ? 54 : 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [ZingColors.purpleBright, ZingColors.coral],
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            Icons.settings_rounded,
            color: Colors.white,
            size: tvMode ? 30 : 25,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CÀI ĐẶT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.7,
                  color: ZingColors.coral,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Tùy chỉnh #zingChart',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        if (onClose != null)
          IconButton(
            key: const ValueKey('settings-close'),
            tooltip: 'Đóng cài đặt',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      const SizedBox(width: 13),
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
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ChoiceOption<T> {
  const _ChoiceOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.keyName,
  });

  final T value;
  final String label;
  final IconData icon;
  final String keyName;
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.current,
    required this.options,
    required this.keyPrefix,
    required this.onChanged,
    this.enabled = true,
  });

  final T current;
  final List<_ChoiceOption<T>> options;
  final String keyPrefix;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: options
        .map(
          (option) => ChoiceChip(
            key: ValueKey('$keyPrefix-${option.keyName}'),
            selected: current == option.value,
            avatar: Icon(option.icon, size: 18),
            label: Text(option.label),
            onSelected: enabled ? (_) => onChanged(option.value) : null,
          ),
        )
        .toList(growable: false),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(
      context,
    ).colorScheme.surfaceContainer.withValues(alpha: 0.64),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: child,
  );
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
    secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: Text(subtitle),
    value: value,
    onChanged: onChanged,
  );
}

class _InlineLabel extends StatelessWidget {
  const _InlineLabel({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 14),
      Expanded(
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    ],
  );
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 16,
    endIndent: 16,
    color: Theme.of(context).colorScheme.outlineVariant,
  );
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: accent.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LocalStats extends StatelessWidget {
  const _LocalStats({required this.controller});

  final MusicPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('Yêu thích', controller.likedSongs.length, Icons.favorite_outline),
      ('Playlist', controller.playlists.length, Icons.queue_music_rounded),
      ('Lịch sử', controller.history.length, Icons.history_rounded),
      ('Nghệ sĩ', controller.followedArtists.length, Icons.person_outline),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth < 430
            ? (constraints.maxWidth - 10) / 2
            : (constraints.maxWidth - 30) / 4;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: values
              .map(
                (item) => Container(
                  width: itemWidth,
                  height: 94,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.$3, size: 20, color: ZingColors.lime),
                      const Spacer(),
                      Text(
                        '${item.$2}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        item.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

String _sleepStatus(MusicPlayerController controller) {
  if (controller.sleepAfterCurrentSong) {
    return 'Đang bật · dừng sau khi bài hiện tại kết thúc.';
  }
  final remaining = controller.sleepTimerRemaining;
  if (remaining == null) {
    return 'Tự động dừng phát sau một khoảng thời gian hoặc khi hết bài.';
  }
  final minutes = (remaining.inSeconds / 60).ceil();
  return 'Đang bật · còn khoảng $minutes phút.';
}
