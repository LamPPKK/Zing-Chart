import 'package:flutter/material.dart';

import '../models/live_radio.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';

class LiveRadioHub extends StatelessWidget {
  const LiveRadioHub({
    super.key,
    required this.snapshot,
    required this.loading,
    required this.errorMessage,
    required this.activeRoomId,
    required this.isPlaying,
    required this.onRetry,
    required this.onRoomTap,
    this.tvMode = false,
  });

  final LiveRadioSnapshot snapshot;
  final bool loading;
  final String? errorMessage;
  final String? activeRoomId;
  final bool isPlaying;
  final VoidCallback onRetry;
  final ValueChanged<LiveRadioRoom> onRoomTap;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    if (loading && snapshot.isEmpty) {
      return const SizedBox(
        height: 360,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (errorMessage != null && snapshot.isEmpty) {
      return _LiveRadioMessage(
        icon: Icons.portable_wifi_off_rounded,
        title: 'Phòng Nhạc đang tạm gián đoạn',
        message: errorMessage!,
        actionLabel: 'Thử lại',
        onAction: onRetry,
      );
    }
    if (snapshot.isEmpty) {
      return _LiveRadioMessage(
        icon: Icons.radio_outlined,
        title: 'Chưa có phòng đang LIVE',
        message: 'Kéo xuống để kiểm tra lại lịch phát mới nhất.',
        actionLabel: 'Làm mới',
        onAction: onRetry,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1420
            ? 5
            : width >= 1040
            ? 4
            : width >= 650
            ? 3
            : 2;
        final horizontalPadding = tvMode ? 32.0 : 20.0;
        final available = width - horizontalPadding * 2 - (columns - 1) * 14;
        final imageSize = (available / columns - 28).clamp(
          tvMode ? 128.0 : 112.0,
          tvMode ? 190.0 : 166.0,
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            tvMode ? 56 : 36,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ZingColors.coral.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: ZingColors.coral.withValues(alpha: 0.42),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PulseDot(),
                        SizedBox(width: 7),
                        Text(
                          'ĐANG PHÁT TRỰC TIẾP',
                          style: TextStyle(
                            color: ZingColors.coral,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (width >= 420) ...[
                    const Spacer(),
                    Text(
                      '${snapshot.rooms.length} phòng',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: tvMode ? 15 : 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: tvMode ? 20 : 14,
                  mainAxisExtent: tvMode ? 314 : 276,
                ),
                itemCount: snapshot.rooms.length,
                itemBuilder: (context, index) {
                  final room = snapshot.rooms[index];
                  return _LiveRoomCard(
                    room: room,
                    imageSize: imageSize,
                    active: activeRoomId == room.id,
                    playing: activeRoomId == room.id && isPlaying,
                    autofocus: tvMode && index == 0,
                    tvMode: tvMode,
                    onTap: () => onRoomTap(room),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LiveRoomCard extends StatefulWidget {
  const _LiveRoomCard({
    required this.room,
    required this.imageSize,
    required this.active,
    required this.playing,
    required this.autofocus,
    required this.tvMode,
    required this.onTap,
  });

  final LiveRadioRoom room;
  final double imageSize;
  final bool active;
  final bool playing;
  final bool autofocus;
  final bool tvMode;
  final VoidCallback onTap;

  @override
  State<_LiveRoomCard> createState() => _LiveRoomCardState();
}

class _LiveRoomCardState extends State<_LiveRoomCard> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = _focused || _hovered || widget.active;
    final artwork = widget.room.program?.thumbnail.trim().isNotEmpty == true
        ? widget.room.program!.thumbnail
        : widget.room.thumbnail;
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: AnimatedScale(
        scale: highlighted && widget.tvMode ? 1.035 : 1,
        duration: const Duration(milliseconds: 160),
        child: Material(
          color: highlighted
              ? Theme.of(
                  context,
                ).colorScheme.surfaceContainer.withValues(alpha: 0.86)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('live-radio-${widget.room.id}'),
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [ZingColors.coral, ZingColors.purpleBright],
                          ),
                          boxShadow: highlighted
                              ? [
                                  BoxShadow(
                                    color: ZingColors.coral.withValues(
                                      alpha: 0.36,
                                    ),
                                    blurRadius: 24,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : const [],
                        ),
                        child: AlbumArt(
                          imageUrl: artwork,
                          semanticLabel: 'Ảnh Phòng Nhạc ${widget.room.title}',
                          size: widget.imageSize,
                          borderRadius: widget.imageSize,
                        ),
                      ),
                      Positioned(
                        left: 12,
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ZingColors.coral,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            widget.playing ? 'LIVE • ĐANG NGHE' : 'LIVE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                      ),
                      if (widget.active)
                        Positioned(
                          right: 5,
                          bottom: 1,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: ZingColors.lime,
                            foregroundColor: ZingColors.ink,
                            child: Icon(
                              widget.playing
                                  ? Icons.graphic_eq_rounded
                                  : Icons.play_arrow_rounded,
                              size: 22,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.room.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: widget.tvMode ? 20 : 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.room.nowPlayingTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: widget.tvMode ? 14 : 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${_formatListeners(widget.room.listenerCount)} người đang nghe',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ZingColors.coral,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot();

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: const BoxDecoration(
      color: ZingColors.coral,
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: ZingColors.coral, blurRadius: 8)],
    ),
  );
}

class _LiveRadioMessage extends StatelessWidget {
  const _LiveRadioMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          children: [
            Icon(icon, size: 54, color: ZingColors.coral),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    ),
  );
}

String _formatListeners(int value) {
  if (value >= 1_000_000) {
    return '${_compactNumber(value / 1_000_000, whole: value >= 10_000_000)}M';
  }
  if (value >= 1000) {
    return '${_compactNumber(value / 1000, whole: value >= 100_000)}K';
  }
  return '$value';
}

String _compactNumber(double value, {required bool whole}) {
  final text = value.toStringAsFixed(whole ? 0 : 1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}
