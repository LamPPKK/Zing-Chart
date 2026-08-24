import 'package:flutter/material.dart';

import '../models/search_suggestions.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';

class SearchSuggestionDropdown extends StatelessWidget {
  const SearchSuggestionDropdown({
    super.key,
    required this.query,
    required this.snapshot,
    required this.loading,
    required this.errorMessage,
    required this.highlightedIndex,
    required this.onKeywordTap,
    required this.onSongTap,
    required this.onSearchAll,
    required this.onHighlightChanged,
    this.loadingSongId,
    this.tvMode = false,
  });

  final String query;
  final SearchSuggestionSnapshot? snapshot;
  final bool loading;
  final String? errorMessage;
  final int highlightedIndex;
  final ValueChanged<String> onKeywordTap;
  final ValueChanged<SearchSuggestionSong> onSongTap;
  final VoidCallback onSearchAll;
  final ValueChanged<int> onHighlightChanged;
  final String? loadingSongId;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final keywords = snapshot?.keywords ?? const <String>[];
    final songs = snapshot?.songs ?? const <SearchSuggestionSong>[];
    final searchAllIndex = keywords.length;
    final songStartIndex = searchAllIndex + 1;
    return Material(
      key: const ValueKey('search-suggestion-dropdown'),
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxHeight: tvMode ? 680 : 540),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(tvMode ? 22 : 16),
          border: Border.all(
            color: ZingColors.purpleBright.withValues(alpha: 0.34),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.42),
              blurRadius: 34,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) const LinearProgressIndicator(minHeight: 3),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(vertical: tvMode ? 10 : 7),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < keywords.length; index++)
                      _SuggestionActionRow(
                        key: ValueKey('search-keyword-$index'),
                        icon: Icons.search_rounded,
                        title: keywords[index],
                        highlighted: highlightedIndex == index,
                        onHover: (value) {
                          if (value) onHighlightChanged(index);
                        },
                        onTap: () => onKeywordTap(keywords[index]),
                        tvMode: tvMode,
                      ),
                    _SuggestionActionRow(
                      key: const ValueKey('search-suggestion-search-all'),
                      icon: Icons.manage_search_rounded,
                      title: 'Tìm kiếm “$query”',
                      highlighted: highlightedIndex == searchAllIndex,
                      onHover: (value) {
                        if (value) onHighlightChanged(searchAllIndex);
                      },
                      onTap: onSearchAll,
                      emphasized: true,
                      tvMode: tvMode,
                    ),
                    if (songs.isNotEmpty) ...[
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          tvMode ? 20 : 16,
                          tvMode ? 17 : 13,
                          tvMode ? 20 : 16,
                          tvMode ? 10 : 7,
                        ),
                        child: Text(
                          'GỢI Ý KẾT QUẢ',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: tvMode ? 13 : 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      for (var index = 0; index < songs.length; index++)
                        _SuggestionSongRow(
                          key: ValueKey(
                            'search-suggestion-song-${songs[index].id}',
                          ),
                          song: songs[index],
                          loading: loadingSongId == songs[index].id,
                          highlighted:
                              highlightedIndex == songStartIndex + index,
                          onHover: (value) {
                            if (value) {
                              onHighlightChanged(songStartIndex + index);
                            }
                          },
                          onTap: () => onSongTap(songs[index]),
                          tvMode: tvMode,
                        ),
                    ] else if (!loading && errorMessage != null) ...[
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          tvMode ? 20 : 16,
                          8,
                          tvMode ? 20 : 16,
                          tvMode ? 16 : 12,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.cloud_off_rounded,
                              color: ZingColors.coral,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Chưa tải được gợi ý. Bạn vẫn có thể tìm kiếm từ khóa này.',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: tvMode ? 15 : 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionActionRow extends StatelessWidget {
  const _SuggestionActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.highlighted,
    required this.onHover,
    required this.onTap,
    required this.tvMode,
    this.emphasized = false,
  });

  final IconData icon;
  final String title;
  final bool highlighted;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;
  final bool tvMode;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: highlighted,
    child: InkWell(
      onTap: onTap,
      onHover: onHover,
      canRequestFocus: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: highlighted
            ? ZingColors.purple.withValues(alpha: 0.34)
            : Colors.transparent,
        padding: EdgeInsets.symmetric(
          horizontal: tvMode ? 20 : 16,
          vertical: tvMode ? 15 : 11,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: highlighted
                  ? ZingColors.lime
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: tvMode ? 27 : 20,
            ),
            SizedBox(width: tvMode ? 15 : 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: tvMode ? 18 : 14,
                  fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.north_west_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: tvMode ? 23 : 17,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SuggestionSongRow extends StatelessWidget {
  const _SuggestionSongRow({
    super.key,
    required this.song,
    required this.loading,
    required this.highlighted,
    required this.onHover,
    required this.onTap,
    required this.tvMode,
  });

  final SearchSuggestionSong song;
  final bool loading;
  final bool highlighted;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;
  final bool tvMode;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: !loading,
    selected: highlighted,
    label: loading
        ? 'Đang mở thông tin ${song.title} của ${song.artist}'
        : 'Mở thông tin ${song.title} của ${song.artist}',
    child: InkWell(
      onTap: loading ? null : onTap,
      onHover: onHover,
      canRequestFocus: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: highlighted
            ? ZingColors.purple.withValues(alpha: 0.34)
            : Colors.transparent,
        padding: EdgeInsets.symmetric(
          horizontal: tvMode ? 20 : 16,
          vertical: tvMode ? 10 : 7,
        ),
        child: Row(
          children: [
            AlbumArt(
              imageUrl: song.thumbnail,
              semanticLabel: 'Ảnh bìa ${song.title}',
              size: tvMode ? 68 : 50,
              borderRadius: tvMode ? 12 : 9,
            ),
            SizedBox(width: tvMode ? 15 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: tvMode ? 18 : 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: tvMode ? 14 : 11,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: tvMode ? 12 : 8),
            if (loading)
              SizedBox.square(
                dimension: tvMode ? 27 : 20,
                child: const CircularProgressIndicator(strokeWidth: 2.4),
              )
            else
              Icon(
                Icons.arrow_outward_rounded,
                color: highlighted ? ZingColors.lime : ZingColors.purpleBright,
                size: tvMode ? 27 : 20,
              ),
          ],
        ),
      ),
    ),
  );
}
