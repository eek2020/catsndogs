# ADR-001: Project Structure Refactor Before Feature Work

**Status:** Accepted
**Date:** 2026-03-01
**Linked Task:** Phase 0 (Tasks 0.1 through 0.5)

---

## Context

The Whisper Crystals prototype has a fully playable Arc 1 with 27 passing tests. However, the codebase has accumulated structural issues during rapid prototyping that will compound as features are added:

1. **`__main__.py` is a 488-line monolith** containing all game wiring, system initialization, callback definitions, splash screen rendering, and the main loop. This makes it impossible to test the game session logic independently and creates a single point of fragility.

2. **Engine Abstraction Layer (EAL) violations** exist in multiple UI files (`navigation.py`, `menu.py`, `dialogue_ui.py`, `cutscene.py`) which directly `import pygame` for image loading, scaling, and screen blitting. This violates the core architecture principle (TRD-001 Section 3) and would block a clean migration to Godot/Unity.

3. **`systems/combat.py` mixes concerns** — it contains both pure combat logic (damage calculation, dodge chance) and the `CombatState` UI class with full rendering code. The systems layer should be engine-agnostic.

4. **`GameStateData` lacks serialization** — every entity has `to_dict()`/`from_dict()` but the master game state container does not, blocking the save/load feature chain.

5. **Image utility functions are duplicated** in three files with slightly different implementations.

6. **`GameLoop` class in `core/game_loop.py` is unused** — the actual game loop runs in `__main__.py`.

## Decision

Perform a coordinated structural refactor (Phase 0) before any new feature work begins. This refactor will:

1. Extract a `GameSession` class from `__main__.py` into `core/session.py`
2. Separate `CombatState` UI into `ui/combat_ui.py`, keeping pure logic in `systems/combat.py`
3. Add `draw_image()` to `RenderInterface` and remove all pygame imports from UI files
4. Consolidate image utilities into `engine/image_utils.py`
5. Add missing `GameStateType` entries and remove dead code
6. Add `to_dict()`/`from_dict()` to `GameStateData`

Phase 0 is assigned to Opus 4.6 (tasks 0.1-0.3) because the changes are cross-cutting and require holistic codebase understanding.

## Alternatives Considered

| Alternative | Pros | Cons |
| ----------- | ---- | ---- |
| Refactor incrementally alongside features | No upfront delay | EAL violations spread further; harder to fix later; save/load blocked |
| Skip refactor, build features on current base | Faster initial feature delivery | Technical debt compounds; migration-readiness degrades; testing becomes harder |
| Full rewrite | Clean slate | Loses working Arc 1; violates vibe coding philosophy; massive risk |

## Consequences

### Positive

- Clean separation of concerns enables independent feature development
- EAL compliance maintained — future Godot/Unity migration stays viable
- `GameSession` is testable without a pygame display
- Save/load feature chain is unblocked
- Smaller models can safely work on features without accidentally breaking architecture

### Negative

- Upfront time investment before new features appear
- All 27 existing tests must continue to pass through the refactor
- UI files will need to use the abstraction layer which adds a small indirection

### Risks

- **Risk:** Refactor introduces regressions in the playable Arc 1.
  **Mitigation:** All tests must pass after each task. Manual play-test after Phase 0 complete.

- **Risk:** `draw_image()` abstraction does not cover all current pygame surface usage.
  **Mitigation:** Audit all `renderer.screen` accesses before designing the interface method.

## Follow-Up Actions

- [x] Create project management structure (Step 1)
- [x] Execute Phase 0 tasks 0.1 through 0.5
- [x] File code review (REVIEW-001) after Phase 0
- [x] Run full test suite and manual play-test
