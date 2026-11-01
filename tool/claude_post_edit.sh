#!/usr/bin/env bash
# Claude Code PostToolUse hook: auto-format the file Claude just edited.
# Reads the hook JSON on stdin. Always exits 0; never blocks an edit. Skips silently if tools are missing.
root="$(cd "$(dirname "$0")/.." && pwd)"
f=$(python3 -c 'import sys,json; d=json.load(sys.stdin); print((d.get("tool_input") or {}).get("file_path",""))' 2>/dev/null)
[ -n "$f" ] && [ -f "$f" ] || exit 0
case "$f" in
  *.rs)
    command -v rustfmt >/dev/null 2>&1 && rustfmt --edition 2024 --config-path "$root" "$f" >/dev/null 2>&1 ;;
  *.dart)
    case "$f" in *.g.dart|*.mapper.dart|*.freezed.dart|*/gen/*) exit 0;; esac
    if command -v fvm >/dev/null 2>&1 && [ -f "$root/.fvmrc" ]; then
      (cd "$root" && fvm dart format --line-length 150 "$f" >/dev/null 2>&1)
    fi ;;
esac
exit 0
