# Whisper Crystals — Master Plan

**Date:** 2026-04-16 (post-Sprint 5b)
**Status:** Authoritative — single source of truth for project planning
**Supersedes:** `docs/archive/plans/MASTER_PLAN_2026-03-20.md`, `MASTER_PLAN_2026-04-05.md`, all previous plan documents

---

## 1. Game Overview

**Genre:** Narrative-driven 2D side-scrolling space pirate game
**Engine:** Godot 4.6 (GL Compatibility renderer), GDScript
**Resolution:** 1280x720, canvas_items stretch mode
**Target:** Desktop (Mac M3/M4 primary, Windows compatible)

**Core Loop:** Explore regions > trigger encounters > make branching choices > fight/trade/negotiate > manage ship and crew > progress through story arcs toward one of three endings.

**Design Pillars:**

- Player agency through consequential choices (karma, faction reputation, story flags)
- Data-driven content (all narrative, encounters, and game data in JSON)
- Decoupled systems communicating through EventBus signals
- Dual protagonist paths offering meaningfully different experiences

---

## 2. Current State (as implemented)

### What Is Built and Playable

| Area | Status | Details |
| ------ | -------- | --------- |
| Dual Protagonist System | Complete | Aristotle (cat) or Dave (dog) with separate encounters, dialogue, side missions, and endings |
| Story — Arcs 1-4 | Complete | Full encounter data, dialogue, arc transition logic, 3 endings (Hold/Share/Destroy) |
| Story — Arcs 5-10 | Data exists | JSON encounter/side mission data for 10 arcs. Not integration-tested or polished |
| Navigation | Complete | WASD ship movement, procedural starfield, animated ship, fog of war, POI system |
| Combat System | Complete | Turn-based with damage formula, dodge, crew trait bonuses, ship sprites |
| Dialogue System | Complete | Branching multi-step dialogue with dual portraits, typewriter reveal |
| Trade System | Complete | Faction-aware crystal pricing with karma modifier |
| Economy System | Complete | Crystal extraction, supply routes, market, repair, upgrades, ship purchase |
| Exploration System | Complete | Region discovery, POI scanning, travel validation, exploration events |
| Faction System | Complete | 8 factions, reputation -100/+100, diplomatic states, cascade rules |
| Faction Conquest AI | Complete | Background warfare, territory control, power rankings |
| Realm Control | Complete | Region ownership, influence drift, contested status |
| Crew Recruitment | Complete | 8 crew members (4 per protagonist), trait bonuses, recruitment missions |
| Crew Morale | Complete | Morale tracking, mutiny risk, combat/trade modifiers |
| Side Missions | Complete | Mission lifecycle, distress signals, mission log UI |
| Star Map (Celestial Codex) | Complete | 3-layer map (galaxy/region/local), fog of war, purchasable maps, fairy cartographer |
| Astral Hazard System | Complete | Static/dynamic hazards, crew mitigation, status effects, hull damage |
| Karma System | Complete | -100/+100 karma, tier-based pricing/NPC disposition |
| Skill Allocation | Complete | Starting stat redistribution with preset archetypes, resonance shards |
| Planet System | Complete | Landing/departure, biome-based surfaces, merchants, treasures |
| Star Base System | Complete | 3 base variants, proximity docking, reputation gating, artifact purchase |
| 2D World Layer | Complete | TileMap outpost (Fringe Haven), player CharacterBody2D, NPC patrol AI, tavern interior, scene transitions |
| Save/Load | Complete | 3-slot atomic saves with version migration framework |
| Music & Audio | Complete | Dynamic BGM per state, arc-specific themes, SFX triggers |
| UI Theme | Complete | Unified dark space-pirate theme (ThemeBuilder) |
| Intro Crawl | Complete | Star Wars perspective-scroll with music sync |
| Arc Summary | Complete | Between-arc stats + hyperspace jump shader |

### Autoloads (4 singletons)

| Singleton | Role |
| ------ | ------ |
| EventBus | 70 pub/sub signals for decoupled communication |
| GameSession | Master orchestrator — owns all 22 systems and game state |
| MusicManager | Dynamic BGM, SFX, arc-specific themes |
| ProceduralMapManager | Procedural navigation/star map backdrops |

### Codebase Metrics

_Measured 2026-04-16 after Sprint 5b. GUT suite 121/121 green._

