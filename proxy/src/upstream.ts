import { createHash, createHmac } from 'node:crypto';
import { isAllowedStreamUrl } from './audio-relay.js';
import type { AppConfig } from './config.js';
import {
  type ArtistCollectionSectionDto,
  type ArtistDetailDto,
  type ChartPointDto,
  type ChartSnapshotDto,
  type CollectionDetailDto,
  type CollectionKind,
  type DiscoveryBannerDto,
  type DiscoveryCategoriesDto,
  type DiscoveryCollectionDto,
  type DiscoveryHomeDto,
  type DiscoveryRecommendationsDto,
  type DiscoverySectionDto,
  type CatalogHubDto,
  type HubDetailDto,
  type HubHomeDto,
  type LyricLineDto,
  type LiveRadioProgramDto,
  type LiveRadioRoomDto,
  type LiveRadioSnapshotDto,
  type MusicUpstream,
  type NewReleaseSnapshotDto,
  type ReleaseAlbumDto,
  type ReleaseCatalogDto,
  type ReleaseRegion,
  type ReleaseSongDto,
  type SearchArtistDto,
  type SearchCollectionDto,
  type SearchSnapshotDto,
  type SearchSuggestionSnapshotDto,
  type SearchSuggestionSongDto,
  type SearchSongDto,
  type SearchVideoDto,
  type SongDetailDto,
  type SongLyricsDto,
  type SongRadioDto,
  type SongDto,
  type StreamQuality,
  type Top100SnapshotDto,
  type WeeklyChartDto,
  type WeeklyChartRegion,
  UpstreamError,
} from './types.js';

type JsonObject = Record<string, unknown>;

function asObject(value: unknown): JsonObject | undefined {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? (value as JsonObject)
    : undefined;
}

function text(value: unknown) {
  return typeof value === 'string' ? value.trim() : '';
}

function finiteNumber(value: unknown, fallback = 0) {
  const result = Number(value);
  return Number.isFinite(result) ? result : fallback;
}

function normalizeUrl(value: string, baseUrl: string) {
  const upgraded = value.startsWith('//')
    ? `https:${value}`
    : value.startsWith('http://')
      ? `https://${value.slice(7)}`
      : value;
  let parsed: URL;
  try {
    parsed = new URL(upgraded, baseUrl);
  } catch {
    throw new UpstreamError('Upstream returned an invalid media URL');
  }
  if (parsed.protocol !== 'https:') {
    throw new UpstreamError('Upstream returned an unsafe media URL');
  }
  return parsed.toString();
}

function normalizeArtworkUrl(value: string) {
  if (!value) return '';
  return normalizeUrl(
    value,
    'https://photo-resize-zmp3.zmdcdn.me/w240_r1x1_jpeg/',
  );
}

function optionalArtworkUrl(value: unknown) {
  const candidate = text(value);
  if (!candidate) return '';
  try {
    return normalizeArtworkUrl(candidate);
  } catch {
    return '';
  }
}

