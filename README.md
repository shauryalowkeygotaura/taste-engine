# taste-engine

A self-improving, per-project design taste layer for Claude Code.

Most "design taste" for AI is a static ruleset: someone writes 1,000 lines of
opinions and every project inherits the same defaults. taste-engine is different.
It learns YOUR aesthetic, keeps a separate taste per project, and lets you feed it
a moodboard of reference images that it reads and turns into concrete rules.

It does three things a fixed ruleset cannot:

- **Per-project taste** - a `_global` profile that refines across everything, plus
  one override profile per project. Your fintech dashboard and your band's landing
  page do not share an aesthetic anymore.
- **Moodboard ingestion** - drop reference images in a folder; vision reads them and
  writes a structured taste-DNA (sampled palette, type feel, motion, density, vibe).
- **Self-improvement** - every correction you make ("darker", "kill the serif") is
  journaled, and recurring corrections get promoted into hardened rules. The taste
  sharpens the more you use it.

> taste-engine is a meta-layer. If you already have a base design skill installed,
> it honors that as the floor and layers your personal, per-project taste on top.

---

## How it works

Taste is resolved as a cascade. Later layers win only where they speak:

```
base design skill  (the floor, if installed)
      |
  _global/profile.md          your cross-project DNA
      |
  <project>/profile.md        overrides for this job
      |
  <project>/taste-dna.md      extracted from the moodboard
      |
  <project>/journal.md        recent, not-yet-hardened corrections
```

Before building anything, the engine states a one-line **taste read** (page kind,
audience, vibe, lead colors, motion, density, and how many learned rules are
active), then builds to it.

### The moodboard

```
profiles/<project>/moodboard/   <- drop ref images here (png/jpg/webp/gif)
```

Run `/ts mood` (or start a design task) and Claude reads each new image,
samples the real palette, and writes `taste-dna.md`. Source images are gitignored
by default, since references are often copyrighted; the extracted text is what
travels with the repo.

