# #zingChart

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

- Realtime Zing Chart with rank, artwork, title, and artist.
- Search, play/pause/stop, seek, previous/next, shuffle, repeat, queue, and
  sleep timer.
- Background playback and native media controls where the OS supports them.
- Local favorites, playlists, history, recent searches, Daily/Mood Mix,
  7/30-day and yearly analytics, and six-slide Mini Wrapped.
- Versioned JSON backup with idempotent Merge and full Overwrite modes.
- Responsive phone/tablet/desktop UI and remote-first 10-foot TV UI.
- Light, dark, and system themes using the existing charcoal/coral/lime visual
  language.

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

The deterministic gallery fixture lives in
[`tool/docs_screenshot_app.dart`](tool/docs_screenshot_app.dart). It never calls
the proxy, real audio, or an operating-system media service.

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
                                      └── signed stream relay → Zing upstream
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

- Favorites, playlists, queue, listening analytics, moods, and session state
  remain on each device. Android Auto Backup/iOS device backup may include
  them according to OS policy.
- Backup v2 is capped at 5 MB, contains no audio or signed stream URL, and can
  still import schema v1.
- The proxy exposes `/health`, `/v1/chart`, `/v1/songs/{code}/source`, and a
  signed `/v1/streams/{token}` relay with CORS allowlisting, rate limiting,
  timeouts, and sanitized errors.
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
