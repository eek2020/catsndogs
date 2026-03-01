# Whisper Crystals — Implementation Plan

## Context

The Whisper Crystals game has strong documentation (3 PRDs, 3 TRDs, design/story docs) and a working Arc 1 prototype. However, the codebase has structural issues that will compound as features are added. This plan delivers all remaining PRD features through a phased approach: first set up project management infrastructure, then refactor the foundation, then incremental feature delivery.

**Current state:** Arc 1 is fully playable. 27 tests pass. Core systems (combat, encounters, factions, narrative) all work. Data is well-structured JSON.

**Key problems:** `__main__.py` is a 488-line monolith. Several UI files import pygame directly (violating the Engine Abstraction Layer). Combat system mixes pure logic with UI rendering. `GameStateData` lacks serialization (blocks save/load). No content exists for Arcs 2-4.

---

## Step 1 — Project Management Structure

**Model:** Haiku | **Complexity:** Low | **Depends on:** Nothing

Create the directory structure and templates that all subsequent work depends on for tracking, reviews, and organisation.

### Directories to create

```text
docs/
  plans/                    # Implementation plans (active)
  plans/archive/            # Completed/superseded plans
  reviews/                  # Code review records (active)
  reviews/archive/          # Completed reviews
  issues/open/              # Active issues
  issues/in-progress/       # Issues being worked on
  issues/closed/            # Resolved issues
  changelog/                # Per-phase changelogs
  decisions/                # Architecture Decision Records (active)
  decisions/archive/        # Superseded ADRs
  prd/archive/              # Completed PRD versions
  trd/archive/              # Completed TRD versions
design/archive/             # Completed design docs
story/archive/              # Completed story docs
```

### Files to create

- `docs/plans/PLAN-001_Implementation_Master_Plan.md` — Full copy of this plan for in-project tracking
- `docs/plans/PLAN-001_Task_Tracker.md` — Checkbox-based task tracker with status, assignee model, dates
- `docs/reviews/REVIEW_TEMPLATE.md` — Code review template (files changed, test results, EAL compliance, issues found)
- `docs/reviews/REVIEW_LOG.md` — Master log linking to individual reviews
- `docs/issues/ISSUE_TEMPLATE.md` — Issue template (ID, severity, description, repro steps, linked task)
- `docs/issues/ISSUE_LOG.md` — Master index of all issues with status
- `docs/changelog/CHANGELOG.md` — Running changelog across all phases
- `docs/decisions/ADR_TEMPLATE.md` — Architecture Decision Record template (context, decision, consequences)
- `docs/decisions/ADR-001_Project_Structure_Refactor.md` — First ADR documenting why the refactor is needed
- `docs/CONTRIBUTING.md` — Guide for AI agents: how to pick up tasks, branch naming, review process, testing requirements
- `CLAUDE.md` — Project-level instructions for any AI agent working on this codebase

### Acceptance criteria

- All directories exist
- All templates are usable (not empty placeholders)
- Task tracker has every task from this plan listed with checkbox, status, model assignment, and dependencies
- CLAUDE.md contains project conventions, architecture rules, and file layout reference

---

## Step 2 — Phase 0: Structural Refactor (Opus 4.6)

> One coordinated session. Must complete before feature work begins.
> File a review in `docs/reviews/` after this phase.

### TASK 0.1 — Extract GameSession from `__main__.py`

- **Model:** Opus 4.6 | **Complexity:** High
- **Create:** `src/whisper_crystals/core/session.py` (GameSession class), `src/whisper_crystals/core/config.py` (constants)
- **Modify:** `src/whisper_crystals/__main__.py` — reduce to under 100 lines (pygame init, engine instantiation, thin main loop)
- **Move into GameSession:** All system init, all callback definitions, state machine management
- **Constraint:** GameSession must have zero pygame imports
- **Acceptance:** `__main__.py` under 100 lines. All 27 tests pass. Game runs identically.

### TASK 0.2 — Separate CombatState UI from combat logic

- **Model:** Opus 4.6 | **Complexity:** Medium
- **Modify:** `src/whisper_crystals/systems/combat.py` — keep only pure logic (CombatShip, CombatLog, calculate_damage, dodge_chance, CombatResolver)
- **Create:** `src/whisper_crystals/ui/combat_ui.py` — move CombatState(GameState) here
- **Acceptance:** `systems/combat.py` has zero imports from `core.interfaces`. Combat tests pass.

