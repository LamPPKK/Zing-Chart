# #zingChart proxy

Self-hosted API boundary between the Flutter clients and the legacy Zing
endpoints. Requires Node.js 22 or newer.

```bash
cp .env.example .env
set -a
. ./.env
set +a
npm ci
npm run dev
```

Node does not load `.env` automatically. The `set -a`/source sequence above
exports every value from the file into the current shell. Restart the process
after changing the file.

## API

- `GET /health` → `{ "status": "ok" }`
- `GET /v1/chart` → `{ "songs": [{ "id", "code", "title", "artist", "artists"?, "albumCover", "albumTitle", "album"?, "durationSeconds", "rank", "rankChange" }], "chart": RealtimeChart }`
- `GET /v1/charts/new-releases` → `{ "title", "updatedAt", "songs", "catalogPlaybackEnabled" }`; each song may include validated structured `artists` and `album` navigation metadata
- `GET /v1/charts/weekly?region=vietnam|usuk|korea[&week=33&year=2026]` → normalized official weekly chart with the same optional structured `artists` and `album` metadata
- `GET /v1/discovery/categories` → `{ "updatedAt", "items": [{ "id", "name" }] }`
- `GET /v1/discovery/recommendations` → `{ "updatedAt", "songs", "catalogPlaybackEnabled" }`
- `GET /v1/discovery/home?categoryId=-1|<id>` → `{ "categoryId", "updatedAt", "quickPlay", "banners", "videos", "sections" }`
- `GET /v1/hubs` → `{ "updatedAt", "featured", "nations", "topics", "genres" }`
- `GET /v1/hubs/:id` → normalized hub metadata and playlist rails
- `GET /v1/top-100` → `{ "updatedAt", "sections" }`
- `GET /v1/releases` → `{ "updatedAt", "songs" (with structured artists/albums), "albums", "catalogPlaybackEnabled" }`
- `GET /v1/artists/:alias` → official artist/OA metadata (including a validated `externalUrl`), six `featuredSongs`, the first 50 `songs` with optional `songPage` metadata and structured artists/albums, up to 50 public MVs, releases, related artists, and biography
- `GET /v1/artists/:id/songs[?page=1&limit=50]` → `{ "artistId", "page", "limit", "total", "hasMore", "items", "catalogPlaybackEnabled" }`; `page` is limited to 1–100 and `limit` to 1–50
- `GET /v1/search/suggestions?q=<query>` → `{ "query", "keywords", "songs" }`
- `GET /v1/search?q=<query>` → `{ "query", "songs" (with `hasLyrics` and structured artists/albums when authorized), "artists", "collections", "videos" (with validated structured artists when supplied), "catalogPlaybackEnabled" }`
- `GET /v1/search?q=<query>&type=songs|artists|collections|videos[&page=1&limit=18]` → `{ "query", "type", "page", "limit", "total", "hasMore", "items", "catalogPlaybackEnabled" }`; `page` is limited to 1–100 and `limit` to 1–50
- `GET /v1/collections/:id` → normalized playlist/album metadata, validated structured `artists`, official `likeCount`, release/distributor metadata, track list, and bounded related collection sections
- `GET /v1/songs/:id/detail` → official song, artist, album, release, genre, composer, engagement, lyric/MV, and strict playback metadata; this route uses the public song ID, not the legacy audio-source code
- `GET /v1/songs/:code/lyrics` → `{ "songId", "synced", "lines": [{ "startTimeMs", "endTimeMs", "text", "words"? }] }`
- `GET /v1/songs/:code/radio` → `{ "seedId", "songs", "catalogPlaybackEnabled" }`
- `GET /v1/radio` → `{ "updatedAt", "rooms": LiveRadioRoom[] }`
- `GET /v1/radio/:id/source` → `{ "url": "https://api.example/v1/live-streams/<opaque-token>" }`
- `GET /v1/live-streams/:opaqueToken` → rewritten HLS playlist or relayed key/segment
- `GET /v1/songs/:code/source?quality=auto|128|320` → `{ "url": "https://api.example/v1/streams/<signed-token>" }`
- `GET /v1/streams/:signedToken` → relayed audio (`200` or `206` with byte-range headers)

