# #zingChart

<p align="center"><img src="web/icons/Icon-192.png" width="112" height="112" alt="#zingChart mark: coral hash and lime audio pulse"></p>

[Tiếng Việt](README.md) · [English](README.en.md) · [简体中文](README.zh-CN.md)

Documentation is maintained in all three languages above. The Flutter UI is
currently Vietnamese-first; native widgets and watch remotes select Vietnamese,
English, or Simplified Chinese labels from the operating-system language.

#zingChart is a Local-First music chart and player built with Flutter. One
codebase targets Android, Android TV, iOS/iPadOS, Web/PWA, Windows, macOS,
Linux, Amazon Fire OS/Fire TV, LG webOS TV, Samsung Tizen TV, and HarmonyOS.
Chart data and audio are always fetched through the self-hosted Node proxy;
clients never call Zing upstream directly.

## Features

- Realtime Zing Chart with rank movement, artwork, title, artist, album, and
  duration from the chart metadata, plus an interactive 24-hour plot for hover,
  touch/drag, keyboard, and TV remote control with per-hour share tooltips and
  direct playback. The visible chart refreshes in the background every two
  minutes, preserves the last snapshot with an inline retry on failure, and
  stops requesting while the app is inactive. Discovery also embeds a compact
  `#zingchart` with the 24-hour plot and top three; it plays the original chart
  queue or opens the full chart without another endpoint. An independently loaded official
  Suggestion row removes chart duplicates, exposes in-app artist/album links,
  and never uploads favorites, listening history, or analytics.
  The list mirrors Zing MP3 with an initial top 10 and an in-place “View top
  100” action, while playback still receives the complete chart queue.
  Every credited artist and the album are separate hover/focus links to the
  matching in-app official page. A Song Info action opens detail without
  autoplay. Inside Song Info, artist, composer, and album links continue into
  the matching in-app profile or collection without interrupting playback or
  replacing the queue; artwork exposes Play, Lock, or Now Playing state on
  hover/focus. Song rows share one canonical More/right-click menu for Play,
  Info, queue, Radio, playlist, sharing, likes, and moods. Restricted songs
  retain safe metadata/library actions but never expose Play, queue, or Radio.
- New-release chart with rank movement, album, duration, strict playback
  eligibility, and adaptive phone/desktop/TV layouts.
- Official Weekly Chart for Vietnam, US-UK, and K-Pop. Three regional cards sit
  directly in Discovery like Zing MP3 and open the matching chart; the full
  view includes an eight-week picker, rank movement, album/duration metadata,
  and playable-only queues.
- Zing-style New Releases catalog with Songs/Albums tabs, All, Vietnam, US-UK,
  Korea, and Other filters, plus playable-only queues. Discovery Home also
  presents a Zing-like 12-song, three-column shelf with All/Vietnam/
  International filters and a link to the full catalog; every song uses the
  same action menu on phone, desktop, and TV, with desktop right-click parity.
- Discovery Home with Zing-style For You, Relax, Work, Trending, Sleep, and
  Workout category pills; each category retains its own Quick Play, editorial
  banner, and collection rails. While the network is pending, a responsive
  Quick Play → banner → song skeleton preserves the final content rhythm on
  phone, tablet, desktop, and TV; its progress becomes static when the OS asks
  for reduced motion. On tablet/desktop, search now flows directly
  into the category rail and Quick Play; that rail stays pinned directly below
  the toolbar while scrolling. The oversized title, recent-search chips, and
  secondary shortcuts no longer push primary content below the fold. Wide
  desktop uses the sidebar instead of duplicating those shortcuts; tablet keeps
  them after prioritized content, while mobile/TV retain touch- and
  remote-friendly ordering. The official Top 100 rail exposes an “ALL” route to
  the full catalog. Quick Play becomes a Zing-style “You may like”
  hero built from compact horizontal cards, left-side square artwork, and the
  coral–plum gradient: two cards on desktop/tablet, three on wide TV, and a
  next-card peek on mobile. Edge-centered paging supports mouse, keyboard, and remote navigation.
  The editorial carousel that follows is a low, full-width panorama: official
  artwork stays intact without title or Play overlays, while mobile still
  previews the next card. It auto-advances while idle like
  Zing MP3, pauses immediately on hover, focus, or touch drag, and stays still
  when the OS requests reduced motion;
  every collection rail keeps swipe navigation on mobile, adds previous/next
  controls on tablet, desktop, and TV only when content overflows, and safely
  resets to the first card when its category changes;
  cards expose a Zing-style hover/focus action deck: the card opens in-app
  details, Heart saves/removes the collection locally, Play starts the first
  eligible track, and More exposes Play, details, save, and official-link
  sharing. On desktop, right-clicking a card opens that same action menu. The
  queue preserves official order and playable tracks only. Discovery rails,
  Hub/Top 100, and New Releases albums keep every validated artist as a
  separate hover/focus link that opens the in-app profile without activating
  the collection card. A “Featured MVs” rail presents
  validated official videos, opens Zing on mobile/web/desktop, and uses QR
  handoff on TV; the app never relays or downloads MV media. The proxy ignores `adBanner`
  and never loads third-party advertising. Its “Song Suggestions /
  Refresh” shelf prefers playable Zing catalog results, renders up to nine
  items as a 3×3 desktop/TV matrix with an action deck on hover/focus, and keeps
  a More menu reachable on mobile for likes, queue/playlist, Song Info, Radio,
  and sharing. Desktop right-click opens that exact menu and every playable
  song menu includes Play Now. Official metadata keeps each credited artist as a hover/focus
  link that opens the in-app profile without starting playback or replacing the
  queue. It then falls back to the current on-device chart. Neither path uploads favorites,
  analytics, or listening history to the proxy. A separate “Recently Played”
  rail reads up to 10 deduplicated tracks from local history, starts the exact
  history queue, and remains available when network Discovery fails. Every card
  reuses the Play/Info/Queue/Radio/Playlist/Share/Like/Mood menu; desktop adds
  right-click parity and TV exposes it through focus/remote navigation. A Home
  “New Release Chart” spotlight presents the top three ranks, preserves locked
  states, and builds its queue in rank order from playable tracks only. Locked
  tracks keep safe metadata/library actions but never expose Play, Queue, or
  Radio.
