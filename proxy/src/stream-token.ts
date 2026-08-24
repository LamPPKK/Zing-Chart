import { createHmac, timingSafeEqual } from 'node:crypto';

import type { StreamQuality } from './types.js';

export interface StreamTokenPayload {
  code: string;
  expiresAt: number;
  quality: StreamQuality;
}

function signature(payload: string, secret: string) {
  return createHmac('sha256', secret).update(payload).digest('base64url');
}

export function createStreamToken(
  code: string,
  secret: string,
  ttlSeconds: number,
  now = Date.now(),
  quality: StreamQuality = 'auto',
) {
  const payload = Buffer.from(JSON.stringify({
    code,
    expiresAt: Math.floor(now / 1000) + ttlSeconds,
    quality,
  } satisfies StreamTokenPayload)).toString('base64url');
  return `${payload}.${signature(payload, secret)}`;
}

export function readStreamTokenPayload(
  token: string,
  secret: string,
  now = Date.now(),
) {
  const [payload, suppliedSignature, extra] = token.split('.');
  if (!payload || !suppliedSignature || extra) return undefined;
  const expected = Buffer.from(signature(payload, secret));
  const supplied = Buffer.from(suppliedSignature);
  if (expected.length !== supplied.length || !timingSafeEqual(expected, supplied)) {
    return undefined;
  }
  try {
    const value = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8')) as Partial<StreamTokenPayload>;
    const quality = value.quality ?? 'auto';
    if (typeof value.code !== 'string'
      || typeof value.expiresAt !== 'number'
      || (quality !== 'auto' && quality !== '128' && quality !== '320')
      || value.expiresAt <= Math.floor(now / 1000)) {
      return undefined;
    }
    return {
      code: value.code,
      expiresAt: value.expiresAt,
      quality,
    } satisfies StreamTokenPayload;
  } catch {
    return undefined;
  }
}

export function readStreamToken(token: string, secret: string, now = Date.now()) {
  return readStreamTokenPayload(token, secret, now)?.code;
}
