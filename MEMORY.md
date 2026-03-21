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

### CanvasLayer for UI scenes

Control nodes added as children of Node2D (GameManager) render in world coordinates, not viewport coordinates. They get affected by cameras and don't auto-size. Solution: wrap UI scenes (main_menu, pause_menu) in a CanvasLayer root. The CanvasLayer renders in viewport coords regardless of parent. Set explicit `position` and `size` on Control children since anchors don't resolve against a CanvasLayer parent.

### CanvasLayer required for UI overlays during navigation

When navigation is active, its Camera2D offsets the viewport. Control-rooted scenes (combat, dialogue, faction_screen) added directly as children of GameManager (Node2D) get displaced by the camera offset and render off-screen or at wrong positions. Solution: wrap overlay scenes in a CanvasLayer (layer 10+) so they render in viewport coordinates independent of the camera.

### Pause menu process_mode

The pause menu CanvasLayer needs `process_mode = PROCESS_MODE_ALWAYS` set on the CanvasLayer root (not just the Control child) for it to render while the tree is paused.

### TextureRect expand_mode for portraits

TextureRect with `STRETCH_KEEP_ASPECT_CENTERED` does NOT shrink images to fit within the rect size by default. Must also set `expand_mode = TextureRect.EXPAND_IGNORE_SIZE` to allow the rect to be smaller than the texture. Without this, large portrait images overflow their container.

### ParallaxBackground mirroring

Set `motion_mirroring` to at least the viewport size (preferably 2x) for seamless tiling. ColorRect size must match mirroring dimensions.

### Starfield implementation

Procedural starfield using a Node2D with `_draw()` on a ParallaxLayer. Stars are pre-generated with deterministic seed (42) for consistency. Twinkle effect uses sin() on frame count.

### Push/pop state for overlays

GameManager uses separate `current_scene` (main state) and `_overlay_scene` (pushed overlays like faction/ship screen) to avoid losing the navigation scene when opening overlay screens. `push_state` hides current_scene, `pop_state` restores it.

### Control-rooted scenes as children of Node2D

Combat, trade, dialogue, faction, and ship screens use Control as root and are added as children of GameManager (Node2D). They render in viewport coordinates because Control nodes with explicit position/size are set up at build time. No CanvasLayer needed for these overlay screens.

### Scene builder pattern for CanvasLayer-rooted scenes

When scene root is CanvasLayer: pack and save the CanvasLayer as root. Attach scripts to the Control child, not the CanvasLayer. Use `set_owner_on_new_nodes(canvas, canvas)` with canvas as scene_owner.

### Test harness input simulation

`Input.action_press()` does NOT trigger `_unhandled_input()` in Godot. Must use `InputEventAction` objects pushed through `_root.push_input()` to simulate input that the dialogue screen and game manager can receive. Pattern: create `InputEventAction`, set `.action` and `.pressed = true`, push via `_root.push_input(ev)`, defer the release event.

### SceneTree script overlay management

For presentation/test scripts that need to show multiple UI scenes sequentially on top of navigation, maintain a dedicated `_overlay_layer: CanvasLayer` and swap scenes in/out of it. The fade overlay should be on an even higher layer (100) to render on top of everything.

### Godot binary path on macOS

Godot is at `/Applications/Godot.app/Contents/MacOS/Godot`. No `timeout` or `gtimeout` available — use Godot's own `--quit-after` for test timeouts.

### Video capture pipeline

Godot `--write-movie` outputs MJPEG AVI. Convert with: `ffmpeg -i output.avi -c:v libx264 -pix_fmt yuv420p -crf 28 -preset slow -vf "scale='min(1280,iw)':-2" -movflags +faststart gameplay.mp4`. Output is ~1.4MB for 30s at 720p.

### Tab key input action

Tab key physical keycode is `4194306` in Godot's InputEventKey format. Added as `ship_screen` input action. Note: also handled via direct keycode check in GameManager since Tab is commonly intercepted.

### Faction screen @onready path

FactionList VBoxContainer is inside a ScrollContainer. The @onready path must be `$ScrollContainer/FactionList`, not `$FactionList`.

### Choice history for endings

Choice types are recorded in `GameSession.choice_history` as `{"type": "...", "arc": N}` by `dialogue_screen.gd` when a choice has `choice_type`. The encounter engine's `determine_ending()` counts types and returns "hold"/"share"/"destroy". Only dialogue_screen records choices (not GameManager) to avoid double-counting.

### Modal stacking guard

`navigation.gd _unhandled_input` must check `_has_overlay()` before pushing any overlay. Without this, every keypress stacks a new overlay. `main.gd push_overlay` also has duplicate-type prevention — both guards needed for belt-and-suspenders fix.

### Theme color overrides

`theme_override_colors` is not a directly accessible dictionary in Godot 4. Use `control.add_theme_color_override("font_color", Color(...))` instead of `control.theme_override_colors.font_color = Color(...)`. The latter throws "Invalid access to property or key" errors.

### Star Map fog grid serialization

Fog of war uses `PackedByteArray` per region, stored in `GameStateData.star_map_data` as `fog_grids: Dictionary[region_id, PackedByteArray]`. Grid dimensions stored separately in `grid_dimensions`. Serialization via `StarMapSystem.to_dict()` / `from_dict()`. Fog cell size is 64 pixels — grid size = bounds / 64.

### Chunked fog rendering

Drawing fog cell-by-cell (8000+ cells) is slow. Render in chunks of 4x4 cells: check if all 16 cells are hidden, draw one large rect instead of 16 small ones. Massive performance improvement for large maps.

### Bounded region navigation

Ship position must be clamped to region bounds each frame: `position_x = clampf(position_x, margin, bounds.x - margin)`. Without this, ship can fly outside authored map area into void.

### POI type color mapping

Extended `ENCOUNTER_TYPE_COLORS` with star map POI types: `story` (gold), `hidden` (purple), `combat` (red), `rescue` (orange), `trade` (green), `exploration` (cyan). Used in both navigation minimap and full star map overlay.

### Spawn zone respawn timers

StarMapSystem manages spawn zones with respawn timers (30–90 seconds). Each zone has `max_active` POIs. Spawns despawn after timeout if not interacted, then respawn at new random position within zone radius.

### Crew trait system integration

`CrewTraitSystem` calculates active bonuses from recruited crew. Systems hook into it: `CombatSystem` applies firepower/critical hit bonuses, `CrewMoraleSystem` applies morale recovery, `EconomySystem` applies hull repair cost reduction, `EncounterEngine` applies exploration discovery rate and ambush detection bonuses.

### Crew recruitment detection

`dialogue_ui.gd` detects crew recruitment by checking `story_flags_set` for flags matching `crew_{id}_recruited`. Pattern: `for flag in choice.outcome.story_flags_set: if flag.begins_with("crew_") and flag.ends_with("_recruited"): recruit_crew_member()`

### Protagonist-aware encounter loading

`DataLoader.load_encounters()` filters by `protagonist_id` from `GameStateData`. Dave has separate encounter files (`arc*_encounters_dave.json`). `GameSession` loads correct encounters on new game based on selected protagonist.

### Input actions

- `star_map` — Tab key (keycode 4194306), opens full map overlay
- `mission_log` — M key (keycode 77), opens mission log
- `ship_screen` — Tab key (same as star_map, handled in navigation based on context)

### Story flag triggers

Encounter engine checks `story_flags_set` for special flags and triggers side effects: `fairy_cartographer_rescued` calls `StarMapSystem.on_cartographer_rescued()`. Pattern allows decoupled flag → system action wiring.
