# Task Decomposition Guide

How to break game features into development tasks. Adapted from the godogen decomposer methodology.

## Core Philosophy

**Minimize the total number of tasks.** Each task boundary is an integration risk point. A capable developer (or AI agent) can implement entire standard games in a single pass. Over-decomposition creates merge friction, loss of holistic context, and compounding integration failures.

A standard 2D arcade or puzzle game should rarely exceed 3 tasks. A complex game with genuinely hard algorithms might need 7.

## The Two-Phase Approach

### Phase 1 — De-risk

Scan for "hard" algorithmic features. If any exist, create isolated early tasks for them **only**. Each gets a minimal test environment that exercises the real challenge (not a simplified version). These tasks run first so failures are caught with clean signal, before the rest of the game adds noise.

### Phase 2 — Bundle

Once algorithmic risks are handled (or if the game has none), bundle ALL remaining standard logic into as few tasks as possible. A single task can encompass player mechanics, enemies, UI, scoring, and level design if they're all routine work.

## What Counts as "Hard" (Isolate)

Features that fail unpredictably, require multiple iteration cycles, and produce ambiguous errors when mixed with other systems:

- **Procedural generation** — terrain, levels, meshes, dungeon layouts
- **Procedural animation** — runtime bone manipulation, inverse kinematics, ragdoll blending
- **Complex vehicle physics** — wheel colliders, suspension, drifting, motorcycle balance
- **Custom shaders** — water surfaces, portals, screen-space effects, dissolve/distortion
- **Runtime geometry** — destructible environments, CSG operations, mesh deformation
- **Dynamic navigation** — pathfinding that adapts to runtime obstacles, crowd simulation, flocking
- **Complex camera systems** — third-person with collision avoidance, cinematic rail transitions, split-screen

## What Counts as "Routine" (Bundle)

Patterns that Godot handles well and that a strong developer implements reliably. Never isolate these:

- **CharacterBody movement** — walking, jumping, gravity, slopes (`move_and_slide`)
- **Collision and triggers** — Area signals, damage on contact, pickups, zones
- **AnimationPlayer / AnimationTree** — playing animations, blend trees, state transitions
- **TileMap / GridMap levels** — tile-based or grid-based world building
- **NavigationAgent** — basic pathfinding on static navmesh
- **UI with Control nodes** — HUD, menus, health bars, score display, pause screens
- **Spawning, timers, waves** — enemy spawners, cooldowns, wave progression
- **Camera follow** — smooth follow, lerp-based tracking, fixed offsets
- **State machines, input handling** — player states, input mapping

## Whisper Crystals Feature Classification

### Hard (Isolate if Implementing)
- Dialogue tree engine with branching and state tracking
- Economy simulation with supply/demand across factions
- Procedural encounter generation

### Routine (Bundle)
- Navigation/flight UI
- HUD overlay (crystals, hull, missions)
- Combat transitions and resolution
- Crew management UI
- Faction reputation display
- Mission log overlay
- Side mission lifecycle
- Save/load serialization

## Task Format

```markdown
## N. {Task Name}
- **Status:** pending | in_progress | done
- **Depends on:** (none) | task numbers
- **Goal:** {What this task achieves and why it matters}
- **Requirements:**
  - {High-level, testable behavior}
- **Assets needed:** {Visual assets required}
- **Verify:** {What screenshots should show to prove the task works}
```

## Guidelines

- **Independence = Blast Radius Control** — two hard features that don't share runtime state should be separate tasks with no dependency. When one fails, the other is unaffected.
- **Verification Must Be Visual and Concrete** — the Verify field describes expected visual outcomes specific enough that screenshots can prove pass/fail.
- **No Implementation Recipes** — requirements describe *what the player experiences*, not *how* to implement it. A capable developer makes good implementation decisions.
- **Don't Isolate Routine Work** — the merge cost of splitting routine features outweighs the isolation benefit.

## Example Task Counts

| Game Type | Tasks | Rationale |
|-----------|-------|-----------|
| Bomberman | 2 | No algorithmic risk: visual setup + core game loop |
| 3D flight through procedural canyons | 3 | Canyon generation is hard; flight mechanics and game completion are routine |
| Tower defense with dynamic pathfinding | 3 | Pathfinding is hard; towers and game loop are routine |
