---
description: Start a fresh sandbox experiment (wipes previous experiment, writes manifest)
---

# New Experiment

Kick off a new isolated experiment in `sandbox/`. Safe — nothing under `godot/` is touched.

## Step 1 — Inspect current state

Check whether `sandbox/.experiment.json` already exists, and whether `sandbox/{scripts,scenes,assets,resources,shaders,data}/` contains any files. Read the manifest if present and show the user its `name` + `intent` + `started` fields. This is context so they know what is about to be thrown away.

## Step 2 — Count untriaged files

// turbo
Run `python3 tools/sandbox/promote.py scan --json` and count `NEW` / `MODIFIED` files. Display the count — if it is non-zero, the previous experiment has untriaged work.

## Step 3 — Decide how to proceed

If a previous experiment exists OR there are any promotable files, use `ask_user_question` with options:

- **Reset & continue** — wipe sandbox and start fresh
- **Abort** — bail without touching anything
- **Keep contents, update manifest only** — preserve files, just rewrite `.experiment.json`

## Step 4 — Reset if requested

If the user chose Reset, run `python3 tools/sandbox/reset.py --force`.

## Step 5 — Pick experiment type

Use `ask_user_question` with options:

- **2D** — traditional 2D prototyping
- **2.5D** — pseudo-3D / parallax / orthographic-with-depth
- **3D** — full 3D scene graph, SubViewports, cameras
- **Custom** — anything else (I will ask for a label)

## Step 6 — Capture intent

Ask the user for a short intent (one line, e.g. "test 2.5D parallax on the nav screen"). Derive a slug from it for the `name` field.

## Step 7 — Write the manifest

Write `sandbox/.experiment.json`:

```json
{
  "name": "<slug>",
  "type": "<2D|2.5D|3D|custom>",
  "intent": "<user's one-liner>",
  "started": "<ISO timestamp>"
}
```

## Step 8 — Offer asset seeding

Use `ask_user_question` (allow multiple) with options:

- **Tiles** — copy `godot/assets/tiles/` into sandbox
- **Characters** — copy `godot/assets/characters/`
- **Audio** — copy `godot/assets/audio/`
- **Skip** — start with empty asset dirs

## Step 9 — Run the seeds

For each chosen option, run `python3 tools/sandbox/seed.py --from assets/<dir>`.

## Step 10 — Confirm

Print a one-paragraph confirmation: experiment name, type, intent, what was seeded, plus the reminder that `/promote-experiment` is the next workflow to run once the experiment has ideas worth keeping.

## Notes

- Step 2 is safe-read and uses `// turbo`.
- Steps 4, 7, and 9 are state-changing — let the user approve each.
- The workflow NEVER touches `godot/`.
