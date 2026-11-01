#!/usr/bin/env bash
# ADR-014: keep the Dart code compilable for web.
# Fails if banned imports appear in web-safe code. Platform-specific code belongs in app/lib/platform/*_io.dart.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0

# Directories that must be web-safe. Missing directories are skipped (pre-Phase-0 repo).
safe_dirs=()
for d in packages/poker_protocol/lib app/lib/model app/lib/net app/lib/provider app/lib/widget app/lib/theme app/lib/pages app/lib/util app/lib/config; do
  [ -d "$d" ] && safe_dirs+=("$d")
done

if [ ${#safe_dirs[@]} -eq 0 ]; then
  echo "check_web_safe: no Dart sources yet, nothing to check."
  exit 0
fi

# 1. Banned imports/usages in web-safe dirs.
banned='dart:io|dart:ffi|dart:html|package:web/|package:poker_bridge|Platform\.is[A-Z]|Platform\.(operatingSystem|environment|localHostname)'
# Comment-only lines may mention the banned names (for example in the rule's own documentation).
if hits=$(grep -rnE --include='*.dart' "$banned" "${safe_dirs[@]}" 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//'); then
  echo "check_web_safe: banned import or API in web-safe code (move it behind app/lib/platform/):"
  echo "$hits"
  fail=1
fi

# 2. Hex colour literals and Color(0x...) outside the token file (ADR-013).
if [ -d app/lib ]; then
  if hits=$(grep -rnE --include='*.dart' 'Color\(0x[0-9A-Fa-f]+\)|Color\.fromARGB|Color\.fromRGBO' app/lib 2>/dev/null | grep -v 'app/lib/theme/tokens.dart'); then
    echo "check_web_safe: colour literal outside app/lib/theme/tokens.dart (use tokens):"
    echo "$hits"
    fail=1
  fi
  # 3. Runtime font downloads break offline LAN play.
  if hits=$(grep -rnE --include='*.dart' --include='pubspec.yaml' 'google_fonts' app 2>/dev/null); then
    echo "check_web_safe: google_fonts downloads fonts at runtime; bundle fonts as assets instead:"
    echo "$hits"
    fail=1
  fi
fi

# 4. Platform seam must use conditional exports, not kIsWeb branching in feature code.
if [ -d app/lib ]; then
  if hits=$(grep -rnE --include='*.dart' 'kIsWeb' app/lib 2>/dev/null | grep -v 'app/lib/platform/'); then
    echo "check_web_safe: kIsWeb used outside app/lib/platform/ (use the platform seam):"
    echo "$hits"
    fail=1
  fi
fi

if [ "$fail" -ne 0 ]; then exit 1; fi
echo "check_web_safe: ok"
