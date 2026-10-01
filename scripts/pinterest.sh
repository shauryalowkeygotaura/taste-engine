#!/usr/bin/env bash
# pull a public Pinterest board's images into a profile's moodboard
# usage: scripts/pinterest.sh <board-url> [slug]   bind the board to the project, pull it
#        scripts/pinterest.sh --refresh [slug]     re-pull the project's bound board
#
# Pinterest is not a second kind of taste source. It fills the SAME moodboard
# folder, so everything downstream (vision, taste-dna, the cascade) is unchanged.
#
# ONE BOARD PER PROJECT. The bound URL lives in profiles/<slug>/board.url, which
# is gitignored like moodboard-sources.md (board URLs are personal). Binding a
# different board replaces it and says so, rather than quietly mixing two
# boards' pins into one moodboard.
#
# Exit codes:
#   0  ok
#   1  usage / fetch error
#   2  robots.txt gate - the user has not acknowledged it. Relay and STOP.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

if [[ "${1:-}" == "--refresh" ]]; then
  slug="$(require_slug "${2:-$(active_slug)}")"
  bound="$PROFILES/$slug/board.url"
  if [[ ! -s "$bound" ]]; then
    echo "error: no board bound to '$slug'. bind one: scripts/pinterest.sh <board-url> $slug" >&2
    exit 1
  fi
  board_url="$(head -1 "$bound" | tr -d '\r\n')"
  set -- "$board_url" "$slug"
fi

board_url="${1:-}"
if [[ -z "$board_url" ]]; then
  echo 'usage: scripts/pinterest.sh <board-url> [slug] | --refresh [slug]' >&2
  exit 1
fi

# Whitelist the URL rather than escaping it. Only a real Pinterest board path is
# accepted, so nothing user-supplied reaches curl as an option or another host.
if [[ ! "$board_url" =~ ^https://([a-z]{2,3}\.)?pinterest\.[a-z.]{2,6}/[A-Za-z0-9_/-]+/?$ ]]; then
  echo "error: not a public Pinterest board URL: $board_url" >&2
  echo "       expected e.g. https://www.pinterest.com/<user>/<board>/" >&2
  exit 1
fi

slug="$(require_slug "${2:-$(active_slug)}")"
dest="$PROFILES/$slug/moodboard"
if [[ ! -d "$dest" ]]; then
  echo "error: no moodboard for '$slug' at $dest" >&2
  exit 1
fi

# ── the robots.txt gate ─────────────────────────────────────────────────────
# Pinterest's robots.txt disallows crawling. The .rss feed is a published feed
# rather than a scraped page, but that is a judgement call and it is the USER'S
# to make, once, explicitly. Never work around this: no HTML scraping, no
# saved-session cookie.
if [[ "${TASTE_PINTEREST_ACK_ROBOTS:-}" != "1" ]]; then
  cat >&2 <<'GATE'
Pinterest's robots.txt disallows automated crawling.

This script reads only the board's PUBLIC .rss feed - a feed Pinterest
publishes for syndication, not a scraped page - and downloads the images it
lists. That is a narrower thing than crawling, but it is still your call to
make, not mine.

If you accept that, set it once:

    export TASTE_PINTEREST_ACK_ROBOTS=1

Then re-run. Use boards you own or that are clearly public, keep the pulled
images local as reference (they stay gitignored), and do not republish them.
GATE
  exit 2
fi

max_pins="${TASTE_PINTEREST_MAX_PINS:-24}"
if [[ ! "$max_pins" =~ ^[0-9]{1,3}$ ]] || (( max_pins < 1 )); then
  echo "error: TASTE_PINTEREST_MAX_PINS must be 1-999 (got: $max_pins)" >&2
  exit 1
fi

feed="${board_url%/}.rss"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# Validate the status before parsing: a 404 body is still a body, and parsing it
# as a feed yields zero pins and a misleading "empty board" message.
code="$(curl -sS -L -o "$tmp" -w '%{http_code}' --max-time 60 \
        -A 'Mozilla/5.0 (taste-engine moodboard fetch)' "$feed" || echo 000)"
if [[ "$code" != "200" ]]; then
  echo "error: board feed returned HTTP $code" >&2
  echo "       $feed" >&2
  echo "       A private or renamed board has no public feed." >&2
  exit 1
fi

# Bind only after the feed proved real, so a typo never replaces a good board.
bound="$PROFILES/$slug/board.url"
prev=""
if [[ -s "$bound" ]]; then prev="$(head -1 "$bound" | tr -d '\r\n')"; fi
if [[ -n "$prev" && "$prev" != "$board_url" ]]; then
  echo "note: '$slug' was bound to $prev - now bound to $board_url" >&2
  echo "      pins already pulled from the old board stay in the moodboard." >&2
fi
printf '%s\n' "$board_url" > "$bound"

# The board's own title is the one piece of design signal the feed carries that
# the pixels do not, so it is surfaced for taste-dna.md.
title="$(sed -n 's:.*<title>\(.*\)</title>.*:\1:p' "$tmp" | head -1 \
         | sed 's/<!\[CDATA\[//; s/\]\]>//' | tr -d '\r')"

# Pin images appear in the feed as 236x/564x thumbnails; 736x is the largest
# reliably available size, so rewrite the segment rather than take the thumbnail.
mapfile -t urls < <(grep -oE 'https://i\.pinimg\.com/[0-9]+x/[^"<> ]+\.jpg' "$tmp" \
                    | sed 's:/[0-9]\+x/:/736x/:' | awk '!seen[$0]++' | head -n "$max_pins")

if (( ${#urls[@]} == 0 )); then
  echo "error: no images in the feed for that board" >&2
  exit 1
fi

sources="$PROFILES/$slug/moodboard-sources.md"
[[ -f "$sources" ]] || printf '# moodboard sources\n\n' > "$sources"
{
  printf '\n## %s - %s\n' "$(today)" "${title:-pinterest board}"
  printf '%s\n\n' "$board_url"
} >> "$sources"

got=0
for u in "${urls[@]}"; do
  pinid="$(basename "$u" .jpg)"
  # Derive the filename from the URL we just whitelisted, never from feed text.
  [[ "$pinid" =~ ^[A-Za-z0-9_-]+$ ]] || continue
  out="$dest/pin-$pinid.jpg"
  if [[ -f "$out" ]]; then continue; fi
  if curl -sS -L --max-time 60 -o "$out" "$u"; then
    # A truncated download is worse than a missing one: it reaches the vision
    # pass as a corrupt image and silently poisons the read.
    if [[ -s "$out" ]] && (( $(wc -c < "$out") > 3000 )); then
      printf -- '- pin-%s.jpg %s\n' "$pinid" "$u" >> "$sources"
      got=$((got + 1))
    else
      rm -f "$out"
    fi
  fi
done

echo "pulled $got image(s) into $dest"
[[ -n "$title" ]] && echo "style label: $title"
echo
echo "Caveats worth stating rather than papering over:"
echo "  - a public feed returns roughly the 25 most recent pins, not the board"
echo "  - re-running pulls the same window; already-present pins are skipped"
