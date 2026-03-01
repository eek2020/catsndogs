# PLAN-001 Task Tracker

**Plan:** Whisper Crystals Implementation Master Plan
**Created:** 2026-03-01
**Last Updated:** 2026-03-01

## Status Legend

- [ ] `pending` — Not yet started
- [x] `done` — Completed
- `in-progress` — Currently being worked on (marked with arrow -->)

---

## Step 1 — Project Management Structure

| Status | Task | Model | Depends On | Completed |
| ------ | ---- | ----- | ---------- | --------- |
| [x] | Create directory structure | Haiku | — | 2026-03-01 |
| [x] | Create CLAUDE.md | Haiku | — | 2026-03-01 |
| [x] | Create CONTRIBUTING.md | Haiku | — | 2026-03-01 |
| [x] | Create templates (review, issue, ADR) | Haiku | — | 2026-03-01 |
| [x] | Create task tracker (this file) | Haiku | — | 2026-03-01 |
| [x] | Create master plan document | Haiku | — | 2026-03-01 |
| [x] | Create changelog and ADR-001 | Haiku | — | 2026-03-01 |

---

## Phase 0 — Structural Refactor

| Status | Task | ID | Model | Depends On | Completed |
| ------ | ---- | -- | ----- | ---------- | --------- |
| [ ] | Extract GameSession from `__main__.py` | 0.1 | Opus 4.6 | Step 1 | — |
| [ ] | Separate CombatState UI from combat logic | 0.2 | Opus 4.6 | Step 1 | — |
| [ ] | Fix Engine Abstraction Layer violations | 0.3 | Opus 4.6 | Step 1 | — |
| [ ] | Add missing GameStateTypes, remove dead code | 0.4 | Sonnet | 0.3 | — |
| [ ] | GameStateData serialization (to_dict/from_dict) | 0.5 | Sonnet | Step 1 | — |

**Review required:** File `docs/reviews/REVIEW-001_phase0_refactor.md` after all Phase 0 tasks complete.

---

## Phase 1 — Core Infrastructure

| Status | Task | ID | Model | Depends On | Completed |
| ------ | ---- | -- | ----- | ---------- | --------- |
| [ ] | Save/Load Manager | 1.1 | Sonnet | 0.5 | — |
| [ ] | Wire Save/Load into UI | 1.2 | Sonnet | 0.1, 1.1 | — |
| [ ] | Pause Menu | 1.3 | Haiku | 0.1, 0.4 | — |
| [ ] | Settings Screen | 1.4 | Haiku | 1.3 | — |

---

## Phase 2 — Game Systems

| Status | Task | ID | Model | Depends On | Completed |
| ------ | ---- | -- | ----- | ---------- | --------- |
| [ ] | Economy System | 2.1 | Sonnet | Phase 0 | — |
| [ ] | Trade UI | 2.2 | Sonnet | 2.1 | — |
| [ ] | Exploration System | 2.3 | Sonnet | Phase 0 | — |
| [ ] | Crew Morale System | 2.4 | Sonnet | Phase 0 | — |
| [ ] | Faction Conquest AI | 2.5 | Sonnet | 2.1 | — |
| [ ] | Realm Control | 2.6 | Sonnet | 2.5 | — |

---

## Phase 3 — Content Pipeline

| Status | Task | ID | Model | Depends On | Completed |
| ------ | ---- | -- | ----- | ---------- | --------- |
| [ ] | Arc 2 Encounter Data | 3.1 | Sonnet | — | — |
| [ ] | Arc 3 Encounter Data | 3.2 | Sonnet | — | — |
| [ ] | Arc 4 Encounter Data | 3.3 | Sonnet | — | — |
| [ ] | Integration Tests for Arcs 2-4 | 3.4 | Sonnet | 3.1, 3.2, 3.3 | — |
| [ ] | Dialogue Data Files | 3.5 | Haiku | — | — |

---

## Phase 4 — Polish and Integration

| Status | Task | ID | Model | Depends On | Completed |
| ------ | ---- | -- | ----- | ---------- | --------- |
| [ ] | Audio Implementation | 4.1 | Sonnet | 0.3 | — |
| [ ] | Minimap in HUD | 4.2 | Haiku | — | — |
| [ ] | Ending Summary Screen | 4.3 | Sonnet | Phase 3 | — |
| [ ] | Difficulty Balance Pass | 4.4 | Sonnet | Phase 2, Phase 3 | — |

---

## Summary

| Phase | Total Tasks | Done | Remaining |
| ----- | ----------- | ---- | --------- |
| Step 1 | 7 | 7 | 0 |
| Phase 0 | 5 | 0 | 5 |
| Phase 1 | 4 | 0 | 4 |
| Phase 2 | 6 | 0 | 6 |
| Phase 3 | 5 | 0 | 5 |
| Phase 4 | 4 | 0 | 4 |
| **Total** | **31** | **7** | **24** |
