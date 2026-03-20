# Crew Missions Feature — Implementation Plan

**Date:** 2026-03-18
**Status:** COMPLETE
**Depends on:** Character Selection Feature (complete), Side Mission System (complete)

Each protagonist recruits a crew of named characters through story-driven missions. Each crew member fills a specific ship role (First Mate, Gunner, Navigator, Surgeon) and brings unique skills/capabilities that enhance gameplay — improving combat outcomes, item discovery, navigation, and other traits.

---

## Crew Roster

### Aristotle's Crew

| Role | Name | Recruitment Story (placeholder) | Key Trait |
|------|------|---------------------------------|-----------|
| First Mate | Nine Lives | A legendary cat survivor found drifting in a damaged escape pod. Has cheated death so many times the crew thinks she's immortal. Willingly joins — she and Aristotle are old friends from the streets. | **Survivability** — reduces crew casualty chance; bonus to hull repair rate |
| Gunner | No Tail | A scarred, battle-hardened cat with a missing tail and a grudge against the Canis League. Found defending a besieged outpost alone. Must be convinced to join — respects only strength. | **Firepower** — increases weapon damage; bonus chance for critical hits |
| Navigator | Silky | A graceful, enigmatic cat who knows hidden routes between realms. Found trapped in a fairy-realm labyrinth. Already great friends with Aristotle — joins without being asked. | **Pathfinding** — unlocks hidden routes; reduces travel time; increases exploration discovery rate |
| Surgeon | Blood Paw | A former Lion court physician who defected after witnessing corruption. Found running a field hospital in a war zone. Must be rescued before she'll join. | **Healing** — increases crew morale recovery; reduces hull repair costs; bonus to post-combat recovery |

### Dave's Crew

| Role | Name | Recruitment Story (placeholder) | Key Trait |
|------|------|---------------------------------|-----------|
| First Mate | Charlie | Dave's childhood friend from the Canis League academy. Found commanding a supply convoy under ambush. Already great friends — joins without hesitation. | **Loyalty** — boosts crew morale; reduces desertion chance; bonus to leadership checks |
| Gunner | Bombardier | A demolitions expert court-martialled for "excessive enthusiasm." Found in a League brig during a prison break encounter. Must be convinced — wants proof Dave isn't just another by-the-book officer. | **Explosives** — increases firepower; area damage bonus; chance to disable enemy systems |
| Navigator | Luna | A quiet, calculating wolf-dog hybrid who reads star charts like poetry. Found stranded on a derelict research station. Willingly joins — fascinated by Dave's mission. | **Star Reading** — unlocks hidden routes; improves ambush detection; reduces fuel consumption |
| Surgeon | Thistle | A field medic from the Knights faction, disillusioned with chivalric politics. Found treating wounded from both sides of a battle. Must be persuaded — doesn't trust military types. | **Field Medicine** — increases crew morale recovery; reduces hull repair costs; bonus to post-combat survival |

---

## Phase 1: Data Foundation

### 1.1 — Crew Member Data Files

**New file:** `godot/data/characters/crew_members.json`

Define all 8 crew members with:
- `crew_id`, `name`, `species`, `role`, `faction_origin`
- `protagonist_id` — which protagonist they belong to (`aristotle` or `dave`)
- `portrait` — path to portrait asset (placeholder initially)
- `description` — character bio text
- `recruitment_story` — placeholder narrative text
- `skills` — array of skill identifiers
- `skill_level` — starting skill level
- `trait_id` — unique trait identifier for gameplay bonuses
- `trait_description` — player-facing text explaining the bonus
- `trait_bonuses` — dictionary of stat/system modifiers (e.g. `{"firepower_bonus": 0.1, "critical_hit_chance": 0.05}`)
- `join_type` — `"willing"` (joins without asking) or `"persuade"` (requires dialogue choice)

### 1.2 — Crew Mission Data Files

**New file:** `godot/data/side_missions/crew_missions_aristotle.json`
**New file:** `godot/data/side_missions/crew_missions_dave.json`

Each file contains 4 missions (one per crew member), using the existing `SideMission` data structure:
- `mission_type`: `"crew_recruitment"`
- `mission_id`: e.g. `"crew_aristotle_nine_lives"`, `"crew_dave_charlie"`
- Standard fields: `title`, `description`, `region`, `objectives`, `rewards`, `faction_rewards`
- New field: `crew_member_id` — ID of the crew member recruited on completion
- `trigger_conditions` — story flags / arc requirements for when the mission becomes available
- Each mission has an encounter chain: discovery → dialogue → optional combat/puzzle → recruitment dialogue

### 1.3 — Crew Recruitment Encounters

**New files:** `godot/data/encounters/crew_nine_lives.json`, `crew_no_tail.json`, `crew_silky.json`, `crew_blood_paw.json`, `crew_charlie.json`, `crew_bombardier.json`, `crew_luna.json`, `crew_thistle.json`

Each encounter file defines:
- Discovery encounter (finding the crew member)
- Recruitment dialogue with branching choices
- For `"persuade"` types: a challenge encounter (combat or skill check)
- Outcome: crew member joins ship on success

---

## Phase 2: Crew Trait System

### 2.1 — CrewTraitSystem

**New file:** `godot/scripts/systems/crew_trait_system.gd`

- `class_name CrewTraitSystem extends RefCounted`
- Loads trait definitions from `crew_members.json`
- `get_active_traits(ship: Ship) -> Array[Dictionary]` — returns all active trait bonuses for the current crew
- `get_bonus(ship: Ship, bonus_key: String) -> float` — returns cumulative bonus for a specific key
- Bonus keys: `firepower_bonus`, `critical_hit_chance`, `hull_repair_rate`, `exploration_discovery_rate`, `fuel_efficiency`, `ambush_detection`, `morale_recovery`, `trade_pricing_bonus`, `crew_casualty_reduction`, `post_combat_recovery`

