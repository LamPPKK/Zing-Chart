#!/usr/bin/env bash
set -euo pipefail

PLATFORM="${1:-}"
API_BASE_URL="${2:-}"
VERSION="${3:-1.0.0}"
TV_FLUTTER_BIN="${TV_FLUTTER_BIN:-flutter}"
TV_WEBOS_PACKAGER="${TV_WEBOS_PACKAGER:-ares-package}"

if [[ "$PLATFORM" != "webos" && "$PLATFORM" != "tizen" ]]; then
  echo "Usage: $0 <webos|tizen> <https-api-base-url> [x.y.z]" >&2
  exit 64
fi
if [[ ! "$API_BASE_URL" =~ ^https:// ]]; then
  echo "TV release builds require an HTTPS API_BASE_URL." >&2
  exit 64
fi
if [[ ! "$VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  echo "TV package version must use x.y.z numeric format." >&2
  exit 64
fi
if [[ "$PLATFORM" == "tizen" ]]; then
  IFS='.' read -r TV_VERSION_MAJOR TV_VERSION_MINOR TV_VERSION_PATCH <<< "$VERSION"
  if ((TV_VERSION_MAJOR > 255 || TV_VERSION_MINOR > 255 || TV_VERSION_PATCH > 65535)); then
    echo "Tizen versions require major/minor <= 255 and patch <= 65535." >&2
    exit 64
  fi
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAGE_DIR="$ROOT_DIR/build/tv/$PLATFORM"
DIST_DIR="$ROOT_DIR/dist/$PLATFORM"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR" "$DIST_DIR"

"$TV_FLUTTER_BIN" build web \
  --release \
  --no-web-resources-cdn \
  --output "$STAGE_DIR" \
  --dart-define="API_BASE_URL=$API_BASE_URL" \
  --dart-define=TV_MODE=true

node "$ROOT_DIR/packaging/tv/prepare_tv_web.mjs" \
  "$PLATFORM" "$STAGE_DIR" "$VERSION"

if [[ "$PLATFORM" == "webos" ]]; then
  command -v "$TV_WEBOS_PACKAGER" >/dev/null 2>&1 || {
    echo "Install the official webOS CLI before packaging: npm install -g @webos-tools/cli@3.2.5" >&2
    exit 69
  }
  find "$DIST_DIR" -maxdepth 1 -type f \
    -name 'software.baycho.app.zingchart_*_all.ipk' -delete
  "$TV_WEBOS_PACKAGER" --no-minify --outdir "$DIST_DIR" "$STAGE_DIR"
else
  TV_TIZEN_ARCHIVE="$DIST_DIR/zingchart-tizen-project-$VERSION.zip"
  rm -f "$TV_TIZEN_ARCHIVE"
  (
    cd "$ROOT_DIR/build/tv"
    zip -qry "$TV_TIZEN_ARCHIVE" tizen
  )
  echo "Created a signable Tizen project. Use package_tizen.sh with a Samsung certificate profile to produce the installable WGT."
fi
