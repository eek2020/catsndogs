# Game Plan: Whisper Crystals

## Game Description

Whisper Crystals is a narrative-driven 2D side-scrolling space pirate game built in Godot 4.6 with GDScript. The player commands Aristotle, a cat pirate captain who controls the multiverse's only source of starship fuel. A 4-arc story with 8 factions, data-driven JSON content, and systems for combat, economy, crew, and faction diplomacy.

## Task DAG Format

Tasks follow this structure:

```text
## N. {Task Name}
- **Status:** pending | in_progress | done
- **Depends on:** (none) | task numbers
- **Goal:** {What this task achieves and why it matters}
- **Requirements:**
  - {High-level, testable behavior}
- **Assets needed:** {Visual assets required — type, size, visual role}
- **Verify:** {What screenshots should show to prove the task works}
```

### Task Status Values

- `pending` — not yet started
- `in_progress` — currently being worked on
- `done` — completed and verified

### Guidelines

- Minimize total task count — bundle routine features, isolate only genuine algorithmic risks
- Each task should be independently verifiable
- Verify criteria should be concrete enough that screenshots can prove pass/fail
- Dependencies form a DAG — no cycles

## Current Tasks

<!-- Add tasks here as development progresses -->
