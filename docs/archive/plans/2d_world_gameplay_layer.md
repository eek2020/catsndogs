# Plan: Add 2D World Gameplay Layer to Whisper Crystals — COMPLETE (2026-03-25)

## Context

The project has a rich backend (18 game systems, 22 UI screens, EventBus with 90+ signals, full data-driven JSON content) but is entirely UI-screen based. There is no actual 2D world — no TileMap, no player CharacterBody2D, no NPC scenes, no interiors. The user's 5-layer roadmap describes how to add this world layer on top of the existing systems.

---

## Phase 1: Tileset Atlas Generator (Pillow script)

**Goal:** Create a Python tool that generates a 32×32px tile atlas PNG ready for Godot's TileMap editor.

- **Create** `tools/godot-dev/tiles/tileset_generator.py`
  - Pillow-based script (same pattern as existing `spritesheet_template.py`)
  - Generates a grid atlas PNG with tile variants: ground (grass, dirt, stone), walls, water, decor (hedges, trees), roof tiles
  - 32×32px per tile, output as single atlas PNG
  - Color-coded placeholder tiles with labels (like the sprite template does with numbered circles)
  - Support terrain-compatible layout (3×3 minimal autotile arrangement per terrain type)
- **Create** `tools/godot-dev/tiles/requirements.txt` — Pillow dependency
- **Output** goes to `godot/assets/tiles/` directory

---

## Phase 2: TileSet & TileMap Setup in Godot

**Goal:** Import the atlas into Godot as a TileSet resource and create a TileMap-based world scene.

- **Create** `godot/assets/tiles/` directory for atlas PNGs
- **Create** `godot/resources/world_tileset.tres` — TileSet resource
  - Tile size 32×32
  - Physics layers for collision (walls, obstacles)
  - Terrain sets for autotiling (ground, walls, water)
- **Create** `godot/scenes/world/world.tscn` — Main world scene
  - Node2D (World) root
  - TileMapLayer nodes: Ground (z=0), Decor (z=1), Roof (z=2) — Note: Godot 4.6 uses TileMapLayer nodes, not a single TileMap with layers
  - Each layer gets independent Z-index and collision
  - YSort enabled on the parent node for depth ordering

---

## Phase 3: Player Controller & Sprite Import

**Goal:** Wire up Aristotle/Dave as playable CharacterBody2D with animated sprites.

- **Create** `godot/scenes/world/player.tscn`
  - CharacterBody2D root
  - CollisionShape2D (capsule or rectangle)
  - AnimatedSprite2D with SpriteFrames resource
  - Camera2D (follows player, smoothing enabled)
- **Create** `godot/scripts/world/player_controller.gd`
  - 8-direction input using existing input map (move_up/down/left/right already defined in project.godot)
  - `move_and_slide()` for physics-based movement
  - Animation state: idle_down, idle_up, idle_left, idle_right, walk_down, walk_up, walk_left, walk_right
  - Emit EventBus signals for interact action
- **Import** existing sprite sheets from `godot/assets/sprites/` (Aristotle, Dave) into SpriteFrames
  - Set hframes/vframes matching sheet layout
  - Create named animations matching movement directions

---

## Phase 4: NPC System

**Goal:** Create NPC scenes with state machines, pathfinding, and dialogue triggers.

- **Create** `godot/scenes/world/npc.tscn` — Reusable NPC scene
  - CharacterBody2D root
  - CollisionShape2D
  - AnimatedSprite2D
  - NavigationAgent2D (pathfinding)
  - Area2D with CollisionShape2D (interaction detection zone)
- **Create** `godot/scripts/world/npc_controller.gd`
  - Enum states: IDLE, PATROL, TALK
  - State machine logic in `_physics_process()`
  - NavigationAgent2D for patrol pathfinding
  - On Area2D body_entered + interact input → emit dialogue signal via EventBus
  - Read faction reputation from GameSession to choose dialogue branch
- **Create** `godot/scripts/world/dialogue_manager.gd` (or integrate with existing dialogue_ui.gd)
  - Reads dialogue JSON from `godot/data/dialogue/`
  - Shows CanvasLayer dialogue box
  - Connects to EventBus for dialogue events

---

## Phase 5: Scene Transitions & Interiors

**Goal:** Add door transitions between world and interior scenes.

- **Create** `godot/scripts/world/scene_transition.gd`
  - Area2D-based door detection (body_entered signal)
  - Fade-out via CanvasLayer → `get_tree().change_scene_to_file()` → fade-in
  - Store return position in GameSession
- **Create** `godot/scenes/world/tavern.tscn` — Example interior
  - Own TileMapLayer nodes for interior layout
  - NavigationRegion2D bakes navmesh from collision shapes
  - Innkeeper NPC instance, patron NPCs
  - Interactable objects (bar counter) via Area2D
- **Create** `godot/scenes/ui/shop_screen.tscn` (or enhance existing trade_screen)
  - GridContainer for item display
  - Merchant NPC triggers show() on shop CanvasLayer
  - Prices affected by faction reputation from GameSession

---

## Phase 6: Overworld Map Enhancement

**Goal:** Connect world locations via an overworld/star map screen.

- **Enhance** existing `godot/scenes/ui/star_map_screen.tscn` and `godot/scripts/ui/star_map_screen.gd`
  - Add clickable TextureButton markers per location
  - Fog-of-war overlay (read discovered regions from GameSession/ExplorationSystem)
  - Travel confirmation UI
  - On travel confirm → transition to appropriate World.tscn or interior scene

---

## Files to Create

| File | Purpose |
|------|---------|
| `tools/godot-dev/tiles/tileset_generator.py` | Pillow atlas generator |
| `tools/godot-dev/tiles/requirements.txt` | Dependencies |
| `godot/scenes/world/world.tscn` | Main world scene |
| `godot/scenes/world/player.tscn` | Player character scene |
| `godot/scenes/world/npc.tscn` | Reusable NPC scene |
| `godot/scenes/world/tavern.tscn` | Example interior |
| `godot/scripts/world/player_controller.gd` | Player movement & animation |
| `godot/scripts/world/npc_controller.gd` | NPC state machine |
| `godot/scripts/world/scene_transition.gd` | Door/area transitions |
| `godot/scripts/world/dialogue_manager.gd` | World dialogue trigger system |

## Files to Modify

| File | Change |
|------|--------|
| `godot/scripts/ui/star_map_screen.gd` | Add location markers, fog-of-war, travel flow |
| `godot/scripts/autoload/game_session.gd` | Add return_position tracking for scene transitions |
| `docs/changelog/CHANGELOG.md` | Document all additions |

## Verification

1. Run `tileset_generator.py` → verify atlas PNG output in `godot/assets/tiles/`
2. Open World.tscn in Godot editor → paint tiles on TileMapLayers using the atlas
3. Run World.tscn → move player with arrow keys, verify collision with walls
4. Place NPC → walk into detection zone, press interact, verify dialogue appears
5. Walk into door Area2D → verify scene transitions to Tavern.tscn and back
6. Open star map → click location → verify travel flow loads correct world scene