- Topic & Genre browsing by nation, mood, and activity, plus Top 100 rails for
  Featured, Vietnam, Asia, US-UK, and Instrumental catalogs; playlist/album
  artist names retain Zing-style in-app navigation.
- Large desktops use a Zing MP3-inspired grouped sidebar for Library,
  Discovery, #zingchart, LIVE Radio, New Release Chart, Topics & Genres, Top
  100, and For You. Hub/Top 100 open directly, with Create playlist and Playback
  queue actions in the footer. Back/Forward keeps up to 50 in-shell
  tab, search, artist, and album/playlist states, with `Alt+←/→` on desktop.
  On tablet and desktop, Back/Forward, search, and Settings stay pinned while
  content scrolls; Discovery also pins its category rail directly underneath.
  Wide desktop adds a Personal avatar and a Local Profile card
  in the sidebar with real like, playlist, and listening-minute counts. Both
  open the on-device profile without pretending a cloud account exists.
  Tablets/TV retain the rail. Phones use a five-item bottom bar:
  `Library · Discovery · #zingchart · Radio · Personal`; Personal groups the
  private on-device profile, likes, playlists, followed artists, Daily/Mood
  Mixes, analytics, and Wrapped without requiring an account. The full New
  Release Chart remains available from Discovery instead of taking another
  primary navigation slot.
- Official song, artist, lyrics, playlist/album, and MV search with Zing-style
  autocomplete for up to four keywords and six song previews, controllable by
  mouse, keyboard, or TV remote. Selecting a song preview resolves the exact
  public song ID into Song Info without autoplay and exposes Play only after
  official metadata confirms eligibility; per-row loading and request guards
  prevent stale details from opening. Full results retain debouncing,
  All/Songs/Playlists-Albums/Artists/MV sections, Zing-style highlights,
  responsive in-shell artist and collection detail pages, and a local
  #zingchart fallback. Collection detail also exposes the official like count,
  release date, distributor, and genres. After the track list, a circular
  Participating Artists rail supports local follow and in-app profiles, followed
  by official “Appears in”/“You may also like” rails whose cards share
  Play/Save/More/Share actions, right-click parity, and keyboard/TV navigation.
  From 1200 px, whenever the remaining content area is wide enough,
  collection detail becomes a Zing-style two-column workspace: artwork, title,
  artists, update date, and actions on the left; an expandable preface and track
  list on the right. Albums use Play All, numbered tracks, and no duplicated
  Album column; playlists use Shuffle Play and retain the Album column. Opening
  queue/lyrics switches the table from actual content constraints into compact
  mode instead of overflowing. Phone/tablet retain the adaptive hero and TV
  keeps its focus-friendly layout. From 1180 px, artist profiles use a full-width Zing OA-style purple
  hero with a circular avatar, oversized name, circular Play, follower count,
  Follow, and Share. Directly below it, wide layouts pair Latest Release with
  three Featured Songs in the same two-column hierarchy as the official artist
  page; constrained content stacks the sections and hides secondary metadata
  instead of overflowing. Mobile/tablet/TV keep appropriate touch and focus targets.
  Single/EP, album, and compilation rails share Play/Save/More/Share actions
  with matching right-click menus; desktop pages by local content width, mobile
  swipes horizontally, and TV uses D-pad/Enter. Related artists can be followed
  locally from their cards.
  Validated artist identities remain hover/focus links into in-app profiles and
  an on-device Save-to-Library action. “Play all” builds a
  queue from every authorized track. While results load, an adaptive skeleton
  preserves the `Highlights → Playlists`
  hierarchy across mobile, tablet, desktop, and TV. With Reduce Motion enabled,
  its progress indicator becomes static. The All tab follows Zing's official order:
  `Highlights → Featured playlists → 6 songs → Playlists/Albums → MV → Artists/OA`.
  Highlights use three equal-height cards: one circular-avatar artist and two
  square-artwork songs, retaining only the content type, title, artist/follower
  count shown by Zing; album, duration, and detailed actions stay in the Songs
  list below. Artists/OA use a responsive 2/3/5-column circular-avatar grid matching Zing's
  search surface, with hover, focus, TV-remote activation, and an official
  follower count only when the API supplies a real value. The Songs tab uses
  Zing-style compact rows with 40 px artwork, artist, a middle album column,
  two-digit duration at the right edge, and desktop actions revealed only on
  hover or focus. The Playlists/Albums tab uses lightly rounded square artwork,
  a single-line title, up to two artist lines, and an adaptive 2/3/4/5-column
  grid. Its Zing-style Play layer appears only on hover/focus while the full
  card remains openable by touch, click, Enter, or TV remote. The MV tab uses
  16:9 thumbnails, two-digit duration labels, validated official artist
  avatars, and single-line metadata; its Play layer also appears only on
  hover/focus before opening the trusted Zing/QR handoff.
  each See all action opens the complete section. The player also supports
  play/pause/stop, seek, previous/next, shuffle,
  repeat, volume/mute, queue management, and sleep timer.
  The “Playing from” header preserves the real queue source—chart, search,
  album, artist, weekly chart, new releases, Library, Song Radio, or LIVE—and
  keeps that context across Next/Previous and local session restore.
  Streaming quality is
  real and signed into the relay URL: Auto prefers 320 kbps then falls back to
  128, Data Saver requires 128, and High requires an available 320 kbps source.
  If a 320 source fails, Now Playing offers Retry or one-tap Auto recovery while
  preserving the current track and queue.
