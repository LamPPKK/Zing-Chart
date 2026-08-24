import { describe, expect, it, vi } from 'vitest';
import { ZingUpstream } from '../src/upstream.js';

const config = {
  chartUrl: 'https://chart.example.test/chart',
  searchUrl: 'https://search.example.test/complete?type=artist,song,album&num=25',
  suggestionUrl: 'https://suggest.example.test/v1/web/ac-suggestions',
  sourceUrl: 'https://source.example.test/get-source',
  currentApiBaseUrl: 'https://current.example.test',
  currentApiKey: '',
  currentApiSigningKey: '',
  currentApiVersion: '1.20.1',
};

describe('ZingUpstream', () => {
  it('normalizes chart payload and filters unusable entries', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0,
      data: {
        song: [
          {
            id: '1', code: 'A', title: 'Bài một', artists_names: 'Ca sĩ',
            thumbnail: '//img.test/a.jpg', duration: 218, rank_num: '3',
            rank_status: 'up',
            artists: [{
              id: 'artist-1', name: 'Ca sĩ', alias: 'Ca-Si',
              link: '/nghe-si/Ca-Si', thumbnail: '//img.test/artist.jpg',
            }],
            album: {
              id: 'album-1', title: 'Bài một (Single)',
              link: '/album/bai-mot/album-1.html',
              thumbnail: '//img.test/album.jpg',
            },
          },
          {
            id: '2', code: 'B', name: 'Bài hai', duration: -30,
            rank_num: 200, rank_status: 'down', album: { title: '  ' },
          },
          { id: '', code: 'C', title: 'Bài lỗi' },
        ],
        songHis: {
          min_score: 10,
          max_score: 200,
          data: {
            '1': [
              { time: 1000, hour: '8', counter: 100 },
              { time: 2000, hour: '09', counter: 150 },
              { time: 'bad', hour: '10', counter: 180 },
            ],
          },
        },
      },
    }), { status: 200 }));
    const upstream = new ZingUpstream(config, fetcher);
    await expect(upstream.fetchChart()).resolves.toEqual({
      songs: [{
        id: '1', code: 'A', title: 'Bài một', artist: 'Ca sĩ',
        artists: [{
          id: 'artist-1', name: 'Ca sĩ', aliasName: 'Ca-Si',
          avatar: 'https://img.test/artist.jpg',
          externalUrl: 'https://current.example.test/nghe-si/Ca-Si',
        }],
        albumCover: 'https://img.test/a.jpg', albumTitle: 'Bài một (Single)',
        album: {
          id: 'album-1', title: 'Bài một (Single)', artist: 'Ca sĩ',
          thumbnail: 'https://img.test/album.jpg', kind: 'album',
          externalUrl:
            'https://current.example.test/album/bai-mot/album-1.html',
        },
        durationSeconds: 218, rank: 1, rankChange: 3,
      }, {
        id: '2', code: 'B', title: 'Bài hai', artist: '', albumCover: '',
        artists: [],
        albumTitle: '', durationSeconds: 0, rank: 2, rankChange: -100,
      }],
      series: {
        '1': [
          { time: 1000, hour: '08', counter: 100 },
          { time: 2000, hour: '09', counter: 150 },
        ],
      },
      minScore: 10,
      maxScore: 200,
      updatedAt: 2000,
    });
  });

  it('normalizes and signs the new-release chart', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0,
      timestamp: 1_787_248_103,
      data: {
        title: 'BXH Nhạc Mới',
        items: [
          {
            encodeId: 'Z9WE0E96',
            title: 'Thiên Đường Với Người Thương',
            artistsNames: 'Phương Mỹ Chi, DTAP',
            artists: [{
              id: 'PHUONGMYCHI',
              name: 'Phương Mỹ Chi',
              alias: 'Phuong-My-Chi',
              link: '/nghe-si/Phuong-My-Chi',
              thumbnail: '//image.example.test/phuong-my-chi.jpg',
            }],
            thumbnailM: '//image.example.test/release.jpg',
            duration: 218,
            link: '/bai-hat/thien-duong/Z9WE0E96.html',
            streamingStatus: 1,
            rakingStatus: 3,
            releasedAt: 1_787_200_000,
            album: {
              encodeId: 'RELEASEALBUM1',
              title: 'Thiên Đường Với Người Thương (Single)',
              artistsNames: 'Phương Mỹ Chi, DTAP',
              link: '/album/thien-duong/RELEASEALBUM1.html',
              thumbnail: '//image.example.test/release-album.jpg',
            },
          },
          {
            encodeId: 'LOCKED',
            title: 'Bài hát giới hạn',
            streamingStatus: 2,
          },
        ],
      },
    }), { status: 200 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher, () => 1_787_248_200_000);

    await expect(upstream.fetchNewReleases()).resolves.toEqual({
      title: 'BXH Nhạc Mới',
      updatedAt: 1_787_248_103_000,
      catalogPlaybackEnabled: true,
      songs: [
        {
          id: 'Z9WE0E96',
          code: 'Z9WE0E96',
          title: 'Thiên Đường Với Người Thương',
          artist: 'Phương Mỹ Chi, DTAP',
          artists: [{
            id: 'PHUONGMYCHI',
            name: 'Phương Mỹ Chi',
            aliasName: 'Phuong-My-Chi',
            avatar: 'https://image.example.test/phuong-my-chi.jpg',
            externalUrl: 'https://current.example.test/nghe-si/Phuong-My-Chi',
          }],
          albumCover: 'https://image.example.test/release.jpg',
          albumTitle: 'Thiên Đường Với Người Thương (Single)',
          album: {
            id: 'RELEASEALBUM1',
            title: 'Thiên Đường Với Người Thương (Single)',
            artist: 'Phương Mỹ Chi, DTAP',
            thumbnail: 'https://image.example.test/release-album.jpg',
            kind: 'album',
            externalUrl:
              'https://current.example.test/album/thien-duong/RELEASEALBUM1.html',
          },
          durationSeconds: 218,
          externalUrl:
            'https://current.example.test/bai-hat/thien-duong/Z9WE0E96.html',
          rank: 1,
          rankChange: 3,
          releasedAt: 1_787_200_000,
          playable: true,
        },
        {
          id: 'LOCKED',
          code: 'LOCKED',
          title: 'Bài hát giới hạn',
          artist: '',
          albumCover: '',
          albumTitle: '',
          durationSeconds: 0,
          externalUrl: 'https://current.example.test/link/song/LOCKED',
          rank: 2,
          rankChange: 0,
          releasedAt: 0,
          playable: false,
        },
      ],
    });
    const signedUrl = new URL(String(fetcher.mock.calls[0]?.[0]));
    expect(signedUrl.pathname).toBe('/api/v2/page/get/newrelease-chart');
    expect(signedUrl.searchParams.get('apiKey')).toBe(
      'authorized-test-api-key',
    );
    expect(fetcher.mock.calls[0]?.[1]?.redirect).toBe('error');
  });

  it('fails before fetching new releases without authorized credentials', async () => {
    const fetcher = vi.fn();
    const upstream = new ZingUpstream(config, fetcher);
    await expect(upstream.fetchNewReleases()).rejects.toThrow(
      'not configured',
    );
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('normalizes and signs a regional weekly chart fail-closed', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0,
      timestamp: 1_787_248_103,
      data: {
        week: 33,
        year: 2026,
        latestWeek: 33,
        startDate: '10/08',
        endDate: '16/08',
        items: [
          {
            encodeId: 'WEEKLY1',
            title: 'Bài hát tuần',
            artistsNames: 'Nghệ sĩ tuần',
            artists: [{
              id: 'WEEKLYARTIST1',
              name: 'Nghệ sĩ tuần',
              alias: 'Nghe-Si-Tuan',
              link: '/nghe-si/Nghe-Si-Tuan',
              thumbnail: '//image.example.test/weekly-artist.jpg',
            }],
            thumbnailM: '//image.example.test/weekly.jpg',
            duration: 225,
            link: '/bai-hat/bai-hat-tuan/WEEKLY1.html',
            streamingStatus: 1,
            weeklyRanking: 1,
            rakingStatus: 2,
            score: 2526,
            album: {
              encodeId: 'WEEKLYALBUM1',
              title: 'Album tuần',
              artistsNames: 'Nghệ sĩ tuần',
              link: '/album/album-tuan/WEEKLYALBUM1.html',
              thumbnail: '//image.example.test/weekly-album.jpg',
            },
          },
          {
            encodeId: 'LOCKED',
            title: 'Bài giới hạn',
            streamingStatus: 2,
            weeklyRanking: 2,
          },
          {
            encodeId: 'PRIVATE',
            title: 'Bài riêng tư',
            streamingStatus: 1,
            isPrivate: true,
          },
        ],
      },
    }), { status: 200 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher, () => 1_787_248_200_000);

    await expect(upstream.fetchWeeklyChart('vietnam', 33, 2026)).resolves.toEqual({
      region: 'vietnam',
      title: 'Bảng Xếp Hạng Tuần',
      week: 33,
      year: 2026,
      latestWeek: 33,
      startDate: '10/08',
      endDate: '16/08',
      updatedAt: 1_787_248_103_000,
      catalogPlaybackEnabled: true,
      songs: [
        {
          id: 'WEEKLY1',
          code: 'WEEKLY1',
          title: 'Bài hát tuần',
          artist: 'Nghệ sĩ tuần',
          artists: [{
            id: 'WEEKLYARTIST1',
            name: 'Nghệ sĩ tuần',
            aliasName: 'Nghe-Si-Tuan',
            avatar: 'https://image.example.test/weekly-artist.jpg',
            externalUrl: 'https://current.example.test/nghe-si/Nghe-Si-Tuan',
          }],
          albumCover: 'https://image.example.test/weekly.jpg',
          album: {
            id: 'WEEKLYALBUM1',
            title: 'Album tuần',
            artist: 'Nghệ sĩ tuần',
            thumbnail: 'https://image.example.test/weekly-album.jpg',
            kind: 'album',
            externalUrl:
              'https://current.example.test/album/album-tuan/WEEKLYALBUM1.html',
          },
          durationSeconds: 225,
          externalUrl:
            'https://current.example.test/bai-hat/bai-hat-tuan/WEEKLY1.html',
          playable: true,
          albumTitle: 'Album tuần',
          rank: 1,
          rankChange: 2,
          score: 2526,
        },
        {
          id: 'LOCKED',
          code: 'LOCKED',
          title: 'Bài giới hạn',
          artist: '',
          albumCover: '',
          durationSeconds: 0,
          externalUrl: 'https://current.example.test/link/song/LOCKED',
          playable: false,
          albumTitle: '',
          rank: 2,
          rankChange: 0,
          score: 0,
        },
      ],
    });

    const signedUrl = new URL(String(fetcher.mock.calls[0]?.[0]));
    expect(signedUrl.pathname).toBe('/api/v2/page/get/week-chart');
    expect(signedUrl.searchParams.get('id')).toBe('IWZ9Z08I');
    expect(signedUrl.searchParams.get('week')).toBe('33');
    expect(signedUrl.searchParams.get('year')).toBe('2026');
    expect(signedUrl.searchParams.get('apiKey')).toBe(
      'authorized-test-api-key',
    );
    expect(fetcher.mock.calls[0]?.[1]?.redirect).toBe('error');
  });

  it('fails before fetching weekly charts without authorized credentials', async () => {
    const fetcher = vi.fn();
    const upstream = new ZingUpstream(config, fetcher);
    await expect(upstream.fetchWeeklyChart('korea')).rejects.toThrow(
      'not configured',
    );
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('signs and normalizes official song detail metadata', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0,
      data: {
        encodeId: 'SONG1',
        title: 'Nơi Này Có Anh',
        artistsNames: 'Sơn Tùng M-TP',
        artists: [
          {
            id: 'ARTIST1',
            name: 'Sơn Tùng M-TP',
            alias: 'Son-Tung-M-TP',
            thumbnailM: '//image.example.test/artist.jpg',
          },
        ],
        thumbnailM: '//image.example.test/song.jpg',
        link: '/bai-hat/noi-nay-co-anh/SONG1.html',
        duration: 262,
        releaseDate: 1_486_918_800,
        distributor: 'VIVI ENM',
        streamingStatus: 1,
        hasLyric: true,
        like: 4_004_063,
        listen: 98_765_432,
        comment: 270,
        genres: [
          { id: 'GENRE1', name: 'Việt Nam' },
          { id: 'GENRE2', name: 'V-Pop' },
          { id: 'GENRE2', name: 'V-Pop' },
        ],
        composers: [
          {
            id: 'ARTIST1',
            name: 'Sơn Tùng M-TP',
            alias: 'Son-Tung-M-TP',
          },
        ],
        album: {
          encodeId: 'ALBUM1',
          title: 'Nơi Này Có Anh (Single)',
          artistsNames: 'Sơn Tùng M-TP',
          thumbnailM: '//image.example.test/album.jpg',
          link: '/album/noi-nay-co-anh/ALBUM1.html',
        },
        mvlink: '/video-clip/noi-nay-co-anh/SONG1.html',
      },
    }), { status: 200 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher, () => 1_787_248_200_000);

    await expect(upstream.fetchSongDetail('SONG1')).resolves.toEqual({
      song: {
        id: 'SONG1',
        code: 'SONG1',
        title: 'Nơi Này Có Anh',
        artist: 'Sơn Tùng M-TP',
        albumCover: 'https://image.example.test/song.jpg',
        durationSeconds: 262,
        externalUrl:
          'https://current.example.test/bai-hat/noi-nay-co-anh/SONG1.html',
        playable: true,
        hasLyrics: true,
      },
      artists: [
        {
          id: 'ARTIST1',
          name: 'Sơn Tùng M-TP',
          aliasName: 'Son-Tung-M-TP',
          avatar: 'https://image.example.test/artist.jpg',
          externalUrl:
            'https://current.example.test/nghe-si/Son-Tung-M-TP',
        },
      ],
      album: {
        id: 'ALBUM1',
        title: 'Nơi Này Có Anh (Single)',
        artist: 'Sơn Tùng M-TP',
        thumbnail: 'https://image.example.test/album.jpg',
        kind: 'album',
        externalUrl:
          'https://current.example.test/album/noi-nay-co-anh/ALBUM1.html',
      },
      releasedAt: 1_486_918_800_000,
      distributor: 'VIVI ENM',
      genres: ['Việt Nam', 'V-Pop'],
      composers: [
        {
          id: 'ARTIST1',
          name: 'Sơn Tùng M-TP',
          aliasName: 'Son-Tung-M-TP',
          avatar: '',
          externalUrl:
            'https://current.example.test/nghe-si/Son-Tung-M-TP',
        },
      ],
      listenCount: 98_765_432,
      likeCount: 4_004_063,
      commentCount: 270,
      mv: {
        id: 'SONG1',
        title: 'Nơi Này Có Anh',
        artist: 'Sơn Tùng M-TP',
        artists: [{
          id: 'ARTIST1',
          name: 'Sơn Tùng M-TP',
          aliasName: 'Son-Tung-M-TP',
          avatar: 'https://image.example.test/artist.jpg',
          externalUrl:
            'https://current.example.test/nghe-si/Son-Tung-M-TP',
        }],
        thumbnail: 'https://image.example.test/song.jpg',
        durationSeconds: 262,
        externalUrl:
          'https://current.example.test/video-clip/noi-nay-co-anh/SONG1.html',
      },
      catalogPlaybackEnabled: true,
    });

    const signedUrl = new URL(String(fetcher.mock.calls[0]?.[0]));
    expect(signedUrl.pathname).toBe('/api/v2/page/get/song');
    expect(signedUrl.searchParams.get('id')).toBe('SONG1');
    expect(signedUrl.searchParams.get('apiKey')).toBe(
      'authorized-test-api-key',
    );
    expect(fetcher.mock.calls[0]?.[1]?.redirect).toBe('error');
  });

  it('fails closed for song detail without credentials or a matching id', async () => {
    const noCredentialsFetcher = vi.fn();
    const noCredentials = new ZingUpstream(config, noCredentialsFetcher);
    await expect(noCredentials.fetchSongDetail('SONG1')).rejects.toThrow(
      'not configured',
    );
    expect(noCredentialsFetcher).not.toHaveBeenCalled();

    const mismatchFetcher = vi.fn().mockResolvedValue(new Response(
      JSON.stringify({ data: { encodeId: 'OTHER', title: 'Sai bài hát' } }),
      { status: 200 },
    ));
    const configured = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, mismatchFetcher);
    await expect(configured.fetchSongDetail('SONG1')).rejects.toThrow(
      'does not match',
    );
  });

  it('normalizes and signs synchronized lyrics', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0,
      data: {
        sentences: [
          {
            words: [
              { startTime: 1300, endTime: 1800, data: 'Một' },
              { startTime: 1800, endTime: 2400, data: 'ngày,' },
            ],
          },
          {
            words: [
              { startTime: 2800, endTime: 3300, data: 'mình' },
              { startTime: 3300, endTime: 3900, data: 'gặp nhau' },
            ],
          },
          { words: [{ startTime: -1, endTime: 0, data: 'Lỗi' }] },
        ],
      },
    }), { status: 200 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher, () => 1_787_248_200_000);

    await expect(upstream.fetchLyrics('SONG1')).resolves.toEqual({
      songId: 'SONG1',
      synced: true,
      lines: [
        {
          startTimeMs: 1300,
          endTimeMs: 2400,
          text: 'Một ngày,',
          words: [
            { startTimeMs: 1300, endTimeMs: 1800, text: 'Một' },
            { startTimeMs: 1800, endTimeMs: 2400, text: 'ngày,' },
          ],
        },
        {
          startTimeMs: 2800,
          endTimeMs: 3900,
          text: 'mình gặp nhau',
          words: [
            { startTimeMs: 2800, endTimeMs: 3300, text: 'mình' },
            { startTimeMs: 3300, endTimeMs: 3900, text: 'gặp nhau' },
          ],
        },
      ],
    });
    const signedUrl = new URL(String(fetcher.mock.calls[0]?.[0]));
    expect(signedUrl.pathname).toBe('/api/v2/lyric/get/lyric');
    expect(signedUrl.searchParams.get('id')).toBe('SONG1');
    expect(signedUrl.searchParams.get('apiKey')).toBe(
      'authorized-test-api-key',
    );
    expect(fetcher.mock.calls[0]?.[1]?.redirect).toBe('error');
  });

  it('falls back to normalized plain lyrics and fails closed without credentials', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0,
      data: { lyric: ' Dòng một\r\n\r\nDòng hai! ' },
    }), { status: 200 }));
    const authorized = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher);
    await expect(authorized.fetchLyrics('SONG1')).resolves.toEqual({
      songId: 'SONG1',
      synced: false,
      lines: [
        { startTimeMs: 0, endTimeMs: 0, text: 'Dòng một' },
        { startTimeMs: 0, endTimeMs: 0, text: 'Dòng hai!' },
      ],
    });

    const unconfiguredFetcher = vi.fn();
    const unconfigured = new ZingUpstream(config, unconfiguredFetcher);
    await expect(unconfigured.fetchLyrics('SONG1')).rejects.toThrow(
      'not configured',
    );
    expect(unconfiguredFetcher).not.toHaveBeenCalled();
  });

  it('fetches and parses only trusted bounded LRC files', async () => {
    const fetcher = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({
        err: 0,
        data: {
          file: 'https://static.current.example.test/lyrics/SONG1.lrc',
        },
      }), { status: 200 }))
      .mockResolvedValueOnce(new Response(
        '[offset:100]\n[00:01.00]Dòng một\n[00:03.250][00:07.50]Dòng lặp',
        { status: 200 },
      ));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher);

    await expect(upstream.fetchLyrics('SONG1')).resolves.toEqual({
      songId: 'SONG1',
      synced: true,
      lines: [
        { startTimeMs: 1100, endTimeMs: 3349, text: 'Dòng một' },
        { startTimeMs: 3350, endTimeMs: 7599, text: 'Dòng lặp' },
        { startTimeMs: 7600, endTimeMs: 15600, text: 'Dòng lặp' },
      ],
    });
    expect(String(fetcher.mock.calls[1]?.[0])).toBe(
      'https://static.current.example.test/lyrics/SONG1.lrc',
    );
    expect(fetcher.mock.calls[1]?.[1]).toMatchObject({
      redirect: 'manual',
      headers: { accept: 'text/plain,text/*;q=0.9' },
    });
  });

  it('does not request an untrusted lyric file and keeps inline fallback', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0,
      data: {
        file: 'http://169.254.169.254/latest/meta-data',
        lyric: 'Lời dự phòng',
      },
    }), { status: 200 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher);

    await expect(upstream.fetchLyrics('SONG1')).resolves.toEqual({
      songId: 'SONG1',
      synced: false,
      lines: [{ startTimeMs: 0, endTimeMs: 0, text: 'Lời dự phòng' }],
    });
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('does not follow a lyric redirect outside the trusted host allowlist', async () => {
    const fetcher = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({
        err: 0,
        data: {
          file: 'https://static.current.example.test/lyrics/SONG1.lrc',
          lyric: 'Lời dự phòng',
        },
      }), { status: 200 }))
      .mockResolvedValueOnce(new Response(null, {
        status: 302,
        headers: { location: 'https://attacker.example/lyrics.lrc' },
      }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher);

    await expect(upstream.fetchLyrics('SONG1')).resolves.toMatchObject({
      synced: false,
      lines: [{ text: 'Lời dự phòng' }],
    });
    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(fetcher.mock.calls[1]?.[1]?.redirect).toBe('manual');
  });

  it('cancels an oversized lyric file and returns an empty safe result', async () => {
    const cancel = vi.fn();
    const body = new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(new Uint8Array(512_001));
      },
      cancel,
    });
    const fetcher = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({
        err: 0,
        data: {
          file: 'https://static.current.example.test/lyrics/SONG1.lrc',
        },
      }), { status: 200 }))
      .mockResolvedValueOnce(new Response(body, { status: 200 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher);

    await expect(upstream.fetchLyrics('SONG1')).resolves.toEqual({
      songId: 'SONG1',
      synced: false,
      lines: [],
    });
    expect(cancel).toHaveBeenCalledTimes(1);
  });

  it('signs and normalizes playable song-radio recommendations', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0,
      data: {
        items: [
          {
            encodeId: 'RADIO1',
            title: 'Bài radio đầu tiên',
            artistsNames: 'Nghệ sĩ A',
            thumbnailM: '//image.example.test/radio-1.jpg',
            duration: 231,
            link: '/bai-hat/radio-1/RADIO1.html',
            streamingStatus: 1,
          },
          {
            encodeId: 'LOCKED',
            title: 'Bài giới hạn',
            streamingStatus: 2,
          },
          {
            encodeId: 'SEED1',
            title: 'Bài gốc bị lặp',
            streamingStatus: 1,
          },
          {
            encodeId: 'RADIO1',
            title: 'Bản trùng',
            streamingStatus: 1,
          },
          {
            encodeId: 'PRIVATE',
            title: 'Bài riêng tư',
            streamingStatus: 1,
            isPrivate: true,
          },
        ],
      },
    }), { status: 200 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher, () => 1_787_248_200_000);

    await expect(upstream.fetchSongRadio('SEED1')).resolves.toEqual({
      seedId: 'SEED1',
      catalogPlaybackEnabled: true,
      songs: [{
        id: 'RADIO1',
        code: 'RADIO1',
        title: 'Bài radio đầu tiên',
        artist: 'Nghệ sĩ A',
        albumCover: 'https://image.example.test/radio-1.jpg',
        durationSeconds: 231,
        externalUrl: 'https://current.example.test/bai-hat/radio-1/RADIO1.html',
        playable: true,
      }],
    });
    const signedUrl = new URL(String(fetcher.mock.calls[0]?.[0]));
    expect(signedUrl.pathname).toBe('/api/v2/recommend/get/songs');
    expect(signedUrl.searchParams.get('id')).toBe('SEED1');
    expect(signedUrl.searchParams.get('count')).toBe('30');
    expect(signedUrl.searchParams.get('sig')).toMatch(/^[a-f0-9]{128}$/);
    expect(fetcher.mock.calls[0]?.[1]?.redirect).toBe('error');
  });

  it('fails before fetching song radio without authorized credentials', async () => {
    const fetcher = vi.fn();
    const upstream = new ZingUpstream(config, fetcher);
    await expect(upstream.fetchSongRadio('SEED1')).rejects.toThrow(
      'not configured',
    );
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('signs and normalizes active live-radio rooms without exposing streams', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0,
      timestamp: 1_787_248_103,
      data: {
        items: [
          {
            sectionType: 'livestream',
            items: [
              {
                id: 'ROOM1',
                encodeId: 'ROOM1',
                title: 'V-POP',
                description: 'Nhạc Việt thời nay',
                thumbnailM: '//image.example.test/live.jpg',
                streaming: 'https://radio.stream.example.test/live/index.m3u8',
                status: 2,
                activeUsers: 254,
                host: {
                  name: 'Zing MP3',
                  thumbnail: '//image.example.test/host.jpg',
                },
                program: {
                  encodeId: 'PROGRAM1',
                  title: 'Yêu Cứ Để Đó',
                  thumbnailH: '//image.example.test/program.jpg',
                  description: 'Nhạc trẻ được yêu thích',
                  startTime: 1_787_248_000,
                  endTime: 1_787_251_600,
                },
              },
              {
                encodeId: 'OFFLINE',
                title: 'Đã dừng',
                streaming: 'https://radio.stream.example.test/offline.m3u8',
                status: 1,
              },
              {
                encodeId: 'UNSAFE',
                title: 'Không an toàn',
                streaming: 'https://attacker.example/live.m3u8',
                status: 2,
              },
            ],
          },
          { sectionType: 'Radio_Schedule', items: [] },
        ],
      },
    }), { status: 200 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
      streamHosts: ['stream.example.test'],
    }, fetcher, () => 1_787_248_200_000);

    const snapshot = await upstream.fetchLiveRadio();
    expect(snapshot).toEqual({
      updatedAt: 1_787_248_103_000,
      rooms: [{
        id: 'ROOM1',
        title: 'V-POP',
        description: 'Nhạc Việt thời nay',
        thumbnail: 'https://image.example.test/live.jpg',
        listenerCount: 254,
        hostName: 'Zing MP3',
        hostThumbnail: 'https://image.example.test/host.jpg',
        program: {
          id: 'PROGRAM1',
          title: 'Yêu Cứ Để Đó',
          thumbnail: 'https://image.example.test/program.jpg',
          description: 'Nhạc trẻ được yêu thích',
          startTime: 1_787_248_000_000,
          endTime: 1_787_251_600_000,
        },
      }],
    });
    expect(JSON.stringify(snapshot)).not.toContain('index.m3u8');
    await expect(upstream.resolveLiveRadioStream('ROOM1')).resolves.toBe(
      'https://radio.stream.example.test/live/index.m3u8',
    );
    expect(fetcher).toHaveBeenCalledTimes(1);
    const signedUrl = new URL(String(fetcher.mock.calls[0]?.[0]));
    expect(signedUrl.pathname).toBe('/api/v2/page/get/radio');
    expect(signedUrl.searchParams.get('page')).toBe('1');
    expect(signedUrl.searchParams.get('count')).toBe('18');
    expect(signedUrl.searchParams.get('sig')).toMatch(/^[a-f0-9]{128}$/);
  });

  it('fails before fetching live radio without authorized credentials', async () => {
    const fetcher = vi.fn();
    const upstream = new ZingUpstream(config, fetcher);
    await expect(upstream.fetchLiveRadio()).rejects.toThrow('not configured');
    await expect(upstream.resolveLiveRadioStream('ROOM1')).rejects.toThrow(
      'not configured',
    );
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('normalizes and signs the song and album release catalog', async () => {
    const fetcher = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({
        err: 0,
        timestamp: 1_787_254_004_584,
        data: [
          {
            encodeId: 'SONGVN',
            title: 'Giữa Thiên Hà',
            artistsNames: 'Yeolan, CoolKid',
            artists: [{
              id: 'YEOLAN',
              name: 'Yeolan',
              alias: 'Yeolan',
              thumbnailM: '//image.example.test/yeolan.jpg',
              link: '/nghe-si/Yeolan',
            }],
            album: {
              encodeId: 'ALBUMVN',
              title: 'Giữa Thiên Hà (Single)',
              artistsNames: 'Yeolan, CoolKid',
              thumbnailM: '//image.example.test/album-vn.jpg',
              link: '/album/giua-thien-ha/ALBUMVN.html',
              isAlbum: true,
            },
            thumbnailM: '//image.example.test/song-vn.jpg',
            duration: 174,
            link: '/bai-hat/giua-thien-ha/SONGVN.html',
            releaseDate: 1_787_230_800,
            genreIds: ['IWZ9Z08I', 'IWZ97FCD'],
            streamingStatus: 1,
          },
          {
            encodeId: 'SONGUS',
            title: 'Motivation',
            artistsNames: 'Carly Rae Jepsen',
            thumbnail: '//image.example.test/song-us.jpg',
            duration: 233,
            releaseDate: 1_787_245_200,
            genreIds: ['IWZ9Z08O'],
            streamingStatus: 2,
          },
          {
            encodeId: 'PRIVATE',
            title: 'Private song',
            isPrivate: true,
            streamingStatus: 1,
          },
          {
            encodeId: 'SONGOTHER',
            title: 'A different market',
            thumbnail: '//image.example.test/song-other.jpg',
            genreIds: ['UNRECOGNIZED'],
            streamingStatus: 1,
          },
        ],
      }), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({
        err: 0,
        timestamp: 1_787_254_003,
        data: [
          {
            encodeId: 'ALBUMKR',
            title: 'Edge of Calm',
            artistsNames: 'Tiffany Young',
            thumbnailM: '//image.example.test/album-kr.jpg',
            link: '/album/edge-of-calm/ALBUMKR.html',
            releaseDate: 1_787_158_800,
            genreIds: ['IWZ9Z08W'],
            isAlbum: true,
          },
          {
            encodeId: 'BADLINK',
            title: 'Unsafe album',
            thumbnailM: '//image.example.test/bad.jpg',
            link: 'https://evil.example.test/album/BADLINK.html',
          },
        ],
      }), { status: 200 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher, () => 1_787_254_100_000);

    await expect(upstream.fetchReleaseCatalog()).resolves.toEqual({
      updatedAt: 1_787_254_004_584,
      catalogPlaybackEnabled: true,
      songs: [
        {
          id: 'SONGVN',
          code: 'SONGVN',
          title: 'Giữa Thiên Hà',
          artist: 'Yeolan, CoolKid',
          artists: [{
            id: 'YEOLAN',
            name: 'Yeolan',
            aliasName: 'Yeolan',
            avatar: 'https://image.example.test/yeolan.jpg',
            externalUrl: 'https://current.example.test/nghe-si/Yeolan',
          }],
          albumCover: 'https://image.example.test/song-vn.jpg',
          album: {
            id: 'ALBUMVN',
            title: 'Giữa Thiên Hà (Single)',
            artist: 'Yeolan, CoolKid',
            thumbnail: 'https://image.example.test/album-vn.jpg',
            kind: 'album',
            externalUrl:
              'https://current.example.test/album/giua-thien-ha/ALBUMVN.html',
          },
          durationSeconds: 174,
          externalUrl:
            'https://current.example.test/bai-hat/giua-thien-ha/SONGVN.html',
          playable: true,
          releasedAt: 1_787_230_800,
          region: 'vietnam',
        },
        {
          id: 'SONGUS',
          code: 'SONGUS',
          title: 'Motivation',
          artist: 'Carly Rae Jepsen',
          albumCover: 'https://image.example.test/song-us.jpg',
          durationSeconds: 233,
          externalUrl: 'https://current.example.test/link/song/SONGUS',
          playable: false,
          releasedAt: 1_787_245_200,
          region: 'usuk',
        },
        {
          id: 'SONGOTHER',
          code: 'SONGOTHER',
          title: 'A different market',
          artist: '',
          albumCover: 'https://image.example.test/song-other.jpg',
          durationSeconds: 0,
          externalUrl: 'https://current.example.test/link/song/SONGOTHER',
          playable: true,
          releasedAt: 0,
          region: 'other',
        },
      ],
      albums: [{
        id: 'ALBUMKR',
        title: 'Edge of Calm',
        artist: 'Tiffany Young',
        thumbnail: 'https://image.example.test/album-kr.jpg',
        kind: 'album',
        externalUrl:
          'https://current.example.test/album/edge-of-calm/ALBUMKR.html',
        releasedAt: 1_787_158_800,
        region: 'korea',
      }],
    });
    expect(fetcher).toHaveBeenCalledTimes(2);
    const songUrl = new URL(String(fetcher.mock.calls[0]?.[0]));
    const albumUrl = new URL(String(fetcher.mock.calls[1]?.[0]));
    expect(songUrl.pathname).toBe('/api/v2/chart/get/new-release');
    expect(songUrl.searchParams.get('type')).toBe('song');
    expect(albumUrl.searchParams.get('type')).toBe('album');
    expect(songUrl.searchParams.get('sig')).toMatch(/^[a-f0-9]{128}$/);
    expect(albumUrl.searchParams.get('sig')).toMatch(/^[a-f0-9]{128}$/);
    expect(fetcher.mock.calls[0]?.[1]?.redirect).toBe('error');
    expect(fetcher.mock.calls[1]?.[1]?.redirect).toBe('error');
  });

  it('fails before fetching the release catalog without credentials', async () => {
    const fetcher = vi.fn();
    const upstream = new ZingUpstream(config, fetcher);
    await expect(upstream.fetchReleaseCatalog()).rejects.toThrow(
      'not configured',
    );
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('normalizes and signs an authoritative artist profile', async () => {
    const fetcher = vi.fn().mockResolvedValueOnce(new Response(JSON.stringify({
      err: 0,
      data: {
        id: 'ARTIST1',
        name: 'Sơn Tùng M-TP',
        alias: 'Son-Tung-M-TP',
        thumbnailM: '//image.example.test/artist.jpg',
        cover: '//image.example.test/artist-cover.jpg',
        biography: 'Ca sĩ &amp; nhạc sĩ.<br>Đại diện V-Pop.',
        realname: 'Nguyễn Thanh Tùng',
        national: 'Việt Nam',
        birthday: '05/07/1994',
        totalFollow: 2_655_838,
        awards: [{ title: 'Top artist' }],
        sections: [
          {
            sectionId: 'aSongs',
            sectionType: 'song',
            title: 'Bài hát nổi bật',
            items: [
              {
                encodeId: 'SONG1',
                title: 'Nơi Này Có Anh',
                artistsNames: 'Sơn Tùng M-TP',
                artists: [
                  {
                    id: 'ARTIST1',
                    name: 'Sơn Tùng M-TP',
                    alias: 'Son-Tung-M-TP',
                    thumbnail: '//image.example.test/artist.jpg',
                    link: '/nghe-si/Son-Tung-M-TP',
                  },
                  { id: 'unsafe id', name: 'Sai ID', alias: 'Sai-ID' },
                ],
                album: {
                  encodeId: 'ALBUM1',
                  title: 'Nơi Này Có Anh (Single)',
                  artistsNames: 'Sơn Tùng M-TP',
                  thumbnail: '//image.example.test/album.jpg',
                  link: '/album/noi-nay-co-anh/ALBUM1.html',
                  isAlbum: true,
                },
                thumbnailM: '//image.example.test/song.jpg',
                duration: 260,
                link: '/bai-hat/noi-nay-co-anh/SONG1.html',
                streamingStatus: 1,
              },
              {
                encodeId: 'LOCKED',
                title: 'Bài giới hạn',
                streamingStatus: 2,
              },
              {
                encodeId: 'PRIVATE',
                title: 'Bài riêng tư',
                isPrivate: true,
                streamingStatus: 1,
              },
            ],
          },
          {
            sectionId: 'aSingle',
            sectionType: 'playlist',
            title: 'Single & EP',
            items: [
              {
                encodeId: 'SINGLE1',
                title: 'Chúng Ta Của Tương Lai',
                artistsNames: 'Sơn Tùng M-TP',
                thumbnailM: '//image.example.test/single.jpg',
                link: '/album/chung-ta-cua-tuong-lai/SINGLE1.html',
                isSingle: true,
              },
              {
                encodeId: 'UNSAFE',
                title: 'Không hợp lệ',
                thumbnailM: '//image.example.test/unsafe.jpg',
                link: 'https://evil.example.test/album/UNSAFE.html',
              },
            ],
          },
          {
            sectionId: 'aMV',
            sectionType: 'video',
            title: 'MV',
            items: [
              {
                encodeId: 'MV1',
                title: 'Chúng Ta Của Tương Lai',
                artistsNames: 'Sơn Tùng M-TP',
                thumbnailM: '//image.example.test/mv.jpg',
                duration: 277,
                link: '/video-clip/chung-ta-cua-tuong-lai/MV1.html',
              },
              {
                encodeId: 'MV1',
                title: 'Bản trùng',
                link: '/video-clip/ban-trung/MV1.html',
              },
              {
                encodeId: 'LOCKEDMV',
                title: 'MV giới hạn',
                link: '/video-clip/mv-gioi-han/LOCKEDMV.html',
                streamingStatus: 2,
              },
              {
                encodeId: 'EVILMV',
                title: 'MV không hợp lệ',
                link: 'https://evil.example.test/video-clip/EVILMV.html',
              },
            ],
          },
          {
            sectionId: 'aReArtist',
            sectionType: 'artist',
            items: [
              {
                id: 'ARTIST2',
                name: 'MONO',
                alias: 'MONO-Nguyen-Viet-Hoang',
                thumbnail: '//image.example.test/mono.jpg',
              },
            ],
          },
        ],
      },
    }), { status: 200 })).mockResolvedValueOnce(new Response(JSON.stringify({
      err: 0,
      data: {
        items: [
          {
            encodeId: 'SONG1',
            title: 'Nơi Này Có Anh',
            artistsNames: 'Sơn Tùng M-TP',
            artists: [{
              id: 'ARTIST1',
              name: 'Sơn Tùng M-TP',
              alias: 'Son-Tung-M-TP',
              thumbnail: '//image.example.test/artist.jpg',
              link: '/nghe-si/Son-Tung-M-TP',
            }],
            album: {
              encodeId: 'ALBUM1',
              title: 'Nơi Này Có Anh (Single)',
              artistsNames: 'Sơn Tùng M-TP',
              thumbnail: '//image.example.test/album.jpg',
              link: '/album/noi-nay-co-anh/ALBUM1.html',
              isAlbum: true,
            },
            thumbnailM: '//image.example.test/song.jpg',
            duration: 260,
            link: '/bai-hat/noi-nay-co-anh/SONG1.html',
            streamingStatus: 1,
          },
          {
            encodeId: 'FULLSONG',
            title: 'Hãy Trao Cho Anh',
            artistsNames: 'Sơn Tùng M-TP, Snoop Dogg',
            thumbnailM: '//image.example.test/full-song.jpg',
            duration: 245,
            link: '/bai-hat/hay-trao-cho-anh/FULLSONG.html',
            streamingStatus: 1,
          },
          {
            encodeId: 'LOCKED',
            title: 'Bài giới hạn',
            streamingStatus: 2,
          },
          {
            encodeId: 'PRIVATE',
            title: 'Bài riêng tư',
            isPrivate: true,
            streamingStatus: 1,
          },
        ],
      },
    }), { status: 200 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher, () => 1_787_255_000_000);

    const result = await upstream.fetchArtistDetail('Son-Tung-M-TP');

    expect(result.artist).toEqual({
      id: 'ARTIST1',
      name: 'Sơn Tùng M-TP',
      aliasName: 'Son-Tung-M-TP',
      avatar: 'https://image.example.test/artist.jpg',
      externalUrl: 'https://current.example.test/nghe-si/Son-Tung-M-TP',
      totalFollow: 2_655_838,
    });
    expect(result.cover).toBe('https://image.example.test/artist-cover.jpg');
    expect(result.biography).toBe('Ca sĩ & nhạc sĩ.\nĐại diện V-Pop.');
    expect(result.totalFollow).toBe(2_655_838);
    expect(result.awardCount).toBe(1);
    expect(result.featuredSongs?.map((song) => [song.id, song.playable])).toEqual([
      ['SONG1', true],
      ['LOCKED', false],
    ]);
    expect(result.songs.map((song) => [song.id, song.playable])).toEqual([
      ['SONG1', true],
      ['FULLSONG', true],
      ['LOCKED', false],
    ]);
    expect(result.songs[0]).toMatchObject({
      artists: [{
        id: 'ARTIST1',
        name: 'Sơn Tùng M-TP',
        aliasName: 'Son-Tung-M-TP',
      }],
      album: {
        id: 'ALBUM1',
        title: 'Nơi Này Có Anh (Single)',
        kind: 'album',
      },
    });
    expect(result.videos).toEqual([{
      id: 'MV1',
      title: 'Chúng Ta Của Tương Lai',
      artist: 'Sơn Tùng M-TP',
      thumbnail: 'https://image.example.test/mv.jpg',
      durationSeconds: 277,
      externalUrl:
        'https://current.example.test/video-clip/chung-ta-cua-tuong-lai/MV1.html',
    }]);
    expect(result.collectionSections).toHaveLength(1);
    expect(result.collectionSections[0]?.id).toBe('aSingle-2');
    expect(result.collectionSections[0]?.collections[0]?.id).toBe('SINGLE1');
    expect(result.relatedArtists[0]?.name).toBe('MONO');
    expect(result.catalogPlaybackEnabled).toBe(true);
    const signedUrl = new URL(String(fetcher.mock.calls[0]?.[0]));
    expect(signedUrl.pathname).toBe('/api/v2/page/get/artist');
    expect(signedUrl.searchParams.get('alias')).toBe('Son-Tung-M-TP');
    expect(signedUrl.searchParams.get('sig')).toMatch(/^[a-f0-9]{128}$/);
    expect(fetcher.mock.calls[0]?.[1]?.redirect).toBe('error');
    const allSongsUrl = new URL(String(fetcher.mock.calls[1]?.[0]));
    expect(allSongsUrl.pathname).toBe('/api/v2/song/get/list');
    expect(allSongsUrl.searchParams.get('id')).toBe('ARTIST1');
    expect(allSongsUrl.searchParams.get('type')).toBe('artist');
    expect(allSongsUrl.searchParams.get('page')).toBe('1');
    expect(allSongsUrl.searchParams.get('count')).toBe('50');
    expect(allSongsUrl.searchParams.get('sectionId')).toBe('aSongs');
    expect(allSongsUrl.searchParams.get('sig')).toMatch(/^[a-f0-9]{128}$/);
    expect(fetcher.mock.calls[1]?.[1]?.redirect).toBe('error');
  });

  it('keeps highlighted artist songs when the complete catalog fails', async () => {
    const fetcher = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({
        err: 0,
        data: {
          id: 'ARTIST1',
          name: 'Sơn Tùng M-TP',
          alias: 'Son-Tung-M-TP',
          sections: [{
            sectionId: 'aSongs',
            sectionType: 'song',
            items: [{
              encodeId: 'HIGHLIGHT1',
              title: 'Bài hát nổi bật',
              artistsNames: 'Sơn Tùng M-TP',
              link: '/bai-hat/bai-hat-noi-bat/HIGHLIGHT1.html',
              streamingStatus: 1,
            }],
          }],
        },
      }), { status: 200 }))
      .mockResolvedValueOnce(new Response('Unavailable', { status: 503 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher);

    const result = await upstream.fetchArtistDetail('Son-Tung-M-TP');

    expect(result.songs.map((song) => song.id)).toEqual(['HIGHLIGHT1']);
    expect(result.featuredSongs?.map((song) => song.id)).toEqual([
      'HIGHLIGHT1',
    ]);
    expect(result.songs[0]?.playable).toBe(true);
    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(new URL(String(fetcher.mock.calls[1]?.[0])).pathname).toBe(
      '/api/v2/song/get/list',
    );
  });

  it('accepts an artist profile whose only usable catalog is a public MV', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0,
      data: {
        id: 'ARTIST1',
        name: 'Sơn Tùng M-TP',
        alias: 'Son-Tung-M-TP',
        sections: [{
          sectionType: 'video',
          items: [{
            encodeId: 'MVONLY',
            title: 'MV chính thức',
            artistsNames: 'Sơn Tùng M-TP',
            duration: 240,
            link: '/video-clip/mv-chinh-thuc/MVONLY.html',
            streamingStatus: 1,
          }],
        }],
      },
    }), { status: 200 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher);

    const result = await upstream.fetchArtistDetail('Son-Tung-M-TP');

    expect(result.songs).toEqual([]);
    expect(result.collectionSections).toEqual([]);
    expect(result.videos.map((video) => video.id)).toEqual(['MVONLY']);
  });

  it('fails before fetching artist detail without credentials', async () => {
    const fetcher = vi.fn();
    const upstream = new ZingUpstream(config, fetcher);
    await expect(upstream.fetchArtistDetail('Son-Tung-M-TP')).rejects.toThrow(
      'not configured',
    );
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('normalizes and signs the official discovery categories', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0,
      timestamp: 1_787_249_000,
      data: {
        items: [
          { id: 14, name: ' Thư giãn ', src: '//image.example/relax.jpg' },
          { id: 13, name: 'Làm   việc', src: '//image.example/work.jpg' },
          { id: 14, name: 'Thư giãn mới' },
          { id: 1000, name: 'Sai mã' },
          { id: 15, name: '' },
        ],
      },
    }), { status: 200 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher);

    await expect(upstream.fetchDiscoveryCategories()).resolves.toEqual({
      updatedAt: 1_787_249_000_000,
      items: [
        { id: '14', name: 'Thư giãn' },
        { id: '13', name: 'Làm việc' },
      ],
    });
    const signedUrl = new URL(String(fetcher.mock.calls[0]?.[0]));
    expect(signedUrl.pathname).toBe('/api/v2/page/get/home-category');
    expect(signedUrl.searchParams.get('sig')).toMatch(/^[a-f0-9]{128}$/);
    expect(fetcher.mock.calls[0]?.[1]?.redirect).toBe('error');
  });

  it('normalizes playable songs from the official discovery station', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0,
      timestamp: 1_787_249_100,
      data: {
        items: [
          {
            encodeId: 'SONG1',
            title: 'Bài hát gợi ý',
            artistsNames: 'Nghệ sĩ A',
            artists: [{
              id: 'ARTIST1',
              name: 'Nghệ sĩ A',
              alias: 'Nghe-Si-A',
              thumbnail: '//image.example.test/artist-a.jpg',
              link: '/nghe-si/Nghe-Si-A',
            }],
            album: {
              encodeId: 'ALBUM1',
              title: 'Bài hát gợi ý (Single)',
              artistsNames: 'Nghệ sĩ A',
              thumbnail: '//image.example.test/album-1.jpg',
              link: '/album/bai-hat-goi-y/ALBUM1.html',
              isAlbum: true,
            },
            thumbnailM: '//image.example.test/song-1.jpg',
            duration: 245,
            link: '/bai-hat/bai-hat-goi-y/SONG1.html',
            streamingStatus: 1,
          },
          {
            encodeId: 'LOCKED',
            title: 'Bài bị khóa',
            thumbnail: '//image.example.test/locked.jpg',
            streamingStatus: 2,
          },
          {
            encodeId: 'PRIVATE',
            title: 'Bài riêng tư',
            streamingStatus: 1,
            isPrivate: true,
          },
          {
            encodeId: 'SONG1',
            title: 'Bài trùng',
            streamingStatus: 1,
          },
        ],
      },
    }), { status: 200 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher);

    await expect(upstream.fetchDiscoveryRecommendations()).resolves.toEqual({
      updatedAt: 1_787_249_100_000,
      songs: [{
        id: 'SONG1',
        code: 'SONG1',
        title: 'Bài hát gợi ý',
        artist: 'Nghệ sĩ A',
        artists: [{
          id: 'ARTIST1',
          name: 'Nghệ sĩ A',
          aliasName: 'Nghe-Si-A',
          avatar: 'https://image.example.test/artist-a.jpg',
          externalUrl: 'https://current.example.test/nghe-si/Nghe-Si-A',
        }],
        albumCover: 'https://image.example.test/song-1.jpg',
        album: {
          id: 'ALBUM1',
          title: 'Bài hát gợi ý (Single)',
          artist: 'Nghệ sĩ A',
          thumbnail: 'https://image.example.test/album-1.jpg',
          kind: 'album',
          externalUrl:
            'https://current.example.test/album/bai-hat-goi-y/ALBUM1.html',
        },
        durationSeconds: 245,
        externalUrl:
          'https://current.example.test/bai-hat/bai-hat-goi-y/SONG1.html',
        playable: true,
      }],
      catalogPlaybackEnabled: true,
    });
    const signedUrl = new URL(String(fetcher.mock.calls[0]?.[0]));
    expect(signedUrl.pathname).toBe(
      '/api/v2/song/get/section-song-station',
    );
    expect(signedUrl.searchParams.get('count')).toBe('12');
    expect(signedUrl.searchParams.get('sig')).toMatch(/^[a-f0-9]{128}$/);
    expect(fetcher.mock.calls[0]?.[1]?.redirect).toBe('error');
  });

  it('normalizes and signs discovery quick play, banners, and collections', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0,
      timestamp: 1_787_249_000,
      data: {
        items: [
          {
            sectionType: 'quickPlay',
            items: [{
              id: 'QUICK1',
              title: 'V-Pop Gây Bão',
              description: 'Những ca khúc V-Pop nổi bật.',
              thumbnail: '//image.example.test/quick-play.jpg',
              link: '/album/v-pop-gay-bao/QUICK1.html',
              type: 2,
            }, {
              id: 'UNSAFE',
              title: 'Liên kết không hợp lệ',
              thumbnail: '//image.example.test/unsafe.jpg',
              link: 'https://evil.example/album/UNSAFE.html',
              type: 2,
            }],
          },
          {
            sectionType: 'banner',
            items: [{
              encodeId: 'BANNER1',
              banner: '//image.example.test/banner.jpg',
              link: '/album/noi-bat/BANNER1.html',
              type: 3,
            }],
          },
          {
            sectionType: 'video',
            items: [{
              encodeId: 'MV1',
              title: 'MV Nổi Bật',
              artistsNames: 'Nghệ sĩ Việt',
              thumbnailM: '//image.example.test/mv.jpg',
              duration: 245,
              link: '/video-clip/mv-noi-bat/MV1.html',
              streamingStatus: 1,
            }, {
              encodeId: 'MV_LOCKED',
              title: 'MV bị khóa',
              thumbnail: '//image.example.test/mv-locked.jpg',
              link: '/video-clip/mv-bi-khoa/MV_LOCKED.html',
              streamingStatus: 2,
            }, {
              encodeId: 'MV_UNSAFE',
              title: 'MV không an toàn',
              thumbnail: '//image.example.test/mv-unsafe.jpg',
              link: 'https://evil.example/video-clip/MV_UNSAFE.html',
              streamingStatus: 1,
            }],
          },
          {
            sectionType: 'playlist',
            title: 'Top 100',
            items: [{
              encodeId: 'TOP100',
              title: 'Top 100 Nhạc Trẻ',
              artistsNames: 'Nhiều nghệ sĩ',
              artists: [{
                id: 'ARTIST1',
                name: 'Sơn Tùng M-TP',
                alias: 'Son-Tung-M-TP',
                thumbnail: '//image.example.test/artist.jpg',
                link: '/nghe-si/Son-Tung-M-TP',
              }],
              thumbnailM: '//image.example.test/top100.jpg',
              link: '/album/top-100/TOP100.html',
              sortDescription: 'Các ca khúc được nghe nhiều nhất.',
              isAlbum: false,
            }],
          },
          {
            sectionType: 'playlist',
            title: 'Album Hot',
            items: [{
              encodeId: 'ALBUM1',
              title: 'Album Mới (EP)',
              artistsNames: 'Nghệ sĩ Việt',
              thumbnail: '//image.example.test/album.jpg',
              link: '/album/album-moi/ALBUM1.html',
              isAlbum: true,
            }],
          },
          { sectionType: 'adBanner', items: [] },
        ],
      },
    }), { status: 200 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher);

    await expect(upstream.fetchDiscovery('14')).resolves.toEqual({
      categoryId: '14',
      updatedAt: 1_787_249_000_000,
      quickPlay: [{
        id: 'QUICK1',
        title: 'V-Pop Gây Bão',
        artist: '',
        thumbnail: 'https://image.example.test/quick-play.jpg',
        kind: 'playlist',
        externalUrl:
          'https://current.example.test/album/v-pop-gay-bao/QUICK1.html',
        description: 'Những ca khúc V-Pop nổi bật.',
      }],
      banners: [{
        id: 'BANNER1',
        image: 'https://image.example.test/banner.jpg',
        collection: {
          id: 'BANNER1',
          title: 'Nổi bật hôm nay',
          artist: '',
          thumbnail: 'https://image.example.test/banner.jpg',
          kind: 'album',
          externalUrl:
            'https://current.example.test/album/noi-bat/BANNER1.html',
        },
      }],
      videos: [{
        id: 'MV1',
        title: 'MV Nổi Bật',
        artist: 'Nghệ sĩ Việt',
        thumbnail: 'https://image.example.test/mv.jpg',
        durationSeconds: 245,
        externalUrl:
          'https://current.example.test/video-clip/mv-noi-bat/MV1.html',
      }],
      sections: [
        {
          id: 'playlist-4',
          title: 'Top 100',
          collections: [{
            id: 'TOP100',
            title: 'Top 100 Nhạc Trẻ',
            artist: 'Nhiều nghệ sĩ',
            artists: [{
              id: 'ARTIST1',
              name: 'Sơn Tùng M-TP',
              aliasName: 'Son-Tung-M-TP',
              avatar: 'https://image.example.test/artist.jpg',
              externalUrl:
                'https://current.example.test/nghe-si/Son-Tung-M-TP',
            }],
            thumbnail: 'https://image.example.test/top100.jpg',
            kind: 'playlist',
            externalUrl:
              'https://current.example.test/album/top-100/TOP100.html',
            description: 'Các ca khúc được nghe nhiều nhất.',
          }],
        },
        {
          id: 'playlist-5',
          title: 'Album Hot',
          collections: [{
            id: 'ALBUM1',
            title: 'Album Mới (EP)',
            artist: 'Nghệ sĩ Việt',
            thumbnail: 'https://image.example.test/album.jpg',
            kind: 'album',
            externalUrl:
              'https://current.example.test/album/album-moi/ALBUM1.html',
            description: '',
          }],
        },
      ],
    });
    const signedUrl = new URL(String(fetcher.mock.calls[0]?.[0]));
    expect(signedUrl.pathname).toBe('/api/v2/page/get/home');
    expect(signedUrl.searchParams.get('page')).toBe('1');
    expect(signedUrl.searchParams.get('count')).toBe('30');
    expect(signedUrl.searchParams.get('categoryId')).toBe('14');
    expect(signedUrl.searchParams.get('apiKey')).toBe(
      'authorized-test-api-key',
    );
  });

  it('fails before fetching discovery without authorized credentials', async () => {
    const fetcher = vi.fn();
    const upstream = new ZingUpstream(config, fetcher);
    await expect(upstream.fetchDiscovery()).rejects.toThrow('not configured');
    await expect(upstream.fetchDiscoveryCategories()).rejects.toThrow(
      'not configured',
    );
    await expect(upstream.fetchDiscoveryRecommendations()).rejects.toThrow(
      'not configured',
    );
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('normalizes signed hub home, hub detail, and Top 100 catalogs', async () => {
    const collection = {
      encodeId: 'PLAYLIST1',
      title: 'Nhạc Gối Đầu Giường',
      artistsNames: 'Nhiều nghệ sĩ',
      thumbnailM: '//image.example.test/playlist.jpg',
      link: '/album/nhac-goi-dau-giuong/PLAYLIST1.html',
      sortDescription: 'Nhạc dịu nhẹ trước khi ngủ.',
      isAlbum: false,
    };
    const fetcher = vi.fn().mockImplementation((input: string | URL) => {
      const endpoint = new URL(String(input));
      if (endpoint.pathname.endsWith('/hub-home')) {
        return Promise.resolve(new Response(JSON.stringify({
          err: 0,
          timestamp: 1_787_250_000,
          data: {
            featured: {
              title: 'Nổi bật',
              items: [{
                encodeId: 'HUBTOP',
                title: 'Top 100',
                description: 'Nghe nhiều nhất hiện tại.',
                cover: '//image.example.test/top.jpg',
                link: '/hub/top-100/HUBTOP.html',
              }],
            },
            nations: [{
              encodeId: 'HUBVN',
              title: 'Nhạc Việt',
              thumbnail: '//image.example.test/vn.jpg',
              link: '/hub/nhac-viet/HUBVN.html',
            }],
            topic: [{
              encodeId: 'HUBSLEEP',
              title: 'Ngủ Ngon',
              cover: '//image.example.test/sleep.jpg',
              link: '/hub/ngu-ngon/HUBSLEEP.html',
              playlists: [collection],
            }],
            genre: [{
              encodeId: 'HUBEDM',
              title: 'Dance/Electronic',
              cover: '//image.example.test/edm.jpg',
              link: '/hub/edm/HUBEDM.html',
              playlists: [collection],
            }],
          },
        }), { status: 200 }));
      }
      if (endpoint.pathname.endsWith('/hub-detail')) {
        return Promise.resolve(new Response(JSON.stringify({
          err: 0,
          data: {
            encodeId: 'HUBSLEEP',
            title: 'Ngủ Ngon',
            cover: '//image.example.test/sleep.jpg',
            link: '/hub/ngu-ngon/HUBSLEEP.html',
            sections: [{
              sectionType: 'playlist',
              sectionId: 'featured',
              title: 'Nổi bật',
              items: [collection],
            }],
          },
        }), { status: 200 }));
      }
      return Promise.resolve(new Response(JSON.stringify({
        err: 0,
        timestamp: 1_787_250_100,
        data: [{
          sectionType: 'playlist',
          sectionId: 'vietnam',
          genre: { name: 'Nhạc Việt Nam' },
          items: [collection],
        }],
      }), { status: 200 }));
    });
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher, () => 1_787_250_200_000);

    const home = await upstream.fetchHubHome();
    const detail = await upstream.fetchHubDetail('HUBSLEEP');
    const top100 = await upstream.fetchTop100();

    expect(home.updatedAt).toBe(1_787_250_000_000);
    expect(home.featured[0]).toMatchObject({
      id: 'HUBTOP',
      title: 'Top 100',
      externalUrl: 'https://current.example.test/hub/top-100/HUBTOP.html',
    });
    expect(home.topics[0]?.collections[0]).toMatchObject({
      id: 'PLAYLIST1',
      title: 'Nhạc Gối Đầu Giường',
      description: 'Nhạc dịu nhẹ trước khi ngủ.',
    });
    expect(home.genres[0]?.title).toBe('Dance/Electronic');
    expect(detail).toMatchObject({
      id: 'HUBSLEEP',
      title: 'Ngủ Ngon',
      sections: [{
        id: 'featured',
        title: 'Nổi bật',
        collections: [{ id: 'PLAYLIST1' }],
      }],
    });
    expect(top100).toMatchObject({
      updatedAt: 1_787_250_100_000,
      sections: [{
        id: 'vietnam',
        title: 'Nhạc Việt Nam',
        collections: [{ id: 'PLAYLIST1' }],
      }],
    });
    const urls = fetcher.mock.calls.map((call) => new URL(String(call[0])));
    expect(urls.map((url) => url.pathname)).toEqual([
      '/api/v2/page/get/hub-home',
      '/api/v2/page/get/hub-detail',
      '/api/v2/page/get/top-100',
    ]);
    expect(urls[1]?.searchParams.get('id')).toBe('HUBSLEEP');
    expect(urls.every((url) => url.searchParams.has('sig'))).toBe(true);
  });

  it('fails all hub catalogs before fetch without authorized credentials', async () => {
    const fetcher = vi.fn();
    const upstream = new ZingUpstream(config, fetcher);
    await expect(upstream.fetchHubHome()).rejects.toThrow('not configured');
    await expect(upstream.fetchHubDetail('HUB')).rejects.toThrow(
      'not configured',
    );
    await expect(upstream.fetchTop100()).rejects.toThrow('not configured');
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('uses the highest available bitrate in auto mode', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0,
      data: {
        source: {
          '128': '//stream.test/song-128.mp3',
          '320': '//stream.test/song-320.mp3',
        },
      },
    }), { status: 200 }));
    const upstream = new ZingUpstream(config, fetcher);
    await expect(upstream.fetchSource('ABC')).resolves.toBe(
      'https://stream.test/song-320.mp3',
    );
    expect(String(fetcher.mock.calls[0]?.[0])).toContain('key=ABC');
  });

  it('checks the signed current API for 320 before falling back to legacy 128', async () => {
    const fetcher = vi
      .fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({
        err: 0,
        data: { source: { '128': '//stream.test/song-128.mp3' } },
      }), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({
        err: 0,
        data: { '320': '//stream.test/song-320-current.mp3' },
      }), { status: 200 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher);

    await expect(upstream.fetchSource('ABC')).resolves.toBe(
      'https://stream.test/song-320-current.mp3',
    );
    expect(new URL(String(fetcher.mock.calls[1]?.[0])).pathname).toBe(
      '/api/v2/song/get/streaming',
    );
  });

  it('honors an explicit 128 kbps request and fails closed for missing 320', async () => {
    const fetcher = vi.fn().mockImplementation(async () => new Response(
      JSON.stringify({
        err: 0,
        data: {
          source: { '128': '//stream.test/song-128.mp3', '320': 'VIP' },
        },
      }),
      { status: 200 },
    ));
    const upstream = new ZingUpstream(config, fetcher);

    await expect(upstream.fetchSource('ABC', undefined, '128')).resolves.toBe(
      'https://stream.test/song-128.mp3',
    );
    await expect(upstream.fetchSource('ABC', undefined, '320')).rejects.toThrow(
      'No 320 kbps legacy source was returned',
    );
  });

  it('normalizes public catalog search songs and artists', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      result: true,
      data: [
        { song: [{
          id: 'ZW79ZBE8',
          name: 'Nơi Này Có Anh',
          artist: 'Sơn Tùng M-TP',
          thumb: 'covers/a/song.jpg',
          duration: '262',
          block: 'false',
          streamingStatus: '1',
        }] },
        { artist: [{
          id: 'IWZ97DB0',
          name: 'Sơn Tùng M-TP',
          aliasName: 'Son-Tung-M-TP',
          totalFollow: '2600000',
          thumb: 'avatars/a/artist.jpg',
          block: 'false',
        }] },
        { album: [{
          id: 'ZWZAC9BF',
          name: 'Những Bài Hát Hay Nhất Của Sơn Tùng M-TP',
          artist: 'Sơn Tùng M-TP',
          thumb: 'cover/a/playlist.jpg',
          boolAttribute: '260',
        }] },
      ],
    }), { status: 200 }));
    const upstream = new ZingUpstream(config, fetcher);

    await expect(upstream.fetchSearch('  Sơn Tùng  ')).resolves.toEqual({
      query: 'Sơn Tùng',
      catalogPlaybackEnabled: false,
      songs: [{
        id: 'ZW79ZBE8',
        code: 'ZW79ZBE8',
        title: 'Nơi Này Có Anh',
        artist: 'Sơn Tùng M-TP',
        albumCover:
          'https://photo-resize-zmp3.zmdcdn.me/w240_r1x1_jpeg/covers/a/song.jpg',
        durationSeconds: 262,
        externalUrl: 'https://current.example.test/link/song/ZW79ZBE8',
        playable: false,
        hasLyrics: false,
      }],
      artists: [{
        id: 'IWZ97DB0',
        name: 'Sơn Tùng M-TP',
        aliasName: 'Son-Tung-M-TP',
        avatar:
          'https://photo-resize-zmp3.zmdcdn.me/w240_r1x1_jpeg/avatars/a/artist.jpg',
        externalUrl:
          'https://current.example.test/nghe-si/Son-Tung-M-TP',
        totalFollow: 2_600_000,
      }],
      collections: [{
        id: 'ZWZAC9BF',
        title: 'Những Bài Hát Hay Nhất Của Sơn Tùng M-TP',
        artist: 'Sơn Tùng M-TP',
        thumbnail:
          'https://photo-resize-zmp3.zmdcdn.me/w240_r1x1_jpeg/cover/a/playlist.jpg',
        kind: 'playlist',
        externalUrl: 'https://current.example.test/link/album/ZWZAC9BF',
      }],
      videos: [],
    });
    expect(String(fetcher.mock.calls[0]?.[0])).toContain(
      'query=S%C6%A1n+T%C3%B9ng',
    );
  });

  it('signs and normalizes the current full search with lyrics and MV', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0,
      data: {
        songs: [
          {
            encodeId: 'SONG1',
            title: 'Bài hát có lời',
            artistsNames: 'Nghệ sĩ A',
            artists: [{
              id: 'ARTIST1',
              name: 'Nghệ sĩ A',
              alias: 'Nghe-Si-A',
              thumbnailM: '//image.example.test/artist.jpg',
              link: '/nghe-si/Nghe-Si-A',
            }],
            album: {
              encodeId: 'ALBUM1',
              title: 'Album A',
              artistsNames: 'Nghệ sĩ A',
              thumbnailM: '//image.example.test/album.jpg',
              link: '/album/album-a/ALBUM1.html',
              isAlbum: true,
            },
            thumbnailM: '//image.example.test/song.jpg',
            duration: 245,
            link: '/bai-hat/bai-hat-co-loi/SONG1.html',
            streamingStatus: 1,
            hasLyric: true,
          },
          {
            encodeId: 'PRIVATE',
            title: 'Bài riêng tư',
            isPrivate: true,
            streamingStatus: 1,
          },
        ],
        artists: [{
          id: 'ARTIST1',
          name: 'Nghệ sĩ A',
          alias: 'Nghe-Si-A',
          totalFollow: 2_600_000,
          thumbnailM: '//image.example.test/artist.jpg',
          link: 'https://evil.example/nghe-si/Nghe-Si-A',
        }],
        playlists: [{
          encodeId: 'ALBUM1',
          title: 'Album A',
          artistsNames: 'Nghệ sĩ A',
          thumbnailM: '//image.example.test/album.jpg',
          link: '/album/album-a/ALBUM1.html',
          isAlbum: true,
        }],
        videos: [
          {
            encodeId: 'VIDEO1',
            title: 'MV A',
            artistsNames: 'Nghệ sĩ A',
            artists: [{
              id: 'ARTIST1',
              name: 'Nghệ sĩ A',
              alias: 'Nghe-Si-A',
              thumbnailM: '//image.example.test/artist.jpg',
              link: '/nghe-si/Nghe-Si-A',
            }],
            thumbnailM: '//image.example.test/video.jpg',
            duration: 263,
            link: '/video-clip/mv-a/VIDEO1.html',
            streamingStatus: 1,
          },
          {
            encodeId: 'LOCKED',
            title: 'MV bị khóa',
            link: '/video-clip/locked/LOCKED.html',
            streamingStatus: 2,
          },
          {
            encodeId: 'UNSAFE',
            title: 'MV URL lỗi',
            link: 'https://evil.example/video',
            streamingStatus: 1,
          },
        ],
      },
    }), { status: 200 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher);

    await expect(upstream.fetchSearch('  lời bài hát  ')).resolves.toEqual({
      query: 'lời bài hát',
      catalogPlaybackEnabled: true,
      songs: [{
        id: 'SONG1',
        code: 'SONG1',
        title: 'Bài hát có lời',
        artist: 'Nghệ sĩ A',
        artists: [{
          id: 'ARTIST1',
          name: 'Nghệ sĩ A',
          aliasName: 'Nghe-Si-A',
          avatar: 'https://image.example.test/artist.jpg',
          externalUrl: 'https://current.example.test/nghe-si/Nghe-Si-A',
        }],
        albumCover: 'https://image.example.test/song.jpg',
        album: {
          id: 'ALBUM1',
          title: 'Album A',
          artist: 'Nghệ sĩ A',
          thumbnail: 'https://image.example.test/album.jpg',
          kind: 'album',
          externalUrl: 'https://current.example.test/album/album-a/ALBUM1.html',
        },
        durationSeconds: 245,
        externalUrl:
          'https://current.example.test/bai-hat/bai-hat-co-loi/SONG1.html',
        playable: true,
        hasLyrics: true,
      }],
      artists: [{
        id: 'ARTIST1',
        name: 'Nghệ sĩ A',
        aliasName: 'Nghe-Si-A',
        avatar: 'https://image.example.test/artist.jpg',
        externalUrl: 'https://current.example.test/nghe-si/Nghe-Si-A',
        totalFollow: 2_600_000,
      }],
      collections: [{
        id: 'ALBUM1',
        title: 'Album A',
        artist: 'Nghệ sĩ A',
        thumbnail: 'https://image.example.test/album.jpg',
        kind: 'album',
        externalUrl: 'https://current.example.test/album/album-a/ALBUM1.html',
      }],
      videos: [{
        id: 'VIDEO1',
        title: 'MV A',
        artist: 'Nghệ sĩ A',
        artists: [{
          id: 'ARTIST1',
          name: 'Nghệ sĩ A',
          aliasName: 'Nghe-Si-A',
          avatar: 'https://image.example.test/artist.jpg',
          externalUrl: 'https://current.example.test/nghe-si/Nghe-Si-A',
        }],
        thumbnail: 'https://image.example.test/video.jpg',
        durationSeconds: 263,
        externalUrl:
          'https://current.example.test/video-clip/mv-a/VIDEO1.html',
      }],
    });
    const signedUrl = new URL(String(fetcher.mock.calls[0]?.[0]));
    expect(signedUrl.pathname).toBe('/api/v2/search/multi');
    expect(signedUrl.searchParams.get('q')).toBe('lời bài hát');
    expect(signedUrl.searchParams.get('allowCorrect')).toBe('1');
    expect(signedUrl.searchParams.get('sig')).toBeTruthy();
    expect(fetcher.mock.calls[0]?.[1]?.redirect).toBe('error');
  });

  it('accepts a discovery home containing only safe Quick Play cards', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0,
      timestamp: 1_787_249_000,
      data: {
        items: [{
          sectionType: 'quickPlay',
          items: [{
            id: 'QUICK_ONLY',
            title: 'V-Pop Mở Nhanh',
            description: 'Playlist mở nhanh.',
            thumbnail: '//image.example.test/quick-only.jpg',
            link: '/album/v-pop-mo-nhanh/QUICK_ONLY.html',
            type: 2,
          }],
        }],
      },
    }), { status: 200 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher);

    const home = await upstream.fetchDiscovery('-1');

    expect(home.quickPlay.map((item) => item.id)).toEqual(['QUICK_ONLY']);
    expect(home.banners).toEqual([]);
    expect(home.videos).toEqual([]);
    expect(home.sections).toEqual([]);
  });

  it('accepts a discovery home containing only safe official MVs', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0,
      timestamp: 1_787_249_000,
      data: {
        items: [{
          sectionType: 'video',
          items: [{
            encodeId: 'MV_ONLY',
            title: 'MV chính thức',
            artistsNames: 'Nghệ sĩ Việt',
            thumbnail: '//image.example.test/mv-only.jpg',
            duration: 201,
            link: '/video-clip/mv-chinh-thuc/MV_ONLY.html',
            streamingStatus: 1,
          }],
        }],
      },
    }), { status: 200 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher);

    const home = await upstream.fetchDiscovery('-1');

    expect(home.quickPlay).toEqual([]);
    expect(home.banners).toEqual([]);
    expect(home.sections).toEqual([]);
    expect(home.videos.map((video) => video.id)).toEqual(['MV_ONLY']);
  });

  it('signs and normalizes Zing-style keyword and song suggestions', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0,
      data: {
        items: [
          {
            keywords: [
              { keyword: ' một đời ' },
              { keyword: 'Một Bước Yêu Vạn Dặm Đau' },
              { keyword: 'MỘT ĐỜI' },
            ],
          },
          {
            suggestions: [
              {
                id: 'SUGGEST1',
                title: 'Một Đời',
                thumb: '//image.example.test/suggest.jpg',
                duration: 328,
                link: '/bai-hat/mot-doi/SUGGEST1.html',
                artists: [{ name: '14 Casper' }, { name: 'Bon Nghiêm' }],
              },
              { id: '', title: 'invalid' },
            ],
          },
        ],
      },
    }), { status: 200 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher, () => 1_787_267_600_000);

    await expect(upstream.fetchSearchSuggestions('  một   ')).resolves.toEqual({
      query: 'một',
      keywords: ['một đời', 'Một Bước Yêu Vạn Dặm Đau'],
      songs: [{
        id: 'SUGGEST1',
        title: 'Một Đời',
        artist: '14 Casper, Bon Nghiêm',
        thumbnail: 'https://image.example.test/suggest.jpg',
        durationSeconds: 328,
        externalUrl:
          'https://current.example.test/bai-hat/mot-doi/SUGGEST1.html',
      }],
    });
    const signedUrl = new URL(String(fetcher.mock.calls[0]?.[0]));
    expect(signedUrl.origin).toBe('https://suggest.example.test');
    expect(signedUrl.pathname).toBe('/v1/web/ac-suggestions');
    expect(signedUrl.searchParams.get('query')).toBe('một');
    expect(signedUrl.searchParams.get('num')).toBe('10');
    expect(signedUrl.searchParams.get('language')).toBe('vi');
    expect(signedUrl.searchParams.get('apiKey')).toBe(
      'authorized-test-api-key',
    );
    expect(fetcher.mock.calls[0]?.[1]?.redirect).toBe('error');
  });

  it('derives safe suggestions from legacy search without credentials', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0,
      data: [{
        song: [{
          id: 'LEGACY1',
          name: 'Một Đời',
          artist: '14 Casper',
          thumb: '//image.example.test/legacy.jpg',
          duration: 328,
          streamingStatus: '1',
        }],
      }],
    }), { status: 200 }));
    const upstream = new ZingUpstream(config, fetcher);

    await expect(upstream.fetchSearchSuggestions('một')).resolves.toEqual({
      query: 'một',
      keywords: ['Một Đời'],
      songs: [{
        id: 'LEGACY1',
        title: 'Một Đời',
        artist: '14 Casper',
        thumbnail: 'https://image.example.test/legacy.jpg',
        durationSeconds: 328,
        externalUrl: 'https://current.example.test/link/song/LEGACY1',
      }],
    });
    expect(new URL(String(fetcher.mock.calls[0]?.[0])).origin).toBe(
      'https://search.example.test',
    );
  });

  it('fails closed for missing or restricted search streaming status', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      data: {
        songs: [
          { encodeId: 'PLAYABLE', title: 'Được phát', streamingStatus: 1 },
          { encodeId: 'UNKNOWN', title: 'Không rõ quyền' },
          { encodeId: 'LOCKED', title: 'Bị khóa', streamingStatus: 2 },
        ],
      },
    }), { status: 200 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher);

    const result = await upstream.fetchSearch('quyền phát');
    expect(result.songs.map((song) => [song.id, song.playable])).toEqual([
      ['PLAYABLE', true],
      ['UNKNOWN', false],
      ['LOCKED', false],
    ]);
  });

  it('parses public MusicPlaylist JSON-LD into a normalized collection', async () => {
    const html = `<!doctype html><html><head>
      <script type="application/ld+json">{"@type":"WebSite","name":"Zing MP3"}</script>
      <script type="application/ld+json">${JSON.stringify({
        '@context': 'https://schema.org',
        '@type': 'MusicAlbum',
        name: 'Nơi Này Có Anh (Single)',
        url: 'https://current.example.test/album/noi-nay-co-anh/ZOUEA86A.html',
        image: 'https://image.example.test/collection.jpg',
        description: 'Single của Sơn Tùng M-TP',
        datePublished: '2017',
        genre: 'Việt Nam,V-Pop',
        track: {
          '@type': 'ItemList',
          itemListElement: [{
            '@type': 'ListItem',
            position: 1,
            url: 'https://current.example.test/bai-hat/noi-nay-co-anh/ZW79ZBE8.html#video-clip',
            item: {
              '@type': 'MusicRecording',
              name: 'Nơi Này Có Anh',
              image: 'https://image.example.test/song.jpg',
              duration: 'PT4M22S',
              byArtist: [{ '@type': 'MusicGroup', name: 'Sơn Tùng M-TP' }],
            },
          }],
        },
      })}</script></head></html>`;
    const fetcher = vi.fn().mockResolvedValue(new Response(html, {
      status: 200,
      headers: { 'content-type': 'text/html' },
    }));
    const upstream = new ZingUpstream(config, fetcher);

    await expect(upstream.fetchCollection('ZOUEA86A')).resolves.toEqual({
      id: 'ZOUEA86A',
      title: 'Nơi Này Có Anh (Single)',
      artist: 'Sơn Tùng M-TP',
      thumbnail: 'https://image.example.test/collection.jpg',
      kind: 'album',
      externalUrl:
        'https://current.example.test/album/noi-nay-co-anh/ZOUEA86A.html',
      artists: [],
      description: 'Single của Sơn Tùng M-TP',
      year: '2017',
      releasedAt: 0,
      distributor: '',
      likeCount: 0,
      genres: ['Việt Nam', 'V-Pop'],
      catalogPlaybackEnabled: false,
      sections: [],
      songs: [{
        id: 'ZW79ZBE8',
        code: 'ZW79ZBE8',
        title: 'Nơi Này Có Anh',
        artist: 'Sơn Tùng M-TP',
        albumCover: 'https://image.example.test/song.jpg',
        durationSeconds: 262,
        externalUrl:
          'https://current.example.test/bai-hat/noi-nay-co-anh/ZW79ZBE8.html',
        playable: false,
      }],
    });
    expect(String(fetcher.mock.calls[0]?.[0])).toBe(
      'https://current.example.test/link/album/ZOUEA86A',
    );
    expect(fetcher.mock.calls[0]?.[1]?.headers).toEqual({
      accept: 'text/html,application/xhtml+xml',
    });
    expect(fetcher.mock.calls[0]?.[1]?.redirect).toBe('manual');
  });

  it('validates every collection redirect before following it', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(null, {
      status: 302,
      headers: { location: 'http://169.254.169.254/latest/meta-data' },
    }));
    const upstream = new ZingUpstream(config, fetcher);

    await expect(upstream.fetchCollection('ZOUEA86A')).rejects.toThrow(
      'redirect is not trusted',
    );
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(fetcher.mock.calls[0]?.[1]?.redirect).toBe('manual');
  });

  it('follows only trusted collection redirects', async () => {
    const html = `<script type="application/ld+json">${JSON.stringify({
      '@type': 'MusicPlaylist',
      name: 'Playlist an toàn',
      url: 'https://current.example.test/playlist/an-toan/ZOUEA86A.html',
      track: [{
        url: 'https://current.example.test/bai-hat/bai-mot/SONG1.html',
        item: { name: 'Bài một' },
      }],
    })}</script>`;
    const fetcher = vi.fn()
      .mockResolvedValueOnce(new Response(null, {
        status: 302,
        headers: {
          location: '/playlist/an-toan/ZOUEA86A.html',
        },
      }))
      .mockResolvedValueOnce(new Response(html, { status: 200 }));
    const upstream = new ZingUpstream(config, fetcher);

    await expect(upstream.fetchCollection('ZOUEA86A')).resolves.toMatchObject({
      title: 'Playlist an toàn',
      songs: [{ id: 'SONG1', playable: false }],
    });
    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(String(fetcher.mock.calls[1]?.[0])).toBe(
      'https://current.example.test/playlist/an-toan/ZOUEA86A.html',
    );
  });

  it('cancels a collection body that exceeds the streamed byte cap', async () => {
    const cancel = vi.fn();
    const body = new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(new Uint8Array(1_000_001));
        controller.enqueue(new Uint8Array(1_000_001));
      },
      cancel,
    });
    const fetcher = vi.fn().mockResolvedValue(new Response(body, { status: 200 }));
    const upstream = new ZingUpstream(config, fetcher);

    await expect(upstream.fetchCollection('ZOUEA86A')).rejects.toThrow(
      'page is too large',
    );
    expect(cancel).toHaveBeenCalledTimes(1);
  });

  it('cancels a collection body rejected by its declared length', async () => {
    const cancel = vi.fn();
    const body = new ReadableStream<Uint8Array>({ cancel });
    const fetcher = vi.fn().mockResolvedValue(new Response(body, {
      status: 200,
      headers: { 'content-length': '2000001' },
    }));
    const upstream = new ZingUpstream(config, fetcher);

    await expect(upstream.fetchCollection('ZOUEA86A')).rejects.toThrow(
      'page is too large',
    );
    expect(cancel).toHaveBeenCalledTimes(1);
  });

  it('checks streaming status for every collection track', async () => {
    const html = `<script type="application/ld+json">${JSON.stringify({
      '@type': 'MusicAlbum',
      name: 'Album quyền phát',
      track: [
        {
          url: 'https://current.example.test/bai-hat/duoc-phat/SONG1.html',
          item: { name: 'Được phát' },
        },
        {
          url: 'https://current.example.test/bai-hat-bi-khoa/SONG2.html',
          item: { name: 'Bị khóa' },
        },
      ],
    })}</script>`;
    const fetcher = vi.fn()
      .mockResolvedValueOnce(new Response(html, { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({
        err: 0,
        data: {
          encodeId: 'SONG1',
          streamingStatus: 1,
          artists: [
            {
              id: 'TRACK_ARTIST',
              name: 'Nghệ sĩ bài hát',
              alias: 'Nghe-Si-Bai-Hat',
              thumbnail: 'https://image.example.test/track-artist.jpg',
              link: '/nghe-si/Nghe-Si-Bai-Hat',
            },
            { id: 'unsafe id', name: 'Sai ID', alias: 'Sai-ID' },
          ],
          album: {
            encodeId: 'TRACK_ALBUM',
            title: 'Album bài hát',
            artistsNames: 'Nghệ sĩ bài hát',
            thumbnail: 'https://image.example.test/track-album.jpg',
            link: '/album/album-bai-hat/TRACK_ALBUM.html',
            isAlbum: true,
          },
        },
      }), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({
        err: 0,
        data: { encodeId: 'SONG2', streamingStatus: 2 },
      }), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({
        err: 0,
        data: {
          encodeId: 'ZOUEA86A',
          like: 2_200_000,
          releaseDate: 1_486_918_800,
          distributor: '  VIVI   ENM  ',
          artists: [
            {
              id: 'ARTIST1',
              name: 'Sơn Tùng M-TP',
              alias: 'Son-Tung-M-TP',
              thumbnail: 'https://image.example.test/artist.jpg',
              link: '/nghe-si/Son-Tung-M-TP',
            },
            {
              id: 'ARTIST1',
              name: 'Bản sao bị loại',
              alias: 'Ban-Sao',
            },
            { id: 'unsafe id', name: 'Không hợp lệ', alias: 'Khong-Hop-Le' },
          ],
        },
      }), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({
        err: 0,
        data: {
          items: [
            {
              sectionId: 'appears-in',
              title: 'Sơn Tùng M-TP Xuất Hiện Trong',
              items: [
                {
                  encodeId: 'RELATED1',
                  title: '100% Năng Lượng Tích Cực',
                  artistsNames: 'Sơn Tùng M-TP, HIEUTHUHAI',
                  thumbnailM: 'https://image.example.test/related.jpg',
                  link: '/album/100-nang-luong/RELATED1.html',
                  sortDescription: 'Playlist có Sơn Tùng M-TP',
                },
                {
                  encodeId: 'RELATED1',
                  title: 'Bản trùng bị loại',
                  thumbnailM: 'https://image.example.test/duplicate.jpg',
                  link: '/album/duplicate/RELATED1.html',
                },
                {
                  encodeId: 'UNSAFE1',
                  title: 'Liên kết ngoài bị loại',
                  thumbnailM: 'https://image.example.test/unsafe.jpg',
                  link: 'https://evil.example.test/album/UNSAFE1.html',
                },
              ],
            },
          ],
        },
      }), { status: 200 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher);

    const detail = await upstream.fetchCollection('ZOUEA86A');
    expect(detail.songs.map((song) => [song.id, song.playable])).toEqual([
      ['SONG1', true],
      ['SONG2', false],
    ]);
    expect(detail.songs[0]).toMatchObject({
      artists: [{
        id: 'TRACK_ARTIST',
        name: 'Nghệ sĩ bài hát',
        aliasName: 'Nghe-Si-Bai-Hat',
      }],
      album: {
        id: 'TRACK_ALBUM',
        title: 'Album bài hát',
        kind: 'album',
      },
    });
    expect(detail.songs[1]?.artists).toBeUndefined();
    expect(detail.songs[1]?.album).toBeUndefined();
    expect(detail.likeCount).toBe(2_200_000);
    expect(detail.releasedAt).toBe(1_486_918_800_000);
    expect(detail.distributor).toBe('VIVI ENM');
    expect(detail.artists).toEqual([{
      id: 'ARTIST1',
      name: 'Sơn Tùng M-TP',
      aliasName: 'Son-Tung-M-TP',
      avatar: 'https://image.example.test/artist.jpg',
      externalUrl: 'https://current.example.test/nghe-si/Son-Tung-M-TP',
    }]);
    expect(detail.sections).toEqual([{
      id: 'appears-in',
      title: 'Sơn Tùng M-TP Xuất Hiện Trong',
      collections: [{
        id: 'RELATED1',
        title: '100% Năng Lượng Tích Cực',
        artist: 'Sơn Tùng M-TP, HIEUTHUHAI',
        thumbnail: 'https://image.example.test/related.jpg',
        kind: 'playlist',
        externalUrl:
          'https://current.example.test/album/100-nang-luong/RELATED1.html',
        description: 'Playlist có Sơn Tùng M-TP',
      }],
    }]);
    for (const call of fetcher.mock.calls.slice(1, 3)) {
      expect(new URL(String(call[0])).pathname).toBe('/api/v2/song/get/info');
    }
    expect(new URL(String(fetcher.mock.calls[3]?.[0])).pathname).toBe(
      '/api/v2/page/get/playlist',
    );
    expect(new URL(String(fetcher.mock.calls[3]?.[0])).searchParams.get('id')).toBe(
      'ZOUEA86A',
    );
    expect(new URL(String(fetcher.mock.calls[4]?.[0])).pathname).toBe(
      '/api/v2/playlist/get/section-bottom',
    );
    expect(new URL(String(fetcher.mock.calls[4]?.[0])).searchParams.get('id')).toBe(
      'ZOUEA86A',
    );
  });

  it('falls back to a signed current source only when credentials are configured', async () => {
    const fetcher = vi
      .fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({
        err: -105, msg: 'Invalid data',
      }), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({
        err: 0, data: { '128': '//stream.test/search-song.mp3' },
      }), { status: 200 }));
    const upstream = new ZingUpstream({
      ...config,
      currentApiKey: 'authorized-test-api-key',
      currentApiSigningKey: 'authorized-test-signing-key',
    }, fetcher, () => 1_787_240_409_000);

    await expect(upstream.fetchSource('ZW79ZBE8')).resolves.toBe(
      'https://stream.test/search-song.mp3',
    );
    const signedUrl = new URL(String(fetcher.mock.calls[1]?.[0]));
    expect(signedUrl.pathname).toBe('/api/v2/song/get/streaming');
    expect(signedUrl.searchParams.get('id')).toBe('ZW79ZBE8');
    expect(signedUrl.searchParams.get('ctime')).toBe('1787240409');
    expect(signedUrl.searchParams.get('version')).toBe('1.20.1');
    expect(signedUrl.searchParams.get('apiKey')).toBe('authorized-test-api-key');
    expect(signedUrl.searchParams.get('sig')).toMatch(/^[a-f0-9]{128}$/);
  });

  it('rejects non-HTTPS media schemes', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      err: 0, data: { source: { '128': 'javascript:alert(1)' } },
    }), { status: 200 }));
    const upstream = new ZingUpstream(config, fetcher);
    await expect(upstream.fetchSource('ABC')).rejects.toThrow('unsafe media URL');
  });
});
