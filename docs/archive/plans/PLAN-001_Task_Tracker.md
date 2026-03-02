> **ARCHIVED — 2026-03-02 — STATUS: SUPERSEDED**
>
> This task tracker is for the original PLAN-001 (Phases 0–3, completed; Phase 4, pending).
> Phase 4 tasks are now tracked in `docs/MASTER_PLAN.md`.
> PLAN-002 tasks are also tracked in `docs/MASTER_PLAN.md`.

---

# PLAN-001 Task Tracker

**Plan:** Whisper Crystals Implementation Master Plan
**Created:** 2026-03-01
**Last Updated:** 2026-03-01 (Phase 0 completed)

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
| [x] | Extract GameSession from `__main__.py` | 0.1 | Opus 4.6 | Step 1 | 2026-03-01 |
| [x] | Separate CombatState UI from combat logic | 0.2 | Opus 4.6 | Step 1 | 2026-03-01 |
| [x] | Fix Engine Abstraction Layer violations | 0.3 | Opus 4.6 | Step 1 | 2026-03-01 |
| [x] | Add missing GameStateTypes, remove dead code | 0.4 | Opus 4.6 | 0.3 | 2026-03-01 |
| [x] | GameStateData serialization (to_dict/from_dict) | 0.5 | Opus 4.6 | Step 1 | 2026-03-01 |

**Review required:** File `docs/reviews/REVIEW-001_phase0_refactor.md` after all Phase 0 tasks complete.

---

## Phase 1 — Core Infrastructure

| Status | Task | ID | Model | Depends On | Completed |
| ------ | ---- | -- | ----- | ---------- | --------- |
| [x] | Save/Load Manager | 1.1 | Opus 4.6 | 0.5 | 2026-03-01 |
| [x] | Wire Save/Load into UI | 1.2 | Opus 4.6 | 0.1, 1.1 | 2026-03-01 |
| [x] | Pause Menu | 1.3 | Opus 4.6 | 0.1, 0.4 | 2026-03-01 |
| [x] | Settings Screen | 1.4 | Opus 4.6 | 1.3 | 2026-03-01 |

---

## Phase 2 — Game Systems

| Status | Task | ID | Model | Depends On | Completed |
| ------ | ---- | -- | ----- | ---------- | --------- |
| [x] | Economy System | 2.1 | Opus 4.6 | Phase 0 | 2026-03-01 |
| [x] | Trade UI | 2.2 | Opus 4.6 | 2.1 | 2026-03-01 |
| [x] | Exploration System | 2.3 | Opus 4.6 | Phase 0 | 2026-03-01 |
| [x] | Crew Morale System | 2.4 | Opus 4.6 | Phase 0 | 2026-03-01 |
| [x] | Faction Conquest AI | 2.5 | Opus 4.6 | 2.1 | 2026-03-01 |
| [x] | Realm Control | 2.6 | Opus 4.6 | 2.5 | 2026-03-01 |

---

## Phase 3 — Content Pipeline

| Status | Task | ID | Model | Depends On | Completed |
| ------ | ---- | -- | ----- | ---------- | --------- |
| [x] | Arc 2 Encounter Data | 3.1 | Sonnet | — | 2026-03-01 |
| [x] | Arc 3 Encounter Data | 3.2 | Sonnet | — | 2026-03-01 |
| [x] | Arc 4 Encounter Data | 3.3 | Sonnet | — | 2026-03-01 |
| [x] | Integration Tests for Arcs 2-4 | 3.4 | Sonnet | 3.1, 3.2, 3.3 | 2026-03-01 |
| [x] | Dialogue Data Files | 3.5 | Haiku | — | 2026-03-01 |

---

## Phase 4 — Polish and Integration

> **These tasks are tracked in `docs/MASTER_PLAN.md` as of 2026-03-02.**

| Status | Task | ID | Model | Depends On | Completed |
| ------ | ---- | -- | ----- | ---------- | --------- |
| [ ] | Music System (BGM playback, track transitions, per-state themes) | 4.1 | Sonnet | 0.3 | — |
| [ ] | Sound Effects System (SFX triggers, event-bus integration, volume control) | 4.1b | Sonnet | 4.1 | — |
| [ ] | Minimap in HUD | 4.2 | Haiku | — | — |
| [ ] | Ending Summary Screen | 4.3 | Sonnet | Phase 3 | — |
| [ ] | Difficulty Balance Pass | 4.4 | Sonnet | Phase 2, Phase 3 | — |

---

## Summary

| Phase | Total Tasks | Done | Remaining |
| ----- | ----------- | ---- | --------- |
| Step 1 | 7 | 7 | 0 |
| Phase 0 | 5 | 5 | 0 |
| Phase 1 | 4 | 4 | 0 |
| Phase 2 | 6 | 6 | 0 |
| Phase 3 | 5 | 5 | 0 |
| Phase 4 | 5 | 0 | 5 — see MASTER_PLAN.md |
| **Total** | **32** | **23** | **9** |