| Metric | Count |
| ------ | ------- |
| GDScript files | 81 (was ~60 pre-refactors) |
| Scene files (.tscn) | ~30 |
| Entity classes | 8 |
| Game systems | 22 |
| UI screens | 22 (includes decomposed helpers under `scripts/ui/{star_map,combat,view_models}/`) |
| JSON data files | 83 |
| EventBus signals | 70 (previous "120+" count was stale; audited 2026-04-16 — see CODE_REVIEW §2.4) |
| `GameSession.` refs (total) | 131 (was 236; UI 106 + rest 25) |
| `GameSession.` refs (`scripts/ui/`) | 106 (was 206) |
| Unit tests | 121 across 14 files |
| SpriteFrames resources | 16 |
| Shaders | 2 |
| Addons | 2 (procedural_world_map, gut) |

---

## 3. Architecture Summary

See `STRUCTURE.md` for the full signal map, system table, and scene inventory.

**Key patterns:**

- **Systems** are `RefCounted` objects owned by `GameSession` (no scene-tree presence)
- **Entities** are `Resource` subclasses with full `to_dict()`/`from_dict()` serialization
- **UI screens** reach `GameSession` only through a narrow per-screen **ViewModel** under `scripts/ui/view_models/` (`NavigationViewModel`, `CombatViewModel`, `StarMapViewModel` as of Sprint 5a). The VM is injected via `initialize(vm)` with a `_ready` fallback to the autoload. Screens yet to be converted still read `GameSession` directly; coupling budget is tracked in the metrics table above.
- **All inter-system communication** goes through `EventBus` signals
- **All narrative/game content** lives in JSON under `godot/data/` — never hardcoded in scripts

**Data flow:** User input > UI controller > GameSession system method > GameStateData mutation > EventBus signal > UI/system reactions

---

## 4. Quality Policy: Test Before Review

All code review activities **must include runtime testing**, not just static code analysis. Reviews that only read source code miss runtime bugs, integration failures, and data-driven content issues.

**Mandatory review process:**

1. **Static analysis** — Read code, check patterns, identify structural issues
2. **Runtime testing** — Run the game in Godot editor; exercise affected systems manually
3. **Automated tests** — Run `GUT` test suite (once established); all tests must pass before review sign-off
4. **Data validation** — For content-facing changes, verify JSON data loads correctly and encounters play through
5. **Regression check** — Save/load round-trip, arc transitions, combat flow, dialogue branching

This policy applies to all future code reviews and to the remediation work below.

---

## 5. Consolidated Issue Tracker (All Code Reviews)

Three code reviews have been conducted. This section is the **single source of truth** for all open issues.

**Review documents:**

- `docs/reviews/CODE_REVIEW_2026-03-27.md` — 16 categories, first Godot review
- `docs/reviews/CODE_REVIEW_2026-04-05.md` — 18 issues, second review
- `docs/reviews/CODE_REVIEW_2026-04-07.md` — 22 issues, third review (18 implemented)

### 5.1 Resolved Issues

These have been implemented and tested as part of the April 7 review remediation:

