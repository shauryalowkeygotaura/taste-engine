---
name: taste-engine
description: A self-improving, per-project design taste layer. Loads a global taste profile plus a project-specific override, ingests a moodboard of reference images into a taste-DNA, applies it to frontend/design work, then learns from your corrections and hardens recurring feedback into rules over time. Use when the user says "use my taste", "/taste", drops a moodboard, or starts frontend/design work that should match their personal aesthetic.
---

# taste-engine

A meta-layer over whatever base taste skill you already have. It does three jobs
a static ruleset cannot:

1. **Per-project taste.** A `_global` profile that refines across every project,
   plus one override profile per project slug.
2. **Moodboard ingestion.** Drop reference images in a folder; vision reads them
   and writes a structured taste-DNA.
3. **Self-improvement.** A journal captures your corrections; a distill step
   promotes the recurring ones into hardened rules, so the taste sharpens with use.

> This skill does NOT replace a base design skill (typography, layout, anti-slop
> rules). If one is installed, honor it first, then apply the layers below on top.

---

## 0. RESOLVE THE ACTIVE PROJECT

The engine lives at `PROFILES_ROOT` (default: this skill's `profiles/` directory;
if the repo was cloned elsewhere, the installed copy points `PROFILES_ROOT` at the
clone via the `.taste-root` pointer file next to this skill).

1. Read the active slug from `PROFILES_ROOT/.active`. If missing, the active slug
   is `_global`.
2. The user can switch with `/taste use <slug>` (writes `.active`) or override for
   one turn with an explicit slug in the request ("build the marrow landing with
   the `marrow` taste").

---

## 1. LOAD LAYERS (in this exact order, later layers win on conflict)

Apply as a cascade. A lower layer only overrides a higher one where it actually
speaks; silence means "inherit".

1. **Base taste skill** - if `~/.claude/skills/taste-skill/SKILL.md` (or any
   installed design skill) exists, load and obey it as the floor.
2. **Global profile** - `PROFILES_ROOT/_global/profile.md`. Your cross-project DNA.
3. **Project profile** - `PROFILES_ROOT/<slug>/profile.md`. Overrides for this job.
4. **Project taste-DNA** - `PROFILES_ROOT/<slug>/taste-dna.md`. Extracted from the
   moodboard (concrete palette, type, motion, density, references).
5. **Recent journal** - the last undistilled entries in
   `PROFILES_ROOT/<slug>/journal.md` and `PROFILES_ROOT/_global/journal.md`.
   These are corrections not yet hardened; treat them as active guidance.

---

## 2. MOODBOARD INGESTION

Before building, check `PROFILES_ROOT/<slug>/moodboard/` for image files
(`.png .jpg .jpeg .webp .gif`).

- If there are images whose filenames are NOT already logged at the bottom of
  `taste-dna.md` under `## Ingested`, they are new. **Read each new image with
  vision** and extract:
  - **Palette**: 4 to 6 dominant hex values, labeled (background / text / accent).
  - **Type feel**: serif vs sans, weight, tightness, any named lookalike font.
  - **Layout & density**: airy vs packed, grid rhythm, alignment bias.
  - **Motion read**: still, subtle, or cinematic (guess intensity 1 to 10).
  - **Vibe words**: 3 to 6 adjectives.
  - **Named references**: brands/sites the board evokes.
- Merge the extraction into `taste-dna.md` (rewrite the structured sections,
  keep an `## Ingested` list of filenames already processed so you never
  double-count). Never invent hexes you did not see; sample from the images.
- If the board is contradictory (two clashing directions), say so in one line and
  ask which direction, per the base skill's one-question rule. Do not average them
  into mud.

Re-run this any time with `/taste moodboard`.

---

## 3. THE TASTE READ (before any code)

Collapse the whole cascade into ONE line, the same way a good base skill states a
design read:

> "Taste read: `<project>` reads as `<page kind>` for `<audience>`, `<vibe>`
> language, palette `<lead colors>`, motion `<n>/10`, density `<n>/10`. Honoring
> `<count>` hardened rules and `<count>` live journal notes."

Then build. If the cascade is silent on something material, fall back to the base
skill, not to generic AI defaults.

---

## 4. CAPTURE (learn from corrections)

Any time the user corrects the aesthetic ("no, darker", "kill the serif", "too
much motion", "that accent is too loud", "more whitespace"), append an entry to
the ACTIVE project's `journal.md` (or `_global/journal.md` if the note is clearly
cross-project, e.g. "I never want purple gradients anywhere"):

```
## <YYYY-MM-DD> | <slug>
- signal: <what you built>
- correction: <what they said>
- rule: <the generalizable takeaway, one line>
- scope: project | global
- distilled: no
```

Do this silently and immediately. One correction, one entry. Do not wait for a
distill run to record.

You can also log manually: `/taste learn "accent should be terracotta not brass"`.

---

## 5. DISTILL (self-improvement)

Trigger: on `/taste distill`, OR automatically when a journal accumulates
`DISTILL_THRESHOLD` (default 5) entries with `distilled: no`.

Procedure:
1. Read all undistilled entries for the scope.
2. Cluster them. A pattern is a rule when >= 2 entries point the same way.
3. Promote each pattern into the matching `profile.md` under `## Hardened Rules
   (learned)`, phrased as an imperative one-liner with a date tag, e.g.
   `- [2026-07-24] Accent is terracotta (#c96f4a), never brass/ochre.`
4. **Conflict policy** lives in `profile.md` under `## Promotion Policy` and is
   user-owned. Default: newer feedback wins; when a new rule contradicts an
   existing hardened rule, REPLACE the old line and append
   `(was: <old rule>)` so the history is visible.
5. Mark the consumed journal entries `distilled: yes` (do not delete them; the
   journal is the audit trail).
6. Report a one-line summary of what hardened.

Single, isolated, never-repeated nitpicks stay in the journal and do NOT get
promoted. Taste is the pattern, not every stray comment.

---

## 6. COMMANDS

The slash command is `/ts`. One command, short:

- `/ts <slug>` - create-or-activate a project in one shot (creates it the first
  time you name it, switches to it every time after). This is the common path.
- `/ts` - status (active slug, layer counts, undistilled entries).
- `/ts learn "<note>"` - append a correction to the journal.
- `/ts mood` - re-ingest the active project's moodboard images.
- `/ts distill` - harden recurring journal entries into rules now.

Reserved words (`learn mood moodboard distill status use new`) cannot be project
slugs. The `scripts/` directory has bash equivalents (`use.sh`, `learn.sh`,
`status.sh`, and the lower-level `new-project.sh` / `set-active.sh`) for use outside
a Claude session.

---

## 7. GUARDRAILS

- Never publish the user's moodboard images. Reference images may be copyrighted;
  `.gitignore` excludes them by default. The extracted taste-DNA (text) is safe to
  commit; the source images are not.
- Never fabricate a palette. If there is no moodboard and no profile color, say the
  taste is unset and fall back to the base skill.
- The journal is append-only truth. Distill reads and marks; it never rewrites a
  past correction.
- Keep copy em-dash-free and honor the base skill's anti-slop bans.
