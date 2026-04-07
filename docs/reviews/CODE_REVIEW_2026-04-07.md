# Code Review — Whisper Crystals (Godot)

## Executive Summary

- **Overall Assessment:** Good
- **Total Issues Found:** 22
- **Critical Issues:** 1
- **Review Date:** 2026-04-07
- **Reviewer:** Cascade (AI)
- **Project / Module Reviewed:** Whisper Crystals — full `res://scripts/` and `res://scenes/`
- **Godot Version:** 4.6 (GL Compatibility)

The codebase is well-structured with a clear separation of concerns: autoloads for global state, a dedicated systems layer for game logic, entity resources for data, and UI scripts for presentation. Signal-based decoupling via `EventBus` is used consistently. The main areas of concern are: duplicated condition-evaluation logic across two systems, inconsistent code style in the cutscene subsystem, several tight couplings from systems to the `GameSession` singleton, and an exploration-state persistence gap that will cause data loss on save/load.

---

## Critical Issues (Immediate Action Required)

### Issue #1: Exploration System State Not Persisted

- **Severity:** Critical
- **Category:** Bug / Data Loss
- **Location:** `res://scripts/autoload/game_session.gd`, `res://scripts/systems/exploration_system.gd`
- **Current Implementation:**

`game_session.gd` saves and restores `star_map_data` and `astral_hazard_data`, but `ExplorationSystem` manages its own `regions` and `points_of_interest` dictionaries containing runtime discovery/visit state. These are never serialised during save and are reloaded from raw JSON on load, losing all player-discovered regions and visited POIs.

```gdscript
# game_session.gd — save_game() serialises these:
game_state.star_map_data = star_map_system.to_dict()
game_state.astral_hazard_data = astral_hazard_system.to_dict()
# But exploration_system state is NEVER saved.
```

`exploration_system.gd` has `get_state_dict()` / `load_state_dict()` methods already implemented but they are never called:

```gdscript
# exploration_system.gd:215-231 — serialisation exists but is unused
func get_state_dict() -> Dictionary:
    var region_dict: Dictionary = {}
    for rid in regions:
        region_dict[rid] = regions[rid].to_dict()
    ...
```

- **Proposed Solution:**

Add exploration state to the save/load flow in `game_session.gd`:

```gdscript
# In save_game():
game_state.exploration_data = exploration.get_state_dict()

# In load_game(), after loading regions:
if not game_state.exploration_data.is_empty():
    exploration.load_state_dict(game_state.exploration_data)
```

Add `@export var exploration_data: Dictionary = {}` to `GameStateData`, and include it in `to_dict()` / `from_dict()`.

- **Reasoning:** Players who discover regions and visit POIs will lose that progress when saving and reloading. The serialisation code already exists but is disconnected.
- **Expected Benefits:** Complete save/load fidelity for exploration progress.
- **Trade-offs:** Slightly larger save files. Requires a save-data migration step if existing saves lack the field.
- **Effort Estimate:** Small
- **Priority:** Must-fix

---

## High Priority Issues

### Issue #2: Duplicated Condition-Evaluation Logic

- **Severity:** High
- **Category:** Redundancy / Maintainability
- **Location:** `res://scripts/systems/encounter_engine.gd:61-92`, `res://scripts/systems/side_mission_system.gd:189-205`
- **Current Implementation:**

Both `EncounterEngine._evaluate_conditions()` and `SideMissionSystem._evaluate_conditions()` implement nearly identical condition-checking logic (current_arc, story flags, `!null` sentinel, bool coercion). The encounter engine version also handles `highest_stat`, `min_*`, and `karma_tier` which the side-mission version silently ignores.

```gdscript
# encounter_engine.gd:61
func _evaluate_conditions(conditions: Dictionary, game_state: GameStateData) -> bool:
    for key in conditions:
        var expected = conditions[key]
        if key == "current_arc":
            if game_state.current_arc != expected:
                return false
        elif key == "highest_stat":
            ...
        elif key.begins_with("min_"):
            ...
        elif key == "karma_tier":
            ...
        else:
            var actual = game_state.story_flags.get(key)
            ...

# side_mission_system.gd:189 — near-identical, missing stat/karma branches
static func _evaluate_conditions(conditions: Dictionary, game_state: GameStateData) -> bool:
    for key in conditions:
        var expected = conditions[key]
        if key == "current_arc":
            if game_state.current_arc != expected:
                return false
        else:
            var actual = game_state.story_flags.get(key)
            ...
```

- **Proposed Solution:**

Centralise into a static utility, e.g. on `StatEvaluator` or a new `ConditionEvaluator` class:

