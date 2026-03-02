# Implementation Plan — Code Review Remediation

**Source:** `CODE_REVIEW_2026-03-02.md`
**Date:** 2026-03-02
**Implementer:** Claude Opus 4.6

---

## Execution Order Overview

1. **BUG-1** — Shadow DataLoader in Economy (Critical)
2. **BUG-3** — Morale Modifier Runaway Drift (Critical)
3. **BUG-2** — `completed_encounters` Unbounded Growth (Medium)
4. **R-5** — Validate `target_stat` Before `setattr` (Medium)
5. **BUG-6** — Missing `EventBus` Import in `menu.py` (Low)
6. **R-1** — Extract `_morale_label()` Helper (Low)
7. **R-2** — Deduplicate Encounter Sorting/Filtering (Low)
8. **R-3** — Add `clear()` to `GameStateMachine` (Low)
9. **R-4** — Error Resilience in `EventBus.publish` (Low)
10. **R-13** — Move Stray Imports (`__main__.py`, `hud.py`) (Low)
11. **Tests** — Add tests for `purchase_upgrade`, `purchase_ship`, and fixes

---

# Detailed Fix Plan

## BUG-1 — Shadow DataLoader in Economy

- **Severity:** Critical
- **Category:** Architecture / Runtime Failure
- **Files Affected:** `systems/economy.py`, `core/session.py`
- **Change Strategy:** Add `data_loader` parameter to `EconomySystem.__init__()`. Remove inline `DataLoader()` instantiations from `purchase_upgrade()` and `purchase_ship()`. Use `self.data_loader` instead. Update `GameSession` to pass its `data_loader` when constructing `EconomySystem`.
- **Test Impact:** Existing tests need fixture updated. New tests for `purchase_upgrade`/`purchase_ship`.
- **Risk Level:** Low (well-scoped dependency injection)
- **Rollback Plan:** Revert two files.

## BUG-3 — Morale Modifier Applied on Every Delta

- **Severity:** Critical
- **Category:** Logic Bug
- **Files Affected:** `systems/crew_morale.py`
- **Change Strategy:** Change `morale_modifier` to scale the delta rather than being added unconditionally. New formula: `member.morale + int(delta * (1 + member.morale_modifier / 10))`. This means a modifier of +2 gives +20% to morale changes, -2 gives -20%. This preserves the intent (some crew are more/less resilient) while preventing runaway drift from idle ticks.
- **Test Impact:** Existing tests may need threshold adjustments.
- **Risk Level:** Low (localized change, one line)
- **Rollback Plan:** Revert formula.

## BUG-2 — `completed_encounters` Unbounded Growth

- **Severity:** Medium
- **Category:** Performance / Memory
- **Files Affected:** `systems/encounter_engine.py`
- **Change Strategy:** Guard the append: only add encounter_id if not already present. This prevents duplicates for repeatable encounters while preserving the list type (set would require serialization changes).
- **Test Impact:** None (behavior preserved for non-repeatable encounters).
- **Risk Level:** Low

## R-5 — Validate `target_stat` Before `setattr`

- **Severity:** Medium
- **Category:** Security / Data Validation
- **Files Affected:** `systems/economy.py`, `entities/ship.py`
- **Change Strategy:** Add `VALID_UPGRADE_STATS` frozenset to `ShipStats`. Validate `target_stat` against it before calling `setattr` in `purchase_upgrade()` and `purchase_ship()`.
- **Test Impact:** New test for invalid `target_stat`.
- **Risk Level:** Low

## BUG-6 — Missing EventBus Import in `menu.py`

- **Severity:** Low
- **Category:** Import / Type Safety
- **Files Affected:** `ui/menu.py`
- **Change Strategy:** Add `EventBus` to the `TYPE_CHECKING` import block.
- **Test Impact:** None.
- **Risk Level:** Low

## R-1 — Extract `_morale_label()` Helper

- **Severity:** Low
- **Category:** Code Quality / Redundancy
- **Files Affected:** `systems/crew_morale.py`
- **Change Strategy:** Create `_morale_label(value: int) -> str` module-level function. Refactor `get_morale_status()` and `get_crew_by_morale()` to use it.
- **Test Impact:** None (behavior preserved).
- **Risk Level:** Low

## R-2 — Deduplicate Encounter Sorting/Filtering

- **Severity:** Low
- **Category:** Code Quality / Redundancy
- **Files Affected:** `systems/encounter_engine.py`
- **Change Strategy:** Extract `_get_eligible_encounters(game_state)` private method. `check_triggers()` returns first result. `get_available_encounters()` returns full list.
- **Test Impact:** None (behavior preserved).
- **Risk Level:** Low

## R-3 — Add `clear()` to `GameStateMachine`

