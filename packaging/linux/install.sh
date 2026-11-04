#!/usr/bin/env bash
# Adds Poker Credits to the application menu for the current user, with its icon.
#   ./install.sh             install (uses the folder this script is in)
#   ./install.sh --uninstall remove the menu entry and icon (the program folder stays)
# Nothing outside ~/.local/share is touched, and no administrator rights are needed.
set -euo pipefail

ID=dev.pokercredits.poker_credits
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
icons="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/512x512/apps"

refresh() {
  command -v update-desktop-database >/dev/null && update-desktop-database "$apps" 2>/dev/null || true
  command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q -t "${icons%/512x512/apps}" 2>/dev/null || true
}

if [[ "${1:-}" == "--uninstall" ]]; then
  rm -f "$apps/$ID.desktop" "$icons/$ID.png"
  refresh
  echo "Removed the Poker Credits menu entry."
  exit 0
fi

[[ -x "$here/poker_credits" ]] || { echo "poker_credits not found next to this script." >&2; exit 1; }
mkdir -p "$apps" "$icons"
install -m 644 "$here/data/$ID.png" "$icons/$ID.png"
sed -e "s|@EXEC@|$here/poker_credits|" -e "s|@DIR@|$here|" "$here/$ID.desktop" > "$apps/$ID.desktop"
chmod 644 "$apps/$ID.desktop"
refresh
echo "Installed. Find Poker Credits in your application menu."
echo "Keep this folder where it is: the menu entry starts the program from here."
