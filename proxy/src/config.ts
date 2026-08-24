export interface AppConfig {
  host: string;
  port: number;
  corsOrigins: string[];
  upstreamTimeoutMs: number;
  chartCacheTtlMs: number;
  searchCacheTtlMs: number;
  rateLimitMax: number;
  rateLimitWindowMs: number;
  trustProxyHops: number;
  chartUrl: string;
  searchUrl: string;
  suggestionUrl: string;
  sourceUrl: string;
  currentApiBaseUrl: string;
  currentApiKey: string;
  currentApiSigningKey: string;
  currentApiVersion: string;
  publicBaseUrl: string;
  streamTokenSecret: string;
  streamTokenTtlSeconds: number;
  liveRadioCacheTtlMs: number;
  liveStreamTokenTtlSeconds: number;
  streamHosts: string[];
  isProduction: boolean;
}

const DEFAULT_CHART_URL =
  'https://mp3.zing.vn/xhr/chart-realtime?songId=0&videoId=0&albumId=0&chart=song&time=-1';
const DEFAULT_SOURCE_URL =
  'https://m.zingmp3.vn/xhr/media/get-source?type=audio&key=';
const DEFAULT_SEARCH_URL =
  'https://ac.zingmp3.vn/complete?type=artist,song,album&num=25';
const DEFAULT_SUGGESTION_URL =
  'https://ac.zingmp3.vn/v1/web/ac-suggestions';
const DEFAULT_CURRENT_API_BASE_URL = 'https://zingmp3.vn';

function positiveInt(value: string | undefined, fallback: number, name: string) {
  if (value === undefined || value.trim() === '') return fallback;
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed <= 0) {
    throw new Error(`${name} must be a positive integer`);
  }
  return parsed;
}

function nonNegativeInt(value: string | undefined, fallback: number, name: string) {
  if (value === undefined || value.trim() === '') return fallback;
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 0) {
    throw new Error(`${name} must be a non-negative integer`);
  }
  return parsed;
}

