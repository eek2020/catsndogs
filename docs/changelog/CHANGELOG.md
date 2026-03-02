# Changelog

All notable changes to the Whisper Crystals project are documented here.

Format: Each entry includes the date, phase/task reference, and summary of changes.

---

## 2026-03-02 — Documentation Audit & Restructure

**Task:** Documentation consolidation and master plan creation
**Scope:** Full /docs reorganisation — no source code changes

### Documentation Structure

- Created `docs/MASTER_PLAN.md` — unified single source of truth for all planning and status
- Created `docs/architecture/` — moved all TRDs (TRD-001, TRD-002, TRD-003) here from `docs/trd/`
- Created `docs/architecture/decisions/` — moved ADR_TEMPLATE and ADR-001 here from `docs/decisions/`
- Created `docs/process/` — moved `CONTRIBUTING.md` here; updated all plan references to `MASTER_PLAN.md`
- Created `docs/archive/prds/` — archived PRD-001, PRD-002, PRD-003 with completion summaries
- Created `docs/archive/plans/` — archived PLAN-001 (superseded) and PLAN-002 (absorbed into MASTER_PLAN.md)
- Created `docs/archive/briefs/` — moved `suggestions.md` here

### Reviews

- Moved `CODE_REVIEW_2026-03-02.md` → `docs/reviews/REVIEW-002_code_review_2026-03-02.md`
- Moved `IMPLEMENTATION_PLAN_2026-03-02.md` → `docs/reviews/REVIEW-002_remediation_plan_2026-03-02.md`
- Updated `docs/reviews/REVIEW_LOG.md` with REVIEW-002 entry

### Removed

- `docs/trd/` — empty after TRD migration to `docs/architecture/`
- `docs/prd/` — empty after PRD archival
- `docs/decisions/` — empty after ADR migration to `docs/architecture/decisions/`
- `docs/plans/` — superseded by `docs/MASTER_PLAN.md`
- `docs/suggestions.md` — moved to `docs/archive/briefs/`

### Updated

- `README.md` — updated project structure, docs links point to new locations, added game status
- `docs/process/CONTRIBUTING.md` — updated all plan references to `MASTER_PLAN.md` and new path structure
- `docs/reviews/REVIEW_LOG.md` — added REVIEW-002 entry

---

## 2026-03-01 — Phase 2: Game Systems

**Tasks:** 2.1, 2.2, 2.3, 2.4, 2.5, 2.6 (PLAN-001)
**Model:** Opus 4.6

### Task 2.1 — Economy System

- Created `systems/economy.py` — crystal extraction, supply routes, market pricing, buy/sell trade
- Added `to_dict()` / `from_dict()` to `CrystalDeposit`, `SupplyRoute`, `CrystalMarket` entities
- Added economy fields to `GameStateData` (crystal_deposits, supply_routes, crystal_market, trade_ledger)
- Updated `GameStateData` serialization for full economy round-trip
- Created `data/economy/economy_data.json` — 6 crystal deposits, 5 supply routes, market config, trade goods
- Added `load_crystal_deposits()`, `load_supply_routes()`, `load_crystal_market()` to `DataLoader`
- Wired `EconomySystem` into `GameSession`
- Created `tests/test_economy.py` — 38 tests covering extraction, discovery, routes, trade, faction economics, serialization

### Task 2.2 — Trade UI

- Created `ui/trade_screen.py` — `TradeScreenState` overlay with buy/sell modes, quantity selection, price display
- Faction-aware pricing with reputation modifiers and trade margin (75% sell/buy ratio)
- Cargo capacity checks, faction reserve limits, trade ledger summary
- Added `open_trade_screen()` to `GameSession` for encounter/dialogue integration

### Task 2.3 — Exploration System

- Created `systems/exploration.py` — `ExplorationSystem` with `Region` and `PointOfInterest` dataclasses
- Region discovery, accessibility, and travel with connected-region validation
- POI discovery via scanning (probability-based), visitation with reward application
- Procedural exploration events with weighted random selection based on region danger
- Full serialization via `get_state_dict()` / `load_state_dict()`
- Created `data/economy/regions.json` — 7 regions with connections, 5 POIs with rewards
- Added `load_regions()`, `load_points_of_interest()` to `DataLoader`
- Created `tests/test_exploration.py` — 16 tests covering regions, travel, POIs, events, serialization

