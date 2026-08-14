import { Readable } from 'node:stream';
import type { AppConfig } from './config.js';
import { UpstreamError } from './types.js';

const MAX_REDIRECTS = 3;
const RANGE_PATTERN = /^bytes=(?:\d+-\d*|-\d+)$/;

export function isAllowedStreamUrl(rawUrl: string, allowedHosts: string[]) {
  let url: URL;
  try {
    url = new URL(rawUrl);
  } catch {
    return false;
  }
  if (url.protocol !== 'https:' || url.username || url.password || url.port) return false;
  const hostname = url.hostname.toLowerCase();
  return allowedHosts.some((host) => hostname === host || hostname.endsWith(`.${host}`));
}

export function validRange(range: string | undefined) {
  return range === undefined || RANGE_PATTERN.test(range);
}

export async function fetchAudio(
  initialUrl: string,
  range: string | undefined,
  config: Pick<AppConfig, 'streamHosts' | 'upstreamTimeoutMs'>,
  fetcher: typeof fetch,
) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), config.upstreamTimeoutMs);
  let handedOff = false;
  let currentUrl = initialUrl;
  try {
    for (let redirectCount = 0; redirectCount <= MAX_REDIRECTS; redirectCount += 1) {
      if (!isAllowedStreamUrl(currentUrl, config.streamHosts)) {
        throw new UpstreamError('Upstream returned a disallowed stream URL');
      }
      let response: Response;
      try {
        response = await fetcher(currentUrl, {
          headers: range ? { accept: 'audio/*', range } : { accept: 'audio/*' },
          redirect: 'manual',
          signal: controller.signal,
        });
      } catch (error) {
        if (error instanceof Error && error.name === 'AbortError') throw error;
        throw new UpstreamError('Unable to contact audio upstream');
      }
      if ([301, 302, 303, 307, 308].includes(response.status)) {
        const location = response.headers.get('location');
        if (!location || redirectCount === MAX_REDIRECTS) {
          throw new UpstreamError('Invalid audio redirect');
        }
        currentUrl = new URL(location, currentUrl).toString();
        continue;
      }
      if (response.status === 416) return {
        response,
        signal: controller.signal,
        dispose() {
          clearTimeout(timeout);
        },
        abort() {
          clearTimeout(timeout);
          controller.abort();
        },
      };
      if (![200, 206].includes(response.status) || !response.body) {
        throw new UpstreamError('Audio upstream rejected the request', response.status);
      }
      handedOff = true;
      return {
        response,
        signal: controller.signal,
        dispose() {
          clearTimeout(timeout);
        },
        abort() {
          clearTimeout(timeout);
          controller.abort();
        },
      };
    }
    throw new UpstreamError('Too many audio redirects');
  } finally {
    if (!handedOff) clearTimeout(timeout);
  }
}

export function audioBody(
  response: Response,
  signal: AbortSignal,
  dispose: () => void,
) {
  if (!response.body) throw new UpstreamError('Audio upstream returned an empty body');
  const body = Readable.fromWeb(
    response.body as import('node:stream/web').ReadableStream<Uint8Array>,
  );
  const abortBody = () => body.destroy(new DOMException('Audio relay timed out', 'AbortError'));
  signal.addEventListener('abort', abortBody, { once: true });
  const finish = () => {
    signal.removeEventListener('abort', abortBody);
    dispose();
  };
  body.once('end', finish);
  body.once('error', finish);
  body.once('close', finish);
  return body;
}
