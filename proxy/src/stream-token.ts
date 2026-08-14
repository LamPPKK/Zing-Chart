import { createHmac, timingSafeEqual } from 'node:crypto';

interface StreamTokenPayload {
  code: string;
  expiresAt: number;
}

function signature(payload: string, secret: string) {
  return createHmac('sha256', secret).update(payload).digest('base64url');
}

export function createStreamToken(
  code: string,
  secret: string,
  ttlSeconds: number,
  now = Date.now(),
) {
  const payload = Buffer.from(JSON.stringify({
    code,
    expiresAt: Math.floor(now / 1000) + ttlSeconds,
  } satisfies StreamTokenPayload)).toString('base64url');
  return `${payload}.${signature(payload, secret)}`;
}

export function readStreamToken(token: string, secret: string, now = Date.now()) {
  const [payload, suppliedSignature, extra] = token.split('.');
  if (!payload || !suppliedSignature || extra) return undefined;
  const expected = Buffer.from(signature(payload, secret));
  const supplied = Buffer.from(suppliedSignature);
  if (expected.length !== supplied.length || !timingSafeEqual(expected, supplied)) {
    return undefined;
  }
  try {
    const value = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8')) as Partial<StreamTokenPayload>;
    if (typeof value.code !== 'string'
      || typeof value.expiresAt !== 'number'
      || value.expiresAt <= Math.floor(now / 1000)) {
      return undefined;
    }
    return value.code;
  } catch {
    return undefined;
  }
}
