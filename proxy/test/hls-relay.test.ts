import { describe, expect, it, vi } from 'vitest';
import {
  fetchLiveResource,
  isHlsPlaylist,
  readHlsPlaylist,
  rewriteHlsPlaylist,
} from '../src/hls-relay.js';

const config = {
  streamHosts: ['stream.example.test'],
  upstreamTimeoutMs: 1000,
};

describe('HLS relay', () => {
  it('validates every redirect before following it', async () => {
    const fetcher = vi.fn().mockResolvedValueOnce(new Response(null, {
      status: 302,
      headers: { location: 'https://attacker.example/live.m3u8' },
    }));
    await expect(fetchLiveResource(
      'https://radio.stream.example.test/live/index.m3u8',
      undefined,
      config,
      fetcher,
    )).rejects.toThrow('not allowed');
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('reads and rewrites child playlists, segments, keys, and maps', async () => {
    const source = [
      '#EXTM3U',
      '#EXT-X-STREAM-INF:BANDWIDTH=128000',
      'audio/index.m3u8',
      '#EXT-X-KEY:METHOD=AES-128,URI="keys/key.bin"',
      '#EXT-X-MAP:URI="init.mp4"',
      '#EXTINF:6.0,',
      'segment-1.aac?token=private',
    ].join('\n');
    const response = new Response(source, {
      headers: { 'content-type': 'application/vnd.apple.mpegurl' },
    });
    const relay = await fetchLiveResource(
      'https://radio.stream.example.test/live/master.m3u8',
      undefined,
      config,
      vi.fn().mockResolvedValue(response),
    );
    expect(isHlsPlaylist(relay.response, relay.finalUrl)).toBe(true);
    const playlist = await readHlsPlaylist(relay);
    const rewritten = rewriteHlsPlaylist(
      playlist,
      relay.finalUrl,
      (url) => `https://api.example.test/proxy/${encodeURIComponent(url)}`,
    );
    expect(rewritten).toContain(
      'https://api.example.test/proxy/https%3A%2F%2Fradio.stream.example.test%2Flive%2Faudio%2Findex.m3u8',
    );
    expect(rewritten).toContain('URI="https://api.example.test/proxy/');
    expect(rewritten).not.toContain('URI="keys/');
    expect(rewritten).not.toContain('\nsegment-1.aac');
  });

  it('cancels a playlist that exceeds the streamed byte cap', async () => {
    const cancel = vi.fn();
    const body = new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(new Uint8Array(1024 * 1024 + 1));
      },
      cancel,
    });
    const relay = await fetchLiveResource(
      'https://radio.stream.example.test/live/index.m3u8',
      undefined,
      config,
      vi.fn().mockResolvedValue(new Response(body, {
        headers: { 'content-type': 'application/vnd.apple.mpegurl' },
      })),
    );
    await expect(readHlsPlaylist(relay)).rejects.toThrow('too large');
    expect(cancel).toHaveBeenCalledTimes(1);
  });
});
