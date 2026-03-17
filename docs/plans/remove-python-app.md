# Remove Legacy Python App Code

Remove all Python/Pygame application code, tests, launchers, and duplicated data/assets now that the project has fully migrated to Godot.

## Files & Directories to Delete

| Item | Reason |
|------|--------|
| `src/` | Entire Python game source (core, engine, entities, systems, ui) |
| `tests/` | Python pytest suite (18 test files) — not usable with Godot |
| `data/` | Root-level JSON data — duplicated in `godot/data/` |
| `assets/` | Root-level assets — duplicated in `godot/assets/` |
| `run.py` | Python launcher script |
| `run.sh` | Shell launcher for Python app |
| `run.bat` | Windows launcher for Python app |
| `pyproject.toml` | Python build/test/lint config (pygame-ce, pytest, ruff) |
| `requirements.txt` | Python pip dependencies |
| `project_structure.json` | Describes old Python file layout |
| `.pytest_cache/` | Pytest cache directory |
| `logs/` | Empty log directory from Python app |

## Files to Update

- **`README.md`** — Rewrite to reference Godot project structure, remove Python quick-start, update tech stack
- **`CLAUDE.md`** — Rewrite to reflect Godot architecture, remove Python/Pygame conventions
- **`.gitignore`** — Remove Python-specific entries (`__pycache__`, `*.py[cod]`, `.pytest_cache`, `.coverage`, `htmlcov/`); keep Godot and general entries

## Execution Order

1. Delete all files and directories listed above
2. Update `.gitignore`
3. Update `README.md`
4. Update `CLAUDE.md`

## Not Touched

- `godot/` — Active Godot project (untouched)
- `docs/` — Documentation, issues, changelog (kept as-is)
- `design/` — Art direction, characters, artwork
- `story/` — Narrative arcs, character profiles, factions