| Source | ID | Issue | Resolution | Files Changed |
| ------ | -- | ----- | ---------- | ------------- |
| Apr-07 | #1 | Exploration state not persisted | `exploration_data` added to save/load | `game_state_data.gd`, `game_session.gd` |
| Apr-05 | #5 | Exploration state not persisted | Same as above | Same |
| Apr-07 | #2 | Duplicated condition evaluation | Created `ConditionEvaluator` class | `condition_evaluator.gd`, `encounter_engine.gd`, `side_mission_system.gd` |
| Mar-27 | §1.1 | Duplicated condition evaluation | Same as above | Same |
| Apr-07 | #3 | Inconsistent indentation (cutscene) | Converted to tabs | `cutscene_manager.gd`, `dialogue_ui.gd` (cutscene), `cutscene_scene.gd` |
| Apr-07 | #4 | Python docstrings in GDScript | Replaced with `##` | `data_loader.gd`, `economy_system.gd`, `dialogue_ui.gd` |
| Apr-07 | #5 | Systems coupled to GameSession | Decoupled via parameter injection | `combat_system.gd`, `economy_system.gd`, `astral_hazard_system.gd` |
| Apr-05 | #3 | Systems coupled to GameSession | Partially same — 3 of ~6 systems done | See §5.2 for remainder |
| Apr-07 | #6 | Duplicated init in start/load | Extracted `_init_systems()` | `game_session.gd` |
| Apr-07 | #7 | Unused GameStateMachine | Marked `@deprecated` | `state_machine.gd` |
| Apr-07 | #8 | Design resolution mismatch | Uses `Config.SCREEN_WIDTH/HEIGHT` | `combat_ui.gd` / `combat_layout.gd` |
| Apr-07 | #9 | Config class too thin | Expanded with game constants | `config.gd` |
| Apr-05 | #8 | Combat loot magic numbers | Partially — Config now has combat constants | `config.gd`, `combat_system.gd` |
| Mar-27 | §13 | Magic numbers in combat/economy | Partially — Config expanded | `config.gd` |
| Apr-07 | #10 | Repeated weighted-random | Created `MathUtils.weighted_pick()` | `math_utils.gd`, `side_mission_system.gd`, `astral_hazard_system.gd`, `exploration_system.gd` |
| Apr-07 | #11 | @onready misuse in MusicManager | Moved `.new()` to `_ready()` | `music_manager.gd` |
| Apr-07 | #12 | Missing @warning_ignore EventBus | File-level annotation | `event_bus.gd` |
| Apr-07 | #13 | StatEvaluator match fragility | Property access via `get()`/`set()` | `stat_evaluator.gd` |
| Apr-07 | #14 | Two dialogue_ui files | Renamed to `CutsceneDialogueUI` | `cutscene/dialogue_ui.gd`, `cutscene_scene.gd`, `cutscene_manager.gd` |
| Apr-07 | #15 | No audio bus separation | Created Music/SFX buses | `default_bus_layout.tres`, `music_manager.gd` |
| Apr-07 | #16 | Save file integrity check | SHA-256 checksum | `save_manager.gd` |
| Apr-05 | #14 | Save manager no integrity check | Same as above | Same |
| Apr-07 | #17 | Faction reputation bypasses system | Delegated to `FactionSystem` | `encounter_engine.gd` |
| Apr-05 | #11 | faction_system bypasses parameter | Partially same | `encounter_engine.gd` |
| Apr-07 | #21 | _process always active | `set_process` toggling | `game_session.gd` |
| Apr-05 | #18 | Playtime includes menu/pause | Same as above | Same |
| Mar-27 | §8 | star_map queue_redraw every frame | Already has REDRAW_INTERVAL throttle | `star_map_screen.gd` |
| Mar-27 | §12 | No save backup rotation | `save_manager.gd` already does `.bak` | Already implemented |
| Apr-05 | #1 | `trigger_encounter_id` never evaluated | Dead field removed from `EncounterOutcome` | `encounter.gd` |
| Apr-05 | #2 | Hull death not emitted from hazard damage | `apply_damage` emits `combat_defeat` on hull 0 → 0 transition (not double-emit) | `astral_hazard_system.gd` |
| Mar-27 | §2.1 | Missing null guard on `player_ship` in morale system | Already present in current code; tracker was stale | `crew_morale_system.gd` |
| Mar-27 | §2.2 | `dialogue_manager.gd` push_overlay API mismatch | Already fixed; passes scene-key string | `world/dialogue_manager.gd` |

### 5.2 Open Issues — Must Fix (Critical)

All four critical bugs from previous reviews closed 2026-04-16 as part of Sprint 1. See §5.1 additions and `docs/changelog/CHANGELOG.md`.

### 5.3 Open Issues — Should Fix (High/Medium)

