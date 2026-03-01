# Contributing to Whisper Crystals

This guide is for AI agents and developers picking up tasks from the implementation plan.

## Before You Start

1. Read `CLAUDE.md` in the project root for architecture rules and conventions
2. Check `docs/plans/PLAN-001_Task_Tracker.md` for available tasks
3. Verify your task's dependencies are marked complete before starting
4. Read all files listed in your task description before making changes

## Picking Up a Task

1. Find your task in the task tracker
2. Confirm all dependencies are complete (status: done)
3. Mark the task as "in-progress" in the tracker
4. Note the recommended model tier — tasks are sized for specific capability levels

## Branch Naming

Use the pattern: `task/{task-id}_{short-description}`

Examples:

- `task/0.1_extract-game-session`
- `task/1.1_save-load-manager`
- `task/3.1_arc2-encounter-data`

## Implementation Checklist

For every task:

- [ ] Read all files to be modified before making changes
- [ ] Follow the Engine Abstraction Layer rules (see CLAUDE.md)
- [ ] Write or update tests for any new logic
- [ ] Run `pytest tests/ -v` — all tests must pass
- [ ] Verify no pygame imports leaked into core/systems/entities
- [ ] Update the task tracker with completion date
- [ ] Add a changelog entry in `docs/changelog/CHANGELOG.md`

## Code Review Process

Reviews are required for Phase 0 tasks and any task that modifies core architecture.

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

1. Create: `docs/decisions/ADR-{NNN}_{decision-title}.md`
2. Use the template from `docs/decisions/ADR_TEMPLATE.md`
3. Move superseded ADRs to `docs/decisions/archive/`

## Content Authoring (Phase 3)

For encounter data, dialogue, and other JSON content:

- Use `data/encounters/arc1_encounters.json` as the reference schema
- All encounter IDs follow pattern: `enc_{arc}_{description}`
- All story flag names follow pattern: `{arc}_{event_description}`
- Validate JSON structure matches existing entity `from_dict()` methods
- Write integration tests that walk through the arc programmatically

## Archiving Completed Documents

When all items in a document are complete:

1. Copy the document to the appropriate `archive/` directory
2. Add a note at the top: `ARCHIVED: {date} — All items complete`
3. Keep the original in place as reference until the next planning cycle
