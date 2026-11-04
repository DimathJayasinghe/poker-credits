#!/usr/bin/env bash
# Rasterise an SVG with headless Chrome: render.sh in.svg out.png size [transparent]
set -euo pipefail
in=$(realpath "$1"); out=$2; size=$3
bg=${4:+00000000}; bg=${bg:-ffffffff}
tmp=$(mktemp -d)
printf '<html><body style="margin:0;background:transparent"><img src="file://%s" width="%s" height="%s" style="display:block"></body></html>' "$in" "$size" "$size" > "$tmp/p.html"
google-chrome --headless=new --no-sandbox --disable-gpu --hide-scrollbars --default-background-color="$bg" \
  --window-size="$size,$size" --screenshot="$out" "file://$tmp/p.html" >/dev/null 2>&1
rm -rf "$tmp"
