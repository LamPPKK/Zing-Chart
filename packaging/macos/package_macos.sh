#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
app_path="$repo_root/build/macos/Build/Products/Release/#zingChart.app"
output_dir="$repo_root/dist/macos"
dmg_path="$output_dir/zingchart-macos.dmg"
zip_path="$output_dir/zingchart-macos-app.zip"

if [[ ! -d "$app_path" ]]; then
  echo "macOS app not found at $app_path. Run flutter build macos --release first." >&2
  exit 1
fi

mkdir -p "$output_dir"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$zip_path"
hdiutil create -volname '#zingChart' -srcfolder "$app_path" -ov -format UDZO "$dmg_path"
