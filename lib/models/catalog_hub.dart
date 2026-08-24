import 'discovery_home.dart';

class CatalogHub {
  const CatalogHub({
    required this.id,
    required this.title,
    required this.description,
    required this.image,
    required this.externalUrl,
    this.collections = const [],
  });

  final String id;
  final String title;
  final String description;
  final String image;
  final String externalUrl;
  final List<DiscoveryCollection> collections;
}

class CatalogHubHome {
  const CatalogHubHome({
    required this.updatedAt,
    required this.featured,
    required this.nations,
    required this.topics,
    required this.genres,
  });

  const CatalogHubHome.empty()
    : this(
        updatedAt: null,
        featured: const [],
        nations: const [],
        topics: const [],
        genres: const [],
      );

  final DateTime? updatedAt;
  final List<CatalogHub> featured;
  final List<CatalogHub> nations;
  final List<CatalogHub> topics;
  final List<CatalogHub> genres;

  bool get isEmpty =>
      featured.isEmpty && nations.isEmpty && topics.isEmpty && genres.isEmpty;
}

class CatalogHubDetail {
  const CatalogHubDetail({required this.hub, required this.sections});

  final CatalogHub hub;
  final List<DiscoverySection> sections;
}

class Top100Catalog {
  const Top100Catalog({required this.updatedAt, required this.sections});

  const Top100Catalog.empty() : this(updatedAt: null, sections: const []);

  final DateTime? updatedAt;
  final List<DiscoverySection> sections;

  bool get isEmpty => sections.isEmpty;
}