| Source | ID | Issue | File | Status |
| ------ | -- | ----- | ---- | ------ |
| Apr-05 | #3 | GameSession coupling (remaining systems) | `encounter_engine.gd`, `faction_system.gd` | 3 of ~6 done; see also UI-coupling row below |
| CR-2026-04-16 §2.1 | — | UI→GameSession coupling (view-model layer) | `scripts/ui/` | 206 → 106 refs; `navigation.gd` 73 → 0 via `NavigationViewModel` (Sprint 3a); `combat_ui.gd` 4 → 0 via `CombatViewModel` (Sprint 3b); `star_map_screen.gd` 23 → 0 via `StarMapViewModel` (Sprint 5a 2026-04-16). Remaining screens in Sprint 6 |
| Apr-05 | #4 | DataLoader cache never invalidated | `data_loader.gd` | Open |
| Apr-05 | #6 | CrewTraitSystem iterates all crew per lookup | `crew_trait_system.gd` | Open |
| Apr-05 | #7 | Per-pixel portrait processing every dialogue open | `dialogue_ui.gd:503-525` | **Done 2026-04-16** — static cache keyed by `resource_path` + thresholds (Sprint 3c). 6 regression tests (`test_portrait_cache.gd`) |
| Apr-05 | #9 | crystal_pickup signal arity mismatch | `event_bus.gd`, callers | Open |
| Apr-05 | #10 | _remove_near_white_bg whiteness metric | `dialogue_ui.gd:518` | Open |
| Apr-05 | #12 | Redundant DataLoader calls for same file | `data_loader.gd` | Open |
| Apr-05 | #13 | No crew capacity enforcement | `game_session.gd` recruitment | Open |
| Apr-05 | #15 | _migrate_save_data is a stub | `save_manager.gd:118-125` | Open — implement version tracking |
| Mar-27 | §2.4 | R key collision (menu_select vs repair) | `project.godot` | **Done 2026-04-16** — already resolved in Sprint 1 (`repair` R→T rebind); stale tracker entry. Sprint 3c added broad `test_input_map_collisions.gd` regression guard |
| Mar-27 | §2.3 | scene_transition tween after scene change | `world/scene_transition.gd:70-75` | **Done 2026-04-16** — post-scene-change work moved to persistent `GameSession.complete_scene_transition(...)`; `scene_transition.gd` no longer awaits on self after swap (Sprint 3c). 4 regression tests (`test_scene_transition_handoff.gd`) |
| Mar-27 | §2.5 | _show_bark infinite recursion risk | `world/dialogue_manager.gd:112-118` | **Done 2026-04-16** — dedicated `EventBus.npc_bark` signal; no longer reuses `exploration_event` (Sprint 3c). 3 regression tests (`test_dialogue_manager_bark.gd`) |
| CR-2026-04-16 | — | pause / skip both bound to ESC (context-separated) | `project.godot:75-113` | Open — surfaced by Sprint 3c `test_input_map_collisions.gd`. Currently tolerated via whitelist since `pause` and `skip` live in disjoint screens; revisit in Sprint 6 input-rebind work |
| CR-2026-04-16 §3 | — | Crew morale dormant in combat + trade | `combat_system.gd`, `economy_system.gd`, `combat_view_model.gd`, `trade_screen.gd` | **Done 2026-04-16** — Sprint 5b. `calculate_damage` takes `morale_modifier`; `get_buy_price`/`get_sell_price`/`buy_crystals`/`sell_crystals` take it too; `CombatViewModel.combat_morale_modifier()` routes it from the session; `trade_screen.gd` pulls from `GameSession.crew_morale.get_trade_modifier`. 24 regression tests in `test_crew_morale_combat_wiring.gd` + `test_crew_morale_trade_wiring.gd` |
| CR-2026-04-16 §3 | — | Astral hazards applied during nav tick | `navigation.gd`, `astral_hazard_system.gd` | **Done** — stale tracker. `navigation.gd:213` already calls `_update_astral_hazards(dt)` each frame (hazard entropy timer, collision, status HUD); discovered during Sprint 5b audit. `NEXT_STEPS.md` §5b row retired accordingly |
| Mar-27 | §3 | Navigation _process does too much per frame | `navigation.gd` (1,717 lines) | Still open; VM conversion 2026-04-16 cut coupling but not line count. Decomposition is NEXT_STEPS.md Sprint 3b / CODE_REVIEW §2.2 |

### 5.4 Open Issues — Low Priority

| Source | ID | Issue | File | Status |
| ------ | -- | ----- | ---- | ------ |
| Apr-05 | #16 | Encounter priority re-sorted every check | `encounter_engine.gd` | Open |
| Apr-05 | #17 | EncounterChoice.conditions never evaluated | `encounter.gd` | Open |
| Apr-07 | #18 | combat_ui.gd complexity (585 lines) | `combat_ui.gd` | Resolved 2026-04-16 — decomposed to 399-line orchestrator + `scripts/ui/combat/` (layout/logic/animations/health_bar) + `CombatViewModel` (Sprint 3b) |
| Apr-07 | #19 | star_map_screen.gd (1,092 lines) | `star_map_screen.gd` | Resolved 2026-04-16 — decomposed to 375-line orchestrator + `scripts/ui/star_map/` (galaxy/region/local layer components) + `StarMapViewModel` (Sprint 5a); 20 regression tests in `test_star_map_view_model.gd` |
| Apr-07 | #20 | dialogue_ui.gd (631 lines) | `dialogue_ui.gd` | Planned — NEXT_STEPS Sprint 6 |
| Apr-07 | #22 | No test suite | Project-wide | Resolved — GUT 9.6.0 vendored 2026-04-16; 97 tests across 12 files as of Sprint 5a |
| Mar-27 | §15 | Missing export presets | `project.godot` | Open |
| Mar-27 | §15 | No error recovery / crash handling | Project-wide | Open |
| Mar-27 | §1.2 | navigation.gd size | `navigation.gd` (1,717 lines) | Open — coupling cut via VM 2026-04-16; decomposition still pending (CODE_REVIEW §2.2) |

