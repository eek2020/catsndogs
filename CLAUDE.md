# Whisper Crystals — AI Agent Instructions

This file contains project conventions and rules for any AI agent working on this codebase.

## Project Overview

Whisper Crystals is a narrative-driven 2D side-scrolling space pirate game built in Godot 4.6 with GDScript. The player commands Aristotle (cat) or Dave (dog), captains caught in a multiverse-wide struggle over the only source of starship fuel.

## Tech Stack

- **Engine:** Godot 4.6 (GL Compatibility renderer)
- **Language:** GDScript
- **Resolution:** 1280×720, canvas_items stretch mode
- **Target:** Desktop (Mac M3/M4 primary, Windows compatible)

## Architecture Rules

### Autoload Singletons

Four global singletons are registered in `project.godot`:

- `EventBus` — `scripts/autoload/event_bus.gd` — Pub/sub signal hub for decoupled communication
- `GameSession` — `scripts/autoload/game_session.gd` — Persistent game state across scenes
- `MusicManager` — `scripts/autoload/music_manager.gd` — Background music control
- `ProceduralMapManager` — `scripts/autoload/procedural_map_manager.gd` — Procedural navigation/star map backdrops

### Data-Driven Content

All story, dialogue, encounters, factions, and ship data live in JSON files under `godot/data/`. Never hardcode narrative or game content in GDScript source.

### Event Bus

Use `EventBus` (autoload singleton) for decoupled communication between systems. Systems should emit signals rather than directly calling each other.

### Scene-Based UI

UI screens are individual `.tscn` scenes in `godot/scenes/ui/`. Each screen has a corresponding controller script in `godot/scripts/ui/`.

## File Layout

```text
godot/
  project.godot       # Godot project config (autoloads, input map, display settings)
  scenes/
    main.tscn          # Main scene (entry point)
    ui/                # UI scene files (.tscn)
  scripts/
    autoload/          # Singletons (EventBus, GameSession, MusicManager)
    core/              # Core game logic
    entities/          # Data models
    systems/           # Game systems (combat, narrative, faction, economy, crew)
    ui/                # UI controller scripts
  data/                # JSON content files
    encounters/        # Arc 1–4 encounter definitions
    dialogue/          # Dialogue trees
    factions/          # Faction registry
    ships/             # Ship templates
    economy/           # Crystal deposits, supply routes, regions
    story/             # Arc definitions and story flags
    side_missions/     # Side mission data
  assets/              # Game assets (sprites, audio)
  shaders/             # Custom shaders
docs/                  # MASTER_PLAN, code reviews, issues, changelog, archive
design/                # Art direction, characters, artwork
story/                 # Narrative reference (arcs, characters, factions)
```

## Coding Conventions

- Use static typing in GDScript where possible
- Docstring comments on all classes and public methods
- Use signals and the EventBus for inter-system communication
- Prefer composition over inheritance via scene tree nodes
- Small scripts doing one thing each
- Standard GDScript style (snake_case functions/variables, PascalCase classes)

## Task Workflow

1. Read all files you will modify before making changes
2. Implement the changes
3. Test in the Godot editor — run the scene and verify behavior
4. Run the GUT test suite (see below) before declaring work done
5. Add an entry to `docs/changelog/CHANGELOG.md`

## Testing

GUT 9.6.0 is vendored at `godot/addons/gut/`. Unit tests live at `godot/tests/unit/` (prefix `test_`, suffix `.gd`).

Headless run (from `godot/`):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Note: `godot` is not on `$PATH` on the primary Mac dev setup — invoke the binary inside the `.app` bundle directly.

Every new bug fix or system should land with a regression test that would have failed before the fix.

## Key Files

- `godot/project.godot` — Project config, autoloads, input mappings
- `godot/scenes/main.tscn` — Main entry scene
- `godot/scripts/autoload/event_bus.gd` — Pub/sub signal hub
- `godot/scripts/autoload/game_session.gd` — Persistent game state
- `godot/data/encounters/arc1_encounters.json` — Reference schema for encounter data
- `godot/data/factions/faction_registry.json` — Faction definitions and relationships
