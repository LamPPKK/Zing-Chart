import { randomUUID } from 'node:crypto';
import cors from '@fastify/cors';
import rateLimit from '@fastify/rate-limit';
import Fastify, { type FastifyInstance } from 'fastify';
import {
  audioBody,
  fetchAudio,
  isAllowedStreamUrl,
  validRange,
} from './audio-relay.js';
import type { AppConfig } from './config.js';
import {
  fetchLiveResource,
  isHlsPlaylist,
  liveMediaBody,
  readHlsPlaylist,
  rewriteHlsPlaylist,
} from './hls-relay.js';
import {
  createLiveStreamToken,
  readLiveStreamToken,
} from './live-stream-token.js';
import {
  createStreamToken,
  readStreamTokenPayload,
} from './stream-token.js';
import type {
  ArtistDetailDto,
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
  SearchResultType,
  SearchSuggestionSnapshotDto,
  SearchSnapshotDto,
  SongDetailDto,
  SongLyricsDto,
  SongRadioDto,
  Top100SnapshotDto,
  WeeklyChartDto,
  WeeklyChartRegion,
  StreamQuality,
} from './types.js';
import { UpstreamError } from './types.js';

interface ChartCacheEntry {
  expiresAt: number;
  snapshot: ChartSnapshotDto;
}

interface SearchCacheEntry {
  expiresAt: number;
  snapshot: SearchSnapshotDto;
}

interface SearchPageCacheEntry {
  expiresAt: number;
  page: SearchPageDto;
}

interface SearchSuggestionCacheEntry {
  expiresAt: number;
  snapshot: SearchSuggestionSnapshotDto;
}

interface CollectionCacheEntry {
  expiresAt: number;
  detail: CollectionDetailDto;
}

interface NewReleaseCacheEntry {
  expiresAt: number;
  snapshot: NewReleaseSnapshotDto;
}

interface DiscoveryCacheEntry {
  expiresAt: number;
  home: DiscoveryHomeDto;
}

interface DiscoveryCategoriesCacheEntry {
  expiresAt: number;
  categories: DiscoveryCategoriesDto;
}

interface DiscoveryRecommendationsCacheEntry {
  expiresAt: number;
  recommendations: DiscoveryRecommendationsDto;
}

interface HubHomeCacheEntry {
  expiresAt: number;
  home: HubHomeDto;
}

interface HubDetailCacheEntry {
  expiresAt: number;
  detail: HubDetailDto;
}

interface Top100CacheEntry {
  expiresAt: number;
  snapshot: Top100SnapshotDto;
}

interface ReleaseCatalogCacheEntry {
  expiresAt: number;
  snapshot: ReleaseCatalogDto;
}

interface ArtistDetailCacheEntry {
  expiresAt: number;
  detail: ArtistDetailDto;
}

interface WeeklyChartCacheEntry {
  expiresAt: number;
  snapshot: WeeklyChartDto;
}

interface LyricsCacheEntry {
  expiresAt: number;
  lyrics: SongLyricsDto;
}

interface SongDetailCacheEntry {
  expiresAt: number;
  detail: SongDetailDto;
}

interface SongRadioCacheEntry {
  expiresAt: number;
  radio: SongRadioDto;
}

interface LiveRadioCacheEntry {
  expiresAt: number;
  snapshot: LiveRadioSnapshotDto;
}

const CODE_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;
const REQUEST_ID_PATTERN = /^[A-Za-z0-9._:-]{1,128}$/;
const SEARCH_QUERY_MAX_LENGTH = 100;
const SEARCH_PAGE_DEFAULT_LIMIT = 18;
const SEARCH_PAGE_MAX = 100;
const SEARCH_PAGE_LIMIT_MAX = 50;
const SEARCH_CACHE_MAX_ENTRIES = 100;
const CONTROL_CHARACTER_PATTERN = /[\u0000-\u001f\u007f]/;
const SEARCH_RESULT_TYPES = new Set<SearchResultType>([
  'songs',
  'artists',
  'collections',
  'videos',
]);
const WEEKLY_REGIONS = new Set<WeeklyChartRegion>([
  'vietnam',
  'usuk',
  'korea',
]);

function boundedSearchInteger(
  value: unknown,
  fallback: number,
  maximum: number,
) {
  if (value === undefined) return fallback;
  if (typeof value !== 'string' || !/^[1-9]\d*$/.test(value)) return undefined;
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed <= maximum ? parsed : undefined;
}

