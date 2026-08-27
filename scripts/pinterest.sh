#!/usr/bin/env bash
# pull a public Pinterest board into the active project's moodboard/
#
# Pinterest is not a new kind of taste source here. It is a way to FILL the
# moodboard folder that already exists. This script only downloads images and
# records where they came from; the vision pass in SKILL.md section 2 is what
# turns them into taste-dna.md, exactly as it does for images dragged in by hand.
#
# usage: scripts/pinterest.sh <board-url | user/board | user> [slug]
#
# See README "Pinterest as a moodboard source" for the env vars and the
# robots.txt situation. There is no API key and no login anywhere in this path.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

UA="${TASTE_PINTEREST_UA:-Mozilla/5.0 (compatible; taste-engine/0.1; +https://github.com/shauryalowkeygotaura/taste-engine)}"
MAX_PINS="${TASTE_PINTEREST_MAX_PINS:-24}"
SIZE="${TASTE_PINTEREST_SIZE:-736x}"
DELAY="${TASTE_PINTEREST_DELAY:-1.5}"
HOST="https://www.pinterest.com"
CDN="https://i.pinimg.com"

die() { echo "error: $*" >&2; exit 1; }

usage() {
  echo "usage: scripts/pinterest.sh <board-url | user/board | user> [slug]" >&2
  echo "  e.g. scripts/pinterest.sh https://www.pinterest.com/travisneilson/neo-brutalist-websites/" >&2
  echo "       scripts/pinterest.sh travisneilson/neo-brutalist-websites marrow" >&2
  exit 1
}

# ---------------------------------------------------------------- input gate
# Whitelist only. We never strip or escape bad characters out of a slug; we
# refuse anything that is not already a known-good shape.
raw="${1:-}"
[[ -n "$raw" ]] || usage

target="$raw"
target="${target#http://}"
target="${target#https://}"
# any pinterest country domain, or a bare user[/board]
case "$target" in
  *pinterest.*/*)
    target="${target#*pinterest.}"
    target="${target#*/}" ;;
esac
target="${target%/}"
target="${target%.rss}"

user="${target%%/*}"
board=""
if [[ "$target" == */* ]]; then
  board="${target#*/}"
  [[ "$board" == */* ]] && die "expected <user>/<board>, got a deeper path: $target"
fi

[[ "$user" =~ ^[A-Za-z0-9_-]{1,64}$ ]] \
  || die "username failed the whitelist ^[A-Za-z0-9_-]{1,64}\$ (got: $user)"
if [[ -n "$board" ]]; then
  [[ "$board" =~ ^[A-Za-z0-9_-]{1,128}$ ]] \
    || die "board slug failed the whitelist ^[A-Za-z0-9_-]{1,128}\$ (got: $board)"
fi

case "$SIZE" in
  236x|474x|564x|736x|originals) : ;;
  *) die "TASTE_PINTEREST_SIZE must be one of: 236x 474x 564x 736x originals (got: $SIZE)" ;;
esac
[[ "$MAX_PINS" =~ ^[0-9]{1,4}$ ]] && [[ "$MAX_PINS" -gt 0 ]] \
  || die "TASTE_PINTEREST_MAX_PINS must be a positive integer (got: $MAX_PINS)"
[[ "$DELAY" =~ ^[0-9]+(\.[0-9]+)?$ ]] \
  || die "TASTE_PINTEREST_DELAY must be a number of seconds (got: $DELAY)"

slug="$(require_slug "${2:-$(active_slug)}")"
[[ -d "$PROFILES/$slug" ]] \
  || die "no profile '$slug'. create it first: scripts/use.sh $slug"
dest="$PROFILES/$slug/moodboard"
mkdir -p "$dest"

if [[ -n "$board" ]]; then
  feed="$HOST/$user/$board.rss"
  what="board $user/$board"
else
  feed="$HOST/$user/feed.rss"
  what="profile feed for $user"
fi
feed_path="${feed#"$HOST"}"

command -v curl >/dev/null 2>&1 || die "curl is required and was not found on PATH"

# ------------------------------------------------------------------ robots
# We fetch and evaluate it at runtime rather than asserting compliance in a
# comment. The group that applies to us is User-agent: * , because taste-engine
# is not on Pinterest's submitted-crawler allowlist.
robots_verdict() {
  local path="$1" robots
  robots="$(curl -fsS --max-time 20 -A "$UA" "$HOST/robots.txt" 2>/dev/null)" || {
    echo "UNKNOWN"
    return 0
  }
  printf '%s\n' "$robots" | awk -v path="$path" '
    function norm(s) { sub(/^[ \t]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
    BEGIN { instar = 0; inua = 0; best = -1; verdict = "ALLOW" }
    {
      line = $0
      sub(/#.*/, "", line)
      line = norm(line)
      if (line == "") next
      if (index(line, ":") == 0) next
      key = tolower(norm(substr(line, 1, index(line, ":") - 1)))
      val = norm(substr(line, index(line, ":") + 1))
      if (key == "user-agent") {
        if (!inua) { inua = 1; instar = 0 }   # a new group starts here
        if (val == "*") instar = 1
        next
      }
      if (key != "allow" && key != "disallow") next
      inua = 0                                 # we are in the rules of this group
      if (!instar) next
      pat = val
      sub(/\*$/, "", pat)                      # trailing wildcard = prefix rule
      if (pat == "") next
      if (index(path, pat) == 1 && length(pat) >= best) {
        # longest match wins; Allow wins an equal-length tie
        if (length(pat) > best || key == "allow") {
          best = length(pat)
          verdict = (key == "allow" ? "ALLOW" : "DISALLOW")
        }
      }
    }
    END { print verdict }'
}