- After a song is selected, desktop keeps the catalog visible by default and
  shows a Zing MP3-style horizontal playback dock with metadata, transport,
  progress, volume, and direct official MV, Lyrics/Karaoke, Now Playing, and
  Playback queue actions. The More button beside Like opens Song details, Song
  Radio, Add to playlist, and official Zing link sharing. MV metadata is loaded
  only after the user clicks and still uses the validated Zing handoff; narrow
  desktop layouts hide the expanded shortcuts to protect transport space. The right drawer has Queue,
  Recently played, and Lyrics tabs: the queue supports play, reorder, per-track
  removal, or a confirmed clear that preserves the active song, progress, and
  playback origin across phone, desktop, and TV. History stays local, and synced lyrics follow the active line, seek
  on tap, and expand to full-screen Karaoke. The dock remains visible while it
  is open.
  The drawer has an explicit close/Escape path and the full-screen option
  remains available. Mobile retains its compact mini-player and TV retains the
  remote-first 10-foot panel.
- The mobile mini-player follows Zing's hierarchy: a thin top progress line,
  artwork, song/artist metadata, Play/Pause, and Next in a 76 px bar directly
  above the five-tab navigation. Stop remains in full Now Playing, avoiding a
  destructive playback action on the frequently tapped mini surface.
- A header Settings action opens a bottom sheet on phones or a dialog on
  tablet/desktop/TV. It centralizes theme, shuffle, Smart Shuffle, repeat, Song Radio
  autoplay, sleep timer, a desktop preference to always open full-screen Now
  Playing, Auto/128/320 kbps streaming quality, and Local-First counters. Every
  choice is wired to the real controller and persisted on-device; there are no
  placeholder toggles.
- Mobile Now Playing follows a closer Zing MP3 hierarchy: artwork and metadata
  stay central, the truthful Auto/128/320 kbps badge opens the quality picker,
  transport remains isolated, and Lyrics/Queue/Song Radio/Sleep Timer live in a
  stable action dock. Song Info, Smart Shuffle, and Car Mode remain available in
  a compact utility group; the app never labels a source Lossless when playback
  currently tops out at 320 kbps.
- Car Mode can be enabled from Settings or Now Playing. It keeps artwork,
  progress, and large Previous/Play/Next/Stop controls while removing secondary
  actions, and its state is stored on-device. This is an in-app
  distraction-reduced surface; it does not claim Android Auto or Apple CarPlay
  integration.
- An in-player Song Info page presents authoritative artist, album, release,
  distributor, genre, composer, listen, like, and comment metadata. MVs only
  open a validated official Zing page or use QR/copy handoff on TV and
  platforms without a launcher.
- Official Zing MP3 links can be shared for songs, artists, and
  playlists/albums. Mobile, web, and desktop prefer the native share sheet;
  TVs and unsupported adapters use QR plus copy. The payload never includes
  local history, favorites, or analytics.
- Official Zing MP3 links open directly inside the app: paste a URL into search
  to route to songs, MVs, artists, albums/playlists, hubs, Top 100, weekly
  charts, new-release charts, or LIVE Radio. Song links open the information
  panel and wait for an explicit Play action; `/video-clip/` links open a
  confirmation handoff with an Open Zing MP3 action or a TV QR. External
  launches never autoplay. Android
  registers a best-effort HTTPS handoff;
  iOS, macOS, Windows, Linux, and HarmonyOS use
  `zingchart://open?url=...`; Web accepts an encoded `?open=<URL>` query. The
  parser only accepts known HTTPS Zing hosts and paths and never forwards an
  arbitrary URL to the proxy.
- Mobile/desktop Now Playing and collection detail reuse already-loaded artwork
  as a blurred, cross-fading atmosphere. A contrast scrim and local gradient
  fallback keep it readable without another API request or personal data.
- Launcher, PWA, desktop, watch, and TV surfaces share one original `# + pulse`
  mark in the existing ink/coral/lime palette. Android includes adaptive and
  monochrome layers; Apple assets are opaque RGB PNGs, and every required size
  is regenerated with `node tool/generate_brand_assets.mjs`.
- Song Radio loads up to 30 authorized similar tracks from a song menu or Now
  Playing, and autoplay can extend the queue when playback reaches its end.
- Smart Shuffle interleaves up to 10 suggestions from the currently loaded
  catalog, ranks them with on-device likes/analytics, and marks every inserted
  item as `SMART`. Listening taste, favorites, and history never reach the proxy.
- LIVE Radio shows V-Pop, Bolero, US-UK, K-Pop, and current-program rooms; HLS
  playlists and media stay on the proxy origin and never expose CDN URLs.
- Immersive Zing-style Lyrics/Karaoke switches to word-level highlighting when
  upstream provides word timestamps, keeps line auto-scroll and tap-to-seek,
  then falls back to line timing or plain text when needed.
- Lyric Card selects up to four lines, previews them, then exports a local PNG
  through the platform share/download/save path; TV uses an on-device QR.
  Rendering never fetches artwork or uploads lyrics, history, or analytics.
- Background playback and native media controls where the OS supports them.
- A Local-First Library uses Zing-style Overview, Songs, Playlists, Albums, and
  Artists sections. Favorites, followed artists/OAs, saved Zing
  albums/playlists, personal playlists, history, recent searches, Daily/Mood
  Mix, 7/30-day and yearly analytics all remain account-free and on-device.
- Six-slide Mini Wrapped remains available year-round.
- JSON backup v3 with idempotent Merge and full Overwrite modes; v1/v2 remain
  importable.
- Responsive phone/tablet/desktop UI and remote-first 10-foot TV UI.
- Catalog updates use a dedicated signal: position, duration, and volume ticks
  rebuild the player only instead of the full Home, Discovery, or chart list;
  favorites, queue, and library changes still update immediately.
- Light, dark, and system themes using the existing charcoal/coral/lime visual
  language.

