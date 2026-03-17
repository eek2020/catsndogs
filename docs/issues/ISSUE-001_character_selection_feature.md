# Issue: ISSUE-001 — Character Selection Feature

**Severity:** High
**Status:** Open
**Reported:** 2026-03-16
**Linked Task:** N/A
**Assigned To:** N/A

---

## Description

Add a character selection feature that allows players to choose between starting the game as either Aristotle (current protagonist) or Dave (current antagonist). This is a significant design change that would fundamentally alter the game's narrative structure and player experience.

Currently, the game is hardcoded to start with Aristotle as the player character. This feature request would require:

1. **Character Selection UI:** A new game state allowing players to choose their starting character
2. **Dual Protagonist Support:** Game systems must support both Aristotle and Dave as valid player characters
3. **Narrative Branching:** Story arcs, dialogue, and encounters must adapt based on the chosen character
4. **Faction Relationships:** Starting faction relationships and reputation must be adjusted based on character choice
5. **Character-Specific Content:** Unique dialogue, encounters, and story elements for each character path

## Design Impact

### Aristotle Path (Current)

- Starts as Felid Corsairs captain
- Controls Whisper Crystal production
- Primary conflict with Dave (Canis League) and Death (rival Corsair)
- Current story arcs remain intact

### Dave Path (New)

- Starts as Canis League commander
- Goal: Break cats' stranglehold on Whisper Crystals
- Primary conflict with Aristotle (Felid Corsairs) and internal Canis League politics
- Requires new narrative perspective on existing story events
- May involve discovering alternative energy sources or military solutions

## Technical Requirements

### Core Systems Changes

- **Character Entity System:** Modify `entities/character.py` to support player-controlled Dave
- **Game State Management:** Update `core/game_state.py` to track selected protagonist
- **Session Management:** Modify `core/session.py` to initialize with chosen character
- **Save System:** Ensure character choice is properly saved and loaded

### UI Changes

- **Character Selection State:** New UI state for character choice
- **Character Portraits:** Assets for both Aristotle and Dave selection screens
- **Main Menu Updates:** Add "New Game" → "Character Selection" flow

### Data Changes

- **Character Stats:** Dave's stats must be playable as protagonist
- **Starting Conditions:** Different starting ships, crew, resources per character
- **Faction Relationships:** Adjusted starting reputation based on character choice
- **Dialogue Adaptation:** Many dialogue files need character-aware branches

### Narrative Adaptation

- **Arc 1:** Dave's perspective on discovering Aristotle's operation
- **Arc 2:** Dave's methods for challenging crystal monopoly
- **Arc 3:** Dave's diplomatic and military strategies
- **Arc 4:** Dave's endgame scenarios (energy independence vs crystal control)

## Files Affected

### Core Files

- `src/whisper_crystals/core/game_state.py` - Add protagonist tracking
- `src/whisper_crystals/core/session.py` - Character initialization
- `src/whisper_crystals/entities/character.py` - Dave as player character support
- `src/whisper_crystals/__main__.py` - Character selection entry point

### UI Files

- `src/whisper_crystals/ui/main_menu_state.py` - Add character selection flow
- New: `src/whisper_crystals/ui/character_selection_state.py` - Character choice UI

### Data Files

- `data/dialogue/*.json` - Character-aware dialogue branches
- `data/encounters/*.json` - Character-specific encounter variations
- `data/story/arc_definitions.json` - Character-specific story flags
- New: `data/characters/dave_protagonist.json` - Dave's playable stats/starting conditions

### Test Files

- `tests/test_character_selection.py` - New tests for character selection
- `tests/test_game_state.py` - Tests for protagonist tracking
- `tests/test_session.py` - Tests for character initialization

## Implementation Phases

### Phase 1: Foundation

1. Character selection UI state
2. Basic protagonist tracking in game state
3. Dave as playable character (stats, basic functionality)

### Phase 2: Narrative Adaptation

1. Character-specific dialogue branches
2. Adapted encounter conditions
3. Faction relationship adjustments

### Phase 3: Content Creation

1. Dave-specific story elements
2. Character-specific endings
3. Unique encounters per character

### Phase 4: Testing & Polish

1. Complete playthrough testing for both characters
2. Balance adjustments
3. UI/UX refinements

## Risks & Considerations

### Narrative Complexity

- Current story is written from Aristotle's perspective
- Dave's path may require significant narrative rewriting
- Risk of inconsistent story beats between characters

### Technical Debt

- Many systems assume Aristotle as protagonist
- Extensive refactoring may be required
- Risk of introducing bugs in existing Aristotle path

### Asset Requirements

- Additional character portraits and sprites
- UI elements for character selection
- Potential voice acting considerations

## Success Criteria

1. Players can choose between Aristotle and Dave at game start
2. Both characters have complete, playable story arcs
3. Existing Aristotle gameplay remains unchanged
4. Dave path provides meaningful narrative alternative
5. All game systems function correctly with either character
6. Save/load works properly for both character types

## Resolution

**Resolved:** {YYYY-MM-DD}
**Fix:** {Brief description of what was done}
**Verified:** {How it was tested}