The source response never exposes the CDN URL. Its short-lived signed URL binds
both the song code and requested bitrate; the stream endpoint resolves them
server-side and relays the audio. `auto` prefers a valid 320 kbps source and
falls back to 128 kbps, while explicit `128` or `320` requests fail closed when
that bitrate is unavailable. It accepts a single HTTP byte range and forwards
`Content-Type`, `Content-Length`, `Content-Range`, and `Accept-Ranges`. Stream
responses always send `Cache-Control: private, no-store` and are never cached by
the chart cache. `UPSTREAM_TIMEOUT_MS` remains active until the audio body ends;
disconnecting the client aborts the CDN request.

`RealtimeChart` contains `series` keyed by the top-three song IDs. Every point
has a Unix-millisecond `time`, a two-digit `hour`, and a numeric `counter`;
`minScore`, `maxScore`, and `updatedAt` let clients scale and label the 24-hour
chart without inventing trend data. The realtime block is additive, so clients
that only consume `songs` remain compatible. Chart rows can also include
normalized primary-artist and album objects. Their IDs and official Zing links
are bounded and validated before Flutter uses them for in-app navigation.

The new-release chart uses the authorized current-API adapter, is single-flight
cached for `CHART_CACHE_TTL_MS`, and includes rank movement, album, duration,
release time, and strict per-song playback eligibility. It fails closed unless
`streamingStatus` is exactly `1`.

The weekly-chart route uses the same server-only credentials and the official
regional IDs for Vietnam, US-UK, and K-Pop. `week` and `year` must be supplied
together; omitting both requests the latest period. Responses include rank,
movement, score, album, duration, and strict per-song playback eligibility,
and are single-flight cached per region/period for `CHART_CACHE_TTL_MS`.

Search suggestions expose at most four normalized keywords and six song-preview
rows. With authorized current-API credentials the proxy signs the configured
`ZING_SUGGESTION_URL`; without them it derives the same response shape from the
legacy catalog search. Credentials, raw upstream URLs, and playback eligibility
are never inferred or returned by this preview endpoint. Selecting a suggestion
still runs the strict full-catalog search before a song can be played. Responses
are single-flight cached per normalized query for `SEARCH_CACHE_TTL_MS`.

Full search signs `/api/v2/search/multi` when current-API credentials are
available and normalizes songs, artists/OA, playlists/albums, lyric capability,
and public MV metadata. Songs fail closed unless `streamingStatus === 1`; private,
pre-release, locked, malformed, and unsafe-link entries are removed. MV playback
is not relayed: the client opens only a validated official `zingmp3.vn/video-clip/`
page, or displays a QR/copy handoff on TV and unsupported platforms. Without
credentials, the legacy adapter returns the compatible shape with no playable
catalog songs or MV entries.

Adding `type` switches the same route to a typed, paginated contract. The public
types `songs`, `artists`, `collections`, and `videos` are mapped server-side to
the signed current `/api/v2/search` types `song`, `artist`, `playlist`, and
`video`. `page` defaults to 1 (maximum 100) and `limit` defaults to 18 (maximum
50). `total` is nullable when upstream omits it, while `hasMore` remains explicit.
Responses echo the normalized query and effective type/page/limit, and each
page is single-flight cached by that complete tuple for `SEARCH_CACHE_TTL_MS`.
Only song pages consult the realtime chart to upgrade a matching legacy source
code; chart failure never prevents catalog discovery. A deployment without the
authorized current adapter keeps aggregate legacy search unchanged and returns
HTTP 501 with `SEARCH_PAGINATION_UNAVAILABLE` for typed pages, allowing clients
to retain the aggregate seed and hide Load more without inventing pagination.

The lyrics route signs `/api/v2/lyric/get/lyric` only on the proxy. Karaoke
sentences are normalized into ordered, bounded lines and optional ordered
`words` (`startTimeMs`, `endTimeMs`, `text`) for word-level highlighting. If a
sentence has incomplete word timing, the proxy fails safely to line timing;
when upstream exposes only plain lyrics the response uses zero timestamps and
`synced: false`. Empty lyrics are a valid empty response. Results are
single-flight cached by song code for `SEARCH_CACHE_TTL_MS`; API credentials,
external lyric-file URLs, and raw upstream payloads are never returned.
Any LRC file fetch uses the same HTTPS `STREAM_HOSTS` allowlist, validates each
manual redirect, and enforces a 512 KB streamed-body cap.

