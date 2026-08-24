import 'package:flutter/widgets.dart';

import 'music_player_controller.dart';

class MusicPlayerScope extends InheritedNotifier<MusicPlayerController> {
  const MusicPlayerScope({
    super.key,
    required MusicPlayerController controller,
    required super.child,
  }) : super(notifier: controller);

  static MusicPlayerController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<MusicPlayerScope>();
    assert(scope != null, 'MusicPlayerScope is missing above this context.');
    return scope!.notifier!;
  }

  /// Reads the player without rebuilding when high-frequency playback values
  /// such as position or duration change.
  static MusicPlayerController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<MusicPlayerScope>();
    assert(scope != null, 'MusicPlayerScope is missing above this context.');
    return scope!.notifier!;
  }
}
