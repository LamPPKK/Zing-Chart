import 'package:flutter/material.dart';

import '../models/catalog_search.dart';

/// Compact, accessible artist links for catalog cards and song rows.
class CatalogArtistLinks extends StatelessWidget {
  const CatalogArtistLinks({
    super.key,
    required this.artists,
    required this.onArtistTap,
    required this.keyPrefix,
    this.tvMode = false,
    this.touchLayout = false,
    this.maxVisible = 2,
  });

  final List<CatalogArtist> artists;
  final ValueChanged<CatalogArtist> onArtistTap;
  final String keyPrefix;
  final bool tvMode;
  final bool touchLayout;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final visibleArtists = artists.take(maxVisible).toList(growable: false);
    final hiddenCount = artists.length - visibleArtists.length;
    final foreground = Theme.of(context).colorScheme.onSurfaceVariant;
    final targetHeight = tvMode
        ? 48.0
        : touchLayout
        ? 44.0
        : 34.0;
    final fontSize = tvMode ? 14.0 : 11.0;
    return SizedBox(
      height: targetHeight,
      child: Row(
        children: [
          for (var index = 0; index < visibleArtists.length; index++) ...[
            if (index > 0)
              Text(
                ', ',
                style: TextStyle(color: foreground, fontSize: fontSize),
              ),
            Flexible(
              child: Semantics(
                link: true,
                label: 'Mở nghệ sĩ ${visibleArtists[index].name}',
                child: TextButton(
                  key: ValueKey('$keyPrefix-${visibleArtists[index].id}'),
                  onPressed: () => onArtistTap(visibleArtists[index]),
                  style: TextButton.styleFrom(
                    foregroundColor: foreground,
                    minimumSize: Size(44, targetHeight),
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(
                    visibleArtists[index].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
          if (hiddenCount > 0) ...[
            const SizedBox(width: 2),
            Text(
              '+$hiddenCount',
              style: TextStyle(
                color: foreground,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
