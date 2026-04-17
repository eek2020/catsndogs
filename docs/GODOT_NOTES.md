# Project Memory — Whisper Crystals (Godot 4.6)

Read before starting work. Write back discoveries after completing tasks.

## Engine Configuration

- **Engine:** Godot 4.6, GL Compatibility renderer
- **Resolution:** 1280x720, canvas_items stretch mode
- **Language:** GDScript with static typing
- **Target:** Desktop (Mac M3/M4 primary, Windows compatible)

## Architecture

- Four autoload singletons: EventBus, GameSession, MusicManager, ProceduralMapManager
- Data-driven content: all story/dialogue/encounters/factions/ships in JSON under `godot/data/`
- Event bus pattern for decoupled inter-system communication
- Scene-based UI: `.tscn` in `godot/scenes/ui/`, controllers in `godot/scripts/ui/`
- UI ↔ `GameSession` coupling is routed through per-screen `RefCounted` ViewModels under `scripts/ui/view_models/` (pattern established Sprint 3a, 2026-04-16). Screens call the VM; the VM is the only thing that touches `GameSession`. Tests inject a `SessionDouble` with the same duck-typed shape.

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

### Coroutines cannot resume on freed nodes (Sprint 3c)

If an `async` GDScript function awaits past a `tree.change_scene_to_file()` call, the calling node gets freed during the scene swap. The coroutine's `GDScriptFunctionState` becomes invalid and the remaining code silently never runs — no crash, just lost work. Specifically `scene_transition.gd` used to do `await tree.process_frame` twice AFTER the scene change, on `self` (an Area2D on the outgoing scene). Fade-in and `_is_transitioning = false` reset were being skipped. **Fix:** move post-scene-change work into a persistent autoload (`GameSession.complete_scene_transition(spawn_pos, spawn_facing, fade_duration)`) whose coroutine survives any scene swap. Tree-owned tweens (`tree.create_tween()`) likewise survive the swap; node-owned tweens do not.

### Dedicated signal > multi-type signal for recursion safety (Sprint 3c)

`dialogue_manager._show_bark` used to emit `EventBus.exploration_event` with `type: "npc_bark"`. `_on_exploration_event` is connected to the same signal, so any future branch that decided to handle barks would have infinite-recursed. **Fix:** dedicated signal `EventBus.npc_bark(npc_name, text)`. Keeps re-entry structurally impossible even if the handler table grows.

### Static cache dicts on GDScript classes for memoisation (Sprint 3c)

`static var _cache: Dictionary = {}` works on a regular `Control`/`Node` subclass (not just `RefCounted`). Pattern used in `dialogue_ui.gd._remove_near_white_bg` to memoise the O(w·h) per-pixel scan keyed by `(resource_path, hard_threshold, soft_threshold)`. Synthetic textures without a `resource_path` (e.g. generated inside tests) should fall through to the uncached path to avoid poisoning the cache with transient inputs.

### InputMap introspection for test guards (Sprint 3c)

`InputMap.get_actions()` returns every action including `ui_*` built-ins; filter by prefix if you only want user-defined ones. `InputMap.action_get_events(name)` returns the `InputEventKey` list. `InputEventKey.keycode == 0` means the binding is physical-only — skip those. This enabled `test_input_map_collisions.gd` to fail CI when two user actions share a keycode (e.g. the original R-key `menu_select` vs `repair` bug). Intentional context-separated overlaps (currently `pause`/`skip` on ESC) are whitelisted with a back-reference.

### ViewModel pattern for UI decoupling (Sprints 3a / 3b / 5a)

Every screen that reaches `GameSession` gets a companion `class_name <Screen>ViewModel extends RefCounted` under `scripts/ui/view_models/`. The VM holds a `_session` reference (the autoload in prod, a `SessionDouble` in tests) and exposes narrow, null-guarded accessors the screen actually needs plus any action methods (e.g. `travel_to_region`). Screens accept the VM via `initialize(vm)` and fall back to `VMClass.new(GameSession)` in `_ready` so the existing scene-switch flow is unchanged. Tests inject a `SessionDouble extends RefCounted` with the same duck-typed shape. Key win: the GD lint `Cannot find member X in base Y` still fires correctly against the VM even though `_session` is `Variant`, because the VM methods are strongly typed.

### Integer division warning suppression (Sprint 5a)

Godot 4.6 warns on `int(x) / 3` even when the result feeds a `Vector2i` constructor. Either do the division on floats first (`int(x / 3.0)`) or add `@warning_ignore("integer_division")` above the line. Preferred: float division + explicit int cast — reads clearer and satisfies the linter everywhere.

### RefCounted classes inherit set_meta / get_meta (Sprint 5a)

