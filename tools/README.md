# tools/

Developer tooling that lives outside the Godot project. Not shipped with the game.

## Subdirectories

- **`sandbox/`** — CLI for the `/sandbox` skill (`.claude/skills/sandbox/`). Seeds, resets, and promotes sandbox experiments into `godot/`. See `sandbox/README.md`.
- **`blender-dev/`** — Blender Python scripts for the 3D character pipeline: Mixamo retargeting, GLB inspection, preview rendering, game-ready decimation. Gitignored (local-only).
- **`godot-dev/`** — Godot-side dev helpers (asset capture, sprite/tile utilities). Local-only.
- **`utils/`** — One-off Python image/text utilities (bounding-box math, ASCII conversion, colour sampling). Not wired into any pipeline; kept for reference.
- **`Universal Animation Library[Standard].zip`** — Local-only Mixamo-compatible animation pack used by the Blender pipeline. Gitignored.
