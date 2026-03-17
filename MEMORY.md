# Project Memory — Whisper Crystals (Godot 4.6)

Read before starting work. Write back discoveries after completing tasks.

## Engine Configuration

- **Engine:** Godot 4.6, GL Compatibility renderer
- **Resolution:** 1280x720, canvas_items stretch mode
- **Language:** GDScript with static typing
- **Target:** Desktop (Mac M3/M4 primary, Windows compatible)

## Architecture

- Three autoload singletons: EventBus, GameSession, MusicManager
- Data-driven content: all story/dialogue/encounters/factions/ships in JSON under `godot/data/`
- Event bus pattern for decoupled inter-system communication
- Scene-based UI: `.tscn` in `godot/scenes/ui/`, controllers in `godot/scripts/ui/`

## Known Godot Quirks (from godogen)

- `:=` with polymorphic math functions (`abs`, `clamp`, `min`, `max`, `lerp`, etc.) causes "Cannot infer type from Variant" — always use explicit type annotation
- `:=` with `instantiate()` fails — use `=` (not `:=`)
- `:=` with array/dict access fails — use explicit type or untyped
- `load()` returns Resource, not PackedScene — must type explicitly: `var scene: PackedScene = load(...)`
- Camera2D has no `current` property — use `make_current()`
- Collision layer/mask are bitmasks (powers of 2), not UI layer numbers
- `set_deferred()` required for collision state changes inside physics callbacks
- `queue_free()` blocks name reuse until frame end — use `free()` for immediate replacement

## Project-Specific Patterns

- Stack-based state machine for game states
- All entities implement `to_dict()` / `from_dict()` for serialization
- snake_case functions/variables, PascalCase classes
- Docstrings on all classes and public methods

## Discoveries

<!-- Add new discoveries here as they are found during development -->
