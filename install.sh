#!/usr/bin/env bash
# install taste-engine as a Claude Code skill, pointing it back at this clone
# so your profiles + moodboards stay in the repo (not buried in ~/.claude).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SKILLS_DIR="$CLAUDE_DIR/skills/taste-engine"
COMMANDS_DIR="$CLAUDE_DIR/commands"

mkdir -p "$SKILLS_DIR" "$COMMANDS_DIR"
cp "$REPO/SKILL.md" "$SKILLS_DIR/SKILL.md"
cp -r "$REPO/base" "$SKILLS_DIR/base"

# the /ts slash command
cp "$REPO/commands/ts.md" "$COMMANDS_DIR/ts.md"

# pointer so the skill + command know where the profiles live
printf '%s' "$REPO/profiles" > "$SKILLS_DIR/.taste-root"

echo "installed taste-engine -> $SKILLS_DIR"
echo "installed /ts command  -> $COMMANDS_DIR/ts.md"
echo "profiles root          -> $REPO/profiles"
echo ""
echo "next:"
echo "  restart Claude Code so it picks up the skill + command"
echo "  in a session: /ts <project>     (creates it the first time, switches after)"
echo "                /ts               (status)"
echo "                /ts learn \"note\"  /ts mood  /ts distill"
