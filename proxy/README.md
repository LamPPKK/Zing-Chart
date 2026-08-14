# #zingChart proxy

Self-hosted API boundary between the Flutter clients and the legacy Zing
endpoints. Requires Node.js 22 or newer.

```bash
cp .env.example .env
npm install
npm run dev
```

## API

- `GET /health` → `{ "status": "ok" }`
- `GET /v1/chart` → `{ "songs": Song[] }`
- `GET /v1/songs/:code/source` → `{ "url": "https://api.example/v1/streams/<signed-token>" }`
- `GET /v1/streams/:signedToken` → relayed audio (`200` or `206` with byte-range headers)

The source response never exposes the CDN URL. Its short-lived signed URL only
contains a song code; the stream endpoint resolves that code server-side and
relays the audio. It accepts a single HTTP byte range and forwards
`Content-Type`, `Content-Length`, `Content-Range`, and `Accept-Ranges`. Stream
responses always send `Cache-Control: private, no-store` and are never cached by
the chart cache. `UPSTREAM_TIMEOUT_MS` remains active until the audio body ends;
disconnecting the client aborts the CDN request.

Errors use `{ "error": { "code", "message", "requestId" } }`. Clients can
send `x-request-id`; the server returns the accepted or generated ID in every
response.

Production requires `CORS_ORIGINS` as a comma-separated allowlist. See
`.env.example` for timeout, cache, and rate-limit settings. Set
`TRUST_PROXY_HOPS=1` only when the container is directly behind one trusted
reverse proxy, so rate limiting keys clients by the correct address.
`PUBLIC_BASE_URL` must be the HTTPS origin exposed to clients and
`STREAM_TOKEN_SECRET` must be a random value of at least 32 characters.
`STREAM_HOSTS` is a comma-separated allowlist of trusted CDN domains; exact
domains and their subdomains are accepted, while ports, credentials, HTTP, and
redirects outside the allowlist are rejected.

```bash
docker build -t zing-chart-proxy .
docker run --rm -p 8080:8080 \
  -e CORS_ORIGINS=https://music.example.com \
  -e PUBLIC_BASE_URL=https://api.example.com \
  -e STREAM_TOKEN_SECRET=replace-with-a-strong-random-secret \
  zing-chart-proxy
```
