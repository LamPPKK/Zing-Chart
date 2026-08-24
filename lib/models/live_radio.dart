class LiveRadioProgram {
  const LiveRadioProgram({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.description,
    required this.startTime,
    required this.endTime,
  });

  final String id;
  final String title;
  final String thumbnail;
  final String description;
  final DateTime? startTime;
  final DateTime? endTime;
}

class LiveRadioRoom {
  const LiveRadioRoom({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.listenerCount,
    required this.hostName,
    required this.hostThumbnail,
    this.program,
  });

  final String id;
  final String title;
  final String description;
  final String thumbnail;
  final int listenerCount;
  final String hostName;
  final String hostThumbnail;
  final LiveRadioProgram? program;

  String get nowPlayingTitle =>
      program?.title.trim().isNotEmpty == true ? program!.title : description;
}

class LiveRadioSnapshot {
  const LiveRadioSnapshot({required this.updatedAt, required this.rooms});

  const LiveRadioSnapshot.empty() : this(updatedAt: null, rooms: const []);

  final DateTime? updatedAt;
  final List<LiveRadioRoom> rooms;

  bool get isEmpty => rooms.isEmpty;
}
