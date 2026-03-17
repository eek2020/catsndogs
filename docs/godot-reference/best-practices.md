# Godot Development Best Practices

Coding standards, patterns, and conventions for Godot 4.6 GDScript development. Derived from godogen methodology and Whisper Crystals project conventions.

## Code Style

- **Static typing** — use type annotations on all public signatures and return types
- **snake_case** for functions, variables, signals; **PascalCase** for classes and node names
- **Docstring comments** (`##`) on all classes and public methods
- **Private prefix** — use `_` prefix for internal variables and methods
- **Signals over direct calls** — use signals and EventBus for inter-system communication
- **Composition over inheritance** — prefer node composition via scene tree over deep class hierarchies
- **Small scripts** — each script does one thing; split complex behavior into multiple node scripts

## Critical Type Safety Rules

**NEVER use `:=` with polymorphic math functions** — `abs`, `sign`, `clamp`, `min`, `max`, `floor`, `ceil`, `round`, `lerp`, `smoothstep`, `move_toward`, `wrap`, `snappedf`, `randf_range`, `randi_range` return Variant (work on multiple types). Always use explicit types:

```gdscript
# WRONG
var x := abs(y)
var clamped := clamp(val, 0.0, 1.0)

# CORRECT
var x: float = abs(y)
var clamped: float = clamp(val, 0.0, 1.0)
```

**NEVER use `:=` with `instantiate()`** — returns Variant:

```gdscript
# WRONG
var model := scene.instantiate()

# CORRECT
var model = scene.instantiate()
```

**NEVER use `:=` with array/dictionary access** — returns Variant:

```gdscript
# WRONG
var pos := positions[i]

# CORRECT
var pos: Vector3 = positions[i]
```

## Script Organization

Follow this section ordering within scripts:

1. `extends` and `class_name`
2. Signals
3. `@onready` node references
4. `@export` properties
5. Private state variables
6. Lifecycle methods (`_ready`, `_process`, `_physics_process`)
7. Public methods
8. Private methods
9. Signal handlers (prefixed with `_on_`)

## Scene Builder vs Runtime Script

These are two fundamentally different kinds of GDScript:

| | Scene Builder | Runtime Script |
|---|---|---|
| Purpose | Produces `.tscn` files | Runs during gameplay |
| Extends | `SceneTree` | Node type (e.g., `CharacterBody2D`) |
| Entry point | `_initialize()` | `_ready()` |
| Ends with | `quit()` | Never |
| Can use `@onready` | No | Yes |
| Can use `preload()` | No (use `load()`) | Yes |
| Signal connections | No (do in runtime scripts) | Yes, in `_ready()` |

## Data-Driven Design

- All narrative content, dialogue, encounters, factions, and ship data live in JSON files under `data/`
- Never hardcode game content in GDScript source
- Use DataLoader for JSON access with caching
- Entity classes implement `to_dict()` / `from_dict()` for serialization

## Signal Best Practices

- Define signals with typed parameters: `signal health_changed(new_value: int)`
- Connect signals in `_ready()`, not in scene builders
- Use EventBus autoload for cross-system communication
- Prefer signals over direct method calls between unrelated systems

## Node Reference Best Practices

- Use `@onready` for child node references, resolved when `_ready()` runs
- Use `%UniqueNode` for scene-unique nodes (set in editor)
- Never call `get_node()` in `_process()` — cache references in `@onready` vars
- Use `get_node_or_null()` for optional nodes, check in `_ready()`

## Performance Guidelines

- Use `PhysicsServer2D` directly for 500+ physics objects (bullets, particles)
- Prefer `move_and_slide()` for character controllers over manual physics
- Use `queue_redraw()` + `_draw()` for custom rendering of many objects
- Cache frequently accessed values — don't call `get_tree()` every frame
- Use `set_deferred()` for collision state changes inside physics callbacks

## Common Anti-Patterns to Avoid

1. **Mixing 2D and 3D nodes** in the same scene hierarchy
2. **Connecting signals in scene builders** — scripts aren't instantiated at build-time
3. **Using `preload()` in scene builders** — fails in headless mode
4. **Forgetting `quit()` in scene builders** — Godot runs forever in headless mode
5. **Missing `set_owner()` on descendants** — nodes won't serialize to `.tscn`
6. **Recursing into GLB children for ownership** — causes 100MB+ scene files
7. **Using `look_at()` in `_initialize()`** — nodes aren't in tree yet, spatial methods fail
