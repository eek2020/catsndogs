> **ARCHIVED — 2026-03-02 — STATUS: COMPLETED**
>
> **Completion Summary:**
> All MUST HAVE requirements are implemented. SHOULD HAVE requirements are partially complete.
> COULD HAVE requirements (collaboration web app) are intentionally deferred.
>
> | Section | Status | Notes |
> |---------|--------|-------|
> | Core Game Loop (REQ-010–015) | ✅ Complete | Navigation, encounter trigger, decision phase, outcome phase, arc progression, state machine all implemented |
> | Ship System (REQ-020–025) | ✅ Partial | Stats, faction profiles, damage model, upgrade system done. Fleet capture (COULD HAVE) not implemented. |
> | Encounter System — Combat (REQ-030–032) | ✅ Complete | CombatState with full combat flow |
> | Encounter System — Trade (REQ-033–035) | ✅ Complete | TradeScreenState with faction pricing |
> | Encounter System — Diplomatic (REQ-036–038) | ✅ Complete | DialogueState with branching trees |
> | Encounter System — Exploration (REQ-039–041) | ✅ Complete | ExplorationSystem with regions and POIs |
> | UI/UX (REQ-050–056) | ✅ Complete | All 7 UI requirements delivered (menu, HUD, dialogue, trade, faction screen, ship screen, pause menu) |
> | Save/Load (REQ-060–064) | ✅ Complete | SaveManager with 3 slots, atomic writes, settings persistence, version validation |
> | Collaboration Web App (REQ-070–075) | ⬜ Deferred | COULD HAVE — game state is JSON-serializable (REQ-005 satisfied); web UI not built |
>
> **Deviations from original scope:**
> - Ship capture (PRD001-REQ-025) not implemented — COULD HAVE priority, deferred
> - Fleet management UI (PRD001-REQ-024) — ships and fleet roster implemented in entities/data; fleet UI accessible via ship screen
> - Auto-save on arc transitions implemented (REQ-062 ✅); separate auto-save slot not yet distinct from manual slots

---

# PRD-001: Game Overview & Feature Requirements

**Project:** Whisper Crystals — A Space Pirates Game
**Version:** 0.1
**Date:** February 2026
**Classification:** Creative Development — Confidential

---

## Section 1: Product Overview

Whisper Crystals is a narrative-driven 2D side-scrolling space pirate game inspired by the Spelljammer D&D setting. The player commands Aristotle, a self-made cat pirate captain who controls the universe's only known source of starship fuel — Whisper Crystals. The game spans a multiverse of colliding factions from fantasy, sci-fi, and myth, all competing for control of this resource.

---

## Section 2: Goals & Success Criteria (MoSCoW)

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD001-REQ-001 | Deliver a playable 2D prototype in Python/Pygame demonstrating core game loop, narrative choice, and faction interaction | MUST HAVE | Player can navigate space, trigger encounters, make narrative choices, and observe faction relationship changes across a minimum of one complete story arc |
| PRD001-REQ-002 | Establish a codebase architecture that can migrate cleanly to Godot or Unity in a future phase | SHOULD HAVE | All game logic is engine-agnostic; no Pygame-specific logic exists in core game systems; module interfaces are documented |
| PRD001-REQ-003 | Create a rich, character-driven narrative with meaningful player choices across 4 story arcs | MUST HAVE | All 4 arcs are playable; minimum 2 decision points per arc; 3 distinct endings are reachable based on cumulative choice history |
| PRD001-REQ-004 | Build a commodity economy system around Whisper Crystals that drives all political and conflict mechanics | MUST HAVE | Crystal inventory, supply/demand pricing, trade encounters, and faction standing changes are functional and observable in-game |
| PRD001-REQ-005 | Support future web-based collaboration tooling for co-development and shared game state visibility | COULD HAVE | Game state is serialisable to JSON; API hooks are stubbed but not implemented in Phase 1 |

---

## Section 3: Out of Scope (Phase 1)

| Item | MoSCoW | Notes |
|------|--------|-------|
| 3D graphics or 3D game engine | WON'T HAVE | Deferred to Phase 2+ |
| Multiplayer or online play | WON'T HAVE | Potential Phase 3 |
| Mobile platform builds | WON'T HAVE | Desktop only in Phase 1 |
| Full voice acting or orchestral soundtrack | WON'T HAVE | Placeholder audio acceptable |
| Unity or Godot migration | WON'T HAVE | Evaluation only; no porting work in Phase 1 |

---

## Section 4: Core Game Loop Requirements