`RefCounted extends Object`, so `set_meta(name, value)` and `get_meta(name, default)` are inherited at no cost. Tests use these directly instead of custom fields when verifying VM actions that call `GameSession.set_meta("world_entry_region", ...)`. Do NOT override `set_meta` on a `RefCounted` subclass — the editor warns about shadowing the native method, and the GDScript warning-as-error policy will fail compilation.

### Typed fields in test doubles reject foreign types (Sprint 5b)

`class SessionDouble: var crew_morale: MoraleDouble = MoraleDouble.new()` is strongly typed. Assigning a real `CrewMoraleSystem` via `session.crew_morale = CrewMoraleSystem.new()` (or `.set(...)`) silently fails — the field keeps its prior value and the test asserts against 1.0 instead of the expected morale modifier. **Fix:** if the double must hold either a simpler stub OR the real system (e.g. for an integration test alongside unit tests), declare the field untyped: `var crew_morale = MoraleDouble.new()`. GDScript's duck typing then accepts both. Keeps the unit tests clean while letting one integration test exercise the real morale-threshold math end-to-end.

### Audit before implementing: "wire the dormant system" tickets may already be wired (Sprint 5b)

Both NEXT_STEPS.md and CODE_REVIEW.md listed "apply astral hazards during navigation tick" as pending. Grep revealed `_update_astral_hazards(dt)` was already running in `navigation.gd._process` since the hazard feature shipped — the tracker was stale. Before touching code on a "wire X into Y" ticket, grep the candidate call-site for the system's entry-point methods. Saves re-wiring effort and catches stale tracker rows that should be retired instead of implemented. (Same pattern surfaced in Sprints 1 and 3c for bug tickets.)

### Godot binary headless GUT run

From the repo root (not from `godot/`):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Expect `121/121 passing` as of 2026-04-16 (Sprint 5b). Splash-boot resource leak warnings at exit are pre-existing; do not treat them as test failures.

### Godot glTF `_Loop` suffix stripping (2026-04-17)

Godot's glTF importer with `gltf/naming_version=2` (the default on newly imported files) **rewrites animation names** when ingesting GLBs that contain NLA strips or named clips:

- Any clip whose name ends in `_Loop` has the suffix stripped AND `loop_mode` set to `LINEAR` (value `1`) automatically.
- Clips without the `_Loop` suffix keep their exact name and get `loop_mode = NONE` (value `0`).

Example: our CC0 UAL character pipeline pushes 19 `*_Loop` clips to the NLA during export (`Walk_Loop`, `Idle_Loop`, `Sprint_Loop`, `Crouch_Idle_Loop`, etc.). After Godot import, the `AnimationPlayer` exposes them as `Walk`, `Idle`, `Sprint`, `Crouch_Idle` — each with `loop_mode=1`. Gameplay code must call `ap.play("Walk")`, NOT `ap.play("Walk_Loop")`. See `docs/CHARACTER_PIPELINE.md` §Gotchas for the full story.

First surfaced by `godot/tools/validate_rigged_glb.gd` on the `nine_lives_rigged.glb` validation run — the validator's initial `EXPECTED_ANIMS` list used the pre-import NLA names and flagged all 19 loop clips as "missing" with exactly matching "extras" that were the stripped forms. The validator's constant table now stores `{post_import_name: expected_loop_mode}` pairs to make the rule explicit and to catch any future regression where `loop_mode` is not set correctly.

### Headless GLB validator pattern (2026-04-17)

For asset pipeline regression checks (character rigs, static props, animated shaders), a `@tool extends SceneTree` script under `godot/tools/*.gd` is the simplest way to get a PASS/FAIL signal from Godot without opening the editor. Key template points:

- `@tool extends SceneTree` with the work done in `_init()` and a terminating `quit(exit_code)` — replaces the SceneTree entirely, so autoloads still load but the project's main scene never starts.
- Args come in via `OS.get_cmdline_user_args()` after the `--` separator on the Godot invocation: `Godot --headless --path godot --script res://tools/X.gd -- arg1 arg2`.
- Mount the scene into `self.root` (the Window) if you need to actually tick signals / animations; otherwise operate purely on the instantiated PackedScene for cheap structural reads.
- Write both a JSON report (next to the asset or in `logs/`) AND a human-readable stdout summary for the developer tailing the log.

Reference implementation: `godot/tools/validate_rigged_glb.gd` — loads a rigged character GLB, walks the tree for `Skeleton3D` / `AnimationPlayer` / `MeshInstance3D`, validates expected bone count + animation set + per-clip `loop_mode`, and plays a handful of canonical clips for a real tick. Exit 0 on PASS, 1 on FAIL.