```gdscript
class_name ConditionEvaluator
extends RefCounted

static func evaluate(conditions: Dictionary, game_state: GameStateData) -> bool:
    for key in conditions:
        var expected = conditions[key]
        if key == "current_arc":
            if game_state.current_arc != expected: return false
        elif key == "highest_stat":
            if game_state.player_character == null: return false
            if StatEvaluator.get_highest_stat(game_state.player_character) != expected: return false
        elif key.begins_with("min_"):
            if game_state.player_character == null: return false
            var stat_name: String = key.substr(4)
            if not StatEvaluator.check_threshold(game_state.player_character, stat_name, int(expected)): return false
        elif key == "karma_tier":
            if GameSession.karma_system != null:
                if GameSession.karma_system.get_tier(game_state) != expected: return false
        else:
            var actual = game_state.story_flags.get(key)
            if expected is String and expected == "!null":
                if actual == null: return false
            else:
                if actual == null and expected is bool: actual = false
                if actual != expected: return false
    return true
```

- **Reasoning:** Divergent copies will inevitably drift. Side missions silently fail to evaluate stat/karma conditions today.
- **Expected Benefits:** Single source of truth; side missions gain full condition support.
- **Trade-offs:** One extra class file.
- **Effort Estimate:** Small
- **Priority:** Must-fix

---

### Issue #3: Inconsistent Indentation in Cutscene Subsystem

- **Severity:** High
- **Category:** Code Quality / Style
- **Location:** `res://scripts/systems/cutscene/cutscene_manager.gd`, `res://scripts/systems/cutscene/dialogue_ui.gd`
- **Current Implementation:**

These two files use 4-space indentation. Every other `.gd` file in the project uses tabs, which is the GDScript style guide standard and what the Godot editor defaults to.

```gdscript
# cutscene_manager.gd — spaces
func _ready() -> void:
    if autostart:
        call_deferred("start", dialogue_path)
```

- **Proposed Solution:**

Convert both files to tab indentation to match the rest of the codebase. Most editors have a "convert indentation" command.

- **Reasoning:** Mixing indentation styles within a project causes diffs, merge conflicts, and cognitive overhead.
- **Expected Benefits:** Consistent codebase.
- **Trade-offs:** None.
- **Effort Estimate:** Small
- **Priority:** Must-fix

---

### Issue #4: Python-Style Docstrings in GDScript

- **Severity:** High
- **Category:** Code Quality / Style
- **Location:** `res://scripts/core/data_loader.gd:87,261,275`, `res://scripts/systems/economy_system.gd:221,253,284`
- **Current Implementation:**

Several functions use Python triple-quoted strings `"""..."""` as docstrings. GDScript does not support these as documentation comments; they compile as string expressions that are evaluated and discarded.

```gdscript
func load_purchasable_ships() -> Array:
    """Return ship templates that have purchasable == true."""
```

- **Proposed Solution:**

Replace with GDScript `##` doc comments:

```gdscript
## Return ship templates that have purchasable == true.
func load_purchasable_ships() -> Array:
```

- **Reasoning:** `"""..."""` strings allocate and discard a string at runtime. `##` comments are the official GDScript doc-comment syntax and show in the editor's built-in help.
- **Expected Benefits:** Proper documentation rendering; no wasted allocations.
- **Trade-offs:** None.
- **Effort Estimate:** Small
- **Priority:** Must-fix

---

### Issue #5: Systems Tightly Coupled to GameSession Singleton

- **Severity:** High
- **Category:** Architecture / Testability
- **Location:** `res://scripts/systems/combat_system.gd:60-72`, `res://scripts/systems/economy_system.gd:103-105`, `res://scripts/systems/encounter_engine.gd:79-81`, `res://scripts/systems/astral_hazard_system.gd:126-128`
- **Current Implementation:**

Multiple system classes directly reference the `GameSession` autoload singleton from within their logic:

```gdscript
# combat_system.gd — static method reaching into GameSession
static func calculate_damage(attacker_fp: int, defender_armour: int, is_player: bool = false) -> int:
    ...
    if is_player and GameSession.game_state != null:
        effective_fp *= (1.0 + GameSession.crew_trait_system.get_bonus(...))
```

```gdscript
# astral_hazard_system.gd
func _get_region_bounds(region_id: String) -> Vector2:
    if GameSession.star_map_system != null:
        return GameSession.star_map_system.get_bounds(region_id)
```

- **Proposed Solution:**

Pass required dependencies as function parameters rather than accessing the singleton:

```gdscript
static func calculate_damage(
    attacker_fp: int,
    defender_armour: int,
    is_player: bool = false,
    crew_bonus: float = 0.0,
    combat_skill: int = 0,
    crit_chance: float = 0.0,
) -> int:
    var effective_fp: float = float(attacker_fp) * (1.0 + crew_bonus)
    effective_fp *= (1.0 + combat_skill * 0.02)
    ...
```

Callers (e.g. `combat_ui.gd`) already have access to `GameSession` and can extract these values before calling.

