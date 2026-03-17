# ISSUE-001: Character Selection Feature — Implementation Plan

Add dual-protagonist support (Aristotle or Dave) with fully separate narrative paths, new encounter data, character selection UI, and Dave-specific endings.

---

## Impact Summary

Based on full codebase review, the following areas are affected:

| Area | Scope | Key Files |
|------|-------|-----------|
| Core systems | Protagonist tracking, session init, save/load | `game_state.py`, `session.py` |
| Entry point | Art loading, new-game wiring | `__main__.py` |
| New UI state | Character selection screen | New: `ui/character_selection.py` |
| Encounter data | 4 new Dave arc files | New: `data/encounters/arc*_encounters_dave.json` |
| Dialogue data | Dave internal + Aristotle-as-NPC | New: `data/dialogue/dave_internal.json`, `aristotle_hub.json` |
| Character data | Dave's playable starting conditions | New: `data/characters/dave_protagonist.json` |
| Story definitions | Dave-specific arc defs + endings | `data/story/arc_definitions.json` |
| Ship/sprites | League Cruiser wired as Dave's player ship | `sprite_manager.py` (already has `league_cruiser.png`) |
| Regions | Dave starts in Canine Order territory | `data/economy/regions.json` |
| Faction relationships | Inverted starting reputation for Dave | `data/factions/faction_registry.json` (read differently) |
| Tests | New + updated tests | Multiple test files |
| Intro cutscene | Character-specific intro text | `session.py` |
| Arc transitions | Character-aware cutscene text | `session.py` |
| Ending screen | Dave-specific endings | `ui/ending_screen.py`, `arc_definitions.json` |

---

## Phase 1: Foundation

### 1.1 — Add `protagonist_id` to GameStateData

**File:** `src/whisper_crystals/core/game_state.py`

