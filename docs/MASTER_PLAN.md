# Whisper Crystals — Master Plan

**Date:** 2026-04-05
**Status:** Authoritative — single source of truth for project planning
**Supersedes:** `docs/archive/plans/MASTER_PLAN_2026-03-20.md`, all previous plan documents

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
| EventBus | 120+ pub/sub signals for decoupled communication |
| GameSession | Master orchestrator — owns all 22 systems and game state |
| MusicManager | Dynamic BGM, SFX, arc-specific themes |
| ProceduralMapManager | Procedural navigation/star map backdrops |

### Codebase Metrics

| Metric | Count |
| ------ | ------- |
| GDScript files | ~60 |
| Scene files (.tscn) | ~30 |
| Entity classes | 8 |
| Game systems | 22 |
| UI screens | 23 |
| JSON data files | ~75 |
| EventBus signals | 120+ |
| SpriteFrames resources | 16 |
| Shaders | 2 |
| Addon | 1 (procedural_world_map) |

---

## 3. Architecture Summary

See `STRUCTURE.md` for the full signal map, system table, and scene inventory.

**Key patterns:**

- **Systems** are `RefCounted` objects owned by `GameSession` (no scene-tree presence)
- **Entities** are `Resource` subclasses with full `to_dict()`/`from_dict()` serialization
- **UI scenes** are stateless views that read from `GameSession.game_state` and call system methods
- **All inter-system communication** goes through `EventBus` signals
- **All narrative/game content** lives in JSON under `godot/data/` — never hardcoded in scripts

**Data flow:** User input > UI controller > GameSession system method > GameStateData mutation > EventBus signal > UI/system reactions

---

## 4. Open Issues (from CODE_REVIEW_2026-04-05)

18 issues identified. Priority breakdown:

### Must-Fix (Critical)

| ID | Issue | File | Description |
| ---- | ------- | ------ | ------------- |
| 1 | trigger_encounter_id never evaluated | encounter_engine.gd | Encounter chain field silently ignored — breaks chained encounters, potential infinite loop risk |
| 2 | Hull death not emitted | astral_hazard_system.gd | `apply_damage()` does not emit game-over when hull reaches 0 |

### Should-Fix (High/Medium)

| ID | Issue | Priority |
| ---- | ------- | ---------- |
| 3 | GameSession tight coupling in static methods | High |
| 4 | DataLoader cache never invalidated | High |
| 5 | Exploration state not persisted in save/load | High |
| 6 | CrewTraitSystem iterates all crew per lookup | Medium |
| 7 | Per-pixel portrait processing on every dialogue open | Medium |
| 8 | Combat loot magic numbers | Medium |
| 9 | crystal_pickup signal arity mismatch | Medium |
| 10 | _remove_near_white_bg whiteness metric | Medium |
| 11 | faction_system bypasses its parameter | Medium |
| 12 | Redundant DataLoader calls | Medium |
| 13 | No crew capacity enforcement | Medium |
| 14 | Save manager no integrity verification | Medium |
| 15 | _migrate_save_data is a stub | Medium |

### Low Priority

| ID | Issue | Priority |
| ---- | ------- | ---------- |
| 16 | Encounter priority re-sorted every check | Low |
| 17 | conditions field loaded but never evaluated | Low |
| 18 | Playtime includes menu/pause | Low |

Full details: `docs/CODE_REVIEW_2026-04-05.md`

---

## 5. Technical Debt Inventory

### From Current Codebase

| Area | Description | Priority |
| ------ | ------------- | ---------- |
| God script | `navigation.gd` is 800+ lines — consider decomposition | Low |
| Cache management | DataLoader cache is unbounded, no invalidation | Medium |
| Save integrity | No checksum/HMAC on save files (low risk for single-player) | Low |
| Trade ledger | `trade_ledger` in GameStateData is unbounded | Low |
| Test coverage | No automated tests in the Godot project (example test harness exists but no CI) | Medium |
| Exploration persistence | Exploration state (discovered regions, visited POIs) not saved | High |

### Engine/Addon Dependencies

| Dependency | Version | Risk |
| ------ | --------- | ------ |
| Godot | 4.6 | Stable — GL Compatibility renderer avoids Vulkan issues on older hardware |
| procedural_world_map addon | 1.0 (vendored) | Low — MIT licensed, vendored in `addons/`, no external dependency |

---

## 6. Active Initiatives

### 6.1 Critical Bug Fixes (Immediate)

Fix the 2 critical issues from the April 2026 code review:

1. Evaluate `trigger_encounter_id` in encounter chain outcomes
2. Emit game-over signal when hull reaches 0 from astral hazard damage

### 6.2 Save System Hardening

- Persist exploration state (discovered regions, visited POIs) in save data
- Implement `_migrate_save_data()` for version-aware save loading
- Add save file integrity check (optional)

### 6.3 Visual Polish — Remaining Sprite Work

From the original PLAN-003 (sprite character & visual identity):

| Status | Task |
| -------- | ------ |
| Done | Sprite asset manager, faction ship sprites, combat ship sprites |
| Todo | Character portraits in all dialogues (faction-coloured frames) |
| Todo | Faction-themed UI panels |
| Todo | Region-specific space backgrounds (colour-temperature tinting) |
| Todo | Crystal visual effects (HUD glow, deposit POI, engine chamber) |

### 6.4 Expansion Content Integration-Testing

The 10-arc story expansion (Arcs 5-10) has JSON encounter/side mission data but has not been:

- Played through end-to-end
- Tested for story flag consistency
- Verified for arc transition correctness
- Balanced for difficulty

### 6.5 Difficulty Balance Pass

Tune combat parameters, encounter data, and ship templates for a satisfying difficulty curve.

---

## 7. Future Roadmap

### Tier 1 — Low Effort, High Impact

1. **Live World News** — Subscribe to FactionConquestSystem events; queue "subspace radio intercepts" to HUD
2. **CI/CD Pipeline** — Headless Godot export via GitHub Actions

### Tier 2 — Medium Effort, High Impact

1. **Wanted / Notoriety System** — Patrol encounters based on player notoriety per faction
2. **Automated Testing** — Port the example test harness to a proper GUT/GdUnit4 test suite

### Tier 3 — Medium Effort, Medium Impact

1. **Tavern / Station Hub with Rumors** — Information economy, purchased rumors unlock encounters
2. **Black Market / Smuggling** — Hidden trade nodes, contraband cargo checks
3. **Astral Dice (Gambling Mini-Game)** — Self-contained dice game; "Death plays dice" encounter

---

## 8. Documentation Index

| Document | Location | Purpose |
| ------ | ---------- | --------- |
| Architecture rules | `CLAUDE.md` | Non-negotiable rules for all contributors |
| Architecture reference | `STRUCTURE.md` | Scenes, signals, systems, entities, data files |
| Game design summary | `docs/GAME_SUMMARY.md` | Complete game world, story, mechanics (implemented + planned) |
| Agent briefing | `AGENT_BRIEFING.md` | Full onboarding document for AI agents |
| Latest code review | `docs/CODE_REVIEW_2026-04-05.md` | 18 open issues with priorities |
| Previous code review | `docs/CODE_REVIEW_2026-03-27.md` | Historical — most issues resolved |
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
