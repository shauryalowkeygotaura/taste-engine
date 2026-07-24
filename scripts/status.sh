#!/usr/bin/env bash
# show taste-engine status
# usage: scripts/status.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

slug="$(active_slug)"
echo "active project : $slug"

count_projects=$(find "$PROFILES" -maxdepth 1 -mindepth 1 -type d ! -name '_template' | wc -l | tr -d ' ')
echo "profiles       : $count_projects (excluding _template)"

# scopes to report: _global always, plus the active project if it differs
scopes=("_global")
[[ "$slug" != "_global" ]] && scopes+=("$slug")

for scope in "${scopes[@]}"; do
  j="$PROFILES/$scope/journal.md"
  [[ -f "$j" ]] || continue
  undistilled=$(grep -c '^- distilled: no$' "$j" 2>/dev/null || true)
  imgs=$(find "$PROFILES/$scope/moodboard" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' \) 2>/dev/null | wc -l | tr -d ' ')
  echo "scope $scope : ${undistilled:-0} undistilled note(s), $imgs moodboard image(s)"
done