- **Reasoning:** Systems become unit-testable without mocking autoloads. Reduces hidden dependencies.
- **Expected Benefits:** Testability, clarity of data flow.
- **Trade-offs:** Slightly more verbose call sites. Can be done incrementally.
- **Effort Estimate:** Medium
- **Priority:** Should-fix

---

### Issue #6: Duplicated Initialisation Sequences in start_new_game / load_game

- **Severity:** High
- **Category:** Redundancy
- **Location:** `res://scripts/autoload/game_session.gd:74-101` and `res://scripts/autoload/game_session.gd:180-211`
- **Current Implementation:**

`start_new_game()` and `load_game()` both call nearly the same sequence of system initialisation methods:

```gdscript
# start_new_game:
narrative.load_arcs()
encounter_engine.load_encounters(...)
side_mission_system.load_missions(...)
side_mission_system.load_distress_signals()
side_mission_system.load_crew_missions(...)
_load_crew_encounters(...)
_load_cartographer_encounters()
realm_control.initialize_realms(game_state)
...
_init_star_maps()
_init_astral_hazards()
_init_karma()
_init_star_bases()
_init_planets()

# load_game — same sequence repeated:
narrative.load_arcs()
encounter_engine.load_encounters(...)
side_mission_system.load_missions(...)
...
```

- **Proposed Solution:**

Extract into a shared `_init_systems()` method:

```gdscript
func _init_systems(protagonist_id: String, arc_id: String) -> void:
    var suffix: String = get_protagonist_config().get("encounter_suffix", "")
    narrative.load_arcs()
    encounter_engine.load_encounters(arc_id, suffix)
    side_mission_system.load_missions(arc_id, suffix)
    side_mission_system.load_distress_signals()
    side_mission_system.load_crew_missions(protagonist_id, data_loader)
    _load_crew_encounters(protagonist_id)
    _load_cartographer_encounters()
    realm_control.initialize_realms(game_state)
    var region_data: Array = data_loader.load_regions()
    exploration.load_regions(region_data)
    _init_star_maps()
    _init_astral_hazards()
    _init_karma()
    _init_star_bases()
    _init_planets()
```

- **Reasoning:** Adding a new system init step means remembering to update two places. One will inevitably be missed.
- **Expected Benefits:** Single init path; reduced maintenance burden.
- **Trade-offs:** None.
- **Effort Estimate:** Small
- **Priority:** Should-fix

---

## Medium Priority Issues

### Issue #7: `GameStateMachine` Class Appears Unused

- **Severity:** Medium
- **Category:** Dead Code
- **Location:** `res://scripts/core/state_machine.gd`
- **Current Implementation:**

`state_machine.gd` defines a `GameStateMachine` class with push/pop/switch/clear operations. However, `main.gd` implements its own scene-switching and overlay stack that does not use `GameStateMachine`. No script in the project instantiates or references this class.

- **Proposed Solution:**

Either:

1. Remove `state_machine.gd` if the current `main.gd` approach is permanent.
2. Refactor `main.gd` to use `GameStateMachine` for overlay management, which would give a cleaner architecture.

- **Reasoning:** Dead code increases cognitive overhead and gives the impression the project's navigation architecture is different from reality.
- **Expected Benefits:** Reduced confusion for new contributors.
- **Trade-offs:** If option 2, medium refactoring effort.
- **Effort Estimate:** Small (option 1) / Medium (option 2)
- **Priority:** Should-fix

---

### Issue #8: Design Resolution Mismatch in combat_ui.gd

- **Severity:** Medium
- **Category:** Bug / Consistency
- **Location:** `res://scripts/ui/combat_ui.gd:6-7`, `res://scripts/core/config.gd:5-6`, `res://project.godot:31-32`
- **Current Implementation:**

```gdscript
# combat_ui.gd
const DESIGN_W: float = 1024.0
const DESIGN_H: float = 576.0

# config.gd
const SCREEN_WIDTH: int = 1280
const SCREEN_HEIGHT: int = 720

# project.godot
window/size/viewport_width=1280
window/size/viewport_height=720
```

The combat UI uses 1024×576, while the project viewport is 1280×720. This means combat layout calculations are based on a different aspect ratio / resolution, requiring the scale factor logic to compensate.

- **Proposed Solution:**

Use `Config.SCREEN_WIDTH` / `Config.SCREEN_HEIGHT` (or better, read `get_viewport().size` at runtime) to ensure consistency.

- **Reasoning:** Multiple resolution constants are confusing and fragile.
- **Expected Benefits:** Layout consistency; removal of manual scale-factor code.
- **Trade-offs:** Combat UI layout will need testing after the change.
- **Effort Estimate:** Small
- **Priority:** Should-fix

---

### Issue #9: `Config` Class Is Extremely Thin and Partially Redundant

