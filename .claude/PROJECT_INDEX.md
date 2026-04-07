# Whisper Crystals - Project Index

**Last Updated:** 2026-04-07  
**Purpose:** Comprehensive index for AI agents to understand project structure and locate relevant files quickly.

## Project Overview

**Project Name:** Whisper Crystals  
**Type:** Narrative-driven 2D space pirate game  
**Engine:** Godot 4.6 (GL Compatibility)  
**Language:** GDScript  
**Status:** Fully playable core game (Arcs 1-4), expansion content in development  

## Directory Structure & Purpose

### Core Game Engine

- **`godot/`** - Main Godot project directory
  - `project.godot` - Project configuration
  - `scenes/` - All .tscn scene files
  - `scripts/` - GDScript source code
  - `data/` - JSON data files (game content)
  - `assets/` - Art, audio, and game assets
  - `addons/` - Godot addons and extensions

### Documentation & Planning

- **`docs/`** - Project documentation
  - `MASTER_PLAN.md` - Current project status and roadmap
  - `GAME_SUMMARY.md` - Complete game design summary
  - `architecture/` - Technical specifications and ADRs
  - `changelog/` - Development history
  - `development-methodology/` - Development guides

### Creative Content

- **`story/`** - Narrative materials
  - `arcs/` - Story arc overviews
  - `characters/` - Character profiles
  - `factions/` - Faction lore
- **`design/`** - Art direction and visual assets
  - `artwork/` - Game art and concepts
  - `characters/` - Character concept art
  - `art_direction/` - Visual style guides

### Development Tools

- **`tools/`** - Development utilities
  - `godot-dev/` - Godot-specific development tools
  - `pipeline/` - Asset pipeline tools
  - `utils/` - General utility scripts
    - `ascii.py`, `ascii2.py`, `ascii3.py` - ASCII art tools
    - `bbox.py`, `bounding_box.py` - Bounding box utilities
    - `check_img.py` - Image validation
    - `colors.py` - Color utilities
    - `empty_lines.py` - Text processing
    - `find_chars.py` - Character finding
    - `match.py` - Pattern matching
    - `measure.py` - Measurement tools
  - `import_assets.sh` - Asset import script
  - `rollback_import.sh` - Asset rollback script

### Legacy & Archive

- **`other_data/`** - Legacy data from previous iterations
- **`backup_assets/`** - Archived asset files
- **`examples/`** - Code examples and patterns

## Key Files for AI Agents

### Primary Reference Documents

1. **`README.md`** - Project overview and quick start
2. **`STRUCTURE.md`** - Detailed architecture reference
3. **`docs/MASTER_PLAN.md`** - Current development status
4. **`docs/GAME_SUMMARY.md`** - Complete game design
5. **`MEMORY.md`** - Project context and decisions

### Core Game Files

- **`godot/project.godot`** - Project configuration
- **`godot/scenes/main.tscn`** - Main entry point
- **`godot/scripts/autoload/`** - Global singletons
- **`godot/data/`** - All game content data

### Development Guidelines

- **`docs/GODOT_DEV_GUIDE.md`** - Godot development practices
- **`docs/development-methodology/`** - Development patterns

## File Naming Conventions

### GDScript Files

- Use snake_case: `game_state_data.gd`
- Controllers: `*_controller.gd` or `*_ui.gd`
- Systems: `*_system.gd`
- Entities: singular: `ship.gd`, `faction.gd`

### Scene Files

- Use snake_case: `character_select.tscn`
- UI scenes: `ui/` subdirectory
- World scenes: `world/` subdirectory

### Data Files

- JSON format in `godot/data/`
- Descriptive names: `faction_registry.json`
- Grouped by type: `characters/`, `encounters/`, etc.

## Common Tasks & File Locations

### Adding New Game Content

1. **Characters:** `godot/data/characters/`
2. **Dialogue:** `godot/data/dialogue/`
3. **Encounters:** `godot/data/encounters/`
4. **Factions:** `godot/data/factions/`
5. **Ships:** `godot/data/ships/`

### Adding New UI Screens

1. Scene: `godot/scenes/ui/`
2. Script: `godot/scripts/ui/`
3. Register in `STRUCTURE.md`

### Adding New Systems

1. Script: `godot/scripts/systems/`
2. Instantiate in `GameSession`
3. Document in `STRUCTURE.md`

### Asset Management

1. Import to `godot/assets/` appropriate subdirectory
2. Update `ASSETS.md`
3. Use `tools/import_assets.sh` for batch imports

## Development Workflow

### Before Making Changes

1. Check `docs/MASTER_PLAN.md` for current priorities
2. Consult `STRUCTURE.md` for architecture guidance
3. Review relevant `MEMORY.md` entries

### After Making Changes

1. Update this index if adding/moving files
2. Update relevant documentation
3. Test in Godot engine

## AI Agent Guidelines

### First Steps When Starting a Task

1. Read this index for context
2. Check `MEMORY.md` for project history
3. Consult `docs/MASTER_PLAN.md` for current status
4. Use `STRUCTURE.md` for technical details

### Keeping This Index Updated

- Update when adding new directories
- Update when moving files
- Update when changing project structure
- Mark changes with date and brief description

### Communication Patterns

- Reference files using backticks: `godot/scripts/autoload/event_bus.gd`
- Use absolute paths for clarity
- Include line numbers for specific code references

---

**Maintenance Note:** This index should be the first file consulted for any project-related task. Keep it accurate and up-to-date.
