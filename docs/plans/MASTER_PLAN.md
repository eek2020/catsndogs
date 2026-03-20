# Whisper Crystals — Master Plan

**Date:** 2026-03-02 (last updated 2026-03-18)
**Status:** Authoritative — supersedes PLAN-001 and PLAN-002
**Review source:** See `docs/reviews/REVIEW-002_code_review_2026-03-02.md`

This document is the single source of truth for project planning going forward.
All previous plan documents are archived in `docs/archive/plans/`.

---

## 1. Current System Overview

Whisper Crystals is a fully playable narrative-driven 2D space pirate game prototype.
All four story arcs have encounter data, dialogue, and arc transition logic.
Three endings are reachable based on cumulative choice history. The core loop is complete.

### What Is Built

| Area | Status | Details |
|------|--------|---------|
| Engine & Architecture | ✅ Complete | EAL (Engine Abstraction Layer), stack state machine, event bus, data-driven content |
| Core Game Loop | ✅ Complete | Navigation → encounter trigger → decision → outcome → arc progression |
| Story — Arcs 1–4 | ✅ Complete | Encounter data, story flags, arc transition logic for all 4 arcs |
| Story — 3 Endings | ✅ Complete | Hold / Share / Destroy calculated from weighted choice history |
| Dialogue System | ✅ Complete | DialogueState with typewriter, conditional branches, portrait rendering |
| Combat System | ✅ Complete | CombatState, CombatResolver, victory/defeat/flee, loot/salvage |
| Trade System | ✅ Complete | TradeScreenState, faction-aware pricing, buy/sell |
| Economy System | ✅ Complete | Crystal extraction, supply routes, market pricing, upgrades, repair |
| Exploration System | ✅ Complete | Region discovery, POI scanning, travel, exploration events |
| Crew Morale System | ✅ Complete | Morale thresholds, faction loyalty, combat/trade modifiers |
| Faction System | ✅ Complete | 6+2 factions, relationship matrix, diplomatic states, cascade rules |
| Faction Conquest AI | ✅ Complete | Background faction warfare, realm control, power rankings |
| Save / Load | ✅ Complete | SaveManager with 3 slots, atomic writes, settings persistence |
| All UI States | ✅ Complete | Menu, Navigation, Combat, Trade, Dialogue, Cutscene, Ship Screen, Faction Screen, Pause, Settings, Ending, Mission Log |
| Side Missions | ✅ Complete | SideMissionSystem, distress signals, mission log UI, 4 arc-1 missions, 5 distress encounters |
| Test Coverage | ✅ Complete | 280 tests, 100% pass rate, all headless (no display context needed) |
| Code Quality | ✅ Complete | Code review done 2026-03-02; 11 critical/medium issues resolved |

### Codebase Metrics

| Metric | Count |
|--------|-------|
| Python modules | 46 |
| Test files | 16 |
| Total tests | 280 |
| Test pass rate | 100% |
| Dataclass entities | 13 |
| Game systems | 10 |
| UI states | 14 |
| JSON data files | 20 |

---

## 2. Product Vision

Aristotle — a street cat turned pirate captain — controls the multiverse's only source of starship fuel.
Every faction wants it. The game is about navigating those competing demands across four arcs, accumulating
choices that determine a final ending. The prototype demonstrates the full narrative arc from discovery to
reckoning.

**Target:** Fully playable desktop prototype (Mac M3/M4 primary, Windows compatible) suitable for evaluation
for engine migration to Godot 4 or Unity.

---

## 3. Engineering Principles

These principles are non-negotiable and enforced in every contribution:

1. **Engine Abstraction Layer (EAL)** — `core/`, `systems/`, `entities/` have zero pygame imports.
   Only `engine/` contains pygame. UI uses `RenderInterface` ABCs.
   Verification: `grep -r "import pygame" src/whisper_crystals/core/ src/whisper_crystals/systems/ src/whisper_crystals/entities/` must return zero results.

2. **Stack state machine** — All game states managed via `core/state_machine.py` (push/pop/switch).
   No ad-hoc boolean flags for state management.

3. **Data-driven content** — All encounters, dialogue, factions, ships in JSON under `data/`.
   No hardcoded narrative in Python.

4. **Entity serialization** — All entities implement `to_dict()` / `from_dict()`.

5. **Event bus** — `core/event_bus.py` for decoupled system communication.
   Systems publish events; they do not call each other directly.

