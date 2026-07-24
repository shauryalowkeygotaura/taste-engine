#!/usr/bin/env bash
# create-or-activate a project in one shot (the snappy path behind `/ts <slug>`)
# usage: scripts/use.sh <slug>
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

slug="$(require_slug "${1:-}")"

# reserved words that are subcommands, not project names
case "$slug" in
  learn|mood|moodboard|distill|status|use|new)
    echo "error: '$slug' is a reserved word, not a project slug" >&2
    exit 1 ;;
esac

if [[ -d "$PROFILES/$slug" ]]; then
  printf '%s' "$slug" > "$ACTIVE_FILE"
  echo "switched to existing project: $slug"
else
  cp -r "$PROFILES/_template" "$PROFILES/$slug"
  for f in "$PROFILES/$slug"/*.md; do
    sed -i "s/<slug>/$slug/g" "$f"
  done
  printf '%s' "$slug" > "$ACTIVE_FILE"
  echo "created and switched to new project: $slug"
  echo "  drop reference images in: profiles/$slug/moodboard/"
fi