verdict="$(robots_verdict "$feed_path")"
echo "robots.txt ($HOST) for $feed_path -> $verdict"

if [[ "$verdict" != "ALLOW" ]]; then
  if [[ "${TASTE_PINTEREST_ACK_ROBOTS:-}" != "1" ]]; then
    {
      echo ""
      echo "error: pinterest.com/robots.txt returns \"$verdict\" for $feed_path."
      echo ""
      echo "  Pinterest's robots.txt ends with:"
      echo ""
      echo "      User-agent: *"
      echo "      Disallow: /"
      echo ""
      echo "  Every bot that is not on their submitted-crawler allowlist is"
      echo "  disallowed site-wide. That covers the .rss feeds, and i.pinimg.com"
      echo "  says the same thing. This script will not fetch anything while that"
      echo "  is true and unacknowledged."
      echo ""
      echo "  There is no key you can add and no app review that changes this. It"
      echo "  is a crawler policy, not an auth wall. So the call is yours, once:"
      echo ""
      echo "    - Pulling a board into your own moodboard, by hand, at your own"
      echo "      keyboard, one request per board plus one per image, is the same"
      echo "      category of traffic as a feed reader or opening the page. Then:"
      echo ""
      echo "          export TASTE_PINTEREST_ACK_ROBOTS=1"
      echo ""
      echo "    - If you want this unattended, on a schedule, or across boards"
      echo "      that are not yours, do not set that. Get on the allowlist:"
      echo "      https://help.pinterest.com/bot-submission-form"
      echo ""
      echo "  Nothing was downloaded."
      echo ""
    } >&2
    exit 2
  fi
  echo "note: TASTE_PINTEREST_ACK_ROBOTS=1 is set, proceeding as a user-initiated fetch"
fi

# ------------------------------------------------------------------- feed
echo "fetching $what"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
code="$(curl -sS --max-time 30 -A "$UA" -o "$tmp" -w '%{http_code}' "$feed")" \
  || die "network call to $feed failed"

if [[ "$code" != "200" ]]; then
  body="$(head -c 200 "$tmp" | tr -d '\r\n')"
  case "$code" in
    404) die "Pinterest returned 404 ($body). Check the spelling, and note that private and secret boards have no public feed." ;;
    429) die "Pinterest returned 429 (rate limited). Wait a few minutes and raise TASTE_PINTEREST_DELAY before retrying." ;;
    *)   die "Pinterest returned HTTP $code for $feed. Body: $body" ;;
  esac
fi

# Validate the payload before trusting it. A login wall or an interstitial comes
# back as 200 text/html, so a status check on its own proves nothing.
head -c 4000 "$tmp" | grep -q '<rss' \
  || die "$feed returned HTTP 200 but the body is not RSS. Pinterest has most likely gated or retired the public .rss feeds. First 200 bytes: $(head -c 200 "$tmp" | tr -d '\r\n')"

board_title="$(sed -n 's|.*<title>\(.*\)</title>.*|\1|p' "$tmp" | head -1)"
board_title="${board_title:-$user}"

