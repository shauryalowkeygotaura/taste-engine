#!/usr/bin/env bash
# taste-engine Stop hook.
#
# At the end of a Claude Code session, count the journal entries that are still
# marked `distilled: no` and nudge you only once there are enough of them to
# actually harden a rule. Below the threshold it prints nothing at all, so it
# does not add a line to every session you ever run.
#
# It never blocks the session and never writes to the journal. The journal is
# append-only truth and the skill already records corrections as they happen
# (SKILL.md section 4); this hook only reminds you to run `/ts distill`.
#
#   install:   bash hooks/install-hook.sh
#   uninstall: bash hooks/install-hook.sh --uninstall
#   threshold: export TASTE_STOP_THRESHOLD=5   (default 2, matching the
#              promotion threshold in profile.md)
#
# Reads the Stop payload on stdin and ignores it. Emits either nothing, or one
# JSON object with a `systemMessage`. Always exits 0.

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HOOK_DIR/.." && pwd)"
PROFILES="$REPO/profiles"

# drain stdin so the caller is never left writing into a full pipe
cat >/dev/null 2>&1 || true

THRESHOLD="${TASTE_STOP_THRESHOLD:-2}"
case "$THRESHOLD" in
  ''|*[!0-9]*) THRESHOLD=2 ;;
esac

[[ -d "$PROFILES" ]] || exit 0

slug="_global"
if [[ -f "$PROFILES/.active" ]]; then
  slug="$(tr -d '\r\n' < "$PROFILES/.active" 2>/dev/null || echo _global)"
fi
# whitelist: anything that is not a plain slug falls back to _global
[[ "$slug" =~ ^[a-z0-9_-]+$ ]] || slug="_global"

scopes=("_global")
[[ "$slug" != "_global" ]] && scopes+=("$slug")

total=0
detail=""
for scope in "${scopes[@]}"; do
  journal="$PROFILES/$scope/journal.md"
  [[ -f "$journal" ]] || continue
  n="$(grep -c '^- distilled: no$' "$journal" 2>/dev/null || true)"
  case "$n" in
    ''|*[!0-9]*) n=0 ;;
  esac
  (( n > 0 )) || continue
  total=$(( total + n ))
  [[ -n "$detail" ]] && detail="$detail, "
  detail="$detail$scope $n"
done

(( total >= THRESHOLD )) || exit 0

# every component below is either an integer or a whitelisted slug, so the
# message is JSON-safe without escaping.
printf '{"systemMessage":"taste-engine: %d undistilled correction(s) waiting (%s). Run /ts distill to harden the repeats."}\n' \
  "$total" "$detail"
exit 0
