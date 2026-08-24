import { Readable, Transform } from 'node:stream';
import type { AppConfig } from './config.js';
import { isAllowedStreamUrl } from './audio-relay.js';
import { UpstreamError } from './types.js';

const MAX_REDIRECTS = 3;
const MAX_PLAYLIST_BYTES = 1024 * 1024;
const MAX_MEDIA_BYTES = 32 * 1024 * 1024;
const REDIRECT_STATUSES = new Set([301, 302, 303, 307, 308]);
const PLAYLIST_CONTENT_TYPES = [
  'application/vnd.apple.mpegurl',
  'application/x-mpegurl',
  'audio/mpegurl',
  'audio/x-mpegurl',
];

export interface LiveRelay {
  response: Response;
  finalUrl: string;
  signal: AbortSignal;
  dispose(): void;
  abort(): void;
}

export async function fetchLiveResource(
  initialUrl: string,
  range: string | undefined,
  config: Pick<AppConfig, 'streamHosts' | 'upstreamTimeoutMs'>,
  fetcher: typeof fetch,
): Promise<LiveRelay> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), config.upstreamTimeoutMs);
  let handedOff = false;
  let currentUrl = initialUrl;
  try {
    for (let redirects = 0; redirects <= MAX_REDIRECTS; redirects += 1) {
      if (!isAllowedStreamUrl(currentUrl, config.streamHosts)) {
        throw new UpstreamError('Live stream URL is not allowed');
      }
      let response: Response;
      try {
        response = await fetcher(currentUrl, {
          redirect: 'manual',
          signal: controller.signal,
          headers: range
            ? { accept: '*/*', range }
            : { accept: 'application/vnd.apple.mpegurl,audio/*,*/*;q=0.5' },
        });
      } catch (error) {
        if (error instanceof Error && error.name === 'AbortError') throw error;
        throw new UpstreamError('Unable to contact live stream upstream');
      }
      if (REDIRECT_STATUSES.has(response.status)) {
        const location = response.headers.get('location');
        await response.body?.cancel();
        if (!location || redirects === MAX_REDIRECTS) {
          throw new UpstreamError('Invalid live stream redirect');
        }
        currentUrl = new URL(location, currentUrl).toString();
        continue;
      }
      if (response.status === 416) {
        handedOff = true;
        return relay(response, currentUrl, controller, timeout);
      }
      if (![200, 206].includes(response.status) || !response.body) {
        await response.body?.cancel();
        throw new UpstreamError(
          'Live stream upstream rejected the request',
          response.status,
        );
      }
      handedOff = true;
      return relay(response, currentUrl, controller, timeout);
    }
    throw new UpstreamError('Too many live stream redirects');
  } finally {
    if (!handedOff) clearTimeout(timeout);
  }
}

function relay(
  response: Response,
  finalUrl: string,
  controller: AbortController,
  timeout: NodeJS.Timeout,
): LiveRelay {
  return {
    response,
    finalUrl,
    signal: controller.signal,
    dispose: () => clearTimeout(timeout),
    abort() {
      clearTimeout(timeout);
      controller.abort();
    },
  };
}

export function isHlsPlaylist(response: Response, finalUrl: string) {
  const type = (response.headers.get('content-type') ?? '')
    .split(';', 1)[0]
    ?.trim()
    .toLowerCase();
  return Boolean(
    (type && PLAYLIST_CONTENT_TYPES.includes(type))
    || new URL(finalUrl).pathname.toLowerCase().endsWith('.m3u8'),
  );
}

export async function readHlsPlaylist(relay: LiveRelay) {
  const declared = Number(relay.response.headers.get('content-length'));
  if (Number.isFinite(declared) && declared > MAX_PLAYLIST_BYTES) {
    await relay.response.body?.cancel();
    relay.abort();
    throw new UpstreamError('Live playlist is too large');
  }
  const reader = relay.response.body?.getReader();
  if (!reader) {
    relay.abort();
    throw new UpstreamError('Live playlist is empty');
  }
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > MAX_PLAYLIST_BYTES) {
        await reader.cancel();
        relay.abort();
        throw new UpstreamError('Live playlist is too large');
      }
      chunks.push(value);
    }
    const body = Buffer.concat(chunks.map((chunk) => Buffer.from(chunk)));
    return body.toString('utf8');
  } finally {
    relay.dispose();
  }
}

export function rewriteHlsPlaylist(
  source: string,
  upstreamUrl: string,
  proxyUrlFor: (absoluteUrl: string) => string,
) {
  const normalized = source.replace(/\r\n?/g, '\n');
  if (!normalized.trimStart().startsWith('#EXTM3U')) {
    throw new UpstreamError('Live playlist is malformed');
  }
  const rewrite = (value: string) => {
    const absolute = new URL(value, upstreamUrl).toString();
    return proxyUrlFor(absolute);
  };
  return normalized
    .split('\n')
    .map((line) => {
      const trimmed = line.trim();
      if (!trimmed) return line;
      if (!trimmed.startsWith('#')) return rewrite(trimmed);
      return line.replace(/URI="([^"]+)"/g, (_match, uri: string) => (
        `URI="${rewrite(uri)}"`
      ));
    })
    .join('\n');
}

export function liveMediaBody(relay: LiveRelay) {
  const declared = Number(relay.response.headers.get('content-length'));
  if (Number.isFinite(declared) && declared > MAX_MEDIA_BYTES) {
    relay.abort();
    throw new UpstreamError('Live media segment is too large');
  }
  if (!relay.response.body) {
    relay.abort();
    throw new UpstreamError('Live media segment is empty');
  }
  const input = Readable.fromWeb(
    relay.response.body as import('node:stream/web').ReadableStream<Uint8Array>,
  );
  let total = 0;
  const limit = new Transform({
    transform(chunk: Buffer, _encoding, callback) {
      total += chunk.length;
      if (total > MAX_MEDIA_BYTES) {
        callback(new UpstreamError('Live media segment is too large'));
        return;
      }
      callback(null, chunk);
    },
  });
  const body = input.pipe(limit);
  const abortBody = () => body.destroy(
    new DOMException('Live media relay timed out', 'AbortError'),
  );
  relay.signal.addEventListener('abort', abortBody, { once: true });
  const finish = () => {
    relay.signal.removeEventListener('abort', abortBody);
    relay.dispose();
  };
  body.once('end', finish);
  body.once('error', () => {
    relay.abort();
    finish();
  });
  body.once('close', finish);
  return body;
}