You can fill that folder by hand, or pull a board from Pinterest into it. See
[Pinterest as a moodboard source](#pinterest-as-a-moodboard-source).

### Pinterest as a moodboard source

Pinterest is not a second kind of taste source. It fills the same
`moodboard/` folder, and everything downstream is unchanged: vision reads the
images, writes `taste-dna.md`, and the cascade applies it. There is no separate
Pinterest profile, no separate vocabulary, no extra file to learn.

```bash
export TASTE_PINTEREST_ACK_ROBOTS=1        # read the robots.txt note below first
scripts/pinterest.sh https://www.pinterest.com/travisneilson/neo-brutalist-websites/
```

or, in a session, `/ts pin <board-url>`, which pulls the board and ingests it in
one step.

It reads the board's public `.rss` feed, downloads the pins at 736px into the
active project's `moodboard/` as `pin-<pinid>.jpg`, and appends provenance to
`profiles/<slug>/moodboard-sources.md`. The board's own title comes back as a
**style label** ("Neo brutalist websites") and lands in `taste-dna.md` under
`## Named references`. That is the one bit of design signal the feed carries that
the pixels do not.

**No API key, no login, no app review.** Pinterest's official API gates board and
pin reads behind an approved app, which is absurd overhead for a personal
moodboard, so this path does not touch it. Nothing here reads a credential and
nothing here stores a cookie.

#### What you should know before using it

- **robots.txt says no, and the script says so out loud.** `pinterest.com/robots.txt`
  ends with `User-agent: *` / `Disallow: /`, and `i.pinimg.com` matches. Every bot
  not on [Pinterest's submitted-crawler allowlist](https://help.pinterest.com/bot-submission-form)
  is disallowed site-wide, `.rss` included. No key or app review changes that; it
  is a crawler policy, not an auth wall. So the script fetches robots.txt at
  runtime, evaluates the `User-agent: *` group against the URL it is about to
  request, and **refuses with exit 2** unless you have explicitly set
  `TASTE_PINTEREST_ACK_ROBOTS=1`. Pulling a board you chose, by hand, one request
  per board plus one per image with a delay between, is feed-reader traffic and
  you may well decide that is fine. Running it unattended, on a schedule, or
  across boards that are not yours is crawling, and you should get allowlisted
  instead. The script will not make that call for you.
- **A public feed is a sample, not a mirror.** It returns roughly the 25 most
  recent pins. A 400-pin board gives you its newest 25. Re-running skips what you
  already have and pulls further down, so repeated runs deepen the board rather
  than redownload it.
- **Private and secret boards have no public feed.** You get a clean
  `404 Board not found`. There is no fallback and none is offered.
- **The pins are other people's images.** Same rule as the rest of the moodboard:
  they stay local. `moodboard-sources.md` is gitignored too, because board URLs
  are personal. Only the derived taste text is committed.

#### Environment

| Variable | Default | What it does |
|---|---|---|
| `TASTE_PINTEREST_ACK_ROBOTS` | unset | Must be `1` to proceed past the robots.txt gate. No default, deliberately. |
| `TASTE_PINTEREST_MAX_PINS` | `24` | Cap on new images per run. |
| `TASTE_PINTEREST_SIZE` | `736x` | One of `236x 474x 564x 736x originals`. `originals` falls back to `736x` when a pin has none. |
| `TASTE_PINTEREST_DELAY` | `1.5` | Seconds between requests. Raise it, do not lower it. |
| `TASTE_PINTEREST_UA` | descriptive taste-engine UA | Sent on every request. It identifies the tool honestly; do not set it to a browser string. |

### Getting smarter over time

Every aesthetic correction lands in the project journal:

```
## 2026-07-24 | marrow
- signal: hero CTA in brass
- correction: "accent should be terracotta, not brass"
- rule: accent is terracotta (#c96f4a)
- scope: project
- distilled: no
```

When a pattern repeats (default: 2 matching entries), `/ts distill` promotes it
into `profile.md` under **Hardened Rules**, with newer feedback overriding older.
One-off nitpicks stay in the journal and never harden. The journal is append-only,
so you keep a full audit trail of how the taste evolved.

---

## Install

```bash
git clone https://github.com/<you>/taste-engine.git
cd taste-engine
bash install.sh          # copies the skill into ~/.claude/skills, points it back here
```

Restart Claude Code so it picks up the skill.

### Optional: the Stop hook

Distilling only helps if you remember to do it. The optional Stop hook counts the
journal entries still marked `distilled: no` at the end of each session and prints
one line once there are enough of them to actually harden a rule:

```
taste-engine: 3 undistilled correction(s) waiting (_global 2, marrow 1). Run /ts distill to harden the repeats.
```

Below the threshold it prints nothing, so it does not tax every session you run.

```bash
bash hooks/install-hook.sh              # add it (or refresh the path after a move)
bash hooks/install-hook.sh --uninstall  # take it back out
bash install.sh --with-hook             # or do both in one go
```

It edits `~/.claude/settings.json` (honoring `CLAUDE_CONFIG_DIR`), backs the file
up to `settings.json.taste-engine.bak` first, and is idempotent: re-running
replaces the old entry instead of stacking a second one. Set
`TASTE_STOP_THRESHOLD` to change the trigger count (default `2`, matching the
promotion threshold in `profile.md`).

The hook is deliberately a **nudge, not an auto-capture**. It never writes to the
journal and never blocks a session. Recording corrections is the skill's job
(SKILL.md section 4), and it already does that the moment you say them, so a hook
that also wrote entries would only duplicate them and pollute the audit trail.
`hooks/stop-nudge.example.json` has the raw snippet if you prefer to paste it by
hand.

## Usage

In a Claude Code session the command is `/ts`. One command, short:

| Command | What it does |
|---|---|
| `/ts <slug>` | create-or-activate a project (creates the first time, switches after) |
| `/ts` | status: active slug, layer counts, undistilled notes |
| `/ts learn "<note>"` | log a correction to the journal |
| `/ts mood` | (re)ingest the active project's moodboard |
| `/ts pin <board-url>` | pull a public Pinterest board into the moodboard, then ingest it |
| `/ts distill` | harden recurring corrections into rules |

`/ts marrow` is the whole create-and-switch flow, so there is no separate "new"
step. Reserved words (`learn mood moodboard distill status use new pin
pinterest`) cannot be project slugs. Prefer a different prefix? Rename `commands/ts.md` to
`commands/<yourword>.md`.

Outside a session, the same actions exist as scripts:

```bash
scripts/use.sh marrow          # create-or-activate in one shot
# drop images into profiles/marrow/moodboard/, or pull a board:
scripts/pinterest.sh https://www.pinterest.com/<user>/<board>/
scripts/learn.sh "accent should be terracotta, not brass"
scripts/status.sh
```

Then just work. When the taste is active, ask Claude to build a page and it will
apply the cascade automatically.

---

## Repo structure

```
taste-engine/
  SKILL.md                     the Claude Code skill (the brain)
  base/taste-baseline.md       minimal anti-slop floor when no base skill exists
  profiles/
    _global/                   cross-project taste (seeded, refines over time)
    _template/                 copied by `new-project`
    example-dark-portfolio/    a worked example (profile + dna + journal)
    <your projects>/
      profile.md               taste rules for this project
      taste-dna.md             extracted from the moodboard
      journal.md               correction log (append-only)
      moodboard/               drop reference images here (gitignored)
      moodboard-sources.md     where pulled images came from (gitignored)
  commands/ts.md               the /ts slash command
  scripts/                     bash equivalents of the slash commands
    pinterest.sh               fill a moodboard from a public board's RSS
  hooks/
    taste-stop.sh              optional Stop hook: nudges you to distill
    install-hook.sh            adds/removes that hook in settings.json
    stop-nudge.example.json    the same block, to paste by hand
  install.sh
```

## Design notes

- **Separation of concerns.** taste-engine never bakes in a specific look. It
  captures and applies yours. Swap the base skill freely.
- **The moodboard stays private.** Only the derived text is committed.
- **Pinterest is an input, not a feature.** It fills `moodboard/` and then gets out
  of the way. Adding a source must never add a vocabulary; if a future source
  cannot be reduced to "images in the folder, plus a style label", it does not
  belong here.
- **The journal is truth.** Distill reads and marks entries; it never rewrites the
  past. You can always see why a rule exists.
- **You own the promotion policy.** Each `profile.md` has a `## Promotion Policy`
  block controlling the threshold and how conflicts resolve. Edit it.

## License

MIT. See [LICENSE](LICENSE).
