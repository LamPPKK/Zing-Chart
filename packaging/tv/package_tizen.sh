#!/usr/bin/env bash
set -euo pipefail

PROFILE="${1:-}"
PROJECT_DIR="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/build/tv/tizen}"
OUTPUT_DIR="${3:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/dist/tizen}"

if [[ -z "$PROFILE" ]]; then
  echo "Usage: $0 <tizen-certificate-profile> [project-dir] [output-dir]" >&2
  exit 64
fi
command -v tizen >/dev/null 2>&1 || {
  echo "Tizen Studio Web CLI is required to create a signed WGT." >&2
  exit 69
}
[[ -f "$PROJECT_DIR/config.xml" ]] || {
  echo "Tizen TV project not found: $PROJECT_DIR" >&2
  exit 66
}

mkdir -p "$OUTPUT_DIR"
BUILD_RESULT="$PROJECT_DIR/.buildResult"
rm -rf -- "$BUILD_RESULT"
tizen build-web --output .buildResult -- "$PROJECT_DIR"
tizen package -t wgt -s "$PROFILE" -- "$BUILD_RESULT"
WGT_PATH="$(find "$BUILD_RESULT" -maxdepth 1 -type f -name '*.wgt' -print -quit)"
[[ -n "$WGT_PATH" ]] || {
  echo "Tizen CLI completed without producing a WGT." >&2
  exit 1
}
cp "$WGT_PATH" "$OUTPUT_DIR/"
