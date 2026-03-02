> **ARCHIVED — 2026-03-02 — STATUS: SUPERSEDED**
>
> The content of this plan has been absorbed into `docs/MASTER_PLAN.md` as the authoritative planning document.
> Implementation detail (task tracker, file lists, JSON schemas, code snippets) is preserved here for reference.
>
> **Status at time of archiving:**
> - `entities/side_mission.py` — SideMission + MissionObjective dataclasses: ✅ DONE
> - All other Side Missions + Distress Signals tasks: ⬜ TODO (see MASTER_PLAN.md § Active Initiatives)

---

# PLAN-002 Entertainment Enhancements

**Created:** 2026-03-02
**Status:** Superseded — absorbed into MASTER_PLAN.md
**Approved by user:** Yes

---

## Background

The core game loop (fly → arc encounter → make choice → repeat) is solid but predictable.
The economic and faction systems are well-built but largely invisible to the player.
The main gap is **texture and surprise between story beats**.

---

## Enhancement Catalogue

### Tier 1 — High Impact, Fits Architecture Cleanly

#### 1. Side Missions / Bounty Board
**What:** Optional quests offered by factions/NPCs alongside the main arc. Bounties to hunt specific ships, escort supply routes, retrieve stolen crystals from pirate dens.

**Why:** Currently all encounters are arc-gated. Side missions give the player something to do *between* arc beats and let them engage factions voluntarily.

**Architecture fit:** Excellent. New `SideMission` entity, a `side_missions` dict in `GameStateData`, and encounters loaded from `data/side_missions/`. Existing trigger/outcome/reward system handles the rest.

---

#### 2. Distress Signal Events
**What:** While flying, occasional signals from damaged ships. Three choice paths: investigate (risk for salvage/crew/rep), ignore (safe, tiny rep hit), exploit (easy loot but faction penalty + notoriety).

**Why:** Breaks predictable encounter cadence. Moral choices with systemic consequences.

**Architecture fit:** Excellent. New encounter type `distress_signal` in its own JSON file. Spawns as a special POI in navigation with amber pulsing visual.

---

#### 3. Live World News (Faction Conquest Surface Layer)
**What:** Surface `FactionConquestSystem` results as "subspace radio intercepts" — HUD news flashes when factions win/lose conflicts.

**Why:** The faction AI is invisible right now. Making it visible turns background simulation into a living world.

**Architecture fit:** Excellent. Conquest system already publishes events via event bus. A `WorldNewsSystem` subscribes and queues items to HUD.

---

### Tier 2 — Medium Lift, High Payoff

#### 4. Wanted / Notoriety System
**What:** Factions track crimes (attacking ships, smuggling, poaching deposits). Notoriety level 0-5 triggers escalating patrol encounters.

**Architecture fit:** Very good. Add `notoriety: dict[str, int]` to `GameStateData`. New `WantedSystem` class injects patrol encounters.

---

#### 5. Named Crew with Mini-Storylines
**What:** Give crew members names, species, backstories, loyalty arcs, and unique abilities.

**Architecture fit:** Good. `CrewMember` entity needs `name`, `backstory`, `loyalty_to_faction`, `special_ability`, `arc_flags`. New `crew_dialogue.json` files.

---

### Tier 3 — Higher Complexity, Strong Flavour

#### 6. Tavern / Station Hub with Rumors
**What:** At faction stations, spend crystals to buy rumors — structured hints about POI locations, faction troop movements, NPC locations.

**Architecture fit:** Good. New `RumorSystem` + `rumor_registry.json`.

---

#### 7. Black Market / Smuggling Run
**What:** Hidden trade nodes with contraband. Carrying contraband makes Canis League patrols search you.

**Architecture fit:** Very good. `contraband_flag` on cargo items. Black market nodes as a POI type.

---

#### 8. Astral Dice (Gambling Mini-Game)
**What:** Dice-based gambling game at taverns or with specific NPCs. "Death plays dice" writes itself.

**Architecture fit:** Moderate. New `MiniGameState`. Self-contained math.

---

## CURRENT WORK: Side Missions + Distress Signals

### Files to Create

| File | Purpose |
|------|---------|
| `src/whisper_crystals/entities/side_mission.py` | `SideMission` + `MissionObjective` dataclasses ✅ DONE |
| `src/whisper_crystals/systems/side_mission.py` | `SideMissionSystem` |
| `data/side_missions/arc1_side_missions.json` | Arc 1 side mission definitions |
| `data/side_missions/distress_signals.json` | Distress signal encounter pool |
| `src/whisper_crystals/ui/mission_log.py` | `MissionLogState` overlay |
| `tests/test_side_missions.py` | Full test suite |

### Files to Modify

