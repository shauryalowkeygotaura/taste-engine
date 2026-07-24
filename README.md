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

Run `/taste moodboard` (or start a design task) and Claude reads each new image,
samples the real palette, and writes `taste-dna.md`. Source images are gitignored
by default, since references are often copyrighted; the extracted text is what
travels with the repo.

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

When a pattern repeats (default: 2 matching entries), `/taste distill` promotes it
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

## Usage

In a Claude Code session:

| Command | What it does |
|---|---|
| `/taste new <slug>` | scaffold a new project profile |
| `/taste use <slug>` | set the active project |
| `/taste moodboard` | (re)ingest the active project's moodboard |
| `/taste learn "<note>"` | log a correction to the journal |
| `/taste distill` | harden recurring corrections into rules |
| `/taste status` | active slug, layer counts, undistilled notes |

Outside a session, the same actions exist as scripts:

```bash
scripts/new-project.sh marrow
scripts/set-active.sh marrow
# drop images into profiles/marrow/moodboard/
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
  scripts/                     bash equivalents of the slash commands
  hooks/                       optional Stop-hook example
  install.sh
```

## Design notes

- **Separation of concerns.** taste-engine never bakes in a specific look. It
  captures and applies yours. Swap the base skill freely.
- **The moodboard stays private.** Only the derived text is committed.
- **The journal is truth.** Distill reads and marks entries; it never rewrites the
  past. You can always see why a rule exists.
- **You own the promotion policy.** Each `profile.md` has a `## Promotion Policy`
  block controlling the threshold and how conflicts resolve. Edit it.

## License

MIT. See [LICENSE](LICENSE).
