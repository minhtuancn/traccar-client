#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/build/branding"
mkdir -p "$OUT"

render_svg() {
  local input="$1" output="$2"
  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w 1024 -h 1024 "$input" -o "$output"
  elif command -v magick >/dev/null 2>&1; then
    magick -background none "$input" -resize 1024x1024 "$output"
  else
    echo "ZalGps branding requires rsvg-convert (librsvg) or ImageMagick." >&2
    exit 1
  fi
}
render_svg "$ROOT/assets/branding/zalgps_icon.svg" "$OUT/zalgps_icon.png"
render_svg "$ROOT/assets/branding/zalgps_foreground.svg" "$OUT/zalgps_foreground.png"
cat > "$OUT/flutter_launcher_icons.yaml" <<'YAML'
flutter_launcher_icons:
  android: "ic_launcher"
  ios: true
  image_path: "build/branding/zalgps_icon.png"
  adaptive_icon_background: "#071F5A"
  adaptive_icon_foreground: "build/branding/zalgps_foreground.png"
  min_sdk_android: 24
  remove_alpha_ios: true
YAML
cd "$ROOT"
dart run flutter_launcher_icons -f build/branding/flutter_launcher_icons.yaml