- Add `protagonist_id: str = "aristotle"` field to `GameStateData`
- Include in `to_dict()` / `from_dict()` serialization
- Modify `create_new_game_state()` to accept a `protagonist_id` parameter
- When `protagonist_id == "dave"`:
  - Set `player_character` to Dave (DOG species, `canis_league` faction, Dave's stats from character_profiles.md)
  - Set `player_ship` from `league_cruiser` template (already exists), named "The Iron Resolve"
  - Set `current_region` to `"canine_order"`
  - Register Aristotle as NPC in `npc_registry` instead of Dave
  - Adjust initial story flags for Dave's arc
  - Set starting faction relationships from Dave's perspective (friendly with Canis League, hostile to Felid Corsairs)

### 1.2 — Create Dave Protagonist Data File

**New file:** `data/characters/dave_protagonist.json`

```json
{
  "character_id": "dave",
  "name": "Dave",
  "species": "DOG",
  "faction_id": "canis_league",
  "title": "Commander",
  "stats": { "cunning": 5, "leadership": 8, "negotiation": 5, "combat_skill": 7, "intimidation": 7, "stealth": 3 },
  "starting_ship": "league_cruiser",
  "ship_name": "The Iron Resolve",
  "starting_region": "canine_order",
  "starting_salvage": 40,
  "starting_crystal_inventory": 0,
  "intro_cutscene_lines": ["..."],
  "endings": {
    "military_victory": { ... },
    "negotiated_peace": { ... },
    "energy_independence": { ... }
  }
}
```

### 1.3 — Character Selection UI State

**New file:** `src/whisper_crystals/ui/character_selection.py`

- New `CharacterSelectionState(GameState)` with `state_type = GameStateType.CHARACTER_SELECT`
- Two-panel layout: Aristotle (left) vs Dave (right) with portraits from existing assets
- Display character name, faction, starting stats, ship, and brief description
- Arrow keys to switch between characters, Enter to confirm
- On confirm: store selected `protagonist_id`, call session's `start_new_game(protagonist_id=...)`
- Add `CHARACTER_SELECT` to `GameStateType` enum in `core/state_machine.py`

### 1.4 — Update Menu → New Game Flow

**File:** `src/whisper_crystals/ui/menu.py`

- "New Game" now pushes `CharacterSelectionState` instead of calling `start_new_game()` directly

**File:** `src/whisper_crystals/core/session.py`

- `push_menu()` passes character selection callback
- `start_new_game()` accepts `protagonist_id` parameter
- Route to character-specific intro cutscene text based on selection
- Arc transition cutscene text (`_on_arc_complete`) uses `self.game_state.player_character.name` instead of hardcoded "Aristotle"

**File:** `src/whisper_crystals/__main__.py`

- Load Dave's character art for use in character selection and Dave's intro cutscene
- Wire `protagonist_id` through the loading flow

### 1.5 — Wire League Cruiser as Dave's Player Ship Sprite

**File:** `src/whisper_crystals/engine/sprite_manager.py`

- `league_cruiser.png` already registered in `SHIP_SPRITES` — no sprite changes needed
- Navigation and combat UI already resolve ship sprites by `ship_template_id` — should work automatically
- Verify the existing player ship sprite logic in `navigation.py` and `combat_ui.py` uses the template ID from `player_ship`, not hardcoded `corsair_raider`

### 1.6 — Encounter Engine Character Awareness

**File:** `src/whisper_crystals/core/session.py` + `systems/encounter_engine.py`

- `encounter_engine.load_encounters()` needs to accept protagonist context
- For Dave: load `arc1_encounters_dave.json` instead of `arc1_encounters.json`
- Pattern: `{arc_id}_encounters_{protagonist_id}.json` falls back to `{arc_id}_encounters.json` for Aristotle

### 1.7 — Region Starting Conditions for Dave

**File:** `data/economy/regions.json`

- `canine_order` region currently has `is_discovered: false`. For Dave's path, this needs to be `true` (his home turf)
- Handle in `create_new_game_state()`: adjust region discovery flags based on protagonist
- Dave starts with `canine_order` and `knight_kingdoms` discovered; Aristotle keeps current setup

### 1.8 — Phase 1 Tests

**New file:** `tests/test_character_selection.py`

- Test `create_new_game_state("aristotle")` produces existing behaviour
- Test `create_new_game_state("dave")` produces correct Dave setup
- Test `protagonist_id` serializes/deserializes correctly
- Test encounter loading uses correct files per protagonist
- Test CharacterSelectionState input handling

---

## Phase 2: Narrative Adaptation

### 2.1 — Dave Arc 1 Encounters

**New file:** `data/encounters/arc1_encounters_dave.json`

Dave's Arc 1 — "The New Command": Dave takes command of a League cruiser squadron and discovers intelligence about a cat pirate who has found an energy source. Key beats:
- **Discovery**: League intelligence reports a new crystal energy source in Corsair territory
- **First contact with Aristotle**: Tense diplomatic encounter from Dave's side — sizing up the pirate
- **First glimpse of Death**: Intercepted comms suggest internal Corsair instability Dave can exploit
- **Stance choice**: Military blockade / Trade negotiation / Espionage infiltration

Story flags: `arc1_intel_received`, `arc1_aristotle_met`, `arc1_corsair_instability`, `arc1_dave_stance`

### 2.2 — Dave Arc 2 Encounters

**New file:** `data/encounters/arc2_encounters_dave.json`

Dave's Arc 2 — "The Campaign": Dave escalates his campaign to secure crystal access. Key beats:
- **Blockade operation**: Dave positions his fleet to choke Corsair supply lines
- **Internal League politics**: Wolf faction pressures Dave for faster results
- **Lion interference**: Lions demand the League stand down from "their" territory
- **Fairy intelligence**: Fairies offer to sell information about Corsair weaknesses

Story flags: `arc2_blockade_status`, `arc2_wolf_pressure`, `arc2_lion_demand`, `arc2_fairy_intel`

### 2.3 — Dave Arc 3 Encounters

**New file:** `data/encounters/arc3_encounters_dave.json`

Dave's Arc 3 — "The Reckoning": Alliances shift, Dave must choose who to trust. Key beats:
- **Alien contact**: The aliens approach Dave separately with a different offer
- **Aristotle parley**: The same parley scene, from Dave's perspective
- **Death approaches Dave**: Death offers to betray Aristotle in exchange for protection
- **Coalition building**: Dave must decide which factions to bring into his coalition

Story flags: `arc3_alien_contact`, `arc3_aristotle_parley`, `arc3_death_offer`, `arc3_coalition`

### 2.4 — Dave Arc 4 Encounters

**New file:** `data/encounters/arc4_encounters_dave.json`

Dave's Arc 4 — "The Siege": The final push for crystal control. Key beats:
- **Full assault on Corsair forge**: Dave launches his armada
- **Death's betrayal**: Death turns on everyone (or on Dave specifically)
- **Sovereign intervention**: Lions/Wolves arrive with their own agenda
- **Final choice** (3 Dave-specific endings):
  - **Military Victory**: Dave seizes the crystals for the League — order through force
  - **Negotiated Peace**: Dave brokers a multiverse treaty — shared governance of crystal production
  - **Energy Independence**: Dave discovers/deploys an alternative energy source — crystals become obsolete

Story flags: `arc4_assault_result`, `arc4_death_betrayal`, `arc4_sovereign_response`, `game_completed`, `ending_military_victory` / `ending_negotiated_peace` / `ending_energy_independence`

### 2.5 — Dave Dialogue Files

**New file:** `data/dialogue/dave_internal.json`

- Dave's internal monologue (equivalent to `aristotle_internal.json`)
- Tone: quiet, direct, methodical — reflecting Dave's character profile
- Choices: review fleet orders, consider the crystal situation, reflect on loyalty

**New file:** `data/dialogue/aristotle_hub.json`

- Aristotle as an NPC antagonist from Dave's perspective
- Mirrors the existing `dave_hub.json` structure but reversed: Aristotle is the one Dave encounters
- Arc-conditional dialogue branches

### 2.6 — Story Arc Definitions for Dave

**File:** `data/story/arc_definitions.json`

- Add Dave-specific arc entries: `arc_1_dave`, `arc_2_dave`, `arc_3_dave`, `arc_4_dave` (or use protagonist-keyed loading)
- Dave-specific ending thresholds for Military Victory / Negotiated Peace / Energy Independence
- Decision point definitions per Dave arc

---

## Phase 3: Content & Systems Integration

### 3.1 — Ending Screen Adaptation

**File:** `src/whisper_crystals/ui/ending_screen.py`

- Detect protagonist and display appropriate ending narrative
- Dave's 3 endings: Military Victory / Negotiated Peace / Energy Independence
- Character-specific decision summary text

### 3.2 — Faction Relationship Inversion for Dave

**File:** `src/whisper_crystals/core/game_state.py` (in `create_new_game_state`)

Dave's starting reputations (inverted from Aristotle's perspective):
- Canis League: **+60** (home faction, was -20 for Aristotle)
- Felid Corsairs: **-20** (enemy, was +60 for Aristotle)
- Wolves: **+30** (allied canines, was -30 for Aristotle)
- Lions: **-10** (same — lions demand from everyone)
- Fairies: **0** (neutral, were +15 for Aristotle)
- Knights: **+10** (was 0 for Aristotle)
- Goblins: **-10** (was +10 for Aristotle)
- Aliens: **0** (same)

