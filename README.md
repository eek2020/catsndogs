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
│   │   ├── ui/                   # UI scenes
│   │   │   ├── character_select.tscn
│   │   │   ├── dialogue_ui.tscn
│   │   │   ├── navigation.tscn
│   │   │   ├── combat_overlay.tscn
│   │   │   ├── purchase_screen.tscn
│   │   │   ├── ship_screen.tscn
│   │   │   ├── faction_screen.tscn
│   │   │   ├── mission_log.tscn
│   │   │   ├── settings_screen.tscn
│   │   │   ├── pause_menu.tscn
│   │   │   ├── arc_summary.tscn
│   │   │   └── ending_screen.tscn
│   │   └── components/           # Reusable UI components
│   ├── scripts/                  # GDScript source
│   │   ├── autoload/             # Singletons (EventBus, GameSession, MusicManager)
│   │   ├── core/                 # Core game logic
│   │   │   ├── game_state_data.gd
│   │   │   ├── data_loader.gd
│   │   │   └── narrative_system.gd
│   │   ├── entities/             # Data models
│   │   │   ├── ship.gd
│   │   │   ├── encounter.gd
│   │   │   ├── side_mission.gd
│   │   │   └── faction.gd
│   │   ├── systems/              # Game systems
│   │   │   ├── combat_system.gd
│   │   │   ├── economy_system.gd
│   │   │   ├── crew_morale_system.gd
│   │   │   ├── faction_system.gd
│   │   │   ├── encounter_engine.gd
│   │   │   ├── side_mission_system.gd
│   │   │   └── crew_trait_system.gd
│   │   └── ui/                   # UI controllers
│   │       ├── main.gd
│   │       ├── navigation.gd
│   │       ├── dialogue_ui.gd
│   │       ├── character_select.gd
│   │       └── [other UI controllers]
│   ├── data/                     # Data-driven content (JSON)
│   │   ├── characters/           # Protagonist and crew definitions
│   │   ├── encounters/           # Arc 1–4 encounter definitions
│   │   ├── dialogue/             # Dialogue trees
│   │   ├── factions/             # Faction registry
│   │   ├── ships/                # Ship templates and upgrades
│   │   ├── economy/              # Crystal deposits, supply routes, regions
│   │   ├── story/                # Arc definitions and story flags
│   │   └── side_missions/        # Side mission and distress signal data
│   ├── assets/                   # Game assets (sprites, audio)
│   │   ├── audio/                # Music and sound effects
│   │   ├── characters/           # Character portraits and sprites
│   │   └── artwork/              # Splash screens and UI art
│   └── shaders/                  # Custom shaders
│       └── hyperspace_jump.gdshader
├── docs/                         # Project documentation
│   ├── plans/                    # Active development plans
│   │   └── MASTER_PLAN.md        # Current project status and roadmap
│   ├── architecture/             # TRDs (tech specs) and ADRs
│   ├── changelog/                # CHANGELOG.md
│   ├── development-methodology/  # Development guides and patterns
│   └── archive/                  # Archived plans and documents
├── story/                        # Narrative reference materials
│   ├── arcs/                     # Story arc overviews
│   ├── characters/               # Character profiles
│   └── factions/                 # Faction lore
├── design/                       # Art direction, characters, artwork
│   ├── artwork/                  # Game art assets
│   ├── characters/               # Character concept art
│   └── art_direction/            # Visual style guides
└── tools/                        # Development tools and utilities
    ├── utils/                    # General utility scripts
    ├── godot-dev/                # Godot-specific tools
    ├── pipeline/                 # Asset pipeline tools
    ├── import_assets.sh          # Asset management
    └── rollback_import.sh        # Asset rollback
