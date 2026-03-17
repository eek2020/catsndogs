# Godogen Asset & Workflow Integration for Whisper Crystals

Integrate valuable Godot 4 development resources from the godogen folder into the Whisper Crystals project, excluding all API-dependent components (Gemini, Tripo3D, Claude Code skill invocations). This plan covers both concrete assets (docs, tools) and reworkable workflow patterns from the godogen skills orchestration system.

## Analysis Summary

The godogen folder contains a comprehensive Godot 4 game development pipeline with extensive documentation, tools, and best practices. After excluding API-dependent components, approximately 70% of its methodology and assets remain usable.

### Documentation Assets (API-Free)

- Complete GDScript language reference with type inference rules and common pitfalls
- 850+ Godot class API documentation in Markdown format
- Engine quirks and gotchas documentation
- Scene generation patterns and best practices
- Script generation patterns and templates
- Test harness patterns
- Project scaffolding guidelines

### Local Tools (No API Dependencies)

- Sprite sheet template generator (Python)
- Sprite sheet slicer (Python)
- Background removal with alpha matting (rembg + pymatting)
- Godot API documentation converter
- Class list utilities

### Reworkable Workflow Patterns

The godogen skills system uses a two-skill orchestration model (orchestrator + executor) with document-based state. While the skill invocation mechanism is Claude Code-specific, the underlying patterns are highly valuable:

| Pattern | Value | Description |
| --------- | ------- | ------------- |
| **Orchestration workflow** | High | Sequential pipeline with resume capability via PLAN.md, STRUCTURE.md, MEMORY.md, ASSETS.md as shared state documents |
| **Task decomposition** | High | "Minimize task count, bundle routine work, isolate algorithmic risks." Most features are routine — only isolate genuinely hard problems (procedural gen, custom physics, complex shaders). Each task boundary = integration risk |
| **Progressive doc loading** | High | Index files (`_common.md`, `_other.md`) with one-line descriptions; full class docs loaded on-demand; phase-specific guides loaded when needed |
| **Scene/script coordination** | High | Generate scenes first, name nodes predictably, attach scripts in scene builder, connect signals in scripts (not scenes), match `extends` to node type |
| **Test harness** | High | `extends SceneTree` for headless execution, `_initialize()` setup, console assertions, simulated input via Timers, camera positioning for verification |
| **Visual QA framework** | Medium | Structured checklists for evaluating screenshots — grid placement, scale, composition, z-fighting, clipping, placeholder remnants. Usable as manual QA checklists without the Gemini API |
| **Project memory (MEMORY.md)** | High | Read before starting work, write back discoveries after completing tasks. Preserves institutional knowledge across sessions |
| **Asset sizing discipline** | Medium | Every asset in ASSETS.md includes intended in-game size (sprite sheets: per-frame display size, backgrounds: pixel dimensions) to prevent scaling bugs |
| **Iteration philosophy** | Medium | Judge when to stop based on progress signals, not arbitrary counts. Keep going if there's progress; stop early if fundamental limitation recognized; red flag: "making same fix repeatedly without convergence" |
| **Capture workflow** | Low | GPU detection via glxinfo, hardware Vulkan when available, xvfb + lavapipe fallback, timeout safety nets |

## Excluded Components (API-Dependent)

The following will **NOT** be integrated as they require external API services:

- `asset_gen.py` — Requires Google Gemini API
- `tripo3d.py` — Requires Tripo3D API
- `visual_qa.py` — Requires Google Gemini API for vision analysis
- `visual-target.md` — References Gemini image generation
- `asset-gen.md` — Gemini/Tripo3D integration guide
- `asset-planner.md` — Budget-aware asset generation (API-based)
- Any SKILL.md files referencing Claude Code skill invocation system

**Alternative approaches:**

- Visual targets: Create reference images manually or use existing concept art
- Assets: Use traditional art pipeline, asset stores, or local generation tools
- Visual QA: Use VQA prompts as manual review checklists

## Integration Plan

### Phase 1: Documentation Structure + Core Workflow Documents

**Create documentation hierarchy in `/docs/godot-reference/`**

1. **Core Language Reference**
   - `gdscript-reference.md` — Complete GDScript syntax, types, operators, patterns
   - `quirks-and-gotchas.md` — Known engine issues, type inference errors, runtime pitfalls
   - `best-practices.md` — Coding standards and patterns specific to Godot

2. **Development Patterns**
   - `scene-generation-patterns.md` — Scene builder patterns, ownership chains, node compositions
   - `script-generation-patterns.md` — Runtime script templates, lifecycle methods, common patterns
   - `scene-script-coordination.md` — Rules for coordinating scene builders and runtime scripts (from `coordination.md`)
   - `test-harness-patterns.md` — Testing approaches for Godot scenes

3. **Godot API Reference**
   - `api/` directory with 850+ class documentation files
   - `api/_common.md` — Index of ~128 most common classes
   - `api/_other.md` — Index of remaining ~730 classes

4. **Core Workflow Documents**
   - `PLAN.md` template — Task DAG format with status tracking
   - `ASSETS.md` template — Asset manifest with sizing column
   - Initialize `MEMORY.md` with known Godot quirks from godogen

### Phase 2: Local Tools Integration

**Create `/tools/godot-dev/` directory for development utilities**

1. **Sprite Tools**
   - `spritesheet_template.py` — Generate numbered grid templates for sprite sheets
   - `spritesheet_slice.py` — Slice sprite sheets into individual frames
   - `requirements.txt` — Python dependencies (PIL/Pillow)