---

## 6. Technical Debt Inventory

| Area | Description | Priority | Tracked In |
| ---- | ----------- | -------- | ---------- |
| God scripts | `navigation.gd` (1,717), `combat_ui.gd` (585 → 399), `star_map_screen.gd` (1,092 → 375), `dialogue_ui.gd` (631). `navigation.gd` decoupled via VM; `combat_ui.gd` decomposed (Sprint 3b); `star_map_screen.gd` decomposed (Sprint 5a) into `scripts/ui/star_map/` (galaxy/region/local layer components) + `StarMapViewModel`. `navigation.gd` line split + `dialogue_ui.gd` still pending | Medium | NEXT_STEPS Sprints 5 / 6 |
| UI coupling | `GameSession.` refs inside `scripts/ui/`: 106 (was 206). `navigation.gd` 0 (was 73); `combat_ui.gd` 0 (was 4); `star_map_screen.gd` 0 (was 23). Pattern = `scripts/ui/view_models/<screen>_view_model.gd` | Medium | CR-2026-04-16 §2.1; §5.3 CR-2026-04-16 row |
| Cache management | DataLoader cache unbounded, no invalidation | Medium | §5.3 Apr-05 #4 |
| Save migration | `_migrate_save_data()` is a stub | Medium | §5.3 Apr-05 #15 |
| Trade ledger | `trade_ledger` in GameStateData is unbounded | Low | Untracked |
| Test coverage | GUT 9.6.0 vendored 2026-04-16; 14 test files, 121 tests (MathUtils, EncounterOutcome, AstralHazard hull death, NavigationViewModel, CombatViewModel, CombatLayout, CombatLogic, InputMapCollisions, DialogueManagerBark, PortraitCache, SceneTransitionHandoff, StarMapViewModel, CrewMoraleCombatWiring, CrewMoraleTradeWiring). Remaining UI and systems still untested | Medium | §7 Sprint 1 (done) + per-sprint regression tests |
| 3D asset sizes | Character GLBs are 34 MB each; textures 20 MB | Medium | NEXT_STEPS Sprint 7 |
| Art direction | Guide committed to Track A floor + Track B aspirational (2026-04-16). Sprite pilot redraw + parity screenshot still pending | Medium | NEXT_STEPS Sprints 2 / 4 |

### Engine/Addon Dependencies

| Dependency | Version | Risk |
| ---------- | ------- | ---- |
| Godot | 4.6 | Stable — GL Compatibility renderer |
| procedural_world_map addon | 1.0 (vendored) | Low — MIT, vendored |
| GUT | 9.6.0 (vendored) | Low — test framework, dev-only |

---

## 7. Active Initiatives & Roadmap

All initiatives organised by sprint. Each sprint must pass automated tests (once established) and manual playtesting before merging.

### Sprint 1: Test Framework + Critical Bugs — **DONE 2026-04-16**

**Goal:** Establish testing infrastructure and fix all critical bugs. Landed via commits `fbb6362` (GUT vendor) + `b6d5c53` (fixes, tests, docs). See `docs/changelog/CHANGELOG.md` for the full summary.

| Task | Priority | Reference | Files |
| ---- | -------- | --------- | ----- |
| Install GUT test framework | High | `docs/REFACTORING_PLAN.md` Phase 1 | `addons/gut/`, `tests/` |
| Write unit tests for `ConditionEvaluator`, `CombatSystem`, `StatEvaluator`, `MathUtils` | High | Refactoring Plan 1.3–1.4 | `tests/unit/` |
| Fix: `trigger_encounter_id` never evaluated | Critical | Apr-05 #1, §5.2 | `encounter_engine.gd`, `encounter.gd` |
| Fix: Hull death not emitted from hazard damage | Critical | Apr-05 #2, §5.2 | `astral_hazard_system.gd` |
| Fix: Null guard on player_ship in morale system | Critical | Mar-27 §2.1, §5.2 | `crew_morale_system.gd` |
| Fix: dialogue_manager push_overlay API | Critical | Mar-27 §2.2, §5.2 | `world/dialogue_manager.gd` |
| Write regression tests for each critical fix | High | Quality Policy §4 | `tests/unit/` |

### Sprint 2: UI View-Model Layer + Combat UI Decomposition + Should-Fix Bugs

**Goal:** Establish the view-model pattern that cuts UI→GameSession coupling, apply it to the two largest screens, and address high-priority open bugs. Tracked in NEXT_STEPS.md §2 as Sprints 3a / 3b / 3c.

