import { describe, expect, it, vi } from 'vitest';
import { ZingUpstream } from '../src/upstream.js';

const config = {
  chartUrl: 'https://chart.example.test/chart',
  sourceUrl: 'https://source.example.test/get-source',
};

describe('ZingUpstream', () => {
  it('normalizes chart payload and filters unusable entries', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0,
      data: { song: [
        { id: '1', code: 'A', title: 'Bài một', artists_names: 'Ca sĩ', thumbnail: '//img.test/a.jpg' },
        { id: '', code: 'B', title: 'Bài lỗi' },
      ] },
    }), { status: 200 }));
    const upstream = new ZingUpstream(config, fetcher);
    await expect(upstream.fetchChart()).resolves.toEqual([{
      id: '1', code: 'A', title: 'Bài một', artist: 'Ca sĩ',
      albumCover: 'https://img.test/a.jpg', rank: 1,
    }]);
  });

  it('prefers 128 kbps and normalizes protocol-relative sources', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0, data: { source: { '128': '//stream.test/song.mp3' } },
    }), { status: 200 }));
    const upstream = new ZingUpstream(config, fetcher);
    await expect(upstream.fetchSource('ABC')).resolves.toBe('https://stream.test/song.mp3');
    expect(String(fetcher.mock.calls[0]?.[0])).toContain('key=ABC');
  });

  it('rejects non-HTTPS media schemes', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0, data: { source: { '128': 'javascript:alert(1)' } },
    }), { status: 200 }));
    const upstream = new ZingUpstream(config, fetcher);
    await expect(upstream.fetchSource('ABC')).rejects.toThrow('unsafe media URL');
  });
});
