import type { AppConfig } from './config.js';
import { type MusicUpstream, type SongDto, UpstreamError } from './types.js';

type JsonObject = Record<string, unknown>;

function asObject(value: unknown): JsonObject | undefined {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? (value as JsonObject)
    : undefined;
}

function text(value: unknown) {
  return typeof value === 'string' ? value.trim() : '';
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
    private readonly config: Pick<AppConfig, 'chartUrl' | 'sourceUrl'>,
    private readonly fetcher: typeof fetch = fetch,
  ) {}

  async fetchChart(signal?: AbortSignal): Promise<SongDto[]> {
    const response = await this.request(this.config.chartUrl, signal);
    const payload = await readJson(response);
    const data = asObject(payload.data);
    if (!data || !Array.isArray(data.song)) {
      throw new UpstreamError('Upstream chart payload is missing songs');
    }

    return data.song.flatMap((raw, index): SongDto[] => {
      const item = asObject(raw);
      if (!item) return [];
      const id = text(item.id);
      const code = text(item.code);
      const title = text(item.title) || text(item.name);
      if (!id || !code || !title) return [];
      return [{
        id,
        code,
        title,
        artist: text(item.artists_names),
        albumCover: text(item.thumbnail)
          ? normalizeUrl(text(item.thumbnail), this.config.chartUrl)
          : '',
        rank: index + 1,
      }];
    });
  }

  async fetchSource(code: string, signal?: AbortSignal): Promise<string> {
    const endpoint = new URL(this.config.sourceUrl);
    endpoint.searchParams.set('type', 'audio');
    endpoint.searchParams.set('key', code);
    const response = await this.request(endpoint, signal);
    const payload = await readJson(response);
    const source = asObject(asObject(payload.data)?.source);
    const rawUrl = text(source?.['128']) || text(source?.['320']);
    if (!rawUrl) throw new UpstreamError('No playable source was returned');
    return normalizeUrl(rawUrl, this.config.sourceUrl);
  }

  private async request(input: string | URL, signal?: AbortSignal) {
    try {
      return await this.fetcher(input, {
        headers: { accept: 'application/json' },
        signal: signal ?? null,
      });
    } catch (error) {
      if (error instanceof Error && error.name === 'AbortError') throw error;
      throw new UpstreamError('Unable to contact upstream');
    }
  }
}