6. **Tests mandatory** — All new systems need tests. `pytest tests/ -v` must pass before any task is marked complete.

See `docs/architecture/TRD-001_Technical_Architecture_Stack.md` for the full architecture specification.

---

## 4. Architecture Summary

```
src/whisper_crystals/
  core/           # Engine-agnostic: config, event_bus, game_state, interfaces, session,
                  #   state_machine, data_loader, save_manager, logger
  entities/       # Dataclasses: Character, Ship, Faction, Encounter, Crystal, SideMission
  systems/        # Logic: combat, economy, exploration, crew_morale, encounter_engine,
                  #   faction_system, faction_conquest, realm_control, narrative, side_mission
  engine/         # Pygame: renderer, input_handler, audio, camera, starfield, image_utils, startup
  ui/             # States: menu, navigation, combat_ui, dialogue_ui, cutscene, hud,
                  #   pause_menu, settings_screen, ship_screen, trade_screen,
                  #   faction_screen, purchase_screen, ending_screen, mission_log

data/             # JSON: encounters/, dialogue/, factions/, ships/, economy/, story/, side_missions/
tests/            # 13 test files, 210 tests
```

Migration classification: `core/`, `entities/`, `systems/` are PORTABLE (pure Python, transfer to Godot/Unity as-is).
`engine/`, `ui/` are REWRITE (engine-specific, must be rebuilt).

---

## 5. Completed Work

### Phases 0–3 (PLAN-001, completed 2026-03-01)

- **Step 1** — Project management structure: directories, templates, CLAUDE.md, CONTRIBUTING.md, changelog, ADR-001
- **Phase 0** — Structural refactor: GameSession extraction, EAL compliance, combat separation, GameStateData serialization
- **Phase 1** — Core infrastructure: SaveManager, save/load UI wiring, PauseMenuState, SettingsScreenState
- **Phase 2** — Game systems: EconomySystem, TradeScreenState, ExplorationSystem, CrewMoraleSystem, FactionConquestAI, RealmControlSystem
- **Phase 3** — Content pipeline: Arc 2–4 encounter data, integration tests, dialogue data files

### Code Review Remediation (2026-03-02)

11 issues from `docs/reviews/REVIEW-002_code_review_2026-03-02.md` resolved:

| Issue | Severity | Resolution |
|-------|----------|-----------|
| BUG-1: Shadow DataLoader in economy.py | Critical | DataLoader injected via constructor |
| BUG-3: Morale modifier runaway drift | Critical | Delta scaling formula applied |
| BUG-2: completed_encounters unbounded growth | Medium | Membership guard on append |
| R-5: Unsafe setattr without validation | Medium | VALID_UPGRADE_STATS whitelist added |
| BUG-6: Missing EventBus import in menu.py | Low | Added to TYPE_CHECKING block |
| R-1: Duplicate morale label logic | Low | _morale_label() helper extracted |
| R-2: Duplicate encounter sorting | Low | _get_eligible_encounters() extracted |
| R-3: Missing clear() on GameStateMachine | Low | clear() method added |
| R-4: EventBus publish error resilience | Low | try/except wraps callbacks |
| BUG-4: _quit_to_menu enter/exit churn | Low | Fixed by R-3 (clear() method) |
| R-13: Stray imports | Low | Imports moved to file top |

### Character Selection Feature (ISSUE-001) — COMPLETE (2026-03-18)

Dual-protagonist support (Aristotle or Dave) with fully separate narrative paths, new encounter data, character selection UI, and Dave-specific endings. Implemented in Godot 4.6 / GDScript.

**Summary of completed work:**
- Character selection screen (`scripts/ui/character_select.gd` + `scenes/ui/character_select.tscn`)
- Protagonist data file (`data/characters/protagonists.json`) with Aristotle and Dave configs
- Dave encounter data for all 4 arcs (`data/encounters/arc*_encounters_dave.json`)
- Dave dialogue files (`data/dialogue/dave_internal.json`, `data/dialogue/aristotle_hub.json`)
- Dave side missions (`data/side_missions/arc1_side_missions_dave.json`)
- Dave arc definitions and endings in `data/story/arc_definitions.json`
- Character-aware cutscene, intro, and ending flows
- League Cruiser wired as Dave's player ship
- Protagonist-aware encounter loading

**Previous plan:** `docs/plans/character-selection-feature-plan.md` — archived.

### Bug Fixes (2026-03-18)