| Task | Priority | Reference | Files | Status |
| ---- | -------- | --------- | ----- | ------ |
| `NavigationViewModel` + convert `navigation.gd` (73 → 0 `GameSession.` refs) | High | CODE_REVIEW §2.1, NEXT_STEPS 3a | `scripts/ui/view_models/navigation_view_model.gd`, `scripts/ui/navigation.gd` | **Done 2026-04-16** |
| Unit tests for NavigationViewModel (`SessionDouble` + per-system doubles) | High | Quality Policy §4 | `tests/unit/test_navigation_view_model.gd` | **Done 2026-04-16** (22 tests) |
| `CombatViewModel` + decompose `combat_ui.gd` (585 → 399 orchestrator + 4 focused components) | Medium | Refactoring Plan Phase 2, NEXT_STEPS 3b | `scripts/ui/view_models/combat_view_model.gd`, `scripts/ui/combat/` | **Done 2026-04-16** |
| Fix: `crystal_pickup` signal arity mismatch | Medium | Apr-05 #9, §5.3 | `event_bus.gd`, callers | Pending |
| Fix: R key collision (menu_select vs repair) | Medium | Mar-27 §2.4, §5.3 | `project.godot` | **Done 2026-04-16** (Sprint 3c; stale tracker — already resolved in Sprint 1) |
| Fix: scene_transition tween after scene change | Medium | Mar-27 §2.3, §5.3 | `world/scene_transition.gd`, `autoload/game_session.gd` | **Done 2026-04-16** (Sprint 3c) |
| Fix: _show_bark recursion risk | Medium | Mar-27 §2.5, §5.3 | `world/dialogue_manager.gd`, `autoload/event_bus.gd` | **Done 2026-04-16** (Sprint 3c) |
| Cache processed portrait textures | Medium | Apr-05 #7, §5.3 | `dialogue_ui.gd` | **Done 2026-04-16** (Sprint 3c) |
| Tests for new combat components | High | Quality Policy §4 | `tests/unit/test_combat_view_model.gd`, `test_combat_layout.gd`, `test_combat_logic.gd` | **Done 2026-04-16** (31 new tests; 62/62 green) |

### Sprint 3: Star Map Decomposition + System Fixes

**Goal:** Decompose `star_map_screen.gd` and fix system-level issues. Maps onto NEXT_STEPS.md Sprint 5 (sliced into 5a/5b/5c).

| Task | Priority | Reference | Files | Status |
| ---- | -------- | --------- | ----- | ------ |
| Decompose `star_map_screen.gd` (1,092 → 375 orchestrator + 3 layer components + VM) | Medium | Refactoring Plan Phase 3, NEXT_STEPS 5a | `scripts/ui/star_map/`, `scripts/ui/view_models/star_map_view_model.gd` | **Done 2026-04-16** |
| Tests for StarMapViewModel | High | Quality Policy §4 | `tests/unit/test_star_map_view_model.gd` | **Done 2026-04-16** (20 tests; 97/97 green) |
| Tests for Sprint 5b morale wiring | High | Quality Policy §4 | `tests/unit/test_crew_morale_combat_wiring.gd`, `test_crew_morale_trade_wiring.gd` | **Done 2026-04-16** (24 tests; 121/121 green) |
| Fix: DataLoader cache invalidation | High | Apr-05 #4, §5.3 | `data_loader.gd` | Pending — NEXT_STEPS 5c |
| Fix: Redundant DataLoader calls | Medium | Apr-05 #12, §5.3 | `data_loader.gd` | Pending — NEXT_STEPS 5c |
| Fix: CrewTraitSystem per-lookup iteration | Medium | Apr-05 #6, §5.3 | `crew_trait_system.gd` | Pending |
| Continue GameSession decoupling (encounter_engine, faction_system) | Medium | Apr-05 #3, §5.3 | `encounter_engine.gd`, `faction_system.gd` | Pending |
| Implement `_migrate_save_data()` version tracking | Medium | Apr-05 #15, §5.3 | `save_manager.gd` | Pending |
| Wire crew morale into combat + trade | Medium | CODE_REVIEW §3, NEXT_STEPS 5b | `combat_system.gd`, `economy_system.gd`, `combat_view_model.gd`, `trade_screen.gd` | **Done 2026-04-16** (Sprint 5b) |
| Apply astral hazards during nav tick | Medium | CODE_REVIEW §3, NEXT_STEPS 5b | `navigation.gd`, `astral_hazard_system.gd` | **Done** — stale tracker (already wired at `navigation.gd:213`); retired in Sprint 5b tidy pass |
| Gate docking via realm_control + reputation | Medium | CODE_REVIEW §3, NEXT_STEPS 5c | `station_screen.gd`, `realm_control_system.gd` | Pending — NEXT_STEPS 5c |
| Surface conquest actions as visible world changes | Medium | CODE_REVIEW §3, NEXT_STEPS 5c | `faction_conquest_system.gd`, `navigation.gd` | Pending — NEXT_STEPS 5c |
| HUD: segmented hull bar, objective on top bar, morale pip | Medium | CODE_REVIEW §4.6, NEXT_STEPS 5c | `navigation.gd` | Pending — NEXT_STEPS 5c |