### Task 2.4 — Crew Morale System

- Created `systems/crew_morale.py` — `CrewMoraleSystem` tracking individual and average crew morale
- Morale thresholds: MUTINY (≤20), DISGRUNTLED (≤40), STEADY (≤60), CONTENT (≤80), INSPIRED (>80)
- Combat modifier (0.7x–1.2x) and trade modifier (0.9x–1.1x) based on morale
- Event-driven morale effects: combat victory/defeat, trade outcomes, idle decay
- Faction loyalty checks: crew from hostile factions suffer morale penalties
- Mutiny risk events published when morale drops below threshold
- Created `tests/test_crew_morale.py` — 16 tests covering queries, changes, combat modifiers, loyalty

### Task 2.5 — Faction Conquest AI

- Created `systems/faction_conquest.py` — `FactionConquestAI` with AI-driven faction-vs-faction warfare
- `ConquestAction` dataclass for attack, blockade, diplomacy, and fortify actions
- AI target selection weighted by negative relationships; action type by personality traits
- Resolution: attacks compare military + tactical vs military + stability; blockades reduce reserves
- Diplomacy improves inter-faction relations; fortify boosts military and stability
- Power rankings, threat queries, conflict history tracking
- Created `tests/test_faction_conquest.py` — 8 tests covering planning, all action types, rankings, serialization

### Task 2.6 — Realm Control

- Created `systems/realm_control.py` — `RealmControlSystem` with `RealmState` tracking per-region influence
- Influence-based control: faction with highest influence controls region
- Contested detection when second-place faction has >70% of leader's influence
- Natural drift: home realm influence grows, foreign influence decays
- Conflict result application: winner gains influence, loser loses
- Danger modifiers for contested regions
- Full serialization via `get_state_dict()` / `load_state_dict()`
- Created tests in `test_faction_conquest.py` — 9 tests covering initialization, influence, control changes, territories

### Test Results

- All 151 tests pass (99 previous + 52 new)
- All tests run headless without pygame display context
- EAL verification: zero pygame imports in `core/`, `systems/`, `entities/`

---

## 2026-03-01 — Phase 1: Core Infrastructure

**Tasks:** 1.1, 1.2, 1.3, 1.4 (PLAN-001)
**Model:** Opus 4.6

### Task 1.1 — Save/Load Manager

- Created `core/save_manager.py` — engine-agnostic save/load system with JSON persistence
- Supports 3 save slots with metadata (character name, arc, playtime, timestamp)
- Atomic writes via temp file + `os.replace()` to prevent corruption
- Created `tests/test_save_manager.py` — 12 tests covering round-trip, corruption, slots, deletion

### Task 1.2 — Wire Save/Load into UI

- Updated `core/session.py` — integrated SaveManager, settings, pause menu, and quit-to-menu flow
- Updated `ui/menu.py` — dynamic "Load Game" options based on available save slots
- Pause menu intercepts `Action.PAUSE` from navigation in `GameSession.tick()`
- Load game from menu or pause restores state and relaunches navigation

### Task 1.3 — Pause Menu

- Created `ui/pause_menu.py` — overlay state with Resume / Save / Load / Settings / Quit to Menu
- Quick save to current slot with visual feedback flash
- Follows overlay pattern (semi-transparent background, `machine.pop()` to resume)

### Task 1.4 — Settings Screen

- Created `ui/settings_screen.py` — overlay with music/SFX volume sliders and difficulty toggle
- Settings persisted to `~/.whisper_crystals/settings.json`
- `load_settings()` / `save_settings()` helpers with defaults merging
- Created `tests/test_settings.py` — 5 tests covering round-trip, defaults, corruption, directory creation

### Test Results