### Opening Zing MP3 links

- In the app, press the chain-link icon in search to paste a URL, or paste it
  directly and press Enter/Search.
- MV links shaped as `https://zingmp3.vn/video-clip/.../<id>.html` always wait
  for **OPEN ZING MP3**; TVs expose QR/copy only to prevent launcher loops.
- Cross-platform scheme:
  `zingchart://open?url=https%3A%2F%2Fzingmp3.vn%2Ftop100`.
- Web/PWA:
  `https://<client-host>/?open=https%3A%2F%2Fzingmp3.vn%2Ftop100`.
- Android HTTPS handoff is best-effort: some devices or older releases may show
  a chooser, while Android 12+ normally opens an unverified domain in the default
  browser. The reliable paths are the custom scheme and paste action. Because
  Zing MP3 owns the domain, this project does not claim a verified Android App
  Link or Apple Universal Link.

Offline audio download is intentionally disabled until a licensed source and
storage rights are available. The PWA caches only the app shell and non-audio
data.

## Screenshots by release

These images are rendered from the current UI with deterministic, fully local
demo data, then grouped by feature milestone. They are not archived captures of
historical binaries and contain no real user data.

### v1.0 — Chart, player, and cross-platform library

<table>
  <tr>
    <td width="33%" align="center"><img src="docs/screenshots/v1.0-home-mobile.png" alt="Realtime ZingChart home on mobile"><br><sub><b>Home</b> · realtime chart and Daily Mix</sub></td>
    <td width="33%" align="center"><img src="docs/screenshots/v1.0-search-mobile.png" alt="Music search on mobile"><br><sub><b>Search</b> · songs, artists, and recent queries</sub></td>
    <td width="33%" align="center"><img src="docs/screenshots/v1.0-now-playing-mobile.png" alt="Now Playing on mobile"><br><sub><b>Now Playing</b> · seek, queue, moods, and sleep timer</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/v1.0-library-mobile.png" alt="Local-First library on mobile"><br><sub><b>Library</b> · favorites, playlists, and local backup</sub></td>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.0-desktop-player.png" alt="Adaptive desktop layout with Now Playing and queue panels"><br><sub><b>Adaptive desktop</b> · chart, Now Playing, and queue in one workspace</sub></td>
  </tr>
</table>

### v1.1 — Local Intelligence

<table>
  <tr>
    <td width="33%" align="center"><img src="docs/screenshots/v1.1-for-you-mobile.png" alt="Daily Mix and Mood Mix in For You"><br><sub><b>For You</b> · on-device Daily Mix and Mood Mix</sub></td>
    <td width="33%" align="center"><img src="docs/screenshots/v1.1-analytics-mobile.png" alt="Local listening analytics dashboard"><br><sub><b>Analytics</b> · 7-day, 30-day, and yearly views</sub></td>
    <td width="33%" align="center"><img src="docs/screenshots/v1.1-wrapped-mobile.png" alt="Exportable Mini Wrapped"><br><sub><b>Mini Wrapped</b> · six slides with PNG export</sub></td>
  </tr>
  <tr>
    <td colspan="3" align="center"><img src="docs/screenshots/v1.1-tv-for-you.png" alt="For You TV layout with remote focus and player panel"><br><sub><b>10-foot TV UI</b> · remote navigation, local mixes, and player panel</sub></td>
  </tr>
</table>

### v1.2 — Zing MP3 catalog discovery