| ID | Issue | Root Cause | Fix |
|----|-------|------------|-----|
| BUG-5 | Space bar opens ship stats modal; pressing again stacks another modal making it harder to close. Same behaviour on E, M, ESC keys. | `navigation.gd _unhandled_input` had no overlay guard — every keypress pushed a new overlay. `main.gd push_overlay` had no duplicate-type prevention. | Added `_has_overlay()` guard in `navigation.gd _unhandled_input`. Added duplicate-overlay-key check in `main.gd push_overlay` (belt-and-suspenders fix for all callers). |
| BUG-6 | Aristotle's head shows white background on character select screen. | Asset `aristotle_head.png` has RGBA mode but all alpha=255 (no actual transparency). Character select loaded raw without background removal. Dialogue UI already had `_remove_near_white_bg` but character select did not. | Added `_remove_near_white_bg` to `character_select.gd` (runtime fix). **Art asset needs re-export with proper transparency** — see § 6.3 missing art notes. |
| BUG-7 | Outcome text in dialogue (e.g. rescue a ship) gets cut off before finishing printing. | `dialogue_ui.gd _on_choice_selected` started a fixed timer in parallel with typewriter reveal. Long text would still be revealing when timer expired and frame closed. | Changed to `await` the typewriter reveal completion first, then start a 2-second read timer. Text always fully visible before close. |
| BUG-8 | Ship screen crashes with "Invalid access to property or key 'theme_override_colors' on Label". Same bug in mission log. | `theme_override_colors` is not a directly accessible dictionary property in Godot 4. Code used `label.theme_override_colors.font_color = Color(...)` instead of the correct method API. | Replaced all occurrences with `label.add_theme_color_override("font_color", Color(...))` — 5 in `ship_screen.gd`, 3 in `mission_log.gd`. ISSUE-002. |
| BUG-9 | Mission log input actions `"menu_up"` / `"menu_down"` don't exist in InputMap — errors every keypress. | Non-existent action names used in `mission_log.gd _unhandled_input`. | Replaced with `"ui_up"` / `"ui_down"` (Godot built-in actions). `move_up`/`move_down` in the `or` clause already worked. |
| BUG-10 | `combat_overlay` variable declared twice in `dialogue_ui.gd` — "declared below in parent block" warning. | Variable declared in both `if` branch (line 225) and fallback path (line 235) in same function scope. | Renamed second declaration to `combat_screen`. |
| BUG-11 | Unused parameter warnings in `game_session.gd`: `old_arc`, `faction_id`, `protagonist_id`. | Parameters received from signals/callers but not used in function bodies. | Prefixed with underscore: `_old_arc`, `_faction_id`, `_protagonist_id`. |
| BUG-12 | Local variable `is_contested` shadows method `is_contested()` in `realm_control_system.gd`. | Local bool at line 64 has same name as class method at line 133. | Renamed local to `region_contested`. |
| BUG-13 | Variable `sign` shadows built-in `sign()` function in `mission_log.gd`. | Local string variable named `sign` used for "+"/"-" prefix. | Renamed to `sign_prefix`. |
| BUG-14 | Local variable `angle_deg` declared but never used in `navigation.gd _draw_ship`. | `rad_to_deg()` result stored but never referenced. | Prefixed with underscore: `_angle_deg`. |

---

## 6. Active Initiatives

### 6.1 Phase 4 — Polish and Integration

These tasks complete the original PLAN-001 scope. All depend on Phases 0–3 being done.

| Status | Task | ID | Notes |
|--------|------|----|-------|
| ✅ Done | Music System (BGM playback, track transitions, per-state themes) | 4.1 | `core/music_manager.py` + `assets/audio/music/` + session wiring |
| ✅ Done | Sound Effects System (SFX triggers via event bus, volume control) | 4.1b | SFX event registry in `core/music_manager.py`, wired via event bus |
| ✅ Done | Ending Summary Screen | 4.3 | Full decision summary in `ui/ending_screen.py` (scrollable) |
| ⬜ Todo | Difficulty Balance Pass | 4.4 | Tune `systems/combat.py`, encounter data, ship templates |

### 6.2 Entertainment Enhancements — Side Missions + Distress Signals (COMPLETE)

✅ **All 13 tasks completed 2026-03-02.**

Adds optional side missions and distress signal encounters for gameplay texture between arc beats.

