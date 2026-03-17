# Architecture Planning Guide

How to design Godot project architecture. Adapted from the godogen scaffolding methodology.

## Scaffold Design Workflow

1. **Assess project state** — new project or incremental change?
2. **Design architecture** — scenes, scripts, signals, input actions
3. **Write `project.godot`** — engine config, input mappings, autoloads
4. **Write `STRUCTURE.md`** — complete architecture reference
5. **Write script stubs** — correct `extends`, signal declarations, empty lifecycle methods
6. **Build scenes** — leaf scenes first, then parents (dependency order)
7. **Verify** — `timeout 60 godot --headless --quit 2>&1` — no errors

## Scene Hierarchy Design

### Principles

1. **Explicit 2D or 3D** — never mix dimensions in the same hierarchy
2. **Composition over inheritance** — use node composition, not deep class hierarchies
3. **Predictable naming** — every node gets a meaningful `.name` for `@onready` references
4. **Single responsibility** — each script handles one aspect of behavior

### Common Scene Structures

**Game Scene (2D):**
```
Main (Node2D)
├── Player (CharacterBody2D)
│   ├── Sprite2D
│   ├── CollisionShape2D
│   └── Camera2D
├── Enemies (Node2D)
│   └── ... spawned enemies
├── Environment (Node2D)
│   └── ... level geometry
└── CanvasLayer (layer=1)
    └── HUD (Control)
        ├── ScoreLabel
        ├── HealthBar
        └── MiniMap
```

**UI Overlay:**
```
CanvasLayer (layer=1)
└── Control (anchors_preset=15, full rect)
    ├── VBoxContainer or HBoxContainer
    │   ├── Label (score)
    │   ├── ProgressBar (health)
    │   └── Button (pause)
    └── ...
```

For pause menus, set `process_mode = Node.PROCESS_MODE_ALWAYS` on the CanvasLayer.

### Layout Containers
- `VBoxContainer` — vertical stack
- `HBoxContainer` — horizontal stack
- `GridContainer` — grid (set `columns` property)
- `MarginContainer` — padding
- `CenterContainer` — centering
- `PanelContainer` — with background
- `size_flags_horizontal/vertical = 3` (SIZE_EXPAND_FILL)
- `custom_minimum_size` for fixed dimensions

## Script Responsibility Patterns

Each script should have a clear responsibility:

| Script Type | Responsibility | Example |
|-------------|---------------|---------|
| Controller | Input handling + movement | `player_controller.gd` |
| Manager | System coordination | `game_manager.gd` |
| Spawner | Entity creation + lifecycle | `enemy_spawner.gd` |
| UI Controller | Display updates + user interaction | `hud_controller.gd` |
| Data Model | State + serialization | `player_data.gd` |

## Signal Flow Design

1. **Declare all input actions** in `project.godot` — anything used by scripts must appear there
2. **Signal contracts** — if script A emits signal X, receivers must be documented
3. **Use EventBus** for cross-system communication (Whisper Crystals autoload)
4. **Connect signals in `_ready()`**, not in scene builders

### Signal Map Format

Document signal flow in STRUCTURE.md:
```
Player:HurtBox.area_entered -> PlayerController._on_hurt_entered
Main:GoalArea.body_entered -> LevelManager._on_goal_reached
```

## Common Built-in Signals

- Area2D/3D — `body_entered`, `body_exited`, `area_entered`, `area_exited`
- Button — `pressed`
- Timer — `timeout`
- AnimationPlayer — `animation_finished`
- RigidBody2D/3D — `body_entered` (requires `contact_monitor = true`)

## STRUCTURE.md Template

```markdown
# {Project Name}

## Dimension: {2D or 3D}

## Input Actions

| Action | Keys |
|--------|------|
| move_right | D, Right |
| jump | Space |

## Scenes

### Main
- **File:** res://scenes/main.tscn
- **Root type:** Node2D
- **Children:** Player, Enemies, Environment, CanvasLayer

## Scripts

### PlayerController
- **File:** res://scripts/player_controller.gd
- **Extends:** CharacterBody2D
- **Attaches to:** Player
- **Signals emitted:** died, scored
- **Signals received:** HurtBox.area_entered -> _on_hurt_entered

## Signal Map

- Player:HurtBox.area_entered -> PlayerController._on_hurt_entered

## Asset Hints

- Player sprite (64x48 per frame, 4-frame walk cycle)
- Background tileset (32x32 tiles)
```
