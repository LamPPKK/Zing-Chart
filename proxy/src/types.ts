export interface SongDto {
  id: string;
  code: string;
  title: string;
  artist: string;
  artists?: SearchArtistDto[];
  albumCover: string;
  albumTitle: string;
  album?: SearchCollectionDto;
  durationSeconds: number;
  rank: number;
  rankChange: number;
}

export interface LyricLineDto {
  startTimeMs: number;
  endTimeMs: number;
  text: string;
  words?: LyricWordDto[];
}

export interface LyricWordDto {
  startTimeMs: number;
  endTimeMs: number;
  text: string;
}

export interface SongLyricsDto {
  songId: string;
  synced: boolean;
  lines: LyricLineDto[];
}

export interface SongRadioDto {
  seedId: string;
  songs: SearchSongDto[];
  catalogPlaybackEnabled: boolean;
}

export interface LiveRadioProgramDto {
  id: string;
  title: string;
  thumbnail: string;
  description: string;
  startTime: number;
  endTime: number;
}

export interface LiveRadioRoomDto {
  id: string;
  title: string;
  description: string;
  thumbnail: string;
  listenerCount: number;
  hostName: string;
  hostThumbnail: string;
  program?: LiveRadioProgramDto;
}

export interface LiveRadioSnapshotDto {
  updatedAt: number;
  rooms: LiveRadioRoomDto[];
}

export type StreamQuality = 'auto' | '128' | '320';

export interface ChartPointDto {
  time: number;
  hour: string;
  counter: number;
}

export interface ChartSnapshotDto {
  songs: SongDto[];
  series: Record<string, ChartPointDto[]>;
  minScore: number;
  maxScore: number;
  updatedAt: number;
}

export interface NewReleaseSongDto {
  id: string;
  code: string;
  title: string;
  artist: string;
  artists?: SearchArtistDto[];
  albumCover: string;
  albumTitle: string;
  album?: SearchCollectionDto;
  durationSeconds: number;
  externalUrl: string;
  rank: number;
  rankChange: number;
  releasedAt: number;
  playable: boolean;
}

export interface NewReleaseSnapshotDto {
  title: string;
  updatedAt: number;
  songs: NewReleaseSongDto[];
  catalogPlaybackEnabled: boolean;
}

export type WeeklyChartRegion = 'vietnam' | 'usuk' | 'korea';

export interface WeeklyChartSongDto extends SearchSongDto {
  albumTitle: string;
  rank: number;
  rankChange: number;
  score: number;
}

export interface WeeklyChartDto {
  region: WeeklyChartRegion;
  title: string;
  week: number;
  year: number;
  latestWeek: number;
  startDate: string;
  endDate: string;
  updatedAt: number;
  songs: WeeklyChartSongDto[];
  catalogPlaybackEnabled: boolean;
}

export interface DiscoveryCollectionDto extends SearchCollectionDto {
  description: string;
}

export interface DiscoveryBannerDto {
  id: string;
  image: string;
  collection?: SearchCollectionDto;
}

export interface DiscoverySectionDto {
  id: string;
  title: string;
  collections: DiscoveryCollectionDto[];
}

export interface DiscoveryHomeDto {
  categoryId: string;
  updatedAt: number;
  quickPlay: DiscoveryCollectionDto[];
  banners: DiscoveryBannerDto[];
  videos: SearchVideoDto[];
  sections: DiscoverySectionDto[];
}

export interface DiscoveryCategoryDto {
  id: string;
  name: string;
}

export interface DiscoveryCategoriesDto {
  updatedAt: number;
  items: DiscoveryCategoryDto[];
}

export interface DiscoveryRecommendationsDto {
  updatedAt: number;
  songs: SearchSongDto[];
  catalogPlaybackEnabled: boolean;
}

export interface CatalogHubDto {
  id: string;
  title: string;
  description: string;
  image: string;
  externalUrl: string;
  collections: DiscoveryCollectionDto[];
}

export interface HubHomeDto {
  updatedAt: number;
  featured: CatalogHubDto[];
  nations: CatalogHubDto[];
  topics: CatalogHubDto[];
  genres: CatalogHubDto[];
}

export interface HubDetailDto extends CatalogHubDto {
  sections: DiscoverySectionDto[];
}

export interface Top100SnapshotDto {
  updatedAt: number;
  sections: DiscoverySectionDto[];
}

export type ReleaseRegion = 'vietnam' | 'usuk' | 'korea' | 'other';

export interface ReleaseSongDto extends SearchSongDto {
  releasedAt: number;
  region: ReleaseRegion;
}

export interface ReleaseAlbumDto extends SearchCollectionDto {
  releasedAt: number;
  region: ReleaseRegion;
}

export interface ReleaseCatalogDto {
  updatedAt: number;
  songs: ReleaseSongDto[];
  albums: ReleaseAlbumDto[];
  catalogPlaybackEnabled: boolean;
}

export interface SearchSongDto {
  id: string;
  code: string;
  title: string;
  artist: string;
  artists?: SearchArtistDto[];
  albumCover: string;
  album?: SearchCollectionDto;
  durationSeconds: number;
  externalUrl: string;
  playable: boolean;
  hasLyrics?: boolean;
}

export interface SearchVideoDto {
  id: string;
  title: string;
  artist: string;
  artists?: SearchArtistDto[];
  thumbnail: string;
  durationSeconds: number;
  externalUrl: string;
}