function url(value: string | undefined, fallback: string, name: string) {
  const candidate = value?.trim() || fallback;
  try {
    return new URL(candidate).toString();
  } catch {
    throw new Error(`${name} must be an absolute URL`);
  }
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const isProduction = env.NODE_ENV === 'production';
  const fallbackOrigins = isProduction
    ? []
    : ['http://localhost:3000', 'http://localhost:8080'];
  const corsOrigins = (env.CORS_ORIGINS?.split(',') ?? fallbackOrigins)
    .map((origin) => origin.trim().replace(/\/$/, ''))
    .filter(Boolean);

  if (isProduction && corsOrigins.length === 0) {
    throw new Error('CORS_ORIGINS is required in production');
  }

  for (const origin of corsOrigins) {
    // Packaged webOS/Tizen applications can identify their file origin as
    // the literal string "null". It is accepted only when explicitly listed.
    if (origin === 'null') continue;
    url(origin, origin, 'CORS_ORIGINS');
  }

  const publicBaseUrl = url(
    env.PUBLIC_BASE_URL,
    'http://localhost:8080',
    'PUBLIC_BASE_URL',
  ).replace(/\/$/, '');
  const publicUrl = new URL(publicBaseUrl);
  if (publicUrl.username || publicUrl.password || publicUrl.search || publicUrl.hash
    || (publicUrl.pathname !== '/' && publicUrl.pathname !== '')) {
    throw new Error('PUBLIC_BASE_URL must contain only scheme, host, and optional port');
  }
  if (isProduction && publicUrl.protocol !== 'https:') {
    throw new Error('PUBLIC_BASE_URL must use HTTPS in production');
  }
  const streamTokenSecret = env.STREAM_TOKEN_SECRET?.trim()
    || (isProduction ? '' : 'development-only-stream-token-secret');
  if (isProduction && streamTokenSecret.length < 32) {
    throw new Error('STREAM_TOKEN_SECRET must contain at least 32 characters in production');
  }
  const streamHosts = (env.STREAM_HOSTS?.split(',')
    ?? ['zingmp3.vn', 'zmdcdn.me'])
    .map((host) => host.trim().toLowerCase().replace(/^\./, ''))
    .filter(Boolean);
  if (streamHosts.length === 0 || streamHosts.some((host) => !/^[a-z0-9.-]+$/.test(host))) {
    throw new Error('STREAM_HOSTS must contain valid comma-separated host suffixes');
  }

  const currentApiKey = env.ZING_CURRENT_API_KEY?.trim() || '';
  const currentApiSigningKey = env.ZING_CURRENT_API_SIGNING_KEY?.trim() || '';
  if (Boolean(currentApiKey) !== Boolean(currentApiSigningKey)) {
    throw new Error(
      'ZING_CURRENT_API_KEY and ZING_CURRENT_API_SIGNING_KEY must be configured together',
    );
  }
  const currentApiVersion = env.ZING_CURRENT_API_VERSION?.trim() || '1.20.1';
  if (!/^\d+\.\d+\.\d+$/.test(currentApiVersion)) {
    throw new Error('ZING_CURRENT_API_VERSION must use semantic numeric format');
  }
  const currentApiBaseUrl = url(
    env.ZING_CURRENT_API_BASE_URL,
    DEFAULT_CURRENT_API_BASE_URL,
    'ZING_CURRENT_API_BASE_URL',
  ).replace(/\/$/, '');
  if (currentApiKey && new URL(currentApiBaseUrl).protocol !== 'https:') {
    throw new Error('ZING_CURRENT_API_BASE_URL must use HTTPS when enabled');
  }
  const suggestionUrl = url(
    env.ZING_SUGGESTION_URL,
    DEFAULT_SUGGESTION_URL,
    'ZING_SUGGESTION_URL',
  );
  const suggestionEndpoint = new URL(suggestionUrl);
  if (suggestionEndpoint.protocol !== 'https:') {
    throw new Error('ZING_SUGGESTION_URL must use HTTPS');
  }
  if (
    suggestionEndpoint.username
    || suggestionEndpoint.password
    || suggestionEndpoint.search
    || suggestionEndpoint.hash
  ) {
    throw new Error(
      'ZING_SUGGESTION_URL must not contain credentials, query, or fragment',
    );
  }

  return {
    host: env.HOST?.trim() || '0.0.0.0',
    port: positiveInt(env.PORT, 8080, 'PORT'),
    corsOrigins,
    upstreamTimeoutMs: positiveInt(
      env.UPSTREAM_TIMEOUT_MS,
      10_000,
      'UPSTREAM_TIMEOUT_MS',
    ),
    chartCacheTtlMs: positiveInt(
      env.CHART_CACHE_TTL_MS,
      60_000,
      'CHART_CACHE_TTL_MS',
    ),
    searchCacheTtlMs: positiveInt(
      env.SEARCH_CACHE_TTL_MS,
      30_000,
      'SEARCH_CACHE_TTL_MS',
    ),
    rateLimitMax: positiveInt(env.RATE_LIMIT_MAX, 120, 'RATE_LIMIT_MAX'),
    rateLimitWindowMs: positiveInt(
      env.RATE_LIMIT_WINDOW_MS,
      60_000,
      'RATE_LIMIT_WINDOW_MS',
    ),
    trustProxyHops: nonNegativeInt(env.TRUST_PROXY_HOPS, 0, 'TRUST_PROXY_HOPS'),
    chartUrl: url(env.ZING_CHART_URL, DEFAULT_CHART_URL, 'ZING_CHART_URL'),
    searchUrl: url(env.ZING_SEARCH_URL, DEFAULT_SEARCH_URL, 'ZING_SEARCH_URL'),
    suggestionUrl,
    sourceUrl: url(env.ZING_SOURCE_URL, DEFAULT_SOURCE_URL, 'ZING_SOURCE_URL'),
    currentApiBaseUrl,
    currentApiKey,
    currentApiSigningKey,
    currentApiVersion,
    publicBaseUrl,
    streamTokenSecret,
    streamTokenTtlSeconds: positiveInt(
      env.STREAM_TOKEN_TTL_SECONDS,
      300,
      'STREAM_TOKEN_TTL_SECONDS',
    ),
    liveRadioCacheTtlMs: positiveInt(
      env.LIVE_RADIO_CACHE_TTL_MS,
      30_000,
      'LIVE_RADIO_CACHE_TTL_MS',
    ),
    liveStreamTokenTtlSeconds: positiveInt(
      env.LIVE_STREAM_TOKEN_TTL_SECONDS,
      21_600,
      'LIVE_STREAM_TOKEN_TTL_SECONDS',
    ),
    streamHosts,
    isProduction,
  };
}