### Sprint 4: Dialogue Decomposition + Crew/Content Fixes

**Goal:** Decompose `dialogue_ui.gd` and fix remaining medium-priority issues.

| Task | Priority | Reference | Files |
| ---- | -------- | --------- | ----- |
| Decompose `dialogue_ui.gd` (632 lines → 5 files) | Medium | Refactoring Plan Phase 4 | `scripts/ui/dialogue/` |
| Fix: _remove_near_white_bg whiteness metric | Medium | Apr-05 #10, §5.3 | `dialogue_ui.gd` (or new `portrait_manager.gd`) |
| Fix: No crew capacity enforcement | Medium | Apr-05 #13, §5.3 | `game_session.gd` |
| Fix: Combat loot magic numbers (remaining) | Medium | Apr-05 #8, §5.3 | `combat_ui.gd` / `combat_logic.gd` |

### Sprint 5: Art Direction + 3D Asset Pipeline

**Goal:** Resolve art direction ambiguity and establish 3D asset conventions.

| Task | Priority | Reference | Files |
| ---- | -------- | --------- | ----- |
| Art direction resolution (design decision) | High | Refactoring Plan Phase 6 | `design/art_direction/art_direction_guide.md` |
| Separate 2D/3D asset directories | Medium | Refactoring Plan Phase 5.1 | `assets/` restructure |
| Optimise 3D model sizes (LOD, texture compression) | Medium | Refactoring Plan Phase 5.2 | `assets/characters/3d/` |
| Consider Git LFS for large binary assets | Medium | Risk mitigation | `.gitattributes` |

### Sprint 6: Cutscene Pipeline + Content Testing

**Goal:** Scale the cutscene system and verify expansion content.

| Task | Priority | Reference | Files |
| ---- | -------- | --------- | ----- |
| Create cutscene template scene | Medium | Refactoring Plan Phase 5.3 | `scenes/cutscenes/cutscene_template.tscn` |
| Extract reusable cutscene utilities | Medium | Refactoring Plan Phase 5.3 | `scripts/systems/cutscene/` |
| Formalise cutscene data schema | Medium | Refactoring Plan Phase 5.3 | `data/cutscenes/_schema.json` |
| Create 3D asset manifest | Low | Refactoring Plan Phase 5.5 | `ASSETS_3D.md` |
| Integration-test Arcs 5–10 expansion content | High | §7 original 6.4 | `data/encounters/`, `data/side_missions/` |
| Difficulty balance pass | Medium | §7 original 6.5 | `data/` JSON files |

### Backlog: Visual Polish & Features

| Task | Priority | Reference |
| ---- | -------- | --------- |
| Character portraits in all dialogues (faction frames) | Medium | Original 6.3 |
| Faction-themed UI panels | Low | Original 6.3 |
| Region-specific space backgrounds | Low | Original 6.3 |
| Crystal visual effects | Low | Original 6.3 |
| Live World News (subspace radio) | Low | Original Tier 1 |
| CI/CD pipeline (headless Godot export) | Low | Original Tier 1 |
| Wanted / Notoriety system | Low | Original Tier 2 |
| Tavern / Station Hub with rumors | Low | Original Tier 3 |
| Black Market / Smuggling | Low | Original Tier 3 |
| Astral Dice mini-game | Low | Original Tier 3 |
| Export presets (macOS notarization, icons) | Low | Mar-27 §15 |
| Error recovery / crash handling | Low | Mar-27 §15 |

---

## 8. Documentation Index

