import { afterEach, describe, expect, it, vi } from 'vitest';
import { buildApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import type { MusicUpstream, SongDto } from '../src/types.js';
import { UpstreamError } from '../src/types.js';

const song: SongDto = {
  id: 'song-1',
  code: 'ABC123',
  title: 'Nàng thơ',
  artist: 'Hoàng Dũng',
  albumCover: 'https://example.test/cover.jpg',
  rank: 1,
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
      fetchChart: vi.fn().mockResolvedValue([song]),
      fetchSource: vi.fn().mockResolvedValue('https://stream.example.test/song.mp3'),
    };
    const app = await setup(upstream);

    const health = await app.inject({ method: 'GET', url: '/health' });
    const chart = await app.inject({ method: 'GET', url: '/v1/chart' });
    const source = await app.inject({ method: 'GET', url: '/v1/songs/ABC123/source' });

    expect(health.statusCode).toBe(200);
    expect(health.json()).toEqual({ status: 'ok' });
    expect(chart.json()).toEqual({ songs: [song] });
    expect(source.json().url).toMatch(
      /^https:\/\/api\.example\.test\/v1\/streams\/[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/,
    );
    expect(upstream.fetchSource).not.toHaveBeenCalled();
  });

  it('rejects invalid song codes before contacting upstream', async () => {
    const upstream: MusicUpstream = {
      fetchChart: vi.fn(),
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
  it('relays range requests with media headers and disables caching', async () => {
    const upstream: MusicUpstream = {
      fetchChart: vi.fn(),
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
    const upstream: MusicUpstream = { fetchChart: vi.fn(), fetchSource: vi.fn() };
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
    const upstream: MusicUpstream = { fetchChart: vi.fn(), fetchSource: vi.fn() };
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

describe('CORS', () => {
  it('allows configured origins and omits the header for other origins', async () => {
    const upstream: MusicUpstream = { fetchChart: vi.fn(), fetchSource: vi.fn() };
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
});

describe('chart cache', () => {
  it('serves repeated requests from the short-lived cache', async () => {
    const fetchChart = vi.fn().mockResolvedValue([song]);
    const app = await setup({ fetchChart, fetchSource: vi.fn() });
    await app.inject({ method: 'GET', url: '/v1/chart' });
    await app.inject({ method: 'GET', url: '/v1/chart' });
    expect(fetchChart).toHaveBeenCalledTimes(1);
  });
});

describe('sanitized failures', () => {
  it('maps upstream failures without leaking their message and includes request ID', async () => {
    const app = await setup({
      fetchChart: vi.fn().mockRejectedValue(new UpstreamError('secret upstream detail', 503)),
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
      fetchChart: vi.fn(() => new Promise<SongDto[]>(() => undefined)),
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
    const upstream: MusicUpstream = { fetchChart: vi.fn(), fetchSource: vi.fn() };
    const app = await buildApp(config({ RATE_LIMIT_MAX: '1' }), upstream);
    apps.push(app);
    await app.inject({ method: 'GET', url: '/health' });
    const response = await app.inject({ method: 'GET', url: '/health' });
    expect(response.statusCode).toBe(429);
    expect(response.json().error.code).toBe('RATE_LIMITED');
    expect(response.json().error.requestId).toBeTypeOf('string');
  });
});