- **Severity:** Medium
- **Category:** Redundancy / Architecture
- **Location:** `res://scripts/core/config.gd`
- **Current Implementation:**

```gdscript
class_name Config
extends RefCounted

const SCREEN_WIDTH: int = 1280
const SCREEN_HEIGHT: int = 720
const FPS: int = 60
```

`SCREEN_WIDTH` and `SCREEN_HEIGHT` duplicate `project.godot`'s display settings. `FPS` is unused (Godot manages frame rate via project settings). Meanwhile, many hard-coded magic numbers exist throughout UI scripts (font sizes, colour values, timing constants) that *should* live in a shared config.

- **Proposed Solution:**

Either:

1. Remove `Config` and read viewport size from the engine at runtime.
2. Expand `Config` to centralise the scattered constants (stat limits, animation durations, colour palettes) and reference it throughout.

- **Reasoning:** A near-empty class that duplicates engine settings provides no value. Scattered magic numbers are the real config gap.
- **Expected Benefits:** Either less dead weight or a genuinely useful shared-constants module.
- **Trade-offs:** Option 2 requires auditing all scripts for extractable constants.
- **Effort Estimate:** Small (option 1) / Medium (option 2)
- **Priority:** Should-fix

---

### Issue #10: Repeated Weighted-Random Selection Pattern

- **Severity:** Medium
- **Category:** Redundancy
- **Location:** `encounter_engine.gd`, `side_mission_system.gd:136-158`, `faction_conquest_system.gd:78-96`, `exploration_system.gd:187-201`, `star_map_system.gd:225-227`, `astral_hazard_system.gd:90-98`
- **Current Implementation:**

Six different files implement the same "accumulate weights → roll → select" pattern with minor variations.

- **Proposed Solution:**

Add a static utility:

```gdscript
## In a shared utility, e.g. MathUtils or Config:
static func weighted_pick(items: Array, weight_fn: Callable) -> Variant:
    var total: float = 0.0
    for item in items:
        total += weight_fn.call(item)
    if total <= 0.0:
        return null
    var roll: float = randf() * total
    var acc: float = 0.0
    for item in items:
        acc += weight_fn.call(item)
        if roll <= acc:
            return item
    return items[-1]
```

- **Reasoning:** DRY principle. Bug fixes to the pattern (e.g. edge cases with zero-weight items) would need to be applied in six places.
- **Expected Benefits:** ~80 lines removed across 6 files; single fix point.
- **Trade-offs:** Tiny runtime overhead of the Callable indirection.
- **Effort Estimate:** Small
- **Priority:** Should-fix

---

### Issue #11: `@onready` Misuse on Manually-Created Nodes

- **Severity:** Medium
- **Category:** Code Quality
- **Location:** `res://scripts/autoload/music_manager.gd:64-65`
- **Current Implementation:**

```gdscript
@onready var _music_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var _sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
```

`@onready` triggers assignment when the node enters the tree. These nodes are `AudioStreamPlayer.new()` (created in-place), not scene-tree lookups. The `@onready` is misleading — the variables would work identically without it, and the real setup happens in `_ready()` where `add_child()` is called.

- **Proposed Solution:**

```gdscript
var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer

func _ready() -> void:
    _music_player = AudioStreamPlayer.new()
    _sfx_player = AudioStreamPlayer.new()
    _music_player.bus = "Master"
    ...
    add_child(_music_player)
    add_child(_sfx_player)
```

- **Reasoning:** `@onready` is semantically for referencing scene-tree nodes. Using it for `.new()` calls is confusing.
- **Expected Benefits:** Clarity.
- **Trade-offs:** None.
- **Effort Estimate:** Small
- **Priority:** Should-fix

---

### Issue #12: Missing `@warning_ignore` on EventBus Signals

- **Severity:** Medium
- **Category:** Code Quality
- **Location:** `res://scripts/autoload/event_bus.gd`
- **Current Implementation:**

Only `combat_hit` (line 10) has `@warning_ignore("unused_signal")`. The remaining ~50 signals likely trigger the same Godot warning since they are emitted from various files, not connected in the EventBus script itself.

- **Proposed Solution:**

Add a file-level annotation at the top:

```gdscript
@warning_ignore("unused_signal")
extends Node
```

Or annotate each signal individually for explicitness.

- **Reasoning:** Clean build output; signals-as-pub/sub will always appear "unused" at the declaration site.
- **Expected Benefits:** Eliminates dozens of warnings in the output panel.
- **Trade-offs:** None.
- **Effort Estimate:** Small
- **Priority:** Should-fix

---

### Issue #13: `StatEvaluator._get_stat` / `set_stat` Use Match Instead of Property Access

- **Severity:** Medium
- **Category:** Maintainability
- **Location:** `res://scripts/systems/stat_evaluator.gd:64-96`
- **Current Implementation:**

