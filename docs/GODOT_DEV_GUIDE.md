# Whisper Crystals — Godot Development Guide

Central reference for Godot 4.6 development on Whisper Crystals. All resources below were integrated from the [godogen](godogen/) game development pipeline, adapted for this project.

## Quick Start

1. **Read CLAUDE.md** — project conventions and architecture rules
2. **Read MEMORY.md** (project root) — accumulated knowledge and known quirks
3. **Check docs/MASTER_PLAN.md** — authoritative project plan, open issues, and roadmap
4. **Reference this guide** — links to all development resources below

## GDScript Reference

| Document | Description |
| ---------- | ------------- |
| [gdscript-reference.md](godot-reference/gdscript-reference.md) | Complete syntax, types, operators, patterns |
| [quirks-and-gotchas.md](godot-reference/quirks-and-gotchas.md) | Known engine issues, type inference errors, runtime pitfalls |
| [best-practices.md](godot-reference/best-practices.md) | Coding standards and patterns for Godot |
| [quick-refs/gdscript-cheat-sheet.md](godot-reference/quick-refs/gdscript-cheat-sheet.md) | Quick reference card |
| [quick-refs/common-nodes.md](godot-reference/quick-refs/common-nodes.md) | Common node types and use cases |

## Development Patterns

| Document | Description |
| ---------- | ------------- |
| [scene-generation-patterns.md](godot-reference/scene-generation-patterns.md) | Building .tscn files programmatically |
| [script-generation-patterns.md](godot-reference/script-generation-patterns.md) | Runtime script templates and patterns |
| [scene-script-coordination.md](godot-reference/scene-script-coordination.md) | Rules for coordinating scenes and scripts |
| [test-harness-patterns.md](godot-reference/test-harness-patterns.md) | Testing approaches for Godot scenes |
| [screenshot-capture.md](godot-reference/screenshot-capture.md) | Screenshot and video capture workflow |

## Godot API Reference

- [api/_common.md](godot-reference/api/_common.md) — Index of ~128 most-used classes (one-line descriptions)
- [api/_other.md](godot-reference/api/_other.md) — Index of ~730 remaining classes
- [api/{ClassName}.md](godot-reference/api/) — 862 individual class docs with properties, methods, signals

**Usage:** Check `_common.md` first for frequently used classes. Load individual class docs on-demand when you need full API details.

## Development Methodology

| Document | Description |
| ---------- | ------------- |
| [task-decomposition.md](development-methodology/task-decomposition.md) | How to break features into tasks |
| [architecture-planning.md](development-methodology/architecture-planning.md) | Scene hierarchy and script design |
| [iteration-strategy.md](development-methodology/iteration-strategy.md) | When to iterate, stop, or escalate |

## Quality Assurance

| Document | Description |
| ---------- | ------------- |
| [visual-qa-checklist.md](qa/visual-qa-checklist.md) | Manual QA checklists for screenshot review |

## Tools

All tools are in `tools/godot-dev/`:

### Sprite Tools (`tools/godot-dev/sprites/`)

- `spritesheet_template.py` — Generate numbered grid templates for sprite sheets
- `spritesheet_slice.py` — Slice sprite sheets into frames (4 modes: keep-bg, clean-bg, split-bg, split-clean)
- `requirements.txt` — Dependencies: Pillow

### Asset Processing (`tools/godot-dev/assets/`)

- `rembg_matting.py` — Background removal with alpha matting (handles semi-transparent materials)
- `requirements.txt` — Dependencies: rembg, pymatting, numpy, scipy, Pillow, onnxruntime

### Documentation Tools (`tools/godot-dev/docs/`)

- `godot_api_converter.py` — Convert Godot XML docs to Markdown
- `class_list.py` — Godot class categorization utilities
- `ensure_doc_api.sh` — Fetch latest Godot API docs

### Capture Tools (`tools/godot-dev/capture/`)

- `gpu_detect.sh` — Detect available GPU for Godot rendering
- `screenshot.sh` — Capture screenshots with GPU or software fallback

### Tool Setup

```bash
# Sprite tools
cd tools/godot-dev/sprites && pip install -r requirements.txt

# Asset processing (heavier dependencies)
cd tools/godot-dev/assets && pip install -r requirements.txt
```

## Examples

Working examples in `docs/godot-reference/examples/godot-patterns/`:

- **scene-builder-example/** — Scene builder that creates a 2D scene programmatically
- **runtime-script-example/** — Player controller with proper type annotations and signal patterns
- **test-harness-example/** — Test harness with simulated input and assertions

## Workflow Documents

| Document | Location | Purpose |
| ---------- | ---------- | --------- |
| docs/MASTER_PLAN.md | docs/ | Authoritative project plan, open issues, roadmap |
| docs/STRUCTURE.md | docs/ | Architecture reference: scenes, signals, systems |
| docs/GODOT_NOTES.md | docs/ | Godot engineering notes and discoveries |
| docs/NEXT_STEPS.md | docs/ | Active sprint plan |
| docs/architecture/CODE_REVIEW.md | docs/architecture/ | Current code review |

## Whisper Crystals Architecture

See [CLAUDE.md](../CLAUDE.md) for the canonical architecture reference. Key points:

- **Autoloads:** EventBus, GameSession, MusicManager
- **Data-driven:** All content in JSON under `godot/data/`
- **Event bus:** Decoupled communication between systems
- **Scene-based UI:** `.tscn` in `godot/scenes/ui/`, controllers in `godot/scripts/ui/`