| File | Change |
|------|--------|
| `src/whisper_crystals/core/data_loader.py` | Add `load_side_missions(arc_id)` and `load_distress_signals()` |
| `src/whisper_crystals/core/game_state.py` | Add `side_missions: dict[str, SideMission]` + serialization |
| `src/whisper_crystals/core/state_machine.py` | Add `MISSION_LOG` to `GameStateType` enum |
| `src/whisper_crystals/core/session.py` | Instantiate `SideMissionSystem`, add `_open_mission_log()` |
| `src/whisper_crystals/ui/navigation.py` | Distress signal random POI spawning; `M` key → mission log |
| `src/whisper_crystals/ui/hud.py` | Active mission count indicator |

### Implementation Details

#### SideMission Entity (DONE)
`entities/side_mission.py` — `SideMission` + `MissionObjective` dataclasses.
- `status`: `"available"` → `"active"` → `"completed"` / `"failed"`
- `objectives`: list of `MissionObjective`, each optionally linked to an `encounter_id`
- `rewards`: `dict[str, int]` (crystals, salvage)
- `faction_rewards`: `dict[str, int]` (rep deltas on completion)
- `discovery_encounter_id`: encounter that makes this mission available

#### SideMissionSystem
```
load_missions(mission_data: list[dict]) -> None
get_available_missions(game_state) -> list[SideMission]
activate_mission(game_state, mission_id) -> bool
on_encounter_completed(game_state, encounter_id) -> list[str]
complete_mission(game_state, mission_id) -> dict
```

#### Distress Signal JSON Schema
```json
{
  "distress_signals": [
    {
      "encounter_id": "distress_001_stranded_merchant",
      "encounter_type": "distress_signal",
      "title": "Distress Beacon: Stranded Merchant",
      "arc_id": "any",
      "location": "any",
      "trigger_conditions": {},
      "repeatable": true,
      "priority": 2,
      "spawn_weight": 1.0,
      "choices": [
        { "choice_id": "help", "text": "Respond to the distress call" },
        { "choice_id": "ignore", "text": "It's not your problem" },
        { "choice_id": "exploit", "text": "Disable their shields and take the cargo" }
      ]
    }
  ]
}
```

#### Side Mission JSON Schema
```json
{
  "side_missions": [
    {
      "mission_id": "sm_arc1_bounty_goblin_raiders",
      "mission_type": "bounty",
      "title": "Clean Up Aisle Seven",
      "region": "asteroid_belt",
      "trigger_conditions": { "current_arc": "arc_1", "arc1_crystal_discovered": true },
      "discovery_encounter_id": "enc_sm_arc1_bounty_offer_goblins",
      "objectives": [
        {
          "objective_id": "defeat_goblins",
          "description": "Defeat the Goblin Scrapper patrol",
          "encounter_id": "enc_arc1_pirate_skirmish"
        }
      ],
      "rewards": { "salvage": 40, "crystals": 5 },
      "faction_rewards": { "felid_corsairs": 8 },
      "priority": 3
    }
  ]
}
```

#### NavigationState Additions
- `self._distress_pool: list[Encounter]` — loaded distress signal encounters
- `self._distress_timer: float` — countdown to next distress spawn (random 30-90s)
- Distress signal POI color: amber `(255, 160, 40)` with fast pulse rate
- Add `M` key hotkey → `session._open_mission_log()`

#### HUD Addition
```
[M: 2 MISSIONS]  — amber text between arc title and hull
```

#### MissionLogState UI
- Two-column layout: left = active missions list, right = selected mission detail
- Shows objectives with checkmarks, rewards on completion
- Amber/gold theme

---

### Test Plan
`tests/test_side_missions.py`:
- `TestSideMissionEntity` — to_dict/from_dict round-trip, is_complete property
- `TestMissionObjective` — round-trip, completion state
- `TestSideMissionSystem` — load, activate, complete, event publishing
- `TestSideMissionIntegration` — encounter completion triggers objective progress
- `TestDistressSignalEncounters` — encounter schema, choice outcomes

---

## Task Tracker (at time of archiving)

| Status | Task |
|--------|------|
| ✅ Done | `entities/side_mission.py` |
| ⬜ Todo | `systems/side_mission.py` |
| ⬜ Todo | `data/side_missions/arc1_side_missions.json` |
| ⬜ Todo | `data/side_missions/distress_signals.json` |
| ⬜ Todo | `core/data_loader.py` additions |
| ⬜ Todo | `core/game_state.py` additions |
| ⬜ Todo | `core/state_machine.py` — MISSION_LOG |
| ⬜ Todo | `core/session.py` — wire SideMissionSystem |
| ⬜ Todo | `ui/navigation.py` — distress signal POIs, M key |
| ⬜ Todo | `ui/hud.py` — active mission count |
| ⬜ Todo | `ui/mission_log.py` |
| ⬜ Todo | `tests/test_side_missions.py` |
| ⬜ Todo | Run full test suite, verify EAL |
