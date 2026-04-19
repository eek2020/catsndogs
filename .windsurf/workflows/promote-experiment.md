---
description: Promote a working sandbox experiment into godot/ via a gated wizard (no commit, no push)
---

# Promote Experiment

Walk a working experiment from `sandbox/` into the main `godot/` project with button-choice triage and four safety gates. **Never commits, never pushes.** Produces a revert manifest so anything can be rolled back.

## Step 1 — Preflight

Read `sandbox/.experiment.json`. If missing, use `ask_user_question`:

- **Create manifest now** — prompt user for intent, write a fresh `.experiment.json`, continue
- **Abort** — exit the workflow

Show the user the experiment `name`, `type`, `intent` so they confirm it is the one they want to promote.

## Step 2 — Scan

// turbo
Run `python3 tools/sandbox/promote.py scan --json > logs/sandbox-scan.json` and parse it. Show a human-readable table of NEW / MODIFIED entries grouped by directory. If the list is empty, print "Nothing to promote" and exit.

## Step 3 — Triage strategy

Use `ask_user_question`:

- **Promote all** — every listed file goes into the pairs manifest with its default target
- **Triage individually** — walk each file one-by-one (Promote / Skip / Rename target)
- **Skip all & abort** — bail without staging

## Step 4 — Per-file triage (only if user chose "Triage individually")

For each scan entry, use `ask_user_question`:

- **Promote** — add to pairs with default target (`sandbox/X -> godot/X`)
- **Skip** — exclude from this promotion
- **Rename target** — prompt for a new target path under `godot/`, add to pairs

Build `logs/sandbox-pairs.json` as a JSON list of `{"source": "...", "target": "..."}`.

## Step 5 — Dependency scan

// turbo
Run `python3 tools/sandbox/promote.py deps --pairs logs/sandbox-pairs.json --json > logs/sandbox-deps.json`. Show the user any `MISSING` refs grouped by source file.

If there are missing refs, use `ask_user_question`:

- **Copy all missing from sandbox** — treat each missing `res://X` as a sandbox file to also promote; append to pairs.json and re-run deps
- **Triage individually** — walk each missing ref, asking `Copy` / `Mark external (skip)` / `Abort`
- **Mark all external** — proceed, accepting the unresolved refs (use if the refs point to work that legitimately lives outside `godot/`)
- **Abort** — bail

## Step 6 — Stage

Run `python3 tools/sandbox/promote.py stage --pairs logs/sandbox-pairs.json --manifest logs/sandbox-revert.json --json`. Report count of files staged + manifest path. From this point, `godot/` has changes, `git add` has been run, and `logs/sandbox-revert.json` is the rollback key.

## Step 7 — Gate 1: headless open

// turbo
Run `python3 tools/sandbox/promote.py test-open`. On non-zero exit, use `ask_user_question`:

- **Revert & abort** — run `promote.py revert --manifest logs/sandbox-revert.json` and stop
- **Keep staged, I will fix manually** — leave files in place for the user to inspect + debug
- **Re-run the gate** — after the user says they have fixed something, loop back

## Step 8 — Gate 2: GUT tests

// turbo
Run `python3 tools/sandbox/promote.py test-gut`. On non-zero exit, offer the same three button choices as Step 7 (Revert / Keep / Re-run).

## Step 9 — Gate 3: changelog

Use `ask_user_question`:

- **Write stub entry** — ask user for a 1-line summary, then run `promote.py changelog --summary "<...>" --files-from logs/sandbox-pairs.json`
- **Skip** — no changelog entry this time

## Step 10 — Gate 4: codemap

Use `ask_user_question`:

- **Regenerate now** — run `promote.py codemap`
- **Skip** — user will regenerate later

## Step 11 — Summary

Print a final block with:

- Experiment name + intent (from `.experiment.json`)
- Files staged (count + target paths under `godot/`)
- Gate results (open / GUT / changelog / codemap)
- Revert manifest path
- Commit hint, e.g.:

```bash
git status
git diff --cached
git commit -m "feat(sandbox): promote <experiment-name> — <summary>"
```

Do NOT run any git commit / push. The user drives that.

## Notes

- Every state-changing step emits a log line to `logs/sandbox-promote.log`.
- `logs/sandbox-pairs.json`, `logs/sandbox-deps.json`, and `logs/sandbox-revert.json` are gitignored (`logs/` is already ignored). Safe to keep for reference between runs.
- If you ctrl-C mid-wizard **before** Step 6, nothing under `godot/` has been touched. After Step 6, use `python3 tools/sandbox/promote.py revert --manifest logs/sandbox-revert.json` to roll back.
- Rename-target is a deliberate escape hatch; the default path rewrite is `sandbox/X -> godot/X` which handles the majority case.
