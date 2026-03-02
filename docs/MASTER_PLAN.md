# Whisper Crystals — Master Plan

**Date:** 2026-03-02
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
| All UI States | ✅ Complete | Menu, Navigation, Combat, Trade, Dialogue, Cutscene, Ship Screen, Faction Screen, Pause, Settings, Ending |
| Test Coverage | ✅ Complete | 186 tests, 100% pass rate, all headless (no display context needed) |
| Code Quality | ✅ Complete | Code review done 2026-03-02; 11 critical/medium issues resolved |

### Codebase Metrics

| Metric | Count |
|--------|-------|
| Python modules | 41 |
| Test files | 12 |
| Total tests | 186 |
| Test pass rate | 100% |
| Dataclass entities | 12 |
| Game systems | 9 |
| UI states | 13 |
| JSON data files | 18 |

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
                  #   faction_system, faction_conquest, realm_control, narrative
  engine/         # Pygame: renderer, input_handler, audio, camera, starfield, image_utils, startup
  ui/             # States: menu, navigation, combat_ui, dialogue_ui, cutscene, hud,
                  #   pause_menu, settings_screen, ship_screen, trade_screen,
                  #   faction_screen, purchase_screen, ending_screen

data/             # JSON: encounters/, dialogue/, factions/, ships/, economy/, story/
tests/            # 12 test files, 186 tests
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

---

## 6. Active Initiatives

### 6.1 Phase 4 — Polish and Integration

These 5 tasks complete the original PLAN-001 scope. All depend on Phases 0–3 being done.

| Status | Task | ID | Notes |
|--------|------|----|-------|
| ⬜ Todo | Music System (BGM playback, track transitions, per-state themes) | 4.1 | Modify `engine/audio.py`; create `assets/audio/music/` |
| ⬜ Todo | Sound Effects System (SFX triggers via event bus, volume control) | 4.1b | Depends on 4.1 |
| ⬜ Todo | Minimap in HUD | 4.2 | Add 150×150 minimap to `ui/hud.py` bottom-right |
| ⬜ Todo | Ending Summary Screen | 4.3 | Full decision summary display in `ui/ending_screen.py` |
| ⬜ Todo | Difficulty Balance Pass | 4.4 | Tune `systems/combat.py`, encounter data, ship templates |

### 6.2 Entertainment Enhancements — Side Missions + Distress Signals

This is the active feature work. The SideMission entity is done; all other tasks are pending.

**Goal:** Give the player agency between arc story beats (side missions) and moral surprise moments
during travel (distress signals), without touching the core narrative structure.

| Status | Task | File(s) |
|--------|------|---------|
| ✅ Done | SideMission + MissionObjective entities | `entities/side_mission.py` |
| ⬜ Todo | SideMissionSystem | `systems/side_mission.py` |
| ⬜ Todo | Arc 1 side mission data (3–4 missions) | `data/side_missions/arc1_side_missions.json` |
| ⬜ Todo | Distress signal encounter pool (4–5 repeatable) | `data/side_missions/distress_signals.json` |
| ⬜ Todo | DataLoader additions | `core/data_loader.py` — add `load_side_missions()`, `load_distress_signals()` |
| ⬜ Todo | GameStateData additions | `core/game_state.py` — add `side_missions: dict[str, SideMission]` |
| ⬜ Todo | MISSION_LOG state type | `core/state_machine.py` — add to `GameStateType` enum |
| ⬜ Todo | Wire SideMissionSystem | `core/session.py` — instantiate system, add `_open_mission_log()` |
| ⬜ Todo | Navigation integration | `ui/navigation.py` — distress POI spawning, M key hotkey |
| ⬜ Todo | HUD active mission indicator | `ui/hud.py` — amber "[M: N MISSIONS]" in top bar |
| ⬜ Todo | MissionLogState UI | `ui/mission_log.py` — overlay with active/completed mission list |
| ⬜ Todo | Full test suite | `tests/test_side_missions.py` |
| ⬜ Todo | Run tests + EAL verification | `pytest tests/ -v` + grep check |

**Implementation notes:**
- `SideMissionSystem` pattern mirrors `ExplorationSystem`
- Distress signals use `arc_id: "any"`, `repeatable: true`, `spawn_weight` field
- Navigation spawns distress signals probabilistically (timer 30–90s), not condition-based
- MissionLogState uses amber/gold theme; pushed as overlay like ShipScreenState
- See `docs/archive/plans/PLAN-002_Entertainment_Enhancements.md` for full JSON schemas and code snippets

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

### Post-Side Missions (PLAN-002 Tier 1 Remainder)

1. **Live World News** — Subscribe to existing `FactionConquestSystem` events; queue "subspace radio intercepts" to HUD.
   Low effort, high entertainment value. No new data files needed.

### PLAN-002 Tier 2

2. **Wanted / Notoriety System** — Add `notoriety: dict[str, int]` to `GameStateData`. New `WantedSystem` injects
   patrol encounters into encounter pool. HUD shows star indicator. Pairs well with distress signal exploit mechanic.

3. **Named Crew with Mini-Storylines** — Add `name`, `backstory`, `loyalty_to_faction`, `special_ability`, `arc_flags`
   to `CrewMember`. New `crew_dialogue.json` files. Morale system already exists; adds the emotional hook.

### PLAN-002 Tier 3

4. **Tavern / Station Hub with Rumors** — Information economy. New `RumorSystem` + `rumor_registry.json`.
   Purchased rumors set story flags unlocking encounters or POI markers.

5. **Black Market / Smuggling** — Hidden trade nodes with contraband. `WantedSystem` checks cargo on patrol.
   Pairs with Wanted system (#2).

6. **Astral Dice (Gambling Mini-Game)** — New `MiniGameState` pushed onto stack. Self-contained dice math.
   "Death plays dice" encounter is the flagship use case.

### Engine Migration

Migration from Python/Pygame to Godot 4 or Unity when any of these conditions are met:
- All four story arcs are fully playable end-to-end
- Pygame performance limits prevent required visual quality or frame rate
- Platform expansion (console, mobile) is targeted
- A collaborator or publisher requires a specific engine

Recommendation: Evaluate Godot 4 first (open source, Python-adjacent GDScript, lighter overhead).

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
| Game design brief | `docs/archive/briefs/suggestions.md` | Original enhancement analysis |
