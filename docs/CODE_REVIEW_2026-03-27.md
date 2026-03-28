# Code Review: Whisper Crystals

**Date:** 2026-03-27
**Reviewer:** Claude Opus 4.6
**Project:** Whisper Crystals — Godot 4.6 / GDScript
**Scope:** Full codebase review (61 GDScript files, 31 scenes, 16 resources, 68 JSON data files)

---

## Executive Summary

Whisper Crystals is a well-architected narrative-driven 2D space pirate game with a strong data-driven design. The codebase demonstrates good separation of concerns, consistent coding conventions, and a thoughtful signal-based event system. However, there are several areas that need attention before production release, particularly around **duplicated logic**, **frame-time performance in the navigation screen**, **missing null guards**, **save data versioning**, and **resource lifecycle management**. The project is in a solid mid-development state with clear paths to improvement.

**Overall Assessment:** Good — needs targeted fixes before shipping.

| Category | Rating | Summary |
|----------|--------|---------|
| Code Quality & Best Practices | B+ | Strong architecture, some redundancy |
| Bug Detection & Edge Cases | B- | Several null-guard gaps and edge cases |
| Performance Optimization | C+ | Navigation `_process()` is heavy; fog iteration is O(n) |
| Readability & Maintainability | A- | Excellent naming, docstrings, separation of concerns |
| Security Considerations | B+ | Minimal attack surface; save file injection possible |
| Godot Engine & Scene Architecture | B+ | Good composition; 4 autoloads is at the limit |
| GDScript-Specific Practices | B+ | Good use of typed variables; some anti-patterns |
| Game Loop & Frame Performance | C+ | Per-frame pixel manipulation and full redraws |
| Rendering & Asset Usage | B | 128x128 sprites fine for 720p; nebula gen could be optimized |
| Audio System | B+ | Well-structured; single SFX player limits concurrency |
| Input System & Player Control | B | Input Map used correctly; R key collision |
| Save/Load & State Management | B- | No version migration; no backup rotation |
| Gameplay Logic & Tuning | B+ | Data-driven; some magic numbers remain |
| Debugging & Tooling | C+ | Heavy use of `print()`; no debug toggles |
| Resource Management | B | `load()` used where `preload()` would be better |
| Production Readiness | C+ | Missing export config, error recovery, accessibility |

---

## 1. Code Quality & Best Practices

### Strengths
- **Signal-based architecture:** The `EventBus` autoload with 60+ signals provides excellent decoupling between systems. Systems emit signals rather than calling each other directly, which aligns perfectly with CLAUDE.md conventions.
- **Data-driven content:** All narrative, encounters, factions, ships, and economy data live in JSON files under `godot/data/`, with no hardcoded narrative in GDScript source.
- **Consistent entity serialization:** Every entity class (`Character`, `Ship`, `Faction`, `Encounter`, etc.) implements `to_dict()` / `from_dict()` consistently.
- **Well-structured class hierarchy:** Inner classes (e.g., `Ship.CrewMember`, `CrystalDeposit.SupplyRoute`, `Encounter.EncounterOutcome`) keep related data grouped without file sprawl.

### Issues

#### CRITICAL: Duplicated Outcome Application Logic
**Files:** `encounter_engine.gd:95-157` and `encounter_engine.gd:162-213`

`apply_choice_outcome()` and `apply_dialogue_step_outcome()` contain near-identical blocks for:
- Setting/clearing story flags
- Applying resource changes
- Applying faction reputation changes
- Applying karma changes
- Recording player decisions

**Recommendation:** Extract a shared `_apply_outcome()` helper:
```gdscript
func _apply_outcome(game_state: GameStateData, encounter: Encounter, outcome: Encounter.EncounterOutcome, choice_id: String, record_weight: float = 0.0) -> void:
    # ... shared logic here
```

#### MODERATE: Duplicated Condition Evaluation
**Files:** `encounter_engine.gd:61-92` and `side_mission_system.gd:189-205`

`_evaluate_conditions()` exists in both `EncounterEngine` and `SideMissionSystem` with overlapping logic. The encounter engine version is more complete (supports `highest_stat`, `min_*`, `karma_tier`), while the side mission version only handles `current_arc` and story flags.

**Recommendation:** Extract into a shared utility, or make the encounter engine's version a static function that the side mission system calls.

#### MODERATE: Duplicated Animation Logic
**Files:** `player_controller.gd:37-76` and `npc_controller.gd:185-198`