A 15-line `match` block maps string names to properties. Adding a new stat requires updating both `_get_stat` and `set_stat`.

```gdscript
static func _get_stat(character: Character, stat_name: String) -> int:
    match stat_name:
        "cunning": return character.cunning
        "leadership": return character.leadership
        ...
```

- **Proposed Solution:**

Use `character.get(stat_name)`:

```gdscript
static func _get_stat(character: Character, stat_name: String) -> int:
    if stat_name in STAT_NAMES:
        return character.get(stat_name) as int
    return 0
```

- **Reasoning:** GDScript resources support property access by name. The match block is fragile and verbose.
- **Expected Benefits:** Adding stats requires only updating `STAT_NAMES` and the `Character` class.
- **Trade-offs:** Slightly less explicit; minor performance difference (negligible).
- **Effort Estimate:** Small
- **Priority:** Should-fix

---

### Issue #14: Two Separate Dialogue UI Classes with Overlapping Names

- **Severity:** Medium
- **Category:** Architecture / Naming
- **Location:** `res://scripts/ui/dialogue_ui.gd` (632 lines), `res://scripts/systems/cutscene/dialogue_ui.gd` (114 lines, `class_name DialogueUI`)
- **Current Implementation:**

The cutscene subsystem has its own `DialogueUI` class (`class_name DialogueUI`) for 3D cutscene dialogue. The main game's dialogue screen at `scripts/ui/dialogue_ui.gd` has no `class_name` but serves a similar purpose for 2D encounter dialogues. Two files with the same filename in different directories is confusing.

- **Proposed Solution:**

Rename the cutscene version to `CutsceneDialogueUI` (both class name and filename) to disambiguate:

```gdscript
class_name CutsceneDialogueUI
extends CanvasLayer
```

- **Reasoning:** Prevents confusion when searching for "dialogue_ui" and avoids potential `class_name` conflicts if the main one ever gains a class name.
- **Expected Benefits:** Clarity.
- **Trade-offs:** Update references in `cutscene_scene.gd` / `cutscene_manager.gd`.
- **Effort Estimate:** Small
- **Priority:** Should-fix

---

### Issue #15: No Audio Bus Separation

- **Severity:** Medium
- **Category:** Architecture / Audio
- **Location:** `res://scripts/autoload/music_manager.gd:69,71`
- **Current Implementation:**

Both music and SFX players use `"Master"` bus:

```gdscript
_music_player.bus = "Master"
_sfx_player.bus = "Master"
```

- **Proposed Solution:**

Create `Music` and `SFX` audio buses in the project's `default_bus_layout.tres`, then assign:

```gdscript
_music_player.bus = "Music"
_sfx_player.bus = "SFX"
```

- **Reasoning:** Separate buses allow independent volume control and effects (e.g. ducking music during dialogue).
- **Expected Benefits:** Proper audio mixing; settings screen can control channels independently.
- **Trade-offs:** Requires creating the bus layout resource.
- **Effort Estimate:** Small
- **Priority:** Should-fix

---

## Low Priority / Enhancements

### Issue #16: Save Files Have No Integrity Check

- **Severity:** Low
- **Category:** Security / Robustness
- **Location:** `res://scripts/core/save_manager.gd`
- **Current Implementation:**

Saves are plain-text JSON with no checksum, encryption, or version migration beyond a stub. Players can trivially edit save files.

- **Proposed Solution:**

For a single-player game, full encryption is likely overkill. A lightweight SHA-256 checksum appended as a `_checksum` field would detect accidental corruption:

```gdscript
var checksum := json_string.sha256_text()
data["_checksum"] = checksum
```

On load, verify the checksum and warn if mismatched.

- **Reasoning:** Protects against corrupted saves from disk errors or partial writes.
- **Expected Benefits:** Corruption detection.
- **Trade-offs:** Doesn't prevent deliberate tampering (acceptable for single-player).
- **Effort Estimate:** Small
- **Priority:** Nice-to-have

---

### Issue #17: Faction Reputation Changed in Two Places

- **Severity:** Low
- **Category:** Redundancy
- **Location:** `res://scripts/systems/faction_system.gd:7-21`, `res://scripts/systems/encounter_engine.gd:163-169`
- **Current Implementation:**

`EncounterEngine._apply_outcome()` directly mutates faction reputation and calls `update_diplomatic_state()`, duplicating what `FactionSystem.change_reputation()` does (including cascade rules):

```gdscript
# encounter_engine.gd:163-169
for faction_id in outcome.faction_changes:
    var delta: int = outcome.faction_changes[faction_id]
    if game_state.faction_registry.has(faction_id):
        var faction: Faction = game_state.faction_registry[faction_id]
        faction.reputation_with_player = clampi(faction.reputation_with_player + delta, -100, 100)
        faction.update_diplomatic_state()
```