<table>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-desktop-sidebar.png" alt="#zingChart desktop with the grouped catalog sidebar, realtime chart, official Suggestion row with artist and album, and playback dock"><br><sub><b>Desktop catalog workspace</b> · 24-hour chart, official Suggestion with in-app artist/album navigation, chart metadata, and playback dock in one screen</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-desktop-playback-dock.png" alt="#zingChart desktop with MV Lyrics Now Playing song menu shortcuts and the playback queue drawer"><br><sub><b>Zing MP3-style dock & queue drawer</b> · direct MV, Lyrics/Karaoke, Now Playing and song actions; reorderable queue and on-device history</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-desktop-lyrics-drawer.png" alt="#zingChart desktop with synchronized Lyrics inside the player drawer"><br><sub><b>Synced lyrics beside the catalog</b> · follow the active line, tap to seek, or expand full-screen Karaoke without leaving the current page</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-library-workspace-desktop.png" alt="Desktop Library with Overview Songs Playlists Albums and Artists sections"><br><sub><b>Zing-style, Local-First Library</b> · five responsive sections, personal playlists, and saved official content without an account</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-realtime-chart-desktop.png" alt="Interactive 24-hour ZingChart plot with data points and the selected-song tooltip"><br><sub><b>24-hour chart pulse</b> · hover, touch/drag, or remote navigation to inspect hourly share and play the selected song</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-chart-top-100-desktop.png" alt="#zingchart ranks 1 through 10 with the View top 100 action"><br><sub><b>Top 10 → Top 100</b> · compact by default like Zing MP3, expanded in place with the complete queue preserved</sub></td>
  </tr>
  <tr>
    <td width="50%" align="center"><img src="docs/screenshots/v1.2-discovery-home-desktop.png" alt="Discovery Home with compact You may like cards and a full-width panorama banner"><br><sub><b>Discovery</b> · Zing-style left artwork, an overlay-free panorama, and accessible carousel controls</sub></td>
    <td width="50%" align="center"><img src="docs/screenshots/v1.2-new-releases-desktop.png" alt="New Release Chart with rank, movement, linked artist and album, and duration on desktop"><br><sub><b>New Release Chart</b> · in-app artist/album navigation, rank movement, duration, and a playable-only queue</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-discovery-mv-desktop.png" alt="Official Featured MVs rail on Discovery Home"><br><sub><b>Featured MVs</b> · adaptive 16:9 cards, validated Zing pages, and TV QR handoff</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-discovery-new-releases-desktop.png" alt="Three-column New Releases shelf on Discovery Home"><br><sub><b>New Releases on Home</b> · 12 tracks, All/Vietnam/International filters, and locked-track-safe queues</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-discovery-recent-desktop.png" alt="Local-first Recently Played rail on Discovery Home"><br><sub><b>Recently Played</b> · private on-device history, a deduplicated queue, and no proxy upload</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-discovery-new-release-chart-desktop.png" alt="Top-three New Release Chart spotlight on Discovery Home with rank movement"><br><sub><b>New Release Chart Top 3</b> · responsive spotlight, locked states, and a playable-only queue</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-search-suggestions-desktop.png" alt="Zing-style search autocomplete with keyword and song suggestions"><br><sub><b>Search autocomplete</b> · song previews open Song Info before explicit Play, with mouse, keyboard, and TV-remote control</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-search-all-desktop.png" alt="All results with three equal-height Zing-style Highlight cards"><br><sub><b>All · Highlights</b> · one artist, two songs, a real follower count, and responsive 1/2/3-column layout</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-search-mv-desktop.png" alt="Zing-style official MV results on desktop"><br><sub><b>Official MV search</b> · 16:9 artwork, duration, artist avatar, and hover/focus overlay; opens through a trusted Zing link or TV QR handoff</sub></td>
  </tr>
  <tr>
    <td width="50%" align="center"><img src="docs/screenshots/v1.2-hubs-desktop.png" alt="Topic and Genre browsing by nation, mood, activity, and genre"><br><sub><b>Topics & Genres</b> · responsive hub navigation into playlist and album detail</sub></td>
    <td width="50%" align="center"><img src="docs/screenshots/v1.2-top-100-desktop.png" alt="Top 100 grouped by music market"><br><sub><b>Top 100</b> · Featured, Vietnam, Asia, US-UK, and Instrumental playlist rails</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-release-catalog-desktop.png" alt="New Releases with per-track artist album duration and market filters"><br><sub><b>New Releases</b> · each song exposes navigable artist/album and duration metadata, plus the Albums tab, market filters, release time, and fail-closed playback</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-artist-profile-desktop.png" alt="Zing OA-style artist profile with a purple hero and Latest Release beside Featured Songs"><br><sub><b>Artist/OA</b> · full-width hero plus two-column Latest Release/Featured Songs; ALL opens up to 50 songs, Single & EP, or MV inside the app</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-artist-follow-desktop.png" alt="Artist profile with an on-device Following state"><br><sub><b>Follow artists</b> · account-free OA following, restored by backup v3 and reopened from Library</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-artist-catalog-actions-desktop.png" alt="Artist Single EP rail with Play Save and More actions plus a separate MV rail with a play overlay"><br><sub><b>Artist catalog</b> · Collections expose Play/Save/More/Share; MVs use a dedicated play overlay; rails support mouse, swipe, keyboard, and TV remote</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-collection-save-desktop.png" alt="Official album in a Zing-style two-column workspace with artwork left and numbered tracks right"><br><sub><b>Official albums/playlists</b> · type-aware CTA, numbered album tracks or playlist Album column, fail-closed locked songs, and Local-First Saved state</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-collection-information-desktop.png" alt="Release information, participating artists, and related official collections on a collection detail page"><br><sub><b>Collection information</b> · compact metadata, locally followed participating artists, and related rails with Play/Save/Share</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-weekly-chart-desktop.png" alt="Weekly Chart with three regions, a period picker, and linked artist and album"><br><sub><b>Weekly Chart</b> · Vietnam/US-UK/K-Pop, in-app artist/album navigation, rank movement, duration, and a playable-only queue</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-song-detail-desktop.png" alt="Official Song Info page on desktop"><br><sub><b>Song Info</b> · metadata, engagement, in-app artist/album navigation, official-link sharing, and MV handoff</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-synced-lyrics-desktop.png" alt="Immersive Karaoke with word-level highlighting"><br><sub><b>Karaoke & lyrics</b> · large artwork, word sync, tap-to-seek, and adaptive phone/desktop/TV layout</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-lyric-share-desktop.png" alt="Lyric Card composer with multi-line selection and share-image preview"><br><sub><b>Lyric Card</b> · select up to four lines, render PNG locally, and use an on-device QR on TV</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-car-mode-desktop.png" alt="#zingChart Car Mode with large playback controls and a reduced interface"><br><sub><b>Car Mode</b> · glanceable metadata, clear progress, and large Previous/Play/Next/Stop controls</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-song-radio-desktop.png" alt="Song Radio and autoplay in the desktop player panel"><br><sub><b>Song Radio</b> · authorized recommendations, queue extension, and autoplay controls on phone/desktop/TV</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-smart-shuffle-desktop.png" alt="Desktop queue with Smart Shuffle and clearly marked inserted songs"><br><sub><b>Smart Shuffle</b> · interleave local-first suggestions, preserve original tracks, and label every automatic addition</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-stream-quality-desktop.png" alt="Auto 128 and 320 kbps streaming-quality picker"><br><sub><b>Real streaming quality</b> · Auto prefers 320 then 128, while explicit 128/320 keeps the selected bitrate through the signed relay</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.2-live-radio-desktop.png" alt="LIVE Radio rooms for V-Pop Bolero US-UK and K-Pop"><br><sub><b>LIVE Radio</b> · live rooms, current programs, listener counts, and same-origin HLS on phone/desktop/TV</sub></td>
  </tr>
</table>

The deterministic gallery fixture lives in
[`tool/docs_screenshot_app.dart`](tool/docs_screenshot_app.dart). It never calls
the proxy, real audio, or an operating-system media service.
Cross-platform icons come from
[`assets/brand/zingchart-mark.svg`](assets/brand/zingchart-mark.svg); run
`node tool/generate_brand_assets.mjs --check` to detect missing or stale output.

