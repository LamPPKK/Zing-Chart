import { describe, expect, it } from 'vitest';
import {
  createStreamToken,
  readStreamToken,
  readStreamTokenPayload,
} from '../src/stream-token.js';

const secret = 'test-secret-at-least-thirty-two-characters';

describe('stream tokens', () => {
  it('round-trips a signed short-lived song code', () => {
    const token = createStreamToken('ABC123', secret, 60, 1_000_000);
    expect(readStreamToken(token, secret, 1_030_000)).toBe('ABC123');
    expect(readStreamTokenPayload(token, secret, 1_030_000)).toMatchObject({
      code: 'ABC123',
      quality: 'auto',
    });
  });

  it('binds the requested bitrate into the signed token', () => {
    const token = createStreamToken(
      'ABC123',
      secret,
      60,
      1_000_000,
      '320',
    );
    expect(readStreamTokenPayload(token, secret, 1_030_000)).toMatchObject({
      code: 'ABC123',
      quality: '320',
    });
  });

  it('rejects expired and tampered tokens', () => {
    const token = createStreamToken('ABC123', secret, 60, 1_000_000);
    expect(readStreamToken(token, secret, 1_061_000)).toBeUndefined();
    expect(readStreamToken(`${token}x`, secret, 1_030_000)).toBeUndefined();
  });
});
