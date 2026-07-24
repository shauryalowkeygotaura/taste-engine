#!/usr/bin/env bash
# set the active project
# usage: scripts/set-active.sh <slug>
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

slug="$(require_slug "${1:-}")"
if [[ ! -d "$PROFILES/$slug" ]]; then
  echo "error: no profile '$slug'. create it with: scripts/new-project.sh $slug" >&2
  exit 1
fi

printf '%s' "$slug" > "$ACTIVE_FILE"
echo "active project: $slug"
