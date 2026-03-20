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
