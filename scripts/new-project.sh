#!/usr/bin/env bash
# scaffold a new project profile from the template
# usage: scripts/new-project.sh <slug>
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

slug="$(require_slug "${1:-}")"
dest="$PROFILES/$slug"

if [[ -e "$dest" ]]; then
  echo "error: profile '$slug' already exists at $dest" >&2
  exit 1
fi

cp -r "$PROFILES/_template" "$dest"
# replace the <slug> placeholder in the copied markdown
for f in "$dest"/*.md; do
  sed -i "s/<slug>/$slug/g" "$f"
done

echo "created profile: $slug"
echo "  profile:   profiles/$slug/profile.md"
echo "  moodboard: profiles/$slug/moodboard/   (drop reference images here)"
echo "  then:      scripts/set-active.sh $slug"