function plainBiography(value: unknown) {
  const source = text(value);
  if (!source) return '';
  return source
    .replace(/<br\s*\/?\s*>/gi, '\n')
    .replace(/<[^>]*>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&quot;/gi, '"')
    .replace(/&#0?39;|&apos;/gi, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/[ \t]+/g, ' ')
    .replace(/ *\n */g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim()
    .slice(0, 4_000);
}

function artistProfile(
  value: JsonObject,
  currentApiBaseUrl: string,
): SearchArtistDto | undefined {
  const id = text(value.id) || text(value.encodeId);
  const name = text(value.name);
  const aliasName = text(value.alias) || text(value.aliasName);
  if (!id || !name || !aliasName) return undefined;
  const link = text(value.link);
  const totalFollow = Math.min(
    2_147_483_647,
    Math.max(0, Math.floor(finiteNumber(value.totalFollow))),
  );
  return {
    id,
    name,
    aliasName,
    avatar: optionalArtworkUrl(value.thumbnailM || value.thumbnail),
    externalUrl: /^\/nghe-si\//.test(link)
      ? normalizeUrl(link, currentApiBaseUrl)
      : normalizeUrl(
          `/nghe-si/${encodeURIComponent(aliasName)}`,
          currentApiBaseUrl,
        ),
    ...(totalFollow > 0 ? { totalFollow } : {}),
  };
}

function structuredSongArtists(
  value: unknown,
  currentApiBaseUrl: string,
): SearchArtistDto[] {
  const artistsById = new Map<string, SearchArtistDto>();
  const rawArtists = Array.isArray(value) ? value : [];
  for (const rawArtist of rawArtists) {
    const item = asObject(rawArtist);
    const artist = item ? artistProfile(item, currentApiBaseUrl) : undefined;
    if (
      !artist
      || !/^[A-Za-z0-9_-]{1,128}$/.test(artist.id)
      || !/^[A-Za-z0-9_-]{1,200}$/.test(artist.aliasName)
      || artist.name.length > 300
    ) {
      continue;
    }
    artistsById.set(artist.id, artist);
    if (artistsById.size === 8) break;
  }
  return [...artistsById.values()];
}

function structuredSongAlbum(
  value: unknown,
  currentApiBaseUrl: string,
): SearchCollectionDto | undefined {
  const rawAlbum = asObject(value);
  const candidate = rawAlbum
    ? discoveryCollection(rawAlbum, currentApiBaseUrl)
    : undefined;
  if (
    !candidate
    || !/^[A-Za-z0-9_-]{1,128}$/.test(candidate.id)
    || candidate.title.length > 300
    || candidate.artist.length > 300
  ) {
    return undefined;
  }
  return { ...candidate, kind: 'album' };
}

function artistSongs(
  value: unknown,
  currentApiBaseUrl: string,
  limit = 50,
) {
  const songs = new Map<string, SearchSongDto>();
  const rawItems = Array.isArray(value) ? value : [];
  for (const rawItem of rawItems) {
    const item = asObject(rawItem);
    if (!item || item.isPrivate === true || item.preRelease === true) continue;
    const id = text(item.encodeId);
    const title = text(item.title);
    if (
      !/^[A-Za-z0-9_-]{1,128}$/.test(id)
      || !title
      || title.length > 300
      || songs.has(id)
    ) {
      continue;
    }
    const link = text(item.link);
    try {
      const album = structuredSongAlbum(item.album, currentApiBaseUrl);
      songs.set(id, {
        id,
        code: id,
        title,
        artist: text(item.artistsNames).slice(0, 300),
        artists: structuredSongArtists(item.artists, currentApiBaseUrl),
        albumCover: optionalArtworkUrl(item.thumbnailM || item.thumbnail),
        ...(album ? { album } : {}),
        durationSeconds: Math.min(
          24 * 60 * 60,
          Math.max(0, Math.floor(finiteNumber(item.duration))),
        ),
        externalUrl: /^\/bai-hat\//.test(link)
          ? normalizeUrl(link, currentApiBaseUrl)
          : `${currentApiBaseUrl}/link/song/${encodeURIComponent(id)}`,
        playable: String(item.streamingStatus ?? '').trim() === '1',
      });
    } catch {
      // One malformed song must not invalidate the complete artist catalog.
    }
    if (songs.size >= limit) break;
  }
  return [...songs.values()];
}

const MAX_COLLECTION_PAGE_BYTES = 2_000_000;
const MAX_COLLECTION_REDIRECTS = 3;
const COLLECTION_PLAYABILITY_CONCURRENCY = 4;
const MAX_LYRIC_LINES = 500;
const MAX_LYRIC_LINE_CHARACTERS = 500;
const MAX_LYRIC_WORDS_PER_LINE = 100;
const MAX_LYRIC_WORD_CHARACTERS = 80;
const MAX_LYRIC_TIME_MS = 24 * 60 * 60 * 1000;
const MAX_LYRIC_FILE_BYTES = 512_000;
const MAX_LYRIC_REDIRECTS = 3;
const REDIRECT_STATUSES = new Set([301, 302, 303, 307, 308]);
const WEEKLY_CHART_IDS: Record<WeeklyChartRegion, string> = {
  vietnam: 'IWZ9Z08I',
  usuk: 'IWZ9Z0BW',
  korea: 'IWZ9Z0BO',
};

function trustedCollectionUrl(value: string | URL, apiBaseUrl: string) {
  let candidate: URL;
  let base: URL;
  try {
    base = new URL(apiBaseUrl);
    candidate = new URL(value, base);
  } catch {
    return false;
  }
  return candidate.protocol === 'https:'
    && candidate.origin === base.origin
    && candidate.username === ''
    && candidate.password === ''
    && (/^\/link\/album\/[A-Za-z0-9_-]+\/?$/.test(candidate.pathname)
      || /^\/(?:album|playlist)\//.test(candidate.pathname));
}

async function readTextWithByteLimit(
  response: Response,
  limit: number,
  resource = 'collection page',
) {
  const reader = response.body?.getReader();
  if (!reader) throw new UpstreamError(`Upstream ${resource} has no body`);
  const decoder = new TextDecoder();
  let size = 0;
  let body = '';
  try {
    while (true) {
      const chunk = await reader.read();
      if (chunk.done) break;
      size += chunk.value.byteLength;
      if (size > limit) {
        await reader.cancel(`${resource} exceeded its byte limit`);
        throw new UpstreamError(`Upstream ${resource} is too large`);
      }
      body += decoder.decode(chunk.value, { stream: true });
    }
    return body + decoder.decode();
  } catch (error) {
    if (error instanceof UpstreamError || isAbortError(error)) throw error;
    throw new UpstreamError(`Unable to read upstream ${resource}`);
  } finally {
    reader.releaseLock();
  }
}

function trustedLyricUrl(
  value: string | URL,
  apiBaseUrl: string,
  allowedHosts: string[],
) {
  let candidate: URL;
  let base: URL;
  try {
    base = new URL(apiBaseUrl);
    candidate = new URL(value, base);
  } catch {
    return false;
  }
  const hostname = candidate.hostname.toLowerCase();
  const hosts = new Set([
    base.hostname.toLowerCase(),
    ...allowedHosts.map((host) => host.toLowerCase()),
  ]);
  return candidate.protocol === 'https:'
    && candidate.username === ''
    && candidate.password === ''
    && (candidate.port === '' || candidate.port === '443')
    && [...hosts].some(
      (host) => hostname === host || hostname.endsWith(`.${host}`),
    );
}

async function discardResponseBody(response: Response) {
  try {
    await response.body?.cancel();
  } catch {
    // The response is already being rejected; cancellation is best-effort.
  }
}

function collectionKind(value: JsonObject): CollectionKind {
  const attributes = Math.max(0, Math.floor(finiteNumber(value.boolAttribute)));
  if ((attributes & 256) !== 0) return 'playlist';
  const name = text(value.name).toLocaleLowerCase('vi');
  return /\b(single|ep|album)\b/.test(name) ? 'album' : 'playlist';
}

function discoveryCollection(
  value: JsonObject,
  apiBaseUrl: string,
  allowUntitled = false,
): SearchCollectionDto | undefined {
  const id = text(value.encodeId);
  const title = text(value.title) || (allowUntitled ? 'Nổi bật hôm nay' : '');
  const link = text(value.link);
  const thumbnail =
    text(value.thumbnailM) ||
    text(value.thumbnail) ||
    text(value.banner) ||
    text(value.cover);
  if (!id || !title || !link || !thumbnail) return undefined;
  if (!/^\/(?:album|playlist)\//.test(link)) return undefined;
  try {
    const artists = structuredSongArtists(value.artists, apiBaseUrl);
    return {
      id,
      title,
      artist: text(value.artistsNames),
      ...(artists.length ? { artists } : {}),
      thumbnail: normalizeArtworkUrl(thumbnail),
      kind: value.isAlbum === true || value.isSingle === true
        ? 'album'
        : 'playlist',
      externalUrl: normalizeUrl(link, apiBaseUrl),
    };
  } catch {
    return undefined;
  }
}

function discoveryCollectionWithDescription(
  value: JsonObject,
  apiBaseUrl: string,
): DiscoveryCollectionDto | undefined {
  const collection = discoveryCollection(value, apiBaseUrl);
  return collection
    ? { ...collection, description: text(value.sortDescription) }
    : undefined;
}

function discoveryVideo(
  value: JsonObject,
  apiBaseUrl: string,
): SearchVideoDto | undefined {
  if (
    value.isPrivate === true
    || value.preRelease === true
    || String(value.streamingStatus ?? '').trim() !== '1'
  ) {
    return undefined;
  }
  const id = text(value.encodeId) || text(value.id);
  const title = text(value.title) || text(value.name);
  const link = text(value.link);
  const thumbnail = optionalArtworkUrl(value.thumbnailM || value.thumbnail);
  if (
    !/^[A-Za-z0-9_-]{1,128}$/.test(id)
    || !title
    || !thumbnail
    || !/^\/video-clip\//.test(link)
  ) {
    return undefined;
  }
  try {
    const artists = structuredSongArtists(
      value.artists,
      apiBaseUrl,
    );
    return {
      id,
      title: title.slice(0, 300),
      artist: text(value.artistsNames || value.artist).slice(0, 300),
      ...(artists.length > 0 ? { artists } : {}),
      thumbnail,
      durationSeconds: Math.min(
        24 * 60 * 60,
        Math.max(0, Math.floor(finiteNumber(value.duration))),
      ),
      externalUrl: normalizeUrl(link, apiBaseUrl),
    };
  } catch {
    return undefined;
  }
}

function discoverySection(
  value: JsonObject,
  index: number,
  apiBaseUrl: string,
  fallbackTitle = '',
): DiscoverySectionDto | undefined {
  const title = text(value.title) || fallbackTitle;
  const items = Array.isArray(value.items) ? value.items : [];
  if (!title || items.length === 0) return undefined;
  const collections = items
    .flatMap((item) => {
      const object = asObject(item);
      if (!object) return [];
      const collection = discoveryCollectionWithDescription(
        object,
        apiBaseUrl,
      );
      return collection ? [collection] : [];
    })
    .slice(0, 20);
  if (collections.length === 0) return undefined;
  return {
    id: text(value.sectionId) || `section-${index + 1}`,
    title,
    collections,
  };
}

function catalogHub(
  value: JsonObject,
  apiBaseUrl: string,
): CatalogHubDto | undefined {
  const id = text(value.encodeId);
  const title = text(value.title);
  const link = text(value.link);
  const image =
    text(value.cover) ||
    text(value.thumbnailR) ||
    text(value.thumbnail);
  if (!id || !title || !link || !image || !/^\/hub\//.test(link)) {
    return undefined;
  }
  try {
    const rawCollections = Array.isArray(value.playlists)
      ? value.playlists
      : [];
    const collections = rawCollections
      .flatMap((item) => {
        const object = asObject(item);
        if (!object) return [];
        const collection = discoveryCollectionWithDescription(
          object,
          apiBaseUrl,
        );
        return collection ? [collection] : [];
      })
      .slice(0, 8);
    return {
      id,
      title,
      description: text(value.description),
      image: normalizeArtworkUrl(image),
      externalUrl: normalizeUrl(link, apiBaseUrl),
      collections,
    };
  } catch {
    return undefined;
  }
}

function timestampMilliseconds(value: unknown, fallback: number) {
  const parsed = Math.max(0, finiteNumber(value));
  if (parsed <= 0) return fallback;
  return parsed < 1_000_000_000_000 ? parsed * 1000 : parsed;
}

function lyricText(value: unknown) {
  return text(value)
    .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, '')
    .replace(/\s+([,.;:!?])/g, '$1')
    .replace(/[ \t]+/g, ' ')
    .trim()
    .slice(0, MAX_LYRIC_LINE_CHARACTERS);
}

function lyricTime(value: unknown) {
  const parsed = Math.floor(finiteNumber(value, -1));
  return parsed >= 0 && parsed <= MAX_LYRIC_TIME_MS ? parsed : -1;
}

function syncedLyricLine(value: unknown): LyricLineDto | undefined {
  const sentence = asObject(value);
  if (!sentence) return undefined;
  const rawWords = Array.isArray(sentence.words) ? sentence.words : [];
  const words = rawWords.slice(0, MAX_LYRIC_WORDS_PER_LINE).flatMap((raw) => {
    const word = asObject(raw);
    if (!word) return [];
    const data = lyricText(word.data ?? word.text).slice(
      0,
      MAX_LYRIC_WORD_CHARACTERS,
    );
    return data ? [{
      data,
      startTime: lyricTime(word.startTime),
      endTime: lyricTime(word.endTime),
    }] : [];
  });
  const lineText = lyricText(
    words.length > 0
      ? words.map((word) => word.data).join(' ')
      : sentence.data ?? sentence.text ?? sentence.lyric,
  );
  if (!lineText) return undefined;
  const allWordTimingsValid = words.length > 0 && words.every(
    (word, index) => word.startTime >= 0
      && word.endTime > word.startTime
      && (index === 0 || word.startTime >= words[index - 1]!.startTime),
  );
  const timedWords = allWordTimingsValid ? words : [];
  const startTimeMs = timedWords.length > 0
    ? Math.min(...timedWords.map((word) => word.startTime))
    : lyricTime(sentence.startTime);
  const endTimeMs = timedWords.length > 0
    ? Math.max(...timedWords.map((word) => word.endTime))
    : lyricTime(sentence.endTime);
  if (startTimeMs < 0 || endTimeMs <= startTimeMs) return undefined;
  return {
    startTimeMs,
    endTimeMs,
    text: lineText,
    words: timedWords.map((word) => ({
      startTimeMs: word.startTime,
      endTimeMs: word.endTime,
      text: word.data,
    })),
  };
}

function lrcTimestampMilliseconds(value: string) {
  const match = /^(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?$/.exec(value);
  if (!match) return -1;
  const minutes = Number(match[1]);
  const seconds = Number(match[2]);
  if (seconds > 59) return -1;
  const fraction = match[3] ?? '';
  const milliseconds = fraction
    ? Number(fraction.padEnd(3, '0').slice(0, 3))
    : 0;
  const result = minutes * 60_000 + seconds * 1000 + milliseconds;
  return result <= MAX_LYRIC_TIME_MS ? result : -1;
}

function lrcLyricLines(source: string): LyricLineDto[] {
  const offsetMatch = /^\s*\[offset:([+-]?\d+)\]\s*$/im.exec(source);
  const offset = Math.max(
    -60_000,
    Math.min(60_000, Math.trunc(finiteNumber(offsetMatch?.[1]))),
  );
  const parsed: Array<{ startTimeMs: number; text: string }> = [];
  for (const rawLine of source.replace(/\r\n?/g, '\n').split('\n')) {
    const content = rawLine.replace(/^(?:\[\d{1,3}:\d{2}(?:[.:]\d{1,3})?\])+/, '');
    const line = lyricText(content);
    if (!line) continue;
    const timePattern = /\[(\d{1,3}:\d{2}(?:[.:]\d{1,3})?)\]/g;
    for (const match of rawLine.matchAll(timePattern)) {
      const timestamp = lrcTimestampMilliseconds(match[1] ?? '');
      if (timestamp < 0) continue;
      parsed.push({
        startTimeMs: Math.max(0, Math.min(MAX_LYRIC_TIME_MS, timestamp + offset)),
        text: line,
      });
      if (parsed.length >= MAX_LYRIC_LINES) break;
    }
    if (parsed.length >= MAX_LYRIC_LINES) break;
  }
  parsed.sort((left, right) => left.startTimeMs - right.startTimeMs);
  const unique = parsed.filter(
    (line, index) => index === 0
      || line.startTimeMs !== parsed[index - 1]!.startTimeMs
      || line.text !== parsed[index - 1]!.text,
  );
  return unique.map((line, index) => {
    const nextStart = unique[index + 1]?.startTimeMs;
    const endTimeMs = nextStart === undefined
      ? Math.min(MAX_LYRIC_TIME_MS, line.startTimeMs + 8_000)
      : Math.max(line.startTimeMs + 1, nextStart - 1);
    return { ...line, endTimeMs };
  });
}

function releaseRegion(value: unknown): ReleaseRegion {
  const ids = new Set(
    (Array.isArray(value) ? value : []).map((item) => text(item)),
  );
  if (ids.has('IWZ9Z08I')) return 'vietnam';
  if (ids.has('IWZ9Z08O')) return 'usuk';
  if (ids.has('IWZ9Z08W')) return 'korea';
  return 'other';
}

function isoDurationSeconds(value: string) {
  const match = /^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$/i.exec(value);
  if (!match) return 0;
  return Number(match[1] ?? 0) * 3600
    + Number(match[2] ?? 0) * 60
    + Number(match[3] ?? 0);
}

function songIdFromPublicUrl(value: string) {
  try {
    const parsed = new URL(value);
    const fileName = parsed.pathname.split('/').filter(Boolean).at(-1) ?? '';
    return fileName.endsWith('.html') ? fileName.slice(0, -5) : '';
  } catch {
    return '';
  }
}

function jsonLdObjects(html: string) {
  const objects: JsonObject[] = [];
  const pattern = /<script\b[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  for (const match of html.matchAll(pattern)) {
    try {
      const body = match[1]?.trim();
      if (!body) continue;
      const parsed = JSON.parse(body) as unknown;
      const candidates = Array.isArray(parsed) ? parsed : [parsed];
      for (const candidate of candidates) {
        const object = asObject(candidate);
        if (object) objects.push(object);
      }
    } catch {
      // Ignore unrelated malformed JSON-LD blocks and require MusicPlaylist below.
    }
  }
  return objects;
}

function isAbortError(error: unknown) {
  return error instanceof Error && error.name === 'AbortError';
}

async function readJson(response: Response): Promise<JsonObject> {
  if (!response.ok) throw new UpstreamError('Upstream request failed', response.status);
  let body: unknown;
  try {
    body = await response.json();
  } catch {
    throw new UpstreamError('Upstream returned invalid JSON', response.status);
  }
  const object = asObject(body);
  if (!object) throw new UpstreamError('Upstream returned an invalid payload');
  if (object.err !== undefined && Number(object.err) !== 0) {
    throw new UpstreamError('Upstream rejected the request');
  }
  return object;
}

export class ZingUpstream implements MusicUpstream {
  constructor(
    private readonly config: Pick<
      AppConfig,
      | 'chartUrl'
      | 'searchUrl'
      | 'suggestionUrl'
      | 'sourceUrl'
      | 'currentApiBaseUrl'
      | 'currentApiKey'
      | 'currentApiSigningKey'
      | 'currentApiVersion'
    > & Partial<Pick<AppConfig, 'streamHosts'>>,
    private readonly fetcher: typeof fetch = fetch,
    private readonly now: () => number = Date.now,
  ) {}

  private readonly liveRadioSources = new Map<
    string,
    { url: string; expiresAt: number }
  >();

  private get hasCurrentApiCredentials() {
    return Boolean(this.config.currentApiKey && this.config.currentApiSigningKey);
  }

  async fetchChart(signal?: AbortSignal): Promise<ChartSnapshotDto> {
    const response = await this.request(this.config.chartUrl, signal);
    const payload = await readJson(response);
    const data = asObject(payload.data);
    if (!data || !Array.isArray(data.song)) {
      throw new UpstreamError('Upstream chart payload is missing songs');
    }

    const songs = data.song.flatMap((raw, index): SongDto[] => {
      const item = asObject(raw);
      if (!item) return [];
      const id = text(item.id);
      const code = text(item.code);
      const title = text(item.title) || text(item.name);
      if (!id || !code || !title) return [];
      const album = asObject(item.album);
      const artists = Array.isArray(item.artists)
        ? item.artists.flatMap((rawArtist): SearchArtistDto[] => {
          const artist = asObject(rawArtist);
          if (!artist) return [];
          const profile = artistProfile(artist, this.config.currentApiBaseUrl);
          return profile &&
              /^[A-Za-z0-9_-]{1,128}$/.test(profile.id) &&
              /^[A-Za-z0-9_-]{1,200}$/.test(profile.aliasName)
            ? [profile]
            : [];
        }).slice(0, 10)
        : [];
      const albumId = text(album?.id) || text(album?.encodeId);
      const albumTitle = text(album?.title).slice(0, 300);
      const albumLink = text(album?.link);
      const normalizedAlbum: SearchCollectionDto | undefined =
        /^[A-Za-z0-9_-]{1,128}$/.test(albumId) && albumTitle
          ? {
            id: albumId,
            title: albumTitle,
            artist: text(item.artists_names).slice(0, 300),
            thumbnail: optionalArtworkUrl(
              album?.thumbnailM || album?.thumbnail || item.thumbnail,
            ),
            kind: 'album',
            externalUrl: trustedCollectionUrl(
              albumLink,
              this.config.currentApiBaseUrl,
            )
              ? normalizeUrl(albumLink, this.config.currentApiBaseUrl)
              : normalizeUrl(
                `/link/album/${encodeURIComponent(albumId)}`,
                this.config.currentApiBaseUrl,
              ),
          }
          : undefined;
      const rankDelta = Math.min(
        100,
        Math.max(0, Math.trunc(finiteNumber(item.rank_num))),
      );
      const rankStatus = text(item.rank_status).toLowerCase();
      return [{
        id,
        code,
        title,
        artist: text(item.artists_names),
        artists,
        albumCover: text(item.thumbnail)
          ? normalizeUrl(text(item.thumbnail), this.config.chartUrl)
          : '',
        albumTitle,
        ...(normalizedAlbum ? { album: normalizedAlbum } : {}),
        durationSeconds: Math.min(
          86_400,
          Math.max(0, Math.trunc(finiteNumber(item.duration))),
        ),
        rank: index + 1,
        rankChange: rankStatus === 'up'
          ? rankDelta
          : rankStatus === 'down'
            ? -rankDelta
            : 0,
      }];
    });

    const songHistory = asObject(data.songHis);
    const historyData = asObject(songHistory?.data);
    const series = Object.fromEntries(
      songs.slice(0, 3).flatMap((song) => {
        const rawPoints = historyData?.[song.id];
        if (!Array.isArray(rawPoints)) return [];
        const points = rawPoints.flatMap((raw): ChartPointDto[] => {
          const point = asObject(raw);
          if (!point) return [];
          const time = finiteNumber(point.time, -1);
          const counter = finiteNumber(point.counter, -1);
          const hour = text(point.hour);
          if (time < 0 || counter < 0 || !/^\d{1,2}$/.test(hour)) return [];
          return [{ time, hour: hour.padStart(2, '0'), counter }];
        }).slice(-24);
        return points.length > 1 ? [[song.id, points] as const] : [];
      }),
    );
    const latestPoint = Object.values(series)
      .flat()
      .reduce((latest, point) => Math.max(latest, point.time), 0);

    return {
      songs,
      series,
      minScore: Math.max(0, finiteNumber(songHistory?.min_score)),
      maxScore: Math.max(0, finiteNumber(songHistory?.max_score)),
      updatedAt: latestPoint || Date.now(),
    };
  }

  async fetchNewReleases(signal?: AbortSignal): Promise<NewReleaseSnapshotDto> {
    if (!this.hasCurrentApiCredentials) {
      throw new UpstreamError('Current catalog adapter is not configured');
    }
    const endpoint = this.signedCurrentApiUrl(
      '/api/v2/page/get/newrelease-chart',
      {},
    );
    const response = await this.request(endpoint, signal);
    const payload = await readJson(response);
    const data = asObject(payload.data);
    const rawItems = Array.isArray(data?.items) ? data.items : [];
    const songs = rawItems.flatMap((raw, index) => {
      const item = asObject(raw);
      if (!item) return [];
      const id = text(item.encodeId);
      const title = text(item.title);
      if (!id || !title) return [];
      const rawAlbum = asObject(item.album);
      const artists = structuredSongArtists(
        item.artists,
        this.config.currentApiBaseUrl,
      );
      const album = structuredSongAlbum(
        item.album,
        this.config.currentApiBaseUrl,
      );
      const link = text(item.link);
      return [{
        id,
        code: id,
        title,
        artist: text(item.artistsNames),
        ...(artists.length ? { artists } : {}),
        albumCover: normalizeArtworkUrl(
          text(item.thumbnailM) || text(item.thumbnail),
        ),
        albumTitle: text(rawAlbum?.title),
        ...(album ? { album } : {}),
        durationSeconds: Math.max(0, Math.floor(finiteNumber(item.duration))),
        externalUrl: link
          ? normalizeUrl(link, this.config.currentApiBaseUrl)
          : `${this.config.currentApiBaseUrl}/link/song/${encodeURIComponent(id)}`,
        rank: index + 1,
        rankChange: Math.trunc(finiteNumber(item.rakingStatus)),
        releasedAt: Math.max(0, Math.floor(finiteNumber(item.releasedAt))),
        playable: String(item.streamingStatus ?? '').trim() === '1',
      }];
    }).slice(0, 100);
    if (songs.length === 0) {
      throw new UpstreamError('New release chart has no songs');
    }
    const rawTimestamp = Math.max(0, finiteNumber(payload.timestamp));
    return {
      title: text(data?.title) || 'BXH Nhạc Mới',
      updatedAt: rawTimestamp > 0
        ? (rawTimestamp < 1_000_000_000_000 ? rawTimestamp * 1000 : rawTimestamp)
        : this.now(),
      songs,
      catalogPlaybackEnabled: true,
    };
  }

  async fetchWeeklyChart(
    region: WeeklyChartRegion,
    week?: number,
    year?: number,
    signal?: AbortSignal,
  ): Promise<WeeklyChartDto> {
    if (!this.hasCurrentApiCredentials) {
      throw new UpstreamError('Current catalog adapter is not configured');
    }
    const endpoint = this.signedCurrentApiUrl('/api/v2/page/get/week-chart', {
      id: WEEKLY_CHART_IDS[region],
      week: String(week ?? 0),
      year: String(year ?? 0),
    });
    const response = await this.request(endpoint, signal);
    const payload = await readJson(response);
    const data = asObject(payload.data);
    const rawItems = Array.isArray(data?.items) ? data.items : [];
    if (!data) throw new UpstreamError('Weekly chart payload is missing');
    const songs = rawItems.flatMap((raw, index) => {
      const item = asObject(raw);
      if (!item || item.isPrivate === true || item.preRelease === true) {
        return [];
      }
      const id = text(item.encodeId);
      const title = text(item.title);
      if (!id || !title) return [];
      const link = text(item.link);
      const rawAlbum = asObject(item.album);
      const artists = structuredSongArtists(
        item.artists,
        this.config.currentApiBaseUrl,
      );
      const album = structuredSongAlbum(
        item.album,
        this.config.currentApiBaseUrl,
      );
      try {
        const weeklyRanking = Math.floor(finiteNumber(item.weeklyRanking));
        return [{
          id,
          code: id,
          title,
          artist: text(item.artistsNames),
          ...(artists.length ? { artists } : {}),
          albumCover: optionalArtworkUrl(item.thumbnailM || item.thumbnail),
          ...(album ? { album } : {}),
          durationSeconds: Math.max(0, Math.floor(finiteNumber(item.duration))),
          externalUrl: /^\/bai-hat\//.test(link)
            ? normalizeUrl(link, this.config.currentApiBaseUrl)
            : `${this.config.currentApiBaseUrl}/link/song/${encodeURIComponent(id)}`,
          playable: String(item.streamingStatus ?? '').trim() === '1',
          albumTitle: text(rawAlbum?.title),
          rank: weeklyRanking > 0 ? weeklyRanking : index + 1,
          rankChange: Math.trunc(finiteNumber(item.rakingStatus)),
          score: Math.max(0, Math.floor(finiteNumber(item.score))),
        }];
      } catch {
        return [];
      }
    }).slice(0, 100);
    const responseWeek = Math.floor(finiteNumber(data.week));
    const responseYear = Math.floor(finiteNumber(data.year));
    if (
      songs.length === 0 ||
      responseWeek < 1 ||
      responseWeek > 53 ||
      responseYear < 2000
    ) {
      throw new UpstreamError('Weekly chart has no usable songs');
    }
    return {
      region,
      title: 'Bảng Xếp Hạng Tuần',
      week: responseWeek,
      year: responseYear,
      latestWeek: Math.max(
        responseWeek,
        Math.floor(finiteNumber(data.latestWeek)),
      ),
      startDate: text(data.startDate),
      endDate: text(data.endDate),
      updatedAt: timestampMilliseconds(payload.timestamp, this.now()),
      songs,
      catalogPlaybackEnabled: true,
    };
  }

  async fetchReleaseCatalog(
    signal?: AbortSignal,
  ): Promise<ReleaseCatalogDto> {
    if (!this.hasCurrentApiCredentials) {
      throw new UpstreamError('Current catalog adapter is not configured');
    }
    const songEndpoint = this.signedCurrentApiUrl(
      '/api/v2/chart/get/new-release',
      { type: 'song' },
    );
    const albumEndpoint = this.signedCurrentApiUrl(
      '/api/v2/chart/get/new-release',
      { type: 'album' },
    );
    const [songResponse, albumResponse] = await Promise.all([
      this.request(songEndpoint, signal),
      this.request(albumEndpoint, signal),
    ]);
    const [songPayload, albumPayload] = await Promise.all([
      readJson(songResponse),
      readJson(albumResponse),
    ]);
    const rawSongs = Array.isArray(songPayload.data) ? songPayload.data : [];
    const rawAlbums = Array.isArray(albumPayload.data) ? albumPayload.data : [];
    const songs = rawSongs.flatMap((raw): ReleaseSongDto[] => {
      const item = asObject(raw);
      if (!item || item.isPrivate === true || item.preRelease === true) {
        return [];
      }
      const id = text(item.encodeId);
      const title = text(item.title);
      if (!id || !title) return [];
      try {
        const link = text(item.link);
        const artists = structuredSongArtists(
          item.artists,
          this.config.currentApiBaseUrl,
        );
        const album = structuredSongAlbum(
          item.album,
          this.config.currentApiBaseUrl,
        );
        return [{
          id,
          code: id,
          title,
          artist: text(item.artistsNames),
          ...(artists.length ? { artists } : {}),
          albumCover: normalizeArtworkUrl(
            text(item.thumbnailM) || text(item.thumbnail),
          ),
          ...(album ? { album } : {}),
          durationSeconds: Math.max(
            0,
            Math.floor(finiteNumber(item.duration)),
          ),
          externalUrl: /^\/bai-hat\//.test(link)
            ? normalizeUrl(link, this.config.currentApiBaseUrl)
            : `${this.config.currentApiBaseUrl}/link/song/${encodeURIComponent(id)}`,
          playable: String(item.streamingStatus ?? '').trim() === '1',
          releasedAt: Math.max(
            0,
            Math.floor(finiteNumber(item.releaseDate)),
          ),
          region: releaseRegion(item.genreIds),
        }];
      } catch {
        return [];
      }
    }).slice(0, 100);
    const albums = rawAlbums.flatMap((raw): ReleaseAlbumDto[] => {
      const item = asObject(raw);
      if (!item || item.isPrivate === true || item.preRelease === true) {
        return [];
      }
      const collection = discoveryCollection(
        { ...item, isAlbum: true },
        this.config.currentApiBaseUrl,
      );
      if (!collection) return [];
      return [{
        ...collection,
        releasedAt: Math.max(
          0,
          Math.floor(finiteNumber(item.releaseDate)),
        ),
        region: releaseRegion(item.genreIds),
      }];
    }).slice(0, 100);
    if (songs.length === 0 || albums.length === 0) {
      throw new UpstreamError('New release catalog has no usable items');
    }
    return {
      updatedAt: timestampMilliseconds(
        Math.max(
          finiteNumber(songPayload.timestamp),
          finiteNumber(albumPayload.timestamp),
        ),
        this.now(),
      ),
      songs,
      albums,
      catalogPlaybackEnabled: true,
    };
  }

  async fetchDiscoveryCategories(
    signal?: AbortSignal,
  ): Promise<DiscoveryCategoriesDto> {
    if (!this.hasCurrentApiCredentials) {
      throw new UpstreamError('Current catalog adapter is not configured');
    }
    const endpoint = this.signedCurrentApiUrl(
      '/api/v2/page/get/home-category',
      {},
    );
    const response = await this.request(endpoint, signal);
    const payload = await readJson(response);
    const data = asObject(payload.data);
    const rawItems = Array.isArray(data?.items) ? data.items : [];
    const byId = new Map<string, string>();
    for (const raw of rawItems) {
      const item = asObject(raw);
      const numericId = Math.trunc(finiteNumber(item?.id, -1));
      const name = text(item?.name)
        .replace(/\s+/g, ' ')
        .slice(0, 40);
      if (numericId <= 0 || numericId > 999 || !name) continue;
      const id = String(numericId);
      if (!byId.has(id)) byId.set(id, name);
      if (byId.size === 12) break;
    }
    if (byId.size === 0) {
      throw new UpstreamError('Discovery categories have no usable items');
    }
    return {
      updatedAt: timestampMilliseconds(payload.timestamp, this.now()),
      items: [...byId].map(([id, name]) => ({ id, name })),
    };
  }

  async fetchDiscoveryRecommendations(
    signal?: AbortSignal,
  ): Promise<DiscoveryRecommendationsDto> {
    if (!this.hasCurrentApiCredentials) {
      throw new UpstreamError('Current catalog adapter is not configured');
    }
    const endpoint = this.signedCurrentApiUrl(
      '/api/v2/song/get/section-song-station',
      { count: '12' },
    );
    const response = await this.request(endpoint, signal);
    const payload = await readJson(response);
    const data = asObject(payload.data);
    const rawItems = Array.isArray(data?.items) ? data.items : [];
    const seen = new Set<string>();
    const songs = rawItems.flatMap((raw): SearchSongDto[] => {
      const item = asObject(raw);
      if (
        !item
        || item.isPrivate === true
        || item.preRelease === true
        || String(item.streamingStatus ?? '').trim() !== '1'
      ) {
        return [];
      }
      const id = text(item.encodeId);
      const title = text(item.title);
      if (!id || !title || seen.has(id)) return [];
      seen.add(id);
      const link = text(item.link);
      const artists = structuredSongArtists(
        item.artists,
        this.config.currentApiBaseUrl,
      );
      const album = structuredSongAlbum(
        item.album,
        this.config.currentApiBaseUrl,
      );
      return [{
        id,
        code: id,
        title,
        artist: text(item.artistsNames),
        ...(artists.length ? { artists } : {}),
        albumCover: optionalArtworkUrl(item.thumbnailM || item.thumbnail),
        ...(album ? { album } : {}),
        durationSeconds: Math.min(
          24 * 60 * 60,
          Math.max(0, Math.floor(finiteNumber(item.duration))),
        ),
        externalUrl: /^\/bai-hat\//.test(link)
          ? normalizeUrl(link, this.config.currentApiBaseUrl)
          : `${this.config.currentApiBaseUrl}/link/song/${encodeURIComponent(id)}`,
        playable: true,
      }];
    }).slice(0, 12);
    if (songs.length === 0) {
      throw new UpstreamError('Discovery recommendations have no playable songs');
    }
    return {
      updatedAt: timestampMilliseconds(payload.timestamp, this.now()),
      songs,
      catalogPlaybackEnabled: true,
    };
  }

  async fetchDiscovery(
    categoryId = '-1',
    signal?: AbortSignal,
  ): Promise<DiscoveryHomeDto> {
    if (!this.hasCurrentApiCredentials) {
      throw new UpstreamError('Current catalog adapter is not configured');
    }
    if (!/^(?:-1|[1-9]\d{0,2})$/.test(categoryId)) {
      throw new UpstreamError('Discovery category is invalid');
    }
    const endpoint = this.signedCurrentApiUrl('/api/v2/page/get/home', {
      page: '1',
      count: '30',
      categoryId,
    });
    const response = await this.request(endpoint, signal);
    const payload = await readJson(response);
    const data = asObject(payload.data);
    const rawSections = Array.isArray(data?.items) ? data.items : [];

    const seenQuickPlay = new Set<string>();
    const quickPlay = rawSections
      .filter((raw) => asObject(raw)?.sectionType === 'quickPlay')
      .flatMap((raw) => {
        const section = asObject(raw);
        const items = Array.isArray(section?.items) ? section.items : [];
        return items.flatMap((item): DiscoveryCollectionDto[] => {
          const value = asObject(item);
          const id = text(value?.id) || text(value?.encodeId);
          if (
            !value
            || !/^[A-Za-z0-9_-]{1,128}$/.test(id)
            || seenQuickPlay.has(id)
          ) {
            return [];
          }
          const collection = discoveryCollection(
            {
              ...value,
              encodeId: id,
              isAlbum: finiteNumber(value.type) === 3,
            },
            this.config.currentApiBaseUrl,
          );
          if (!collection) return [];
          seenQuickPlay.add(id);
          return [{
            ...collection,
            description: text(value.description)
              .replace(/\s+/g, ' ')
              .slice(0, 240),
          }];
        });
      })
      .slice(0, 10);

    const banners = rawSections
      .filter((raw) => asObject(raw)?.sectionType === 'banner')
      .flatMap((raw) => {
        const section = asObject(raw);
        const items = Array.isArray(section?.items) ? section.items : [];
        return items.flatMap((item, index) => {
          const value = asObject(item);
          if (!value) return [];
          const image = normalizeArtworkUrl(
            text(value.banner) || text(value.cover),
          );
          if (!image) return [];
          const id = text(value.encodeId) || `banner-${index + 1}`;
          const collection = discoveryCollection(
            finiteNumber(value.type) === 3
              ? { ...value, isAlbum: true }
              : value,
            this.config.currentApiBaseUrl,
            true,
          );
          return [{
            id,
            image,
            ...(collection ? { collection } : {}),
          } satisfies DiscoveryBannerDto];
        });
      })
      .slice(0, 6);

    const videoById = new Map<string, SearchVideoDto>();
    for (const raw of rawSections) {
      const section = asObject(raw);
      if (text(section?.sectionType) !== 'video') continue;
      const items = Array.isArray(section?.items) ? section.items : [];
      for (const rawItem of items) {
        const item = asObject(rawItem);
        if (!item) continue;
        const video = discoveryVideo(item, this.config.currentApiBaseUrl);
        if (!video || videoById.has(video.id)) continue;
        videoById.set(video.id, video);
        if (videoById.size === 12) break;
      }
      if (videoById.size === 12) break;
    }
    const videos = [...videoById.values()];

    const sections = rawSections.flatMap((raw, sectionIndex) => {
      const section = asObject(raw);
      if (text(section?.sectionType) !== 'playlist') return [];
      const title = text(section?.title);
      const items = Array.isArray(section?.items) ? section.items : [];
      if (!title || items.length === 0) return [];
      const collections = items
        .flatMap((item) => {
          const value = asObject(item);
          if (!value) return [];
          const collection = discoveryCollection(
            value,
            this.config.currentApiBaseUrl,
          );
          if (!collection) return [];
          return [{
            ...collection,
            description: text(value.sortDescription),
          } satisfies DiscoveryCollectionDto];
        })
        .slice(0, 12);
      if (collections.length === 0) return [];
      return [{
        id: `playlist-${sectionIndex + 1}`,
        title,
        collections,
      } satisfies DiscoverySectionDto];
    });
    if (
      quickPlay.length === 0
      && banners.length === 0
      && videos.length === 0
      && sections.length === 0
    ) {
      throw new UpstreamError('Discovery home has no usable content');
    }
    const rawTimestamp = Math.max(0, finiteNumber(payload.timestamp));
    return {
      categoryId,
      updatedAt: timestampMilliseconds(rawTimestamp, this.now()),
      quickPlay,
      banners,
      videos,
      sections,
    };
  }

  async fetchHubHome(signal?: AbortSignal): Promise<HubHomeDto> {
    if (!this.hasCurrentApiCredentials) {
      throw new UpstreamError('Current catalog adapter is not configured');
    }
    const endpoint = this.signedCurrentApiUrl('/api/v2/page/get/hub-home', {});
    const response = await this.request(endpoint, signal);
    const payload = await readJson(response);
    const data = asObject(payload.data);
    if (!data) throw new UpstreamError('Hub home payload is missing');

    const mapHubs = (value: unknown, limit: number) =>
      (Array.isArray(value) ? value : [])
        .flatMap((raw) => {
          const object = asObject(raw);
          if (!object) return [];
          const hub = catalogHub(object, this.config.currentApiBaseUrl);
          return hub ? [hub] : [];
        })
        .slice(0, limit);
    const featuredGroup = asObject(data.featured);
    const featured = mapHubs(featuredGroup?.items, 8);
    const nations = mapHubs(data.nations, 8);
    const topics = mapHubs(data.topic, 24);
    const genres = mapHubs(data.genre, 24);
    if (featured.length === 0 || genres.length === 0) {
      throw new UpstreamError('Hub home has no usable catalog groups');
    }
    return {
      updatedAt: timestampMilliseconds(payload.timestamp, this.now()),
      featured,
      nations,
      topics,
      genres,
    };
  }

  async fetchHubDetail(
    id: string,
    signal?: AbortSignal,
  ): Promise<HubDetailDto> {
    if (!this.hasCurrentApiCredentials) {
      throw new UpstreamError('Current catalog adapter is not configured');
    }
    const endpoint = this.signedCurrentApiUrl('/api/v2/page/get/hub-detail', {
      id,
    });
    const response = await this.request(endpoint, signal);
    const payload = await readJson(response);
    const data = asObject(payload.data);
    if (!data) throw new UpstreamError('Hub detail payload is missing');
    const hub = catalogHub(data, this.config.currentApiBaseUrl);
    if (!hub || hub.id !== id) {
      throw new UpstreamError('Hub detail metadata is invalid');
    }
    const rawSections = Array.isArray(data.sections) ? data.sections : [];
    const sections = rawSections.flatMap((raw, index) => {
      const section = asObject(raw);
      if (!section || text(section.sectionType) !== 'playlist') return [];
      const normalized = discoverySection(
        section,
        index,
        this.config.currentApiBaseUrl,
      );
      return normalized ? [normalized] : [];
    });
    if (sections.length === 0) {
      throw new UpstreamError('Hub detail has no collection sections');
    }
    return { ...hub, sections };
  }

  async fetchTop100(signal?: AbortSignal): Promise<Top100SnapshotDto> {
    if (!this.hasCurrentApiCredentials) {
      throw new UpstreamError('Current catalog adapter is not configured');
    }
    const endpoint = this.signedCurrentApiUrl('/api/v2/page/get/top-100', {});
    const response = await this.request(endpoint, signal);
    const payload = await readJson(response);
    const rawSections = Array.isArray(payload.data) ? payload.data : [];
    const sections = rawSections.flatMap((raw, index) => {
      const section = asObject(raw);
      if (!section || text(section.sectionType) !== 'playlist') return [];
      const genre = asObject(section.genre);
      const normalized = discoverySection(
        section,
        index,
        this.config.currentApiBaseUrl,
        text(genre?.name),
      );
      return normalized ? [normalized] : [];
    });
    if (sections.length === 0) {
      throw new UpstreamError('Top 100 has no collection sections');
    }
    return {
      updatedAt: timestampMilliseconds(payload.timestamp, this.now()),
      sections,
    };
  }

  async fetchSearch(query: string, signal?: AbortSignal): Promise<SearchSnapshotDto> {
    const normalizedQuery = query.trim();
    if (this.hasCurrentApiCredentials) {
      return this.fetchCurrentSearch(normalizedQuery, signal);
    }
    const endpoint = new URL(this.config.searchUrl);
    endpoint.searchParams.set('query', normalizedQuery);
    const response = await this.request(endpoint, signal);
    const payload = await readJson(response);
    const groups = Array.isArray(payload.data) ? payload.data : [];
    const songById = new Map<string, SearchSongDto>();
    const artistById = new Map<string, SearchArtistDto>();
    const collectionById = new Map<string, SearchCollectionDto>();

    for (const rawGroup of groups) {
      const group = asObject(rawGroup);
      if (!group) continue;
      const rawSongs = Array.isArray(group.song) ? group.song : [];
      for (const rawSong of rawSongs) {
        const item = asObject(rawSong);
        if (!item || text(item.block).toLowerCase() === 'true') continue;
        const id = text(item.id);
        const title = text(item.name) || text(item.title);
        if (!id || !title || songById.has(id)) continue;
        songById.set(id, {
          id,
          code: id,
          title,
          artist: text(item.artist),
          albumCover: normalizeArtworkUrl(text(item.thumb)),
          durationSeconds: Math.max(0, Math.floor(finiteNumber(item.duration))),
          externalUrl: `${this.config.currentApiBaseUrl}/link/song/${encodeURIComponent(id)}`,
          playable: false,
          hasLyrics: false,
        });
      }

      const rawArtists = Array.isArray(group.artist) ? group.artist : [];
      for (const rawArtist of rawArtists) {
        const item = asObject(rawArtist);
        if (!item || text(item.block).toLowerCase() === 'true') continue;
        const id = text(item.id);
        const name = text(item.name);
        const aliasName = text(item.aliasName);
        if (!id || !name || !aliasName || artistById.has(id)) continue;
        const totalFollow = Math.min(
          2_147_483_647,
          Math.max(0, Math.floor(finiteNumber(item.totalFollow))),
        );
        artistById.set(id, {
          id,
          name,
          aliasName,
          avatar: normalizeArtworkUrl(text(item.thumb)),
          externalUrl: normalizeUrl(
            `/nghe-si/${encodeURIComponent(aliasName)}`,
            this.config.currentApiBaseUrl,
          ),
          ...(totalFollow > 0 ? { totalFollow } : {}),
        });
      }

      const rawCollections = Array.isArray(group.album) ? group.album : [];
      for (const rawCollection of rawCollections) {
        const item = asObject(rawCollection);
        if (!item || text(item.block).toLowerCase() === 'true') continue;
        const id = text(item.id);
        const title = text(item.name) || text(item.title);
        if (!id || !title || collectionById.has(id)) continue;
        collectionById.set(id, {
          id,
          title,
          artist: text(item.artist),
          thumbnail: normalizeArtworkUrl(text(item.thumb)),
          kind: collectionKind(item),
          externalUrl: `${this.config.currentApiBaseUrl}/link/album/${encodeURIComponent(id)}`,
        });
      }
    }

    return {
      query: normalizedQuery,
      songs: [...songById.values()].slice(0, 25),
      artists: [...artistById.values()].slice(0, 10),
      collections: [...collectionById.values()].slice(0, 25),
      videos: [],
      catalogPlaybackEnabled: false,
    };
  }

  private async fetchCurrentSearch(
    query: string,
    signal?: AbortSignal,
  ): Promise<SearchSnapshotDto> {
    const endpoint = this.signedCurrentApiUrl('/api/v2/search/multi', {
      q: query,
      allowCorrect: '1',
    });
    const response = await this.request(endpoint, signal);
    const payload = await readJson(response);
    const data = asObject(payload.data);
    if (!data) throw new UpstreamError('Current search payload is missing');

    const songById = new Map<string, SearchSongDto>();
    const rawSongs = Array.isArray(data.songs) ? data.songs : [];
    for (const raw of rawSongs) {
      const item = asObject(raw);
      if (
        !item ||
        item.isPrivate === true ||
        item.preRelease === true ||
        text(item.block).toLowerCase() === 'true'
      ) {
        continue;
      }
      const id = text(item.encodeId) || text(item.id);
      const title = text(item.title) || text(item.name);
      if (!id || !title || songById.has(id)) continue;
      const link = text(item.link);
      const artists = structuredSongArtists(
        item.artists,
        this.config.currentApiBaseUrl,
      );
      const album = structuredSongAlbum(
        item.album,
        this.config.currentApiBaseUrl,
      );
      songById.set(id, {
        id,
        code: id,
        title: title.slice(0, 300),
        artist: text(item.artistsNames || item.artist).slice(0, 300),
        ...(artists.length ? { artists } : {}),
        albumCover: optionalArtworkUrl(item.thumbnailM || item.thumbnail),
        ...(album ? { album } : {}),
        durationSeconds: Math.min(
          24 * 60 * 60,
          Math.max(0, Math.floor(finiteNumber(item.duration))),
        ),
        externalUrl: /^\/bai-hat\//.test(link)
          ? normalizeUrl(link, this.config.currentApiBaseUrl)
          : `${this.config.currentApiBaseUrl}/link/song/${encodeURIComponent(id)}`,
        playable: String(item.streamingStatus ?? '').trim() === '1',
        hasLyrics: item.hasLyric === true,
      });
      if (songById.size === 25) break;
    }

    const artistById = new Map<string, SearchArtistDto>();
    const rawArtists = Array.isArray(data.artists) ? data.artists : [];
    for (const raw of rawArtists) {
      const item = asObject(raw);
      if (!item || text(item.block).toLowerCase() === 'true') continue;
      const artist = artistProfile(item, this.config.currentApiBaseUrl);
      if (!artist || artistById.has(artist.id)) continue;
      artistById.set(artist.id, artist);
      if (artistById.size === 10) break;
    }

    const collectionById = new Map<string, SearchCollectionDto>();
    const rawCollections = Array.isArray(data.playlists) ? data.playlists : [];
    for (const raw of rawCollections) {
      const item = asObject(raw);
      if (!item || item.isPrivate === true || item.preRelease === true) continue;
      const collection = discoveryCollection(
        item,
        this.config.currentApiBaseUrl,
      );
      if (!collection || collectionById.has(collection.id)) continue;
      collectionById.set(collection.id, collection);
      if (collectionById.size === 25) break;
    }

    const videoById = new Map<string, SearchVideoDto>();
    const rawVideos = Array.isArray(data.videos) ? data.videos : [];
    for (const raw of rawVideos) {
      const item = asObject(raw);
      if (
        !item ||
        item.isPrivate === true ||
        item.preRelease === true ||
        String(item.streamingStatus ?? '').trim() !== '1'
      ) {
        continue;
      }
      const id = text(item.encodeId) || text(item.id);
      const title = text(item.title) || text(item.name);
      const link = text(item.link);
      if (
        !id ||
        !title ||
        videoById.has(id) ||
        !/^\/video-clip\//.test(link)
      ) {
        continue;
      }
      try {
        const artists = structuredSongArtists(
          item.artists,
          this.config.currentApiBaseUrl,
        );
        videoById.set(id, {
          id,
          title: title.slice(0, 300),
          artist: text(item.artistsNames || item.artist).slice(0, 300),
          ...(artists.length > 0 ? { artists } : {}),
          thumbnail: optionalArtworkUrl(item.thumbnailM || item.thumbnail),
          durationSeconds: Math.min(
            24 * 60 * 60,
            Math.max(0, Math.floor(finiteNumber(item.duration))),
          ),
          externalUrl: normalizeUrl(link, this.config.currentApiBaseUrl),
        });
      } catch {
        continue;
      }
      if (videoById.size === 20) break;
    }

    return {
      query,
      songs: [...songById.values()],
      artists: [...artistById.values()],
      collections: [...collectionById.values()],
      videos: [...videoById.values()],
      catalogPlaybackEnabled: true,
    };
  }

  async fetchSearchSuggestions(
    query: string,
    signal?: AbortSignal,
  ): Promise<SearchSuggestionSnapshotDto> {
    const normalizedQuery = query.trim().replace(/\s+/g, ' ');
    if (!this.hasCurrentApiCredentials) {
      return this.fallbackSearchSuggestions(normalizedQuery, signal);
    }

    try {
      const configured = new URL(this.config.suggestionUrl);
      const endpoint = this.signedCurrentApiUrl(
        configured.pathname,
        { query: normalizedQuery, num: '10', language: 'vi' },
        configured.origin,
      );
      const response = await this.request(endpoint, signal);
      const payload = await readJson(response);
      const data = asObject(payload.data);
      const items = Array.isArray(data?.items) ? data.items : [];
      const keywordByKey = new Map<string, string>();
      const songById = new Map<string, SearchSuggestionSongDto>();

      for (const rawGroup of items) {
        const group = asObject(rawGroup);
        if (!group) continue;
        const rawKeywords = Array.isArray(group.keywords) ? group.keywords : [];
        for (const rawKeyword of rawKeywords) {
          const item = asObject(rawKeyword);
          const keyword = (item ? text(item.keyword) : text(rawKeyword))
            .replace(/\s+/g, ' ')
            .slice(0, 100);
          if (!keyword) continue;
          const key = keyword.toLocaleLowerCase('vi');
          if (!keywordByKey.has(key)) keywordByKey.set(key, keyword);
          if (keywordByKey.size === 4) break;
        }

        const rawSuggestions = Array.isArray(group.suggestions)
          ? group.suggestions
          : [];
        for (const rawSuggestion of rawSuggestions) {
          const item = asObject(rawSuggestion);
          if (!item) continue;
          const id = text(item.id) || text(item.encodeId);
          const title = text(item.title) || text(item.name);
          if (!id || !title || songById.has(id)) continue;
          const rawArtists = Array.isArray(item.artists) ? item.artists : [];
          const artist = rawArtists
            .map(asObject)
            .filter((value): value is JsonObject => value !== undefined)
            .map((value) => text(value.name))
            .filter(Boolean)
            .join(', ') || text(item.artistsNames);
          const link = text(item.link);
          songById.set(id, {
            id,
            title: title.slice(0, 200),
            artist: artist.slice(0, 300),
            thumbnail: optionalArtworkUrl(item.thumb || item.thumbnail),
            durationSeconds: Math.min(
              86_400,
              Math.max(0, Math.floor(finiteNumber(item.duration))),
            ),
            externalUrl: /^\/bai-hat\//.test(link)
              ? normalizeUrl(link, this.config.currentApiBaseUrl)
              : `${this.config.currentApiBaseUrl}/link/song/${encodeURIComponent(id)}`,
          });
          if (songById.size === 6) break;
        }
      }

      return {
        query: normalizedQuery,
        keywords: [...keywordByKey.values()].slice(0, 4),
        songs: [...songById.values()].slice(0, 6),
      };
    } catch (error) {
      if (isAbortError(error)) throw error;
      return this.fallbackSearchSuggestions(normalizedQuery, signal);
    }
  }

  private async fallbackSearchSuggestions(
    query: string,
    signal?: AbortSignal,
  ): Promise<SearchSuggestionSnapshotDto> {
    const search = await this.fetchSearch(query, signal);
    const keywords: string[] = [];
    const seen = new Set<string>();
    for (const finalSong of search.songs) {
      const keyword = finalSong.title.trim().replace(/\s+/g, ' ').slice(0, 100);
      const key = keyword.toLocaleLowerCase('vi');
      if (!keyword || seen.has(key)) continue;
      seen.add(key);
      keywords.push(keyword);
      if (keywords.length === 4) break;
    }
    return {
      query,
      keywords,
      songs: search.songs.slice(0, 6).map((song) => ({
        id: song.id,
        title: song.title,
        artist: song.artist,
        thumbnail: song.albumCover,
        durationSeconds: song.durationSeconds,
        externalUrl: song.externalUrl,
      })),
    };
  }

  async fetchArtistDetail(
    alias: string,
    signal?: AbortSignal,
  ): Promise<ArtistDetailDto> {
    if (!this.hasCurrentApiCredentials) {
      throw new UpstreamError('Current catalog adapter is not configured');
    }
    const endpoint = this.signedCurrentApiUrl('/api/v2/page/get/artist', {
      alias,
    });
    const response = await this.request(endpoint, signal);
    const payload = await readJson(response);
    const data = asObject(payload.data);
    if (!data) throw new UpstreamError('Artist detail payload is missing');
    const artist = artistProfile(data, this.config.currentApiBaseUrl);
    if (
      !artist ||
      artist.aliasName.toLocaleLowerCase('vi') !== alias.toLocaleLowerCase('vi')
    ) {
      throw new UpstreamError('Artist detail metadata is invalid');
    }

    const rawSections = Array.isArray(data.sections) ? data.sections : [];
    const featuredSongs: SearchSongDto[] = [];
    const videos: SearchVideoDto[] = [];
    const videoIds = new Set<string>();
    const collectionSections: ArtistCollectionSectionDto[] = [];
    const relatedArtists: SearchArtistDto[] = [];
    const relatedIds = new Set<string>();
    let songSectionId = '';

    for (const [sectionIndex, rawSection] of rawSections.entries()) {
      const section = asObject(rawSection);
      if (!section) continue;
      const sectionType = text(section.sectionType);
      const title = text(section.title);
      const items = Array.isArray(section.items) ? section.items : [];
      if (sectionType === 'song' && featuredSongs.length === 0) {
        songSectionId = text(section.sectionId);
        for (const song of artistSongs(
          items,
          this.config.currentApiBaseUrl,
          6,
        )) {
          featuredSongs.push(song);
        }
        continue;
      }
      if (sectionType === 'video' && videos.length === 0) {
        for (const rawItem of items) {
          const item = asObject(rawItem);
          if (!item || item.isPrivate === true || item.preRelease === true) {
            continue;
          }
          const streamingStatus = String(item.streamingStatus ?? '').trim();
          if (streamingStatus && streamingStatus !== '1') continue;
          const id = text(item.encodeId) || text(item.id);
          const videoTitle = text(item.title) || text(item.name);
          const link = text(item.link);
          if (
            !/^[A-Za-z0-9_-]{1,128}$/.test(id) ||
            !videoTitle ||
            videoIds.has(id) ||
            !/^\/video-clip\//.test(link)
          ) {
            continue;
          }
          try {
            const artists = structuredSongArtists(
              item.artists,
              this.config.currentApiBaseUrl,
            );
            videos.push({
              id,
              title: videoTitle.slice(0, 300),
              artist: text(item.artistsNames || item.artist).slice(0, 300),
              ...(artists.length > 0 ? { artists } : {}),
              thumbnail: optionalArtworkUrl(
                item.thumbnailM || item.thumbnail,
              ),
              durationSeconds: Math.min(
                24 * 60 * 60,
                Math.max(0, Math.floor(finiteNumber(item.duration))),
              ),
              externalUrl: normalizeUrl(
                link,
                this.config.currentApiBaseUrl,
              ),
            });
            videoIds.add(id);
          } catch {
            // A malformed MV must not invalidate the complete artist page.
          }
          if (videos.length >= 50) break;
        }
        continue;
      }
      if (
        sectionType === 'playlist' &&
        title &&
        collectionSections.length < 6
      ) {
        const collections = items
          .flatMap((rawItem) => {
            const item = asObject(rawItem);
            if (!item || item.isPrivate === true || item.preRelease === true) {
              return [];
            }
            const collection = discoveryCollection(
              item,
              this.config.currentApiBaseUrl,
            );
            return collection ? [collection] : [];
          })
          .slice(0, 50);
        if (collections.length > 0) {
          collectionSections.push({
            id: `${text(section.sectionId) || 'section'}-${sectionIndex + 1}`,
            title,
            collections,
          });
        }
        continue;
      }
      if (sectionType === 'artist') {
        for (const rawItem of items) {
          const item = asObject(rawItem);
          if (!item) continue;
          const related = artistProfile(item, this.config.currentApiBaseUrl);
          if (
            !related ||
            related.id === artist.id ||
            relatedIds.has(related.id)
          ) {
            continue;
          }
          relatedArtists.push(related);
          relatedIds.add(related.id);
          if (relatedArtists.length >= 8) break;
        }
      }
    }
    const songs = [...featuredSongs];
    try {
      const completeSongs = await this.fetchArtistSongList(
        artist.id,
        songSectionId,
        signal,
      );
      if (completeSongs.length > 0) {
        songs.splice(0, songs.length, ...completeSongs);
      }
    } catch (error) {
      if (isAbortError(error)) throw error;
      // The profile's highlighted songs remain a safe fallback when the
      // independent all-songs endpoint is unavailable.
    }
    if (
      songs.length === 0 &&
      videos.length === 0 &&
      collectionSections.length === 0
    ) {
      throw new UpstreamError('Artist detail has no usable catalog');
    }
    const awards = Array.isArray(data.awards)
      ? data.awards.length
      : Math.max(0, Math.floor(finiteNumber(data.awards)));
    return {
      artist,
      cover: optionalArtworkUrl(data.cover),
      biography: plainBiography(text(data.biography) || text(data.sortBiography)),
      realName: text(data.realname),
      national: text(data.national),
      birthday: text(data.birthday),
      totalFollow: Math.max(0, Math.floor(finiteNumber(data.totalFollow))),
      awardCount: awards,
      featuredSongs,
      songs,
      videos,
      collectionSections,
      relatedArtists,
      catalogPlaybackEnabled: true,
    };
  }

  private async fetchArtistSongList(
    artistId: string,
    sectionId: string,
    signal?: AbortSignal,
  ) {
    const params: Record<string, string> = {
      id: artistId,
      type: 'artist',
      page: '1',
      count: '50',
    };
    if (sectionId) params.sectionId = sectionId;
    const endpoint = this.signedCurrentApiUrl('/api/v2/song/get/list', params);
    const response = await this.request(endpoint, signal);
    const payload = await readJson(response);
    const data = asObject(payload.data);
    if (!data || !Array.isArray(data.items)) {
      throw new UpstreamError('Artist song catalog is missing');
    }
    return artistSongs(data.items, this.config.currentApiBaseUrl, 50);
  }

  async fetchCollection(id: string, signal?: AbortSignal): Promise<CollectionDetailDto> {
    const endpoint = new URL(`/link/album/${encodeURIComponent(id)}`, this.config.currentApiBaseUrl);
    const response = await this.fetchCollectionPage(endpoint, signal);
    if (!response.ok) {
      throw new UpstreamError('Upstream collection page failed', response.status);
    }
    const contentLength = finiteNumber(response.headers.get('content-length'));
    if (contentLength > MAX_COLLECTION_PAGE_BYTES) {
      await discardResponseBody(response);
      throw new UpstreamError('Upstream collection page is too large');
    }
    const html = await readTextWithByteLimit(response, MAX_COLLECTION_PAGE_BYTES);
    const playlist = jsonLdObjects(html).find((object) => {
      const type = object['@type'];
      return type === 'MusicPlaylist'
        || type === 'MusicAlbum'
        || (Array.isArray(type)
          && (type.includes('MusicPlaylist') || type.includes('MusicAlbum')));
    });
    if (!playlist) throw new UpstreamError('Collection metadata is missing');

    const title = text(playlist.name);
    const rawTracks = Array.isArray(asObject(playlist.track)?.itemListElement)
      ? asObject(playlist.track)?.itemListElement as unknown[]
      : Array.isArray(playlist.track)
        ? playlist.track
        : [];
    const parsedSongs = rawTracks.flatMap((raw): SearchSongDto[] => {
      const listItem = asObject(raw);
      const item = asObject(listItem?.item) ?? listItem;
      if (!item) return [];
      const publicUrl = text(listItem?.url) || text(item.url);
      const songId = songIdFromPublicUrl(publicUrl);
      const songTitle = text(item.name);
      if (!songId || !songTitle) return [];
      const byArtist = Array.isArray(item.byArtist) ? item.byArtist : [];
      const artists = byArtist
        .map((rawArtist) => text(asObject(rawArtist)?.name))
        .filter(Boolean);
      return [{
        id: songId,
        code: songId,
        title: songTitle,
        artist: artists.join(', '),
        albumCover: text(item.image)
          ? normalizeUrl(text(item.image), this.config.currentApiBaseUrl)
          : '',
        durationSeconds: isoDurationSeconds(text(item.duration)),
        externalUrl: publicUrl.split('#', 1)[0] ?? publicUrl,
        playable: false,
      }];
    });
    const [trackMetadata, officialMetadata] = await Promise.all([
      this.hasCurrentApiCredentials
        ? this.fetchCollectionTrackMetadata(
            parsedSongs.map((song) => song.id),
            signal,
          )
        : Promise.resolve([]),
      this.hasCurrentApiCredentials
        ? this.fetchCollectionOfficialMetadata(id, signal)
        : Promise.resolve({
            likeCount: 0,
            artists: [],
            releasedAt: 0,
            distributor: '',
            sections: [],
          }),
    ]);
    const songs = parsedSongs.map((song, index) => {
      const metadata = trackMetadata[index];
      return {
        ...song,
        playable: metadata?.playable ?? false,
        ...(metadata?.artists.length ? { artists: metadata.artists } : {}),
        ...(metadata?.album ? { album: metadata.album } : {}),
      };
    });
    if (!title || songs.length === 0) {
      throw new UpstreamError('Collection metadata has no playable catalog');
    }
    const genres = Array.isArray(playlist.genre)
      ? playlist.genre.map(text).filter(Boolean)
      : text(playlist.genre).split(',').map((genre) => genre.trim()).filter(Boolean);
    const artist = [...new Set(songs.flatMap((song) => song.artist.split(', ')))]
      .filter(Boolean)
      .slice(0, 4)
      .join(', ');
    const thumbnail = text(playlist.image) || text(playlist.thumbnailUrl);
    const externalUrl = text(playlist.url) || endpoint.toString();
    const metadataType = playlist['@type'];
    const isAlbum = metadataType === 'MusicAlbum'
      || (Array.isArray(metadataType) && metadataType.includes('MusicAlbum'));
    return {
      id,
      title,
      artist,
      thumbnail: thumbnail
        ? normalizeUrl(thumbnail, this.config.currentApiBaseUrl)
        : '',
      kind: isAlbum || /\b(single|ep|album)\b/i.test(title)
        ? 'album'
        : 'playlist',
      externalUrl: normalizeUrl(externalUrl, this.config.currentApiBaseUrl),
      artists: officialMetadata.artists,
      description: text(playlist.description),
      year: text(playlist.datePublished),
      releasedAt: officialMetadata.releasedAt,
      distributor: officialMetadata.distributor,
      likeCount: officialMetadata.likeCount,
      genres,
      songs,
      sections: officialMetadata.sections,
      catalogPlaybackEnabled: this.hasCurrentApiCredentials,
    };
  }

  async fetchLyrics(
    code: string,
    signal?: AbortSignal,
  ): Promise<SongLyricsDto> {
    if (!this.hasCurrentApiCredentials) {
      throw new UpstreamError('Current lyric adapter is not configured');
    }
    const endpoint = this.signedCurrentApiUrl('/api/v2/lyric/get/lyric', {
      id: code,
    });
    const response = await this.request(endpoint, signal);
    const payload = await readJson(response);
    const data = asObject(payload.data);
    if (!data) throw new UpstreamError('Lyric payload is missing');

    const rawSentences = Array.isArray(data.sentences) ? data.sentences : [];
    const syncedLines = rawSentences
      .flatMap((sentence) => {
        const line = syncedLyricLine(sentence);
        return line ? [line] : [];
      })
      .sort((left, right) => left.startTimeMs - right.startTimeMs)
      .slice(0, MAX_LYRIC_LINES);
    if (syncedLines.length > 0) {
      return { songId: code, synced: true, lines: syncedLines };
    }

    const lyricFile = text(data.file);
    if (lyricFile) {
      try {
        const fileUrl = new URL(lyricFile, this.config.currentApiBaseUrl);
        const fileBody = await this.fetchLyricFile(fileUrl, signal);
        const fileLines = lrcLyricLines(fileBody);
        if (fileLines.length > 0) {
          return { songId: code, synced: true, lines: fileLines };
        }
      } catch (error) {
        if (isAbortError(error)) throw error;
        // Untrusted URLs are rejected before an outbound file request; any
        // other file failure still leaves inline lyrics as a safe fallback.
      }
    }

    const inlineLyrics = text(data.lyric);
    const inlineSyncedLines = lrcLyricLines(inlineLyrics);
    if (inlineSyncedLines.length > 0) {
      return { songId: code, synced: true, lines: inlineSyncedLines };
    }
    const plainLines = inlineLyrics
      .replace(/\r\n?/g, '\n')
      .split('\n')
      .map(lyricText)
      .filter(Boolean)
      .slice(0, MAX_LYRIC_LINES)
      .map((line) => ({ startTimeMs: 0, endTimeMs: 0, text: line }));
    return { songId: code, synced: false, lines: plainLines };
  }

  async fetchSongDetail(
    id: string,
    signal?: AbortSignal,
  ): Promise<SongDetailDto> {
    if (!this.hasCurrentApiCredentials) {
      throw new UpstreamError('Current song-detail adapter is not configured');
    }
    const endpoint = this.signedCurrentApiUrl('/api/v2/page/get/song', {
      id,
    });
    const response = await this.request(endpoint, signal);
    const payload = await readJson(response);
    const data = asObject(payload.data);
    if (!data) throw new UpstreamError('Song detail payload is missing');

    const responseId = text(data.encodeId) || text(data.id);
    const title = text(data.title) || text(data.name);
    if (!responseId || responseId !== id || !title) {
      throw new UpstreamError('Song detail payload does not match the request');
    }
    const link = text(data.link);
    const streamingStatus = String(data.streamingStatus ?? '').trim();
    const isRestricted =
      data.isPrivate === true ||
      data.preRelease === true ||
      text(data.block).toLowerCase() === 'true';
    const song: SearchSongDto = {
      id: responseId,
      code: responseId,
      title: title.slice(0, 300),
      artist: text(data.artistsNames || data.artist).slice(0, 300),
      albumCover: optionalArtworkUrl(data.thumbnailM || data.thumbnail),
      durationSeconds: Math.min(
        24 * 60 * 60,
        Math.max(0, Math.floor(finiteNumber(data.duration))),
      ),
      externalUrl: /^\/bai-hat\//.test(link)
        ? normalizeUrl(link, this.config.currentApiBaseUrl)
        : `${this.config.currentApiBaseUrl}/link/song/${encodeURIComponent(responseId)}`,
      playable: !isRestricted && streamingStatus === '1',
      hasLyrics: data.hasLyric === true,
    };

    const normalizePeople = (value: unknown) => {
      const rawItems = Array.isArray(value) ? value : [];
      const byId = new Map<string, SearchArtistDto>();
      for (const raw of rawItems) {
        const item = asObject(raw);
        if (!item) continue;
        const person = artistProfile(item, this.config.currentApiBaseUrl);
        if (!person || byId.has(person.id)) continue;
        byId.set(person.id, person);
        if (byId.size === 8) break;
      }
      return [...byId.values()];
    };

    const albumData = asObject(data.album);
    const normalizedAlbum =
      albumData && albumData.isPrivate !== true && albumData.preRelease !== true
        ? discoveryCollection(albumData, this.config.currentApiBaseUrl)
        : undefined;
    const album = normalizedAlbum
      ? { ...normalizedAlbum, kind: 'album' as const }
      : undefined;

    const genres = Array.isArray(data.genres)
      ? [...new Set(
          data.genres
            .map((raw) => text(asObject(raw)?.name))
            .filter(Boolean)
            .map((name) => name.slice(0, 80)),
        )].slice(0, 8)
      : [];

    const mvLink = text(data.mvlink);
    let mv: SearchVideoDto | undefined;
    if (!isRestricted && /^\/video-clip\//.test(mvLink)) {
      const mvArtists = normalizePeople(data.artists);
      mv = {
        id: responseId,
        title: song.title,
        artist: song.artist,
        ...(mvArtists.length > 0 ? { artists: mvArtists } : {}),
        thumbnail: song.albumCover,
        durationSeconds: song.durationSeconds,
        externalUrl: normalizeUrl(mvLink, this.config.currentApiBaseUrl),
      };
    }

    const boundedCount = (value: unknown) =>
      Math.min(
        Number.MAX_SAFE_INTEGER,
        Math.max(0, Math.floor(finiteNumber(value))),
      );
    return {
      song,
      artists: normalizePeople(data.artists),
      ...(album ? { album } : {}),
      releasedAt: timestampMilliseconds(data.releaseDate, 0),
      distributor: text(data.distributor).slice(0, 200),
      genres,
      composers: normalizePeople(data.composers),
      listenCount: boundedCount(data.listen),
      likeCount: boundedCount(data.like),
      commentCount: boundedCount(data.comment),
      ...(mv ? { mv } : {}),
      catalogPlaybackEnabled: true,
    };
  }

  async fetchSongRadio(
    code: string,
    signal?: AbortSignal,
  ): Promise<SongRadioDto> {
    if (!this.hasCurrentApiCredentials) {
      throw new UpstreamError('Current catalog adapter is not configured');
    }
    const endpoint = this.signedCurrentApiUrl(
      '/api/v2/recommend/get/songs',
      { id: code, count: '30' },
    );
    const response = await this.request(endpoint, signal);
    const payload = await readJson(response);
    const data = asObject(payload.data);
    const rawItems = Array.isArray(data?.items) ? data.items : [];
    const seen = new Set<string>([code]);
    const songs = rawItems.flatMap((raw): SearchSongDto[] => {
      const item = asObject(raw);
      if (
        !item
        || item.isPrivate === true
        || item.preRelease === true
        || String(item.streamingStatus ?? '').trim() !== '1'
      ) {
        return [];
      }
      const id = text(item.encodeId);
      const title = text(item.title);
      if (!id || !title || seen.has(id)) return [];
      seen.add(id);
      const link = text(item.link);
      return [{
        id,
        code: id,
        title,
        artist: text(item.artistsNames),
        albumCover: optionalArtworkUrl(item.thumbnailM || item.thumbnail),
        durationSeconds: Math.min(
          24 * 60 * 60,
          Math.max(0, Math.floor(finiteNumber(item.duration))),
        ),
        externalUrl: /^\/bai-hat\//.test(link)
          ? normalizeUrl(link, this.config.currentApiBaseUrl)
          : `${this.config.currentApiBaseUrl}/link/song/${encodeURIComponent(id)}`,
        playable: true,
      }];
    }).slice(0, 30);
    return {
      seedId: code,
      songs,
      catalogPlaybackEnabled: true,
    };
  }

  async fetchLiveRadio(signal?: AbortSignal): Promise<LiveRadioSnapshotDto> {
    if (!this.hasCurrentApiCredentials) {
      throw new UpstreamError('Current catalog adapter is not configured');
    }
    const endpoint = this.signedCurrentApiUrl('/api/v2/page/get/radio', {
      page: '1',
      count: '18',
    });
    const response = await this.request(endpoint, signal);
    const payload = await readJson(response);
    const data = asObject(payload.data);
    const sections = Array.isArray(data?.items) ? data.items : [];
    const allowedHosts = this.config.streamHosts ?? ['zmdcdn.me'];
    const seen = new Set<string>();
    const rooms = sections.flatMap((raw): LiveRadioRoomDto[] => {
      const section = asObject(raw);
      if (text(section?.sectionType) !== 'livestream') return [];
      const items = Array.isArray(section?.items) ? section.items : [];
      return items.flatMap((entry): LiveRadioRoomDto[] => {
        const item = asObject(entry);
        if (!item || finiteNumber(item.status, -1) !== 2) return [];
        const id = text(item.encodeId) || text(item.id);
        const title = text(item.title);
        const streamUrl = text(item.streaming);
        if (
          !id
          || !title
          || seen.has(id)
          || !isAllowedStreamUrl(streamUrl, allowedHosts)
        ) {
          return [];
        }
        seen.add(id);
        this.liveRadioSources.set(id, {
          url: streamUrl,
          expiresAt: this.now() + 30_000,
        });
        const host = asObject(item.host);
        const rawProgram = asObject(item.program);
        let program: LiveRadioProgramDto | undefined;
        if (rawProgram) {
          const programId = text(rawProgram.encodeId);
          const programTitle = text(rawProgram.title);
          if (programId && programTitle) {
            program = {
              id: programId,
              title: programTitle,
              thumbnail: optionalArtworkUrl(
                rawProgram.thumbnailH || rawProgram.thumbnail,
              ),
              description: text(rawProgram.description).slice(0, 500),
              startTime: timestampMilliseconds(rawProgram.startTime, 0),
              endTime: timestampMilliseconds(rawProgram.endTime, 0),
            };
          }
        }
        return [{
          id,
          title: title.slice(0, 200),
          description: text(item.description).slice(0, 500),
          thumbnail: optionalArtworkUrl(
            item.thumbnailM || item.thumbnail || item.thumbnailV,
          ),
          listenerCount: Math.min(
            10_000_000,
            Math.max(0, Math.floor(finiteNumber(item.activeUsers))),
          ),
          hostName: text(host?.name).slice(0, 200),
          hostThumbnail: optionalArtworkUrl(host?.thumbnail),
          ...(program ? { program } : {}),
        }];
      });
    }).slice(0, 18);
    if (rooms.length === 0) {
      throw new UpstreamError('Live radio has no active rooms');
    }
    const now = this.now();
    for (const [id, source] of this.liveRadioSources) {
      if (source.expiresAt <= now || !seen.has(id)) {
        this.liveRadioSources.delete(id);
      }
    }
    return {
      updatedAt: timestampMilliseconds(payload.timestamp, now),
      rooms,
    };
  }

  async resolveLiveRadioStream(
    id: string,
    signal?: AbortSignal,
  ): Promise<string> {
    const cached = this.liveRadioSources.get(id);
    if (cached && cached.expiresAt > this.now()) return cached.url;
    await this.fetchLiveRadio(signal);
    const resolved = this.liveRadioSources.get(id);
    if (!resolved || resolved.expiresAt <= this.now()) {
      throw new UpstreamError('Live radio room is unavailable');
    }
    return resolved.url;
  }

  async fetchSource(
    code: string,
    signal?: AbortSignal,
    quality: StreamQuality = 'auto',
  ): Promise<string> {
    const resolveBitrate = (
      source: JsonObject | undefined,
      baseUrl: string,
      bitrate: '128' | '320',
    ) => {
      const rawUrl = text(source?.[bitrate]);
      if (!rawUrl) return undefined;
      if (rawUrl.startsWith('//') || /^https?:\/\//i.test(rawUrl)) {
        return normalizeUrl(rawUrl, baseUrl);
      }
      if (/^[a-z][a-z0-9+.-]*:/i.test(rawUrl)) {
        return normalizeUrl(rawUrl, baseUrl);
      }
      return undefined;
    };
    let legacySource: JsonObject | undefined;
    let legacyError: unknown;
    try {
      const endpoint = new URL(this.config.sourceUrl);
      endpoint.searchParams.set('type', 'audio');
      endpoint.searchParams.set('key', code);
      const response = await this.request(endpoint, signal);
      const payload = await readJson(response);
      legacySource = asObject(asObject(payload.data)?.source);
      const requestedLegacy = quality === 'auto'
        ? resolveBitrate(legacySource, this.config.sourceUrl, '320')
        : resolveBitrate(legacySource, this.config.sourceUrl, quality);
      if (requestedLegacy) return requestedLegacy;
      legacyError = new UpstreamError(
        quality === 'auto'
          ? 'No 320 kbps legacy source was returned'
          : `No ${quality} kbps legacy source was returned`,
      );
    } catch (error) {
      if (isAbortError(error)) throw error;
      legacyError = error;
    }

    if (!this.hasCurrentApiCredentials) {
      if (quality === 'auto') {
        const legacyFallback = resolveBitrate(
          legacySource,
          this.config.sourceUrl,
          '128',
        );
        if (legacyFallback) return legacyFallback;
      }
      if (legacyError instanceof Error) throw legacyError;
      throw new UpstreamError('No playable source was returned');
    }

    let currentSource: JsonObject | undefined;
    let currentError: unknown;
    try {
      const endpoint = this.signedCurrentApiUrl('/api/v2/song/get/streaming', {
        id: code,
      });
      const response = await this.request(endpoint, signal);
      const payload = await readJson(response);
      currentSource = asObject(payload.data);
    } catch (error) {
      if (isAbortError(error)) throw error;
      currentError = error;
    }

    if (quality === 'auto') {
      const currentHigh = resolveBitrate(
        currentSource,
        this.config.currentApiBaseUrl,
        '320',
      );
      if (currentHigh) return currentHigh;
      const legacyFallback = resolveBitrate(
        legacySource,
        this.config.sourceUrl,
        '128',
      );
      if (legacyFallback) return legacyFallback;
      const currentFallback = resolveBitrate(
        currentSource,
        this.config.currentApiBaseUrl,
        '128',
      );
      if (currentFallback) return currentFallback;
      if (currentError instanceof Error) throw currentError;
      if (legacyError instanceof Error) throw legacyError;
      throw new UpstreamError('No playable source was returned');
    }

    const currentRequested = resolveBitrate(
      currentSource,
      this.config.currentApiBaseUrl,
      quality,
    );
    if (currentRequested) return currentRequested;
    if (currentError instanceof Error) throw currentError;
    throw new UpstreamError(
      `The requested ${quality} kbps source is unavailable`,
    );
  }

  private signedCurrentApiUrl(
    path: string,
    params: Record<string, string>,
    baseUrl = this.config.currentApiBaseUrl,
  ) {
    const signingParams: Record<string, string> = {
      ...params,
      ctime: String(Math.floor(this.now() / 1000)),
      version: this.config.currentApiVersion,
    };
    const serialized = Object.keys(signingParams)
      .sort()
      .map((key) => `${key}=${signingParams[key]}`)
      .join('');
    const digest = createHash('sha256').update(serialized).digest('hex');
    const signature = createHmac('sha512', this.config.currentApiSigningKey)
      .update(`${path}${digest}`)
      .digest('hex');
    const endpoint = new URL(path, `${baseUrl}/`);
    for (const [key, value] of Object.entries(signingParams)) {
      endpoint.searchParams.set(key, value);
    }
    endpoint.searchParams.set('sig', signature);
    endpoint.searchParams.set('apiKey', this.config.currentApiKey);
    return endpoint;
  }

  private async fetchLyricFile(endpoint: URL, signal?: AbortSignal) {
    let current = endpoint;
    const allowedHosts = this.config.streamHosts ?? ['zmdcdn.me'];
    for (let redirects = 0; redirects <= MAX_LYRIC_REDIRECTS; redirects++) {
      if (!trustedLyricUrl(
        current,
        this.config.currentApiBaseUrl,
        allowedHosts,
      )) {
        throw new UpstreamError('Upstream lyric URL is not trusted');
      }
      const response = await this.request(
        current,
        signal,
        'text/plain,text/*;q=0.9',
        'manual',
      );
      if (!REDIRECT_STATUSES.has(response.status)) {
        if (
          response.url
          && !trustedLyricUrl(
            response.url,
            this.config.currentApiBaseUrl,
            allowedHosts,
          )
        ) {
          await discardResponseBody(response);
          throw new UpstreamError('Upstream lyric URL is not trusted');
        }
        if (!response.ok) {
          await discardResponseBody(response);
          throw new UpstreamError('Upstream lyric file failed', response.status);
        }
        const contentLength = finiteNumber(response.headers.get('content-length'));
        if (contentLength > MAX_LYRIC_FILE_BYTES) {
          await discardResponseBody(response);
          throw new UpstreamError('Upstream lyric file is too large');
        }
        return readTextWithByteLimit(
          response,
          MAX_LYRIC_FILE_BYTES,
          'lyric file',
        );
      }
      const location = response.headers.get('location');
      if (!location || redirects === MAX_LYRIC_REDIRECTS) {
        await discardResponseBody(response);
        throw new UpstreamError('Upstream lyric redirected too many times');
      }
      let next: URL;
      try {
        next = new URL(location, current);
      } catch {
        await discardResponseBody(response);
        throw new UpstreamError('Upstream lyric redirect is invalid');
      }
      if (!trustedLyricUrl(
        next,
        this.config.currentApiBaseUrl,
        allowedHosts,
      )) {
        await discardResponseBody(response);
        throw new UpstreamError('Upstream lyric URL is not trusted');
      }
      await discardResponseBody(response);
      current = next;
    }
    throw new UpstreamError('Upstream lyric redirected too many times');
  }

  private async fetchCollectionPage(endpoint: URL, signal?: AbortSignal) {
    let current = endpoint;
    for (let redirects = 0; redirects <= MAX_COLLECTION_REDIRECTS; redirects++) {
      if (!trustedCollectionUrl(current, this.config.currentApiBaseUrl)) {
        throw new UpstreamError('Upstream collection redirect is not trusted');
      }
      const response = await this.request(
        current,
        signal,
        'text/html,application/xhtml+xml',
        'manual',
      );
      if (!REDIRECT_STATUSES.has(response.status)) {
        if (
          response.url
          && !trustedCollectionUrl(response.url, this.config.currentApiBaseUrl)
        ) {
          throw new UpstreamError('Upstream collection redirect is not trusted');
        }
        return response;
      }
      const location = response.headers.get('location');
      if (!location || redirects === MAX_COLLECTION_REDIRECTS) {
        await discardResponseBody(response);
        throw new UpstreamError('Upstream collection redirected too many times');
      }
      let next: URL;
      try {
        next = new URL(location, current);
      } catch {
        await discardResponseBody(response);
        throw new UpstreamError('Upstream collection redirect is invalid');
      }
      if (!trustedCollectionUrl(next, this.config.currentApiBaseUrl)) {
        await discardResponseBody(response);
        throw new UpstreamError('Upstream collection redirect is not trusted');
      }
      await discardResponseBody(response);
      current = next;
    }
    throw new UpstreamError('Upstream collection redirected too many times');
  }

  private async fetchCollectionTrackMetadata(
    songIds: string[],
    signal?: AbortSignal,
  ) {
    const results: Array<{
      playable: boolean;
      artists: SearchArtistDto[];
      album?: SearchCollectionDto;
    }> = Array.from({ length: songIds.length }, () => ({
      playable: false,
      artists: [],
    }));
    let cursor = 0;
    const worker = async () => {
      while (cursor < songIds.length) {
        const index = cursor++;
        const id = songIds[index]!;
        try {
          const endpoint = this.signedCurrentApiUrl('/api/v2/song/get/info', { id });
          const response = await this.request(endpoint, signal);
          const payload = await readJson(response);
          const data = asObject(payload.data);
          if (!data || text(data.encodeId) !== id) {
            throw new UpstreamError('Upstream song identity is invalid');
          }
          const artists = structuredSongArtists(
            data.artists,
            this.config.currentApiBaseUrl,
          );
          const album = structuredSongAlbum(
            data.album,
            this.config.currentApiBaseUrl,
          );
          results[index] = {
            playable: String(data.streamingStatus ?? '').trim() === '1',
            artists,
            ...(album ? { album } : {}),
          };
        } catch (error) {
          if (isAbortError(error)) throw error;
          results[index] = { playable: false, artists: [] };
        }
      }
    };
    await Promise.all(
      Array.from(
        { length: Math.min(COLLECTION_PLAYABILITY_CONCURRENCY, songIds.length) },
        worker,
      ),
    );
    return results;
  }

  private async fetchCollectionOfficialMetadata(
    id: string,
    signal?: AbortSignal,
  ) {
    let info = {
      likeCount: 0,
      artists: [] as SearchArtistDto[],
      releasedAt: 0,
      distributor: '',
    };
    let sections: DiscoverySectionDto[] = [];
    await Promise.all([
      this.fetchCollectionOfficialInfo(id, signal)
        .then((value) => {
          info = value;
        })
        .catch((error) => {
          if (isAbortError(error)) throw error;
        }),
      this.fetchCollectionBottomSections(id, signal)
        .then((value) => {
          sections = value;
        })
        .catch((error) => {
          if (isAbortError(error)) throw error;
        }),
    ]);
    return { ...info, sections };
  }

  private async fetchCollectionOfficialInfo(
    id: string,
    signal?: AbortSignal,
  ) {
    try {
      const endpoint = this.signedCurrentApiUrl('/api/v2/page/get/playlist', {
        id,
      });
      const response = await this.request(endpoint, signal);
      const payload = await readJson(response);
      const data = asObject(payload.data);
      if (!data || text(data.encodeId) !== id) {
        throw new UpstreamError('Upstream collection identity is invalid');
      }
      const rawArtists = [
        ...(Array.isArray(data.artists) ? data.artists : []),
        data.artist,
      ];
      const artists = new Map<string, SearchArtistDto>();
      for (const rawArtist of rawArtists) {
        const item = asObject(rawArtist);
        if (!item) continue;
        const artist = artistProfile(item, this.config.currentApiBaseUrl);
        if (
          !artist
          || !/^[A-Za-z0-9_-]{1,128}$/.test(artist.id)
          || !/^[A-Za-z0-9_-]{1,200}$/.test(artist.aliasName)
          || artists.has(artist.id)
        ) {
          continue;
        }
        artists.set(artist.id, artist);
        if (artists.size === 8) break;
      }
      return {
        likeCount: Math.min(
          Number.MAX_SAFE_INTEGER,
          Math.max(0, Math.floor(finiteNumber(data.like))),
        ),
        artists: [...artists.values()],
        releasedAt: timestampMilliseconds(data.releaseDate, 0),
        distributor: text(data.distributor).replace(/\s+/g, ' ').slice(0, 200),
      };
    } catch (error) {
      if (isAbortError(error)) throw error;
      return {
        likeCount: 0,
        artists: [] as SearchArtistDto[],
        releasedAt: 0,
        distributor: '',
      };
    }
  }

  private async fetchCollectionBottomSections(
    id: string,
    signal?: AbortSignal,
  ): Promise<DiscoverySectionDto[]> {
    const endpoint = this.signedCurrentApiUrl(
      '/api/v2/playlist/get/section-bottom',
      { id },
    );
    const response = await this.request(endpoint, signal);
    const payload = await readJson(response);
    const data = asObject(payload.data);
    const rawSections = Array.isArray(payload.data)
      ? payload.data
      : Array.isArray(data?.items)
        ? data.items
        : [];
    const sectionIds = new Set<string>();
    const sections: DiscoverySectionDto[] = [];
    for (let index = 0; index < rawSections.length; index++) {
      const rawSection = asObject(rawSections[index]);
      if (!rawSection) continue;
      const parsed = discoverySection(
        rawSection,
        index,
        this.config.currentApiBaseUrl,
      );
      if (!parsed || sectionIds.has(parsed.id)) continue;
      const collectionIds = new Set<string>();
      const collections = parsed.collections.filter((collection) => {
        if (collectionIds.has(collection.id)) return false;
        collectionIds.add(collection.id);
        return true;
      }).slice(0, 12);
      if (collections.length === 0) continue;
      sectionIds.add(parsed.id);
      sections.push({ ...parsed, collections });
      if (sections.length === 4) break;
    }
    return sections;
  }

  private async request(
    input: string | URL,
    signal?: AbortSignal,
    accept = 'application/json',
    redirect: RequestRedirect = 'error',
  ) {
    try {
      return await this.fetcher(input, {
        headers: { accept },
        signal: signal ?? null,
        redirect,
      });
    } catch (error) {
      if (isAbortError(error)) throw error;
      throw new UpstreamError('Unable to contact upstream');
    }
  }
}