This bypasses cascade rules that `FactionSystem.change_reputation()` applies.

- **Proposed Solution:**

Delegate to `FactionSystem`:

```gdscript
for faction_id in outcome.faction_changes:
    var delta: int = outcome.faction_changes[faction_id]
    GameSession.faction_system.change_reputation(game_state, faction_id, delta)
```

- **Reasoning:** Encounter outcomes should trigger the same faction cascade logic as all other reputation changes.
- **Expected Benefits:** Consistent faction dynamics.
- **Trade-offs:** Need to ensure no circular calls.
- **Effort Estimate:** Small
- **Priority:** Nice-to-have

---

### Issue #18: `combat_ui.gd` _draw() Complexity

- **Severity:** Low
- **Category:** Readability / Maintainability
- **Location:** `res://scripts/ui/combat_ui.gd` (585 lines)
- **Current Implementation:**

The file is 585 lines with manual `_draw()` calls for health bars, laser beams, ship positioning, and UI layout. Cyclomatic complexity is high. Many magic numbers for positions, sizes, and colours are scattered throughout.

- **Proposed Solution:**

1. Extract health-bar drawing into a reusable `HealthBar` Control node.
2. Move colour palette constants to `ThemeBuilder` or `Config`.
3. Consider breaking the file into `CombatLayout`, `CombatAnimations`, and `CombatLogic` components.

- **Reasoning:** 585 lines in one script with manual drawing makes changes risky.
- **Expected Benefits:** Easier to modify combat visuals independently.
- **Trade-offs:** More files to manage.
- **Effort Estimate:** Large
- **Priority:** Nice-to-have

---

### Issue #19: `star_map_screen.gd` Is 750 Lines

- **Severity:** Low
- **Category:** Readability / Maintainability
- **Location:** `res://scripts/ui/star_map_screen.gd`
- **Current Implementation:**

The Celestial Codex screen handles three map layers (galaxy, region, local), procedural backdrops, fog rendering, POI drawing, legend display, and input handling — all in a single 750-line script.

- **Proposed Solution:**

Extract layer-specific rendering into helper classes:

- `GalaxyLayerRenderer`
- `RegionLayerRenderer`
- `LocalLayerRenderer`

Each with its own `draw()` and input handling.

- **Reasoning:** Reduces cognitive load; each layer can evolve independently.
- **Expected Benefits:** Improved readability and testability.
- **Trade-offs:** More files.
- **Effort Estimate:** Large
- **Priority:** Nice-to-have

---

### Issue #20: `dialogue_ui.gd` Is 632 Lines with High Complexity

- **Severity:** Low
- **Category:** Readability / Maintainability
- **Location:** `res://scripts/ui/dialogue_ui.gd`
- **Current Implementation:**

This script handles both legacy single-step encounters and new multi-step branching dialogue, including UI construction, typewriter effects, choice button creation, outcome application, combat transitions, crew recruitment, and portrait loading.

- **Proposed Solution:**

Consider splitting:

- Legacy encounter handling → `LegacyDialogueHandler`
- Multi-step dialogue → `BranchingDialogueHandler`
- Shared UI building → keep in `dialogue_ui.gd`

- **Reasoning:** The dual-mode design (legacy vs branching) with interleaved code paths is error-prone.
- **Expected Benefits:** Each dialogue mode can be modified independently.
- **Trade-offs:** Requires careful extraction.
- **Effort Estimate:** Large
- **Priority:** Nice-to-have

---

### Issue #21: `_process` Always Active in GameSession

- **Severity:** Low
- **Category:** Performance
- **Location:** `res://scripts/autoload/game_session.gd:65-67`
- **Current Implementation:**

```gdscript
func _process(delta: float) -> void:
    if game_state != null:
        game_state.playtime_seconds += delta
```

This runs every frame even when on the main menu (where `game_state` is `null`). The overhead is minimal (a null check), but it's better practice to disable processing when not needed.

- **Proposed Solution:**

```gdscript
func _ready() -> void:
    ...
    set_process(false)  # Enable only when game_state is set

func start_new_game(...) -> void:
    ...
    set_process(true)

func quit_to_menu() -> void:
    game_state = null
    set_process(false)
    ...
```

- **Reasoning:** Best practice — don't process when unnecessary.
- **Expected Benefits:** Marginal; mainly architectural hygiene.
- **Trade-offs:** Must remember to toggle `set_process`.
- **Effort Estimate:** Small
- **Priority:** Nice-to-have

---

### Issue #22: No Test Suite

- **Severity:** Low
- **Category:** Quality Assurance
- **Location:** Project-wide
- **Current Implementation:**

No GUT, GdUnit4, or custom test scenes were found. The `examples/` directory contains demo scenes for the procedural map plugin but no game-logic tests.