```

## Tech Stack

- **Engine:** Godot 4.6 (GL Compatibility renderer)
- **Language:** GDScript
- **Resolution:** 1280×720, canvas_items stretch mode
- **Target Platform:** Desktop (Mac M3/M4 primary, Windows compatible)

## Architecture Principles

- **Autoload singletons** — `EventBus`, `GameSession`, `MusicManager`, and `ProceduralMapManager` provide global services
- **Data-driven content** — Story, dialogue, encounters, factions loaded from JSON at runtime
- **Event bus** — Pub/sub system for decoupled communication between game systems
- **Scene-based UI** — UI screens are individual scenes managed via the scene tree

## Game State

The game is **fully playable** with complete implementation of all core systems and story content. Players can experience the full narrative arc from character selection through all four story arcs to one of three distinct endings.

### Completed Features

- **Dual Protagonist System:** Choose Aristotle (cat) or Dave (dog) with unique narrative paths
- **Complete Story Arcs:** All 4 arcs with encounter data, dialogue, and arc transition logic
- **Deep Lore System:** Comprehensive world-building with faction histories, character backstories, and crystal network mythology
- **Crew Recruitment:** 8 recruitable crew members (4 per protagonist) with trait bonuses and deep personal stories
- **Branching Dialogue:** Two-sided conversations with portrait support and multiple outcomes
- **Combat System:** Tactical combat with ship upgrades, damage calculations, and victory/defeat states
- **Economy & Trade:** Crystal extraction, supply routes, shipyard (repairs, upgrades, ship purchases)
- **Exploration:** Region discovery, POI scanning, exploration events
- **Faction System:** 8 factions with diplomacy, conquest AI, and realm control
- **Side Missions:** Optional missions and distress signal encounters
- **Save System:** 3-slot save/load with full game state persistence
- **Music & Audio:** Dynamic themes, volume control, and SFX support
- **Polish Features:** Arc transition animations, hyperspace jump effects, UI improvements

### Current Status

- **Engine:** Godot 4.6 (GL Compatibility) — Complete migration from Python prototype
- **Core Game:** Arcs 1-4 fully playable with 3 endings, 7 regions, dual protagonist paths
- **Expansion Content:** Arcs 5-10 have encounter data but are not integration-tested
- **Known Issues:** 18 issues identified in April 2026 code review, including 2 critical bugs — see `docs/CODE_REVIEW_2026-04-05.md`
- **Art Assets:** Core sprites and portraits integrated (crew portraits as placeholders)

See `docs/MASTER_PLAN.md` for the authoritative project plan and development status.

## Documentation

- [`docs/MASTER_PLAN.md`](docs/MASTER_PLAN.md) — Authoritative project plan: current state, tasks, roadmap
- [`docs/GAME_SUMMARY.md`](docs/GAME_SUMMARY.md) — Complete game design summary (implemented + planned content)
- [`docs/reviews/CODE_REVIEW_2026-04-05.md`](docs/reviews/CODE_REVIEW_2026-04-05.md) — Latest code review with open issues
- [`docs/STRUCTURE.md`](docs/STRUCTURE.md) — Architecture reference: scenes, signals, systems
- [`docs/NEXT_STEPS.md`](docs/NEXT_STEPS.md) — Active sprint plan (engineering + art tracks)
- [`docs/architecture/CODE_REVIEW.md`](docs/architecture/CODE_REVIEW.md) — Current code review (2026-04-16)
- [`.claude/PROJECT_INDEX.md`](.claude/PROJECT_INDEX.md) — AI agent project index and file location guide
- [`.claude/MEMORY.md`](.claude/MEMORY.md) — Global AI agent memory and technical patterns
- [`docs/story/LORE_EXPANSION.md`](docs/story/LORE_EXPANSION.md) — Deep world-building: faction histories, character backstories, crystal network mythology
- [`docs/changelog/CHANGELOG.md`](docs/changelog/CHANGELOG.md) — Detailed change log and development history
- [`docs/archive/`](docs/archive/) — Archived TRDs (Python-era), PRDs, old plans, superseded feature specs

## License

Creative Development — Confidential
