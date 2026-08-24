import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
} from 'node:crypto';

export type LiveStreamTokenKind = 'room' | 'url';

export interface LiveStreamTokenPayload {
  kind: LiveStreamTokenKind;
  value: string;
  expiresAt: number;
}

const VERSION = 'v1';
const AAD = Buffer.from('zingchart-live-stream-v1');
const IV_BYTES = 12;
const TAG_BYTES = 16;
const MAX_VALUE_LENGTH = 1024;
const MAX_TOKEN_LENGTH = 2048;

function key(secret: string) {
  return createHash('sha256').update(secret).digest();
}

export function createLiveStreamToken(
  kind: LiveStreamTokenKind,
  value: string,
  secret: string,
  ttlSeconds: number,
  now = Date.now(),
) {
  if (!value || value.length > MAX_VALUE_LENGTH) {
    throw new Error('Live stream token value is invalid');
  }
  const iv = randomBytes(IV_BYTES);
  const cipher = createCipheriv('aes-256-gcm', key(secret), iv);
  cipher.setAAD(AAD);
  const payload = Buffer.from(JSON.stringify({
    kind,
    value,
    expiresAt: Math.floor(now / 1000) + ttlSeconds,
  } satisfies LiveStreamTokenPayload));
  const encrypted = Buffer.concat([cipher.update(payload), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${VERSION}.${Buffer.concat([iv, tag, encrypted]).toString('base64url')}`;
}

export function readLiveStreamToken(
  token: string,
  secret: string,
  now = Date.now(),
): LiveStreamTokenPayload | undefined {
  if (!token || token.length > MAX_TOKEN_LENGTH) return undefined;
  const [version, encoded, extra] = token.split('.');
  if (version !== VERSION || !encoded || extra) return undefined;
  try {
    const packed = Buffer.from(encoded, 'base64url');
    if (packed.length <= IV_BYTES + TAG_BYTES) return undefined;
    const iv = packed.subarray(0, IV_BYTES);
    const tag = packed.subarray(IV_BYTES, IV_BYTES + TAG_BYTES);
    const encrypted = packed.subarray(IV_BYTES + TAG_BYTES);
    const decipher = createDecipheriv('aes-256-gcm', key(secret), iv);
    decipher.setAAD(AAD);
    decipher.setAuthTag(tag);
    const decoded = Buffer.concat([
      decipher.update(encrypted),
      decipher.final(),
    ]).toString('utf8');
    const payload = JSON.parse(decoded) as Partial<LiveStreamTokenPayload>;
    if (
      (payload.kind !== 'room' && payload.kind !== 'url')
      || typeof payload.value !== 'string'
      || payload.value.length === 0
      || payload.value.length > MAX_VALUE_LENGTH
      || typeof payload.expiresAt !== 'number'
      || !Number.isSafeInteger(payload.expiresAt)
      || payload.expiresAt <= Math.floor(now / 1000)
    ) {
      return undefined;
    }
    return payload as LiveStreamTokenPayload;
  } catch {
    return undefined;
  }
}