## Widgets and smartwatch remotes

| Surface | Minimum/support | Controls |
| --- | --- | --- |
| Android Home Widget | Android phone/tablet | Previous, play/pause, next |
| Fire OS tablet | Included in the Android APK; visibility depends on launcher widget support | Previous, play/pause, next |
| iOS/iPadOS WidgetKit | iOS/iPadOS 17+ | Interactive App Intent controls |
| macOS WidgetKit | macOS 14+ | Previous, play/pause, next |
| HarmonyOS Service Widget | HarmonyOS 5.1/API 18 | Previous, play/pause, next |
| Wear OS remote | Wear OS 3+ paired to Android | Data Layer RPC and player state |
| watchOS remote | watchOS 10+ paired to iPhone | WatchConnectivity RPC and player state |
| Windows/Linux/Web/TV | No portable home-widget API in v1 | Existing SMTC, MPRIS, Media Session, or TV remote controls |

All companion surfaces use the same throttled, versioned player snapshot.
They never receive listening history, favorites, stream URLs, or analytics,
and no companion data is sent to the proxy.

## Architecture

```text
Flutter UI + PlaybackService
        │
        ├── SystemMediaBridge → lock screen / SMTC / MPRIS / Media Session
        ├── CompanionBridge   → widgets / Wear OS / watchOS
        └── MusicRepository   → self-hosted Node/Fastify proxy
                                      │
                                      ├── chart + catalog search → Zing upstream
                                      ├── authorized new releases → Zing upstream
                                      ├── authorized weekly charts → Zing upstream
                                      ├── authorized synced lyrics → Zing upstream
                                      ├── authorized Song Radio   → Zing upstream
                                      ├── authorized LIVE Radio   → Zing upstream
                                      ├── encrypted HLS relay     → Zing CDN
                                      └── signed stream relay   → Zing upstream
```

| Component | Location |
| --- | --- |
| Flutter app and Local-First services | `lib/` |
| Proxy and tests | `proxy/` |
| Native runners | `android/`, `ios/`, `macos/`, `windows/`, `linux/`, `web/` |
| Wear OS and Apple companions | `android/wear/`, `ios/ZingChartWatch/`, `ios/ZingChartWidget/`, `macos/ZingChartWidget/` |
| Fire/Harmony/TV/installer tooling | `packaging/` |
| CI and release matrix | `.github/workflows/` |

## Prerequisites

- Git, FVM, Flutter `3.44.7`, and the bundled Dart `3.12.2`.
- Node.js `22+` for the proxy, or Docker.
- A reachable proxy URL. Public release builds require HTTPS.
- Android: Android SDK 36 and JDK 17+.
- Apple: macOS, full Xcode, CocoaPods, and Ruby gem `xcodeproj 1.27.0`.
- Windows: Visual Studio 2022 with Desktop development with C++.
- Linux: Clang, CMake, Ninja, GTK 3, LZMA, and GStreamer development packages.
- HarmonyOS: CPF-Flutter `3.41.10-ohos-1.0.0`, Dart `3.11.5`, DevEco tools,
  and HarmonyOS SDK 5.1/API 18.

## First-time setup

```sh
git clone https://github.com/LamPPKK/Zing-Chart.git
cd Zing-Chart
fvm install 3.44.7
fvm use 3.44.7
fvm flutter pub get
```

Start the development proxy:

```sh
cd proxy
cp .env.example .env
set -a
. ./.env
set +a
npm ci
npm run dev
```

Verify it from another terminal:

```sh
curl http://localhost:8080/health
curl http://localhost:8080/v1/chart
curl http://localhost:8080/v1/charts/new-releases
curl 'http://localhost:8080/v1/charts/weekly?region=vietnam'
curl 'http://localhost:8080/v1/charts/weekly?region=usuk&week=33&year=2026'
curl http://localhost:8080/v1/discovery/categories
curl http://localhost:8080/v1/discovery/recommendations
curl 'http://localhost:8080/v1/discovery/home?categoryId=-1'
curl 'http://localhost:8080/v1/discovery/home?categoryId=14'
curl http://localhost:8080/v1/hubs
curl http://localhost:8080/v1/hubs/IWZ9Z09B
curl http://localhost:8080/v1/top-100
curl http://localhost:8080/v1/releases
curl http://localhost:8080/v1/artists/Son-Tung-M-TP
curl --get http://localhost:8080/v1/search/suggestions --data-urlencode 'q=Sơn Tùng M-TP'
curl --get http://localhost:8080/v1/search --data-urlencode 'q=Sơn Tùng M-TP'
curl http://localhost:8080/v1/collections/6DIZIU79
curl http://localhost:8080/v1/songs/ZW79ZBE8/detail
curl http://localhost:8080/v1/songs/Z9WE0E96/lyrics
curl http://localhost:8080/v1/songs/Z9WE0E96/radio
curl http://localhost:8080/v1/radio
curl http://localhost:8080/v1/radio/IWZ979UB/source
```

Run Flutter on a selected device:

```sh
fvm flutter devices
fvm flutter run -d <device-id> \
  --dart-define=API_BASE_URL=http://localhost:8080
```

Use an HTTPS proxy reachable by the device for physical phones, tablets, TVs,
and release builds. `https://api.example.invalid` is a deliberate diagnostic
placeholder and never falls back to direct Zing access.

