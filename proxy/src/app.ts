import { randomUUID } from 'node:crypto';
import cors from '@fastify/cors';
import rateLimit from '@fastify/rate-limit';
import Fastify, { type FastifyInstance } from 'fastify';
import { audioBody, fetchAudio, validRange } from './audio-relay.js';
import type { AppConfig } from './config.js';
import { createStreamToken, readStreamToken } from './stream-token.js';
import type { MusicUpstream, SongDto } from './types.js';
import { UpstreamError } from './types.js';

interface CacheEntry {
  expiresAt: number;
  songs: SongDto[];
}

const CODE_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;
const REQUEST_ID_PATTERN = /^[A-Za-z0-9._:-]{1,128}$/;

export async function buildApp(
  config: AppConfig,
  upstream: MusicUpstream,
  audioFetcher: typeof fetch = fetch,
): Promise<FastifyInstance> {
  const app = Fastify({
    // Signed stream tokens can reach ~260 chars for the maximum accepted code.
    routerOptions: { maxParamLength: 384 },
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

  let chartCache: CacheEntry | undefined;
  let pendingChart: Promise<SongDto[]> | undefined;

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

  app.get('/health', async () => ({ status: 'ok' as const }));

  app.get('/v1/chart', async () => {
    const now = Date.now();
    if (chartCache && chartCache.expiresAt > now) return { songs: chartCache.songs };
    pendingChart ??= withTimeout((signal) => upstream.fetchChart(signal))
      .then((songs) => {
        chartCache = { songs, expiresAt: Date.now() + config.chartCacheTtlMs };
        return songs;
      })
      .finally(() => {
        pendingChart = undefined;
      });
    return { songs: await pendingChart };
  });

  app.get<{ Params: { code: string } }>('/v1/songs/:code/source', async (request, reply) => {
    const code = request.params.code.trim();
    if (!CODE_PATTERN.test(code)) {
      return reply.code(400).send({
        error: { code: 'INVALID_CODE', message: 'Mã bài hát không hợp lệ.', requestId: request.id },
      });
    }
    const token = createStreamToken(
      code,
      config.streamTokenSecret,
      config.streamTokenTtlSeconds,
    );
    return { url: `${config.publicBaseUrl}/v1/streams/${token}` };
  });

  app.get<{ Params: { token: string } }>('/v1/streams/:token', async (request, reply) => {
    reply.header('cache-control', 'private, no-store, max-age=0');
    reply.header('pragma', 'no-cache');
    const code = readStreamToken(request.params.token, config.streamTokenSecret);
    if (!code || !CODE_PATTERN.test(code)) {
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
    const sourceUrl = await withTimeout((signal) => upstream.fetchSource(code, signal));
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
