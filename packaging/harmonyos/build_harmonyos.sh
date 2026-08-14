#!/usr/bin/env bash
set -euo pipefail

API_BASE_URL="${1:-}"
VERSION="${2:-1.0.0}"
BUILD_NUMBER="${HARMONY_BUILD_NUMBER:-1}"
HARMONY_FLUTTER_BIN="${HARMONY_FLUTTER_BIN:-flutter}"
ROOT_DIR="${HARMONY_PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
STAGE_DIR="$ROOT_DIR/build/harmonyos"
OUTPUT_DIR="$ROOT_DIR/dist/harmonyos"

if [[ ! "$API_BASE_URL" =~ ^https:// ]]; then
  echo "HarmonyOS release builds require an HTTPS API_BASE_URL." >&2
  exit 64
fi
if [[ ! "$VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  echo "HarmonyOS package version must use x.y.z numeric format." >&2
  exit 64
fi
if [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || ((BUILD_NUMBER > 2147483647)); then
  echo "HARMONY_BUILD_NUMBER must be between 1 and 2147483647." >&2
  exit 64
fi
command -v "$HARMONY_FLUTTER_BIN" >/dev/null 2>&1 || {
  echo "HarmonyOS Flutter executable not found: $HARMONY_FLUTTER_BIN" >&2
  exit 69
}
command -v node >/dev/null 2>&1 || {
  echo "Node.js is required to prepare the HarmonyOS runner." >&2
  exit 69
}
if ! "$HARMONY_FLUTTER_BIN" create --help 2>&1 | grep -q 'ohos'; then
  echo "Use CPF-Flutter 3.41.x with OpenHarmony support, not upstream Flutter." >&2
  exit 69
fi
HARMONY_FLUTTER_VERSION="$("$HARMONY_FLUTTER_BIN" --version 2>&1)"
if [[ "${HARMONY_ALLOW_UNTESTED_SDK:-0}" != "1" &&
      ( ! "$HARMONY_FLUTTER_VERSION" =~ Flutter[[:space:]]3\.41\.10([^0-9]|$) ||
        ! "$HARMONY_FLUTTER_VERSION" =~ Dart[[:space:]]3\.11\.5([^0-9]|$) ) ]]; then
  echo "This pipeline requires CPF-Flutter 3.41.10 with Dart 3.11.5." >&2
  echo "Set HARMONY_ALLOW_UNTESTED_SDK=1 only after validating another version." >&2
  exit 69
fi
if [[ -z "${DEVECO_SDK_HOME:-}" || ! -d "$DEVECO_SDK_HOME" ]]; then
  echo "DEVECO_SDK_HOME must point to a HarmonyOS 5.1.0 (API 18) SDK." >&2
  exit 69
fi
if [[ "${HARMONY_ALLOW_UNTESTED_SDK:-0}" != "1" ]]; then
  SDK_API18_FOUND=0
  while IFS= read -r SDK_METADATA; do
    if grep -Eq '"apiVersion"[[:space:]]*:[[:space:]]*"18"' "$SDK_METADATA"; then
      SDK_API18_FOUND=1
      break
    fi
  done < <(find "$DEVECO_SDK_HOME" -maxdepth 2 -type f -name sdk-pkg.json -print)
  if ((SDK_API18_FOUND == 0)); then
    echo "DEVECO_SDK_HOME must contain a DevEco HarmonyOS API 18 sdk-pkg.json." >&2
    echo "An OpenHarmony SDK directory alone cannot build this HarmonyOS HAP." >&2
    exit 69
  fi
fi
# CPF-Flutter reads HOS_SDK_HOME. Keep DEVECO_SDK_HOME as this repository's
# public input and export the same SDK under the toolchain's expected name.
export HOS_SDK_HOME="$DEVECO_SDK_HOME"

rm -rf "$STAGE_DIR"
mkdir -p "$(dirname "$STAGE_DIR")" "$OUTPUT_DIR"
"$HARMONY_FLUTTER_BIN" create \
  --platforms=ohos \
  --org software.baycho \
  --project-name zmp3chart \
  "$STAGE_DIR"

rm -rf "$STAGE_DIR/lib" "$STAGE_DIR/test"
cp -R "$ROOT_DIR/lib" "$STAGE_DIR/lib"
cp "$ROOT_DIR/pubspec.yaml" "$STAGE_DIR/pubspec.yaml"
cp "$ROOT_DIR/analysis_options.yaml" "$STAGE_DIR/analysis_options.yaml"
cp "$ROOT_DIR/packaging/harmonyos/pubspec_overrides.yaml" \
  "$STAGE_DIR/pubspec_overrides.yaml"
cp "$ROOT_DIR/packaging/harmonyos/pubspec.lock" "$STAGE_DIR/pubspec.lock"
node "$ROOT_DIR/packaging/harmonyos/prepare_harmonyos.mjs" \
  "$STAGE_DIR" "$VERSION" "$BUILD_NUMBER"

(
  cd "$STAGE_DIR"
  PUB_ATTEMPT=1
  until "$HARMONY_FLUTTER_BIN" pub get --enforce-lockfile; do
    if ((PUB_ATTEMPT >= 3)); then
      echo "Unable to restore the locked HarmonyOS dependencies after 3 attempts." >&2
      exit 69
    fi
    PUB_ATTEMPT=$((PUB_ATTEMPT + 1))
    echo "Retrying locked HarmonyOS dependencies ($PUB_ATTEMPT/3)..." >&2
  done
  "$HARMONY_FLUTTER_BIN" build hap \
    --release \
    --target-platform=ohos-arm64 \
    --dart-define="API_BASE_URL=$API_BASE_URL" \
    --dart-define=DISTRIBUTION_CHANNEL=huawei
)

HAP_PATH="$(find "$STAGE_DIR" -type f -name '*-signed.hap' \
  ! -path '*/ohosTest/*' -print -quit)"
if [[ -z "$HAP_PATH" ]]; then
  HAP_PATH="$(find "$STAGE_DIR" -type f -name '*.hap' \
    ! -path '*/ohosTest/*' -print -quit)"
fi
[[ -n "$HAP_PATH" && -s "$HAP_PATH" ]] || {
  echo "Flutter completed without producing a HarmonyOS HAP." >&2
  exit 1
}

OUTPUT_HAP="$OUTPUT_DIR/zingchart-harmonyos-$VERSION.hap"
cp "$HAP_PATH" "$OUTPUT_HAP"
echo "Created HarmonyOS HAP: $OUTPUT_HAP"
