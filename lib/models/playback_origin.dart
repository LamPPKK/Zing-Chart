enum PlaybackOriginKind {
  chart,
  newReleaseChart,
  weeklyChart,
  search,
  collection,
  artist,
  discovery,
  recommendations,
  recentlyPlayed,
  releaseCatalog,
  library,
  playlist,
  forYou,
  songRadio,
  liveRadio,
  other,
}

class PlaybackOrigin {
  const PlaybackOrigin({required this.kind, required this.label});

  const PlaybackOrigin.chart()
    : kind = PlaybackOriginKind.chart,
      label = '#zingChart';

  final PlaybackOriginKind kind;
  final String label;

  Map<String, dynamic> toJson() => {'kind': kind.name, 'label': label};

  factory PlaybackOrigin.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      return const PlaybackOrigin.chart();
    }
    final rawKind = value['kind'];
    final rawLabel = value['label'];
    if (rawKind is! String || rawLabel is! String) {
      return const PlaybackOrigin.chart();
    }
    final label = sanitizeLabel(rawLabel);
    PlaybackOriginKind? kind;
    for (final candidate in PlaybackOriginKind.values) {
      if (candidate.name == rawKind) {
        kind = candidate;
        break;
      }
    }
    if (kind == null || label.isEmpty) return const PlaybackOrigin.chart();
    return PlaybackOrigin(kind: kind, label: label);
  }

  static String sanitizeLabel(String value) {
    final normalized = value
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return String.fromCharCodes(normalized.runes.take(96));
  }
}
