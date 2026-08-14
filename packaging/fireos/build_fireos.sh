#!/usr/bin/env bash
set -euo pipefail

API_BASE_URL="${1:-}"
VERSION="${2:-1.0.0}"
TARGET="${3:-touch}"
BUILD_NUMBER="${FIREOS_BUILD_NUMBER:-1}"
FLUTTER_BIN="${FIREOS_FLUTTER_BIN:-flutter}"
ROOT_DIR="${FIREOS_PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

if [[ ! "$API_BASE_URL" =~ ^https:// ]]; then
  echo "Fire OS release builds require an HTTPS API_BASE_URL." >&2
  exit 64
fi
if [[ ! "$VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  echo "Fire OS package version must use x.y.z numeric format." >&2
  exit 64
fi
if [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo "FIREOS_BUILD_NUMBER must be a positive integer." >&2
  exit 64
fi
if (( BUILD_NUMBER > 1049999999 )); then
  echo "FIREOS_BUILD_NUMBER is too large to derive Amazon variant version codes." >&2
  exit 64
fi
if [[ "$TARGET" != "touch" && "$TARGET" != "tv" ]]; then
  echo "Fire OS target must be either 'touch' or 'tv'." >&2
  exit 64
fi
command -v "$FLUTTER_BIN" >/dev/null 2>&1 || {
  echo "Flutter executable not found: $FLUTTER_BIN" >&2
  exit 69
}

SOURCE_APK="$ROOT_DIR/build/app/outputs/flutter-apk/app-release.apk"
if [[ "$TARGET" == "tv" ]]; then
  OUTPUT_DIR="$ROOT_DIR/dist/firetv"
  ARTIFACT_NAME="zingchart-firetv"
  DISTRIBUTION_CHANNEL="amazon-fire-tv"
  VERSION_CODE=$((BUILD_NUMBER * 2 + 1))
else
  OUTPUT_DIR="$ROOT_DIR/dist/fireos"
  ARTIFACT_NAME="zingchart-fireos"
  DISTRIBUTION_CHANNEL="amazon"
  VERSION_CODE=$((BUILD_NUMBER * 2))
fi
ARTIFACT_SUFFIX=""
if [[ ! -s "$ROOT_DIR/android/key.properties" ]]; then
  if [[ "${FIREOS_REQUIRE_PRODUCTION_SIGNING:-0}" == "1" ]]; then
    echo "Production Fire OS builds require android/key.properties." >&2
    exit 78
  fi
  ARTIFACT_SUFFIX="-development"
fi
OUTPUT_APK="$OUTPUT_DIR/$ARTIFACT_NAME-$VERSION$ARTIFACT_SUFFIX.apk"

FLUTTER_ARGS=(
  build apk
  --release
  "--build-name=$VERSION"
  "--build-number=$VERSION_CODE"
  "--dart-define=API_BASE_URL=$API_BASE_URL"
  "--dart-define=DISTRIBUTION_CHANNEL=$DISTRIBUTION_CHANNEL"
)
if [[ "$TARGET" == "tv" ]]; then
  FLUTTER_ARGS+=(--dart-define=TV_MODE=true)
fi

(
  cd "$ROOT_DIR"
  "$FLUTTER_BIN" "${FLUTTER_ARGS[@]}"
)

[[ -s "$SOURCE_APK" ]] || {
  echo "Flutter completed without producing an APK: $SOURCE_APK" >&2
  exit 1
}
mkdir -p "$OUTPUT_DIR"
cp "$SOURCE_APK" "$OUTPUT_APK"
echo "Created Fire OS $TARGET APK: $OUTPUT_APK"
