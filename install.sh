#!/usr/bin/env bash
# install taste-engine as a Claude Code skill, pointing it back at this clone
# so your profiles + moodboards stay in the repo (not buried in ~/.claude).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}/taste-engine"

mkdir -p "$SKILLS_DIR"
cp "$REPO/SKILL.md" "$SKILLS_DIR/SKILL.md"
cp -r "$REPO/base" "$SKILLS_DIR/base"

# pointer so the skill knows where the profiles live
printf '%s' "$REPO/profiles" > "$SKILLS_DIR/.taste-root"

echo "installed taste-engine -> $SKILLS_DIR"
echo "profiles root          -> $REPO/profiles"
echo ""
echo "next:"
echo "  restart Claude Code so it picks up the skill"
echo "  in a session: /taste new <project>   (or scripts/new-project.sh <project>)"
