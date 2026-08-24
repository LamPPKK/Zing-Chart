import 'catalog_search.dart';

class DiscoveryCategory {
  const DiscoveryCategory({required this.id, required this.name});

  final String id;
  final String name;
}

class DiscoveryCategories {
  const DiscoveryCategories({required this.updatedAt, required this.items});

  const DiscoveryCategories.empty() : this(updatedAt: null, items: const []);

  final DateTime? updatedAt;
  final List<DiscoveryCategory> items;

  bool get isEmpty => items.isEmpty;
}

class DiscoveryRecommendations {
  const DiscoveryRecommendations({
    required this.updatedAt,
    required this.entries,
    required this.catalogPlaybackEnabled,
  });

  const DiscoveryRecommendations.empty()
    : updatedAt = null,
      entries = const [],
      catalogPlaybackEnabled = false;

  final DateTime? updatedAt;
  final List<CatalogSong> entries;
  final bool catalogPlaybackEnabled;

  List<CatalogSong> get playableEntries =>
      entries.where((entry) => entry.playable).toList(growable: false);

  bool get isEmpty => entries.isEmpty;
}

class DiscoveryBanner {
  const DiscoveryBanner({
    required this.id,
    required this.image,
    this.collection,
  });

  final String id;
  final String image;
  final CatalogCollection? collection;
}

class DiscoveryCollection {
  const DiscoveryCollection({
    required this.collection,
    required this.description,
  });

  final CatalogCollection collection;
  final String description;
}

class DiscoverySection {
  const DiscoverySection({
    required this.id,
    required this.title,
    required this.collections,
  });

  final String id;
  final String title;
  final List<DiscoveryCollection> collections;
}

class DiscoveryHome {
  const DiscoveryHome({
    this.categoryId = '-1',
    required this.updatedAt,
    this.quickPlay = const [],
    required this.banners,
    this.videos = const [],
    required this.sections,
  });

  const DiscoveryHome.empty([this.categoryId = '-1'])
    : updatedAt = null,
      quickPlay = const [],
      banners = const [],
      videos = const [],
      sections = const [];

  final String categoryId;
  final DateTime? updatedAt;
  final List<DiscoveryCollection> quickPlay;
  final List<DiscoveryBanner> banners;
  final List<CatalogVideo> videos;
  final List<DiscoverySection> sections;

  bool get isEmpty =>
      quickPlay.isEmpty &&
      banners.isEmpty &&
      videos.isEmpty &&
      sections.isEmpty;
}
