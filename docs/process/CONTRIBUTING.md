# Contributing to Whisper Crystals

This guide is for AI agents and developers picking up tasks.

## Before You Start

1. Read `CLAUDE.md` in the project root for architecture rules and conventions
2. Check `docs/MASTER_PLAN.md` for active tasks and current priorities
3. Verify your task's dependencies are marked complete before starting
4. Read all files listed in your task description before making changes

## Picking Up a Task

1. Find your task in `docs/MASTER_PLAN.md` under "Active Initiatives"
2. Confirm all dependencies are complete
3. Note the recommended model tier — tasks are sized for specific capability levels

## Branch Naming

Use the pattern: `task/{task-id}_{short-description}`

Examples:

- `task/0.1_extract-game-session`
- `task/1.1_save-load-manager`
- `task/sm-01_side-mission-system`

## Implementation Checklist

For every task:

- [ ] Read all files to be modified before making changes
- [ ] Follow the Engine Abstraction Layer rules (see CLAUDE.md)
- [ ] Write or update tests for any new logic
- [ ] Run `pytest tests/ -v` — all tests must pass
- [ ] Verify no pygame imports leaked into core/systems/entities
- [ ] Update `docs/MASTER_PLAN.md` with completion status
- [ ] Add a changelog entry in `docs/changelog/CHANGELOG.md`

## Code Review Process

Reviews are required for tasks that modify core architecture or cross-cutting concerns.

### Filing a Review

1. Create a new file: `docs/reviews/REVIEW-{NNN}_{task-id}.md`
2. Use the template from `docs/reviews/REVIEW_TEMPLATE.md`
3. Log it in `docs/reviews/REVIEW_LOG.md`

### Review Checklist

- Does the change maintain EAL compliance?
- Do all tests pass?
- Is the code consistent with existing patterns?
- Are there any new pygame imports outside of `engine/`?
- Is the change backward-compatible with the save file schema?

## Filing Issues

When you encounter a bug or problem during implementation:

1. Create a new file: `docs/issues/open/ISSUE-{NNN}_{short-description}.md`
2. Use the template from `docs/issues/ISSUE_TEMPLATE.md`
3. Log it in `docs/issues/ISSUE_LOG.md`
4. Move to `in-progress/` when work begins
5. Move to `closed/` when resolved

## Architecture Decision Records

When a task requires an architectural decision (choosing between approaches, changing patterns):

1. Create: `docs/architecture/decisions/ADR-{NNN}_{decision-title}.md`
2. Use the template from `docs/architecture/decisions/ADR_TEMPLATE.md`
3. Add a SUPERSEDED header to any ADR that is replaced by a new decision

## Content Authoring

For encounter data, dialogue, and other JSON content:

- Use `data/encounters/arc1_encounters.json` as the reference schema
- All encounter IDs follow pattern: `enc_{arc}_{description}`
- All story flag names follow pattern: `{arc}_{event_description}`
- Validate JSON structure matches existing entity `from_dict()` methods
- Write integration tests that walk through the arc programmatically

## Documentation Structure

```
docs/
├── MASTER_PLAN.md          # Single source of truth for planning (read this first)
├── architecture/           # TRDs and ADRs
│   ├── TRD-001 to TRD-003  # Technical Reference Documents
│   └── decisions/          # ADR-001+, ADR_TEMPLATE
├── process/                # This file and process documentation
├── changelog/              # CHANGELOG.md
├── issues/                 # open/, in-progress/, closed/
├── reviews/                # Code reviews and remediation plans
└── archive/                # Completed/superseded documents
    ├── prds/               # Archived PRDs with completion summaries
    └── plans/              # Archived PLAN-001, PLAN-002
```
