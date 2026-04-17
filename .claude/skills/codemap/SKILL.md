---
name: codemap
description: Generate or refresh docs/architecture/CODEMAP.md — the code-anchored index of autoloads, EventBus signals, systems, ViewModels, UI screens, scenes, and data files. Run at the start of a session for orientation, or whenever structure changes (new system, new signal, new UI screen, renamed file). Cheap and deterministic: reruns on unchanged code produce no diff.
---

# Codemap skill

## When to run

- First action on a fresh session, before touching an unfamiliar area — gives a fast map of where things live.
- After adding/renaming/moving a system, autoload, signal, ViewModel, UI screen, or data category.
- Before opening a PR that restructures code — confirms the map still matches reality.
- When the user asks "where is X?", "how is X wired?", "what signals does Y emit?" — read `docs/architecture/CODEMAP.md` first; regenerate only if it looks stale relative to what you see in the tree.

## How to run

```bash
bash .claude/skills/codemap/generate.sh
```

Output: `docs/architecture/CODEMAP.md`. The script is idempotent — if nothing meaningful changed it prints `codemap: no changes` and leaves the file alone. Otherwise it rewrites the file and prints `codemap: wrote …`.

## What the map contains

- **Autoloads** — parsed from `[autoload]` in `godot/project.godot`.
- **EventBus signals** — extracted from `godot/scripts/autoload/event_bus.gd`, grouped by the `# --- Foo events ---` section headers, each with a line-number anchor.
- **Core / Entities / Systems / Cutscene / World** — one section per `scripts/*/` subtree.
- **ViewModels → Screens → Scenes** — table pairing each `scripts/ui/view_models/*.gd` with its controller script and `.tscn`.
- **UI screens** — top-level `scripts/ui/*.gd` plus subfolders (`combat/`, `star_map/`).
- **Scenes** — entry point, UI, world, cutscenes.
- **Data files** — one section per `data/<category>/` subfolder.
- **Inventory** — counts (autoloads, signals, systems, UI, VMs, scenes, JSON).

## Update rules

- **Never hand-edit `CODEMAP.md`.** The top of the file says so; any manual edits will be clobbered on next regen.
- To change *what* the map contains (new section, different grouping), edit `generate.sh` — then regenerate and commit both the script and the resulting map in the same change.
- If the map is wrong but the script is right, the code has drifted — fix the code, not the map.

## Relationship to other docs

- [`CLAUDE.md`](../../../CLAUDE.md) — architecture rules (what *should* be true). Stable, hand-written.
- [`.claude/PROJECT_INDEX.md`](../../PROJECT_INDEX.md) — narrative project overview (directories, conventions, workflow). Stable, hand-written.
- `docs/architecture/CODEMAP.md` — the code as it actually is right now. Generated; always trust the code over this file if they disagree.