**Files created:**
- `systems/side_mission.py` — SideMissionSystem (lifecycle, objectives, rewards, distress spawning)
- `data/side_missions/arc1_side_missions.json` — 4 arc 1 missions (bounty, retrieval, escort, salvage)
- `data/side_missions/distress_signals.json` — 5 distress signal encounters (3 choices each)
- `ui/mission_log.py` — MissionLogState overlay (two-panel: list + detail with objectives/rewards)
- `tests/test_side_missions.py` — 24 tests

**Files modified:**
- `core/interfaces.py` — MISSION_LOG action
- `core/state_machine.py` — MISSION_LOG state type
- `core/data_loader.py` — `load_side_missions()`, `load_distress_signals()`
- `core/game_state.py` — `side_missions` field + serialization
- `core/session.py` — SideMissionSystem wired, M key hotkey, `_open_mission_log()`
- `entities/encounter.py` — `spawn_weight` field
- `engine/input_handler.py` — M key → MISSION_LOG
- `ui/navigation.py` — distress POI spawning, mission objective checking, distress_signal color
- `ui/hud.py` — active mission count indicator

### 6.3 PLAN-003 — Sprite Character & Visual Identity

**Goal:** Give the game visual personality. Replace geometric placeholders with sprite-based
rendering for ships, characters, and faction-specific visual treatments. Leverage existing
art assets (8 character portraits, 5 ship sprites, splash art, cutlass icon) and build the
infrastructure to make adding new sprites trivial.

**Priority order:**

| Status | Task | ID | Scope |
|--------|------|----|-------|
| ✅ Done | Sprite asset manager | 3.1 | `engine/sprite_manager.py` — centralised sprite loading, caching, scaling, faction-keyed registry. Lazy-load with vector fallback. |
| ✅ Done | Faction ship sprites in navigation | 3.2 | POIs show faction ship sprites for combat encounters. SpriteManager wired into session + navigation. Faction inferred from encounter data. |
| ⬜ Todo | Character portraits in all dialogues | 3.3 | Ensure all dialogue encounters render NPC portraits from `design/charcters/`. Add faction-coloured portrait frames. Handle missing portraits with silhouette fallback. |
| ✅ Done | Combat scene ship sprites | 3.4 | Ship sprites replace vector shapes in `ui/combat_ui.py`. Player ship left, enemy right (flipped). Vector fallback preserved. `CombatShip.ship_template_id` added. |
| ⬜ Todo | Faction-themed UI panels | 3.5 | Apply faction colour palettes (from art direction guide) to UI panel borders, glow effects, and text colours when viewing faction-specific content. Extract colours to `ui/theme.py`. |
| ⬜ Todo | Region-specific space backgrounds | 3.6 | Colour-temperature tinting per region (amber for starting realm, blue for Canis territory, gold for Lion territory). Modify starfield palette based on `current_region`. |
| ⬜ Todo | Crystal visual effects | 3.7 | Whisper crystal glow in HUD (pulsing blue-white), crystal deposit POI effects, ship engine crystal chamber glow during thrust. |
| ⬜ Todo | Character sprite sheets (future) | 3.8 | Placeholder task for animated character sprites if/when needed. Not required for prototype. |

**Key principles:**
- All sprite loading goes through `engine/` (EAL compliance)
- UI states reference sprites via abstract IDs, not file paths
- Graceful fallback: if a sprite is missing, fall back to existing vector shapes
- No breaking changes to game logic — sprites are purely visual layer
- Leverage existing `engine/image_utils.py` infrastructure (load_image_alpha, remove_background_by_corners)

**Existing art assets ready for integration:**

| Asset | Location | Current Status |
|-------|----------|----------------|
| Aristotle portrait (head) | `design/charcters/aristotle_head.png` | Used in dialogue |
| Dave portrait (head) | `design/charcters/dave_head.png` | Used in dialogue |
| Death portrait (head) | `design/charcters/death_head.png` | Used in dialogue |
| Player ship (right profile) | `design/ships/ship_r_side.png` | Used in navigation |
| Player ship (top-down) | `design/ships/ship_up_side.png` | Alternative, loaded |
| League Cruiser | `design/ships/league_cruiser.png` | Not used — ready for 3.2 |
| League Destroyer | `design/ships/league_destroyer.jpg` | Not used — ready for 3.2 |
| Royal Galleon | `design/ships/royal_galleon.jpg` | Not used — ready for 3.2 |
| Wolf Strike Craft | `design/ships/wolf_ship.png` | Used in navigation + combat (3.2, 3.4) |
| Fairy Vessel | `design/ships/fairy_ship.png` | Used in navigation + combat (3.2, 3.4) |
| Knight Warship | `design/ships/knight_ship.png` | Used in navigation + combat (3.2, 3.4) |
| Goblin Scrapship | `design/ships/goblin_scrapper.png` | Used in navigation + combat (3.2, 3.4) |
| Combat cutlass icon | `design/ui_ux/fight_cutlass.png` | Used for combat POIs |
| Splash screen | `design/artwork/wc_splash_screen.png` | Used on startup |
| Title graphic | `design/artwork/whisper_crystals_title.png` | Used on menu |

