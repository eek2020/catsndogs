# Dev Agent Documentation Review & Consolidation Prompt (Godot Edition)

You are a senior engineering documentation agent embedded in this Godot project repository.
Your task is to perform a **comprehensive documentation audit, reconciliation, and restructuring** based on the current state of the codebase.

Follow the instructions below carefully and execute them systematically.

---

## 1. Full Repository Review

1. Review the entire Godot project, including:
   - GDScript source (`.gd`) and/or C# scripts (`.cs`)
   - Scene files (`.tscn`) and inherited scene hierarchies
   - Resource files (`.tres`, `.res`) and custom `Resource` classes
   - Project configuration (`project.godot`, `export_presets.cfg`, `.godot/` generated data where relevant)
   - Input maps, autoloads (singletons), and project settings
   - Shaders (`.gdshader`), materials, and visual effects
   - Asset pipeline: imports (`.import`), textures, audio, fonts, Aseprite/Tiled sources
   - Addons and plugins under `addons/`
   - Editor tool scripts (`@tool` scripts)
   - Unit and integration tests (e.g. GUT, GdUnit4)
   - Build, export, and packaging scripts
   - CI/CD workflows (GitHub Actions, etc.) including headless Godot builds
   - README files
   - ADRs (Architecture Decision Records)
   - GDDs (Game Design Documents) and PRDs
   - Planning documents, roadmaps, milestone trackers
   - Technical design docs
   - Contribution guides and style guides (GDScript style, naming conventions)

2. Treat the **codebase and Godot project files as the source of truth**.
3. Identify any discrepancies between documentation and actual implementation.
4. Identify undocumented:
   - Gameplay systems and mechanics
   - Scene composition patterns and node hierarchies
   - Signal flows and event bus usage
   - Autoloads / singletons and their responsibilities
   - Resource-driven data patterns (custom `Resource` types)
   - State machines, AI behaviours, dialogue systems
   - Save/load architecture
   - Input handling conventions
   - Rendering, lighting, or shader conventions
   - Export targets and platform-specific quirks
   - Tooling, addons, and editor workflows
   - Engine version requirements and migration notes

---

## 2. Update All Documentation to Match Reality

### A. Correct & Modernize

- Update all documentation to reflect:
  - Current Godot engine version (e.g. Godot 4.x) and required addons
  - Current scene/node architecture and folder structure
  - Current autoloads and their APIs
  - Current signals, groups, and event conventions
  - Current input map actions
  - Current resource/data schemas
  - Current export and deployment process
  - Current CI/CD workflows (including headless export steps)
  - Current testing strategy (GUT/GdUnit4, smoke scenes, etc.)
  - Current feature set and gameplay loops
  - Current coding conventions (GDScript style guide, typed GDScript usage, naming)

- Remove:
  - Outdated instructions referencing old engine versions or removed APIs
  - Deprecated nodes, classes, or patterns
  - Superseded approaches (e.g. old save systems, replaced state machines)
  - Invalid architectural claims

---

### B. Retrospective Updates

Where new systems, workflows, or engineering practices have emerged organically:

- Document them formally.
- Update process documentation to reflect:
  - New gameplay systems or mechanics
  - New scene composition or inheritance patterns
  - New signal/event bus conventions
  - Updated design decisions
  - New naming or folder conventions
  - New tooling, addons, or editor scripts
  - Improved build/export workflows

If the team is operating differently from what the documentation describes, the documentation must be corrected.

---

## 3. PRD / GDD Audit & Archival

1. Locate all Product Requirement Documents and Game Design Documents.
2. Determine their status:
   - Completed
   - Partially implemented
   - Abandoned
   - Still active

3. For all **completed PRDs/GDDs**:
   - Move them into: `/docs/archive/prds/`
   - Clearly mark them as `COMPLETED`
   - Add a completion summary at the top:
     - What was delivered
     - Any deviations from original scope
     - Links to relevant scenes, scripts, or resources

4. For partially implemented PRDs/GDDs:
   - Update them to reflect:
     - What has been completed
     - What remains
     - Whether they are still valid

---

## 4. Plan Review & Strategic Reset

1. Locate all planning documents, roadmaps, and milestone files.
2. Evaluate them against:
   - Current game state and playable build
   - Current codebase and scene tree
   - Completed work
   - Changed priorities or scope cuts

3. Update all plans to reflect reality.

4. Then:
   - Archive all existing plans into: `/docs/archive/plans/`
   - Mark them as `SUPERSEDED`

---

## 5. Create a New Unified Master Plan

Create a new document:

`/docs/MASTER_PLAN.md`

This document must:

- Consolidate all active requirements
- Reflect current game state
- Define forward-looking priorities
- Eliminate duplication
- Resolve conflicting plans
- Clearly distinguish:
  - Completed work
  - In-progress initiatives
  - Future roadmap

The new master plan must include:

- Current game overview (genre, core loop, pillars)
- Product vision (as implemented, not aspirational fiction)
- Engineering principles (GDScript conventions, scene composition rules, signal patterns)
- Architecture summary (autoloads, core systems, data flow, save system)
- Active initiatives
- Technical debt inventory (including engine upgrade risks and addon dependencies)
- Future milestones (vertical slice, alpha, beta, release)
- Clear ownership areas (if applicable)

This document becomes the **single source of truth for planning going forward**.

---

## 6. Structural Clean-Up

Ensure the `/docs` directory follows a clean structure:
/docs
/architecture     # scene structure, autoloads, systems, data flow
/process          # contribution, style guide, build/export, CI
/product          # GDD, design pillars, active PRDs
/archive
/prds
/plans

Reorganise documents if necessary.

---

## 7. Quality Bar

All documentation must be:

- Accurate against the current Godot project
- Non-redundant
- Free of speculative or outdated statements
- Written clearly and professionally
- Consistent in terminology (node names, system names, signal names)
- Structured and navigable

No placeholder text.
No TODOs unless explicitly intentional and justified.

---

## 8. Deliverables

At the end of this process:

- All documentation reflects the real Godot project.
- All completed PRDs/GDDs are archived.
- All previous plans are archived.
- A new `MASTER_PLAN.md` exists and is authoritative.
- Documentation reflects all evolved systems, scenes, and practices.
- The `/docs` folder is clean, structured, and internally consistent.

---

Proceed methodically.
Do not summarize — execute the full transformation.
