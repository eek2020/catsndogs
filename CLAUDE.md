# Whisper Crystals — AI Agent Instructions

This file contains project conventions and rules for any AI agent working on this codebase.

## Project Overview

Whisper Crystals is a narrative-driven 2D side-scrolling space pirate game built in Python/Pygame-CE. The player commands Aristotle, a cat pirate captain who controls the multiverse's only source of starship fuel.

## Tech Stack

- **Language:** Python 3.11+
- **Game Library:** pygame-ce 2.4.1+
- **Testing:** pytest 8.0+
- **Linting:** ruff 0.2+
- **Target:** Desktop (Mac M3/M4 primary, Windows compatible)

## Architecture Rules (Non-Negotiable)

### Engine Abstraction Layer (EAL)

The most critical architecture rule: **game logic must never import pygame**.

- `core/` — Engine-agnostic game logic. ZERO pygame imports. ZERO engine imports.
- `entities/` — Dataclass models. ZERO pygame imports.
- `systems/` — Game systems operating on entities. ZERO pygame imports.
- `engine/` — Pygame-specific implementations. Only place pygame is allowed.
- `ui/` — UI state classes. Must use `RenderInterface` from `core/interfaces.py`, never `pygame` directly.

**Verification:** `grep -r "import pygame" src/whisper_crystals/core/ src/whisper_crystals/systems/ src/whisper_crystals/entities/` must return zero results.

### State Machine

All game states are managed via `core/state_machine.py` (push/pop/switch stack). No ad-hoc boolean flags for state management. Each UI screen implements the `GameState` ABC (enter, exit, handle_input, update, render).

### Data-Driven Content

All story, dialogue, encounters, factions, and ship data live in JSON files under `data/`. Never hardcode narrative or game content in Python source.

### Entity Serialization

All entities in `entities/` must implement `to_dict()` and `from_dict()` class methods for JSON serialization.

### Event Bus

Use `core/event_bus.py` (pub/sub) for decoupled communication between systems. Systems should publish events rather than directly calling each other.

## File Layout

```text
src/whisper_crystals/
  core/           # Game logic, state machine, data loading, event bus, interfaces
  entities/       # Dataclass models (character, ship, faction, crystal, encounter)
  systems/        # Game systems (combat, narrative, faction, economy, crew)
  engine/         # Pygame rendering, input, audio, camera, asset management
  ui/             # UI state classes (menu, navigation, dialogue, combat, etc.)
data/             # JSON content files (encounters, factions, ships, story, dialogue)
tests/            # Pytest test suite
docs/             # PRDs, TRDs, plans, reviews, issues, decisions, changelog
design/           # Art direction, UI/UX specs, ship designs
story/            # Narrative reference (arcs, characters, factions)
```

## Testing Requirements

- All new systems must have corresponding tests in `tests/`
- Run `pytest tests/ -v` before marking any task complete
- Game logic tests must run without a pygame display context
- Integration tests should walk through game flows programmatically

## Coding Conventions

- Type hints on all public function signatures
- Docstrings on all classes and public methods
- Line length: 100 characters (ruff enforced)
- Use dataclasses for entities, not plain dicts
- Standard OOP patterns — no clever tricks, prefer explicit over implicit
- Small classes doing one thing each

## Task Workflow

1. Check `docs/archive/plans/PLAN-001_Task_Tracker.md` for your assigned task
2. Read the task description, dependencies, and acceptance criteria
3. Read all files you will modify before making changes
4. Implement the changes
5. Run `pytest tests/ -v` and fix any failures
6. Update the task tracker (mark complete, add date)
7. If the task requires a review, file one in `docs/reviews/`
8. Add an entry to `docs/changelog/CHANGELOG.md`

## Migration Classification

Every module has a migration class for future Godot/Unity port:

- **PORTABLE:** Pure Python logic. Transfers as-is. (core/, entities/, systems/)
- **REWRITE:** Engine-specific. Must be rebuilt. (engine/, ui/)
- **ABSTRACTED:** Behind an interface to isolate engine dependency. (save system)

## Key Files

- `core/interfaces.py` — ABC interfaces for RenderInterface, InputInterface, AudioInterface
- `core/state_machine.py` — GameStateMachine and GameState ABC
- `core/event_bus.py` — Pub/sub event system
- `core/game_state.py` — Master GameStateData container
- `data/encounters/arc1_encounters.json` — Reference schema for all encounter data
- `data/factions/faction_registry.json` — All faction definitions and relationship matrix
