export interface AppConfig {
  host: string;
  port: number;
  corsOrigins: string[];
  upstreamTimeoutMs: number;
  chartCacheTtlMs: number;
  rateLimitMax: number;
  rateLimitWindowMs: number;
  trustProxyHops: number;
  chartUrl: string;
  sourceUrl: string;
  publicBaseUrl: string;
  streamTokenSecret: string;
  streamTokenTtlSeconds: number;
  streamHosts: string[];
  isProduction: boolean;
}

const DEFAULT_CHART_URL =
  'https://mp3.zing.vn/xhr/chart-realtime?songId=0&videoId=0&albumId=0&chart=song&time=-1';
const DEFAULT_SOURCE_URL =
  'https://m.zingmp3.vn/xhr/media/get-source?type=audio&key=';

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
    rateLimitMax: positiveInt(env.RATE_LIMIT_MAX, 120, 'RATE_LIMIT_MAX'),
    rateLimitWindowMs: positiveInt(
      env.RATE_LIMIT_WINDOW_MS,
      60_000,
      'RATE_LIMIT_WINDOW_MS',
    ),
    trustProxyHops: nonNegativeInt(env.TRUST_PROXY_HOPS, 0, 'TRUST_PROXY_HOPS'),
    chartUrl: url(env.ZING_CHART_URL, DEFAULT_CHART_URL, 'ZING_CHART_URL'),
    sourceUrl: url(env.ZING_SOURCE_URL, DEFAULT_SOURCE_URL, 'ZING_SOURCE_URL'),
    publicBaseUrl,
    streamTokenSecret,
    streamTokenTtlSeconds: positiveInt(
      env.STREAM_TOKEN_TTL_SECONDS,
      300,
      'STREAM_TOKEN_TTL_SECONDS',
    ),
    streamHosts,
    isProduction,
  };
}