Song detail accepts the public song ID (the realtime chart's `id`, not its
legacy audio-source `code`), signs `/api/v2/page/get/song` only on the proxy,
and returns a bounded, normalized single-page contract. The client receives official artist,
album, release date, distributor, genre, composer, engagement, lyric capability,
and optional public MV metadata without receiving credentials or raw upstream
payloads. Playback fails closed unless `streamingStatus === 1`; private,
pre-release, blocked, mismatched, and malformed songs never become playable.
MV media is not relayed: clients may open only the validated official page or
show the existing QR/copy handoff on TV and unsupported platforms. Detail
responses are single-flight cached by song code for `SEARCH_CACHE_TTL_MS`.

Song Radio signs `/api/v2/recommend/get/songs` on the proxy and returns at most
30 unique recommendations. It excludes the seed, private and pre-release
entries, and fails closed unless `streamingStatus === 1`. Results are
single-flight cached by seed for `SEARCH_CACHE_TTL_MS`; no client favorites,
analytics, queue, or listening history are accepted or forwarded.

Phòng Nhạc signs the current radio directory request only on the proxy and
returns sanitized room, host, listener-count, and current-program metadata.
Raw HLS/CDN URLs never reach Flutter: the source contract returns an encrypted,
opaque same-origin token. Every master/media playlist URL (including encryption
keys and initialization maps) is resolved against the upstream playlist,
checked against `STREAM_HOSTS`, encrypted into a child token, and rewritten to
`/v1/live-streams/...`. Redirects are followed manually only after allowlist
validation; playlists are capped at 1 MB, segments at 32 MB, byte ranges are
validated, and the upstream timeout remains active through the response body.
Directory metadata is single-flight cached for `LIVE_RADIO_CACHE_TTL_MS`;
playlist and media responses are always `private, no-store`.

Discovery Home uses the same authorized adapter to normalize the official
`quickPlay` playlist carousel, editorial banner targets, public MV cards, and
playlist/album rails such as Top 100, Chill, and Album Hot. It keeps at most 10
unique Quick Play cards, 6 banners, 12 public MVs, and 12 collections per
section. Collection cards preserve at most 8 validated structured artists so
clients can render the same independent artist links as Zing instead of
parsing `artistsNames`. MV entries preserve at most 8 validated structured
artists for official avatar rendering, require `streamingStatus === 1`, and
require a validated relative `/video-clip/` target; media is never relayed. Malformed, private, pre-release,
duplicate, external, and unsupported targets are dropped. The upstream
`adBanner` placeholder and third-party advertising payloads are intentionally
ignored. Each category is single-flight cached for `SEARCH_CACHE_TTL_MS`.

Discovery recommendations sign the official anonymous Song Station request on
the server. The adapter keeps at most 12 unique, non-private, non-pre-release
tracks whose `streamingStatus` is exactly `1`; it never receives installation
IDs, favorites, analytics, or local listening history. Each retained song also
preserves bounded, validated structured artist and album metadata so clients
can navigate official content without parsing display strings.

Topic & Genre Home, hub detail, and Top 100 use the authorized current-API
adapter as well. Hub Home normalizes featured, nation, topic/activity, and genre
groups; hub detail preserves playlist-rail order; Top 100 preserves the source
section order. Invalid IDs, malformed links, non-HTTPS artwork, and unsupported
collection targets fail closed; structured collection artists use the same
bounded identity/link validation. Home, Top 100, and each hub detail are
single-flight cached for `SEARCH_CACHE_TTL_MS` and never receive client
analytics, favorites, or listening history.

The New Releases catalog requests the authorized song and album release feeds
in parallel, preserves bounded structured artist/album metadata for song rows,
preserves bounded structured artists for album cards, normalizes each item into
Vietnam, US-UK, Korea, or Other, and
fails closed unless a song has `streamingStatus === 1`. Private, pre-release,
malformed, and unsupported targets are discarded. The combined response is
single-flight cached for `SEARCH_CACHE_TTL_MS`.