Both controllers have nearly identical `_update_animation()` and `_play_anim()` patterns with the same fallback-to-`idle_down` logic.

**Recommendation:** Extract into a shared `SpriteAnimationHelper` utility or a base class.

#### LOW: Redundant `_paint_rect` / `_paint_rect_legacy` Methods
**File:** `fringe_haven_outpost.gd:591-600`

These two methods differ only in calling `_set_tile` vs `_set_legacy`. Could be unified with a source parameter.

#### LOW: `DataLoader` Re-parses Same JSON for Related Data
**File:** `data_loader.gd:44-66`

`load_factions()`, `load_relationship_matrix()`, and `load_cascade_rules()` each call `_load_json("factions/faction_registry.json")` independently. While the cache prevents re-reading the file, the three separate calls add conceptual overhead. Consider a single `load_faction_data()` that returns all three.

---

## 2. Bug Detection & Edge Cases

### CRITICAL: Missing Null Guard on `player_ship` in Morale System
**File:** `crew_morale_system.gd:26`

```gdscript
func get_average_morale(game_state: GameStateData) -> int:
    var crew: Array = game_state.player_ship.crew  # Will crash if player_ship is null
```

If `player_ship` is null (possible during early initialization or corrupted save), this will throw a null reference error. The same pattern appears in `get_crew_by_morale()`, `change_crew_morale()`, `check_faction_loyalty()`, and `apply_faction_loyalty_effects()`.

**Fix:** Add `if game_state.player_ship == null: return 100` (or empty array) at the top of each method.

### CRITICAL: `dialogue_manager.gd` Push Overlay Passes Instance Instead of Key
**File:** `dialogue_manager.gd:109`

```gdscript
main.push_overlay(dialogue_instance)  # Passes a Control instance
```

But `main.gd:71` `push_overlay()` expects a `scene_key: String`, not a Control instance. This will fail at runtime because `SCENES.get(scene_key, "")` will return empty for a Control object.

**Fix:** Either modify `push_overlay` to accept a Control directly, or have `dialogue_manager` use the scene key approach. This is likely a runtime crash that hasn't surfaced yet because the code path may not have been tested end-to-end.

### HIGH: Input Map Collision — `menu_select` and `repair` Both Map to R Key
**File:** `project.godot:90-103`

Both `menu_select` and `repair` actions are bound to keycode 82 (R key). This means pressing R will trigger both actions simultaneously, causing unpredictable behavior.

**Fix:** Rebind one of these actions to a different key.

### HIGH: `scene_transition.gd` Creates Tween After Scene Change
**File:** `scene_transition.gd:70-75`

After `tree.change_scene_to_file()`, the SceneTransition node itself may have been freed (it was part of the old scene). Calling `create_tween()` on line 73 after the scene change and frame waits is risky — the node may no longer be in the tree.

**Fix:** Use `get_tree().create_tween()` instead of `create_tween()`, or restructure to handle the fade-in from the new scene's `_ready()`.

### HIGH: `_show_bark` Causes Infinite Recursion Risk
**File:** `dialogue_manager.gd:112-118`

```gdscript
func _show_bark(npc_name: String, text: String) -> void:
    EventBus.exploration_event.emit({
        "type": "npc_bark",
        ...
    })
```

`_on_exploration_event` is connected to `EventBus.exploration_event`. While `_on_exploration_event` checks for `type == "npc_dialogue"`, if future code adds handling for `"npc_bark"` in this same method, it would create infinite recursion. This is a latent risk.

**Recommendation:** Use a separate signal for barks (e.g., `EventBus.npc_bark`) instead of reusing `exploration_event`.

### MODERATE: `faction_system.gd:129` Calls `.get("reputation")` on Faction Object
**File:** `dialogue_manager.gd:129`

```gdscript
rep = faction_reg[faction_id].get("reputation", 0)
```

`faction_reg[faction_id]` is a `Faction` object, not a Dictionary. Calling `.get()` on a Resource works like `get()` on Object (returns property by name), but the property is `reputation_with_player`, not `reputation`. This will always return the default `0`.

**Fix:** Change to `faction_reg[faction_id].reputation_with_player`.

### MODERATE: No Bounds Check on `encounter_table` Access
**File:** `encounter_engine.gd:100`

```gdscript
var choice: Encounter.EncounterChoice = encounter.choices[choice_index]
```

No validation that `choice_index` is within range of `encounter.choices`. An out-of-range index will crash.

**Fix:** Add `if choice_index < 0 or choice_index >= encounter.choices.size(): return ""`