### 3.3 — Side Missions for Dave

**New file:** `data/side_missions/arc1_side_missions_dave.json`

- Dave-flavoured side missions: patrol duty, League intelligence gathering, supply escort
- Use same SideMissionSystem, just different data files loaded per protagonist

### 3.4 — Cutscene Text Character Awareness

**File:** `src/whisper_crystals/core/session.py`

- Intro cutscene: Dave-specific opening narrative about the Canis League's mission
- Arc transition cutscenes: use player character name dynamically
- Ending cutscene routing: detect protagonist for correct ending set

### 3.5 — HUD and Navigation Dave Awareness

- HUD should display Dave's faction colour scheme (blue instead of purple)
- Navigation starting position: `canine_order` region coordinates
- Verify all navigation references use `game_state.player_character` not hardcoded values

---

## Phase 4: Testing & Polish

### 4.1 — Test Suite

| Test File | Scope |
|-----------|-------|
| `tests/test_character_selection.py` (new) | CharacterSelectionState UI, protagonist_id routing |
| `tests/test_game_state.py` (update) | Protagonist tracking, Dave init, serialization |
| `tests/test_session.py` (update) | Character-aware new game, encounter loading |
| `tests/test_dave_encounters.py` (new) | All 4 Dave arc encounter files parse and execute |
| `tests/test_dave_dialogue.py` (new) | Dave dialogue files valid, all nodes reachable |
| `tests/test_ending_screen.py` (new) | Both character ending sets render correctly |

