# TRD-001: Technical Architecture & Stack

**Project:** Whisper Crystals — A Space Pirates Game  
**Version:** 0.1  
**Date:** February 2026  
**Classification:** Creative Development — Confidential  

---

## Section 1: Executive Summary

This document defines the technical architecture, technology stack, and structural conventions for the Whisper Crystals Phase 1 prototype. The architecture prioritises separation of concerns, data-driven content, and engine-agnostic game logic to enable future migration to Godot or Unity. The prototype is built in Python 3.11+ using Pygame-CE for rendering, with all game state persisted as JSON.

---

## Section 2: Technology Stack

| Component | Technology | Version | Notes |
|-----------|-----------|---------|-------|
| Language | Python | 3.11+ | Type hints required on all public interfaces |
| Game Library | pygame-ce | 2.4.1+ | Community Edition preferred for Apple Silicon performance |
| Architecture | Object-oriented | — | Modular package structure from day one |
| Data Persistence | JSON | — | Local filesystem; human-readable save files |
| Content Data | JSON / YAML | — | Story, dialogue, encounters, faction data loaded at runtime |
| Asset Format | PNG (sprites) | — | Placeholder assets acceptable for prototype |
| Testing | pytest | 8.0+ | Unit tests on all game logic modules |
| Version Control | Git | — | Feature branch workflow; GitHub hosted |
| Package Management | pip + venv | — | requirements.txt for dependency pinning |
| Linting | ruff | 0.2+ | Enforced via pre-commit hook |

### Environment Setup

```bash
# Create virtual environment
python3.11 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run the game
python -m whisper_crystals

# Run tests
pytest tests/ -v
```

### Mac M3/M4 Considerations

- **pygame-ce** is recommended over standard pygame for native Apple Silicon (ARM64) support
- Ensure Python 3.11+ is the ARM64 build (not Rosetta x86 emulation): `python3 -c "import platform; print(platform.machine())"` should return `arm64`
- SDL2 (pygame dependency) has full Metal rendering support on macOS — no OpenGL compatibility layer needed
- Audio subsystem: CoreAudio is the default backend on macOS; no additional configuration required

---

## Section 3: Architecture Principles & Constraints

### Principle 1: Separation of Concerns

**Constraint:** Game logic, rendering, and data must exist in separate modules with no cross-imports between rendering and core logic.

**Rationale:** Enables unit testing of game logic without a display context. Enables engine migration without rewriting game rules.

**Implementation:** The `core/` package contains all game logic. The `engine/` package contains all Pygame-specific rendering and input. The `data/` module handles loading/saving. Core never imports from engine.

### Principle 2: Migration-Ready (CRITICAL — Non-Negotiable)

**Constraint:** No Pygame-specific logic may exist in any module outside of `engine/`. All game logic must be callable without initialising a Pygame display. The Phase 1 Python/Pygame prototype MUST be architected for clean migration to a commercial game engine (Godot 4 or Unity) in a later phase. This is not optional. Every technical decision in Phase 1 must be made with migration in mind. Any code that cannot be migrated must be explicitly documented as throwaway.

**Rationale:** The prototype is a proof of concept and narrative vehicle — not the final product. The architecture must ensure that when the decision is made to migrate, the core game logic, data models, story content, and asset pipeline transfer with minimal rework. The engine is replaceable. The game is not.

**Implementation:** Core modules operate on plain Python objects and dataclasses. The engine layer translates between Pygame events/surfaces and core interfaces. Every module specification must include a Migration Notes field stating whether it is: **PORTABLE** (pure logic, transfers as-is), **REWRITE REQUIRED** (engine-specific, must be rebuilt), or **ABSTRACTED** (wrapped behind an interface to isolate engine dependency).

### Principle 2a: Engine Abstraction Layer (EAL)

**Constraint:** All Pygame-specific code (rendering, input, audio, windowing) must sit behind an abstraction interface. Core game logic must never call Pygame directly.

**Rationale:** The EAL allows the engine to be swapped without touching game logic. Phase 1 implements the EAL with Pygame; Phase 2 implements it with Godot or Unity.

**Implementation:** Abstract base classes define the rendering, input, and audio interfaces:

```python
from abc import ABC, abstractmethod

class RenderInterface(ABC):
    """Abstract rendering interface. Pygame implements Phase 1; Godot/Unity Phase 2."""

    @abstractmethod
    def clear(self) -> None:
        pass

    @abstractmethod
    def draw_sprite(self, sprite_id: str, world_pos: tuple[float, float]) -> None:
        pass

    @abstractmethod
    def draw_text(self, text: str, pos: tuple[int, int], font_id: str,
                  color: tuple[int, int, int] = (255, 255, 255)) -> None:
        pass

    @abstractmethod
    def draw_rect(self, rect: tuple[int, int, int, int],
                  color: tuple[int, int, int], width: int = 0) -> None:
        pass

    @abstractmethod
    def present(self) -> None:
        pass


class InputInterface(ABC):
    """Abstract input interface. Returns engine-agnostic action enums."""

    @abstractmethod
    def poll_actions(self) -> list:
        """Return list of Action enums triggered this frame."""
        pass

    @abstractmethod
    def is_action_held(self, action) -> bool:
        pass

    @abstractmethod
    def should_quit(self) -> bool:
        pass


class AudioInterface(ABC):
    """Abstract audio interface."""

    @abstractmethod
    def play_sfx(self, sfx_id: str) -> None:
        pass

    @abstractmethod
    def play_music(self, music_id: str, loop: bool = True) -> None:
        pass

    @abstractmethod
    def stop_music(self) -> None:
        pass

    @abstractmethod
    def set_volume(self, volume: float) -> None:
        """Volume from 0.0 to 1.0."""
        pass
```

The Pygame implementations (`engine/renderer.py`, `engine/input_handler.py`, `engine/audio.py`) inherit from these ABCs. Core game logic only references the abstract interfaces.

### Principle 3: State Machine Driven

**Constraint:** All game states (MENU, NAVIGATION, ENCOUNTER, CUTSCENE, DIALOGUE, END) must be managed via an explicit state machine with defined transitions. No ad-hoc boolean flags for state management.

**Rationale:** Prevents state bugs (e.g., combat input processed during dialogue). Makes state transitions auditable and testable.

**Implementation:** `core/state_machine.py` defines a `GameStateMachine` with `push`, `pop`, and `switch` operations on a state stack.

### Principle 4: Data-Driven Content

**Constraint:** Story arcs, dialogue trees, encounter tables, faction data, and ship templates must be loaded from JSON/YAML files at runtime. No hardcoded narrative or game content in Python source.

**Rationale:** Enables content iteration without code changes. Enables modding. Simplifies testing with mock data.

**Implementation:** All content files live in `data/` directory. A `DataLoader` class in `core/data_loader.py` handles schema validation and loading.

---

## Section 4: Module & Package Structure