### TASK 0.3 — Fix Engine Abstraction Layer violations

- **Model:** Opus 4.6 | **Complexity:** Medium
- **Create:** `src/whisper_crystals/engine/image_utils.py`, `src/whisper_crystals/engine/asset_manager.py`
- **Modify:** `core/interfaces.py` — add `draw_image()` to RenderInterface
- **Modify:** `engine/renderer.py` — implement `draw_image()`
- **Modify:** `ui/navigation.py`, `ui/menu.py`, `ui/dialogue_ui.py`, `ui/cutscene.py` — remove all `import pygame`
- **Acceptance:** Zero pygame imports in `ui/`, `systems/`, `core/`.

### TASK 0.4 — Add missing GameStateTypes, remove dead code

- **Model:** Sonnet | **Complexity:** Low
- **Modify:** `core/state_machine.py` — add FACTION_SCREEN, SHIP_SCREEN, SETTINGS
- **Modify:** `ui/faction_screen.py`, `ui/ship_screen.py` — use correct state types
- **Delete or update:** `core/game_loop.py` (unused)
- **Acceptance:** Each UI state has its own GameStateType. No unused code.

### TASK 0.5 — GameStateData serialization

- **Model:** Sonnet | **Complexity:** Medium
- **Modify:** `src/whisper_crystals/core/game_state.py` — add `to_dict()` / `from_dict()`
- **Create:** `tests/test_game_state_serialization.py`
- **Acceptance:** Round-trip serialization produces identical output.

---

## Step 3 — Phase 1: Core Infrastructure

### TASK 1.1 — Save/Load Manager

- **Model:** Sonnet | **Depends on:** 0.5
- **Create:** `src/whisper_crystals/core/save_manager.py`, `tests/test_save_manager.py`
- **Acceptance:** 3 save slots. Human-readable JSON. Round-trip restores full state. Graceful error handling.

### TASK 1.2 — Wire Save/Load into UI

- **Model:** Sonnet | **Depends on:** 0.1, 1.1
- **Modify:** `ui/menu.py` — add Continue, Load Game options
- **Modify:** `core/session.py` — add `load_game(slot)`
- **Create:** `ui/save_load_screen.py`
- **Acceptance:** Menu shows Continue (greyed if no saves). Auto-save on arc transition.

### TASK 1.3 — Pause Menu

- **Model:** Haiku | **Depends on:** 0.1, 0.4
- **Create:** `ui/pause_menu.py`
- **Modify:** `ui/navigation.py` — ESC pushes PauseMenuState
- **Acceptance:** ESC pauses. Resume returns to exact state.

### TASK 1.4 — Settings Screen

- **Model:** Haiku | **Depends on:** 1.3
- **Create:** `ui/settings_screen.py`, `core/settings.py`
- **Acceptance:** Settings persist via `settings.json`. Text speed affects typewriter.

---

## Step 4 — Phase 2: Game Systems

> Parallelizable (except where noted). All must be engine-agnostic (zero pygame imports).

### TASK 2.1 — Economy System

- **Model:** Sonnet | **Depends on:** Phase 0
- **Create:** `systems/economy.py`, `tests/test_economy.py`
- **Acceptance:** Faction rep affects prices +/-25%. Crystal quality multiplies price.

### TASK 2.2 — Trade UI

- **Model:** Sonnet | **Depends on:** 2.1
- **Create:** `ui/trade_ui.py`
- **Acceptance:** Trade encounters launch TradeState. Price breakdown visible.

### TASK 2.3 — Exploration System

- **Model:** Sonnet | **Depends on:** Phase 0
- **Create:** `systems/exploration.py`, `data/exploration/deposits.json`, `tests/test_exploration.py`
- **Acceptance:** Deposits discoverable. Extraction rate based on quality.

### TASK 2.4 — Crew Morale System

- **Model:** Sonnet | **Depends on:** Phase 0
- **Create:** `systems/crew.py`, `tests/test_crew.py`
- **Acceptance:** Morale updates on events. Low (under 30) triggers warnings. High (over 80) grants combat bonus.

### TASK 2.5 — Faction Conquest AI

- **Model:** Sonnet | **Depends on:** 2.1
- **Create:** `systems/faction_ai.py`, `tests/test_faction_ai.py`
- **Acceptance:** AI ticks periodically. Can generate dynamic encounters.

### TASK 2.6 — Realm Control

