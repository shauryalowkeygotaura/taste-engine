#!/usr/bin/env bash
# append a correction to the active (or given) project's journal
# usage: scripts/learn.sh "correction note" [slug]
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

note="${1:-}"
if [[ -z "$note" ]]; then
  echo 'usage: scripts/learn.sh "correction note" [slug]' >&2
  exit 1
fi
slug="${2:-$(active_slug)}"
journal="$PROFILES/$slug/journal.md"
if [[ ! -f "$journal" ]]; then
  echo "error: no journal for '$slug' at $journal" >&2
  exit 1
fi

{
  echo ""
  echo "## $(today) | $slug"
  echo "- signal: (manual entry)"
  echo "- correction: $note"
  echo "- rule: $note"
  echo "- scope: project"
  echo "- distilled: no"
} >> "$journal"

echo "logged to $slug journal. run '/ts distill' or scripts to harden."