# One record per <item>. Pairing two separate greps would silently desync the
# moment an item has a guid but no image (video and idea pins do this), so parse
# per item and drop any record missing either half.
mapfile -t records < <(awk 'BEGIN { RS = "<item>" } NR > 1 {
    gsub(/\n/, " ")
    pid = ""; img = ""
    if (match($0, /<guid>https:\/\/www\.pinterest\.com\/pin\/[0-9]+\/<\/guid>/)) {
      g = substr($0, RSTART, RLENGTH); sub(/.*\/pin\//, "", g); sub(/\/<\/guid>/, "", g); pid = g
    }
    if (match($0, /i\.pinimg\.com\/236x\/[^&"]+/)) {
      m = substr($0, RSTART, RLENGTH); sub(/i\.pinimg\.com\/236x\//, "", m); img = m
    }
    if (pid != "" && img != "") printf "%s %s\n", pid, img
  }' "$tmp")

[[ ${#records[@]} -gt 0 ]] \
  || die "parsed 0 usable pins out of $feed. The feed format may have changed; open the URL and look at it."

echo "board title    : $board_title"
echo "pins in feed   : ${#records[@]} (the public feed caps out around 25, it is not the whole board)"

# ---------------------------------------------------------------- download
got=0
skipped=0
failed=0
manifest=()

for rec in "${records[@]}"; do
  [[ "$got" -lt "$MAX_PINS" ]] || break
  pid="${rec%% *}"
  path="${rec#* }"

  # Whitelist again on the way out. These values came off the network, so they
  # are untrusted input for the URL and the filename we are about to build.
  [[ "$pid" =~ ^[0-9]{1,32}$ ]] || { failed=$((failed + 1)); continue; }
  [[ "$path" =~ ^[0-9a-f]{2}/[0-9a-f]{2}/[0-9a-f]{2}/[0-9a-f]{32}\.(jpg|jpeg|png|webp|gif)$ ]] \
    || { failed=$((failed + 1)); continue; }

  ext="${path##*.}"
  out="$dest/pin-$pid.$ext"

  if [[ -f "$out" ]]; then
    skipped=$((skipped + 1))
    manifest+=("$(basename "$out")|$pid")
    continue
  fi

  icode="$(curl -sS --max-time 30 -A "$UA" -o "$out" -w '%{http_code}' "$CDN/$SIZE/$path" || echo 000)"

  # `originals` is not stored for every pin and sometimes under a different
  # extension. Fall back to the largest size Pinterest always generates.
  if [[ "$icode" != "200" && "$SIZE" == "originals" ]]; then
    sleep "$DELAY"
    icode="$(curl -sS --max-time 30 -A "$UA" -o "$out" -w '%{http_code}' "$CDN/736x/$path" || echo 000)"
  fi

  if [[ "$icode" == "200" ]]; then
    got=$((got + 1))
    manifest+=("$(basename "$out")|$pid")
    printf '  + %s\n' "$(basename "$out")"
  else
    rm -f "$out"
    failed=$((failed + 1))
    printf '  ! pin %s failed (HTTP %s)\n' "$pid" "$icode" >&2
  fi

  # Be a good guest: one image at a time, with a real gap between requests.
  sleep "$DELAY"
done

# ------------------------------------------------------------- provenance
# Gitignored, same as the images. It holds board URLs, which are personal, and
# the repo's rule is that only DERIVED taste text is committed. The board title
# still travels, because vision writes it into taste-dna.md as a style label.
sources="$PROFILES/$slug/moodboard-sources.md"
if [[ ! -f "$sources" ]]; then
  {
    echo "# Moodboard sources: $slug"
    echo ""
    echo "> Where the images in \`moodboard/\` came from. Local only, gitignored"
    echo "> alongside the images themselves. The derived taste text in"
    echo "> \`taste-dna.md\` is the part that gets committed."
  } > "$sources"
fi
{
  echo ""
  echo "## $(today) | pinterest | $what"
  echo "- feed:        $feed"
  echo "- style label: $board_title"
  echo "- size:        $SIZE"
  for m in "${manifest[@]}"; do
    echo "- ${m%%|*} <- $HOST/pin/${m#*|}/"
  done
} >> "$sources"

echo ""
echo "downloaded $got, already had $skipped, failed $failed -> profiles/$slug/moodboard/"
echo "provenance  -> profiles/$slug/moodboard-sources.md (gitignored)"
echo "style label -> \"$board_title\""
echo ""
echo "next: run '/ts mood' so vision reads the new images into taste-dna.md."
