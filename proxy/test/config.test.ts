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
});
