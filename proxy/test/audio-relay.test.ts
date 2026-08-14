import { describe, expect, it, vi } from 'vitest';
import { audioBody, fetchAudio } from '../src/audio-relay.js';

describe('audio relay lifetime', () => {
  it('keeps the timeout active until the response body finishes', async () => {
    const stalled = new ReadableStream<Uint8Array>({
      pull() {
        // Intentionally never enqueue or close.
      },
    });
    const fetcher = vi.fn().mockResolvedValue(new Response(stalled));
    const relay = await fetchAudio(
      'https://stream.example.test/song.mp3',
      undefined,
      { streamHosts: ['stream.example.test'], upstreamTimeoutMs: 10 },
      fetcher,
    );
    const body = audioBody(relay.response, relay.signal, relay.dispose);
    await expect(new Promise<void>((resolve, reject) => {
      body.once('end', resolve);
      body.once('error', reject);
      body.resume();
    })).rejects.toMatchObject({ name: 'AbortError' });
  });
});
