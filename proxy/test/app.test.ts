import { afterEach, describe, expect, it, vi } from 'vitest';
import { buildApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import type {
  ArtistDetailDto,
  ArtistSongPageDto,
  ChartSnapshotDto,
  CollectionDetailDto,
  DiscoveryCategoriesDto,
  DiscoveryHomeDto,
  DiscoveryRecommendationsDto,
  HubDetailDto,
  HubHomeDto,
  LiveRadioSnapshotDto,
  MusicUpstream,
  NewReleaseSnapshotDto,
  ReleaseCatalogDto,
  SearchPageDto,
  SearchSuggestionSnapshotDto,
  SearchSnapshotDto,
  SongDto,
  SongDetailDto,
  SongLyricsDto,
  SongRadioDto,
  Top100SnapshotDto,
  WeeklyChartDto,
} from '../src/types.js';
import { UpstreamError } from '../src/types.js';

const song: SongDto = {
  id: 'song-1',
  code: 'ABC123',
  title: 'Nàng thơ',
  artist: 'Hoàng Dũng',
  artists: [{
    id: 'artist-1',
    name: 'Hoàng Dũng',
    aliasName: 'Hoang-Dung',
    avatar: 'https://example.test/artist.jpg',
    externalUrl: 'https://zingmp3.vn/nghe-si/Hoang-Dung',
  }],
  albumCover: 'https://example.test/cover.jpg',
  albumTitle: 'Nàng thơ (Single)',
  album: {
    id: 'album-1',
    title: 'Nàng thơ (Single)',
    artist: 'Hoàng Dũng',
    thumbnail: 'https://example.test/cover.jpg',
    kind: 'album',
    externalUrl: 'https://zingmp3.vn/album/nang-tho/album-1.html',
  },
  durationSeconds: 254,
  rank: 1,
  rankChange: 2,
};

const snapshot: ChartSnapshotDto = {
  songs: [song],
  series: {
    'song-1': [
      { time: 1000, hour: '08', counter: 100 },
      { time: 2000, hour: '09', counter: 140 },
    ],
  },
  minScore: 0,
  maxScore: 140,
  updatedAt: 2000,
};

const searchSnapshot: SearchSnapshotDto = {
  query: 'nàng thơ',
  catalogPlaybackEnabled: false,
  songs: [{
    id: 'song-1',
    code: 'song-1',
    title: 'Nàng thơ',
    artist: 'Hoàng Dũng',
    albumCover: 'https://example.test/search-cover.jpg',
    durationSeconds: 254,
    externalUrl: 'https://zingmp3.vn/link/song/song-1',
    playable: false,
    hasLyrics: true,
  }],
  artists: [{
    id: 'artist-1',
    name: 'Hoàng Dũng',
    aliasName: 'Hoang-Dung',
    avatar: 'https://example.test/artist.jpg',
    externalUrl: 'https://zingmp3.vn/nghe-si/Hoang-Dung',
  }],
  collections: [],
  videos: [{
    id: 'video-1',
    title: 'Nàng thơ (MV)',
    artist: 'Hoàng Dũng',
    thumbnail: 'https://example.test/video.jpg',
    durationSeconds: 254,
    externalUrl: 'https://zingmp3.vn/video-clip/nang-tho/video-1.html',
  }],
};

const searchSuggestions: SearchSuggestionSnapshotDto = {
  query: 'nàng',
  keywords: ['nàng thơ', 'nàng thơ remix'],
  songs: [{
    id: 'song-1',
    title: 'Nàng thơ',
    artist: 'Hoàng Dũng',
    thumbnail: 'https://example.test/search-cover.jpg',
    durationSeconds: 254,
    externalUrl: 'https://zingmp3.vn/link/song/song-1',
  }],
};

const searchSongPage: SearchPageDto = {
  query: 'nàng thơ',
  type: 'songs',
  page: 1,
  limit: 18,
  total: 37,
  hasMore: true,
  items: searchSnapshot.songs,
  catalogPlaybackEnabled: true,
};

const discoveryRecommendations: DiscoveryRecommendationsDto = {
  updatedAt: 1_787_249_100_000,
  catalogPlaybackEnabled: true,
  songs: [{
    id: 'recommended-1',
    code: 'RECOMMENDED1',
    title: 'Bài hát gợi ý',
    artist: 'Nghệ sĩ A',
    albumCover: 'https://example.test/recommended.jpg',
    durationSeconds: 245,
    externalUrl: 'https://zingmp3.vn/bai-hat/goi-y/RECOMMENDED1.html',
    playable: true,
  }],
};

const collectionDetail: CollectionDetailDto = {
  id: 'COLLECTION1',
  title: 'Tuyển tập Nàng thơ',
  artist: 'Hoàng Dũng',
  thumbnail: 'https://example.test/collection.jpg',
  kind: 'playlist',
  externalUrl: 'https://zingmp3.vn/album/tuyen-tap/COLLECTION1.html',
  artists: [{
    id: 'ARTIST1',
    name: 'Hoàng Dũng',
    aliasName: 'Hoang-Dung',
    avatar: 'https://example.test/artist.jpg',
    externalUrl: 'https://zingmp3.vn/nghe-si/Hoang-Dung',
  }],
  description: 'Những bài hát nổi bật',
  year: '2026',
  releasedAt: 1_787_240_400_000,
  distributor: 'Zing Music Distribution',
  likeCount: 2_200_000,
  genres: ['V-Pop'],
  songs: searchSnapshot.songs,
  sections: [],
  catalogPlaybackEnabled: false,
};

const newReleaseSnapshot: NewReleaseSnapshotDto = {
  title: 'BXH Nhạc Mới',
  updatedAt: 1_787_248_103_000,
  catalogPlaybackEnabled: true,
  songs: [{
    id: 'NEW1',
    code: 'NEW1',
    title: 'Bài hát mới',
    artist: 'Nghệ sĩ mới',
    albumCover: 'https://example.test/new.jpg',
    albumTitle: 'Single mới',
    durationSeconds: 218,
    externalUrl: 'https://zingmp3.vn/bai-hat/new/NEW1.html',
    rank: 1,
    rankChange: 2,
    releasedAt: 1_787_200_000,
    playable: true,
  }],
};

const weeklyChart: WeeklyChartDto = {
  region: 'vietnam',
  title: 'Bảng Xếp Hạng Tuần',
  week: 33,
  year: 2026,
  latestWeek: 33,
  startDate: '10/08',
  endDate: '16/08',
  updatedAt: 1_787_248_103_000,
  catalogPlaybackEnabled: true,
  songs: [{
    id: 'WEEKLY1',
    code: 'WEEKLY1',
    title: 'Bài hát tuần',
    artist: 'Nghệ sĩ tuần',
    albumCover: 'https://example.test/weekly.jpg',
    albumTitle: 'Album tuần',
    durationSeconds: 225,
    externalUrl: 'https://zingmp3.vn/bai-hat/weekly/WEEKLY1.html',
    playable: true,
    rank: 1,
    rankChange: 2,
    score: 2526,
  }],
};

const songLyrics: SongLyricsDto = {
  songId: 'ABC123',
  synced: true,
  lines: [
    { startTimeMs: 1200, endTimeMs: 2400, text: 'Dòng đầu tiên' },
    { startTimeMs: 2800, endTimeMs: 4100, text: 'Dòng tiếp theo' },
  ],
};

const songDetail: SongDetailDto = {
  song: {
    id: 'ABC123',
    code: 'ABC123',
    title: 'Nàng thơ',
    artist: 'Hoàng Dũng',
    albumCover: 'https://example.test/song-detail.jpg',
    durationSeconds: 254,
    externalUrl: 'https://zingmp3.vn/bai-hat/nang-tho/ABC123.html',
    playable: true,
    hasLyrics: true,
  },
  artists: searchSnapshot.artists,
  album: {
    id: 'ALBUM1',
    title: 'Nàng thơ (Single)',
    artist: 'Hoàng Dũng',
    thumbnail: 'https://example.test/song-detail.jpg',
    kind: 'album',
    externalUrl: 'https://zingmp3.vn/album/nang-tho/ALBUM1.html',
  },
  releasedAt: 1_602_086_400_000,
  distributor: 'Sony Music Entertainment',
  genres: ['Việt Nam', 'V-Pop'],
  composers: searchSnapshot.artists,
  listenCount: 12_345_678,
  likeCount: 987_654,
  commentCount: 321,
  mv: searchSnapshot.videos![0]!,
  catalogPlaybackEnabled: true,
};

const songRadio: SongRadioDto = {
  seedId: 'ABC123',
  catalogPlaybackEnabled: true,
  songs: [{
    id: 'RADIO1',
    code: 'RADIO1',
    title: 'Bài hát tương tự',
    artist: 'Nghệ sĩ radio',
    albumCover: 'https://example.test/radio.jpg',
    durationSeconds: 221,
    externalUrl: 'https://zingmp3.vn/bai-hat/radio/RADIO1.html',
    playable: true,
  }],
};

const liveRadio: LiveRadioSnapshotDto = {
  updatedAt: 1_787_248_103_000,
  rooms: [{
    id: 'ROOM1',
    title: 'V-POP',
    description: 'Nhạc Việt thời nay',
    thumbnail: 'https://example.test/live-radio.jpg',
    listenerCount: 254,
    hostName: 'Zing MP3',
    hostThumbnail: 'https://example.test/live-host.jpg',
    program: {
      id: 'PROGRAM1',
      title: 'Yêu Cứ Để Đó',
      thumbnail: 'https://example.test/live-program.jpg',
      description: 'Nhạc trẻ được yêu thích',
      startTime: 1_787_248_000_000,
      endTime: 1_787_251_600_000,
    },
  }],
};

const discoveryHome: DiscoveryHomeDto = {
  categoryId: '-1',
  updatedAt: 1_787_249_000_000,
  quickPlay: [],
  banners: [{
    id: 'BANNER1',
    image: 'https://example.test/banner.jpg',
  }],
  videos: [],
  sections: [{
    id: 'top-100',
    title: 'Top 100',
    collections: [{
      id: 'TOP100',
      title: 'Top 100 Nhạc Trẻ',
      artist: 'Nhiều nghệ sĩ',
      thumbnail: 'https://example.test/top100.jpg',
      kind: 'playlist',
      externalUrl: 'https://zingmp3.vn/album/top-100/TOP100.html',
      description: 'Các ca khúc được nghe nhiều nhất.',
    }],
  }],
};

const discoveryCategories: DiscoveryCategoriesDto = {
  updatedAt: 1_787_249_000_000,
  items: [
    { id: '14', name: 'Thư giãn' },
    { id: '13', name: 'Làm việc' },
    { id: '21', name: 'Trending' },
    { id: '18', name: 'Ngủ ngon' },
    { id: '15', name: 'Tập luyện' },
  ],
};

const hubCollection = discoveryHome.sections[0]!.collections[0]!;

const hubHome: HubHomeDto = {
  updatedAt: 1_787_250_000_000,
  featured: [{
    id: 'HUBFEATURED',
    title: 'Top 100',
    description: 'Các ca khúc được nghe nhiều nhất.',
    image: 'https://example.test/hub-featured.jpg',
    externalUrl: 'https://zingmp3.vn/hub/top-100/HUBFEATURED.html',
    collections: [],
  }],
  nations: [],
  topics: [{
    id: 'HUBSLEEP',
    title: 'Ngủ Ngon',
    description: '',
    image: 'https://example.test/hub-sleep.jpg',
    externalUrl: 'https://zingmp3.vn/hub/ngu-ngon/HUBSLEEP.html',
    collections: [hubCollection],
  }],
  genres: [{
    id: 'HUBEDM',
    title: 'Dance/Electronic',
    description: '',
    image: 'https://example.test/hub-edm.jpg',
    externalUrl: 'https://zingmp3.vn/hub/edm/HUBEDM.html',
    collections: [hubCollection],
  }],
};

const hubDetail: HubDetailDto = {
  ...hubHome.topics[0]!,
  sections: discoveryHome.sections,
};

const top100Snapshot: Top100SnapshotDto = {
  updatedAt: 1_787_250_100_000,
  sections: discoveryHome.sections,
};

const releaseCatalog: ReleaseCatalogDto = {
  updatedAt: 1_787_254_000_000,
  catalogPlaybackEnabled: true,
  songs: [{
    id: 'RELEASESONG1',
    code: 'RELEASESONG1',
    title: 'Giữa Thiên Hà',
    artist: 'Yeolan, CoolKid',
    albumCover: 'https://example.test/release-song.jpg',
    durationSeconds: 174,
    externalUrl: 'https://zingmp3.vn/bai-hat/giua-thien-ha/RELEASESONG1.html',
    playable: true,
    releasedAt: 1_787_230_800,
    region: 'vietnam',
  }],
  albums: [{
    id: 'RELEASEALBUM1',
    title: 'Edge of Calm',
    artist: 'Tiffany Young',
    thumbnail: 'https://example.test/release-album.jpg',
    kind: 'album',
    externalUrl: 'https://zingmp3.vn/album/edge-of-calm/RELEASEALBUM1.html',
    releasedAt: 1_787_158_800,
    region: 'korea',
  }],
};

const artistDetail: ArtistDetailDto = {
  artist: {
    id: 'ARTIST1',
    name: 'Sơn Tùng M-TP',
    aliasName: 'Son-Tung-M-TP',
    avatar: 'https://example.test/artist.jpg',
    externalUrl: 'https://zingmp3.vn/nghe-si/Son-Tung-M-TP',
  },
  cover: 'https://example.test/artist-cover.jpg',
  biography: 'Nghệ sĩ V-Pop.',
  realName: 'Nguyễn Thanh Tùng',
  national: 'Việt Nam',
  birthday: '05/07/1994',
  totalFollow: 2_655_838,
  awardCount: 1,
  songs: searchSnapshot.songs,
  videos: searchSnapshot.videos ?? [],
  collectionSections: [{
    id: 'aAlbum-1',
    title: 'Album',
    collections: [collectionDetail],
  }],
  relatedArtists: searchSnapshot.artists,
  catalogPlaybackEnabled: true,
};

const artistSongPage: ArtistSongPageDto = {
  artistId: 'ARTIST1',
  page: 2,
  limit: 50,
  total: 137,
  hasMore: true,
  items: searchSnapshot.songs,
  catalogPlaybackEnabled: true,
};

const apps: Array<Awaited<ReturnType<typeof buildApp>>> = [];

function config(overrides: NodeJS.ProcessEnv = {}) {
  return loadConfig({
    NODE_ENV: 'test',
    CORS_ORIGINS: 'https://app.example.test',
    UPSTREAM_TIMEOUT_MS: '1000',
    CHART_CACHE_TTL_MS: '60000',
    RATE_LIMIT_MAX: '100',
    PUBLIC_BASE_URL: 'https://api.example.test',
    STREAM_TOKEN_SECRET: 'test-secret-at-least-thirty-two-characters',
    STREAM_HOSTS: 'stream.example.test',
    ...overrides,
  });
}

async function setup(upstream: MusicUpstream) {
  const app = await buildApp(config(), upstream);
  apps.push(app);
  return app;
}

afterEach(async () => {
  await Promise.all(apps.splice(0).map((app) => app.close()));
});

describe('proxy contract', () => {
  it('returns health, normalized chart, and source contracts', async () => {
    const upstream: MusicUpstream = {
      fetchChart: vi.fn().mockResolvedValue(snapshot),
      fetchSearch: vi.fn(), fetchCollection: vi.fn(),
      fetchSource: vi.fn().mockResolvedValue('https://stream.example.test/song.mp3'),
    };
    const app = await setup(upstream);

    const health = await app.inject({ method: 'GET', url: '/health' });
    const chart = await app.inject({ method: 'GET', url: '/v1/chart' });
    const source = await app.inject({ method: 'GET', url: '/v1/songs/ABC123/source' });

    expect(health.statusCode).toBe(200);
    expect(health.json()).toEqual({ status: 'ok' });
    expect(chart.json()).toEqual({
      songs: [song],
      chart: {
        series: snapshot.series,
        minScore: 0,
        maxScore: 140,
        updatedAt: 2000,
      },
    });
    expect(source.json().url).toMatch(
      /^https:\/\/api\.example\.test\/v1\/streams\/[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/,
    );
    expect(upstream.fetchSource).not.toHaveBeenCalled();
  });

  it('validates and single-flight caches normalized lyrics', async () => {
    const fetchLyrics = vi.fn().mockResolvedValue(songLyrics);
    const upstream: MusicUpstream = {
      fetchChart: vi.fn(),
      fetchSearch: vi.fn(),
      fetchCollection: vi.fn(),
      fetchLyrics,
      fetchSource: vi.fn(),
    };
    const app = await setup(upstream);

    const [first, second] = await Promise.all([
      app.inject({ method: 'GET', url: '/v1/songs/ABC123/lyrics' }),
      app.inject({ method: 'GET', url: '/v1/songs/ABC123/lyrics' }),
    ]);
    expect(first.statusCode).toBe(200);
    expect(second.statusCode).toBe(200);
    expect(first.json()).toEqual(songLyrics);
    expect(first.headers['cache-control']).toContain('public, max-age=300');
    expect(fetchLyrics).toHaveBeenCalledTimes(1);
    expect(fetchLyrics).toHaveBeenCalledWith('ABC123', expect.any(AbortSignal));

    const invalid = await app.inject({
      method: 'GET',
      url: '/v1/songs/bad%20code/lyrics',
    });
    expect(invalid.statusCode).toBe(400);
    expect(invalid.json().error.code).toBe('INVALID_CODE');
  });

  it('validates and single-flight caches normalized song detail', async () => {
    const fetchSongDetail = vi.fn().mockResolvedValue(songDetail);
    const upstream: MusicUpstream = {
      fetchChart: vi.fn(),
      fetchSearch: vi.fn(),
      fetchCollection: vi.fn(),
      fetchSongDetail,
      fetchSource: vi.fn(),
    };
    const app = await setup(upstream);

    const [first, second] = await Promise.all([
      app.inject({ method: 'GET', url: '/v1/songs/ABC123/detail' }),
      app.inject({ method: 'GET', url: '/v1/songs/ABC123/detail' }),
    ]);
    expect(first.statusCode).toBe(200);
    expect(second.statusCode).toBe(200);
    expect(first.json()).toEqual(songDetail);
    expect(first.headers['cache-control']).toContain('public, max-age=300');
    expect(fetchSongDetail).toHaveBeenCalledTimes(1);
    expect(fetchSongDetail).toHaveBeenCalledWith(
      'ABC123',
      expect.any(AbortSignal),
    );

    const invalid = await app.inject({
      method: 'GET',
      url: '/v1/songs/bad%20code/detail',
    });
    expect(invalid.statusCode).toBe(400);
    expect(invalid.json().error.code).toBe('INVALID_CODE');
  });

  it('does not mark failed lyric responses as publicly cacheable', async () => {
    const app = await setup({
      fetchChart: vi.fn(),
      fetchSearch: vi.fn(),
      fetchCollection: vi.fn(),
      fetchLyrics: vi.fn().mockRejectedValue(
        new UpstreamError('lyric upstream unavailable'),
      ),
      fetchSource: vi.fn(),
    });

    const response = await app.inject({
      method: 'GET',
      url: '/v1/songs/ABC123/lyrics',
    });
    expect(response.statusCode).toBe(502);
    expect(response.json().error.code).toBe('UPSTREAM_ERROR');
    expect(response.headers['cache-control'] ?? '').not.toContain('public');
  });

  it('validates and single-flight caches normalized song radio', async () => {
    const fetchSongRadio = vi.fn().mockResolvedValue(songRadio);
    const app = await setup({
      fetchChart: vi.fn(),
      fetchSearch: vi.fn(),
      fetchCollection: vi.fn(),
      fetchSongRadio,
      fetchSource: vi.fn(),
    });

    const [first, second] = await Promise.all([
      app.inject({ method: 'GET', url: '/v1/songs/ABC123/radio' }),
      app.inject({ method: 'GET', url: '/v1/songs/ABC123/radio' }),
    ]);
    expect(first.statusCode).toBe(200);
    expect(second.statusCode).toBe(200);
    expect(first.json()).toEqual(songRadio);
    expect(first.headers['cache-control']).toContain('public, max-age=300');
    expect(fetchSongRadio).toHaveBeenCalledTimes(1);
    expect(fetchSongRadio).toHaveBeenCalledWith(
      'ABC123',
      expect.any(AbortSignal),
    );

    const invalid = await app.inject({
      method: 'GET',
      url: '/v1/songs/bad%20code/radio',
    });
    expect(invalid.statusCode).toBe(400);
    expect(invalid.json().error.code).toBe('INVALID_CODE');
  });

  it('returns and single-flight caches the normalized live-radio directory', async () => {
    const fetchLiveRadio = vi.fn().mockResolvedValue(liveRadio);
    const app = await setup({
      fetchChart: vi.fn(),
      fetchSearch: vi.fn(),
      fetchCollection: vi.fn(),
      fetchLiveRadio,
      resolveLiveRadioStream: vi.fn(),
      fetchSource: vi.fn(),
    });

    const [first, second] = await Promise.all([
      app.inject({ method: 'GET', url: '/v1/radio' }),
      app.inject({ method: 'GET', url: '/v1/radio' }),
    ]);
    expect(first.statusCode).toBe(200);
    expect(second.statusCode).toBe(200);
    expect(first.json()).toEqual(liveRadio);
    expect(first.headers['cache-control']).toContain('public, max-age=15');
    expect(fetchLiveRadio).toHaveBeenCalledTimes(1);
    expect(fetchLiveRadio).toHaveBeenCalledWith(expect.any(AbortSignal));
  });

  it('returns and caches the normalized new-release chart', async () => {
    const fetchNewReleases = vi.fn().mockResolvedValue(newReleaseSnapshot);
    const app = await setup({
      fetchChart: vi.fn(),
      fetchNewReleases,
      fetchSearch: vi.fn(),
      fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    });

    const first = await app.inject({
      method: 'GET',
      url: '/v1/charts/new-releases',
    });
    const second = await app.inject({
      method: 'GET',
      url: '/v1/charts/new-releases',
    });

    expect(first.statusCode).toBe(200);
    expect(first.json()).toEqual(newReleaseSnapshot);
    expect(second.json()).toEqual(newReleaseSnapshot);
    expect(fetchNewReleases).toHaveBeenCalledTimes(1);
    expect(fetchNewReleases).toHaveBeenCalledWith(expect.any(AbortSignal));
  });

  it('validates, returns, and single-flight caches weekly charts by period', async () => {
    const fetchWeeklyChart = vi.fn().mockResolvedValue(weeklyChart);
    const app = await setup({
      fetchChart: vi.fn(),
      fetchWeeklyChart,
      fetchSearch: vi.fn(),
      fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    });

    const [first, second] = await Promise.all([
      app.inject({
        method: 'GET',
        url: '/v1/charts/weekly?region=vietnam&week=33&year=2026',
      }),
      app.inject({
        method: 'GET',
        url: '/v1/charts/weekly?region=vietnam&week=33&year=2026',
      }),
    ]);

    expect(first.statusCode).toBe(200);
    expect(first.json()).toEqual(weeklyChart);
    expect(second.json()).toEqual(weeklyChart);
    expect(fetchWeeklyChart).toHaveBeenCalledTimes(1);
    expect(fetchWeeklyChart).toHaveBeenCalledWith(
      'vietnam',
      33,
      2026,
      expect.any(AbortSignal),
    );

    for (const url of [
      '/v1/charts/weekly?region=invalid',
      '/v1/charts/weekly?region=vietnam&week=0&year=2026',
      '/v1/charts/weekly?region=vietnam&week=33',
    ]) {
      const invalid = await app.inject({ method: 'GET', url });
      expect(invalid.statusCode).toBe(400);
    }
    expect(fetchWeeklyChart).toHaveBeenCalledTimes(1);
  });

  it('returns and single-flight caches discovery categories and each home', async () => {
    const fetchDiscovery = vi.fn().mockImplementation(
      async (categoryId: string) => ({ ...discoveryHome, categoryId }),
    );
    const fetchDiscoveryCategories = vi.fn().mockResolvedValue(
      discoveryCategories,
    );
    const app = await setup({
      fetchChart: vi.fn(),
      fetchDiscovery,
      fetchDiscoveryCategories,
      fetchSearch: vi.fn(),
      fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    });

    const [categoriesA, categoriesB, first, second, relaxA, relaxB] =
      await Promise.all([
        app.inject({ method: 'GET', url: '/v1/discovery/categories' }),
        app.inject({ method: 'GET', url: '/v1/discovery/categories' }),
      app.inject({ method: 'GET', url: '/v1/discovery/home' }),
      app.inject({ method: 'GET', url: '/v1/discovery/home' }),
        app.inject({
          method: 'GET',
          url: '/v1/discovery/home?categoryId=14',
        }),
        app.inject({
          method: 'GET',
          url: '/v1/discovery/home?categoryId=14',
        }),
    ]);

    expect(categoriesA.json()).toEqual(discoveryCategories);
    expect(categoriesB.json()).toEqual(discoveryCategories);
    expect(first.statusCode).toBe(200);
    expect(first.json()).toEqual(discoveryHome);
    expect(second.json()).toEqual(discoveryHome);
    expect(relaxA.json()).toEqual({ ...discoveryHome, categoryId: '14' });
    expect(relaxB.json()).toEqual({ ...discoveryHome, categoryId: '14' });
    expect(fetchDiscoveryCategories).toHaveBeenCalledTimes(1);
    expect(fetchDiscoveryCategories).toHaveBeenCalledWith(
      expect.any(AbortSignal),
    );
    expect(fetchDiscovery).toHaveBeenCalledTimes(2);
    expect(fetchDiscovery).toHaveBeenCalledWith(
      '-1',
      expect.any(AbortSignal),
    );
    expect(fetchDiscovery).toHaveBeenCalledWith(
      '14',
      expect.any(AbortSignal),
    );

    for (const url of [
      '/v1/discovery/home?categoryId=',
      '/v1/discovery/home?categoryId=0',
      '/v1/discovery/home?categoryId=1000',
      '/v1/discovery/home?categoryId=bad',
    ]) {
      const invalid = await app.inject({ method: 'GET', url });
      expect(invalid.statusCode).toBe(400);
      expect(invalid.json().error.code).toBe('INVALID_DISCOVERY_CATEGORY');
    }
    expect(fetchDiscovery).toHaveBeenCalledTimes(2);
  });

  it('returns and single-flight caches discovery song recommendations', async () => {
    const fetchDiscoveryRecommendations = vi.fn().mockResolvedValue(
      discoveryRecommendations,
    );
    const app = await setup({
      fetchChart: vi.fn(),
      fetchDiscoveryRecommendations,
      fetchSearch: vi.fn(),
      fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    });

    const [first, second] = await Promise.all([
      app.inject({ method: 'GET', url: '/v1/discovery/recommendations' }),
      app.inject({ method: 'GET', url: '/v1/discovery/recommendations' }),
    ]);

    expect(first.statusCode).toBe(200);
    expect(first.json()).toEqual(discoveryRecommendations);
    expect(second.json()).toEqual(discoveryRecommendations);
    expect(fetchDiscoveryRecommendations).toHaveBeenCalledTimes(1);
    expect(fetchDiscoveryRecommendations).toHaveBeenCalledWith(
      expect.any(AbortSignal),
    );
  });

  it('returns and single-flight caches hub home, detail, and Top 100', async () => {
    const fetchHubHome = vi.fn().mockResolvedValue(hubHome);
    const fetchHubDetail = vi.fn().mockResolvedValue(hubDetail);
    const fetchTop100 = vi.fn().mockResolvedValue(top100Snapshot);
    const app = await setup({
      fetchChart: vi.fn(),
      fetchHubHome,
      fetchHubDetail,
      fetchTop100,
      fetchSearch: vi.fn(),
      fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    });

    const [homeA, homeB, topA, topB, detailA, detailB] = await Promise.all([
      app.inject({ method: 'GET', url: '/v1/hubs' }),
      app.inject({ method: 'GET', url: '/v1/hubs' }),
      app.inject({ method: 'GET', url: '/v1/top-100' }),
      app.inject({ method: 'GET', url: '/v1/top-100' }),
      app.inject({ method: 'GET', url: '/v1/hubs/HUBSLEEP' }),
      app.inject({ method: 'GET', url: '/v1/hubs/HUBSLEEP' }),
    ]);

    expect(homeA.json()).toEqual(hubHome);
    expect(homeB.json()).toEqual(hubHome);
    expect(topA.json()).toEqual(top100Snapshot);
    expect(topB.json()).toEqual(top100Snapshot);
    expect(detailA.json()).toEqual(hubDetail);
    expect(detailB.json()).toEqual(hubDetail);
    expect(fetchHubHome).toHaveBeenCalledTimes(1);
    expect(fetchTop100).toHaveBeenCalledTimes(1);
    expect(fetchHubDetail).toHaveBeenCalledTimes(1);
    expect(fetchHubDetail).toHaveBeenCalledWith(
      'HUBSLEEP',
      expect.any(AbortSignal),
    );

    const invalid = await app.inject({
      method: 'GET',
      url: '/v1/hubs/bad%20id',
    });
    expect(invalid.statusCode).toBe(400);
    expect(invalid.json().error.code).toBe('INVALID_HUB_ID');
    expect(fetchHubDetail).toHaveBeenCalledTimes(1);
  });

  it('returns and single-flight caches the song and album release catalog', async () => {
    const fetchReleaseCatalog = vi.fn().mockResolvedValue(releaseCatalog);
    const app = await setup({
      fetchChart: vi.fn(),
      fetchReleaseCatalog,
      fetchSearch: vi.fn(),
      fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    });

    const [first, second] = await Promise.all([
      app.inject({ method: 'GET', url: '/v1/releases' }),
      app.inject({ method: 'GET', url: '/v1/releases' }),
    ]);

    expect(first.statusCode).toBe(200);
    expect(first.json()).toEqual(releaseCatalog);
    expect(second.json()).toEqual(releaseCatalog);
    expect(fetchReleaseCatalog).toHaveBeenCalledTimes(1);
    expect(fetchReleaseCatalog).toHaveBeenCalledWith(expect.any(AbortSignal));
  });

  it('returns and single-flight caches artist detail by alias', async () => {
    const fetchArtistDetail = vi.fn().mockResolvedValue(artistDetail);
    const app = await setup({
      fetchChart: vi.fn(),
      fetchArtistDetail,
      fetchSearch: vi.fn(),
      fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    });

    const [first, second] = await Promise.all([
      app.inject({ method: 'GET', url: '/v1/artists/Son-Tung-M-TP' }),
      app.inject({ method: 'GET', url: '/v1/artists/Son-Tung-M-TP' }),
    ]);
    expect(first.statusCode).toBe(200);
    expect(first.json()).toEqual(artistDetail);
    expect(second.json()).toEqual(artistDetail);
    expect(fetchArtistDetail).toHaveBeenCalledTimes(1);
    expect(fetchArtistDetail).toHaveBeenCalledWith(
      'Son-Tung-M-TP',
      expect.any(AbortSignal),
    );

    const invalid = await app.inject({
      method: 'GET',
      url: '/v1/artists/bad%20alias',
    });
    expect(invalid.statusCode).toBe(400);
    expect(invalid.json().error.code).toBe('INVALID_ARTIST_ALIAS');
    expect(fetchArtistDetail).toHaveBeenCalledTimes(1);
  });

  it('returns and single-flight caches bounded artist song pages', async () => {
    const fetchArtistSongs = vi.fn((artistId: string, page: number, limit: number) =>
      Promise.resolve({
        ...artistSongPage,
        artistId,
        page,
        limit,
      }));
    const app = await setup({
      supportsPaginatedArtistSongs: true,
      fetchChart: vi.fn(),
      fetchArtistSongs,
      fetchSearch: vi.fn(),
      fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    });

    const [first, second] = await Promise.all([
      app.inject({
        method: 'GET',
        url: '/v1/artists/ARTIST1/songs?page=2',
      }),
      app.inject({
        method: 'GET',
        url: '/v1/artists/ARTIST1/songs?page=2',
      }),
    ]);
    expect(first.statusCode).toBe(200);
    expect(first.json()).toEqual(artistSongPage);
    expect(second.json()).toEqual(artistSongPage);
    expect(fetchArtistSongs).toHaveBeenCalledTimes(1);
    expect(fetchArtistSongs).toHaveBeenCalledWith(
      'ARTIST1',
      2,
      50,
      expect.any(AbortSignal),
    );

    const distinct = await app.inject({
      method: 'GET',
      url: '/v1/artists/ARTIST1/songs?page=3&limit=25',
    });
    expect(distinct.statusCode).toBe(200);
    expect(distinct.json()).toMatchObject({
      artistId: 'ARTIST1',
      page: 3,
      limit: 25,
    });
    expect(fetchArtistSongs).toHaveBeenCalledTimes(2);
  });

  it('validates artist song pagination and fails closed when unavailable', async () => {
    const fetchArtistSongs = vi.fn().mockResolvedValue(artistSongPage);
    const enabled = await setup({
      supportsPaginatedArtistSongs: true,
      fetchChart: vi.fn(),
      fetchArtistSongs,
      fetchSearch: vi.fn(),
      fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    });
    const invalidCases = [
      ['/v1/artists/bad%20id/songs', 'INVALID_ARTIST_ID'],
      ['/v1/artists/ARTIST1/songs?page=0', 'INVALID_ARTIST_SONG_PAGE'],
      ['/v1/artists/ARTIST1/songs?page=101', 'INVALID_ARTIST_SONG_PAGE'],
      ['/v1/artists/ARTIST1/songs?page=1.5', 'INVALID_ARTIST_SONG_PAGE'],
      ['/v1/artists/ARTIST1/songs?page=1e2', 'INVALID_ARTIST_SONG_PAGE'],
      ['/v1/artists/ARTIST1/songs?limit=0', 'INVALID_ARTIST_SONG_LIMIT'],
      ['/v1/artists/ARTIST1/songs?limit=51', 'INVALID_ARTIST_SONG_LIMIT'],
    ] as const;
    for (const [url, code] of invalidCases) {
      const response = await enabled.inject({ method: 'GET', url });
      expect(response.statusCode).toBe(400);
      expect(response.json().error.code).toBe(code);
    }
    expect(fetchArtistSongs).not.toHaveBeenCalled();

    const unavailable = await setup({
      fetchChart: vi.fn(),
      fetchArtistSongs,
      fetchSearch: vi.fn(),
      fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    });
    const response = await unavailable.inject({
      method: 'GET',
      url: '/v1/artists/ARTIST1/songs',
    });
    expect(response.statusCode).toBe(501);
    expect(response.json().error.code).toBe(
      'ARTIST_SONG_PAGINATION_UNAVAILABLE',
    );
    expect(response.headers['cache-control']).toContain('no-store');
    expect(fetchArtistSongs).not.toHaveBeenCalled();
  });

  it('rejects and does not cache an artist song page with mismatched identity', async () => {
    const fetchArtistSongs = vi.fn().mockResolvedValue({
      ...artistSongPage,
      artistId: 'OTHER_ARTIST',
    });
    const app = await setup({
      supportsPaginatedArtistSongs: true,
      fetchChart: vi.fn(),
      fetchArtistSongs,
      fetchSearch: vi.fn(),
      fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    });

    for (let attempt = 0; attempt < 2; attempt += 1) {
      const response = await app.inject({
        method: 'GET',
        url: '/v1/artists/ARTIST1/songs?page=2',
      });
      expect(response.statusCode).toBe(502);
      expect(response.json().error.code).toBe('UPSTREAM_ERROR');
    }
    expect(fetchArtistSongs).toHaveBeenCalledTimes(2);
  });

  it('rejects and does not cache hasMore beyond the artist page cap', async () => {
    const fetchArtistSongs = vi.fn(
      (artistId: string, page: number, limit: number) =>
        Promise.resolve({
          ...artistSongPage,
          artistId,
          page,
          limit,
          hasMore: true,
        }),
    );
    const app = await setup({
      supportsPaginatedArtistSongs: true,
      fetchChart: vi.fn(),
      fetchArtistSongs,
      fetchSearch: vi.fn(),
      fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    });

    for (let attempt = 0; attempt < 2; attempt += 1) {
      const response = await app.inject({
        method: 'GET',
        url: '/v1/artists/ARTIST1/songs?page=100',
      });
      expect(response.statusCode).toBe(502);
      expect(response.json().error.code).toBe('UPSTREAM_ERROR');
    }
    expect(fetchArtistSongs).toHaveBeenCalledTimes(2);
  });

  it('returns normalized catalog search and reuses a playable chart code', async () => {
    let resolveChart: ((value: ChartSnapshotDto) => void) | undefined;
    const pendingChart = new Promise<ChartSnapshotDto>((resolve) => {
      resolveChart = resolve;
    });
    const fetchSearch = vi.fn().mockResolvedValue(searchSnapshot);
    const upstream: MusicUpstream = {
      fetchChart: vi.fn().mockReturnValue(pendingChart),
      fetchSearch, fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    };
    const app = await setup(upstream);

    const responseRequest = app.inject({
      method: 'GET',
      url: '/v1/search?q=%20n%C3%A0ng%20%20th%C6%A1%20',
    });
    await vi.waitFor(() => {
      expect(fetchSearch).toHaveBeenCalledTimes(1);
      expect(upstream.fetchChart).toHaveBeenCalledTimes(1);
    });
    resolveChart?.(snapshot);
    const response = await responseRequest;

    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({
      ...searchSnapshot,
      query: 'nàng thơ',
      songs: [{ ...searchSnapshot.songs[0], code: 'ABC123', playable: true }],
    });
    expect(fetchSearch).toHaveBeenCalledWith('nàng thơ', expect.any(AbortSignal));

    await app.inject({ method: 'GET', url: '/v1/search?q=N%C3%80NG%20TH%C6%A0' });
    expect(fetchSearch).toHaveBeenCalledTimes(1);
  });

  it('returns and single-flight caches a typed song page with chart upgrades', async () => {
    const fetchSearchPage = vi.fn().mockResolvedValue(searchSongPage);
    const upstream: MusicUpstream = {
      supportsPaginatedSearch: true,
      fetchChart: vi.fn().mockResolvedValue(snapshot),
      fetchSearch: vi.fn(),
      fetchSearchPage,
      fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    };
    const app = await setup(upstream);

    const [first, second] = await Promise.all([
      app.inject({
        method: 'GET',
        url: '/v1/search?q=%20n%C3%A0ng%20%20th%C6%A1%20&type=songs',
      }),
      app.inject({
        method: 'GET',
        url: '/v1/search?q=N%C3%80NG%20TH%C6%A0&type=songs&page=1&limit=18',
      }),
    ]);

    expect(first.statusCode).toBe(200);
    expect(first.json()).toEqual({
      ...searchSongPage,
      items: [{ ...searchSongPage.items[0], code: 'ABC123', playable: true }],
    });
    expect(second.json().query).toBe('NÀNG THƠ');
    expect(fetchSearchPage).toHaveBeenCalledTimes(1);
    expect(fetchSearchPage).toHaveBeenCalledWith(
      'nàng thơ',
      'songs',
      1,
      18,
      expect.any(AbortSignal),
    );
    expect(upstream.fetchChart).toHaveBeenCalledTimes(1);
  });

  it('keys typed search cache by query, type, page, and limit', async () => {
    const fetchSearchPage = vi.fn().mockImplementation(
      async (query: string, type: 'songs' | 'artists', page: number, limit: number) => {
        if (type === 'artists') {
          return {
            query,
            type,
            page,
            limit,
            total: 1,
            hasMore: false,
            items: searchSnapshot.artists,
            catalogPlaybackEnabled: true,
          } satisfies SearchPageDto;
        }
        return {
          ...searchSongPage,
          query,
          page,
          limit,
        } satisfies SearchPageDto;
      },
    );
    const upstream: MusicUpstream = {
      supportsPaginatedSearch: true,
      fetchChart: vi.fn().mockRejectedValue(new UpstreamError('chart unavailable')),
      fetchSearch: vi.fn(),
      fetchSearchPage,
      fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    };
    const app = await setup(upstream);

    for (const url of [
      '/v1/search?q=n%C3%A0ng%20th%C6%A1&type=songs&page=2&limit=18',
      '/v1/search?q=N%C3%80NG%20TH%C6%A0&type=songs&page=2&limit=18',
      '/v1/search?q=n%C3%A0ng%20th%C6%A1&type=songs&page=3&limit=18',
      '/v1/search?q=n%C3%A0ng%20th%C6%A1&type=songs&page=2&limit=19',
      '/v1/search?q=n%C3%A0ng%20th%C6%A1&type=artists&page=2&limit=18',
    ]) {
      const response = await app.inject({ method: 'GET', url });
      expect(response.statusCode).toBe(200);
    }

    expect(fetchSearchPage).toHaveBeenCalledTimes(4);
    expect(upstream.fetchChart).toHaveBeenCalledTimes(4);
  });

  it('validates typed pagination and reports unavailable adapters explicitly', async () => {
    const fetchSearchPage = vi.fn();
    const unavailable: MusicUpstream = {
      fetchChart: vi.fn(),
      fetchSearch: vi.fn(),
      fetchSearchPage,
      fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    };
    const unavailableApp = await setup(unavailable);
    const unavailableResponse = await unavailableApp.inject({
      method: 'GET',
      url: '/v1/search?q=n%C3%A0ng&type=songs',
    });
    expect(unavailableResponse.statusCode).toBe(501);
    expect(unavailableResponse.json().error.code).toBe(
      'SEARCH_PAGINATION_UNAVAILABLE',
    );
    expect(unavailableResponse.json().error.requestId).toBeTruthy();
    expect(unavailableResponse.headers['cache-control']).toContain('no-store');
    expect(fetchSearchPage).not.toHaveBeenCalled();

    const enabledFetch = vi.fn();
    const enabled: MusicUpstream = {
      supportsPaginatedSearch: true,
      fetchChart: vi.fn(),
      fetchSearch: vi.fn(),
      fetchSearchPage: enabledFetch,
      fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    };
    const enabledApp = await setup(enabled);
    const invalidCases = [
      ['/v1/search?q=n%C3%A0ng&page=1', 'INVALID_SEARCH_PAGINATION'],
      ['/v1/search?q=n%C3%A0ng&type=all', 'INVALID_SEARCH_TYPE'],
      ['/v1/search?q=n%C3%A0ng&type=songs&page=0', 'INVALID_SEARCH_PAGE'],
      ['/v1/search?q=n%C3%A0ng&type=songs&page=101', 'INVALID_SEARCH_PAGE'],
      ['/v1/search?q=n%C3%A0ng&type=songs&page=1.5', 'INVALID_SEARCH_PAGE'],
      ['/v1/search?q=n%C3%A0ng&type=songs&page=1e2', 'INVALID_SEARCH_PAGE'],
      ['/v1/search?q=n%C3%A0ng&type=songs&limit=0', 'INVALID_SEARCH_LIMIT'],
      ['/v1/search?q=n%C3%A0ng&type=songs&limit=51', 'INVALID_SEARCH_LIMIT'],
    ] as const;
    for (const [url, code] of invalidCases) {
      const response = await enabledApp.inject({ method: 'GET', url });
      expect(response.statusCode).toBe(400);
      expect(response.json().error.code).toBe(code);
    }
    expect(enabledFetch).not.toHaveBeenCalled();
    expect(enabled.fetchChart).not.toHaveBeenCalled();
  });

  it('returns cached autocomplete suggestions with normalized queries', async () => {
    const fetchSearchSuggestions = vi.fn().mockResolvedValue(searchSuggestions);
    const upstream: MusicUpstream = {
      fetchChart: vi.fn(),
      fetchSearch: vi.fn(),
      fetchSearchSuggestions,
      fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    };
    const app = await setup(upstream);

    const [first, second] = await Promise.all([
      app.inject({
        method: 'GET',
        url: '/v1/search/suggestions?q=%20n%C3%A0ng%20%20',
      }),
      app.inject({
        method: 'GET',
        url: '/v1/search/suggestions?q=N%C3%80NG',
      }),
    ]);

    expect(first.statusCode).toBe(200);
    expect(first.json()).toEqual(searchSuggestions);
    expect(second.json()).toEqual(searchSuggestions);
    expect(fetchSearchSuggestions).toHaveBeenCalledTimes(1);
    expect(fetchSearchSuggestions).toHaveBeenCalledWith(
      'nàng',
      expect.any(AbortSignal),
    );
  });

  it('rejects invalid autocomplete terms before calling upstream', async () => {
    const fetchSearchSuggestions = vi.fn();
    const upstream: MusicUpstream = {
      fetchChart: vi.fn(),
      fetchSearch: vi.fn(),
      fetchSearchSuggestions,
      fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    };
    const app = await setup(upstream);
    for (const url of [
      '/v1/search/suggestions?q=',
      '/v1/search/suggestions?q=line%0Abreak',
      `/v1/search/suggestions?q=${'a'.repeat(101)}`,
    ]) {
      const response = await app.inject({ method: 'GET', url });
      expect(response.statusCode).toBe(400);
      expect(response.json().error.code).toBe('INVALID_SEARCH_QUERY');
    }
    expect(fetchSearchSuggestions).not.toHaveBeenCalled();
  });

  it('rejects empty, control-character, and oversized search terms', async () => {
    const upstream: MusicUpstream = {
      fetchChart: vi.fn(),
      fetchSearch: vi.fn(), fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    };
    const app = await setup(upstream);
    for (const url of [
      '/v1/search?q=',
      '/v1/search?q=line%0Abreak',
      `/v1/search?q=${'a'.repeat(101)}`,
    ]) {
      const response = await app.inject({ method: 'GET', url });
      expect(response.statusCode).toBe(400);
      expect(response.json().error.code).toBe('INVALID_SEARCH_QUERY');
    }
    expect(upstream.fetchSearch).not.toHaveBeenCalled();
  });

  it('keeps public search available when the chart adapter is down', async () => {
    const upstream: MusicUpstream = {
      fetchChart: vi.fn().mockRejectedValue(new UpstreamError('chart unavailable')),
      fetchSearch: vi.fn().mockResolvedValue(searchSnapshot),
      fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    };
    const app = await setup(upstream);

    const response = await app.inject({
      method: 'GET',
      url: '/v1/search?q=n%C3%A0ng%20th%C6%A1',
    });

    expect(response.statusCode).toBe(200);
    expect(response.json().songs).toEqual(searchSnapshot.songs);
  });

  it('returns cached collection detail and upgrades songs found in chart', async () => {
    let resolveChart: ((value: ChartSnapshotDto) => void) | undefined;
    const pendingChart = new Promise<ChartSnapshotDto>((resolve) => {
      resolveChart = resolve;
    });
    const fetchCollection = vi.fn().mockResolvedValue(collectionDetail);
    const upstream: MusicUpstream = {
      fetchChart: vi.fn().mockReturnValue(pendingChart),
      fetchSearch: vi.fn(),
      fetchCollection,
      fetchSource: vi.fn(),
    };
    const app = await setup(upstream);

    const responseRequest = app.inject({
      method: 'GET',
      url: '/v1/collections/COLLECTION1',
    });
    await vi.waitFor(() => {
      expect(fetchCollection).toHaveBeenCalledTimes(1);
      expect(upstream.fetchChart).toHaveBeenCalledTimes(1);
    });
    resolveChart?.(snapshot);
    const response = await responseRequest;

    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({
      ...collectionDetail,
      songs: [{
        ...collectionDetail.songs[0],
        code: 'ABC123',
        playable: true,
      }],
    });
    expect(fetchCollection).toHaveBeenCalledWith(
      'COLLECTION1',
      expect.any(AbortSignal),
    );
    await app.inject({ method: 'GET', url: '/v1/collections/COLLECTION1' });
    expect(fetchCollection).toHaveBeenCalledTimes(1);
  });

  it('rejects invalid collection IDs before contacting upstream', async () => {
    const fetchCollection = vi.fn();
    const upstream: MusicUpstream = {
      fetchChart: vi.fn(),
      fetchSearch: vi.fn(),
      fetchCollection,
      fetchSource: vi.fn(),
    };
    const app = await setup(upstream);
    const response = await app.inject({
      method: 'GET',
      url: '/v1/collections/bad%20id',
    });
    expect(response.statusCode).toBe(400);
    expect(response.json().error.code).toBe('INVALID_COLLECTION_ID');
    expect(fetchCollection).not.toHaveBeenCalled();
  });

  it('rejects invalid song codes before contacting upstream', async () => {
    const upstream: MusicUpstream = {
      fetchChart: vi.fn(),
      fetchSearch: vi.fn(), fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    };
    const app = await setup(upstream);
    const response = await app.inject({ method: 'GET', url: '/v1/songs/bad%20code/source' });
    expect(response.statusCode).toBe(400);
    expect(response.json().error.code).toBe('INVALID_CODE');
    expect(upstream.fetchSource).not.toHaveBeenCalled();
  });

  it('serves a signed stream URL for the maximum accepted code length', async () => {
    const code = 'A'.repeat(128);
    const upstream: MusicUpstream = {
      fetchChart: vi.fn(),
      fetchSearch: vi.fn(), fetchCollection: vi.fn(),
      fetchSource: vi.fn().mockResolvedValue('https://stream.example.test/song.mp3'),
    };
    const audioFetcher = vi.fn().mockResolvedValue(new Response('audio'));
    const app = await buildApp(config(), upstream, audioFetcher);
    apps.push(app);
    const source = await app.inject({ method: 'GET', url: `/v1/songs/${code}/source` });
    expect(source.statusCode).toBe(200);
    const response = await app.inject({
      method: 'GET', url: new URL(source.json().url).pathname,
    });
    expect(response.statusCode).toBe(200);
    expect(upstream.fetchSource).toHaveBeenCalledWith(code, expect.any(AbortSignal));
  });
});

describe('secure audio relay', () => {
  it('signs the requested bitrate and rejects unknown quality values', async () => {
    const upstream: MusicUpstream = {
      fetchChart: vi.fn(),
      fetchSearch: vi.fn(),
      fetchCollection: vi.fn(),
      fetchSource: vi.fn().mockResolvedValue(
        'https://cdn.stream.example.test/song-320.mp3',
      ),
    };
    const audioFetcher = vi.fn().mockResolvedValue(new Response('audio', {
      status: 200,
      headers: { 'content-type': 'audio/mpeg' },
    }));
    const app = await buildApp(config(), upstream, audioFetcher);
    apps.push(app);

    const invalid = await app.inject({
      method: 'GET',
      url: '/v1/songs/ABC123/source?quality=lossless',
    });
    expect(invalid.statusCode).toBe(400);
    expect(invalid.json().error.code).toBe('INVALID_QUALITY');
    const repeated = await app.inject({
      method: 'GET',
      url: '/v1/songs/ABC123/source?quality=128&quality=320',
    });
    expect(repeated.statusCode).toBe(400);
    expect(repeated.json().error.code).toBe('INVALID_QUALITY');

    const source = await app.inject({
      method: 'GET',
      url: '/v1/songs/ABC123/source?quality=320',
    });
    expect(source.headers['cache-control']).toBe(
      'private, no-store, max-age=0',
    );
    const response = await app.inject({
      method: 'GET',
      url: new URL(source.json().url).pathname,
    });

    expect(response.statusCode).toBe(200);
    expect(upstream.fetchSource).toHaveBeenCalledWith(
      'ABC123',
      expect.any(AbortSignal),
      '320',
    );
  });

  it('relays range requests with media headers and disables caching', async () => {
    const upstream: MusicUpstream = {
      fetchChart: vi.fn(),
      fetchSearch: vi.fn(), fetchCollection: vi.fn(),
      fetchSource: vi.fn().mockResolvedValue('https://cdn.stream.example.test/song.mp3'),
    };
    const audioFetcher = vi.fn().mockResolvedValue(new Response('audio-bytes', {
      status: 206,
      headers: {
        'content-type': 'audio/mpeg',
        'content-length': '11',
        'content-range': 'bytes 10-20/100',
        'accept-ranges': 'bytes',
      },
    }));
    const app = await buildApp(config(), upstream, audioFetcher);
    apps.push(app);
    const source = await app.inject({ method: 'GET', url: '/v1/songs/ABC123/source' });
    const streamPath = new URL(source.json().url).pathname;
    const response = await app.inject({
      method: 'GET', url: streamPath, headers: { range: 'bytes=10-20' },
    });

    expect(response.statusCode).toBe(206);
    expect(response.body).toBe('audio-bytes');
    expect(response.headers['content-type']).toContain('audio/mpeg');
    expect(response.headers['content-range']).toBe('bytes 10-20/100');
    expect(response.headers['accept-ranges']).toBe('bytes');
    expect(response.headers['cache-control']).toBe('private, no-store, max-age=0');
    expect(upstream.fetchSource).toHaveBeenCalledWith('ABC123', expect.any(AbortSignal));
    expect(audioFetcher).toHaveBeenCalledWith(
      'https://cdn.stream.example.test/song.mp3',
      expect.objectContaining({
        redirect: 'manual',
        headers: { accept: 'audio/*', range: 'bytes=10-20' },
      }),
    );
  });

  it('rejects tampered tokens without resolving or fetching a CDN URL', async () => {
    const upstream: MusicUpstream = {
      fetchChart: vi.fn(), fetchSearch: vi.fn(), fetchCollection: vi.fn(), fetchSource: vi.fn(),
    };
    const audioFetcher = vi.fn();
    const app = await buildApp(config(), upstream, audioFetcher);
    apps.push(app);
    const response = await app.inject({ method: 'GET', url: '/v1/streams/tampered.token' });
    expect(response.statusCode).toBe(401);
    expect(response.json().error.code).toBe('INVALID_STREAM_TOKEN');
    expect(upstream.fetchSource).not.toHaveBeenCalled();
    expect(audioFetcher).not.toHaveBeenCalled();
  });

  it('rejects disallowed CDN hosts without making a relay request', async () => {
    const upstream: MusicUpstream = {
      fetchChart: vi.fn(),
      fetchSearch: vi.fn(), fetchCollection: vi.fn(),
      fetchSource: vi.fn().mockResolvedValue('https://attacker.example/track.mp3'),
    };
    const audioFetcher = vi.fn();
    const app = await buildApp(config(), upstream, audioFetcher);
    apps.push(app);
    const source = await app.inject({ method: 'GET', url: '/v1/songs/ABC123/source' });
    const response = await app.inject({
      method: 'GET', url: new URL(source.json().url).pathname,
    });
    expect(response.statusCode).toBe(502);
    expect(response.json().error.code).toBe('UPSTREAM_ERROR');
    expect(audioFetcher).not.toHaveBeenCalled();
  });

  it('does not follow a redirect outside the CDN allowlist', async () => {
    const upstream: MusicUpstream = {
      fetchChart: vi.fn(),
      fetchSearch: vi.fn(), fetchCollection: vi.fn(),
      fetchSource: vi.fn().mockResolvedValue('https://stream.example.test/song.mp3'),
    };
    const audioFetcher = vi.fn().mockResolvedValueOnce(new Response(null, {
      status: 302,
      headers: { location: 'https://attacker.example/track.mp3' },
    }));
    const app = await buildApp(config(), upstream, audioFetcher);
    apps.push(app);
    const source = await app.inject({ method: 'GET', url: '/v1/songs/ABC123/source' });
    const response = await app.inject({
      method: 'GET', url: new URL(source.json().url).pathname,
    });
    expect(response.statusCode).toBe(502);
    expect(audioFetcher).toHaveBeenCalledTimes(1);
  });

  it('rejects malformed ranges before resolving the CDN source', async () => {
    const upstream: MusicUpstream = {
      fetchChart: vi.fn(), fetchSearch: vi.fn(), fetchCollection: vi.fn(), fetchSource: vi.fn(),
    };
    const app = await buildApp(config(), upstream, vi.fn());
    apps.push(app);
    const source = await app.inject({ method: 'GET', url: '/v1/songs/ABC123/source' });
    const response = await app.inject({
      method: 'GET',
      url: new URL(source.json().url).pathname,
      headers: { range: 'items=0-10' },
    });
    expect(response.statusCode).toBe(400);
    expect(response.json().error.code).toBe('INVALID_RANGE');
    expect(upstream.fetchSource).not.toHaveBeenCalled();
  });
});

describe('secure live-radio HLS relay', () => {
  it('keeps playlists and byte-range segments on the proxy origin', async () => {
    const upstream: MusicUpstream = {
      fetchChart: vi.fn(),
      fetchSearch: vi.fn(),
      fetchCollection: vi.fn(),
      fetchLiveRadio: vi.fn().mockResolvedValue(liveRadio),
      resolveLiveRadioStream: vi.fn().mockResolvedValue(
        'https://radio.stream.example.test/live/index.m3u8',
      ),
      fetchSource: vi.fn(),
    };
    const playlist = [
      '#EXTM3U',
      '#EXT-X-TARGETDURATION:6',
      '#EXT-X-KEY:METHOD=AES-128,URI="key.bin"',
      '#EXTINF:6,',
      'segment-1.aac',
    ].join('\n');
    const audioFetcher = vi.fn()
      .mockResolvedValueOnce(new Response(playlist, {
        headers: { 'content-type': 'application/vnd.apple.mpegurl' },
      }))
      .mockResolvedValueOnce(new Response('segment-bytes', {
        status: 206,
        headers: {
          'content-type': 'audio/aac',
          'content-length': '13',
          'content-range': 'bytes 0-12/13',
          'accept-ranges': 'bytes',
        },
      }));
    const app = await buildApp(config(), upstream, audioFetcher);
    apps.push(app);

    const source = await app.inject({
      method: 'GET',
      url: '/v1/radio/ROOM1/source',
    });
    expect(source.statusCode).toBe(200);
    expect(source.headers['cache-control']).toContain('no-store');
    expect(source.body).not.toContain('radio.stream.example.test');
    const playlistResponse = await app.inject({
      method: 'GET',
      url: new URL(source.json().url).pathname,
    });
    expect(playlistResponse.statusCode).toBe(200);
    expect(playlistResponse.headers['content-type']).toContain(
      'application/vnd.apple.mpegurl',
    );
    expect(playlistResponse.body).not.toContain('radio.stream.example.test');
    const proxyUrls = playlistResponse.body.match(
      /https:\/\/api\.example\.test\/v1\/live-streams\/[A-Za-z0-9._-]+/g,
    );
    expect(proxyUrls).toHaveLength(2);

    const segmentResponse = await app.inject({
      method: 'GET',
      url: new URL(proxyUrls![1]!).pathname,
      headers: { range: 'bytes=0-12' },
    });
    expect(segmentResponse.statusCode).toBe(206);
    expect(segmentResponse.body).toBe('segment-bytes');
    expect(segmentResponse.headers['content-range']).toBe('bytes 0-12/13');
    expect(segmentResponse.headers['cache-control']).toContain('no-store');
    expect(upstream.resolveLiveRadioStream).toHaveBeenCalledWith(
      'ROOM1',
      expect.any(AbortSignal),
    );
    expect(audioFetcher).toHaveBeenNthCalledWith(
      2,
      'https://radio.stream.example.test/live/segment-1.aac',
      expect.objectContaining({
        redirect: 'manual',
        headers: { accept: '*/*', range: 'bytes=0-12' },
      }),
    );
  });

  it('rejects tampered tokens and disallowed playlist children', async () => {
    const resolveLiveRadioStream = vi.fn().mockResolvedValue(
      'https://radio.stream.example.test/live/index.m3u8',
    );
    const upstream: MusicUpstream = {
      fetchChart: vi.fn(),
      fetchSearch: vi.fn(),
      fetchCollection: vi.fn(),
      fetchLiveRadio: vi.fn().mockResolvedValue(liveRadio),
      resolveLiveRadioStream,
      fetchSource: vi.fn(),
    };
    const audioFetcher = vi.fn().mockResolvedValue(new Response([
      '#EXTM3U',
      '#EXTINF:6,',
      'https://attacker.example/segment.aac',
    ].join('\n'), {
      headers: { 'content-type': 'application/vnd.apple.mpegurl' },
    }));
    const app = await buildApp(config(), upstream, audioFetcher);
    apps.push(app);

    const tampered = await app.inject({
      method: 'GET',
      url: '/v1/live-streams/v1.tampered',
    });
    expect(tampered.statusCode).toBe(401);
    expect(tampered.json().error.code).toBe('INVALID_LIVE_STREAM_TOKEN');
    expect(resolveLiveRadioStream).not.toHaveBeenCalled();

    const source = await app.inject({
      method: 'GET',
      url: '/v1/radio/ROOM1/source',
    });
    const rejected = await app.inject({
      method: 'GET',
      url: new URL(source.json().url).pathname,
    });
    expect(rejected.statusCode).toBe(502);
    expect(rejected.json().error.code).toBe('UPSTREAM_ERROR');
    expect(audioFetcher).toHaveBeenCalledTimes(1);
  });
});

describe('CORS', () => {
  it('allows configured origins and omits the header for other origins', async () => {
    const upstream: MusicUpstream = {
      fetchChart: vi.fn(), fetchSearch: vi.fn(), fetchCollection: vi.fn(), fetchSource: vi.fn(),
    };
    const app = await setup(upstream);
    const allowed = await app.inject({
      method: 'GET', url: '/health', headers: { origin: 'https://app.example.test' },
    });
    const denied = await app.inject({
      method: 'GET', url: '/health', headers: { origin: 'https://evil.example.test' },
    });
    expect(allowed.headers['access-control-allow-origin']).toBe('https://app.example.test');
    expect(denied.headers['access-control-allow-origin']).toBeUndefined();
  });

  it('allows a packaged TV null origin only when configured', async () => {
    const upstream: MusicUpstream = {
      fetchChart: vi.fn(), fetchSearch: vi.fn(), fetchCollection: vi.fn(), fetchSource: vi.fn(),
    };
    const app = await buildApp(config({
      CORS_ORIGINS: 'https://app.example.test,null',
    }), upstream);
    apps.push(app);
    const response = await app.inject({
      method: 'GET', url: '/health', headers: { origin: 'null' },
    });
    expect(response.headers['access-control-allow-origin']).toBe('null');
  });
});

describe('chart cache', () => {
  it('serves repeated requests from the short-lived cache', async () => {
    const fetchChart = vi.fn().mockResolvedValue(snapshot);
    const app = await setup({
      fetchChart, fetchSearch: vi.fn(), fetchCollection: vi.fn(), fetchSource: vi.fn(),
    });
    await app.inject({ method: 'GET', url: '/v1/chart' });
    await app.inject({ method: 'GET', url: '/v1/chart' });
    expect(fetchChart).toHaveBeenCalledTimes(1);
  });
});

describe('sanitized failures', () => {
  it('maps upstream failures without leaking their message and includes request ID', async () => {
    const app = await setup({
      fetchChart: vi.fn().mockRejectedValue(new UpstreamError('secret upstream detail', 503)),
      fetchSearch: vi.fn(), fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    });
    const response = await app.inject({
      method: 'GET',
      url: '/v1/chart',
      headers: { 'x-request-id': 'trace-123' },
    });
    expect(response.statusCode).toBe(502);
    expect(response.headers['x-request-id']).toBe('trace-123');
    expect(response.json()).toEqual({
      error: {
        code: 'UPSTREAM_ERROR',
        message: 'Không thể tải dữ liệu âm nhạc lúc này.',
        requestId: 'trace-123',
      },
    });
    expect(response.body).not.toContain('secret upstream detail');
  });

  it('enforces a hard upstream deadline even if the adapter ignores abort', async () => {
    const app = await buildApp(config({ UPSTREAM_TIMEOUT_MS: '10' }), {
      fetchChart: vi.fn(() => new Promise<ChartSnapshotDto>(() => undefined)),
      fetchSearch: vi.fn(), fetchCollection: vi.fn(),
      fetchSource: vi.fn(),
    });
    apps.push(app);
    const response = await app.inject({ method: 'GET', url: '/v1/chart' });
    expect(response.statusCode).toBe(502);
    expect(response.json().error.code).toBe('UPSTREAM_TIMEOUT');
  });
});

describe('rate limiting', () => {
  it('returns the normalized rate-limit error contract', async () => {
    const upstream: MusicUpstream = {
      fetchChart: vi.fn(), fetchSearch: vi.fn(), fetchCollection: vi.fn(), fetchSource: vi.fn(),
    };
    const app = await buildApp(config({ RATE_LIMIT_MAX: '1' }), upstream);
    apps.push(app);
    await app.inject({ method: 'GET', url: '/health' });
    const response = await app.inject({ method: 'GET', url: '/health' });
    expect(response.statusCode).toBe(429);
    expect(response.json().error.code).toBe('RATE_LIMITED');
    expect(response.json().error.requestId).toBeTypeOf('string');
  });
});