### LOW: `star_map_system.gd` Fog Grid Percentage is O(n)
**File:** `star_map_system.gd:361-373`

`get_region_fog_percentage()` iterates every cell in the grid. For a 6000/64 = 94 column by 94 row grid (~8,836 cells), this is fine. But if grid sizes increase, this becomes expensive. Consider caching the revealed count.

### LOW: Empty `arc2_side_missions.json`
The JSON data exploration revealed that `arc2_side_missions.json` is empty. This means Arc 2 has no side missions, which may be intentional (content not yet authored) or a bug.

---

## 3. Performance Optimization

### HIGH: Navigation Screen `_process()` Does Too Much Per Frame
**File:** `navigation.gd:193-214`

Every frame, the navigation screen:
1. Handles movement and position updates
2. Updates engine trail particles
3. Refreshes POI timers
4. Updates distress signals
5. Updates star map spawns
6. Updates astral hazards
7. Checks POI collisions (iterates all active POIs)
8. Checks star map POI collisions
9. Checks base proximity
10. Checks planet proximity
11. Updates flash text
12. Updates HUD labels
13. Calls `queue_redraw()` — triggers a full custom `_draw()` pass

**Recommendations:**
- Move collision checks to a timer (every 0.1s is sufficient for 300px/s ship speed)
- Only `queue_redraw()` when the ship has actually moved or state has changed
- Batch HUD label updates — only update when values change
- Consider using a dirty flag pattern for POI refresh

### HIGH: Per-Frame Background Removal in Navigation `_ready()`
**File:** `navigation.gd:106-108`

```gdscript
_ship_texture = _remove_background_by_corners(_ship_texture)
_ship_up_texture = _remove_background_by_corners(_ship_up_texture)
_ship_rotate_texture = _remove_background_by_corners(_ship_rotate_texture)
```

`_remove_background_by_corners()` iterates every pixel of each ship texture image on every scene instantiation. For a 72x72 image, that's 5,184 pixel operations × 3 textures = 15,552 pixel reads/writes.

**Recommendation:** Pre-process textures with transparent backgrounds in your art pipeline (export as PNG with alpha). Remove this runtime processing entirely. If runtime processing is required, cache the result in a static variable so it only runs once per game session.

### MODERATE: Star Map Fog Rendering Iterates Full Grid
**File:** `navigation.gd` (referenced in fog drawing)

Drawing fog of war requires iterating the full fog grid every frame to determine which cells to draw. Even with `FOG_CHUNK_SIZE = 4`, this is still iterating ~2,200 chunks per frame.

**Recommendation:** Generate a fog texture once and update it incrementally when cells are revealed. Use `Image` + `ImageTexture` for the fog layer instead of drawing individual rectangles.

### LOW: `DataLoader` JSON Cache Never Expires
**File:** `data_loader.gd:8`

The `_cache` dictionary grows unboundedly as more JSON files are loaded. For this project's 68 JSON files this is not a problem, but the cache has no eviction strategy.

### LOW: `fringe_haven_outpost.gd` Generates All Colliders in `_ready()`
**File:** `fringe_haven_outpost.gd:86-91`

The procedural generation creates all map tiles, water colliders, structure colliders, labels, and camera bounds synchronously in `_ready()`. For the current 44×25 map this completes quickly, but for larger maps this could cause a noticeable frame hitch.

**Recommendation:** Consider using `call_deferred()` for non-critical setup or breaking generation into coroutine steps.

---

## 4. Readability & Maintainability

### Strengths
- **Consistent naming:** snake_case for functions/variables, PascalCase for classes, UPPER_CASE for constants throughout.
- **Docstring comments:** Most classes and systems have file-level docstrings explaining purpose and Python-migration lineage.
- **Small, focused scripts:** Each system file handles one domain (combat, economy, factions, etc.) with clear boundaries.
- **Self-documenting code:** Variable names like `reputation_with_player`, `crystal_production_rate`, `extraction_rate` make the code readable without comments.

### Issues

#### MODERATE: `navigation.gd` is a God Script
This file exceeds 800 lines and handles:
- Ship movement physics (flip, bank, vertical blend)
- Starfield generation and rendering
- Nebula backdrop
- POI spawning, collision, and interaction
- Engine trail particle system
- Fog of war rendering
- Minimap drawing
- Distress signal management
- Astral hazard visualization
- Star base docking
- Planet landing
- Region boundary transitions
- HUD updates
- Flash messages
- Welcome message

