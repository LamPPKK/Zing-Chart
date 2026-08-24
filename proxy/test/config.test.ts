import { describe, expect, it } from 'vitest';
import { loadConfig } from '../src/config.js';

const production = {
  NODE_ENV: 'production',
  CORS_ORIGINS: 'https://app.example.test',
  PUBLIC_BASE_URL: 'https://api.example.test',
  STREAM_TOKEN_SECRET: 'production-secret-at-least-thirty-two-characters',
};

describe('stream production config', () => {
  it('requires an HTTPS public origin and a strong token secret', () => {
    expect(() => loadConfig({ ...production, PUBLIC_BASE_URL: 'http://api.example.test' }))
      .toThrow('PUBLIC_BASE_URL must use HTTPS');
    expect(() => loadConfig({ ...production, STREAM_TOKEN_SECRET: 'short' }))
      .toThrow('at least 32 characters');
    expect(() => loadConfig({ ...production, PUBLIC_BASE_URL: 'https://api.example.test/path' }))
      .toThrow('only scheme, host, and optional port');
  });

  it('allows the packaged TV null origin only when explicitly configured', () => {
    const config = loadConfig({
      ...production,
      CORS_ORIGINS: 'https://app.example.test,null',
    });
    expect(config.corsOrigins).toEqual(['https://app.example.test', 'null']);
    expect(() =>
      loadConfig({ ...production, CORS_ORIGINS: 'not-an-origin' }),
    ).toThrow('CORS_ORIGINS must be an absolute URL');
  });

  it('requires current API credentials as a complete HTTPS pair', () => {
    expect(() => loadConfig({
      ...production,
      ZING_CURRENT_API_KEY: 'authorized-key',
    })).toThrow('must be configured together');
    expect(() => loadConfig({
      ...production,
      ZING_CURRENT_API_KEY: 'authorized-key',
      ZING_CURRENT_API_SIGNING_KEY: 'authorized-signing-key',
      ZING_CURRENT_API_BASE_URL: 'http://zing.example.test',
    })).toThrow('must use HTTPS');
    expect(loadConfig({
      ...production,
      ZING_CURRENT_API_KEY: 'authorized-key',
      ZING_CURRENT_API_SIGNING_KEY: 'authorized-signing-key',
    }).currentApiKey).toBe('authorized-key');
  });
});
