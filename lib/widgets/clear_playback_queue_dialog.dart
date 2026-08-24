import 'package:flutter/material.dart';

import '../music_player_controller.dart';

Future<void> showClearPlaybackQueueDialog(
  BuildContext context, {
  required MusicPlayerController controller,
}) async {
  if (!controller.canClearPlaybackQueue) return;
  final current = controller.currentSong;
  final queuedCount = controller.queue
      .where((song) => song.id != current?.id)
      .length;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('clear-playback-queue-dialog'),
      icon: const Icon(Icons.playlist_remove_rounded),
      title: const Text('Xóa hàng đợi?'),
      content: Text(
        'Giữ “${current?.displayTitle ?? 'bài đang phát'}” và xóa '
        '$queuedCount bài còn lại khỏi danh sách phát.',
      ),
      actions: [
        TextButton(
          key: const ValueKey('cancel-clear-playback-queue'),
          autofocus: true,
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Ở LẠI'),
        ),
        FilledButton.tonalIcon(
          key: const ValueKey('confirm-clear-playback-queue'),
          onPressed: () => Navigator.pop(dialogContext, true),
          icon: const Icon(Icons.delete_sweep_outlined),
          label: const Text('XÓA'),
        ),
      ],
    ),
  );
  if (confirmed == true) controller.clearPlaybackQueue();
}