export interface SongDetailDto {
  song: SearchSongDto;
  artists: SearchArtistDto[];
  album?: SearchCollectionDto;
  releasedAt: number;
  distributor: string;
  genres: string[];
  composers: SearchArtistDto[];
  listenCount: number;
  likeCount: number;
  commentCount: number;
  mv?: SearchVideoDto;
  catalogPlaybackEnabled: boolean;
}

export interface SearchArtistDto {
  id: string;
  name: string;
  aliasName: string;
  avatar: string;
  externalUrl: string;
  totalFollow?: number;
}

export interface ArtistCollectionSectionDto {
  id: string;
  title: string;
  collections: SearchCollectionDto[];
}

export interface ArtistDetailDto {
  artist: SearchArtistDto;
  cover: string;
  biography: string;
  realName: string;
  national: string;
  birthday: string;
  totalFollow: number;
  awardCount: number;
  featuredSongs?: SearchSongDto[];
  songs: SearchSongDto[];
  videos: SearchVideoDto[];
  collectionSections: ArtistCollectionSectionDto[];
  relatedArtists: SearchArtistDto[];
  catalogPlaybackEnabled: boolean;
}

export type CollectionKind = 'playlist' | 'album';

export interface SearchCollectionDto {
  id: string;
  title: string;
  artist: string;
  artists?: SearchArtistDto[];
  thumbnail: string;
  kind: CollectionKind;
  externalUrl: string;
}

export interface CollectionDetailDto extends SearchCollectionDto {
  artists: SearchArtistDto[];
  description: string;
  year: string;
  releasedAt: number;
  distributor: string;
  likeCount: number;
  genres: string[];
  songs: SearchSongDto[];
  sections: DiscoverySectionDto[];
  catalogPlaybackEnabled: boolean;
}

export interface SearchSnapshotDto {
  query: string;
  songs: SearchSongDto[];
  artists: SearchArtistDto[];
  collections: SearchCollectionDto[];
  videos?: SearchVideoDto[];
  catalogPlaybackEnabled: boolean;
}

export type SearchResultType =
  | 'songs'
  | 'artists'
  | 'collections'
  | 'videos';

interface SearchPageBaseDto {
  query: string;
  page: number;
  limit: number;
  total: number | null;
  hasMore: boolean;
  catalogPlaybackEnabled: boolean;
}

export type SearchPageDto =
  | (SearchPageBaseDto & { type: 'songs'; items: SearchSongDto[] })
  | (SearchPageBaseDto & { type: 'artists'; items: SearchArtistDto[] })
  | (SearchPageBaseDto & {
    type: 'collections';
    items: SearchCollectionDto[];
  })
  | (SearchPageBaseDto & { type: 'videos'; items: SearchVideoDto[] });

export interface SearchSuggestionSongDto {
  id: string;
  title: string;
  artist: string;
  thumbnail: string;
  durationSeconds: number;
  externalUrl: string;
}

export interface SearchSuggestionSnapshotDto {
  query: string;
  keywords: string[];
  songs: SearchSuggestionSongDto[];
}

export interface MusicUpstream {
  readonly supportsPaginatedSearch?: boolean;
  fetchChart(signal?: AbortSignal): Promise<ChartSnapshotDto>;
  fetchNewReleases?(signal?: AbortSignal): Promise<NewReleaseSnapshotDto>;
  fetchWeeklyChart?(
    region: WeeklyChartRegion,
    week?: number,
    year?: number,
    signal?: AbortSignal,
  ): Promise<WeeklyChartDto>;
  fetchDiscovery?(
    categoryId: string,
    signal?: AbortSignal,
  ): Promise<DiscoveryHomeDto>;
  fetchDiscoveryCategories?(
    signal?: AbortSignal,
  ): Promise<DiscoveryCategoriesDto>;
  fetchDiscoveryRecommendations?(
    signal?: AbortSignal,
  ): Promise<DiscoveryRecommendationsDto>;
  fetchHubHome?(signal?: AbortSignal): Promise<HubHomeDto>;
  fetchHubDetail?(id: string, signal?: AbortSignal): Promise<HubDetailDto>;
  fetchTop100?(signal?: AbortSignal): Promise<Top100SnapshotDto>;
  fetchReleaseCatalog?(signal?: AbortSignal): Promise<ReleaseCatalogDto>;
  fetchArtistDetail?(
    alias: string,
    signal?: AbortSignal,
  ): Promise<ArtistDetailDto>;
  fetchSearch(query: string, signal?: AbortSignal): Promise<SearchSnapshotDto>;
  fetchSearchPage?(
    query: string,
    type: SearchResultType,
    page: number,
    limit: number,
    signal?: AbortSignal,
  ): Promise<SearchPageDto>;
  fetchSearchSuggestions?(
    query: string,
    signal?: AbortSignal,
  ): Promise<SearchSuggestionSnapshotDto>;
  fetchCollection(id: string, signal?: AbortSignal): Promise<CollectionDetailDto>;
  fetchSongDetail?(id: string, signal?: AbortSignal): Promise<SongDetailDto>;
  fetchLyrics?(code: string, signal?: AbortSignal): Promise<SongLyricsDto>;
  fetchSongRadio?(code: string, signal?: AbortSignal): Promise<SongRadioDto>;
  fetchLiveRadio?(signal?: AbortSignal): Promise<LiveRadioSnapshotDto>;
  resolveLiveRadioStream?(id: string, signal?: AbortSignal): Promise<string>;
  fetchSource(
    code: string,
    signal?: AbortSignal,
    quality?: StreamQuality,
  ): Promise<string>;
}

export class UpstreamError extends Error {
  constructor(
    message: string,
    readonly status?: number,
  ) {
    super(message);
    this.name = 'UpstreamError';
  }
}