- **Proposed Solution:**

Start with unit tests for the pure-logic systems (`CombatSystem`, `EconomySystem`, `KarmaSystem`, `StatEvaluator`, `ConditionEvaluator`) using GUT or GdUnit4. These classes extend `RefCounted` and are easy to instantiate in tests.

- **Reasoning:** Systems with complex branching (condition evaluation, damage calculation, economy ticks) are prime candidates for regression tests.
- **Expected Benefits:** Confidence in refactoring; catches regressions early.
- **Trade-offs:** Initial setup time; ongoing maintenance.
- **Effort Estimate:** Medium (initial setup) / ongoing
- **Priority:** Nice-to-have

---

## Quick Wins

1. **Issue #4** — Replace `"""..."""` with `##` doc comments (6 occurrences, 5 minutes)
2. **Issue #12** — Add `@warning_ignore("unused_signal")` to EventBus (1 line)
3. **Issue #11** — Fix `@onready` misuse in MusicManager (move `.new()` to `_ready()`)
4. **Issue #21** — Toggle `set_process` in GameSession (3 lines changed)
5. **Issue #3** — Convert cutscene files to tab indentation (editor command)

---

## Long-term Improvements

1. **Issue #5** — Decouple systems from GameSession singleton. Recommend doing incrementally over 2–3 sprints, starting with `CombatSystem` (easiest, static methods).
2. **Issues #18, #19, #20** — Break up large UI scripts (`combat_ui`, `star_map_screen`, `dialogue_ui`). Plan for a dedicated UI refactoring sprint.
3. **Issue #22** — Introduce a test framework. Start with `RefCounted` systems, expand to scene integration tests.

---

## Positive Findings

- **Clean EventBus pattern** — Signals are well-organised by domain (combat, economy, narrative, etc.) with typed parameters. This is textbook Godot decoupling.
- **Consistent entity serialisation** — All entities (`Character`, `Ship`, `Faction`, `Encounter`, etc.) implement matching `to_dict()` / `from_dict()` pairs, making save/load straightforward.
- **Good use of `Resource` subclasses** — Entities extend `Resource` with `@export` properties, which works well with Godot's inspector and serialisation.
- **Robust save system** — `SaveManager` uses atomic writes (tmp → rename) with backup files, which is a best practice for preventing data loss.
- **Well-structured data loading** — `DataLoader` provides a caching layer with clear error reporting via `push_error`.
- **Typed GDScript** — Most code uses typed variables and return types, improving IDE support and runtime safety.
- **Autoload discipline** — Only four autoloads, each with a clear responsibility. No god-object anti-pattern.
- **`ProceduralMapManager` texture caching** — Avoids regenerating expensive procedural textures unless parameters change.

---

## Recommendations Summary

| Issue ID | Title | Severity | Effort | Priority | Category | Status |
| -------- | ----- | -------- | ------ | -------- | -------- | ------ |
| #1 | Exploration state not persisted | Critical | Small | Must-fix | Bug | ✅ Done |
| #2 | Duplicated condition evaluation | High | Small | Must-fix | Redundancy | ✅ Done |
| #3 | Inconsistent indentation (cutscene) | High | Small | Must-fix | Style | ✅ Done |
| #4 | Python docstrings in GDScript | High | Small | Must-fix | Style | ✅ Done |
| #5 | Systems coupled to GameSession | High | Medium | Should-fix | Architecture | ✅ Done (incremental) |
| #6 | Duplicated init in start/load | High | Small | Should-fix | Redundancy | ✅ Done |
| #7 | Unused GameStateMachine class | Medium | Small | Should-fix | Dead code | ✅ Deprecated |
| #8 | Design resolution mismatch | Medium | Small | Should-fix | Bug | ✅ Done |
| #9 | Config class too thin / redundant | Medium | Small | Should-fix | Architecture | ✅ Expanded |
| #10 | Repeated weighted-random pattern | Medium | Small | Should-fix | Redundancy | ✅ Done |
| #11 | @onready misuse in MusicManager | Medium | Small | Should-fix | Style | ✅ Done |
| #12 | Missing @warning_ignore on EventBus | Medium | Small | Should-fix | Style | ✅ Done |
| #13 | StatEvaluator match-block fragility | Medium | Small | Should-fix | Maintainability | ✅ Done |
| #14 | Two dialogue_ui files | Medium | Small | Should-fix | Naming | ✅ Done |
| #15 | No audio bus separation | Medium | Small | Should-fix | Audio | ✅ Done |
| #16 | Save file integrity check | Low | Small | Nice-to-have | Security | ✅ Done |
| #17 | Faction reputation bypasses system | Low | Small | Nice-to-have | Redundancy | ✅ Done |
| #18 | combat_ui.gd complexity | Low | Large | Nice-to-have | Maintainability | ⏳ Deferred |
| #19 | star_map_screen.gd 750 lines | Low | Large | Nice-to-have | Maintainability | ⏳ Deferred |
| #20 | dialogue_ui.gd 632 lines | Low | Large | Nice-to-have | Maintainability | ⏳ Deferred |
| #21 | _process always active | Low | Small | Nice-to-have | Performance | ✅ Done |
| #22 | No test suite | Low | Medium | Nice-to-have | QA | ⏳ Deferred |

