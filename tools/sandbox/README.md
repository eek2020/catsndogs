# Sandbox Tooling

CLI that powers the `/new-experiment` and `/promote-experiment` Windsurf workflows. Each subcommand is also usable standalone for manual debugging.

## Layout

- `promote.py` — main CLI (scan / map / deps / stage / revert / test-open / test-gut / changelog / codemap)
- `reset.py` — wipe `sandbox/` contents (keeps `project.godot` and `README.md`)
- `seed.py` — copy selected subtrees from `godot/` into `sandbox/` as starting assets

All scripts are pure stdlib Python 3 — no dependencies.

## Paths assumed

- Repo root: two levels above this file
- Sandbox project: `sandbox/`
- Main project: `godot/`
- Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot`
- Log file: `logs/sandbox-promote.log`

## One-experiment-at-a-time convention

`sandbox/` holds a single active experiment. `sandbox/.experiment.json` records what the experiment is about. To start a new one, run `/new-experiment` (which calls `reset.py --force` under the hood).

## Manual usage examples

```bash
# What's changed in sandbox/ vs godot/?
python3 tools/sandbox/promote.py scan

# Where would sandbox/scripts/foo.gd land?
python3 tools/sandbox/promote.py map sandbox/scripts/foo.gd

# What res:// refs do these files touch?
python3 tools/sandbox/promote.py deps sandbox/scripts/foo.gd sandbox/scenes/bar.tscn

# Stage a promotion (pairs.json = [{source, target}, ...])
python3 tools/sandbox/promote.py stage --pairs pairs.json --manifest logs/revert.json

# Gates
python3 tools/sandbox/promote.py test-open
python3 tools/sandbox/promote.py test-gut

# Rollback if a gate fails
python3 tools/sandbox/promote.py revert --manifest logs/revert.json

# Wrap-up
python3 tools/sandbox/promote.py changelog --summary "your summary" --files-from pairs.json
python3 tools/sandbox/promote.py codemap
```

## What `stage` does not do

- No `git commit`.
- No `git push`.
- No auto-promotion of files not listed in `pairs.json`.

Every stage produces a revert manifest in `logs/` so you can undo cleanly.

## `pairs.json` format

```json
[
  { "source": "scripts/ui/foo.gd", "target": "scripts/ui/foo.gd" },
  { "source": "scenes/world/bar.tscn", "target": "scenes/world/bar.tscn" }
]
```

`source` is relative to `sandbox/`, `target` is relative to `godot/`. The trivial default is `source == target`; use rename when you want to relocate during promotion.
