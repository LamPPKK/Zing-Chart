import { describe, expect, it } from 'vitest';
import { createStreamToken, readStreamToken } from '../src/stream-token.js';

const secret = 'test-secret-at-least-thirty-two-characters';

describe('stream tokens', () => {
  it('round-trips a signed short-lived song code', () => {
    const token = createStreamToken('ABC123', secret, 60, 1_000_000);
    expect(readStreamToken(token, secret, 1_030_000)).toBe('ABC123');
  });

  it('rejects expired and tampered tokens', () => {
    const token = createStreamToken('ABC123', secret, 60, 1_000_000);
    expect(readStreamToken(token, secret, 1_061_000)).toBeUndefined();
    expect(readStreamToken(`${token}x`, secret, 1_030_000)).toBeUndefined();
  });
});