With authorized current-API credentials, full search signs the official request
inside the proxy and returns songs (including lyric capability), artists/OA,
playlists/albums, and public MV metadata. Playback fails closed unless a song has
`streamingStatus = 1`. MVs are never relayed or downloaded: the app opens only a
validated official `zingmp3.vn/video-clip/` page, with a QR/copy fallback on TV
and unsupported platforms. Without credentials, the legacy search keeps the
same response shape but does not infer catalog playability or return MVs.
Collection detail is normalized by the proxy from public metadata and track
lists. Current-chart songs reuse their working legacy code; current-API
credentials remain server-side and are never embedded into Flutter.
The new-release chart also requires that authorized adapter. It is cached by
the proxy and treats only `streamingStatus = 1` as playable.
The official Weekly Chart is available from `GET /v1/charts/weekly` for
`vietnam`, `usuk`, and `korea`. `week` and `year` are optional as a pair; when
omitted, upstream selects the latest period. Requests are signed server-side,
single-flight cached per region/period, and fail closed for playback unless
`streamingStatus = 1`.
`GET /v1/songs/{code}/lyrics` signs the lyrics request in the proxy, normalizes
karaoke sentences into `startTimeMs`/`endTimeMs` lines, and falls back to plain
lyrics when timestamps are unavailable. Flutter never fetches an external
lyrics file directly; results are cached and single-flighted by song code.
`GET /v1/songs/{code}/radio` signs the recommendation request only on the
proxy, then keeps at most 30 unique, non-private, non-pre-release tracks whose
`streamingStatus` is exactly `1`. Results use a short single-flight cache;
favorites, analytics, and local listening history are never uploaded.
`GET /v1/radio` returns a normalized LIVE Radio directory. Its source endpoint
returns only an encrypted first-party token; the proxy allowlists and rewrites
HLS playlists, keys, maps, and segments onto `/v1/live-streams/{opaqueToken}`.
Flutter never receives a CDN URL or credential, and LIVE sessions are excluded
from listening analytics, history, recommendations, and local backup.
Discovery Home uses the same authorized server-side adapter to normalize the
Quick Play carousel, editorial banners, Top 100, Chill, and Hot Albums. The
proxy ignores third-party `adBanner` payloads. It is single-flight cached for
`SEARCH_CACHE_TTL_MS`; opening a card reuses the collection-detail flow and no
local listening history or analytics is sent upstream.

The “Recently Played” rail is Local-First data rendered directly by Flutter
from on-device history. The proxy has no endpoint, parameter, or payload for
this rail. Clearing listening history also clears the rail without affecting
favorites. Its action menu reuses the same contract as other song rows without
sending local history over the network.
`GET /v1/discovery/recommendations` signs the anonymous Song Station request on
the proxy and retains at most 12 public tracks whose `streamingStatus` is
exactly `1`. The request contains no installation ID or local profile data;
the client falls back to its current on-device chart if the endpoint is offline.
Topic & Genre Home, hub detail, and Top 100 are exposed as `/v1/hubs`,
`/v1/hubs/{id}`, and `/v1/top-100`. They preserve upstream ordering, drop
malformed cards, share the authorized adapter and single-flight cache, and
never receive Local-First history or analytics.

`GET /v1/releases` combines the current Songs and Albums release catalogs,
normalizes Vietnam, US-UK, Korea, and Other regions, and only reports a song as
playable when `streamingStatus` is exactly `1`. It uses a short single-flight
cache and never receives listening history or personal client data. Discovery
Home reuses this snapshot for its 12-song Zing-style shelf; International
combines non-Vietnam regions and every playback queue excludes locked tracks.

`GET /v1/artists/{alias}` returns an authoritative Artist/OA profile with
metadata, follower count, six featured songs, up to 50 songs from the signed
artist catalog, up to 50 public MVs for the All view, singles, albums,
compilations, related artists, and a plain-text biography. The app routes the
official `/{alias}/bai-hat`, `/{alias}/single`, and `/{alias}/video` URLs to
their internal sections, with an ALL action on each overview group. If the
full catalog request fails, the proxy retains the featured-song section as a
fallback. The proxy caps each group, drops
malformed children, enables playback only for `streamingStatus = 1`, and
single-flight caches each alias without exposing signing credentials.

## Verification

```sh
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze
fvm flutter test --reporter expanded

cd proxy
npm ci
npm run typecheck
npm test
npm run build
cd ..

node --test \
  packaging/apple/*.test.mjs \
  packaging/fireos/*.test.mjs \
  packaging/harmonyos/*.test.mjs \
  packaging/tv/*.test.mjs \
  packaging/wearos/*.test.mjs
```

## Build by platform

Set these examples to real values:

```sh
API_BASE_URL=https://proxy.example.com
VERSION=1.1.0
```

### Android phone, tablet, Android TV, and Home Widget

```sh
fvm flutter build apk --release \
  --dart-define=API_BASE_URL="$API_BASE_URL"
fvm flutter build appbundle --release \
  --dart-define=API_BASE_URL="$API_BASE_URL"
```

Outputs are `build/app/outputs/flutter-apk/app-release.apk` and
`build/app/outputs/bundle/release/app-release.aab`. The same package contains
the Android Home Widget and optional Leanback launcher. To force the TV UI for
sideload testing, add `--dart-define=TV_MODE=true`.

For production signing, put the keystore at `android/app/release.jks` and
create the ignored `android/key.properties`:

```properties
storeFile=release.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=YOUR_KEY_ALIAS
keyPassword=YOUR_KEY_PASSWORD
```

### Wear OS remote

Build the Android app first so Flutter writes the shared version metadata,
then build the watch module:

```sh
./android/gradlew -p android :wear:assembleRelease
```

Output: `build/wear/outputs/apk/release/wear-release.apk`.

The phone and watch APKs deliberately share application ID
`software.baycho.zmp3chart` and must be signed by the same certificate. Install
each APK on its matching device, open the phone app once, then launch
**#zingChart Remote** on the paired Wear OS watch.

### iOS/iPadOS WidgetKit and watchOS

```sh
gem install xcodeproj -v 1.27.0 --no-document
ruby packaging/apple/prepare_ios_companions.rb
fvm flutter build ios --release --no-codesign \
  --dart-define=API_BASE_URL="$API_BASE_URL"
```

The generated `Runner.app` embeds `ZingChartWidget.appex` and
`ZingChartWatch.app`. For signed distribution, register:

