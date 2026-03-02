# Whisper Crystals — A Space Pirates Game

A narrative-driven 2D side-scrolling space pirate game inspired by the Spelljammer D&D setting. Command Aristotle, a self-made cat pirate captain who controls the multiverse's only source of starship fuel — Whisper Crystals.

## Quick Start

```bash
# Option 1: Use the launcher (recommended)
./run.sh          # Mac/Linux
run.bat           # Windows
python run.py     # Cross-platform Python launcher

# Option 2: Manual setup
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python -m whisper_crystals

# Run tests
pytest tests/ -v
```

## Project Structure

```text
whisper_crystals/
├── docs/                       # Project documentation
│   ├── MASTER_PLAN.md          # Active plan — start here
│   ├── architecture/           # TRDs (tech specs) and ADRs
│   ├── process/                # CONTRIBUTING.md
│   ├── changelog/              # CHANGELOG.md
│   ├── reviews/                # Code review records
│   ├── issues/                 # Issue tracking
│   └── archive/                # Completed PRDs and superseded plans
├── story/                      # Narrative reference materials
│   ├── arcs/                   # Story arc overviews
│   ├── characters/             # Character profiles
│   └── factions/               # Faction lore
├── design/                     # Art direction, UI/UX, ship design specs
├── src/
│   └── whisper_crystals/
│       ├── core/               # Engine-agnostic game logic
│       ├── entities/           # Data models (Character, Ship, Faction, etc.)
│       ├── systems/            # Game systems (combat, economy, crew, etc.)
│       ├── engine/             # Pygame-specific rendering and input
│       └── ui/                 # UI state classes
├── data/                       # Data-driven content (JSON)
│   ├── encounters/             # Arc 1–4 encounter definitions
│   ├── dialogue/               # Dialogue trees
│   ├── factions/               # Faction registry and relationship matrix
│   ├── ships/                  # Ship templates per faction
│   ├── economy/                # Crystal deposits, supply routes, regions
│   └── story/                  # Arc definitions and story flags
├── assets/                     # Game assets (sprites, audio)
└── tests/                      # Pytest test suite (186 tests)
```

## Tech Stack

- **Language:** Python 3.11+
- **Game Library:** pygame-ce 2.4.1+
- **Testing:** pytest 8.0+
- **Linting:** ruff 0.2+
- **Target Platform:** Desktop (Mac M3/M4 primary, Windows compatible)

## Architecture Principles

- **Engine Abstraction Layer (EAL)** — `core/`, `systems/`, `entities/` have zero pygame imports; only `engine/` contains pygame
- **Migration-ready** — All game logic is engine-agnostic for future Godot/Unity port
- **Stack state machine** — Explicit push/pop/switch state machine manages all game states
- **Data-driven content** — Story, dialogue, encounters, factions loaded from JSON at runtime
- **Event bus** — Pub/sub system for decoupled communication between game systems

## Game State

All four story arcs are implemented. The game is fully playable from new game to one of three endings.
See `docs/MASTER_PLAN.md` for current development status and active work.

## Documentation

- [`docs/MASTER_PLAN.md`](docs/MASTER_PLAN.md) — Active plan: current state, tasks, roadmap
- [`docs/architecture/TRD-001`](docs/architecture/TRD-001_Technical_Architecture_Stack.md) — Technical Architecture & Stack
- [`docs/architecture/TRD-002`](docs/architecture/TRD-002_Game_Engine_Prototype_Specification.md) — Game Engine & Prototype Specification
- [`docs/architecture/TRD-003`](docs/architecture/TRD-003_Data_Model_State_Management.md) — Data Model & State Management
- [`docs/process/CONTRIBUTING.md`](docs/process/CONTRIBUTING.md) — Contributor guide

## License

Creative Development — Confidential
