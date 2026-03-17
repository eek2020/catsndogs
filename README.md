# Whisper Crystals — A Space Pirates Game

A narrative-driven 2D side-scrolling space pirate game inspired by the Spelljammer D&D setting. Command Aristotle, a self-made cat pirate captain who controls the multiverse's only source of starship fuel — Whisper Crystals.

## Quick Start

1. Install [Godot 4.6](https://godotengine.org/download/) (GL Compatibility renderer)
2. Open the project: **Project → Import → select `godot/project.godot`**
3. Press **F5** (or ▶) to run the game

## Project Structure

```text
whisper_crystals/
├── godot/                        # Godot 4.6 project root
│   ├── project.godot             # Godot project config
│   ├── scenes/                   # Scene tree (.tscn files)
│   │   ├── main.tscn             # Main scene (entry point)
│   │   └── ui/                   # UI scenes
│   ├── scripts/                  # GDScript source
│   │   ├── autoload/             # Singletons (EventBus, GameSession, MusicManager)
│   │   ├── core/                 # Core game logic
│   │   ├── entities/             # Data models
│   │   ├── systems/              # Game systems (combat, economy, crew, etc.)
│   │   └── ui/                   # UI controllers
│   ├── data/                     # Data-driven content (JSON)
│   │   ├── encounters/           # Arc 1–4 encounter definitions
│   │   ├── dialogue/             # Dialogue trees
│   │   ├── factions/             # Faction registry
│   │   ├── ships/                # Ship templates
│   │   ├── economy/              # Crystal deposits, supply routes, regions
│   │   ├── story/                # Arc definitions and story flags
│   │   └── side_missions/        # Side mission data
│   ├── assets/                   # Game assets (sprites, audio)
│   └── shaders/                  # Custom shaders
├── docs/                         # Project documentation
│   ├── MASTER_PLAN.md            # Active plan — start here
│   ├── architecture/             # TRDs (tech specs) and ADRs
│   ├── changelog/                # CHANGELOG.md
│   └── issues/                   # Issue tracking
├── story/                        # Narrative reference materials
│   ├── arcs/                     # Story arc overviews
│   ├── characters/               # Character profiles
│   └── factions/                 # Faction lore
└── design/                       # Art direction, characters, artwork
```

## Tech Stack

- **Engine:** Godot 4.6 (GL Compatibility renderer)
- **Language:** GDScript
- **Resolution:** 1280×720, canvas_items stretch mode
- **Target Platform:** Desktop (Mac M3/M4 primary, Windows compatible)

## Architecture Principles

- **Autoload singletons** — `EventBus`, `GameSession`, and `MusicManager` provide global services
- **Data-driven content** — Story, dialogue, encounters, factions loaded from JSON at runtime
- **Event bus** — Pub/sub system for decoupled communication between game systems
- **Scene-based UI** — UI screens are individual scenes managed via the scene tree

## Game State

All four story arcs are implemented. The game is fully playable from new game to one of three endings.
See `docs/MASTER_PLAN.md` for current development status and active work.

## Documentation

- [`docs/MASTER_PLAN.md`](docs/MASTER_PLAN.md) — Active plan: current state, tasks, roadmap
- [`docs/architecture/TRD-001`](docs/architecture/TRD-001_Technical_Architecture_Stack.md) — Technical Architecture & Stack
- [`docs/architecture/TRD-002`](docs/architecture/TRD-002_Game_Engine_Prototype_Specification.md) — Game Engine & Prototype Specification
- [`docs/architecture/TRD-003`](docs/architecture/TRD-003_Data_Model_State_Management.md) — Data Model & State Management

## License

Creative Development — Confidential
