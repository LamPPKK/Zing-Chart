#!/usr/bin/env bash
set -euo pipefail

version="${1:-0.0.0}"
version="${version#v}"
if [[ ! "$version" =~ ^[0-9][0-9A-Za-z.+:~-]*$ ]]; then
  version="0.0.0"
fi
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bundle_dir="$repo_root/build/linux/x64/release/bundle"
output_dir="$repo_root/dist/linux"
stage_dir="$repo_root/build/packaging/linux"
app_dir="$stage_dir/AppDir"
deb_root="$stage_dir/deb"

if [[ ! -x "$bundle_dir/zmp3chart" ]]; then
  echo "Linux release bundle not found at $bundle_dir. Run flutter build linux --release first." >&2
  exit 1
fi

mkdir -p "$output_dir"
tar -C "$bundle_dir" -czf "$output_dir/zingchart-linux-portable.tar.gz" .

rm -rf "$app_dir" "$deb_root"
mkdir -p "$app_dir/usr/lib/zingchart" "$app_dir/usr/bin" "$app_dir/usr/share/applications" "$app_dir/usr/share/icons/hicolor/512x512/apps"
cp -a "$bundle_dir/." "$app_dir/usr/lib/zingchart/"
ln -s ../lib/zingchart/zmp3chart "$app_dir/usr/bin/zingchart"
install -m 0644 "$repo_root/packaging/linux/zingchart.desktop" "$app_dir/usr/share/applications/zingchart.desktop"
install -m 0644 "$repo_root/web/icons/Icon-512.png" "$app_dir/usr/share/icons/hicolor/512x512/apps/zingchart.png"

if [[ -n "${LINUXDEPLOY:-}" && -x "$LINUXDEPLOY" ]]; then
  (
    cd "$stage_dir"
    OUTPUT="$output_dir/zingchart-linux.AppImage" "$LINUXDEPLOY" \
      --appdir "$app_dir" \
      --desktop-file "$app_dir/usr/share/applications/zingchart.desktop" \
      --output appimage
  )
else
  echo "LINUXDEPLOY is not executable; skipping AppImage." >&2
fi

mkdir -p "$deb_root/DEBIAN" "$deb_root/opt/zingchart" "$deb_root/usr/bin" "$deb_root/usr/share/applications" "$deb_root/usr/share/icons/hicolor/512x512/apps"
cp -a "$bundle_dir/." "$deb_root/opt/zingchart/"
ln -s /opt/zingchart/zmp3chart "$deb_root/usr/bin/zingchart"
install -m 0644 "$repo_root/packaging/linux/zingchart.desktop" "$deb_root/usr/share/applications/zingchart.desktop"
install -m 0644 "$repo_root/web/icons/Icon-512.png" "$deb_root/usr/share/icons/hicolor/512x512/apps/zingchart.png"
sed "s/@VERSION@/$version/g" "$repo_root/packaging/linux/control" > "$deb_root/DEBIAN/control"
dpkg-deb --build --root-owner-group "$deb_root" "$output_dir/zingchart_${version}_amd64.deb"
