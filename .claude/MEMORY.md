# Global AI Agent Memory - Whisper Crystals Project

**Created:** 2026-04-07  
**Purpose:** Persistent memory for AI agents working on the Whisper Crystals project. This file should be read before starting any task and updated with new discoveries.

## Project Context

### Core Identity

- **Project:** Whisper Crystals - A narrative-driven 2D space pirate game
- **Inspiration:** Spelljammer D&D setting
- **Protagonist:** Aristotle (cat pirate captain) or Dave (dog pirate captain)
- **Unique Mechanic:** Control of Whisper Crystals - the multiverse's only starship fuel source

### Technical Foundation

- **Engine:** Godot 4.6 (GL Compatibility renderer)
- **Language:** GDScript with static typing preferred
- **Resolution:** 1280×720, canvas_items stretch mode
- **Architecture:** Event-driven with autoload singletons
- **Data Format:** JSON-driven content for all game assets

### Development Status

- **Core Game:** Fully playable (Arcs 1-4 complete)
- **Endings:** 3 distinct endings based on player choices
- **Expansion:** Arcs 5-10 have data but need integration
- **Known Issues:** 18 issues from April 2026 code review, 2 critical

## Architecture Patterns

### Global Singletons (Autoloads)

1. **EventBus** - Central pub/sub signal hub (120+ signals)
2. **GameSession** - Master orchestrator, owns all systems
3. **MusicManager** - Dynamic audio management
4. **ProceduralMapManager** - World map rendering

### System Organization

- **Core Systems:** StateMachine, DataLoader, SaveManager, Config
- **Game Systems:** Combat, Narrative, Faction, Economy, etc.
- **All systems** are RefCounted objects owned by GameSession
- **Communication** via EventBus signals, never direct references

### Data Architecture

- **JSON-driven:** All content in `godot/data/` subdirectories
- **Serializable:** All entities implement `to_dict()`/`from_dict()`
- **Runtime Loading:** DataLoader caches all JSON on game start

## Critical Godot 4.6 Patterns

### Type Inference Issues

```gdscript
# DON'T - fails with polymorphic math functions
var result := abs(value)

# DO - explicit type annotation
var result: float = abs(value)

# DON'T - instantiate() with :=
var node := scene.instantiate()

# DO - use = for instantiate()
var node = scene.instantiate()
```

### Scene Management

- **UI Scenes:** Use CanvasLayer for viewport-coordinate rendering
- **World Scenes:** Node2D hierarchy for world-coordinate rendering
- **Overlays:** Push/pop system for modal screens
- **Camera2D:** Use `make_current()`, not `current` property

### Input System

- **Simulation:** Use `InputEventAction` objects, not `Input.action_press()`
- **Key Codes:** Tab is 4194306, M is 77
- **Actions:** Defined in project settings, referenced by string names

## File Organization Standards

### Naming Conventions

- **Files:** snake_case (`game_state_data.gd`)
- **Classes:** PascalCase (`GameStateData`)
- **Functions/Variables:** snake_case (`calculate_damage()`)
- **Constants:** UPPER_SNAKE_CASE (`MAX_CREW_SIZE`)

### Directory Structure

```
godot/
├── scenes/           # .tscn files
│   ├── ui/          # UI screens
│   └── world/       # World scenes
├── scripts/         # .gd files
│   ├── autoload/    # Global singletons
│   ├── core/        # Core systems
│   ├── systems/     # Game systems
│   └── ui/          # UI controllers
├── data/            # JSON content
│   ├── characters/  # Character definitions
│   ├── encounters/  # Story encounters
│   └── ...          # Other content types
└── assets/          # Art, audio, etc.
```

## Common Tasks & Patterns

### Adding New Game Content

1. Create JSON file in appropriate `godot/data/` subdirectory
2. Add to `DataLoader` loading logic
3. Update relevant system to handle new data
4. Test with game session

### Adding New UI Screens

1. Create scene in `godot/scenes/ui/`
2. Create controller script in `godot/scripts/ui/`
3. Add to state machine in GameSession
4. Update `STRUCTURE.md`

### Adding New Systems

1. Create script in `godot/scripts/systems/`
2. Instantiate in GameSession `_ready()`
3. Wire up EventBus signals
4. Document in `STRUCTURE.md`

## Known Technical Solutions

### CanvasLayer for UI Overlays

- Wrap UI scenes in CanvasLayer for viewport coordinates
- Set layer 10+ for game overlays
- Use `process_mode = PROCESS_MODE_ALWAYS` for pause menus

### Performance Optimizations

- **Fog of War:** Render in 4x4 chunks instead of individual cells
- **Starfield:** Pre-generate with deterministic seed
- **Parallax:** Set motion_mirroring to 2x viewport size

### Save System

- **3-slot save system** with atomic writes
- **Version migration** support in SaveManager
- **Complete state** serialization via GameStateData

## Development Workflow

### Before Starting Work

1. Read `PROJECT_INDEX.md` for file locations
2. Check `docs/MASTER_PLAN.md` for current priorities
3. Consult this MEMORY for technical patterns
4. Review `STRUCTURE.md` for architecture details

### After Completing Work

1. Update this MEMORY with new discoveries
2. Update relevant documentation files
3. Test changes in Godot engine
4. Update PROJECT_INDEX if structure changed

## Project-Specific Knowledge

### Narrative Structure

- **Dual Protagonists:** Aristotle (cat) and Dave (dog)
- **Story Arcs:** 10 planned arcs, 4 complete
- **Choice System:** Tracks choices for ending determination
- **Crew System:** 8 recruitable crew members with traits

### Game Systems

- **Combat:** Tactical with ship upgrades and crew bonuses
- **Economy:** Crystal extraction, trading, shipyard
- **Factions:** 8 factions with diplomacy and conquest
- **Exploration:** Region discovery, POI scanning, hazards

### Content Organization

- **Characters:** `godot/data/characters/`
- **Dialogue:** `godot/data/dialogue/`
- **Encounters:** `godot/data/encounters/`
- **Factions:** `godot/data/factions/`
- **Ships:** `godot/data/ships/`

## Debugging & Testing

### Common Issues

- **Type inference errors** with polymorphic functions
- **Camera offset** problems with UI overlays
- **Signal connection** failures in EventBus
- **JSON loading** errors in DataLoader

### Testing Patterns

- **Unit tests:** Use `godot/examples/` directory
- **Integration tests:** Full game session testing
- **Input simulation:** Use InputEventAction objects
- **Visual testing:** Use Godot's --write-movie feature

## Code Review History

### April 2026 Review

- **18 issues identified**, 2 critical
- **Focus areas:** Performance, UI responsiveness, save stability
- **Status:** Documented in `docs/CODE_REVIEW_2026-04-05.md`

---

**Maintenance:** This file should be updated after each significant development session. Add new discoveries, patterns, and solutions as they are found.