- **Model:** Sonnet | **Depends on:** 2.5
- **Create:** `systems/realm_control.py`, `data/realms/realm_registry.json`
- **Acceptance:** Realms have faction control percentages. Combat and AI shifts control.

---

## Step 5 — Phase 3: Content Pipeline

> Arc data tasks are fully parallelizable. Follow `data/encounters/arc1_encounters.json` schema exactly.

### TASK 3.1 — Arc 2 Encounter Data

- **Model:** Sonnet
- **Create:** `data/encounters/arc2_encounters.json` (7 encounters)
- **Must set flags:** `arc2_route_resolved`, `arc2_death_betrayal`, `arc2_lion_response`, `arc2_priority`

### TASK 3.2 — Arc 3 Encounter Data

- **Model:** Sonnet
- **Create:** `data/encounters/arc3_encounters.json` (5+ encounters)
- **Must set flags:** `arc3_alien_contact`, `arc3_dave_parley`, `arc3_death_allegiance`

### TASK 3.3 — Arc 4 Encounter Data

- **Model:** Sonnet
- **Create:** `data/encounters/arc4_encounters.json` (5 encounters)

### TASK 3.4 — Integration Tests for Arcs 2-4

- **Model:** Sonnet | **Depends on:** 3.1, 3.2, 3.3
- **Create:** `tests/test_arc2_flow.py`, `tests/test_arc3_flow.py`, `tests/test_arc4_flow.py`, `tests/test_full_game_flow.py`
- **Acceptance:** Full game flow reaches all 3 endings.

### TASK 3.5 — Dialogue Data Files

- **Model:** Haiku
- **Create:** `data/dialogue/dave_dialogues.json`, `data/dialogue/death_dialogues.json`, `data/dialogue/aristotle_dialogues.json`
- **Acceptance:** 3+ dialogue trees per character. Conditional branches on flags and scores.

---

## Step 6 — Phase 4: Polish and Integration

### TASK 4.1 — Audio Implementation

- **Model:** Sonnet | **Depends on:** 0.3
- **Modify:** `engine/audio.py` — real PygameAudio implementation
- **Create:** `assets/audio/sfx/`, `assets/audio/music/` with placeholders

### TASK 4.2 — Minimap in HUD

- **Model:** Haiku
- **Modify:** `ui/hud.py` — add 150x150 minimap in bottom-right

### TASK 4.3 — Ending Summary Screen

- **Model:** Sonnet | **Depends on:** Phase 3
- **Create:** `ui/ending_screen.py`

### TASK 4.4 — Difficulty Balance Pass

- **Model:** Sonnet | **Depends on:** Phase 2 and Phase 3
- **Modify:** `systems/combat.py`, `data/encounters/*.json`, `data/ships/ship_templates.json`

---

## Dependency Graph

```text
Step 1: Project management structure (first, unblocks everything)

Phase 0 (Opus - sequential):
  0.1 --+
  0.2   +-- 0.3 -- 0.4
  0.5 --+

Phase 1 (after Phase 0):
  0.5 -> 1.1 -> 1.2
  0.1 -> 1.3 -> 1.4

Phase 2 (after Phase 0, parallelizable):
  2.1 -> 2.2
  2.1 -> 2.5 -> 2.6
  2.3 (independent)
  2.4 (independent)

Phase 3 (parallelizable, independent of Phase 2):
  3.1 -+
  3.2 -+-> 3.4
  3.3 -+
  3.5 (independent)

Phase 4 (after Phase 2 and 3):
  0.3 -> 4.1
  4.2 (independent)
  Phase 3 -> 4.3
  Phase 2 + 3 -> 4.4
```

## Model Assignment Summary

| Tier | Tasks | Rationale |
| ---- | ----- | --------- |
| Opus 4.6 | 0.1, 0.2, 0.3 | Cross-cutting refactors requiring holistic codebase understanding |
| Sonnet | 0.4, 0.5, 1.1, 1.2, 2.1-2.6, 3.1-3.4, 4.1, 4.3, 4.4 | Feature implementation with moderate complexity |
| Haiku | Step 1, 1.3, 1.4, 3.5, 4.2 | Small well-defined tasks following existing patterns |

## Verification

After each phase:

1. `pytest tests/ -v` — all tests pass
2. `python run.py` — game launches and Arc 1 is playable
3. No pygame imports in `core/`, `systems/`, or `entities/` directories
4. After Phase 3 and 4: full 4-arc playthrough reaches all 3 endings
5. Task tracker updated, review filed, changelog entry added
