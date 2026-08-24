import { describe, expect, it } from 'vitest';
import {
  createLiveStreamToken,
  readLiveStreamToken,
} from '../src/live-stream-token.js';

const secret = 'test-secret-at-least-thirty-two-characters';

describe('encrypted live stream tokens', () => {
  it('round-trips room and URL payloads without exposing the upstream URL', () => {
    const room = createLiveStreamToken('room', 'ROOM1', secret, 60, 1_000_000);
    expect(readLiveStreamToken(room, secret, 1_000_000)).toEqual({
      kind: 'room',
      value: 'ROOM1',
      expiresAt: 1060,
    });

    const upstreamUrl = 'https://radio.stream.example.test/live/segment-1.aac';
    const url = createLiveStreamToken('url', upstreamUrl, secret, 60, 1_000_000);
    expect(url).not.toContain('radio.stream.example.test');
    expect(url).not.toContain(Buffer.from(upstreamUrl).toString('base64url'));
    expect(readLiveStreamToken(url, secret, 1_000_000)).toEqual({
      kind: 'url',
      value: upstreamUrl,
      expiresAt: 1060,
    });
  });

  it('rejects tampering, expiry, wrong secrets, and oversized input', () => {
    const token = createLiveStreamToken('room', 'ROOM1', secret, 60, 1_000_000);
    expect(readLiveStreamToken(`${token}x`, secret, 1_000_000)).toBeUndefined();
    expect(readLiveStreamToken(token, 'different-secret', 1_000_000)).toBeUndefined();
    expect(readLiveStreamToken(token, secret, 1_060_000)).toBeUndefined();
    expect(readLiveStreamToken(`v1.${'a'.repeat(2050)}`, secret)).toBeUndefined();
  });
});