Artist detail uses the authorized current-API adapter and validates the alias
before contacting upstream. It normalizes official metadata and enriches the
profile through the signed `/song/get/list` artist catalog with at most 50
songs, six featured songs, bounded structured artist/album navigation metadata, 50 public MV
cards, six release/playlist rails, eight related artists, and a plain-text
biography. If that independent song-list request fails, the profile keeps its
bounded featured-song section instead of failing the whole page. Artist links
are normalized to HTTPS `/nghe-si/` pages
on the configured Zing origin; arbitrary upstream hosts are never forwarded.
MV handoffs are restricted to official HTTPS `/video-clip/` pages. Private,
pre-release, and malformed entries are discarded; explicitly locked songs are
retained as metadata but never become playable. Song playback is enabled only
for `streamingStatus === 1`, malformed child cards are
dropped without invalidating the whole page, and each alias is single-flight
cached for `SEARCH_CACHE_TTL_MS`.

The additive artist-song route continues the same signed catalog beyond the
profile's first 50 songs. Pages are single-flight cached by exact artist ID,
page, and limit; their upstream JSON is capped at 2 MB. `total` is nullable,
`hasMore` is calculated from raw upstream pagination before malformed records
are removed, and duplicate IDs are removed within each page. Clients must
deduplicate while accumulating multiple pages because the upstream catalog may
change between requests. Missing credentials/capability return a non-cacheable
`501` instead of falling back to untrusted data.

Catalog search signs Zing's current `/api/v2/search/multi` endpoint when
credentials are configured, preserves validated structured artist/album
metadata on song rows, normalizes at most 25 songs, 10 artists, 25
playlist/album cards, and 20 public MV cards, and is cached for
`SEARCH_CACHE_TTL_MS`. Without credentials it uses the public autocomplete
boundary but fails closed for catalog playback and returns no MVs. Typed pages
use the independently bounded `/api/v2/search` contract described above, cap
upstream JSON at 2 MB, discard malformed records independently, and never expose
credentials, signatures, or raw upstream URLs. Collection
detail parses the public JSON-LD
`MusicPlaylist`/`MusicAlbum` document, validates every redirect before following
it, enforces a 2 MB streamed-body limit, and caches at most 100 entries. When
current API credentials are configured, it also signs both
`/api/v2/page/get/playlist` and `/api/v2/playlist/get/section-bottom` to obtain
the release date, distributor and at most four deduplicated related-collection
sections (12 validated Zing collections each). Each signed request fails closed
and degrades independently from the public track list. A track
reports `playable: false` when it is outside the current chart and the proxy has
no authorized current-API adapter. With that adapter configured, the proxy
checks each collection track's current `streamingStatus` and fails closed for
restricted or unverifiable tracks. Chart matches are automatically upgraded to
their working legacy code.
To enable playback for the remaining catalog, configure `ZING_CURRENT_API_KEY`
and `ZING_CURRENT_API_SIGNING_KEY` together, plus the matching base URL/version.
These values stay in the proxy environment; they are never returned to Flutter
or embedded in an app build. Do not copy credentials from third-party
repositories—use only values your deployment is authorized to use.

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

Packaged webOS and Tizen applications can send the literal CORS origin `null`
because they launch from an installed file bundle. Add `null` explicitly to
`CORS_ORIGINS` only for a proxy deployment that serves these TV packages. This
also admits other sandboxed/file origins, so keep rate limiting enabled and use
a separate TV proxy origin when stricter browser isolation is required.

## Production with Node.js

Create and edit `.env.production` first, then load it into the shell before
starting the compiled server:

```bash
cp .env.example .env.production # Run once, then edit production values.
npm ci
npm run typecheck
npm test
npm run build
set -a
. ./.env.production
set +a
npm start
```

## Production with Docker

Reuse the production environment file described above:

```bash
docker build -t zing-chart-proxy .
docker run --rm -p 8080:8080 \
  --env-file .env.production \
  zing-chart-proxy
```