**Recommendation:** Break into sub-components:
- `ShipController` — movement physics, orientation, trail
- `NavigationRenderer` — custom `_draw()` for stars, nebula, fog, POIs, minimap
- `NavigationHUD` — HUD label updates, flash messages
- `POIManager` — POI spawning, collision detection, interaction

#### LOW: Magic Strings for State Keys
Throughout the codebase, game states are referenced by string literals: `"navigation"`, `"menu"`, `"combat"`, `"trade"`, etc. These could be an enum or constants to prevent typos.

#### LOW: Inconsistent Error Handling Style
Some functions use `push_error()` (e.g., `save_manager.gd:31`), others silently return defaults (e.g., `data_loader.gd`), and others use `print()` (e.g., `crew_morale_system.gd:65`). A consistent error reporting strategy would help debugging.

---

## 5. Security Considerations

### MODERATE: Save File JSON Injection
**File:** `save_manager.gd:59-80`

Save files are plain JSON stored in `user://saves/`. A player could manually edit save data to:
- Set `crystal_inventory` to arbitrary values
- Modify `faction_registry` reputation values
- Set story flags to skip content
- Manipulate `karma` values

**Risk Level:** Low for a single-player game, but relevant if leaderboards or achievements are ever added.

**Recommendation:** Consider adding a simple checksum/hash to save files to detect tampering. For a single-player game, this is low priority but good practice.

### LOW: No Input Sanitization on JSON Data
**File:** `data_loader.gd`

JSON data files are loaded from `res://data/` (bundled with the game), so injection risk is minimal. However, if modding support is ever added, untrusted JSON could cause issues with unexpected types or missing keys.

### LOW: Atomic Save Has a Race Window
**File:** `save_manager.gd:52-54`

```gdscript
if FileAccess.file_exists(path):
    DirAccess.remove_absolute(path)
DirAccess.rename_absolute(tmp_path, path)
```

There's a tiny window between remove and rename where a crash would lose the save. On most desktop OS, `rename` is atomic and would overwrite the target — the explicit remove is unnecessary and actually creates the race condition.

**Fix:** Remove the `FileAccess.file_exists` check and `DirAccess.remove_absolute` call. Just call `DirAccess.rename_absolute(tmp_path, path)` directly.

---

## 6. Godot Engine & Scene Architecture

### Strengths
- **Composition over inheritance:** Scenes are composed of nodes rather than deep inheritance trees. NPCs, players, and transitions are separate scenes instanced into world scenes.
- **Scene-based UI:** Each UI screen is a `.tscn` with a corresponding controller script, enabling independent development and testing.
- **Proper use of groups:** Player detection uses `is_in_group("player")` for flexible identification.

### Issues

#### MODERATE: 4 Autoloads — At the Practical Limit
**Files:** `project.godot:22-27`

The project has 4 autoloads: `EventBus`, `GameSession`, `MusicManager`, `ProceduralMapManager`. Godot best practice recommends keeping autoloads to a minimum (typically 2-3). `ProceduralMapManager` could potentially be a regular node or a system under `GameSession` since it's only used for texture generation.

#### MODERATE: `dialogue_manager.gd` Should Be an Autoload or Part of GameSession
**File:** `dialogue_manager.gd`

This script is a Node that connects to EventBus but needs to be manually added to each world scene. If it's missing from a scene, NPC dialogue won't work. Consider making it part of GameSession or an autoload to ensure consistent availability.

#### LOW: `fringe_haven_outpost.tscn` and `oakhaven_outpost.tscn` Appear Duplicated
The scene exploration revealed these two outpost scenes have "identical structure." If they share the same layout, they should be a single parameterized scene with data-driven differences.