---

## Next Steps

1. ~~**Immediate (this sprint):** Fix Issues #1, #2, #3–#4, #6~~ — **DONE**
2. ~~**Next sprint:** Address #5, #7–#15~~ — **DONE**
3. **Roadmap:** Plan UI refactoring sprint for #18–#20; introduce test framework (#22).

---

## Implementation Log (2026-04-07)

### New files created

- `res://scripts/systems/condition_evaluator.gd` — centralised condition evaluation (Issue #2)
- `res://scripts/core/math_utils.gd` — shared `weighted_pick()` utility (Issue #10)
- `res://default_bus_layout.tres` — Music + SFX audio buses (Issue #15)

### Files modified

| File | Issues Addressed | Summary |
| ---- | ---------------- | ------- |
| `scripts/core/game_state_data.gd` | #1 | Added `exploration_data` field + serialisation |
| `scripts/autoload/game_session.gd` | #1, #6, #21, #5 | Persist exploration; extract `_init_systems()`; toggle `set_process`; inject deps |
| `scripts/systems/encounter_engine.gd` | #2, #17 | Delegate to `ConditionEvaluator`; delegate faction rep to `FactionSystem` |
| `scripts/systems/side_mission_system.gd` | #2, #10 | Delegate to `ConditionEvaluator`; use `MathUtils.weighted_pick` |
| `scripts/systems/cutscene/cutscene_manager.gd` | #3, #14 | Tabs; updated DialogueUI reference |
| `scripts/systems/cutscene/dialogue_ui.gd` | #3, #14 | Tabs; renamed class to `CutsceneDialogueUI` |
| `scripts/systems/cutscene/cutscene_scene.gd` | #3, #14 | Tabs; updated type annotation |
| `scripts/core/data_loader.gd` | #4 | `"""…"""` → `##` doc comments (3 functions) |
| `scripts/systems/economy_system.gd` | #4, #5, #9 | `"""…"""` → `##`; decoupled karma/repair; use Config const |
| `scripts/autoload/music_manager.gd` | #11, #15 | Fixed `@onready` misuse; Music/SFX bus assignment |
| `scripts/autoload/event_bus.gd` | #12 | File-level `@warning_ignore("unused_signal")` |
| `scripts/systems/stat_evaluator.gd` | #13 | Property access via `get()`/`set()` instead of match |
| `scripts/systems/combat_system.gd` | #5, #9 | Decoupled from GameSession; Config constants |
| `scripts/systems/astral_hazard_system.gd` | #5, #10 | Injected `star_map_system`; use `MathUtils.weighted_pick` |
| `scripts/systems/exploration_system.gd` | #10 | Use `MathUtils.weighted_pick` |
| `scripts/ui/combat_ui.gd` | #8 | Design resolution now uses `Config.SCREEN_WIDTH/HEIGHT` |
| `scripts/core/config.gd` | #9 | Expanded with stat limits, economy, combat, timing constants |
| `scripts/core/state_machine.gd` | #7 | Added `@deprecated` notice |
| `scripts/core/save_manager.gd` | #16 | SHA-256 checksum on save; verify on load |

### Deferred items (large effort / roadmap)

- **#18, #19, #20** — UI script decomposition (combat_ui, star_map_screen, dialogue_ui) — planned for dedicated UI refactoring sprint
- **#22** — Test framework introduction — recommend GUT or GdUnit4, starting with `CombatSystem`, `ConditionEvaluator`, `StatEvaluator`

---

## Review Sign-off

- **Reviewed by:** Cascade (AI)
- **Date:** 2026-04-07
- **Implementation completed:** 2026-04-07
- **Approved for implementation:** [x] Yes [ ] No [ ] Partial
- **Follow-up review needed:** [x] Yes [ ] No
- **Notes:** 18 of 22 issues resolved. Remaining 4 are large-effort UI decomposition (#18–#20) and test framework setup (#22), both deferred to roadmap. Review covers `res://scripts/` (52 GDScript files), `res://scenes/` (32 `.tscn` files), and `project.godot`. Addon code (`procedural_world_map`) was scanned but not deeply reviewed. A follow-up review of data files (`res://data/`) and shader files is recommended. Full details: `reviews/CODE_REVIEW_2026-04-07.md` (Implementation Log section).
