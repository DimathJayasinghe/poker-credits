#!/usr/bin/env bash
# Virtual-card rooms keep the deck and every hole card inside RoomState, its ops and some wire
# messages. Their `Debug` output is redacted, but the safest rule is that none of them is ever
# handed to a log macro. Fails if a tracing call formats room state, an op, a message, a view or
# anything that can hold cards. Log ids, error codes and counts instead.
#   bash tool/check_no_state_logging.sh              check the repository
#   bash tool/check_no_state_logging.sh --self-test  prove the check catches what it should
set -euo pipefail
cd "$(dirname "$0")/.."

# Names that can carry cards (or a whole room). A `?name` / `%name` field or a `{name:?}` hole.
names='state|room_state|game|table|deal|deck|op|ops|command|outcome|message|msg|view|snapshot|cards|holes|hole_cards|hand'

scan() {
  perl -0777 -ne '
    my ($names, $file) = ($ENV{NAMES}, $ARGV);
    while (/\b(?:tracing::)?(?:trace|debug|info|warn|error)!\s*\((.*?)\);/gs) {
      my $args = $1;
      if ($args =~ /[?%]\s*(?:self\.)?(?:$names)\b/ || $args =~ /\{\s*(?:self\.)?(?:$names)\s*:[#]?\?\s*\}/) {
        (my $shown = $args) =~ s/\s+/ /g;
        print "$file: logs room data: $shown\n";
      }
    }
  ' "$@"
}

if [ "${1:-}" = "--self-test" ]; then
  dir=$(mktemp -d)
  trap 'rm -rf "$dir"' EXIT
  cat > "$dir/bad.rs" <<'RS'
fn f() {
    tracing::warn!(?op, "bad");
    tracing::info!(state = ?self.state, "bad");
    error!("{state:?}");
    tracing::debug!(
        peer = %addr,
        message = ?message,
        "bad"
    );
}
RS
  cat > "$dir/good.rs" <<'RS'
fn f() {
    tracing::warn!(code = ?error.code, "fine");
    tracing::info!(%code, ?reason, count = 3, "fine");
    tracing::error!(player = %conn.player_id, "fine");
}
RS
  bad=$(NAMES="$names" scan "$dir/bad.rs" | wc -l)
  good=$(NAMES="$names" scan "$dir/good.rs" | wc -l)
  if [ "$bad" -ne 4 ] || [ "$good" -ne 0 ]; then
    echo "check_no_state_logging: self-test failed (bad=$bad expected 4, good=$good expected 0)"
    exit 1
  fi
  echo "check_no_state_logging: self-test ok"
  exit 0
fi

files=$(find crates packages -path '*/src/*' -name '*.rs' -not -path '*/target/*' -not -name 'frb_generated.rs' 2>/dev/null | sort)
if [ -z "$files" ]; then
  echo "check_no_state_logging: no Rust sources, nothing to check."
  exit 0
fi
# shellcheck disable=SC2086
hits=$(NAMES="$names" scan $files || true)
if [ -n "$hits" ]; then
  echo "check_no_state_logging: a tracing call formats room data (it may hold cards):"
  echo "$hits"
  exit 1
fi
echo "check_no_state_logging: ok"