#### LOW: No Scene Preloading Strategy
All scene transitions use `load()` which blocks the main thread. For the UI scenes this is fine (they're small), but world scenes with procedural generation could benefit from background loading via `ResourceLoader.load_threaded_request()`.

---

## 7. GDScript / Language-Specific Practices

### Strengths
- **Static typing used consistently:** `var x: String`, `func foo() -> bool:`, typed arrays `Array[String]`, typed parameters.
- **Proper `@onready` usage:** Node references are declared with `@onready` throughout.
- **`@export` for editor-tunable values:** `player_controller.gd` exports `move_speed`, `npc_controller.gd` exports patrol points, idle duration, etc.
- **Correct `await` / coroutine usage:** Scene transitions and music fades properly use `await tween.finished`.

### Issues

#### HIGH: `navigation.gd` Accesses Internal `_overlay_stack` Directly
**File:** `navigation.gd:184-190`

```gdscript
func _has_overlay() -> bool:
    var main: Control = get_tree().current_scene
    if main and "_overlay_stack" in main:
        var stack: Array = main._overlay_stack
```

Directly accessing a private member (`_overlay_stack`) of another node breaks encapsulation. If `main.gd` changes its internal representation, this breaks silently.

**Fix:** Add a public method to `main.gd`: `func has_active_overlay() -> bool`.

#### MODERATE: `load()` Used Where `preload()` Would Be Better
**Files:** `main.gd:62`, `music_manager.gd:167,230`, `npc_controller.gd:61`

`load()` is called at runtime for resources that could be `preload()`ed at compile time:
- `main.gd:62`: `var scene: PackedScene = load(path)` — could use a preloaded scene dictionary
- `music_manager.gd`: Music and SFX files loaded at runtime — understandable for dynamic paths, but frequently used themes could be preloaded
- `npc_controller.gd:61`: `sprite.sprite_frames = load(path)` — loaded per-NPC at ready time

#### LOW: `randomize()` Called in `navigation.gd:105`
**File:** `navigation.gd:105`

`randomize()` is called in `_ready()`. In Godot 4, the random seed is already randomized by default. This call is unnecessary.

#### LOW: Python-Style Docstrings Used Instead of GDScript `##`
**Files:** `data_loader.gd:87,221,261`, `economy_system.gd:221,252`

Some methods use triple-quote `"""` docstrings (Python style) instead of GDScript's `##` doc comments. While these don't cause errors, they're string literals that get allocated at runtime rather than being parsed as documentation.

**Fix:** Replace `"""..."""` with `## ...` doc comments.

---

## 8. Game Loop & Frame Performance

### HIGH: `_process()` in `star_map_screen.gd` Calls `queue_redraw()` Every Frame
**File:** `star_map_screen.gd:47-49`

```gdscript
func _process(dt: float) -> void:
    _elapsed += dt
    map_canvas.queue_redraw()
```

This forces a complete redraw of the star map canvas every frame, even when nothing has changed. The star map is a complex drawing with galaxy nodes, connections, fog, and POIs.

**Recommendation:** Only redraw when the layer changes, when the user interacts, or on a timer (e.g., every 0.5s for animated elements).

### MODERATE: Engine Trail Particle System Is Array-Based
**File:** `navigation.gd:313-319`

```gdscript
func _update_trail(dt: float) -> void:
    var new_trail: Array = []
    for p in _trail:
        p["life"] -= dt
        if p["life"] > 0:
            new_trail.append(p)
    _trail = new_trail
```

A new array is allocated every frame and old Dictionary particles are iterated. For ~60 active particles this is fine, but a `PackedFloat32Array` with a ring buffer would be more cache-friendly and avoid GC pressure.

### MODERATE: `_physics_process` in NPC Controller Runs Even When NPC is Off-Screen
**File:** `npc_controller.gd:65-73`

All NPCs run their state machine and animation updates every physics frame regardless of visibility. In `fringe_haven_outpost.tscn` with 5+ NPCs, this adds up.

**Recommendation:** Use `VisibleOnScreenNotifier2D` to pause processing when off-screen.

### LOW: `move_and_slide()` Called in IDLE and TALK States with Zero Velocity
**File:** `npc_controller.gd:77-78, 101-102`

```gdscript
func _process_idle(delta: float) -> void:
    velocity = Vector2.ZERO
    move_and_slide()
```

Calling `move_and_slide()` with zero velocity every frame is wasteful. It still performs collision detection.

**Fix:** Only call `move_and_slide()` when `velocity.length() > 0`.

---

## 9. Rendering & Asset Usage

### Strengths
- **Consistent sprite frame setup:** All 15 character SpriteFrames resources use a uniform 128x128 pixel frame size with 4 frames per direction at consistent FPS (4.0 idle, 8.0 walk).
- **Multi-source tileset:** `world_tileset.tres` properly uses separate atlas sources for different tile types (main, village, water, campfire).
- **Procedural nebula backgrounds:** `ProceduralMapManager` generates region-specific backgrounds at quarter resolution (320×180) for performance.

### Issues

#### MODERATE: Runtime Pixel Manipulation for Ship Textures
**File:** `navigation.gd:118-159`

`_remove_background_by_corners()` performs per-pixel color comparison and alpha manipulation on ship textures at runtime. This is 15,000+ pixel operations per scene load.

**Fix:** Export ship sprites with proper transparency from the art tool. Remove this runtime processing entirely.

#### LOW: No LOD or Texture Streaming
All sprite textures are loaded at full resolution. For 128x128 character sprites at 720p, this is appropriate. No action needed currently, but keep in mind for higher resolution targets.

#### LOW: Fog of War Drawn as Individual Rectangles
Rather than drawing fog as a texture, the navigation screen draws individual colored rectangles for each fog chunk. This generates many draw calls for large fog regions.

**Recommendation:** Render fog to an `Image`/`ImageTexture` once, then update incrementally.

---

## 10. Audio System

### Strengths
- **State-to-theme mapping:** `MusicManager` cleanly maps game states to music themes with arc-specific overrides.
- **Pause/resume with position tracking:** Music playback position is saved and restored when transitioning between themes, providing seamless audio transitions.
- **SFX auto-triggered by EventBus:** Combat, trade, and UI events automatically play appropriate sound effects.
- **Linear volume scaling:** `set_music_volume()` properly converts linear 0-1 scale to dB.

### Issues

#### MODERATE: Single SFX AudioStreamPlayer Limits Concurrency
**File:** `music_manager.gd:221-231`

```gdscript
func play_sfx(sfx_id: String) -> void:
    _sfx_player.stream = load(path)
    _sfx_player.play()
```

Only one SFX can play at a time. If a `crystal_pickup` triggers while a `laser_hit` is playing, the hit sound is cut short. This is jarring in combat where hits, misses, and pickups can overlap.

**Recommendation:** Use an `AudioStreamPolyphonic` player or maintain a pool of 4-8 `AudioStreamPlayer` nodes for concurrent SFX playback.

#### LOW: SFX Resources Loaded Every Play
**File:** `music_manager.gd:224-229`

Each SFX play call does `load(path)` which, even with Godot's internal caching, involves path resolution and type checking. For frequently played sounds, consider `preload()` or a preloaded dictionary.

#### LOW: No Audio Bus Separation
**File:** `music_manager.gd:69-71`

Both music and SFX players use the "Master" bus. Separating them into "Music" and "SFX" buses would allow independent volume control via Godot's built-in audio bus system, which is more efficient than per-player volume adjustment.

---

## 11. Input System & Player Control

### Strengths
- **Input Map used correctly:** All input actions are defined in `project.godot` and referenced by name (e.g., `"move_up"`, `"interact"`).
- **`_unhandled_input` used properly:** Both `player_controller.gd` and `npc_controller.gd` use `_unhandled_input()` which correctly respects UI focus.
- **Camera follow with smoothing:** Player camera has `position_smoothing_enabled = true` with configurable speed.

### Issues

#### HIGH: R Key Collision Between `menu_select` and `repair`
**File:** `project.godot:90-103`

Both actions bound to keycode 82 (R). Will cause unintended dual-activation.

#### MODERATE: No Gamepad/Controller Support
All input bindings are keyboard-only. No joystick axes or gamepad buttons are mapped. For a desktop game targeting Mac/Windows, controller support is expected.

**Recommendation:** Add gamepad bindings for at least movement, interact, confirm, cancel, and pause.

#### MODERATE: No Input Rebinding
Input actions are hardcoded in `project.godot`. There's no settings UI for key rebinding. The `settings_screen.tscn` only has music/SFX toggles and a volume slider.

#### LOW: Diagonal Movement Not Speed-Normalized in World Scenes
**File:** `player_controller.gd:21-22`

```gdscript
_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
velocity = _direction * move_speed
```

`Input.get_vector()` returns a normalized vector by default (the `deadzone` parameter defaults handle this), so this is actually correct. However, the navigation screen movement in `navigation.gd:229-230` manually normalizes, creating an inconsistency in how movement is handled between the two modes.

---

## 12. Save/Load & State Management

### CRITICAL: No Save Data Version Migration
**File:** `save_manager.gd`

Save files include a `version` field in `GameStateData` but there's no migration code. If the data schema changes (new fields, renamed fields, restructured arrays), existing saves will fail to load or load with missing data.

**Recommendation:** Implement a version check in `load_game()`:
```gdscript
func _migrate_save_data(data: Dictionary) -> Dictionary:
    var version: String = data.get("version", "0.1.0")
    if version == "0.1.0":
        # Migration logic for 0.1.0 -> 0.2.0
        data["new_field"] = default_value
        data["version"] = "0.2.0"
    return data
```

### HIGH: No Save Backup Rotation
**File:** `save_manager.gd:43-54`

If the save process is interrupted after deleting the old file but before renaming the temp file, the save is lost. Additionally, there's no backup of the previous save.

**Recommendation:**
1. Remove the explicit delete (as noted in Security section — `rename` can overwrite)
2. Keep one backup: rename `save_slot_0.json` to `save_slot_0.json.bak` before writing new data

### MODERATE: Playtime Not Tracked
**File:** `game_state_data.gd:9`

`playtime_seconds` is declared but never incremented anywhere in the codebase. The save metadata will always show 0.0 playtime.

**Fix:** Add `game_state.playtime_seconds += dt` in `navigation.gd:_process()` or `game_session.gd`.

### MODERATE: `GameSession.quit_to_menu()` Doesn't Prompt for Unsaved Changes
**File:** `game_session.gd:240-245`

`quit_to_menu()` immediately sets `game_state = null` without checking for unsaved progress. Players could lose significant progress.

**Recommendation:** Emit a "confirm quit" signal or check if the game has been saved since the last state change.

---

## 13. Gameplay Logic & Tuning

### Strengths
- **Data-driven encounters:** All encounters, choices, and outcomes are defined in JSON with configurable trigger conditions, faction changes, and karma effects.
- **Exported tuning variables:** Player/NPC speed, idle duration, and patrol points are `@export`ed for editor tuning.
- **Karma system with tiered effects:** 5 karma tiers with price modifiers and NPC disposition offsets provide meaningful gameplay consequences.

### Issues

#### MODERATE: Magic Numbers in Combat System
**File:** `combat_system.gd:58-82`

- `0.8, 1.2` — damage variance range
- `0.02` — combat skill bonus per level
- `0.04` — dodge chance per speed point
- `0.45, 0.55` — dodge caps
- `0.01` — stealth bonus per level
- `1.5` — critical hit damage multiplier

These should be exported constants or loaded from a `combat_config.json` to allow balance tuning without code changes.

#### MODERATE: Economy Magic Numbers
**File:** `economy_system.gd:161-183`

- `0.001` — supply modifier increment per throughput unit
- `2.0` — max supply modifier
- `50` — low crystal reserves threshold
- `100` — high crystal reserves threshold
- `0.02` — demand multiplier increase rate
- `2.5` — max demand multiplier
- `0.01` — demand multiplier decrease rate
- `0.5` — min demand multiplier
- `0.75` — sell price as fraction of buy price

**Recommendation:** Move these to `economy_data.json` or a `balance_config.json` for easier tuning.

#### LOW: Crew Morale Labels Are Not Data-Driven
**File:** `crew_morale_system.gd:1-23`

Morale thresholds (20, 40, 60, 80) and labels ("MUTINY", "DISGRUNTLED", etc.) are hardcoded. Consider moving to a config file for localization and tuning.

---

## 14. Debugging & Tooling

### Issues

#### MODERATE: Excessive `print()` Usage
**Files:** Multiple

- `save_manager.gd:55`: `print("Game saved to slot %d: %s" % [slot, path])`
- `save_manager.gd:122`: `print("Deleted save slot %d" % slot)`
- `crew_morale_system.gd:65`: `print("Crew mutiny risk: %s (morale %d)" % [...])`
- `save_manager.gd:65`: `print("No save file for slot %d" % slot)`

These `print()` calls will appear in the output console in release builds. They should be wrapped in a debug check or use Godot's logger with appropriate log levels.

**Recommendation:** Create a simple logging utility or use `print_debug()` for development-only output.

#### MODERATE: No Debug Toggles or Developer Console
There are no debug flags, cheat codes, or developer tools for testing. Common useful features:
- Skip to specific arc
- Add crystals/salvage
- Teleport to region
- Toggle fog of war
- Force encounter trigger

**Recommendation:** Add a debug panel accessible via a key combo (e.g., Ctrl+Shift+D) that's disabled in release builds.

#### LOW: No Custom Editor Tools
The project uses the ProceduralWorldMap addon for editor integration, but there are no custom inspectors for game-specific data (e.g., encounter preview, faction relationship visualizer, dialogue tree viewer).

---

## 15. Resource Management

### Issues

#### MODERATE: `ProceduralMapManager` Datasource Lifecycle
**File:** `procedural_map_manager.gd:162-170`

```gdscript
func _cleanup_datasource(ds: ProceduralWorldDatasource) -> void:
    if "area_info_cache" in ds:
        for ai in ds.area_info_cache:
            if ai != null and is_instance_valid(ai):
                ai.free()
        ds.area_info_cache.clear()
    ds.free()
```

The datasource is a Node that's never added to the tree, requiring manual `free()`. This is fragile — if an exception occurs before cleanup, the node leaks. Consider using `RefCounted` for datasources or adding them temporarily to the tree.

#### MODERATE: `_dialogue_cache` in `dialogue_manager.gd` Grows Unbounded
**File:** `dialogue_manager.gd:8`

Loaded dialogue data is cached forever. If the player interacts with many NPCs over a long session, this cache grows. For the current 5 dialogue files, this is negligible, but the pattern doesn't scale.

#### LOW: Scene Instantiation Uses `load()` Instead of `preload()`
**File:** `main.gd:62`

```gdscript
var scene: PackedScene = load(path)
```

For the 20+ UI scenes, `load()` is called on each transition. Frequently visited scenes (navigation, dialogue, trade) could benefit from preloading or caching.

#### LOW: SpriteFrames Loaded Per-NPC Instance
**File:** `npc_controller.gd:54-62`

Each NPC instance loads its SpriteFrames resource independently with `load(path)`. If multiple NPCs share the same sprite (e.g., generic guards), Godot's resource cache handles this, but explicit sharing via `@export` would be clearer.

---

## 16. Production Readiness

### Issues

#### HIGH: Missing Primary Target Export Presets
**File:** `project.godot`

Export presets exist for Linux/X11 and Web, but **not for the primary targets** (macOS and Windows) listed in CLAUDE.md. The project needs:
- Export presets for macOS (.dmg/.app) — primary target per project spec
- Export presets for Windows (.exe) — secondary target per project spec
- Application signing (macOS notarization)
- Custom application icon (currently using Godot default)

#### HIGH: No Error Recovery / Crash Handling
If any system fails during gameplay (e.g., corrupted encounter data, missing audio file), there's no graceful recovery. The game will either crash or enter an undefined state.

**Recommendation:** Add try-catch patterns around critical paths (scene loading, save/load, encounter resolution) with user-facing error messages.

#### MODERATE: No Accessibility Features
The game lacks:
- Scalable UI text
- Color-blind friendly palette options
- Screen reader support
- Configurable text speed for dialogue
- Subtitle/caption options for audio

#### MODERATE: No Loading Screen
Scene transitions use a simple fade-to-black. For heavier scenes (fringe haven outpost with procedural generation), a loading indicator would improve UX.

#### MODERATE: No Localization Infrastructure
All text strings are hardcoded in English across GDScript files and JSON data. Godot supports `.csv`/`.po` translation files, but the project has no `TranslationServer` usage or translation keys.

#### LOW: `icon.png` Is a Placeholder
The Godot default icon is still present. A custom game icon should be created for the application.

#### LOW: No Analytics or Telemetry Framework
No crash reporting or anonymous usage analytics to understand player behavior, common crash points, or engagement metrics.

---

## Priority Action Items

### P0 — Fix Before Next Playtest
1. **Fix `dialogue_manager.gd` push_overlay type mismatch** — likely a runtime crash
2. **Fix R key input collision** (`menu_select` / `repair`)
3. **Add null guards to `CrewMoraleSystem`** for `player_ship`
4. **Fix `faction_system.gd:129`** `.get("reputation")` → `.reputation_with_player`

### P1 — Fix Before Alpha
5. **Extract shared outcome application logic** in `EncounterEngine`
6. **Add save data version migration** framework
7. **Fix scene transition tween lifetime** issue
8. **Track `playtime_seconds`** in the game loop
9. **Add save backup rotation**
10. **Replace `print()` with debug-only logging**

### P2 — Fix Before Beta
11. **Optimize navigation screen `_process()`** — throttle collision checks, conditional redraws
12. **Break up `navigation.gd`** into sub-components
13. **Pre-process ship textures** with transparency (remove runtime pixel manipulation)
14. **Add SFX polyphony** (multiple concurrent sound effects)
15. **Add export presets** for Mac and Windows
16. **Add gamepad support**

### P3 — Polish for Release
17. **Add error recovery** around critical paths
18. **Add loading screens** for heavy scene transitions
19. **Implement accessibility basics** (text scaling, color-blind mode)
20. **Add debug panel** for development testing
21. **Move combat/economy magic numbers** to config files
22. **Set up localization infrastructure**

---

*Review conducted on 2026-03-27 by Claude Opus 4.6*
*Codebase snapshot: commit 300c573 (main branch)*
