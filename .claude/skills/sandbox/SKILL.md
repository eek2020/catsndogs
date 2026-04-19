---
name: sandbox
description: Run an isolated experiment in sandbox/ (fully separate Godot project) or promote a working sandbox experiment into godot/ via a gated wizard — scan, per-file triage, dependency check, staged copy with `git add`, headless-open + GUT + changelog + codemap gates, revert manifest. Use when the user wants to prototype 2D/2.5D/3D ideas without risking the main codebase, or when they want to push working sandbox code into godot/ without hand-identifying files. Never commits or pushes.
---

# Sandbox skill

The sandbox gives the user a fully isolated Godot project at `sandbox/` (gitignored via `/sandbox/` at `.gitignore:25`) where they can prototype without touching `godot/`. Two flows are supported:

- **Start a new experiment** (wipe sandbox, scaffold manifest, optionally seed assets from `godot/`).
- **Promote a working experiment** into `godot/` with button-choice triage and four safety gates.

Parallel IDE entry points exist at `.windsurf/workflows/new-experiment.md` and `.windsurf/workflows/promote-experiment.md` — this skill is the Claude Code equivalent.

## When to run

- User says they want to "test", "try", "prototype", "sandbox", "experiment", or "play with" something — propose `/new-experiment` first.
- User says "2D → 2.5D", "2.5D → 3D", or "try 3D" ideas — these are the canonical sandbox use cases.
- User has a working sandbox feature and says "push this to main", "merge this", "promote this", "bring this in" — run the promotion flow.
- User asks "which files would change?" after sandbox work — run `promote.py scan` and report without staging.

## Underlying CLI

All heavy lifting is in `tools/sandbox/`:

- `tools/sandbox/promote.py` — nine subcommands (`scan`, `map`, `deps`, `stage`, `revert`, `test-open`, `test-gut`, `changelog`, `codemap`).
- `tools/sandbox/reset.py` — wipe sandbox contents (keeps `project.godot` + `README.md`).
- `tools/sandbox/seed.py` — copy selected `godot/` subtrees into `sandbox/` as starting assets.
- `tools/sandbox/README.md` — detailed CLI reference.

All scripts are pure stdlib Python 3. Logs go to `logs/sandbox-promote.log`.

## Flow A — Start a new experiment

1. **Inspect current state.** Read `sandbox/.experiment.json` if it exists and show the user the `name` / `intent` / `started` fields. Run `python3 tools/sandbox/promote.py scan --json` to count any promotable files — if non-zero, the previous experiment has untriaged work.
2. **Ask the user** (button choices) whether to:
   - Reset & continue,
   - Abort,
   - Keep contents but rewrite the manifest only.
3. **If resetting**, run `python3 tools/sandbox/reset.py --force`.
4. **Ask the user** what experiment type this is: `2D`, `2.5D`, `3D`, or `custom`.
5. **Ask for a short intent line.** Derive a slug for `name`.
6. **Write `sandbox/.experiment.json`**:

    ```json
    {
      "name": "<slug>",
      "type": "<2D|2.5D|3D|custom>",
      "intent": "<one-liner>",
      "started": "<ISO timestamp>"
    }
    ```

7. **Offer asset seeding** (button choices, multi-select): tiles, characters, audio, or skip. For each, run `python3 tools/sandbox/seed.py --from assets/<dir>`.
8. **Confirm**. Print experiment summary + remind the user that `/promote-experiment` (or this skill's Flow B) is how they push working ideas to `godot/`.

This flow never touches `godot/`.

## Flow B — Promote an experiment

Each step below maps to one or more CLI calls. Every gate emits a JSON report; read it and surface the result to the user as a button-choice question on failure.

### 1. Preflight

Read `sandbox/.experiment.json`. If missing, ask whether to write one now or abort. Show `name` / `type` / `intent` so the user confirms this is the right experiment.

### 2. Scan

```bash
python3 tools/sandbox/promote.py scan --json > logs/sandbox-scan.json
```

Parse the JSON, show the user a grouped table of `NEW` / `MODIFIED` entries. If empty, print "Nothing to promote" and stop.

### 3. Triage

Ask the user with button choices:

- **Promote all** — default target for every file (`sandbox/X → godot/X`).
- **Triage individually** — per-file question: *Promote* / *Skip* / *Rename target*.
- **Abort** — stop without staging.

Build `logs/sandbox-pairs.json` as `[{"source": "...", "target": "..."}, ...]`.

### 4. Dependency scan

```bash
python3 tools/sandbox/promote.py deps --pairs logs/sandbox-pairs.json --json > logs/sandbox-deps.json
```

Show the user any `MISSING` `res://` refs. For each, offer: *Copy from sandbox* / *Mark external* / *Abort*. If copying, append to `pairs.json` and re-run deps until no surprises remain.

### 5. Stage

```bash
python3 tools/sandbox/promote.py stage --pairs logs/sandbox-pairs.json --manifest logs/sandbox-revert.json --json
```

From this point, `godot/` has staged changes and a revert manifest exists.

### 6. Gate 1 — headless open

```bash
python3 tools/sandbox/promote.py test-open
```

On non-zero exit, offer: *Revert & abort* / *Keep staged, I'll fix manually* / *Re-run gate*.

### 7. Gate 2 — GUT tests

```bash
python3 tools/sandbox/promote.py test-gut
```

Same three choices on failure.

### 8. Gate 3 — changelog

Button choice. If **Write stub entry**, ask for a 1-line summary, then:

```bash
python3 tools/sandbox/promote.py changelog --summary "<...>" --files-from logs/sandbox-pairs.json
```

### 9. Gate 4 — codemap

Button choice. If **Regenerate**, run:

```bash
python3 tools/sandbox/promote.py codemap
```

(Thin wrapper over `bash .claude/skills/codemap/generate.sh`.)

### 10. Summary

Print experiment name + intent, files staged, gate results, revert manifest path, and a commit hint:

```bash
git status
git diff --cached
git commit -m "feat(sandbox): promote <experiment-name> — <summary>"
```

Do **not** run any `git commit` or `git push`. Leave staging to the user.

## Revert

If anything goes wrong after Step 5, roll back with:

```bash
python3 tools/sandbox/promote.py revert --manifest logs/sandbox-revert.json
```

This unstages and deletes newly-created files, and restores modified files from `HEAD`. `godot/` ends up byte-identical to its pre-stage state.

## Invariants

- The sandbox is **single-slot** — one active experiment at a time. `/new-experiment` wipes before scaffolding.
- The wizard **never** runs `git commit` or `git push`. It stops at `git add`.
- Every destructive step must be preceded by an explicit user confirmation.
- `tools/sandbox/*` is **not** ignored (`.gitignore:25` anchors the ignore to `/sandbox/`). `sandbox/` at the repo root **is** ignored.
- Logs always go to `logs/sandbox-promote.log` — do not spam the chat with gate output; summarize and link.

## Relationship to other docs

- [`CLAUDE.md`](../../../CLAUDE.md) — architecture rules for the main project.
- [`sandbox/README.md`](../../../sandbox/README.md) — sandbox-project-side doc (how to open in Godot, conventions).
- [`tools/sandbox/README.md`](../../../tools/sandbox/README.md) — full CLI reference for manual use.
- [`.windsurf/workflows/new-experiment.md`](../../../.windsurf/workflows/new-experiment.md) and [`promote-experiment.md`](../../../.windsurf/workflows/promote-experiment.md) — the Windsurf IDE twins of Flow A / B.
