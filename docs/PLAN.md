# Game Plan: Whisper Crystals

**Status (2026-04-16):** The active sprint plan lives in [`NEXT_STEPS.md`](NEXT_STEPS.md), and the authoritative issue tracker + sprint tables live in [`MASTER_PLAN.md`](MASTER_PLAN.md). This file is kept as a **task DAG template** for future heavy-duty planning work; it is **not** the current working task list.

When a future sprint needs a DAG with cross-task dependencies that doesn't fit the linear sprint structure in `NEXT_STEPS.md`, populate the `## Current Tasks` section below following the format in the next section.

## Game Description

Whisper Crystals is a narrative-driven 2D side-scrolling space pirate game built in Godot 4.6 with GDScript. Players command Aristotle (cat) or Dave (dog), captains caught in a multiverse-wide struggle over the only source of starship fuel. A 10-arc story with 8 factions, dual protagonist paths, data-driven JSON content, and systems for combat, economy, crew, hazards, realm control, karma, and faction diplomacy.

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

<!--
  Empty by design. Live sprint work tracked in NEXT_STEPS.md §2.
  Populate this section for DAG-shaped work that doesn't fit linear sprints.
-->