The core loop is: **Navigate space → Encounter event → Make decision → Outcome affects state → Progress arc → Repeat**

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD001-REQ-010 | Space Navigation Phase: Player controls Aristotle's ship in a 2D side-scrolling space environment, moving between regions and realms | MUST HAVE | Ship responds to player input (move, accelerate, brake); regions are traversable; realm boundaries trigger transition events |
| PRD001-REQ-011 | Encounter Trigger Phase: Movement through space triggers encounter events based on location, story state, and random encounter tables | MUST HAVE | Encounters fire based on data-driven trigger conditions; encounter type (combat/trade/diplomacy/exploration) is correctly dispatched |
| PRD001-REQ-012 | Decision Phase: Player is presented with context-appropriate choices during encounters | MUST HAVE | Minimum 2 choices per encounter; choices are presented via UI; selection is recorded in choice history |
| PRD001-REQ-013 | Outcome Phase: Player decisions modify game state — resources, faction relationships, story flags | MUST HAVE | Resource quantities update correctly; faction scores change; story flags are set; changes persist across encounters |
| PRD001-REQ-014 | Arc Progression Phase: Cumulative state changes trigger arc transitions when entry/exit conditions are met | MUST HAVE | Arc transitions fire when conditions are met; player receives narrative feedback on arc change; new arc content becomes available |
| PRD001-REQ-015 | Loop Continuity: The game loop is the central orchestrator; all phases are managed via an explicit state machine | MUST HAVE | Game states (MENU, NAVIGATION, ENCOUNTER, CUTSCENE, END) are distinct; transitions are clean with no orphaned state |

---

## Section 5: Ship System Requirements

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD001-REQ-020 | Ship Stats: Each ship has Speed, Armour, Firepower, Crystal Capacity, and Crew Capacity attributes | MUST HAVE | All 5 stats are displayed in ship HUD; stats affect gameplay calculations |
| PRD001-REQ-021 | Faction Ship Profiles: Cat ships are fast/low-armour/high-manoeuvrability; Dog ships are bulky/heavy-armour/high-firepower | MUST HAVE | Ship stat templates exist per faction; faction ships are visually and mechanically distinct |
| PRD001-REQ-022 | Damage Model: Ships take damage to hull and systems during combat encounters; damage reduces stat effectiveness | MUST HAVE | Damage is calculated per-hit; damaged ships show reduced stats; ships can be destroyed (0 hull) |
| PRD001-REQ-023 | Upgrade System: Ships can be upgraded between encounters using resources (crystals, salvage) | SHOULD HAVE | Upgrade options are available at friendly ports; upgrades modify base stats; upgrades persist in save data |
| PRD001-REQ-024 | Fleet Management: Player can acquire additional ships and assign crew across the fleet | SHOULD HAVE | Fleet roster UI shows all owned ships; crew assignment affects ship performance; fleet state persists |
| PRD001-REQ-025 | Ship Capture: Enemy ships can be captured during combat encounters and added to fleet | COULD HAVE | Capture is available as a combat outcome; captured ships inherit damage state; faction reputation changes on capture |

---

## Section 6: Encounter System Requirements

### 6.1 Combat Encounters

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD001-REQ-030 | Combat Trigger: Combat encounters fire when entering hostile territory, being intercepted by enemy faction ships, or as story-scripted events | MUST HAVE | Trigger conditions are data-driven; combat state initialises with correct combatants |
| PRD001-REQ-031 | Combat Interaction: Side-scrolling space combat where player fires weapons, dodges projectiles, and can attempt boarding actions | MUST HAVE | Player controls ship movement and weapons; enemy AI manoeuvres and fires; boarding is available at close range |
| PRD001-REQ-032 | Combat Outcomes: Victory yields loot/salvage and faction standing changes; defeat results in resource loss and potential ship damage; flee is an option with cost | MUST HAVE | Victory/defeat/flee states are implemented; resource and faction changes apply correctly post-combat |

### 6.2 Trade Encounters

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD001-REQ-033 | Trade Trigger: Trade encounters fire at trade posts, friendly ports, or when hailed by merchant vessels | MUST HAVE | Trade UI opens with correct inventory for both parties |
| PRD001-REQ-034 | Trade Interaction: Negotiation UI with offer/counter-offer mechanic on Whisper Crystal supply and other commodities; faction relationship affects base pricing | MUST HAVE | Player can propose trades; NPC counter-offers; faction standing modifies prices by ±25% |
| PRD001-REQ-035 | Trade Outcomes: Successful trades modify crystal inventory and faction standing; refused trades may escalate to diplomatic or combat encounters | MUST HAVE | Inventory updates on trade completion; faction scores adjust; failed trades can trigger follow-up encounters |

### 6.3 Diplomatic Encounters

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD001-REQ-036 | Diplomatic Trigger: Diplomatic encounters fire at faction capitals, during story beats, or when faction standing crosses thresholds | MUST HAVE | Dialogue tree UI opens with correct NPC and context |
| PRD001-REQ-037 | Diplomatic Interaction: Choice-driven dialogue trees where player selects from 2–4 response options; outcomes affect faction standing and story flags | MUST HAVE | Dialogue options reflect current game state; selections are recorded in choice history |
| PRD001-REQ-038 | Diplomatic Outcomes: Successful diplomacy opens trade routes, reveals intel, or shifts faction alignment; failed diplomacy closes routes or triggers hostility | MUST HAVE | Faction relationship changes apply; story flags are set/cleared; new content unlocks or locks based on outcome |