### 4.2 — Playthrough Verification

- Full Aristotle path regression: ensure zero changes to existing gameplay
- Full Dave path: verify all 4 arcs playable, all 3 Dave endings reachable
- Save/load with both characters
- Character selection → load saved game of opposite character

### 4.3 — Balance Pass

- Dave's starting stats/ship vs encounter difficulty
- Faction relationship tuning for Dave's path
- Ending weight thresholds for Dave's 3 endings

---

## New Files Summary

| File | Type |
|------|------|
| `src/whisper_crystals/ui/character_selection.py` | Python — UI state |
| `data/characters/dave_protagonist.json` | JSON — Dave's playable config |
| `data/encounters/arc1_encounters_dave.json` | JSON — Dave Arc 1 |
| `data/encounters/arc2_encounters_dave.json` | JSON — Dave Arc 2 |
| `data/encounters/arc3_encounters_dave.json` | JSON — Dave Arc 3 |
| `data/encounters/arc4_encounters_dave.json` | JSON — Dave Arc 4 |
| `data/dialogue/dave_internal.json` | JSON — Dave inner monologue |
| `data/dialogue/aristotle_hub.json` | JSON — Aristotle as NPC |
| `data/side_missions/arc1_side_missions_dave.json` | JSON — Dave side missions |
| `tests/test_character_selection.py` | Python — tests |
| `tests/test_dave_encounters.py` | Python — tests |
| `tests/test_dave_dialogue.py` | Python — tests |

## Modified Files Summary

| File | Changes |
|------|---------|
| `src/whisper_crystals/core/game_state.py` | `protagonist_id` field, Dave init in `create_new_game_state()` |
| `src/whisper_crystals/core/session.py` | Character selection flow, character-aware cutscenes/loading |
| `src/whisper_crystals/core/state_machine.py` | `CHARACTER_SELECT` state type |
| `src/whisper_crystals/__main__.py` | Art loading, protagonist_id wiring |
| `src/whisper_crystals/ui/menu.py` | Route to character selection |
| `src/whisper_crystals/ui/ending_screen.py` | Dave-specific endings |
| `src/whisper_crystals/systems/encounter_engine.py` | Protagonist-aware file loading |
| `data/story/arc_definitions.json` | Dave arc definitions + ending thresholds |
| `data/economy/regions.json` | (handled dynamically in game_state init) |

## Risks

- **Aristotle regression**: Every core change must be tested against existing path
- **Encounter data volume**: 4 new arc files with rich narrative text is significant writing work
- **Ending weight balance**: Dave's 3 new endings need careful threshold tuning
- **Save compatibility**: Old saves won't have `protagonist_id` — `from_dict` must default to `"aristotle"`
