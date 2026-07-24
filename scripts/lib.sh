#!/usr/bin/env bash
# shared helpers for taste-engine scripts
set -euo pipefail

# repo root = parent of the scripts/ dir this file lives in
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$LIB_DIR/.." && pwd)"
PROFILES="$REPO/profiles"
ACTIVE_FILE="$PROFILES/.active"

active_slug() {
  if [[ -f "$ACTIVE_FILE" ]]; then
    cat "$ACTIVE_FILE"
  else
    echo "_global"
  fi
}

today() { date +%Y-%m-%d; }

require_slug() {
  local slug="${1:-}"
  if [[ -z "$slug" ]]; then
    echo "error: slug required" >&2
    exit 1
  fi
  # whitelist: lowercase letters, digits, hyphen, underscore only
  if [[ ! "$slug" =~ ^[a-z0-9_-]+$ ]]; then
    echo "error: slug must match ^[a-z0-9_-]+$ (got: $slug)" >&2
    exit 1
  fi
  echo "$slug"
}