**Missing art to commission/generate:**

- Alien vessel sprite (neon cyan/bioluminescent)
- Faction-specific UI frame textures (optional, can use colour tinting)
- Crystal deposit sprite/animation
- **`aristotle_head.png` needs re-export with proper transparency** — current asset is RGBA but all alpha=255 (solid white background). Runtime `_remove_near_white_bg` handles it but a proper transparent PNG is preferred.
- 8 crew member portraits (placeholder silhouettes used until art is ready)

---

## 7. Technical Debt Inventory

Deferred items from code review. None are blockers. Prioritize when addressing Phase 4 polish.

| ID | Area | Description | Priority |
|----|------|-------------|----------|
| ARCH-1 | Architecture | `GameSession` is a god object (480 lines). Decompose into `StateTransitionManager`, `CombatFlowController`, `LoadFlowController` | Low — after Phase 4 |
| PERF-1 | Performance | `image_utils.remove_near_white_bg` uses Python per-pixel loop. Use `surfarray` or `PixelArray` | Low — only runs at startup |
| PERF-2 | Performance | `Starfield.draw` iterates 200 stars per frame individually. Pre-render to a surface | Low — Phase 4 |
| PERF-3 | Performance | `renderer.draw_nebula` calls `pygame.transform.rotate` every frame. Cache rotated versions | Low — Phase 4 |
| PERF-4 | Performance | Alpha rectangle surfaces created per call in `draw_rect`. Cache or reuse | Low — Phase 4 |
| PERF-5 | Memory | `_glow_cache` in renderer grows unboundedly. Cap with eviction | Low |
| PERF-6 | Memory | `trade_ledger` in GameStateData is unbounded. Cap or archive for long playthroughs | Low |
| R-8 | Correctness | Convert `completed_encounters` from `list` to `set` (requires serialization changes) | Low |
| R-9 | Maintainability | Extract UI color/size magic numbers into `theme.py` | Low — Phase 4 |
| R-11 | Testing | Add unit tests for UI state `handle_input()`/`update()` with mock renderers | Medium |
| R-12 | Testing | Add `GameSession` integration test with mock renderer/input | Medium |
| R-14 | Data | Add JSON schema validation in `DataLoader` for better error messages | Low |
| SEC-1 | Security | Save files have no integrity check (checksum/HMAC). Low risk for single-player | Low |

---

## 8. Future Roadmap

### Next up: PLAN-003 — Sprite Character & Visual Identity (see § 6.3)

Give the game visual personality with sprite-based rendering. 8 tasks covering sprite manager,
faction ship sprites, character portraits, combat sprites, themed UI, region backgrounds, and
crystal effects. All existing art assets are ready for integration.

### 6.5 Crew Missions Feature — COMPLETE (2026-03-18)

**Goal:** Each protagonist recruits a crew of 4 named characters through story-driven missions.
Each crew member fills a ship role and brings unique trait bonuses that enhance gameplay.

**Full plan:** `docs/plans/crew-missions-feature-plan.md`

**Aristotle's Crew:**

| Role | Name | Join Type | Key Trait |
|------|------|-----------|-----------|
| First Mate | Nine Lives | Willing (old friends) | Survivability — hull repair, crew casualty reduction |
| Gunner | No Tail | Persuade (respects strength) | Firepower — damage bonus, critical hits |
| Navigator | Silky | Willing (great friends) | Pathfinding — hidden routes, discovery rate |
| Surgeon | Blood Paw | Rescue required | Healing — morale recovery, repair costs |

**Dave's Crew:**