### 2.2 — Wire Traits into Existing Systems

**Modified files:**

- `systems/combat_system.gd` — apply `firepower_bonus`, `critical_hit_chance` from crew traits to damage calculation
- `systems/crew_morale_system.gd` — apply `morale_recovery`, `crew_casualty_reduction` bonuses
- `systems/economy_system.gd` — apply `fuel_efficiency`, `trade_pricing_bonus`
- `systems/encounter_engine.gd` — apply `exploration_discovery_rate`, `ambush_detection`

### 2.3 — Extend CrewMember Entity

**Modified file:** `godot/scripts/entities/ship.gd` (CrewMember inner class)

Add fields:
- `trait_id: String` — links to trait definition
- `portrait: String` — path to portrait asset
- `backstory: String` — character bio
- `recruitment_status: String` — `"unknown"`, `"discovered"`, `"recruited"`

Include in `to_dict()` / `from_dict()` serialization.

---

## Phase 3: Recruitment Flow

### 3.1 — Crew Mission Integration with SideMissionSystem

**Modified file:** `godot/scripts/systems/side_mission_system.gd`

- On game start, load crew missions for the active protagonist
- Crew missions appear as special side missions in the mission log (tagged distinctly)
- On crew mission completion: instantiate `CrewMember` from data, add to `player_ship.crew`

### 3.2 — Recruitment Dialogue

**Modified file:** `godot/scripts/ui/dialogue_ui.gd`

- Detect crew recruitment encounters (by encounter metadata)
- After successful recruitment dialogue, trigger crew join event via EventBus
- Display recruitment confirmation: portrait + name + role + trait description

### 3.3 — Crew Recruitment Event

**Modified file:** `godot/scripts/autoload/event_bus.gd`

- Add signal: `crew_member_recruited(crew_id: String, protagonist_id: String)`
- GameSession listens and adds crew member to ship

### 3.4 — Crew Roster in Ship Screen

**Modified file:** `godot/scripts/ui/ship_screen.gd`

- Enhanced crew display showing: name, role, portrait (placeholder), trait description, morale
- Empty crew slots shown with "?" and role name to hint at available recruitment missions

---

## Phase 4: Mission Log Integration

### 4.1 — Crew Missions Section in Mission Log

**Modified file:** `godot/scripts/ui/mission_log.gd`

- Add "CREW MISSIONS" group header between MAIN and SIDE missions
- Crew missions show crew member portrait (placeholder) and role
- Completed crew missions show "RECRUITED" status in green

---

## Phase 5: Placeholder Art & Polish

### 5.1 — Placeholder Portraits

- Generate or create simple placeholder portraits for all 8 crew members
- Use faction-coloured silhouettes as minimum viable placeholder
- Store in `godot/assets/characters/crew/`

### 5.2 — Crew Status HUD Indicator

**Modified file:** `godot/scripts/ui/navigation.gd` (HUD section)

- Show crew count indicator: "Crew: X/4" in HUD
- Flash notification when new crew member joins

---

## Phase 6: Testing

### 6.1 — Test Suite

| Test | Scope |
|------|-------|
| Crew data files parse correctly | All 8 crew members load from JSON |
| Crew missions load per protagonist | Aristotle gets his 4, Dave gets his 4 |
| Crew trait bonuses calculate correctly | CrewTraitSystem returns correct modifiers |
| Crew member joins ship on mission complete | Full recruitment flow |
| Crew serialization round-trips | to_dict/from_dict preserves all crew data |
| Ship screen shows crew roster | UI renders crew with traits |

---

## New Files Summary

| File | Type |
|------|------|
| `godot/data/characters/crew_members.json` | JSON — crew member definitions |
| `godot/data/side_missions/crew_missions_aristotle.json` | JSON — Aristotle crew missions |
| `godot/data/side_missions/crew_missions_dave.json` | JSON — Dave crew missions |
| `godot/data/encounters/crew_*.json` (8 files) | JSON — recruitment encounters |
| `godot/scripts/systems/crew_trait_system.gd` | GDScript — trait bonus system |
| `godot/assets/characters/crew/` | Directory — placeholder portraits |

## Modified Files Summary

| File | Changes |
|------|---------|
| `godot/scripts/entities/ship.gd` | Extended CrewMember with trait/portrait/backstory/status fields |
| `godot/scripts/systems/combat_system.gd` | Apply crew trait bonuses to damage |
| `godot/scripts/systems/crew_morale_system.gd` | Apply morale/casualty trait bonuses |
| `godot/scripts/systems/economy_system.gd` | Apply fuel/trade trait bonuses |
| `godot/scripts/systems/encounter_engine.gd` | Apply discovery/ambush trait bonuses |
| `godot/scripts/systems/side_mission_system.gd` | Load crew missions, handle recruitment completion |
| `godot/scripts/ui/dialogue_ui.gd` | Recruitment confirmation display |
| `godot/scripts/ui/ship_screen.gd` | Enhanced crew roster display |
| `godot/scripts/ui/mission_log.gd` | Crew missions group |
| `godot/scripts/ui/navigation.gd` | Crew count HUD indicator |
| `godot/scripts/autoload/event_bus.gd` | crew_member_recruited signal |

## Risks

- **Art dependency**: All crew portraits are placeholders — final art is in development
- **Story dependency**: Recruitment narratives are placeholders — story refinement is ongoing
- **Balance**: Crew trait bonuses need tuning against existing difficulty
- **Crew capacity**: Ship crew_capacity must accommodate 4 named crew + any existing generic crew
