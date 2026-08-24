import 'dart:ui';

import 'package:share_plus/share_plus.dart';

enum OfficialContentKind { song, artist, collection }

class OfficialContentShare {
  const OfficialContentShare({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.externalUrl,
  });

  final OfficialContentKind kind;
  final String title;
  final String subtitle;
  final String externalUrl;

  String get kindLabel => switch (kind) {
    OfficialContentKind.song => 'bài hát',
    OfficialContentKind.artist => 'nghệ sĩ',
    OfficialContentKind.collection => 'playlist/album',
  };

  String get message {
    final attribution = subtitle.trim();
    return [
      title.trim(),
      if (attribution.isNotEmpty) attribution,
      externalUrl,
      'Chia sẻ từ #zingChart',
    ].join('\n');
  }
}

enum OfficialContentShareResult { shared, unavailable }

abstract interface class OfficialContentShareService {
  Future<OfficialContentShareResult> share(
    OfficialContentShare content, {
    Rect? origin,
  });
}

class SharePlusOfficialContentShareService
    implements OfficialContentShareService {
  const SharePlusOfficialContentShareService();

  @override
  Future<OfficialContentShareResult> share(
    OfficialContentShare content, {
    Rect? origin,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        title: content.title,
        subject: content.title,
        text: content.message,
        sharePositionOrigin: origin,
      ),
    );
    return result.status == ShareResultStatus.unavailable
        ? OfficialContentShareResult.unavailable
        : OfficialContentShareResult.shared;
  }
}