export async function buildApp(
  config: AppConfig,
  upstream: MusicUpstream,
  audioFetcher: typeof fetch = fetch,
): Promise<FastifyInstance> {
  const app = Fastify({
    // Encrypted HLS child tokens remain bounded but can contain long segment URLs.
    routerOptions: { maxParamLength: 2048 },
    // Set TRUST_PROXY_HOPS=1 when deployed directly behind one trusted ingress.
    trustProxy: config.trustProxyHops,
    logger: config.isProduction
      ? { level: 'info', redact: ['req.headers.authorization', 'req.headers.cookie'] }
      : false,
    genReqId(request) {
      const supplied = request.headers['x-request-id'];
      return typeof supplied === 'string' && REQUEST_ID_PATTERN.test(supplied)
        ? supplied
        : randomUUID();
    },
  });

  await app.register(cors, {
    origin(origin, callback) {
      if (!origin || config.corsOrigins.includes(origin.replace(/\/$/, ''))) {
        callback(null, true);
        return;
      }
      callback(null, false);
    },
  });
  await app.register(rateLimit, {
    max: config.rateLimitMax,
    timeWindow: config.rateLimitWindowMs,
  });

  app.addHook('onRequest', async (request, reply) => {
    reply.header('x-request-id', request.id);
  });
  app.addHook('onResponse', async (request, reply) => {
    request.log.info({
      requestId: request.id,
      method: request.method,
      path: request.routeOptions.url,
      statusCode: reply.statusCode,
      latencyMs: reply.elapsedTime,
    }, 'request completed');
  });

  let chartCache: ChartCacheEntry | undefined;
  let pendingChart: Promise<ChartSnapshotDto> | undefined;
  let newReleaseCache: NewReleaseCacheEntry | undefined;
  let pendingNewReleases: Promise<NewReleaseSnapshotDto> | undefined;
  const discoveryCache = new Map<string, DiscoveryCacheEntry>();
  const pendingDiscovery = new Map<string, Promise<DiscoveryHomeDto>>();
  let discoveryCategoriesCache: DiscoveryCategoriesCacheEntry | undefined;
  let pendingDiscoveryCategories: Promise<DiscoveryCategoriesDto> | undefined;
  let discoveryRecommendationsCache:
    | DiscoveryRecommendationsCacheEntry
    | undefined;
  let pendingDiscoveryRecommendations:
    | Promise<DiscoveryRecommendationsDto>
    | undefined;
  let hubHomeCache: HubHomeCacheEntry | undefined;
  let pendingHubHome: Promise<HubHomeDto> | undefined;
  let top100Cache: Top100CacheEntry | undefined;
  let pendingTop100: Promise<Top100SnapshotDto> | undefined;
  let releaseCatalogCache: ReleaseCatalogCacheEntry | undefined;
  let pendingReleaseCatalog: Promise<ReleaseCatalogDto> | undefined;
  const hubDetailCache = new Map<string, HubDetailCacheEntry>();
  const pendingHubDetail = new Map<string, Promise<HubDetailDto>>();
  const searchCache = new Map<string, SearchCacheEntry>();
  const pendingSearch = new Map<string, Promise<SearchSnapshotDto>>();
  const searchPageCache = new Map<string, SearchPageCacheEntry>();
  const pendingSearchPages = new Map<string, Promise<SearchPageDto>>();
  const searchSuggestionCache = new Map<string, SearchSuggestionCacheEntry>();
  const pendingSearchSuggestions = new Map<
    string,
    Promise<SearchSuggestionSnapshotDto>
  >();
  const collectionCache = new Map<string, CollectionCacheEntry>();
  const pendingCollection = new Map<string, Promise<CollectionDetailDto>>();
  const artistDetailCache = new Map<string, ArtistDetailCacheEntry>();
  const pendingArtistDetail = new Map<string, Promise<ArtistDetailDto>>();
  const weeklyChartCache = new Map<string, WeeklyChartCacheEntry>();
  const pendingWeeklyChart = new Map<string, Promise<WeeklyChartDto>>();
  const lyricsCache = new Map<string, LyricsCacheEntry>();
  const pendingLyrics = new Map<string, Promise<SongLyricsDto>>();
  const songDetailCache = new Map<string, SongDetailCacheEntry>();
  const pendingSongDetail = new Map<string, Promise<SongDetailDto>>();
  const songRadioCache = new Map<string, SongRadioCacheEntry>();
  const pendingSongRadio = new Map<string, Promise<SongRadioDto>>();
  let liveRadioCache: LiveRadioCacheEntry | undefined;
  let pendingLiveRadio: Promise<LiveRadioSnapshotDto> | undefined;

  async function withTimeout<T>(operation: (signal: AbortSignal) => Promise<T>) {
    const controller = new AbortController();
    let timeout: NodeJS.Timeout | undefined;
    const deadline = new Promise<never>((_resolve, reject) => {
      timeout = setTimeout(() => {
        controller.abort();
        reject(new DOMException('Upstream request timed out', 'AbortError'));
      }, config.upstreamTimeoutMs);
    });
    try {
      return await Promise.race([operation(controller.signal), deadline]);
    } finally {
      if (timeout) clearTimeout(timeout);
    }
  }

  function loadChartSnapshot() {
    const now = Date.now();
    if (chartCache && chartCache.expiresAt > now) {
      return Promise.resolve(chartCache.snapshot);
    }
    pendingChart ??= withTimeout((signal) => upstream.fetchChart(signal))
      .then((snapshot) => {
        chartCache = { snapshot, expiresAt: Date.now() + config.chartCacheTtlMs };
        return snapshot;
      })
      .finally(() => {
        pendingChart = undefined;
      });
    return pendingChart;
  }

  function loadNewReleaseSnapshot() {
    const fetchNewReleases = upstream.fetchNewReleases;
    if (!fetchNewReleases) {
      return Promise.reject(new UpstreamError('New release adapter is unavailable'));
    }
    const now = Date.now();
    if (newReleaseCache && newReleaseCache.expiresAt > now) {
      return Promise.resolve(newReleaseCache.snapshot);
    }
    pendingNewReleases ??= withTimeout((signal) =>
      fetchNewReleases.call(upstream, signal))
      .then((snapshot) => {
        newReleaseCache = {
          snapshot,
          expiresAt: Date.now() + config.chartCacheTtlMs,
        };
        return snapshot;
      })
      .finally(() => {
        pendingNewReleases = undefined;
      });
    return pendingNewReleases;
  }

  function loadDiscoveryCategories() {
    const fetchDiscoveryCategories = upstream.fetchDiscoveryCategories;
    if (!fetchDiscoveryCategories) {
      return Promise.reject(
        new UpstreamError('Discovery category adapter is unavailable'),
      );
    }
    const now = Date.now();
    if (
      discoveryCategoriesCache
      && discoveryCategoriesCache.expiresAt > now
    ) {
      return Promise.resolve(discoveryCategoriesCache.categories);
    }
    pendingDiscoveryCategories ??= withTimeout((signal) =>
      fetchDiscoveryCategories.call(upstream, signal))
      .then((categories) => {
        discoveryCategoriesCache = {
          categories,
          expiresAt: Date.now() + config.searchCacheTtlMs,
        };
        return categories;
      })
      .finally(() => {
        pendingDiscoveryCategories = undefined;
      });
    return pendingDiscoveryCategories;
  }

  function loadDiscoveryRecommendations() {
    const fetchDiscoveryRecommendations = upstream.fetchDiscoveryRecommendations;
    if (!fetchDiscoveryRecommendations) {
      return Promise.reject(
        new UpstreamError('Discovery recommendation adapter is unavailable'),
      );
    }
    const now = Date.now();
    if (
      discoveryRecommendationsCache
      && discoveryRecommendationsCache.expiresAt > now
    ) {
      return Promise.resolve(discoveryRecommendationsCache.recommendations);
    }
    pendingDiscoveryRecommendations ??= withTimeout((signal) =>
      fetchDiscoveryRecommendations.call(upstream, signal))
      .then((recommendations) => {
        discoveryRecommendationsCache = {
          recommendations,
          expiresAt: Date.now() + config.searchCacheTtlMs,
        };
        return recommendations;
      })
      .finally(() => {
        pendingDiscoveryRecommendations = undefined;
      });
    return pendingDiscoveryRecommendations;
  }

  function loadDiscoveryHome(categoryId: string) {
    const fetchDiscovery = upstream.fetchDiscovery;
    if (!fetchDiscovery) {
      return Promise.reject(new UpstreamError('Discovery adapter is unavailable'));
    }
    const now = Date.now();
    const cached = discoveryCache.get(categoryId);
    if (cached && cached.expiresAt > now) {
      return Promise.resolve(cached.home);
    }
    let pending = pendingDiscovery.get(categoryId);
    if (pending) return pending;
    pending = withTimeout((signal) =>
      fetchDiscovery.call(upstream, categoryId, signal))
      .then((home) => {
        discoveryCache.set(categoryId, {
          home,
          expiresAt: Date.now() + config.searchCacheTtlMs,
        });
        while (discoveryCache.size > 16) {
          const oldestKey = discoveryCache.keys().next().value;
          if (oldestKey === undefined) break;
          discoveryCache.delete(oldestKey);
        }
        return home;
      })
      .finally(() => {
        pendingDiscovery.delete(categoryId);
      });
    pendingDiscovery.set(categoryId, pending);
    return pending;
  }

  function loadHubHome() {
    const fetchHubHome = upstream.fetchHubHome;
    if (!fetchHubHome) {
      return Promise.reject(new UpstreamError('Hub home adapter is unavailable'));
    }
    const now = Date.now();
    if (hubHomeCache && hubHomeCache.expiresAt > now) {
      return Promise.resolve(hubHomeCache.home);
    }
    pendingHubHome ??= withTimeout((signal) =>
      fetchHubHome.call(upstream, signal))
      .then((home) => {
        hubHomeCache = {
          home,
          expiresAt: Date.now() + config.searchCacheTtlMs,
        };
        return home;
      })
      .finally(() => {
        pendingHubHome = undefined;
      });
    return pendingHubHome;
  }

  function loadTop100() {
    const fetchTop100 = upstream.fetchTop100;
    if (!fetchTop100) {
      return Promise.reject(new UpstreamError('Top 100 adapter is unavailable'));
    }
    const now = Date.now();
    if (top100Cache && top100Cache.expiresAt > now) {
      return Promise.resolve(top100Cache.snapshot);
    }
    pendingTop100 ??= withTimeout((signal) =>
      fetchTop100.call(upstream, signal))
      .then((snapshot) => {
        top100Cache = {
          snapshot,
          expiresAt: Date.now() + config.searchCacheTtlMs,
        };
        return snapshot;
      })
      .finally(() => {
        pendingTop100 = undefined;
      });
    return pendingTop100;
  }

  function loadReleaseCatalog() {
    const fetchReleaseCatalog = upstream.fetchReleaseCatalog;
    if (!fetchReleaseCatalog) {
      return Promise.reject(
        new UpstreamError('New release catalog adapter is unavailable'),
      );
    }
    const now = Date.now();
    if (releaseCatalogCache && releaseCatalogCache.expiresAt > now) {
      return Promise.resolve(releaseCatalogCache.snapshot);
    }
    pendingReleaseCatalog ??= withTimeout((signal) =>
      fetchReleaseCatalog.call(upstream, signal))
      .then((snapshot) => {
        releaseCatalogCache = {
          snapshot,
          expiresAt: Date.now() + config.searchCacheTtlMs,
        };
        return snapshot;
      })
      .finally(() => {
        pendingReleaseCatalog = undefined;
      });
    return pendingReleaseCatalog;
  }

  function loadHubDetail(id: string) {
    const fetchHubDetail = upstream.fetchHubDetail;
    if (!fetchHubDetail) {
      return Promise.reject(new UpstreamError('Hub detail adapter is unavailable'));
    }
    const cached = hubDetailCache.get(id);
    if (cached && cached.expiresAt > Date.now()) {
      return Promise.resolve(cached.detail);
    }
    let pending = pendingHubDetail.get(id);
    if (!pending) {
      pending = withTimeout((signal) =>
        fetchHubDetail.call(upstream, id, signal))
        .then((detail) => {
          hubDetailCache.set(id, {
            detail,
            expiresAt: Date.now() + config.searchCacheTtlMs,
          });
          while (hubDetailCache.size > 50) {
            const oldestKey = hubDetailCache.keys().next().value;
            if (oldestKey === undefined) break;
            hubDetailCache.delete(oldestKey);
          }
          return detail;
        })
        .finally(() => pendingHubDetail.delete(id));
      pendingHubDetail.set(id, pending);
    }
    return pending;
  }

  function loadArtistDetail(alias: string) {
    const fetchArtistDetail = upstream.fetchArtistDetail;
    if (!fetchArtistDetail) {
      return Promise.reject(
        new UpstreamError('Artist detail adapter is unavailable'),
      );
    }
    const cacheKey = alias.toLocaleLowerCase('vi');
    const cached = artistDetailCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      return Promise.resolve(cached.detail);
    }
    let pending = pendingArtistDetail.get(cacheKey);
    if (!pending) {
      pending = withTimeout((signal) =>
        fetchArtistDetail.call(upstream, alias, signal))
        .then((detail) => {
          artistDetailCache.set(cacheKey, {
            detail,
            expiresAt: Date.now() + config.searchCacheTtlMs,
          });
          while (artistDetailCache.size > 50) {
            const oldestKey = artistDetailCache.keys().next().value;
            if (oldestKey === undefined) break;
            artistDetailCache.delete(oldestKey);
          }
          return detail;
        })
        .finally(() => pendingArtistDetail.delete(cacheKey));
      pendingArtistDetail.set(cacheKey, pending);
    }
    return pending;
  }

  function loadWeeklyChart(
    region: WeeklyChartRegion,
    week?: number,
    year?: number,
  ) {
    const fetchWeeklyChart = upstream.fetchWeeklyChart;
    if (!fetchWeeklyChart) {
      return Promise.reject(
        new UpstreamError('Weekly chart adapter is unavailable'),
      );
    }
    const cacheKey = `${region}:${week ?? 0}:${year ?? 0}`;
    const cached = weeklyChartCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      return Promise.resolve(cached.snapshot);
    }
    let pending = pendingWeeklyChart.get(cacheKey);
    if (!pending) {
      pending = withTimeout((signal) =>
        fetchWeeklyChart.call(upstream, region, week, year, signal))
        .then((snapshot) => {
          weeklyChartCache.set(cacheKey, {
            snapshot,
            expiresAt: Date.now() + config.chartCacheTtlMs,
          });
          while (weeklyChartCache.size > 50) {
            const oldestKey = weeklyChartCache.keys().next().value;
            if (oldestKey === undefined) break;
            weeklyChartCache.delete(oldestKey);
          }
          return snapshot;
        })
        .finally(() => pendingWeeklyChart.delete(cacheKey));
      pendingWeeklyChart.set(cacheKey, pending);
    }
    return pending;
  }

  function loadLyrics(code: string) {
    const fetchLyrics = upstream.fetchLyrics;
    if (!fetchLyrics) {
      return Promise.reject(new UpstreamError('Lyric adapter is unavailable'));
    }
    const cached = lyricsCache.get(code);
    if (cached && cached.expiresAt > Date.now()) {
      return Promise.resolve(cached.lyrics);
    }
    let pending = pendingLyrics.get(code);
    if (!pending) {
      pending = withTimeout((signal) =>
        fetchLyrics.call(upstream, code, signal))
        .then((lyrics) => {
          lyricsCache.set(code, {
            lyrics,
            expiresAt: Date.now() + config.searchCacheTtlMs,
          });
          while (lyricsCache.size > 200) {
            const oldestKey = lyricsCache.keys().next().value;
            if (oldestKey === undefined) break;
            lyricsCache.delete(oldestKey);
          }
          return lyrics;
        })
        .finally(() => pendingLyrics.delete(code));
      pendingLyrics.set(code, pending);
    }
    return pending;
  }

  function loadSongDetail(id: string) {
    const fetchSongDetail = upstream.fetchSongDetail;
    if (!fetchSongDetail) {
      return Promise.reject(
        new UpstreamError('Song detail adapter is unavailable'),
      );
    }
    const cached = songDetailCache.get(id);
    if (cached && cached.expiresAt > Date.now()) {
      return Promise.resolve(cached.detail);
    }
    let pending = pendingSongDetail.get(id);
    if (!pending) {
      pending = withTimeout((signal) =>
        fetchSongDetail.call(upstream, id, signal),
      )
        .then((detail) => {
          songDetailCache.set(id, {
            detail,
            expiresAt: Date.now() + config.searchCacheTtlMs,
          });
          while (songDetailCache.size > 200) {
            const oldestKey = songDetailCache.keys().next().value;
            if (oldestKey === undefined) break;
            songDetailCache.delete(oldestKey);
          }
          return detail;
        })
        .finally(() => pendingSongDetail.delete(id));
      pendingSongDetail.set(id, pending);
    }
    return pending;
  }

  function loadSongRadio(code: string) {
    const fetchSongRadio = upstream.fetchSongRadio;
    if (!fetchSongRadio) {
      return Promise.reject(new UpstreamError('Song radio adapter is unavailable'));
    }
    const cached = songRadioCache.get(code);
    if (cached && cached.expiresAt > Date.now()) {
      return Promise.resolve(cached.radio);
    }
    let pending = pendingSongRadio.get(code);
    if (!pending) {
      pending = withTimeout((signal) =>
        fetchSongRadio.call(upstream, code, signal))
        .then((radio) => {
          songRadioCache.set(code, {
            radio,
            expiresAt: Date.now() + config.searchCacheTtlMs,
          });
          while (songRadioCache.size > 200) {
            const oldestKey = songRadioCache.keys().next().value;
            if (oldestKey === undefined) break;
            songRadioCache.delete(oldestKey);
          }
          return radio;
        })
        .finally(() => pendingSongRadio.delete(code));
      pendingSongRadio.set(code, pending);
    }
    return pending;
  }

  function loadLiveRadio() {
    const fetchLiveRadio = upstream.fetchLiveRadio;
    if (!fetchLiveRadio) {
      return Promise.reject(new UpstreamError('Live radio adapter is unavailable'));
    }
    if (liveRadioCache && liveRadioCache.expiresAt > Date.now()) {
      return Promise.resolve(liveRadioCache.snapshot);
    }
    pendingLiveRadio ??= withTimeout((signal) =>
      fetchLiveRadio.call(upstream, signal))
      .then((snapshot) => {
        liveRadioCache = {
          snapshot,
          expiresAt: Date.now() + config.liveRadioCacheTtlMs,
        };
        return snapshot;
      })
      .finally(() => {
        pendingLiveRadio = undefined;
      });
    return pendingLiveRadio;
  }

  app.get('/health', async () => ({ status: 'ok' as const }));

  app.get('/v1/chart', async () => {
    const snapshot = await loadChartSnapshot();
    return {
      songs: snapshot.songs,
      chart: {
        series: snapshot.series,
        minScore: snapshot.minScore,
        maxScore: snapshot.maxScore,
        updatedAt: snapshot.updatedAt,
      },
    };
  });

  app.get('/v1/charts/new-releases', async () => loadNewReleaseSnapshot());

  app.get<{
    Querystring: { region?: string; week?: string; year?: string };
  }>('/v1/charts/weekly', async (request, reply) => {
    const rawRegion = request.query.region?.trim() ?? '';
    if (!WEEKLY_REGIONS.has(rawRegion as WeeklyChartRegion)) {
      return reply.code(400).send({
        error: {
          code: 'INVALID_WEEKLY_REGION',
          message: 'Khu vực bảng xếp hạng tuần không hợp lệ.',
          requestId: request.id,
        },
      });
    }
    const rawWeek = request.query.week?.trim();
    const rawYear = request.query.year?.trim();
    const hasPeriod = rawWeek !== undefined || rawYear !== undefined;
    const week = rawWeek === undefined ? undefined : Number(rawWeek);
    const year = rawYear === undefined ? undefined : Number(rawYear);
    if (
      (hasPeriod && (rawWeek === undefined || rawYear === undefined)) ||
      (week !== undefined && (!Number.isInteger(week) || week < 1 || week > 53)) ||
      (year !== undefined && (!Number.isInteger(year) || year < 2000 || year > 2100))
    ) {
      return reply.code(400).send({
        error: {
          code: 'INVALID_WEEKLY_PERIOD',
          message: 'Tuần hoặc năm của bảng xếp hạng không hợp lệ.',
          requestId: request.id,
        },
      });
    }
    return loadWeeklyChart(
      rawRegion as WeeklyChartRegion,
      week,
      year,
    );
  });

  app.get('/v1/discovery/categories', async () => loadDiscoveryCategories());

  app.get(
    '/v1/discovery/recommendations',
    async () => loadDiscoveryRecommendations(),
  );

  app.get<{ Querystring: { categoryId?: string } }>(
    '/v1/discovery/home',
    async (request, reply) => {
      const categoryId = typeof request.query.categoryId === 'string'
        ? request.query.categoryId.trim()
        : '-1';
      if (!/^(?:-1|[1-9]\d{0,2})$/.test(categoryId)) {
        return reply.code(400).send({
          error: {
            code: 'INVALID_DISCOVERY_CATEGORY',
            message: 'Danh mục Khám phá không hợp lệ.',
            requestId: request.id,
          },
        });
      }
      return loadDiscoveryHome(categoryId);
    },
  );

  app.get('/v1/hubs', async () => loadHubHome());

  app.get('/v1/top-100', async () => loadTop100());

  app.get('/v1/releases', async () => loadReleaseCatalog());

  app.get<{ Params: { alias: string } }>(
    '/v1/artists/:alias',
    async (request, reply) => {
      const alias = request.params.alias.trim();
      if (!CODE_PATTERN.test(alias)) {
        return reply.code(400).send({
          error: {
            code: 'INVALID_ARTIST_ALIAS',
            message: 'Định danh nghệ sĩ không hợp lệ.',
            requestId: request.id,
          },
        });
      }
      return loadArtistDetail(alias);
    },
  );

  app.get<{ Params: { id: string } }>('/v1/hubs/:id', async (request, reply) => {
    const id = request.params.id.trim();
    if (!CODE_PATTERN.test(id)) {
      return reply.code(400).send({
        error: {
          code: 'INVALID_HUB_ID',
          message: 'Mã chủ đề không hợp lệ.',
          requestId: request.id,
        },
      });
    }
    return loadHubDetail(id);
  });

  app.get<{ Querystring: { q?: string } }>(
    '/v1/search/suggestions',
    async (request, reply) => {
      const rawQuery = typeof request.query.q === 'string'
        ? request.query.q.trim()
        : '';
      const query = rawQuery.replace(/\s+/g, ' ');
      if (
        !query
        || query.length > SEARCH_QUERY_MAX_LENGTH
        || CONTROL_CHARACTER_PATTERN.test(rawQuery)
      ) {
        return reply.code(400).send({
          error: {
            code: 'INVALID_SEARCH_QUERY',
            message: 'Từ khóa gợi ý phải có từ 1 đến 100 ký tự.',
            requestId: request.id,
          },
        });
      }
      const fetchSuggestions = upstream.fetchSearchSuggestions;
      if (!fetchSuggestions) {
        throw new UpstreamError('Search suggestions adapter is unavailable');
      }
      const cacheKey = query.toLocaleLowerCase('vi');
      const cached = searchSuggestionCache.get(cacheKey);
      if (cached && cached.expiresAt > Date.now()) return cached.snapshot;
      let pending = pendingSearchSuggestions.get(cacheKey);
      if (!pending) {
        pending = withTimeout((signal) =>
          fetchSuggestions.call(upstream, query, signal))
          .then((snapshot) => {
            searchSuggestionCache.set(cacheKey, {
              snapshot,
              expiresAt: Date.now() + config.searchCacheTtlMs,
            });
            while (searchSuggestionCache.size > 100) {
              const oldestKey = searchSuggestionCache.keys().next().value;
              if (oldestKey === undefined) break;
              searchSuggestionCache.delete(oldestKey);
            }
            return snapshot;
          })
          .finally(() => pendingSearchSuggestions.delete(cacheKey));
        pendingSearchSuggestions.set(cacheKey, pending);
      }
      return pending;
    },
  );

  app.get<{
    Querystring: {
      q?: unknown;
      type?: unknown;
      page?: unknown;
      limit?: unknown;
    };
  }>('/v1/search', async (request, reply) => {
    const rawQuery = typeof request.query.q === 'string'
      ? request.query.q.trim()
      : '';
    const query = rawQuery.replace(/\s+/g, ' ');
    if (
      !query
      || query.length > SEARCH_QUERY_MAX_LENGTH
      || CONTROL_CHARACTER_PATTERN.test(rawQuery)
    ) {
      return reply.code(400).send({
        error: {
          code: 'INVALID_SEARCH_QUERY',
          message: 'Từ khóa tìm kiếm phải có từ 1 đến 100 ký tự.',
          requestId: request.id,
        },
      });
    }

    const rawType = request.query.type;
    if (rawType === undefined) {
      if (request.query.page !== undefined || request.query.limit !== undefined) {
        return reply.code(400).send({
          error: {
            code: 'INVALID_SEARCH_PAGINATION',
            message: 'Phân trang tìm kiếm cần một loại kết quả hợp lệ.',
            requestId: request.id,
          },
        });
      }

      // Search and chart load concurrently. Awaiting this snapshot means chart
      // songs are playable on the very first search response, while a chart
      // outage never prevents public catalog discovery.
      const chartSnapshot = loadChartSnapshot().catch(() => undefined);

      const cacheKey = query.toLocaleLowerCase('vi');
      const cached = searchCache.get(cacheKey);
      let snapshot: SearchSnapshotDto;
      if (cached && cached.expiresAt > Date.now()) {
        snapshot = cached.snapshot;
      } else {
        if (cached) searchCache.delete(cacheKey);
        let pending = pendingSearch.get(cacheKey);
        if (!pending) {
          pending = withTimeout((signal) => upstream.fetchSearch(query, signal))
            .then((result) => {
              searchCache.set(cacheKey, {
                snapshot: result,
                expiresAt: Date.now() + config.searchCacheTtlMs,
              });
              while (searchCache.size > SEARCH_CACHE_MAX_ENTRIES) {
                const oldestKey = searchCache.keys().next().value;
                if (oldestKey === undefined) break;
                searchCache.delete(oldestKey);
              }
              return result;
            })
            .finally(() => pendingSearch.delete(cacheKey));
          pendingSearch.set(cacheKey, pending);
        }
        snapshot = await pending;
      }

      const chartCodes = new Map(
        ((await chartSnapshot)?.songs ?? []).map((song) => [song.id, song.code]),
      );
      return {
        ...snapshot,
        query,
        videos: snapshot.videos ?? [],
        songs: snapshot.songs.map((song) => {
          const chartCode = chartCodes.get(song.id);
          return chartCode
            ? { ...song, code: chartCode, playable: true }
            : song;
        }),
      };
    }

    if (
      typeof rawType !== 'string'
      || !SEARCH_RESULT_TYPES.has(rawType as SearchResultType)
    ) {
      return reply.code(400).send({
        error: {
          code: 'INVALID_SEARCH_TYPE',
          message: 'Loại kết quả phải là songs, artists, collections hoặc videos.',
          requestId: request.id,
        },
      });
    }
    const type = rawType as SearchResultType;
    const page = boundedSearchInteger(request.query.page, 1, SEARCH_PAGE_MAX);
    if (page === undefined) {
      return reply.code(400).send({
        error: {
          code: 'INVALID_SEARCH_PAGE',
          message: 'Trang tìm kiếm phải là số nguyên từ 1 đến 100.',
          requestId: request.id,
        },
      });
    }
    const limit = boundedSearchInteger(
      request.query.limit,
      SEARCH_PAGE_DEFAULT_LIMIT,
      SEARCH_PAGE_LIMIT_MAX,
    );
    if (limit === undefined) {
      return reply.code(400).send({
        error: {
          code: 'INVALID_SEARCH_LIMIT',
          message: 'Số kết quả mỗi trang phải là số nguyên từ 1 đến 50.',
          requestId: request.id,
        },
      });
    }

    const fetchSearchPage = upstream.fetchSearchPage;
    if (upstream.supportsPaginatedSearch !== true || !fetchSearchPage) {
      reply.header('cache-control', 'private, no-store, max-age=0');
      return reply.code(501).send({
        error: {
          code: 'SEARCH_PAGINATION_UNAVAILABLE',
          message: 'Tìm kiếm phân trang chưa khả dụng trên máy chủ này.',
          requestId: request.id,
        },
      });
    }

    const chartSnapshot = type === 'songs'
      ? loadChartSnapshot().catch(() => undefined)
      : Promise.resolve(undefined);
    const cacheKey = JSON.stringify([
      query.toLocaleLowerCase('vi'),
      type,
      page,
      limit,
    ]);
    const cached = searchPageCache.get(cacheKey);
    let searchPage: SearchPageDto;
    if (cached && cached.expiresAt > Date.now()) {
      searchPage = cached.page;
    } else {
      if (cached) searchPageCache.delete(cacheKey);
      let pending = pendingSearchPages.get(cacheKey);
      if (!pending) {
        pending = withTimeout((signal) =>
          fetchSearchPage.call(upstream, query, type, page, limit, signal))
          .then((result) => {
            if (
              result.query !== query
              || result.type !== type
              || result.page !== page
              || result.limit !== limit
            ) {
              throw new UpstreamError('Paginated search identity is invalid');
            }
            searchPageCache.set(cacheKey, {
              page: result,
              expiresAt: Date.now() + config.searchCacheTtlMs,
            });
            while (searchPageCache.size > SEARCH_CACHE_MAX_ENTRIES) {
              const oldestKey = searchPageCache.keys().next().value;
              if (oldestKey === undefined) break;
              searchPageCache.delete(oldestKey);
            }
            return result;
          })
          .finally(() => pendingSearchPages.delete(cacheKey));
        pendingSearchPages.set(cacheKey, pending);
      }
      searchPage = await pending;
    }

    if (searchPage.type !== 'songs') {
      return { ...searchPage, query, type, page, limit };
    }
    const chartCodes = new Map(
      ((await chartSnapshot)?.songs ?? []).map((song) => [song.id, song.code]),
    );
    return {
      ...searchPage,
      query,
      type,
      page,
      limit,
      items: searchPage.items.map((song) => {
        const chartCode = chartCodes.get(song.id);
        return chartCode
          ? { ...song, code: chartCode, playable: true }
          : song;
      }),
    };
  });

  app.get<{ Params: { id: string } }>('/v1/collections/:id', async (request, reply) => {
    const id = request.params.id.trim();
    if (!CODE_PATTERN.test(id)) {
      return reply.code(400).send({
        error: {
          code: 'INVALID_COLLECTION_ID',
          message: 'Mã playlist/album không hợp lệ.',
          requestId: request.id,
        },
      });
    }
    const chartSnapshot = loadChartSnapshot().catch(() => undefined);
    const cached = collectionCache.get(id);
    let detail: CollectionDetailDto;
    if (cached && cached.expiresAt > Date.now()) {
      detail = cached.detail;
    } else {
      let pending = pendingCollection.get(id);
      if (!pending) {
        pending = withTimeout((signal) => upstream.fetchCollection(id, signal))
          .then((result) => {
            collectionCache.set(id, {
              detail: result,
              expiresAt: Date.now() + config.searchCacheTtlMs,
            });
            while (collectionCache.size > 100) {
              const oldestKey = collectionCache.keys().next().value;
              if (oldestKey === undefined) break;
              collectionCache.delete(oldestKey);
            }
            return result;
          })
          .finally(() => pendingCollection.delete(id));
        pendingCollection.set(id, pending);
      }
      detail = await pending;
    }
    const chartCodes = new Map(
      ((await chartSnapshot)?.songs ?? []).map((song) => [song.id, song.code]),
    );
    return {
      ...detail,
      songs: detail.songs.map((song) => {
        const chartCode = chartCodes.get(song.id);
        return chartCode
          ? { ...song, code: chartCode, playable: true }
          : song;
      }),
    };
  });

  app.get<{ Params: { id: string } }>(
    '/v1/songs/:id/detail',
    async (request, reply) => {
      const id = request.params.id.trim();
      if (!CODE_PATTERN.test(id)) {
        return reply.code(400).send({
          error: {
            code: 'INVALID_CODE',
            message: 'Mã bài hát không hợp lệ.',
            requestId: request.id,
          },
        });
      }
      const detail = await loadSongDetail(id);
      reply.header(
        'cache-control',
        'public, max-age=300, stale-while-revalidate=600',
      );
      return detail;
    },
  );

  app.get<{ Params: { code: string } }>(
    '/v1/songs/:code/lyrics',
    async (request, reply) => {
      const code = request.params.code.trim();
      if (!CODE_PATTERN.test(code)) {
        return reply.code(400).send({
          error: {
            code: 'INVALID_CODE',
            message: 'Mã bài hát không hợp lệ.',
            requestId: request.id,
          },
        });
      }
      const lyrics = await loadLyrics(code);
      reply.header(
        'cache-control',
        'public, max-age=300, stale-while-revalidate=600',
      );
      return lyrics;
    },
  );

  app.get('/v1/radio', async (_request, reply) => {
    const snapshot = await loadLiveRadio();
    reply.header('cache-control', 'public, max-age=15, stale-while-revalidate=30');
    return snapshot;
  });

  app.get<{ Params: { id: string } }>(
    '/v1/radio/:id/source',
    async (request, reply) => {
      const id = request.params.id.trim();
      if (!CODE_PATTERN.test(id)) {
        return reply.code(400).send({
          error: {
            code: 'INVALID_RADIO_ID',
            message: 'Mã phòng nhạc không hợp lệ.',
            requestId: request.id,
          },
        });
      }
      if (!upstream.resolveLiveRadioStream) {
        throw new UpstreamError('Live radio adapter is unavailable');
      }
      const currentSource = await withTimeout((signal) =>
        upstream.resolveLiveRadioStream!(id, signal));
      if (!isAllowedStreamUrl(currentSource, config.streamHosts)) {
        throw new UpstreamError('Live stream URL is not allowed');
      }
      const token = createLiveStreamToken(
        'room',
        id,
        config.streamTokenSecret,
        config.liveStreamTokenTtlSeconds,
      );
      reply.header('cache-control', 'private, no-store, max-age=0');
      return { url: `${config.publicBaseUrl}/v1/live-streams/${token}` };
    },
  );

  app.get<{ Params: { code: string } }>(
    '/v1/songs/:code/radio',
    async (request, reply) => {
      const code = request.params.code.trim();
      if (!CODE_PATTERN.test(code)) {
        return reply.code(400).send({
          error: {
            code: 'INVALID_CODE',
            message: 'Mã bài hát không hợp lệ.',
            requestId: request.id,
          },
        });
      }
      const radio = await loadSongRadio(code);
      reply.header(
        'cache-control',
        'public, max-age=300, stale-while-revalidate=600',
      );
      return radio;
    },
  );

  app.get<{
    Params: { code: string };
    Querystring: { quality?: string };
  }>('/v1/songs/:code/source', async (request, reply) => {
    const code = request.params.code.trim();
    if (!CODE_PATTERN.test(code)) {
      return reply.code(400).send({
        error: { code: 'INVALID_CODE', message: 'Mã bài hát không hợp lệ.', requestId: request.id },
      });
    }
    const rawQuality = request.query.quality;
    const requestedQuality = rawQuality === undefined
      ? 'auto'
      : typeof rawQuality === 'string'
        ? rawQuality.trim()
        : '';
    if (requestedQuality !== 'auto'
      && requestedQuality !== '128'
      && requestedQuality !== '320') {
      return reply.code(400).send({
        error: {
          code: 'INVALID_QUALITY',
          message: 'Chất lượng phát nhạc không hợp lệ.',
          requestId: request.id,
        },
      });
    }
    const quality = requestedQuality as StreamQuality;
    const token = createStreamToken(
      code,
      config.streamTokenSecret,
      config.streamTokenTtlSeconds,
      Date.now(),
      quality,
    );
    reply.header('cache-control', 'private, no-store, max-age=0');
    return { url: `${config.publicBaseUrl}/v1/streams/${token}` };
  });

  app.get<{ Params: { token: string } }>('/v1/streams/:token', async (request, reply) => {
    reply.header('cache-control', 'private, no-store, max-age=0');
    reply.header('pragma', 'no-cache');
    const token = readStreamTokenPayload(
      request.params.token,
      config.streamTokenSecret,
    );
    if (!token || !CODE_PATTERN.test(token.code)) {
      return reply.code(401).send({
        error: { code: 'INVALID_STREAM_TOKEN', message: 'Liên kết phát nhạc không hợp lệ hoặc đã hết hạn.', requestId: request.id },
      });
    }
    const range = typeof request.headers.range === 'string' ? request.headers.range : undefined;
    if (!validRange(range)) {
      return reply.code(400).send({
        error: { code: 'INVALID_RANGE', message: 'Khoảng dữ liệu không hợp lệ.', requestId: request.id },
      });
    }
    const sourceUrl = await withTimeout((signal) => token.quality === 'auto'
      ? upstream.fetchSource(token.code, signal)
      : upstream.fetchSource(token.code, signal, token.quality));
    const relay = await fetchAudio(sourceUrl, range, config, audioFetcher);
    const { response } = relay;
    for (const header of ['content-type', 'content-length', 'content-range', 'accept-ranges'] as const) {
      const value = response.headers.get(header);
      if (value) reply.header(header, value);
    }
    if (!reply.getHeader('content-type')) reply.type('audio/mpeg');
    if (response.status === 416) {
      relay.dispose();
      return reply.code(416).send();
    }
    const body = audioBody(response, relay.signal, relay.dispose);
    reply.raw.once('close', () => {
      if (!body.destroyed) body.destroy();
      relay.abort();
    });
    return reply.code(response.status).send(body);
  });

  app.get<{ Params: { token: string } }>(
    '/v1/live-streams/:token',
    async (request, reply) => {
      reply.header('cache-control', 'private, no-store, max-age=0');
      reply.header('pragma', 'no-cache');
      const token = readLiveStreamToken(
        request.params.token,
        config.streamTokenSecret,
      );
      if (!token) {
        return reply.code(401).send({
          error: {
            code: 'INVALID_LIVE_STREAM_TOKEN',
            message: 'Liên kết phòng nhạc không hợp lệ hoặc đã hết hạn.',
            requestId: request.id,
          },
        });
      }
      let sourceUrl: string;
      if (token.kind === 'room') {
        if (!CODE_PATTERN.test(token.value) || !upstream.resolveLiveRadioStream) {
          return reply.code(401).send({
            error: {
              code: 'INVALID_LIVE_STREAM_TOKEN',
              message: 'Liên kết phòng nhạc không hợp lệ hoặc đã hết hạn.',
              requestId: request.id,
            },
          });
        }
        sourceUrl = await withTimeout((signal) =>
          upstream.resolveLiveRadioStream!(token.value, signal));
      } else {
        sourceUrl = token.value;
      }
      if (!isAllowedStreamUrl(sourceUrl, config.streamHosts)) {
        throw new UpstreamError('Live stream URL is not allowed');
      }
      const range = typeof request.headers.range === 'string'
        ? request.headers.range
        : undefined;
      if (!validRange(range)) {
        return reply.code(400).send({
          error: {
            code: 'INVALID_RANGE',
            message: 'Khoảng dữ liệu không hợp lệ.',
            requestId: request.id,
          },
        });
      }
      const pathIsPlaylist = new URL(sourceUrl).pathname
        .toLowerCase()
        .endsWith('.m3u8');
      if (range && pathIsPlaylist) {
        return reply.code(400).send({
          error: {
            code: 'INVALID_RANGE',
            message: 'Playlist phòng nhạc không hỗ trợ range.',
            requestId: request.id,
          },
        });
      }
      const relay = await fetchLiveResource(
        sourceUrl,
        range,
        config,
        audioFetcher,
      );
      if (isHlsPlaylist(relay.response, relay.finalUrl)) {
        if (range) {
          relay.abort();
          return reply.code(400).send({
            error: {
              code: 'INVALID_RANGE',
              message: 'Playlist phòng nhạc không hỗ trợ range.',
              requestId: request.id,
            },
          });
        }
        const playlist = await readHlsPlaylist(relay);
        const rewritten = rewriteHlsPlaylist(
          playlist,
          relay.finalUrl,
          (absoluteUrl) => {
            if (!isAllowedStreamUrl(absoluteUrl, config.streamHosts)) {
              throw new UpstreamError('Live playlist contains a disallowed URL');
            }
            const childToken = createLiveStreamToken(
              'url',
              absoluteUrl,
              config.streamTokenSecret,
              config.liveStreamTokenTtlSeconds,
            );
            return `${config.publicBaseUrl}/v1/live-streams/${childToken}`;
          },
        );
        reply.type('application/vnd.apple.mpegurl');
        return reply.code(200).send(rewritten);
      }
      const { response } = relay;
      for (const header of [
        'content-type',
        'content-length',
        'content-range',
        'accept-ranges',
      ] as const) {
        const value = response.headers.get(header);
        if (value) reply.header(header, value);
      }
      if (!reply.getHeader('content-type')) reply.type('application/octet-stream');
      if (response.status === 416) {
        relay.dispose();
        return reply.code(416).send();
      }
      const body = liveMediaBody(relay);
      reply.raw.once('close', () => {
        if (!body.destroyed) body.destroy();
        relay.abort();
      });
      return reply.code(response.status).send(body);
    },
  );

  app.setNotFoundHandler((request, reply) => reply.code(404).send({
    error: { code: 'NOT_FOUND', message: 'Không tìm thấy tài nguyên.', requestId: request.id },
  }));

  app.setErrorHandler((error, request, reply) => {
    const knownError = error instanceof Error ? error : new Error('Unknown error');
    const statusCode = 'statusCode' in knownError
      ? Number(knownError.statusCode)
      : undefined;
    if (statusCode === 429) {
      return reply.code(429).send({
        error: { code: 'RATE_LIMITED', message: 'Quá nhiều yêu cầu. Vui lòng thử lại sau.', requestId: request.id },
      });
    }
    const timedOut = knownError.name === 'AbortError';
    const upstreamFailure = knownError instanceof UpstreamError || timedOut;
    request.log.error({
      requestId: request.id,
      err: knownError,
      upstreamStatus: knownError instanceof UpstreamError ? knownError.status : undefined,
    }, 'request failed');
    return reply.code(upstreamFailure ? 502 : 500).send({
      error: {
        code: timedOut ? 'UPSTREAM_TIMEOUT' : upstreamFailure ? 'UPSTREAM_ERROR' : 'INTERNAL_ERROR',
        message: timedOut
          ? 'Dịch vụ âm nhạc phản hồi quá chậm.'
          : upstreamFailure
            ? 'Không thể tải dữ liệu âm nhạc lúc này.'
            : 'Đã xảy ra lỗi máy chủ.',
        requestId: request.id,
      },
    });
  });

  return app;
}
