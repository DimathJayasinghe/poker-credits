#!/usr/bin/env bash
# Checks the local toolchain for this repo and prints what is missing.
# Usage: bash tool/setup_dev.sh            (check only, changes nothing)
#        bash tool/setup_dev.sh --install  (install missing Rust/FVM tooling after asking)
set -uo pipefail
cd "$(dirname "$0")/.."

install=0
[ "${1:-}" = "--install" ] && install=1
missing=0

check() { # name, command, hint
  if command -v "$2" >/dev/null 2>&1; then
    printf '  ok       %-28s %s\n' "$1" "$(command -v "$2")"
  else
    printf '  MISSING  %-28s %s\n' "$1" "$3"
    missing=1
  fi
}

echo "Toolchain check for Poker Credits"
check "rustup"                 rustup  "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
check "cargo"                  cargo   "installed with rustup; toolchain comes from rust-toolchain.toml"
check "rust-analyzer"          rust-analyzer "rustup component add rust-analyzer"
check "fvm"                    fvm     "dart pub global activate fvm   (then add ~/.pub-cache/bin to PATH)"
check "flutter (system)"       flutter "only needed to bootstrap fvm; project uses 'fvm flutter'"
check "flutter_rust_bridge_codegen" flutter_rust_bridge_codegen "cargo install flutter_rust_bridge_codegen   (version must match flutter_rust_bridge in pubspec)"
check "cargo-nextest (optional)" cargo-nextest "cargo install cargo-nextest --locked"
check "cargo-deny (optional)"  cargo-deny "cargo install cargo-deny --locked"
check "graphify"               graphify "uv tool install graphifyy   or   pip install graphifyy"
check "gh (optional)"          gh      "https://cli.github.com"

echo
echo "Platform toolchains (only for the targets you build):"
echo "  Android: Android SDK + NDK (for cargokit), accept licences:  fvm flutter doctor --android-licenses"
echo "  Linux desktop: clang, cmake, ninja-build, pkg-config, libgtk-3-dev, libsecret-1-dev"
echo "  Windows: Visual Studio 2022 'Desktop development with C++'"
echo "  iOS/macOS: Xcode (macOS only). Rust targets: rustup target add aarch64-apple-ios aarch64-apple-darwin"
echo "  Android Rust targets: rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android"

echo
if [ -f .fvmrc ]; then echo "Flutter pin (.fvmrc): $(grep -o '"flutter": *"[^"]*"' .fvmrc)"; fi
if [ -f rust-toolchain.toml ]; then echo "Rust pin (rust-toolchain.toml): $(grep -E '^channel' rust-toolchain.toml)"; fi

echo
if [ "$(git config core.hooksPath 2>/dev/null)" = ".githooks" ]; then
  echo "git hooks: enabled (.githooks)"
else
  echo "git hooks: NOT enabled. Run: git config core.hooksPath .githooks"
fi

if [ "$install" -eq 1 ] && [ "$missing" -eq 1 ]; then
  echo
  echo "--install requested."
  if ! command -v rustup >/dev/null 2>&1; then
    read -r -p "Install rustup (downloads and runs https://sh.rustup.rs)? [y/N] " a
    if [ "$a" = "y" ]; then curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal; fi
  fi
  if ! command -v fvm >/dev/null 2>&1 && command -v dart >/dev/null 2>&1; then
    read -r -p "Install fvm with 'dart pub global activate fvm'? [y/N] " a
    if [ "$a" = "y" ]; then dart pub global activate fvm; fi
  fi
  echo "Re-run without --install to verify. Open a new shell so PATH changes apply."
fi

exit 0