- App Group `group.software.baycho.zmp3chart.shared`;
- bundle IDs `software.baycho.zmp3chart.widget` and
  `software.baycho.zmp3chart.watchkitapp`;
- separate Runner, Widget, and Watch provisioning profiles under one team.

Widget controls require iOS/iPadOS 17+. The watch remote requires watchOS 10+
and an iPhone pairing. It controls phone playback; it does not download audio.

### Web/PWA

```sh
fvm flutter build web --release \
  --dart-define=API_BASE_URL="$API_BASE_URL"
python3 -m http.server 8081 --directory build/web
```

Deploy `build/web/` on HTTPS with SPA fallback to `index.html`. The browser's
autoplay and background rules still apply; closing the tab ends playback.

### Windows

Build only on Windows:

```powershell
flutter config --enable-windows-desktop
flutter build windows --release `
  --dart-define=API_BASE_URL="https://proxy.example.com"
.\packaging\windows\package_windows.ps1 -Version 1.1.0
.\packaging\windows\package_msix.ps1 -Version 1.1.0
```

This is a packaged Flutter Win32 application, not a UWP runner. SMTC supplies
system controls; no Windows Widget provider is shipped in v1.

### macOS and WidgetKit

```sh
fvm flutter config --enable-macos-desktop
gem install xcodeproj -v 1.27.0 --no-document
ruby packaging/apple/prepare_macos_widget.rb
fvm flutter build macos --release \
  --dart-define=API_BASE_URL="$API_BASE_URL"
./packaging/macos/package_macos.sh
```

The widget requires macOS 14+ and the shared App Group. Public distribution
also requires Developer ID signing, hardened runtime, notarization, and
stapling.

### Linux x64

```sh
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev \
  liblzma-dev libfuse2 libgstreamer1.0-dev \
  libgstreamer-plugins-base1.0-dev
fvm flutter build linux --release \
  --dart-define=API_BASE_URL="$API_BASE_URL"
./packaging/linux/package_linux.sh "$VERSION"
```

The script creates a portable archive and DEB, plus AppImage when a reviewed
`LINUXDEPLOY` binary is provided.

### Amazon Fire OS and Fire TV

```sh
FIREOS_FLUTTER_BIN="$(fvm which flutter)" FIREOS_BUILD_NUMBER=1 \
  ./packaging/fireos/build_fireos.sh "$API_BASE_URL" "$VERSION" touch
FIREOS_FLUTTER_BIN="$(fvm which flutter)" FIREOS_BUILD_NUMBER=1 \
  ./packaging/fireos/build_fireos.sh "$API_BASE_URL" "$VERSION" tv
```

Fire touch and TV use unique version codes `2N` and `2N+1`. Release mode fails
closed without the production Android signing secrets. Fire TV has no home
widget; Fire tablet widget placement depends on the Amazon launcher.

### LG webOS and Samsung Tizen TV

```sh
TV_FLUTTER_BIN="$(fvm which flutter)" \
  ./packaging/tv/build_tv_web.sh webos "$API_BASE_URL" "$VERSION"
TV_FLUTTER_BIN="$(fvm which flutter)" \
  ./packaging/tv/build_tv_web.sh tizen "$API_BASE_URL" "$VERSION"
./packaging/tv/package_tizen.sh YOUR_SAMSUNG_CERT_PROFILE
```

webOS requires `@webos-tools/cli@3.2.5`. Tizen requires Tizen Studio, TV
Extension, and a Samsung certificate. Packaged file-based TV clients require
literal `null` in the dedicated proxy's CORS allowlist.

### HarmonyOS phone/tablet and Service Widget

```sh
export HARMONY_FLUTTER_BIN=/opt/flutter-ohos/bin/flutter
export DEVECO_SDK_HOME=/opt/HarmonyOS/sdk
export PATH="/opt/DevEco-Studio/tools/ohpm/bin:/opt/DevEco-Studio/tools/hvigor/bin:/opt/DevEco-Studio/tools/node/bin:$PATH"
HARMONY_BUILD_NUMBER=1 \
  ./packaging/harmonyos/build_harmonyos.sh "$API_BASE_URL" "$VERSION"
```

The isolated runner injects the `2×4` Service Widget, local Preferences state,
and the companion MethodChannel before producing
`dist/harmonyos/zingchart-harmonyos-<version>.hap`. An OpenHarmony-only SDK is
not sufficient; the build requires DevEco HarmonyOS API 18 metadata.

## Local data, proxy, and release notes

- Favorites, followed artists, saved Zing albums/playlists, personal playlists,
  queue, listening analytics, moods, and session state remain on each device.
  Android Auto Backup/iOS device backup may include them according to OS policy.
- Backup v3 is capped at 5 MB, contains no audio or signed stream URL, and can
  still import schemas v1 and v2.
- The proxy exposes `/health`, `/v1/chart`, `/v1/artists/{alias}`,
  `/v1/search/suggestions`, `/v1/search`,
  `/v1/collections/{id}`, `/v1/songs/{code}/lyrics`,
  `/v1/songs/{code}/source`, and a signed
  `/v1/streams/{token}` relay with CORS allowlisting, rate limiting, timeouts,
  and sanitized errors.
- CI builds Wear OS alongside Android and prepares Apple/Harmony companion
  targets. Signed iOS release requires three provisioning-profile secrets:
  `IOS_PROVISIONING_PROFILE_BASE64`,
  `IOS_WIDGET_PROVISIONING_PROFILE_BASE64`, and
  `IOS_WATCH_PROVISIONING_PROFILE_BASE64`.
- Store submission, auto-update, and real-device pairing tests are not fully
  automated. Validate media keys, widgets, watch pairing, background playback,
  and signing on physical target hardware before release.

See [packaging/README.md](packaging/README.md) for installer details and
[proxy/README.md](proxy/README.md) for the proxy contract and security model.
