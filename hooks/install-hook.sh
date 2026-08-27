#!/usr/bin/env bash
# Install (or remove) the taste-engine Stop hook in your Claude Code settings.
#
#   bash hooks/install-hook.sh              install / refresh the hook
#   bash hooks/install-hook.sh --uninstall  remove it again
#
# The hook is opt-in on purpose: `install.sh` does not add it unless you pass
# --with-hook. It edits $CLAUDE_CONFIG_DIR/settings.json (default
# ~/.claude/settings.json), backs the file up first, and is idempotent: any
# previously installed taste-engine Stop hook is replaced, never duplicated.
set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
HOOK_CMD="bash \"$HOOK_DIR/taste-stop.sh\""

MODE="install"
if [[ "${1:-}" == "--uninstall" ]]; then
  MODE="uninstall"
elif [[ -n "${1:-}" ]]; then
  echo "usage: bash hooks/install-hook.sh [--uninstall]" >&2
  exit 1
fi

PY=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1; then PY="$candidate"; break; fi
done
if [[ -z "$PY" ]]; then
  echo "error: python3 (or python) is required to edit settings.json safely." >&2
  echo "add this to the 'hooks' block of $SETTINGS by hand instead:" >&2
  echo "  Stop -> matcher '*' -> command: $HOOK_CMD" >&2
  exit 1
fi

mkdir -p "$CLAUDE_DIR"
[[ -f "$SETTINGS" ]] || printf '{}\n' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.taste-engine.bak"

"$PY" - "$SETTINGS" "$HOOK_CMD" "$MODE" <<'PY'
import json, sys

settings_path, hook_cmd, mode = sys.argv[1], sys.argv[2], sys.argv[3]

with open(settings_path, encoding="utf-8") as fh:
    raw = fh.read().strip()

try:
    data = json.loads(raw) if raw else {}
except json.JSONDecodeError as exc:
    sys.exit("error: %s is not valid JSON (%s). nothing was changed." % (settings_path, exc))

if not isinstance(data, dict):
    sys.exit("error: %s does not contain a JSON object. nothing was changed." % settings_path)

hooks = data.setdefault("hooks", {})
if not isinstance(hooks, dict):
    sys.exit("error: 'hooks' in %s is not an object. nothing was changed." % settings_path)

stop = hooks.get("Stop") or []
if not isinstance(stop, list):
    sys.exit("error: 'hooks.Stop' in %s is not a list. nothing was changed." % settings_path)


def is_ours(matcher_entry):
    """True when this Stop matcher only exists to run our hook script."""
    if not isinstance(matcher_entry, dict):
        return False
    inner = matcher_entry.get("hooks")
    if not isinstance(inner, list) or not inner:
        return False
    return all(
        isinstance(h, dict) and "taste-stop.sh" in str(h.get("command", ""))
        for h in inner
    )


kept = [entry for entry in stop if not is_ours(entry)]
removed = len(stop) - len(kept)

if mode == "install":
    kept.append({
        "matcher": "*",
        "hooks": [{"type": "command", "command": hook_cmd}],
    })

if kept:
    hooks["Stop"] = kept
else:
    hooks.pop("Stop", None)
if not hooks:
    data.pop("hooks", None)

with open(settings_path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")

if mode == "install":
    print("replaced %d existing taste-engine Stop hook(s)" % removed if removed else "added the taste-engine Stop hook")
else:
    print("removed %d taste-engine Stop hook(s)" % removed)
PY

echo "settings : $SETTINGS"
echo "backup   : $SETTINGS.taste-engine.bak"
if [[ "$MODE" == "install" ]]; then
  echo "command  : $HOOK_CMD"
  echo ""
  echo "restart Claude Code (or run /hooks) so it reloads settings."
  echo "it stays quiet until \${TASTE_STOP_THRESHOLD:-2} corrections are undistilled."
fi
