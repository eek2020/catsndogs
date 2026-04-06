# Code Review: Whisper Crystals

## Executive Summary

- **Overall Assessment:** Good
- **Total Issues Found:** 18
- **Critical Issues:** 2
- **Review Date:** 2026-04-05
- **Reviewer:** Claude Opus 4.6 (AI-assisted)
- **Code/Module Reviewed:** Full codebase — `godot/scripts/`, `godot/data/`, `godot/scenes/`, `godot/shaders/`

The Whisper Crystals codebase is well-architected with clean separation of concerns, consistent data-driven design, and robust serialization. The project demonstrates strong GDScript conventions and a thoughtful event-driven architecture. The primary concerns are: (1) unvalidated encounter chain triggers that could cause infinite loops, (2) missing hull-death handling outside of combat, and (3) several medium-priority issues around tight coupling to the `GameSession` singleton, redundant iteration patterns, and unused data fields.

---

## Critical Issues (Immediate Action Required)

### Issue #1: Encounter Chain Triggers Can Cause Infinite Loops

- **Severity:** Critical
- **Category:** Bug
- **Current Implementation:**

In [encounter.gd:59](godot/scripts/entities/encounter.gd#L59), `EncounterOutcome` includes a `trigger_encounter_id` field:

```gdscript
@export var trigger_encounter_id: String = ""
```

However, the encounter engine's `_apply_outcome()` method in [encounter_engine.gd:135-184](godot/scripts/systems/encounter_engine.gd#L135-L184) **never uses `trigger_encounter_id`**. This means:

1. If encounter data specifies chained triggers, they are silently ignored — a content bug.
2. If this field is implemented later without loop detection, encounter A triggering B triggering A would create an infinite loop.

- **Proposed Solution:**

Either implement trigger chains with a visited-set guard, or remove the unused field:

```gdscript
# Option A: Implement with loop protection
func _apply_outcome(...) -> void:
    # ... existing logic ...
    
    if not outcome.trigger_encounter_id.is_empty():
        if outcome.trigger_encounter_id not in game_state.completed_encounters:
            var chained := _find_encounter(outcome.trigger_encounter_id)
            if chained != null:
                # Defer to avoid recursive stack growth
                GameSession.call_deferred("_trigger_encounter", chained)

# Option B: Remove dead field from EncounterOutcome
# Delete trigger_encounter_id from encounter.gd EncounterOutcome
```

- **Reasoning:** Dead code paths that reference data fields create a false promise for content authors. If a designer adds `trigger_encounter_id` to JSON data, nothing happens — a silent failure that's hard to debug.
- **Expected Benefits:** Prevents future infinite loop bugs; eliminates confusion for content authors.
- **Trade-offs:** Option A adds complexity; Option B removes a planned feature.
- **Effort Estimate:** Small
- **Priority:** Must-fix

---

### Issue #2: Ship Destruction Outside Combat Has No Game-Over Handling

- **Severity:** Critical
- **Category:** Bug
- **Current Implementation:**

The astral hazard system applies hull damage in [astral_hazard_system.gd:283-286](godot/scripts/systems/astral_hazard_system.gd#L283-L286):

```gdscript
func apply_damage(game_state: GameStateData, damage: int) -> void:
    if game_state.player_ship == null:
        return
    game_state.player_ship.current_hull = maxi(0, game_state.player_ship.current_hull - damage)
```

If `current_hull` reaches 0 from hazard damage, **no game-over or defeat event is emitted**. The player's ship is destroyed but the game continues with 0 hull. Similarly, the `crystal_drain` status effect in `_tick_status_effects` can drain all crystals to 0 with no notification.

In contrast, the combat system properly emits `combat_defeat` when hull reaches 0.

- **Proposed Solution:**

```gdscript
func apply_damage(game_state: GameStateData, damage: int) -> void:
    if game_state.player_ship == null:
        return
    game_state.player_ship.current_hull = maxi(0, game_state.player_ship.current_hull - damage)
    if game_state.player_ship.current_hull <= 0:
        EventBus.combat_defeat.emit()
```

- **Reasoning:** Players can silently die from hazard damage with no feedback or consequence, which is both a gameplay bug and a potential source of downstream null/zero errors.
- **Expected Benefits:** Consistent death handling across all damage sources.
- **Trade-offs:** May need a distinct signal (e.g., `ship_destroyed`) if hazard death should differ from combat defeat.
- **Effort Estimate:** Small
- **Priority:** Must-fix

---

## High Priority Issues

### Issue #3: Tight Coupling to GameSession Singleton in Static/System Methods

- **Severity:** High
- **Category:** Code Quality / Testability
- **Current Implementation:**

Multiple systems reach directly into the `GameSession` autoload singleton for cross-system data. For example, in [combat_system.gd:60-65](godot/scripts/systems/combat_system.gd#L60-L65):

```gdscript
static func calculate_damage(attacker_fp: int, defender_armour: int, is_player: bool = false) -> int:
    var effective_fp: float = float(attacker_fp)
    if is_player and GameSession.game_state != null:
        effective_fp *= (1.0 + GameSession.crew_trait_system.get_bonus(GameSession.game_state.player_ship, "firepower_bonus"))
```

Also in [encounter_engine.gd:35-37](godot/scripts/systems/encounter_engine.gd#L35-L37), [economy_system.gd:103-105](godot/scripts/systems/economy_system.gd#L103-L105), [astral_hazard_system.gd:125-127](godot/scripts/systems/astral_hazard_system.gd#L125-L127), and [faction_system.gd:61-63](godot/scripts/systems/faction_system.gd#L61-L63).

- **Proposed Solution:**

Pass dependencies explicitly rather than reaching into the global singleton:

```gdscript
static func calculate_damage(
    attacker_fp: int,
    defender_armour: int,
    crew_trait_system: CrewTraitSystem = null,
    player_ship: Ship = null,
    player_character: Character = null,
) -> int:
    var effective_fp: float = float(attacker_fp)
    if crew_trait_system != null and player_ship != null:
        effective_fp *= (1.0 + crew_trait_system.get_bonus(player_ship, "firepower_bonus"))
```

- **Reasoning:** Static methods accessing global mutable state makes unit testing impossible and creates hidden dependencies. The systems are `RefCounted` objects specifically to be decoupled, but the singleton access undermines this.
- **Expected Benefits:** Testable systems; clearer API contracts; easier to reason about data flow.
- **Trade-offs:** More verbose call sites; requires updating callers.
- **Effort Estimate:** Medium
- **Priority:** Should-fix

---

### Issue #4: DataLoader Cache Never Invalidated

- **Severity:** High
- **Category:** Bug / Performance
- **Current Implementation:**

[data_loader.gd:16-17](godot/scripts/core/data_loader.gd#L16-L17):

```gdscript
func _load_json(relative_path: String) -> Variant:
    if _cache.has(relative_path):
        return _cache[relative_path]
```

The `_cache` dictionary is populated on first load and never cleared. This means:

1. If the same file is loaded multiple times (e.g., `faction_registry.json` is loaded by `load_factions()`, `load_relationship_matrix()`, and `load_cascade_rules()`), it returns the same parsed Dictionary reference.
2. Since Dictionaries are reference types in GDScript, **mutations to loaded data propagate back into the cache**. For example, if `Faction.from_dict()` modifies the input dict, subsequent loads return the mutated version.
3. On `load_game()`, old cached data from the previous session persists.

- **Proposed Solution:**

Return deep copies from the cache, or clear the cache on game start/load:

```gdscript
func _load_json(relative_path: String) -> Variant:
    if _cache.has(relative_path):
        var cached = _cache[relative_path]
        if cached is Dictionary:
            return cached.duplicate(true)
        if cached is Array:
            return cached.duplicate(true)
        return cached

func clear_cache() -> void:
    _cache.clear()
```

- **Reasoning:** Silent cache mutation is a source of hard-to-reproduce bugs, especially across save/load cycles where stale cached data could contaminate a new game.
- **Expected Benefits:** Eliminates an entire class of state corruption bugs.
- **Trade-offs:** Deep copy has a performance cost; alternatively, call `clear_cache()` at appropriate lifecycle points.
- **Effort Estimate:** Small
- **Priority:** Must-fix

---

### Issue #5: Exploration State Not Persisted in Save/Load

- **Severity:** High
- **Category:** Bug
- **Current Implementation:**

`ExplorationSystem` has full `get_state_dict()` and `load_state_dict()` methods ([exploration_system.gd:215-231](godot/scripts/systems/exploration_system.gd#L215-L231)), but `GameStateData` has **no field for exploration state**, and `GameSession.save_game()` / `load_game()` never calls these methods.

This means:

- Region discovery state (`is_discovered`) is lost on save/load
- Point-of-interest visit state (`is_visited`) is lost on save/load
- Players can re-collect POI rewards after reloading

- **Proposed Solution:**

Add exploration state to `GameStateData` and wire it into save/load:

```gdscript
# In GameStateData:
@export var exploration_data: Dictionary = {}

# In GameSession.save_game():
game_state.exploration_data = exploration.get_state_dict()

# In GameSession.load_game():
if not game_state.exploration_data.is_empty():
    exploration.load_state_dict(game_state.exploration_data)
```

- **Reasoning:** Players lose meaningful progress on every save/load cycle. This is a data loss bug.
- **Expected Benefits:** Region and POI discovery properly persists.
- **Trade-offs:** Increases save file size modestly.
- **Effort Estimate:** Small
- **Priority:** Must-fix

---

## Medium Priority Issues

### Issue #6: CrewTraitSystem Iterates All Crew on Every Bonus Lookup

- **Severity:** Medium
- **Category:** Performance
- **Current Implementation:**

[crew_trait_system.gd:45-54](godot/scripts/systems/crew_trait_system.gd#L45-L54):

```gdscript
func get_bonus(ship: Ship, bonus_key: String) -> float:
    var total: float = 0.0
    for c in ship.crew:
        var defn: Dictionary = _crew_definitions.get(c.trait_id, {})
        if defn.is_empty():
            defn = _crew_definitions.get(c.crew_id, {})
        if defn.is_empty():
            continue
        var bonuses: Dictionary = defn.get("trait_bonuses", {})
        total += bonuses.get(bonus_key, 0.0)
    return total
```

This is called multiple times per frame from combat calculations, navigation hazard checks, encounter priority sorting, and economy pricing. Each call iterates all crew members and does two dictionary lookups per member.

- **Proposed Solution:**

Cache computed bonuses and invalidate on crew roster changes:

```gdscript
var _bonus_cache: Dictionary = {}  # ship_id -> {bonus_key -> float}

func invalidate_cache(ship: Ship) -> void:
    _bonus_cache.erase(ship.ship_id)

func get_bonus(ship: Ship, bonus_key: String) -> float:
    if _bonus_cache.has(ship.ship_id):
        return _bonus_cache[ship.ship_id].get(bonus_key, 0.0)
    # Compute all bonuses at once
    var totals := get_all_bonuses(ship)
    _bonus_cache[ship.ship_id] = totals
    return totals.get(bonus_key, 0.0)
```

- **Reasoning:** While the crew roster is typically small (< 10), `get_bonus` is called in hot paths (per-frame combat, per-encounter sorting). Caching eliminates redundant iteration.
- **Expected Benefits:** Reduced per-frame CPU overhead in combat and navigation.
- **Trade-offs:** Must remember to invalidate cache on crew changes.
- **Effort Estimate:** Small
- **Priority:** Should-fix

---

### Issue #7: Dialogue UI Per-Pixel Image Processing on Every Portrait Load

- **Severity:** Medium
- **Category:** Performance
- **Current Implementation:**

[dialogue_ui.gd:503-525](godot/scripts/ui/dialogue_ui.gd#L503-L525):

```gdscript
static func _remove_near_white_bg(
    tex: Texture2D, hard_threshold: float = 0.91, soft_threshold: float = 0.77
) -> Texture2D:
    # ...
    for y in h:
        for x in w:
            var c: Color = image.get_pixel(x, y)
            # Per-pixel alpha computation
```

This runs a per-pixel loop over every portrait image every time a dialogue is opened. For a 256x256 portrait, that's 65,536 iterations of `get_pixel`/`set_pixel` in GDScript — expensive interpreted code.

- **Proposed Solution:**

Cache processed textures by character_id:

```gdscript
static var _portrait_cache: Dictionary = {}  # character_id -> Texture2D

func _load_portrait(...) -> void:
    if _portrait_cache.has(character_id):
        rect.texture = _portrait_cache[character_id]
        return
    # ... load and process ...
    texture = _remove_near_white_bg(texture)
    _portrait_cache[character_id] = texture
    rect.texture = texture
```

Alternatively, pre-process portraits at build time with transparent backgrounds, eliminating the need for runtime processing entirely.

- **Reasoning:** Dialogue opens frequently during gameplay. Each open causes a visible stutter on lower-end hardware due to the GDScript pixel loop.
- **Expected Benefits:** Eliminates portrait-loading stutter after first encounter with each character.
- **Trade-offs:** Trades memory for speed; ~12 portraits cached is negligible.
- **Effort Estimate:** Small
- **Priority:** Should-fix

---

### Issue #8: Combat Victory Loot Uses Magic Numbers Without Data-Driven Config

- **Severity:** Medium
- **Category:** Code Quality
- **Current Implementation:**

[combat_ui.gd:381-384](godot/scripts/ui/combat_ui.gd#L381-L384):

```gdscript
if _result == "victory" and GameSession.game_state:
    var crystal_loot := randi_range(3, 10)
    var salvage_loot := randi_range(5, 15)
    GameSession.game_state.crystal_inventory += crystal_loot
    GameSession.game_state.salvage += salvage_loot
```

Loot ranges are hardcoded in the UI layer. This violates the project's data-driven design principle and means:

- Loot doesn't scale with enemy ship type, region danger level, or arc progression
- Content authors can't tune loot without modifying GDScript

- **Proposed Solution:**

Move loot tables to JSON data and calculate based on enemy context:

```gdscript
# In CombatSystem or EconomySystem:
static func calculate_combat_loot(enemy: CombatShip, danger_level: int) -> Dictionary:
    var base_crystals := enemy.firepower  # Stronger enemies = more loot
    var base_salvage := enemy.armour * 2
    return {
        "crystals": randi_range(base_crystals / 2, base_crystals),
        "salvage": randi_range(base_salvage / 2, base_salvage),
    }
```

- **Reasoning:** All other game content is data-driven; combat loot is an outlier that will cause balance issues.
- **Expected Benefits:** Consistent data-driven design; enables content tuning without code changes.
- **Trade-offs:** Requires defining a loot schema.
- **Effort Estimate:** Small
- **Priority:** Should-fix

---

### Issue #9: `crystal_pickup` Signal Emitted With Inconsistent Argument Counts

- **Severity:** Medium
- **Category:** Bug
- **Current Implementation:**

The `crystal_pickup` signal is defined without parameters in [event_bus.gd:17](godot/scripts/autoload/event_bus.gd#L17):

```gdscript
signal crystal_pickup
```

But emitted with an argument in [combat_ui.gd:385](godot/scripts/ui/combat_ui.gd#L385):

```gdscript
EventBus.crystal_pickup.emit(crystal_loot)
```

And emitted without arguments in [economy_system.gd:30](godot/scripts/systems/economy_system.gd#L30):

```gdscript
EventBus.crystal_pickup.emit()
```

In Godot 4, emitting a signal with more arguments than declared is allowed but any connected callback expecting 0 args will crash when the combat version fires with 1 arg.

- **Proposed Solution:**

Decide on the signal signature and use it consistently:

```gdscript
# In event_bus.gd:
signal crystal_pickup(amount: int)

# In economy_system.gd:
EventBus.crystal_pickup.emit(amount)
```

- **Reasoning:** Inconsistent signal signatures cause runtime crashes when new listeners connect.
- **Expected Benefits:** Type safety; prevents callback arity crashes.
- **Trade-offs:** Need to update all emit/connect call sites.
- **Effort Estimate:** Small
- **Priority:** Must-fix

---

### Issue #10: `_remove_near_white_bg` Measures "Whiteness" Incorrectly

- **Severity:** Medium
- **Category:** Bug
- **Current Implementation:**

[dialogue_ui.gd:518](godot/scripts/ui/dialogue_ui.gd#L518):

```gdscript
var whiteness: float = minf(c.r, minf(c.g, c.b))
```

This uses the **minimum** channel value as "whiteness". A pixel with `(1.0, 0.0, 0.0)` (pure red) has whiteness 0.0 (correct — not white). But `(0.92, 0.92, 0.5)` (yellowish) also has whiteness 0.5 (not removed). Meanwhile, `(0.95, 0.95, 0.95)` (near-white) has whiteness 0.95 (correctly removed).

The issue: this is actually measuring the **minimum channel** not whiteness. For most portrait backgrounds (which tend to be uniformly bright), this works. But for portraits with warm-toned backgrounds (cream, beige), they won't be removed because one channel is lower.

- **Proposed Solution:**

Use luminance or average of channels:

```gdscript
var luminance: float = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
var saturation: float = maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
if luminance >= hard_threshold and saturation < 0.15:
    image.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
```

- **Reasoning:** Using min-channel as whiteness misses near-white colors that aren't perfectly neutral. The saturation check ensures only truly "white-ish" backgrounds are removed.
- **Expected Benefits:** Better background removal for portraits with warm-toned backgrounds.
- **Trade-offs:** Slightly more complex math per pixel (mitigated if portraits are cached per Issue #7).
- **Effort Estimate:** Small
- **Priority:** Nice-to-have

---

### Issue #11: Faction System `get_all_standings` Accesses GameSession Directly

- **Severity:** Medium
- **Category:** Code Quality
- **Current Implementation:**

[faction_system.gd:61-63](godot/scripts/systems/faction_system.gd#L61-L63):

```gdscript
var player_faction: String = GameSession.game_state.player_character.faction_id \
    if GameSession.game_state and GameSession.game_state.player_character \
    else "felid_corsairs"
```

This method already receives `game_state` as a parameter but bypasses it to access `GameSession.game_state` directly. This is inconsistent with the method's own interface.

- **Proposed Solution:**

```gdscript
var player_faction: String = game_state.player_character.faction_id \
    if game_state.player_character else "felid_corsairs"
```

- **Reasoning:** The method already has `game_state` — using the singleton is a copy-paste artifact that undermines the explicit parameter.
- **Expected Benefits:** Consistent API usage; the method signature tells the truth.
- **Trade-offs:** None.
- **Effort Estimate:** Small
- **Priority:** Should-fix

---

### Issue #12: Redundant `_load_json` Calls for Same File in DataLoader

- **Severity:** Medium
- **Category:** Performance / Redundancy
- **Current Implementation:**

In [data_loader.gd](godot/scripts/core/data_loader.gd), three methods load `factions/faction_registry.json` independently:

```gdscript
func load_factions() -> Dictionary:
    var data: Variant = _load_json("factions/faction_registry.json")
    ...

func load_relationship_matrix() -> Dictionary:
    var data: Variant = _load_json("factions/faction_registry.json")
    ...

func load_cascade_rules() -> Array:
    var data: Variant = _load_json("factions/faction_registry.json")
    ...
```

Similarly, `economy/economy_data.json` is loaded by `load_crystal_deposits()`, `load_supply_routes()`, and `load_crystal_market()`. And `ships/ship_templates.json` is loaded by `load_ship_templates()`, `load_upgrades()`, and `load_purchasable_ships()`.

While the cache mitigates the I/O cost, each caller parses the same top-level structure and then picks one key. This pattern also multiplies the cache mutation risk from Issue #4.

- **Proposed Solution:**

Consolidate related loaders into single methods that return structured results:

```gdscript
func load_faction_data() -> Dictionary:
    var data: Variant = _load_json("factions/faction_registry.json")
    if data == null:
        return {"factions": {}, "relationship_matrix": {}, "cascade_rules": []}
    var factions: Dictionary = {}
    for faction_data in data.get("factions", []):
        var faction := Faction.from_dict(faction_data)
        factions[faction.faction_id] = faction
    return {
        "factions": factions,
        "relationship_matrix": data.get("relationship_matrix", {}),
        "cascade_rules": data.get("cascade_rules", []),
    }
```

- **Reasoning:** Reduces redundant code paths and makes it clear that these data are loaded from the same source.
- **Expected Benefits:** Cleaner API; single point of loading reduces mutation risk.
- **Trade-offs:** Changes caller code in `GameSession.create_new_game_state()`.
- **Effort Estimate:** Medium
- **Priority:** Nice-to-have

---

### Issue #13: No Crew Capacity Enforcement on Recruitment

- **Severity:** Medium
- **Category:** Bug
- **Current Implementation:**

[game_session.gd:307-317](godot/scripts/autoload/game_session.gd#L307-L317):

```gdscript
func _on_crew_member_recruited(crew_id: String, _protagonist_id: String) -> void:
    if game_state == null:
        return
    var crew_members: Array = data_loader.load_crew_members()
    for member_data in crew_members:
        if member_data.get("crew_id", "") == crew_id:
            var cm := Ship.CrewMember.from_dict(member_data)
            cm.recruitment_status = "recruited"
            cm.morale = 100
            game_state.player_ship.crew.append(cm)
            break
```

There is no check against `ship.crew_capacity`. Players can recruit unlimited crew members, exceeding the ship's capacity.

- **Proposed Solution:**

```gdscript
func _on_crew_member_recruited(crew_id: String, _protagonist_id: String) -> void:
    if game_state == null:
        return
    if game_state.player_ship.crew.size() >= game_state.player_ship.crew_capacity:
        push_warning("Cannot recruit %s — crew at capacity" % crew_id)
        return
    # ... existing logic ...
```

- **Reasoning:** Ship stats include `crew_capacity` but it's never enforced, making it a dead stat.
- **Expected Benefits:** Crew capacity becomes a meaningful gameplay constraint.
- **Trade-offs:** Need UI feedback when recruitment is blocked.
- **Effort Estimate:** Small
- **Priority:** Should-fix

---

### Issue #14: Save Manager Has No Data Integrity Verification

- **Severity:** Medium
- **Category:** Security / Reliability
- **Current Implementation:**

[save_manager.gd:61-83](godot/scripts/core/save_manager.gd#L61-L83):

```gdscript
func load_game(slot: int) -> GameStateData:
    # ... reads file, parses JSON ...
    data.erase("_meta")
    data = _migrate_save_data(data)
    return GameStateData.from_dict(data)
```

Save files are plain JSON with no checksum or version validation. A corrupted file, a hand-edited cheat, or an interrupted write could produce a partially valid `GameStateData` that silently breaks systems.

- **Proposed Solution:**

Add a checksum field and validate on load:

```gdscript
func save_game(game_state: GameStateData, slot: int) -> bool:
    # ... existing logic ...
    var json_string := JSON.stringify(data, "\t")
    data["_checksum"] = json_string.md5_text()
    # ... write file ...

func load_game(slot: int) -> GameStateData:
    # ... read file ...
    var stored_checksum: String = data.get("_checksum", "")
    data.erase("_checksum")
    data.erase("_meta")
    var computed_checksum: String = JSON.stringify(data, "\t").md5_text()
    if not stored_checksum.is_empty() and stored_checksum != computed_checksum:
        push_warning("Save file checksum mismatch — file may be corrupted")
    # ... continue loading ...
```

- **Reasoning:** A backup `.bak` file exists, but there's no way to know if the primary save is corrupt until `from_dict()` encounters invalid data deep in deserialization.
- **Expected Benefits:** Early detection of corrupted saves; ability to fall back to `.bak`.
- **Trade-offs:** Prevents save file modding (may or may not be desired).
- **Effort Estimate:** Small
- **Priority:** Nice-to-have

---

### Issue #15: `_migrate_save_data` Is a Stub With No Version Tracking

- **Severity:** Medium
- **Category:** Code Quality / Maintainability
- **Current Implementation:**

[save_manager.gd:118-125](godot/scripts/core/save_manager.gd#L118-L125):

```gdscript
func _migrate_save_data(data: Dictionary) -> Dictionary:
    var _version: String = data.get("version", "0.1.0")
    # Add migration steps here as the data format evolves
    return data
```

The version field in `GameStateData` is always `"0.1.0"`. As the game evolves (new fields added to state), old saves will load with missing data, relying on `from_dict` defaults — which works for simple additions but not for schema changes.

- **Proposed Solution:**

Increment version when the schema changes and add migration steps:

```gdscript
const CURRENT_VERSION: String = "0.2.0"

func _migrate_save_data(data: Dictionary) -> Dictionary:
    var version: String = data.get("version", "0.1.0")
    if version == "0.1.0":
        # Example: exploration_data was added in 0.2.0
        if not data.has("exploration_data"):
            data["exploration_data"] = {}
        data["version"] = "0.2.0"
        version = "0.2.0"
    return data
```

- **Reasoning:** Without explicit migration, adding new required fields to GameStateData will silently break old saves.
- **Expected Benefits:** Forward-compatible save files; players don't lose progress on updates.
- **Trade-offs:** Requires discipline to update version on schema changes.
- **Effort Estimate:** Small
- **Priority:** Should-fix

---

## Low Priority / Enhancements

### Issue #16: Encounter Priority Sorting Recalculated on Every Check

- **Severity:** Low
- **Category:** Performance
- **Current Implementation:**

[encounter_engine.gd:31-52](godot/scripts/systems/encounter_engine.gd#L31-L52):

```gdscript
func _get_eligible_encounters(game_state: GameStateData) -> Array:
    var result: Array = []
    var sorted_table := encounter_table.duplicate()
    # ... crew bonus calculations ...
    sorted_table.sort_custom(func(a, b): ...)
```

The entire encounter table is duplicated and re-sorted on every call. With 9 arcs of encounters potentially loaded, this could be 50+ encounters sorted repeatedly.

- **Proposed Solution:**

Pre-sort on load and only re-sort when crew bonuses change:

```gdscript
var _sorted_dirty: bool = true

func load_encounters(arc_id: String, suffix: String = "") -> void:
    encounter_table = data_loader.load_encounters(arc_id, suffix)
    _sorted_dirty = true
```

- **Reasoning:** Encounter checks happen on various triggers during gameplay; pre-sorting reduces per-check overhead.
- **Expected Benefits:** Minor performance improvement for encounter-heavy arcs.
- **Trade-offs:** Must track when bonuses change.
- **Effort Estimate:** Small
- **Priority:** Nice-to-have

---

### Issue #17: `EncounterChoice.conditions` Field Is Loaded But Never Evaluated

- **Severity:** Low
- **Category:** Redundancy
- **Current Implementation:**

[encounter.gd:80](godot/scripts/entities/encounter.gd#L80):

```gdscript
@export var conditions: Dictionary = {}
```

`EncounterChoice` and `DialogueStepChoice` both have a `conditions` field that is deserialized from JSON but never checked before presenting choices to the player. All choices are always shown regardless of conditions.

- **Proposed Solution:**

Either implement condition filtering in the dialogue UI:

```gdscript
# In dialogue_ui.gd when building choices:
for choice in step.choices:
    if not choice.conditions.is_empty():
        if not GameSession.encounter_engine._evaluate_conditions(choice.conditions, GameSession.game_state):
            continue
    # ... show choice button ...
```

Or remove the unused field to reduce confusion.

- **Reasoning:** Content authors may be adding conditions to choices expecting them to filter, but they have no effect.
- **Expected Benefits:** Enables conditional dialogue choices — a major narrative feature.
- **Trade-offs:** Implementing filtering is a feature addition, not just a fix.
- **Effort Estimate:** Small (implement) / Trivial (remove)
- **Priority:** Should-fix

---

### Issue #18: `_process` Runs Continuously in GameSession for Playtime Tracking

- **Severity:** Low
- **Category:** Performance
- **Current Implementation:**

[game_session.gd:65-67](godot/scripts/autoload/game_session.gd#L65-L67):

```gdscript
func _process(delta: float) -> void:
    if game_state != null:
        game_state.playtime_seconds += delta
```

This runs every frame even when the game is on the menu, in settings, or paused. While the cost is negligible (one float addition), the playtime counter includes menu time and pause time.

- **Proposed Solution:**

Only count playtime during active gameplay:

```gdscript
var _counting_playtime: bool = false

func _process(delta: float) -> void:
    if _counting_playtime and game_state != null:
        game_state.playtime_seconds += delta
```

Toggle `_counting_playtime` based on game state transitions.

- **Reasoning:** Players may care about accurate playtime; including pause/menu time inflates it.
- **Expected Benefits:** More accurate playtime reporting.
- **Trade-offs:** Need to define what counts as "active" gameplay.
- **Effort Estimate:** Small
- **Priority:** Nice-to-have

---

## Quick Wins

High-impact, low-effort improvements:

1. **Issue #9** — Fix `crystal_pickup` signal signature inconsistency (prevents runtime crashes)
2. **Issue #11** — Use `game_state` parameter instead of `GameSession.game_state` in `get_all_standings` (1-line fix)
3. **Issue #2** — Add hull-death check to `AstralHazardSystem.apply_damage` (3-line fix)
4. **Issue #13** — Add crew capacity check to recruitment handler (3-line fix)
5. **Issue #5** — Wire exploration state into save/load (6-line fix)

---

## Long-term Improvements

Items for technical roadmap:

1. **Issue #3** — Dependency injection for system classes: replace `GameSession` singleton access with explicit parameters across all systems. This is a larger refactor but dramatically improves testability.
2. **Issue #4 + #12** — DataLoader overhaul: deep-copy cache returns, consolidate multi-access loaders, add `clear_cache()` lifecycle hook.
3. **Issue #17** — Implement conditional choice filtering: this unlocks a major narrative feature (stat-gated dialogue options, faction-locked choices) that the data schema already supports.
4. **Issue #7** — Pre-process portrait assets at build time with transparent backgrounds, eliminating runtime pixel processing entirely.

---

## Positive Findings

Highlight well-implemented patterns and good practices:

- **Data-driven architecture**: All narrative, encounter, faction, ship, and economy content lives in JSON files. No hardcoded game content in GDScript. This is exemplary for a narrative-heavy game.
- **EventBus pattern**: 120+ typed signals with clear categorization. Systems communicate through events rather than direct calls, enabling loose coupling.
- **Consistent serialization**: Every entity class implements `to_dict()` / `from_dict()` with sensible defaults, enabling robust save/load.
- **Atomic save writes**: `SaveManager` writes to `.tmp` then renames, with `.bak` backup — a production-quality save pattern.
- **Scene overlay stack**: `main.gd`'s push/pop/replace overlay system is clean and handles edge cases (duplicate prevention, stale instance cleanup, music state restoration).
- **Dialogue UI**: The multi-step dialogue system with portrait switching, typewriter reveal, reading pause, and branch navigation is well-engineered. The `MAX_STEPS` guard prevents infinite dialogue loops.
- **Star map fog system**: Cell-based fog of war with efficient `PackedByteArray` storage and base64 serialization is a good technical choice.
- **Karma integration**: The karma system cleanly modifies economy pricing and NPC disposition without coupling to specific systems.
- **Hyperspace shader**: The `hyperspace_jump.gdshader` is a polished multi-phase visual effect (star stretch → tunnel → flash → fade).

---

## Recommendations Summary

| Issue ID | Title | Severity | Effort | Priority | Category |
| ---------- | ------- | ---------- | -------- | ---------- | ---------- |
| #1 | Encounter chain triggers can infinite loop | Critical | Small | Must-fix | Bug |
| #2 | No game-over on hazard hull destruction | Critical | Small | Must-fix | Bug |
| #3 | Tight coupling to GameSession singleton | High | Medium | Should-fix | Code Quality |
| #4 | DataLoader cache never invalidated | High | Small | Must-fix | Bug |
| #5 | Exploration state not persisted in save/load | High | Small | Must-fix | Bug |
| #6 | CrewTraitSystem iterates all crew per lookup | Medium | Small | Should-fix | Performance |
| #7 | Per-pixel image processing on every portrait load | Medium | Small | Should-fix | Performance |
| #8 | Combat loot uses hardcoded magic numbers | Medium | Small | Should-fix | Code Quality |
| #9 | `crystal_pickup` signal arity mismatch | Medium | Small | Must-fix | Bug |
| #10 | `_remove_near_white_bg` whiteness metric | Medium | Small | Nice-to-have | Bug |
| #11 | `get_all_standings` bypasses its own parameter | Medium | Small | Should-fix | Code Quality |
| #12 | Redundant `_load_json` calls for same file | Medium | Medium | Nice-to-have | Redundancy |
| #13 | No crew capacity enforcement on recruitment | Medium | Small | Should-fix | Bug |
| #14 | Save manager has no integrity verification | Medium | Small | Nice-to-have | Reliability |
| #15 | `_migrate_save_data` is a stub | Medium | Small | Should-fix | Maintainability |
| #16 | Encounter priority re-sorted on every check | Low | Small | Nice-to-have | Performance |
| #17 | Choice `conditions` field loaded but never evaluated | Low | Small | Should-fix | Redundancy |
| #18 | Playtime includes menu/pause time | Low | Small | Nice-to-have | Code Quality |

---

## Next Steps

1. **Immediate** — Fix Issues #1, #2, #4, #5, #9 (all small effort, must-fix bugs that affect game correctness)
2. **Sprint 1** — Address Issues #3, #6, #7, #8, #11, #13, #15, #17 (should-fix items that improve code quality and prevent future bugs)
3. **Roadmap** — Plan Issue #3 (dependency injection refactor) and Issue #17 (conditional choices) as feature work for the next milestone

---

## Review Sign-off

- **Reviewed by:** Claude Opus 4.6 (AI-assisted)
- **Date:** 2026-04-05
- **Approved for implementation:** [x] Partial
- **Follow-up review needed:** [x] Yes — after must-fix issues are resolved
- **Notes:** The codebase is in good health overall. The architecture is sound and follows the project's own conventions well. The critical issues are localized and straightforward to fix. The data-driven design is a major strength that will pay dividends as content scales.