### 6.4 Exploration Encounters

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD001-REQ-039 | Exploration Trigger: Exploration encounters fire when entering uncharted regions, scanning anomalies, or following lore clues | SHOULD HAVE | Exploration events are data-driven; new regions are discoverable |
| PRD001-REQ-040 | Exploration Interaction: Player investigates environments, discovers hidden crystal deposits, lore artefacts, or new realm entrances | SHOULD HAVE | Investigation UI presents findings; player can collect or leave discoveries |
| PRD001-REQ-041 | Exploration Outcomes: Discoveries add to crystal reserves, unlock lore entries, or open new navigation routes | SHOULD HAVE | Resources update; lore log populates; map/navigation data updates |

---

## Section 7: UI/UX Requirements

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD001-REQ-050 | Main Menu: Title screen with New Game, Continue, Settings, and Quit options | MUST HAVE | All menu options are functional; Continue is greyed out if no save exists |
| PRD001-REQ-051 | HUD: In-game heads-up display showing ship stats, crystal inventory, current arc/mission, and minimap | MUST HAVE | All HUD elements update in real-time; HUD is non-obstructive to gameplay view |
| PRD001-REQ-052 | Dialogue Interface: Full-screen or overlay dialogue UI for diplomatic and narrative encounters with character portraits, text, and response options | MUST HAVE | Character name and portrait display; text renders with typewriter effect; response buttons are selectable |
| PRD001-REQ-053 | Trade Interface: Split-screen inventory UI showing player and NPC inventories with drag-and-drop or button-based offer/counter-offer | MUST HAVE | Both inventories display correctly; offer/accept/reject flow works; totals update dynamically |
| PRD001-REQ-054 | Faction Status Screen: Accessible panel showing all faction relationship scores and current diplomatic states | SHOULD HAVE | All factions listed; relationship scores displayed as bars or numbers; diplomatic state labels are correct |
| PRD001-REQ-055 | Ship Management Screen: Panel for viewing ship stats, applying upgrades, and managing fleet | SHOULD HAVE | Stats display correctly; upgrades can be applied; fleet roster is browsable |
| PRD001-REQ-056 | Pause Menu: In-game pause with Resume, Save, Load, Settings, and Quit to Menu | MUST HAVE | Game pauses; all menu actions work; resume returns to exact game state |

---

## Section 8: Save/Load Requirements

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD001-REQ-060 | Save Game: Player can save current game state to a local JSON file at any point outside of encounters | MUST HAVE | Save writes all game state (resources, faction scores, story flags, ship data, arc progress) to JSON; file is human-readable |
| PRD001-REQ-061 | Load Game: Player can load a previously saved game from the main menu or pause menu | MUST HAVE | Load restores exact game state from JSON file; player resumes at correct arc/location with correct resources and relationships |
| PRD001-REQ-062 | Auto-Save: Game auto-saves at arc transitions and after significant encounters | SHOULD HAVE | Auto-save triggers at defined checkpoints; auto-save slot is separate from manual saves |
| PRD001-REQ-063 | Save Slot Management: Support for minimum 3 manual save slots plus 1 auto-save slot | SHOULD HAVE | Slots display save metadata (date, arc, playtime); player can overwrite or delete saves |
| PRD001-REQ-064 | Save File Integrity: Save files include version stamp and basic validation to prevent corrupt loads | MUST HAVE | Version mismatch is detected; corrupt files produce error message, not crash |

---

## Section 9: Collaboration Web Application Requirements

A web-based collaboration application is planned to allow a co-creator (creative collaborator) to view and engage with the game's development in real time. This is a development collaboration tool, not a player-facing feature.

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD001-REQ-070 | Collaboration Dashboard: Web-based read-only dashboard displaying current game state for a creative collaborator who does not need to run the game themselves | COULD HAVE | Dashboard renders in a browser; displays current game state data; does not require Pygame or Python installation |
| PRD001-REQ-071 | Story Arc Progress Viewer: Dashboard displays current story arc status, completed arcs, active story flags, and key decision history | COULD HAVE | Arc progress is visible; flags are listed; decision history shows choices and outcomes |
| PRD001-REQ-072 | Faction Relationship Viewer: Dashboard displays the full faction relationship matrix with current reputation scores and diplomatic states | COULD HAVE | All factions listed; reputation bars/numbers display; diplomatic state labels are correct |
| PRD001-REQ-073 | Character State Viewer: Dashboard displays core character states including behaviour state, relationship with player, and current arc | COULD HAVE | Aristotle, Dave, and Death states are visible; NPC behaviour states update when game state changes |
| PRD001-REQ-074 | Crystal Economy Snapshot: Dashboard displays Whisper Crystal inventory, production rate, active supply routes, and market pricing | COULD HAVE | Economy data renders correctly; supply route status is visible |
| PRD001-REQ-075 | Narrative Suggestion Pipeline (Phase 3 Stretch): Collaborator can submit narrative suggestions or faction event ideas via the web app that feed into the development pipeline | COULD HAVE | Submission form exists; submissions are stored; developer can review submissions |

---

*PRD-001 v0.2 | Whisper Crystals | Creative Development Confidential*
