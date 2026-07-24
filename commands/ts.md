---
description: taste-engine — set the active per-project taste, log corrections, ingest a moodboard, or distill rules
argument-hint: "[slug] | learn \"note\" | mood | distill  (empty = status)"
allowed-tools: Bash, Read, Edit, Write, Glob
---

You are dispatching the `taste-engine` skill. Resolve the repo first, then act on
`$ARGUMENTS`.

## Resolve the repo
Run: `cat ~/.claude/skills/taste-engine/.taste-root` to get the profiles path
(`PROFILES`). The repo root is its parent dir; scripts live at `<repo>/scripts/`.
If `.taste-root` is missing, tell the user to run `bash install.sh` in their
taste-engine clone and stop.

## Dispatch on $ARGUMENTS

- **empty** -> run `scripts/status.sh` and report the output verbatim, one line.

- **starts with `learn `** -> everything after `learn ` is the note. Run
  `scripts/learn.sh "<note>"`. Confirm it was logged to the active project.

- **`mood` or `moodboard`** -> follow section 2 (MOODBOARD INGESTION) of the
  taste-engine SKILL.md for the ACTIVE project: read each new image in the active
  project's `moodboard/` with vision, sample the palette, and rewrite `taste-dna.md`.
  Report the extracted palette + vibe in 2 lines.

- **`distill`** -> follow section 5 (DISTILL) of the SKILL.md for the active project:
  cluster undistilled journal entries, promote recurring patterns into `profile.md`
  under `## Hardened Rules (learned)`, mark entries `distilled: yes`. Report what
  hardened in one line.

- **anything else** -> treat the first token as a project slug. Run
  `scripts/use.sh <slug>` (creates the project if new, then sets it active). Then
  load the taste cascade from the SKILL.md (base skill -> _global -> project profile
  -> taste-dna -> recent journal) and output the one-line **taste read** so the user
  knows what taste is now active. If there are un-ingested images in the project's
  moodboard, ingest them first (as in `mood`).

Keep every response tight. This is a control command, not a conversation.