| Document | Location | Purpose |
| ------ | ---------- | --------- |
| Architecture rules | `CLAUDE.md` | Non-negotiable rules for all contributors |
| Architecture reference | `docs/STRUCTURE.md` | Scenes, signals, systems, entities, data files |
| Game design summary | `docs/GAME_SUMMARY.md` | Complete game world, story, mechanics (implemented + planned) |
| Agent briefing | `docs/AGENT_BRIEFING.md` | Full onboarding document for AI agents |
| Current code review | `docs/architecture/CODE_REVIEW.md` | Enhanced 2026-04-16 review |
| Active sprint plan | `docs/NEXT_STEPS.md` | Engineering + art sprint schedule |
| Godot engineering notes | `docs/GODOT_NOTES.md` | Engine quirks, CanvasLayer rules, discoveries |
| Latest code review | `docs/reviews/CODE_REVIEW_2026-04-07.md` | 22 issues, 18 implemented |
| Code review (Apr 5) | `docs/reviews/CODE_REVIEW_2026-04-05.md` | 18 issues, partially resolved |
| Code review (Mar 27) | `docs/reviews/CODE_REVIEW_2026-03-27.md` | First Godot review, partially resolved |
| Refactoring plan | `docs/REFACTORING_PLAN.md` | UI decomposition, test framework, 3D pipeline |
| Changelog | `docs/changelog/CHANGELOG.md` | Per-session change log |
| Dev guide | `docs/GODOT_DEV_GUIDE.md` | Godot development reference and tool index |
| Contributing guide | `docs/process/CONTRIBUTING.md` | How to pick up tasks |
| Development methodology | `docs/development-methodology/` | Task decomposition, architecture planning, iteration strategy |
| ADRs | `docs/architecture/decisions/` | Architecture Decision Records |
| Issues | `docs/issues/` | Issue tracking (open/in-progress/closed) |
| Reviews | `docs/reviews/` | Code review history |
| QA | `docs/qa/` | Visual QA checklist |
| Story reference | `story/` | Arc overview, character profiles, faction lore |
| Archived TRDs | `docs/archive/architecture/` | Python-era technical specs (historical) |
| Archived PRDs | `docs/archive/prds/` | Completed product requirement docs |
| Archived plans | `docs/archive/plans/` | Superseded plans (PLAN-001, PLAN-002, old MASTER_PLAN, completed feature plans) |
| Archived features | `docs/archive/features/` | Superseded feature proposals |

---

## 9. Completed Work History

### Python Prototype (February 2026)

Complete Python/Pygame prototype with 46 modules, 280 tests, 100% pass rate. All 4 arcs playable. Full EAL (Engine Abstraction Layer) for migration readiness.

### Godot Migration (March 2026)

Complete rewrite of engine and UI layers in GDScript. Core logic (systems, entities, data models) ported with minimal changes. All autoloads, UI screens, and data loading rebuilt for Godot scene tree.

### Character Selection Feature (2026-03-18)

Dual protagonist support — Aristotle or Dave with fully separate narrative paths.

### Crew Missions Feature (2026-03-18)

8 recruitable crew members with trait bonuses and story-driven recruitment encounters.

### Star Map Feature (2026-03-20)

Per-region fog of war, purchasable maps, fairy cartographer, spawn zones, galaxy layout.

### 2D World Gameplay Layer (2026-03-25)

TileMap-based outpost (Fringe Haven), player CharacterBody2D, NPC patrol AI, tavern interior, dialogue manager, scene transitions.

### Code Review Remediation (2026-03-27)

16 P0/P1 fixes from first Godot code review.

### Astral Hazard System (2026-04-05)

Static and dynamic hazards, crew mitigation, hull damage, status effects.

### Karma System, Planet System, Star Base System, Skill Allocation

All implemented between March 18-April 5, 2026. See changelog for details.

### Code Review Remediation (2026-04-07)

18 of 22 issues from the third code review implemented in a single session. Key deliverables:

- **Critical fix:** Exploration state persistence in save/load (`game_state_data.gd`, `game_session.gd`)
- **New classes:** `ConditionEvaluator` (centralised condition logic), `MathUtils` (weighted random utility)
- **Architecture:** Decoupled `CombatSystem`, `EconomySystem`, `AstralHazardSystem` from `GameSession`; extracted `_init_systems()` method; expanded `Config` with game constants
- **Style:** Tab indentation for cutscene files, `##` doc comments, `@warning_ignore` on EventBus, `@onready` cleanup, `CutsceneDialogueUI` rename
- **Audio:** Separate Music/SFX audio buses (`default_bus_layout.tres`)
- **Save system:** SHA-256 checksum integrity check, `set_process` toggling
- **Faction system:** Encounter outcomes now delegate to `FactionSystem.change_reputation()` with cascade rules

Full details: `docs/CODE_REVIEW_2026-04-07.md` (Implementation Log section).