| Role | Name | Join Type | Key Trait |
|------|------|-----------|-----------|
| First Mate | Charlie | Willing (childhood friend) | Loyalty — morale boost, desertion reduction |
| Gunner | Bombardier | Persuade (prove yourself) | Explosives — firepower, area damage |
| Navigator | Luna | Willing (fascinated by mission) | Star Reading — hidden routes, ambush detection |
| Surgeon | Thistle | Persuade (distrust military) | Field Medicine — morale recovery, survival |

**Summary of completed work:**

- **Data files created:** `crew_members.json` (8 crew definitions), `crew_missions_aristotle.json` (4 missions), `crew_missions_dave.json` (4 missions), 8 crew encounter files (2-3 encounters each with story-driven dialogue)
- **New system:** `CrewTraitSystem` (`scripts/systems/crew_trait_system.gd`) — loads crew definitions, calculates active trait bonuses per ship
- **Entity extensions:** `CrewMember` extended with `trait_id`, `portrait`, `backstory`, `recruitment_status`; `SideMission` extended with `crew_member_id`; `Encounter` extended with `mission_type`, `crew_member_id`
- **System integrations:** `CombatSystem` applies firepower/critical hit bonuses; `CrewMoraleSystem` applies morale recovery bonuses; `EconomySystem` applies hull repair cost reduction; `EncounterEngine` applies exploration discovery rate and ambush detection bonuses
- **Recruitment flow:** `DialogueUI` detects crew recruitment encounters and triggers `recruit_crew_member()` via `GameSession`; `EventBus.crew_member_recruited` signal wired to `GameSession._on_crew_member_recruited()`
- **DataLoader methods:** `load_crew_members()`, `load_crew_missions()`, `load_crew_encounters()`
- **SideMissionSystem:** `load_crew_missions()` appends crew missions to mission templates
- **UI enhancements:** Ship screen shows detailed crew roster with roles, traits, morale, and empty role slots; Mission log groups crew missions under "CREW MISSIONS" header; Navigation HUD shows crew count indicator
- **Placeholder art:** `assets/characters/crew/` directory created for portraits

**Art status:** All crew portraits are placeholders — artwork in development.
**Story status:** Recruitment narratives are placeholder — story refinement ongoing.

---

### Post-Current Enhancements

**Tier 1 (Low effort, high impact):**

1. **Live World News** — Subscribe to existing `FactionConquestSystem` events; queue "subspace
   radio intercepts" to HUD. No new data files needed.

**Tier 2 (Medium effort, high impact):**

2. **Wanted / Notoriety System** — Add `notoriety: dict[str, int]` to `GameStateData`. New
   `WantedSystem` injects patrol encounters into encounter pool. HUD shows star indicator.
   Pairs well with distress signal exploit mechanic.

**Tier 3 (Medium effort, medium impact):**

3. **Tavern / Station Hub with Rumors** — Information economy. New `RumorSystem` +
   `rumor_registry.json`. Purchased rumors set story flags unlocking encounters or POI markers.

4. **Black Market / Smuggling** — Hidden trade nodes with contraband. `WantedSystem` checks
   cargo on patrol. Pairs with Wanted system (#2).

5. **Astral Dice (Gambling Mini-Game)** — New `MiniGameState` pushed onto stack. Self-contained
   dice math. "Death plays dice" encounter is the flagship use case.

---

## 9. Documentation Index

| Document | Location | Purpose |
|----------|----------|---------|
| Architecture rules | `CLAUDE.md` | Non-negotiable rules for all contributors |
| Contributing guide | `docs/process/CONTRIBUTING.md` | How to pick up tasks |
| Changelog | `docs/changelog/CHANGELOG.md` | Per-phase change log |
| Architecture specs | `docs/architecture/TRD-001 to TRD-003` | Tech stack, engine spec, data models |
| ADRs | `docs/architecture/decisions/` | Architecture Decision Records |
| Code reviews | `docs/reviews/` | REVIEW-001 (Phase 0), REVIEW-002 (2026-03-02) |
| Issues | `docs/issues/` | open/, in-progress/, closed/ |
| Archived PRDs | `docs/archive/prds/` | PRD-001, PRD-002, PRD-003 with completion summaries |
| Archived plans | `docs/archive/plans/` | PLAN-001, PLAN-002 superseded by this document |
| Character selection plan | `docs/archive/plans/character-selection-feature-plan.md` | ISSUE-001 — completed, archived |
| Crew missions plan | `docs/plans/crew-missions-feature-plan.md` | Active — crew recruitment feature |
| Game design brief | `docs/archive/briefs/suggestions.md` | Original enhancement analysis |
