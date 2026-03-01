# Whisper Crystals — A Space Pirates Game

A narrative-driven 2D side-scrolling space pirate game inspired by the Spelljammer D&D setting. Command Aristotle, a self-made cat pirate captain who controls the multiverse's only source of starship fuel — Whisper Crystals.

## Quick Start

```bash
# Option 1: Use the launcher (recommended)
./run.sh          # Mac/Linux
run.bat           # Windows
python run.py     # Cross-platform Python launcher

# Option 2: Manual setup
# Create virtual environment
python3.11 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run the game
python -m whisper_crystals

```bash
# Run tests
pytest tests/ -v
```

## Project Structure

```text
CatsnDogs/
├── docs/               # PRD and TRD documentation
│   ├── prd/            # Product Requirements Documents (PRD-001 to PRD-003)
│   └── trd/            # Technical Requirements Documents (TRD-001 to TRD-003)
├── story/              # Narrative reference materials
│   ├── arcs/           # Story arc overviews and beat sheets
│   ├── characters/     # Character profiles and progression
│   ├── factions/       # Faction registry and relationship data
│   └── dialogue/       # Dialogue tree drafts
├── design/             # Design reference materials
│   ├── art_direction/  # Visual style guide and colour palettes
│   ├── ui_ux/          # UI/UX wireframes and specifications
│   └── ships/          # Ship design specs and stat tables
├── src/                # Python source code
│   └── whisper_crystals/
│       ├── core/       # Engine-agnostic game logic
│       ├── entities/   # Data models (Character, Ship, Faction, etc.)
│       ├── systems/    # Game systems (combat, trade, diplomacy, etc.)
│       ├── engine/     # Pygame-specific rendering and input
│       └── ui/         # UI components
├── data/               # Data-driven content (JSON)
│   ├── encounters/     # Encounter definitions
│   ├── dialogue/       # Dialogue trees
│   ├── factions/       # Faction data and relationship matrix
│   ├── ships/          # Ship templates
│   └── story/          # Story arc definitions
├── assets/             # Game assets (sprites, audio)
└── tests/              # Pytest test suite
```

## Tech Stack

- **Language:** Python 3.11+
- **Game Library:** pygame-ce 2.4.1+
- **Testing:** pytest 8.0+
- **Target Platform:** Desktop (Mac M3/M4 primary, Windows compatible)

## Architecture Principles

- **Separation of concerns** — Game logic, rendering, and data are cleanly separated
- **Migration-ready** — All game logic is engine-agnostic for future Godot/Unity port
- **State machine driven** — Explicit state machine manages all game states
- **Data-driven content** — Story, dialogue, encounters loaded from JSON at runtime

## Documentation

- `docs/prd/PRD-001` — Game Overview & Feature Requirements
- `docs/prd/PRD-002` — Narrative & Story System Requirements
- `docs/prd/PRD-003` — Character & Faction System Requirements
- `docs/trd/TRD-001` — Technical Architecture & Stack
- `docs/trd/TRD-002` — Game Engine & Prototype Specification
- `docs/trd/TRD-003` — Data Model & State Management

## License

Creative Development — Confidential
