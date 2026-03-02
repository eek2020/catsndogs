# Code Review — Whisper Crystals

**Date:** 2026-03-02
**Reviewer:** Cascade (AI pair programmer)
**Scope:** Full codebase review — `src/whisper_crystals/`, `tests/`, `data/`, engine, and project config

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture & Patterns](#2-architecture--patterns)
3. [Code Quality & Redundancy](#3-code-quality--redundancy)
4. [Bugs & Edge Cases](#4-bugs--edge-cases)
5. [Error Handling](#5-error-handling)
6. [Performance](#6-performance)
7. [Readability & Maintainability](#7-readability--maintainability)
8. [Security Considerations](#8-security-considerations)
9. [Test Coverage](#9-test-coverage)
10. [Summary & Recommendations](#10-summary--recommendations)

---

## 1. Project Overview

Whisper Crystals is a narrative-driven 2D space game built with Pygame. The player commands Captain Aristotle — a cat turned corsair — flying between realms, trading whisper crystals, resolving encounters, and navigating faction politics across a four-arc story.

### Tech Stack

- **Language:** Python 3.10+ (type hints, `from __future__ import annotations`)
- **Engine:** Pygame (Phase 1), designed for Godot/Unity migration (Phase 2)
- **Testing:** pytest
- **Data:** JSON files under `data/`
- **Logging:** Python `logging` with `RotatingFileHandler`

### Module Structure

| Layer | Path | Purpose |
|-------|------|---------|
| **Core** | `core/` | Config, data loader, event bus, game state, interfaces, session, state machine, save manager, logger |
| **Engine** | `engine/` | Pygame renderer, audio, camera, input, starfield, image utils, startup |
| **Entities** | `entities/` | Data models: Character, Ship, Faction, Encounter, Crystal, SideMission |
| **Systems** | `systems/` | Game logic: combat, economy, encounter engine, narrative, crew morale, exploration, faction conquest, realm control |
| **UI** | `ui/` | Game states: menu, navigation, pause, combat, dialogue, cutscene, trade, purchase, ship, faction, settings, ending, HUD |
| **Tests** | `tests/` | 11 test files covering systems, entities, economy, serialization, settings, exploration, crew morale, faction conquest, dialogue format |

---

## 2. Architecture & Patterns

### Strengths

- **Engine Abstraction Layer (EAL):** `core/interfaces.py` defines `RenderInterface`, `InputInterface`, and `AudioInterface` as ABCs. Core game logic is engine-agnostic — only `engine/` contains Pygame imports. This is excellent forward planning for Phase 2 migration.
- **Stack-based state machine:** `GameStateMachine` with push/pop/switch cleanly manages overlays (pause, trade, settings) and state transitions (menu → cutscene → navigation).
- **Event bus:** `EventBus` provides loose coupling between systems. Faction score changes, trade events, and combat outcomes propagate without direct dependencies.
- **Serialization consistency:** Every entity has `to_dict()` / `from_dict()` round-trip methods. `GameStateData` serializes the entire game state to JSON.
- **Data-driven design:** Encounters, factions, ships, and economy all load from JSON, making content extensible without code changes.

### Concerns

- **God object tendency in `GameSession`** (`core/session.py`, 480 lines): This class wires every system, handles all state transitions, and contains callback closures for combat/dialogue/arc flow. It should be decomposed:
  - Extract a `StateTransitionManager` for screen push/pop/switch callbacks.
  - Extract a `CombatFlowController` for `_on_combat_from_encounter` and its nested closures.
  - Extract a `LoadFlowController` for `_open_load_from_menu` / `_open_load_from_pause`.

- **Circular-feeling imports in `economy.py`:** `purchase_upgrade()` (line 418) and `purchase_ship()` (line 496) import `DataLoader` locally and instantiate **new** `DataLoader()` with default `data_root="data"` — bypassing the session's configured data loader. This creates a **shadow data loader** with a different root path.

- **Missing unsubscribe discipline:** Subscribers are added to `EventBus` in `GameSession.__init__` but never removed. If `_quit_to_menu` is called and a new session is conceptually started, stale handlers accumulate.

---

## 3. Code Quality & Redundancy

### Redundant Patterns

1. **Duplicate morale status logic** — `get_morale_status()` and `get_crew_by_morale()` in `crew_morale.py` both independently map morale values to status strings ("MUTINY", "DISGRUNTLED", etc.) using identical threshold logic. Extract a `_morale_label(value: int) -> str` helper.

2. **Duplicate encounter sorting** — `check_triggers()` and `get_available_encounters()` in `encounter_engine.py` both do `sorted(self.encounter_table, key=lambda e: -e.priority)` and nearly identical filter logic. The second method is a superset of the first; `check_triggers` could call `get_available_encounters` and return the first result.

3. **Repeated `DataLoader` instantiation** — `economy.py` lines 418-420 and 496-498 create throwaway `DataLoader()` instances instead of receiving one via dependency injection.

4. **Repeated diplomatic state derivation** — The threshold boundaries for `DiplomaticState` are defined in `Faction.update_diplomatic_state()` (faction.py) as code, not constants. If these ever change, the test expectations in `test_entities.py` would silently break.

### Style Issues

- **Import placement:** `__main__.py` line 40 imports `setup_logging` between function definitions — should be at the top.
- **`hud.py` line 89:** `import math` inside a method body. Should be at the module top level.
- **`menu.py` line 26:** Type annotation `EventBus | None = None` references `EventBus` but it's never imported — this will raise `NameError` at runtime if Python resolves the annotation eagerly. Since the file uses `from __future__ import annotations`, this is safe **only** at annotation evaluation time, but a reader (or a tool doing runtime introspection) would be confused. Should add a `TYPE_CHECKING` import.
- **`session.py` line 168:** `callable` (lowercase) is used as a type hint instead of `Callable` from `typing`. While technically valid in Python 3.9+, `Callable` is more conventional and precise.

---

## 4. Bugs & Edge Cases

### BUG-1: Shadow DataLoader in Economy (Severity: High)

**File:** `src/whisper_crystals/systems/economy.py` lines 418-420, 496-498

```python
from whisper_crystals.core.data_loader import DataLoader
data_loader = DataLoader()  # Uses default data_root="data" (relative!)
upgrades = data_loader.load_upgrades()
```

This creates a new `DataLoader` with the default relative path `"data"`, which will fail unless the process CWD happens to be the project root. The session already has a properly configured `DataLoader` but it's not passed to `EconomySystem`.

**Fix:** Inject the `DataLoader` into `EconomySystem.__init__()` and use it for `purchase_upgrade()` and `purchase_ship()`.

### BUG-2: `completed_encounters` Grows Unboundedly (Severity: Medium)

**File:** `src/whisper_crystals/systems/encounter_engine.py` line 123

```python
game_state.completed_encounters.append(encounter.encounter_id)
```

Repeatable encounters are excluded from triggers via `if not encounter.repeatable`, but the ID is still appended every time. For repeatable encounters, this list grows with every resolution. Over a long playthrough this wastes memory and slows `in` checks (it's a list, not a set).

**Fix:** Use a `set` for `completed_encounters`, or guard the append: `if encounter.encounter_id not in game_state.completed_encounters`.

### BUG-3: `morale_modifier` Applied on Every Delta (Severity: Medium)

**File:** `src/whisper_crystals/systems/crew_morale.py` line 99

```python
member.morale = max(0, min(100, member.morale + delta + member.morale_modifier))
```

The `morale_modifier` is a permanent trait on `CrewMember`, but it's added on **every call** to `change_crew_morale`. If `on_idle_tick` is called 60 times per second, a crew member with `morale_modifier=1` gains +60 morale per second on top of the delta. This should either:
- Apply `morale_modifier` only once during initialization, or
- Scale it by time (`delta * dt`), or
- Only apply it during specific events.

### BUG-4: `_quit_to_menu` Calls `enter()` on Stale States (Severity: Low)

**File:** `src/whisper_crystals/core/session.py` lines 472-476

```python
while not self.state_machine.is_empty:
    self.state_machine.pop()
```

`GameStateMachine.pop()` calls `exit()` on the top state and `enter()` on the state below. When clearing the entire stack, each intermediate state gets an `enter()` then immediately an `exit()`. This is wasteful and could trigger side effects (e.g., rebuilding menu options, loading data). Consider adding a `clear()` method to `GameStateMachine`.

### BUG-5: Arc Title Text Centering (Severity: Low)

**File:** `src/whisper_crystals/ui/hud.py` line 60

```python
renderer.draw_text(arc_text, (sw // 2 - len(arc_text) * 5, y+1), ...)
```

Text centering is estimated as `len(text) * 5` pixels, but actual font width varies per character and font size. Use `renderer.measure_text(arc_text, 20)` for accurate centering.

### BUG-6: Missing `EventBus` Import in `menu.py` (Severity: Low)

**File:** `src/whisper_crystals/ui/menu.py` line 26

```python
event_bus: EventBus | None = None,
```

`EventBus` is referenced in the type annotation but never imported. This works because `from __future__ import annotations` defers evaluation, but it will break if anyone tries to use `typing.get_type_hints()` on this class.

### Edge Cases

- **Empty crew list:** `get_average_morale()` correctly returns 100 for empty crews, but `get_crew_by_morale()` returns an empty list — no status is derivable. UI code should handle this.
- **Zero-hull ships:** `calculate_repair_cost` divides by `ship.max_hull` in the formula (`repair_amount / ship.max_hull`). If `max_hull` is 0, this divides by zero. Guard needed.
- **Supply modifier drift:** `update_faction_economics()` only increases `supply_modifier` but never decreases it (except indirectly through demand). Over time it'll hit the cap of 2.0 and stay there permanently.
- **Sell price floor:** `get_sell_price` returns `max(1, int(buy_total * 0.75))`. If `buy_total` is 0 (faction not found), sell price is 1 instead of 0, letting the player sell for free salvage.

---

## 5. Error Handling

### Strengths

- **DataLoader** handles `FileNotFoundError` and `JSONDecodeError` with logging.
- **SaveManager** uses atomic writes (`.tmp` + `os.replace`) — excellent crash safety.
- **SaveManager.load_game** catches `OSError`, `JSONDecodeError`, `KeyError`, `TypeError` — robust against corruption.
- **Audio** gracefully handles missing files and uninitialized mixer.

### Gaps

- **No validation on loaded data:** `DataLoader` parses JSON but doesn't validate schemas. A malformed `faction_registry.json` (e.g., missing `faction_id` key) will raise a `KeyError` deep in `Faction.from_dict()` with no context about which file or entry failed.
- **EventBus swallows nothing:** If a subscriber raises an exception, `publish()` crashes the entire event chain. Other subscribers for the same event are never called. Consider wrapping callbacks in try/except with logging.
- **`encounter_engine.apply_choice_outcome`:** No bounds checking on `choice_index`. If passed an out-of-range index, it raises `IndexError` with no game-specific context.
- **`CombatShip.from_template`:** If `template` is an empty dict (bad data), all stats default to 5 silently. This may mask data loading issues.

---

## 6. Performance

### Hot Path Concerns

1. **`image_utils.remove_near_white_bg`** — Iterates every pixel with `get_at`/`set_at` (Python-level per-pixel loop). For a 1024×1024 image that's ~1M iterations in pure Python. This should use `pygame.surfarray` or `PixelArray` for batch processing. Currently only called at startup so impact is limited, but it can cause noticeable load times for large artwork.

2. **`Starfield.draw`** — Iterates 200 stars per frame with per-star math and `draw_circle` calls. At 60 FPS this is 12,000 draw calls per second just for stars. Consider batching into a pre-rendered surface that only updates when the camera moves significantly.

3. **`renderer.draw_nebula`** — Creates a cached texture but calls `pygame.transform.rotate` every frame (line 182). Rotation is CPU-intensive. Cache rotated versions at discrete angle intervals (e.g., every 5°).

4. **`completed_encounters` as a list:** Used with `in` operator for membership testing (O(n)). Should be a `set` for O(1) lookups.

5. **`draw_rect` with alpha** — Creates a new `pygame.Surface` every call for alpha rectangles. HUD draws multiple alpha rects per frame. Cache or reuse surfaces.

### Memory

- **`_glow_cache` in renderer** grows unboundedly. Add an eviction strategy or cap.
- **`CombatLog`** correctly caps at 8 entries — good.
- **`trade_ledger`** in `GameStateData` is an unbounded list. For long playthroughs, consider capping or archiving.

---

## 7. Readability & Maintainability

### Strengths

- **Consistent naming:** snake_case throughout, clear class names, descriptive method names.
- **Docstrings:** Most public methods and classes have docstrings. Module-level docstrings explain purpose.
- **Type hints:** Comprehensive use of `from __future__ import annotations` and modern union syntax (`str | None`).
- **`TYPE_CHECKING` guards:** Used correctly in most files to avoid circular imports.
- **Dataclass usage:** Entities use `@dataclass` consistently with sensible defaults.
- **Separation of concerns:** UI states don't contain business logic; systems don't import pygame.

### Concerns

- **`session.py` complexity:** 480 lines with deeply nested closures (`on_victory`, `on_defeat`, `on_flee` inside `_on_combat_from_encounter`). These closures capture `self` and local variables, making the control flow hard to trace.
- **Magic numbers:** Colors, sizes, and positions are hardcoded throughout UI files (e.g., `(15, 12, 25, 200)` in `hud.py`). Extract into a theme/constants module.
- **Navigation state** (`navigation.py`, 444 lines) handles movement, rendering, encounter checks, POI generation, sprite loading, and particle effects. Consider splitting rendering into a separate `NavigationRenderer`.
- **Side mission entity** (`side_mission.py`) is defined but never referenced in any system or test. It appears to be planned but unintegrated.

---

## 8. Security Considerations

### Save File Integrity

- Save files are plain JSON with no integrity check. A player (or malicious actor in a multiplayer future) could edit save files to give themselves unlimited resources.
- **Recommendation:** Add a checksum or HMAC to save metadata for tamper detection.

### Settings Path Traversal

- Settings are saved to `~/.whisper_crystals/settings.json`. The path is hardcoded and not user-controllable, so path traversal is not a risk currently.

### Data File Trust

- All data files under `data/` are loaded without schema validation. If the game distribution is tampered with, malicious JSON could cause unexpected behavior. For a single-player game this is low risk, but worth noting.

### Arbitrary `setattr` in Economy

**File:** `src/whisper_crystals/systems/economy.py` lines 457, 463

```python
setattr(ship.base_stats, upgrade.target_stat, current_stat + upgrade.modifier)
```

`target_stat` comes from JSON data. If a modder or corrupted data file sets `target_stat` to an unexpected attribute name, this could overwrite unrelated state. Validate `target_stat` against a whitelist of `ShipStats` field names.

---

## 9. Test Coverage

### Coverage Summary

| Test File | Systems Covered | Verdict |
|-----------|----------------|---------|
| `test_systems.py` | EncounterEngine, NarrativeSystem, FactionSystem, Combat, full arc integration | Good |
| `test_entities.py` | Character, Ship, Faction, Encounter, CrystalMarket serialization | Good |
| `test_data_loader.py` | DataLoader, create_new_game_state | Good |
| `test_economy.py` | EconomySystem (extraction, routes, trade, repair, serialization) | Excellent |
| `test_save_manager.py` | SaveManager (save, load, delete, corruption) | Good |
| `test_settings.py` | Settings load/save, defaults, corruption | Good |
| `test_crew_morale.py` | CrewMoraleSystem (queries, changes, combat modifiers, faction loyalty) | Excellent |
| `test_exploration.py` | ExplorationSystem (regions, travel, POIs, events, scanning) | Excellent |
| `test_faction_conquest.py` | FactionConquestAI, RealmControlSystem | Excellent |
| `test_game_state_serialization.py` | GameStateData round-trip, JSON compatibility | Good |
| `test_dialogue_format.py` | Dialogue JSON schema validation | Good |

### Gaps

- **No UI tests:** None of the `GameState` subclasses (MenuState, NavigationState, CombatState, etc.) have tests. Even without rendering, `handle_input()` and `update()` logic could be tested with mock renderers.
- **No `purchase_upgrade` / `purchase_ship` tests:** These methods in `EconomySystem` are untested and contain the shadow DataLoader bug.
- **No `SideMission` tests:** The entity exists but has no test coverage and no integration.
- **No EventBus error resilience tests:** No tests verify behavior when subscribers throw exceptions.
- **No `GameSession` integration tests:** The orchestration layer that wires everything together is untested.

---

## 10. Summary & Recommendations

### Critical (Fix Now)

| # | Issue | File | Lines |
|---|-------|------|-------|
| BUG-1 | Shadow DataLoader in `purchase_upgrade`/`purchase_ship` — will fail at runtime with wrong CWD | `economy.py` | 418-420, 496-498 |
| BUG-3 | `morale_modifier` applied on every morale change call, causing runaway morale drift | `crew_morale.py` | 99 |

### Important (Fix Soon)

| # | Issue | File | Lines |
|---|-------|------|-------|
| BUG-2 | `completed_encounters` grows unboundedly for repeatable encounters; should be a set | `encounter_engine.py` | 123 |
| BUG-6 | Missing `EventBus` import in `menu.py` — fragile under runtime introspection | `menu.py` | 26 |
| ARCH-1 | `GameSession` is a god object — decompose into transition/flow controllers | `session.py` | — |
| PERF-1 | `image_utils.remove_near_white_bg` uses per-pixel Python loop | `image_utils.py` | 33-53 |

### Recommended Improvements

| # | Area | Recommendation |
|---|------|---------------|
| R-1 | Redundancy | Extract `_morale_label(value)` helper in `crew_morale.py` |
| R-2 | Redundancy | Deduplicate encounter sorting/filtering in `encounter_engine.py` |
| R-3 | Robustness | Add `clear()` method to `GameStateMachine` to avoid enter/exit churn |
| R-4 | Robustness | Wrap `EventBus.publish` callbacks in try/except with logging |
| R-5 | Robustness | Validate `target_stat` against `ShipStats` fields before `setattr` |
| R-6 | Performance | Cache rotated nebula at discrete angles in `renderer.py` |
| R-7 | Performance | Pre-render starfield to a surface; refresh only on significant camera movement |
| R-8 | Performance | Convert `completed_encounters` from `list` to `set` |
| R-9 | Maintainability | Extract UI color/size constants into a `theme.py` module |
| R-10 | Maintainability | Integrate or remove the unused `SideMission` entity |
| R-11 | Testing | Add unit tests for `purchase_upgrade`, `purchase_ship`, and UI state handlers |
| R-12 | Testing | Add `GameSession` integration test with mock renderer/input |
| R-13 | Style | Move stray imports to top of file (`__main__.py:40`, `hud.py:89`) |
| R-14 | Data | Add JSON schema validation in `DataLoader` for better error messages |

### Overall Assessment

The codebase is well-structured with strong architectural foundations — the engine abstraction layer, event bus, and data-driven design are all excellent choices. Serialization is thorough and well-tested. The main areas needing attention are: the shadow DataLoader bug in economy (runtime failure risk), the god-object tendency in `GameSession`, and the lack of UI and integration tests. Code style is clean and consistent. With the critical bugs fixed and the recommended decomposition of `GameSession`, this codebase is in solid shape for continued development.

---

*Review generated by Cascade — 2026-03-02*