```
whisper_crystals/                   # Project root
├── src/
│   └── whisper_crystals/           # Main game package
│       ├── __init__.py
│       ├── __main__.py             # Entry point: python -m whisper_crystals
│       │
│       ├── core/                   # Engine-agnostic game logic
│       │   ├── __init__.py
│       │   ├── state_machine.py    # GameStateMachine — push/pop/switch states
│       │   ├── game_loop.py        # Core loop orchestrator (tick-based)
│       │   ├── data_loader.py      # JSON/YAML content loader with validation
│       │   ├── save_manager.py     # Save/load game state to JSON files
│       │   └── event_bus.py        # Pub/sub event system for decoupled communication
│       │
│       ├── entities/               # Data models and entity definitions
│       │   ├── __init__.py
│       │   ├── character.py        # Character dataclass (Aristotle, Dave, Death, NPCs)
│       │   ├── ship.py             # Ship dataclass (stats, damage, upgrades)
│       │   ├── faction.py          # Faction dataclass (registry, relationships)
│       │   ├── crystal.py          # WhisperCrystal resource model
│       │   └── encounter.py        # Encounter dataclass (triggers, outcomes)
│       │
│       ├── systems/                # Game systems operating on entities
│       │   ├── __init__.py
│       │   ├── combat.py           # Combat resolution logic
│       │   ├── trade.py            # Trade/negotiation logic
│       │   ├── diplomacy.py        # Diplomatic encounter logic
│       │   ├── exploration.py      # Exploration encounter logic
│       │   ├── faction_system.py   # Faction relationship calculations
│       │   ├── narrative.py        # Story arc progression and choice tracking
│       │   └── economy.py          # Crystal supply/demand and pricing
│       │
│       ├── engine/                 # Pygame-specific rendering and input
│       │   ├── __init__.py
│       │   ├── renderer.py         # Main rendering pipeline
│       │   ├── input_handler.py    # Keyboard/mouse input mapping
│       │   ├── asset_manager.py    # Sprite and audio asset loading/caching
│       │   ├── camera.py           # Viewport and scrolling camera
│       │   └── audio.py            # Sound effect and music playback
│       │
│       └── ui/                     # UI components (rendered via engine)
│           ├── __init__.py
│           ├── hud.py              # In-game HUD (stats, crystals, minimap)
│           ├── dialogue_ui.py      # Dialogue box with portraits and choices
│           ├── trade_ui.py         # Trade negotiation interface
│           ├── menu.py             # Main menu and pause menu
│           └── faction_screen.py   # Faction relationship status panel
│
├── data/                           # Data-driven content (JSON/YAML)
│   ├── encounters/                 # Encounter definition files
│   ├── dialogue/                   # Dialogue tree files
│   ├── factions/                   # Faction registry and relationship matrix
│   ├── ships/                      # Ship templates per faction
│   └── story/                      # Story arc definitions and flags
│
├── assets/                         # Game assets
│   ├── sprites/
│   │   ├── characters/             # Character portraits and sprites
│   │   ├── ships/                  # Ship sprites per faction
│   │   ├── ui/                     # UI element sprites
│   │   └── environment/            # Background and environment art
│   └── audio/
│       ├── sfx/                    # Sound effects
│       └── music/                  # Background music tracks
│
├── tests/                          # Pytest test suite
│   ├── test_state_machine.py
│   ├── test_combat.py
│   ├── test_trade.py
│   ├── test_faction_system.py
│   ├── test_narrative.py
│   └── test_save_load.py
│
├── docs/                           # Project documentation
│   ├── prd/                        # Product Requirements Documents
│   └── trd/                        # Technical Requirements Documents
│
├── requirements.txt
├── pyproject.toml
└── README.md
```

---

## Section 5: Data Flow Diagram (Text Description)

### Primary Data Flow: Game Tick

```
[Input Handler] → raw input events
       ↓
[Game State Machine] → determines active state
       ↓
[Active State Handler] → (Navigation / Combat / Trade / Dialogue)
       ↓
[Game Systems] → process logic (combat calc, trade eval, faction update)
       ↓
[Entity Updates] → modify Character, Ship, Faction, Crystal entities
       ↓
[Event Bus] → broadcast state changes (e.g., "faction_score_changed")
       ↓
[UI Components] → subscribe to events, update display state
       ↓
[Renderer] → draw current frame (background → entities → UI → HUD)
       ↓
[Display] → present frame to screen
```

### Secondary Data Flow: Save/Load

```
[Save Trigger] → (manual save / auto-save checkpoint)
       ↓
[Save Manager] → serialise all entity states + story flags + choice history
       ↓
[JSON File] → write to saves/slot_N.json

[Load Trigger] → (menu selection)
       ↓
[Save Manager] → read JSON, validate schema, deserialise
       ↓
[Entity Restoration] → rebuild all entities from saved state
       ↓
[State Machine] → set active state to saved position
```

### Tertiary Data Flow: Content Loading

```
[Game Init / Arc Transition]
       ↓
[Data Loader] → read data/encounters/*.json, data/dialogue/*.json, etc.
       ↓
[Schema Validation] → verify structure matches expected format
       ↓
[Content Registry] → index content by ID for runtime lookup
       ↓
[Systems] → query registry when encounters trigger or dialogue starts
```

---

## Section 6: Future Phase Migration Analysis

### 6.1 Module Migration Classification

All Phase 1 modules are pre-classified by migration complexity:

| Module | Migration Class | Pattern Used | Notes |
|--------|----------------|-------------|-------|
| `core/state_machine.py` | PORTABLE | State machine (push/pop/switch) | Pure Python logic. Direct port to GDScript or C#. |
| `core/game_loop.py` | PORTABLE | Tick-based orchestrator | Pure Python. Delta-time based. |
| `core/data_loader.py` | PORTABLE | JSON parser with validation | JSON parsing is native in both Godot and Unity. |
| `core/save_manager.py` | ABSTRACTED | JSON serialisation behind interface | JSON in Phase 1. Interface allows swap to engine-native system. |
| `core/event_bus.py` | PORTABLE | Pub/sub pattern | Standard pattern maps to Godot signals / Unity events. |
| `entities/*` | PORTABLE | Python dataclasses | Dataclass → Godot Resource / Unity struct. Data files migrate unchanged. |
| `systems/combat.py` | PORTABLE | Pure calculation functions | No engine dependency. |
| `systems/trade.py` | PORTABLE | Pure calculation functions | No engine dependency. |
| `systems/diplomacy.py` | PORTABLE | Pure calculation functions | No engine dependency. |
| `systems/narrative.py` | PORTABLE | JSON-driven state progression | Data files migrate unchanged. |
| `systems/economy.py` | PORTABLE | Pure calculation logic | No engine dependency. |
| `systems/faction_system.py` | PORTABLE | Pure calculation logic | No engine dependency. |
| `engine/renderer.py` | REWRITE | Implements `RenderInterface` ABC | Pygame surface/blit → Godot Node2D / Unity SpriteRenderer. |
| `engine/input_handler.py` | REWRITE | Implements `InputInterface` ABC | Pygame event loop → Godot Input / Unity InputSystem. |
| `engine/asset_manager.py` | REWRITE | Cache pattern behind loader interface | Pygame image.load → Godot ResourceLoader / Unity AssetBundle. |
| `engine/camera.py` | REWRITE | Manual viewport calculation | Manual viewport → Godot Camera2D / Unity Cinemachine. |
| `engine/audio.py` | REWRITE | Implements `AudioInterface` ABC | Pygame mixer → Godot AudioStreamPlayer / Unity AudioSource. |
| `ui/*` | REWRITE | Pygame surface drawing | Pygame surfaces → Godot Control nodes / Unity Canvas. |

For every **REWRITE** module, the Phase 1 implementation must inherit from the abstract interface defined in Section 3 (Principle 2a: EAL). For every **PORTABLE** module, the pattern used (dataclass, pure function, state machine) ensures portability.

### 6.2 Migration Risks

- **Risk:** Game systems accumulate Pygame-specific shortcuts over time. **Mitigation:** Code review gate — any PR touching `systems/` or `core/` must not import from `engine/`.
- **Risk:** Data file format drift between engines. **Mitigation:** Use JSON Schema validation; same schema works in all engines.
- **Risk:** Timing differences between Pygame clock and Godot/Unity frame timing. **Mitigation:** All game logic uses delta-time, never frame-count.
- **Risk:** EAL abstraction adds overhead for a single-developer project. **Mitigation:** Keep interfaces minimal; don't over-abstract. The vibe coding philosophy applies — simple interfaces that work, not enterprise patterns.

### 6.3 Migration Trigger Criteria

Migration from Python/Pygame to a commercial engine will be triggered when one or more of the following conditions are met:

1. The prototype successfully demonstrates all four story arcs end-to-end.
2. Performance limitations of Pygame prevent delivery of required visual quality or frame rate.
3. A collaborator or publisher requires a specific engine as a delivery condition.
4. The decision is made to target console or mobile platforms.

**Recommendation:** Evaluate Godot 4 first (open source, Python-adjacent GDScript, lighter overhead) before Unity (stronger commercial ecosystem, heavier tooling).

### 6.4 Migration-Ready Design Principles (Summary)

- **Engine Abstraction Layer (EAL):** All Pygame-specific code sits behind ABC interfaces (Section 3, Principle 2a).
- **Data-Driven Content:** All story, dialogue, encounters, factions, and characters in JSON/YAML — these migrate without changes.
- **Pure Python Game Logic:** State machine, combat, economy, narrative — zero engine dependencies. These are the migration payload.
- **Asset Independence:** All art assets in structured `/assets` directory with engine-agnostic manifest.
- **No Engine-Specific Patterns:** Standard OOP patterns that map to Godot Nodes or Unity GameObjects. No Pygame Sprite groups as primary architecture.

### 6.5 Collaboration Application API

The game state model (TRD-003) must expose a clean API or export format that the Phase 3 web-based collaboration dashboard can consume without coupling to the game engine. Requirements:

- Game state serialises to JSON (already required for save/load).
- A `GameStateExporter` utility class can produce a read-only snapshot of current state.
- Export format includes: arc progress, faction scores, character states, crystal economy data.
- The exporter is a PORTABLE module — no engine dependency.

---

*Cross-references: See TRD-002 for Pygame-specific implementation details. See TRD-003 for entity data models.*

*TRD-001 v0.2 | Whisper Crystals | Creative Development Confidential*