- **Severity:** Low
- **Category:** Robustness
- **Files Affected:** `core/state_machine.py`, `core/session.py`
- **Change Strategy:** Add `clear()` method that calls `exit()` on the top state only, then clears the stack. Update `_quit_to_menu()` to use it.
- **Test Impact:** None.
- **Risk Level:** Low

## R-4 — Error Resilience in `EventBus.publish`

- **Severity:** Low
- **Category:** Robustness
- **Files Affected:** `core/event_bus.py`
- **Change Strategy:** Wrap each callback in try/except, log exceptions, continue to next subscriber.
- **Test Impact:** New test for exception handling.
- **Risk Level:** Low

## R-13 — Move Stray Imports

- **Severity:** Low
- **Category:** Style
- **Files Affected:** `__main__.py`, `ui/hud.py`
- **Change Strategy:** Move `import math` to top of `hud.py`. Move `setup_logging` import to top of `__main__.py`.
- **Test Impact:** None.
- **Risk Level:** Low

---

# Deferred / Roadmap Items

1. **ARCH-1** (God object `GameSession`) — Requires architectural discussion. Decomposition into `StateTransitionManager`, `CombatFlowController`, `LoadFlowController` is significant refactoring scope.
2. **PERF-1** (`remove_near_white_bg` pixel loop) — Engine-specific optimization. Low priority since it runs only at startup.
3. **R-6** (Cache rotated nebula) — Engine-layer optimization, deferred to Phase 4 polish.
4. **R-7** (Pre-render starfield) — Engine-layer optimization, deferred to Phase 4 polish.
5. **R-8** (Convert `completed_encounters` to set) — Would require serialization changes across `GameStateData.to_dict/from_dict` and `SaveManager`. Guard-on-append is safer for now.
6. **R-9** (Theme constants module) — Good idea but broad scope. Deferred.
7. **R-10** (Integrate SideMission) — Already tracked in PLAN-002.
8. **R-11/R-12** (UI tests, GameSession integration tests) — Large effort, tracked separately.
9. **R-14** (JSON schema validation in DataLoader) — Nice-to-have, deferred.
10. **BUG-4** (`_quit_to_menu` enter/exit churn) — Addressed by R-3 (`clear()` method).
11. **BUG-5** (Arc title text centering) — Requires `measure_text` on RenderInterface; deferred to avoid interface changes.

---

# Settings

- **Scope:** High + Critical issues, plus low-effort improvements
- **Risk Tolerance:** Low
- **Refactor Allowance:** Limited (dedup helpers only)
- **Add Tests:** Mandatory for bug fixes
- **Output Format:** File-by-file edits

---

# Implementation Summary

- **Total Issues Addressed:** 11
- **Critical Issues Resolved:** 2 (BUG-1, BUG-3)
- **Tests Added:** 24 new tests in `tests/test_code_review_fixes.py`
- **Breaking Changes:** None
- **Total Tests:** 186 (all passing)
- **EAL Verification:** Pass (zero pygame imports in core/systems/entities)

---

# Review → Fix Mapping

| Issue ID | Title | Files Modified | Change Summary | Tests Updated |
|----------|-------|---------------|---------------|--------------|
| BUG-1 | Shadow DataLoader in Economy | `economy.py`, `session.py` | Inject DataLoader via constructor; remove inline instantiation | Yes (4 tests) |
| BUG-2 | completed_encounters unbounded growth | `encounter_engine.py` | Guard append with membership check | Yes (1 test) |
| BUG-3 | morale_modifier runaway drift | `crew_morale.py` | Scale delta by modifier instead of flat addition | Yes (4 tests) |
| BUG-4 | _quit_to_menu enter/exit churn | `session.py` | Use new `clear()` method | Covered by R-3 |
| BUG-6 | Missing EventBus import in menu.py | `menu.py` | Add to TYPE_CHECKING block | Yes (1 test) |
| R-1 | Duplicate morale label logic | `crew_morale.py` | Extract `_morale_label()` helper | Yes (5 tests) |
| R-2 | Duplicate encounter filtering | `encounter_engine.py` | Extract `_get_eligible_encounters()` | Yes (2 tests) |
| R-3 | GameStateMachine missing clear() | `state_machine.py`, `session.py` | Add `clear()`, update `_quit_to_menu` | Yes (3 tests) |
| R-4 | EventBus publish error resilience | `event_bus.py` | try/except with logging around callbacks | Yes (2 tests) |
| R-5 | Unsafe setattr without validation | `economy.py`, `ship.py` | Validate target_stat against ShipStats fields | Yes (2 tests) |
| R-13 | Stray imports | `__main__.py`, `hud.py` | Move imports to top of file | No |

---

# Testing Notes

Commands to run:
```
python3 -m pytest tests/ -v
grep -r "import pygame" src/whisper_crystals/core/ src/whisper_crystals/systems/ src/whisper_crystals/entities/
```

Expected outcomes:
- All 186 tests pass
- Zero pygame imports in core/systems/entities (EAL clean)
- No lint errors