- All 61 tests pass (44 previous + 17 new)
- All tests run headless without pygame display context
- EAL verification: zero pygame imports in `core/`, `systems/`, `entities/`

---

## 2026-03-01 — Phase 0: Structural Refactor

**Tasks:** 0.1, 0.2, 0.3, 0.4, 0.5 (PLAN-001)
**Model:** Opus 4.6

### Task 0.1 — Extract GameSession from `__main__.py`

- Created `core/session.py` — engine-agnostic `GameSession` class with all callbacks, state transitions, and system orchestration
- Created `core/config.py` — game constants (screen size, FPS, splash duration)
- Created `engine/startup.py` — pygame-specific splash screen and loading frame rendering
- Created `engine/image_utils.py` — centralised pygame image loading and transformation
- Reduced `__main__.py` from 488 lines to 87 lines (pygame init, engine setup, thin main loop)

### Task 0.2 — Separate CombatState UI from combat logic

- Created `ui/combat_ui.py` — CombatState (GameState subclass) with all rendering and interaction
- Stripped `systems/combat.py` to pure logic only: CombatShip, CombatLog, calculate_damage, dodge_chance
- `systems/combat.py` now has zero imports from `core.interfaces` or `core.state_machine`

### Task 0.3 — Fix Engine Abstraction Layer violations

- Added `draw_image()`, `get_image_size()`, `measure_text()` to `RenderInterface` in `core/interfaces.py`
- Implemented all three in `engine/renderer.py` (PygameRenderer)
- Removed `import pygame` from `ui/menu.py`, `ui/navigation.py`, `ui/dialogue_ui.py`, `ui/cutscene.py`
- All UI files now use `RenderInterface` methods exclusively (draw_image, get_image_size, measure_text)
- **Verification:** zero pygame imports in `core/`, `systems/`, `entities/`, `ui/`

### Task 0.4 — Add missing GameStateTypes, remove dead code

- Added `FACTION_SCREEN`, `SHIP_SCREEN`, `SETTINGS` to `GameStateType` enum
- Updated `ui/faction_screen.py` to use `GameStateType.FACTION_SCREEN`
- Updated `ui/ship_screen.py` to use `GameStateType.SHIP_SCREEN`
- Deleted unused `core/game_loop.py`

### Task 0.5 — GameStateData serialization

- Added `to_dict()` / `from_dict()` to `PlayerDecision` and `GameStateData`
- Fixed `Faction.from_dict()` to accept both `reputation_with_player` and `starting_reputation` keys
- Created `tests/test_game_state_serialization.py` — 5 tests covering fresh/modified round-trip, JSON serialization, faction and NPC registry persistence

### Test Results

- All 44 tests pass (27 original + 17 new/modified)
- All tests run headless without pygame display context

---

## 2026-03-01 — Step 1: Project Management Structure

**Task:** Step 1 (PLAN-001)
**Model:** Opus 4.6 (planning), Haiku (execution)

### Added

- `CLAUDE.md` — Project-level AI agent instructions with architecture rules and conventions
- `docs/CONTRIBUTING.md` — Task workflow guide for AI agents and developers
- `docs/plans/PLAN-001_Implementation_Master_Plan.md` — Full implementation plan (31 tasks across 6 phases)
- `docs/plans/PLAN-001_Task_Tracker.md` — Checkbox-based progress tracker for all tasks
- `docs/reviews/REVIEW_TEMPLATE.md` — Code review template with EAL compliance checklist
- `docs/reviews/REVIEW_LOG.md` — Master review log
- `docs/issues/ISSUE_TEMPLATE.md` — Issue reporting template
- `docs/issues/ISSUE_LOG.md` — Master issue index
- `docs/decisions/ADR_TEMPLATE.md` — Architecture Decision Record template
- `docs/decisions/ADR-001_Project_Structure_Refactor.md` — First ADR documenting the refactor rationale
- `docs/changelog/CHANGELOG.md` — This file

### Directory Structure

- Created archive directories for: plans, reviews, issues, decisions, PRDs, TRDs, design, story
- Created issue tracking directories: open, in-progress, closed