2. **Asset Processing**
   - `rembg_matting.py` — Advanced background removal with alpha matting
   - `requirements-assets.txt` — Dependencies (rembg, pymatting, numpy, scipy, PIL)

3. **Documentation Tools**
   - `godot_api_converter.py` — Convert Godot XML docs to Markdown
   - `class_list.py` — Godot class categorization utilities
   - `ensure_doc_api.sh` — Script to fetch latest Godot API docs

4. **Capture Tools**
   - `gpu_detect.sh` — GPU detection via glxinfo
   - `screenshot.sh` — Capture wrapper with xvfb fallback

### Phase 3: Development Methodology + Workflow Guides

**Create `/docs/development-methodology/` for planning frameworks**

1. **Task Decomposition Guide**
   - Extract decomposition strategies from `decomposer.md`
   - Adapt "hard vs routine" feature classification
   - Document minimal task decomposition philosophy
   - Include examples relevant to RPG/narrative games
   - Classify Whisper Crystals features: "hard" (dialogue tree engine, economy simulation) vs "routine" (UI, basic movement)

2. **Architecture Planning Guide**
   - Extract scaffolding patterns from `scaffold.md`
   - Document scene hierarchy design principles
   - Script responsibility patterns
   - Signal flow design

3. **Iteration Strategy Guide**
   - Progress-based stopping criteria
   - Escalation criteria for architectural issues
   - When to pivot vs persist

4. **Quality Assurance Framework**
   - Visual QA checklists adapted from VQA prompts (static and dynamic)
   - Implementation quality checks (grid placement, scale, composition)
   - Visual bug detection (z-fighting, clipping, floating objects, placeholder remnants)
   - Screenshot review workflow

### Phase 4: Testing Infrastructure

1. **Test Harness Templates** — `extends SceneTree` examples for headless verification
2. **Screenshot Capture Workflow** — Document capture commands for different scene types
3. **GPU Setup Guide** — Document setup for CI/CD environments

### Phase 5: Project-Specific Adaptations + Documentation

1. **Whisper Crystals Development Guide**
   - `/docs/GODOT_DEV_GUIDE.md` — Central reference linking to all godogen assets
   - Project-specific patterns (dialogue systems, crew management, economy)
   - Integration with existing architecture (TRD documents)

2. **Quick Reference Cards** (`/docs/godot-reference/quick-refs/`)
   - GDScript cheat sheet
   - Common node types and use cases
   - Debugging checklist

3. **Tool Configuration**
   - Set up Python virtual environment for tools
   - Create wrapper scripts for common operations
   - Document tool usage

4. **Example Implementations** (`/examples/godot-patterns/`)
   - Scene builder example
   - Runtime script example
   - Test harness example

## File Structure After Integration

```text
whisper_crystals/
├── PLAN.md                              # Task DAG (adapted from godogen)
├── ASSETS.md                            # Asset manifest with sizing
├── docs/
│   ├── GODOT_DEV_GUIDE.md              # Central reference
│   ├── godot-reference/
│   │   ├── gdscript-reference.md
│   │   ├── quirks-and-gotchas.md
│   │   ├── best-practices.md
│   │   ├── scene-generation-patterns.md
│   │   ├── script-generation-patterns.md
│   │   ├── scene-script-coordination.md
│   │   ├── test-harness-patterns.md
│   │   ├── screenshot-capture.md
│   │   ├── quick-refs/
│   │   │   ├── gdscript-cheat-sheet.md
│   │   │   └── common-nodes.md
│   │   └── api/
│   │       ├── _common.md
│   │       ├── _other.md
│   │       └── [850+ class files]
│   ├── development-methodology/
│   │   ├── task-decomposition.md
│   │   ├── architecture-planning.md
│   │   ├── iteration-strategy.md
│   │   └── workflow-pipeline.md
│   └── qa/
│       └── visual-qa-checklist.md
├── tools/
│   └── godot-dev/
│       ├── sprites/
│       │   ├── spritesheet_template.py
│       │   ├── spritesheet_slice.py
│       │   └── requirements.txt
│       ├── assets/
│       │   ├── rembg_matting.py
│       │   └── requirements.txt
│       ├── docs/
│       │   ├── godot_api_converter.py
│       │   ├── class_list.py
│       │   └── ensure_doc_api.sh
│       └── capture/
│           ├── gpu_detect.sh
│           └── screenshot.sh
└── examples/
    └── godot-patterns/
        ├── scene-builder-example/
        ├── runtime-script-example/
        └── test-harness-example/
```

## Success Criteria

- [ ] All documentation accessible in `/docs/godot-reference/`
- [ ] Tools functional with documented setup instructions
- [ ] Quick reference materials created for common tasks
- [ ] PLAN.md format adopted for task tracking
- [ ] MEMORY.md initialized with godogen quirks and in active use
- [ ] ASSETS.md template created with sizing column
- [ ] Task decomposition guide created for Whisper Crystals features
- [ ] Scene/script coordination patterns documented
- [ ] Test harness templates created
- [ ] Screenshot capture workflow established
- [ ] Manual QA checklist created from VQA prompts
- [ ] Iteration strategy documented
- [ ] Example implementations provided for key patterns
- [ ] Integration documented in GODOT_DEV_GUIDE.md
- [ ] All tools tested and working in project environment
- [ ] No API-dependent components included
