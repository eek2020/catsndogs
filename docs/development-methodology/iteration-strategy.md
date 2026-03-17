# Iteration Strategy Guide

When to keep iterating, when to stop, and when to escalate. Adapted from the godogen methodology.

## Progress-Based Stopping Criteria

Judge when to stop based on **progress signals**, not arbitrary iteration counts.

### Keep Going When
- Each iteration produces measurable improvement
- The fix pattern is clear and converging
- Visual output is getting closer to the goal
- Errors are decreasing in severity

### Stop Early When
- A fundamental limitation is recognized (engine capability, asset quality, architectural mismatch)
- Making the same fix repeatedly without convergence (red flag)
- The remaining gap is cosmetic, not functional
- The task's core goal is achieved even if imperfect

### Escalate When
- An architectural change is needed that affects other systems
- The problem requires a different approach entirely
- The fix would break existing functionality
- You've spent 3+ cycles on the same issue without progress

## Iteration Workflow

```
1. Implement change
2. Verify (run scene, capture screenshot, check assertions)
3. Assess:
   - Goal met? → Done
   - Progress? → Continue (go to 1)
   - Stuck? → Escalate or pivot
```

## Common Iteration Patterns

### Visual QA Loop
1. Implement scene/script changes
2. Capture screenshots
3. Review for issues (see QA checklist)
4. Fix issues found
5. Re-capture and compare
6. Max 3 fix-and-rerun cycles before escalating

### Physics Tuning
1. Set initial values based on game feel target
2. Run and observe behavior
3. Adjust one parameter at a time
4. Compare before/after
5. Stop when movement "feels right" — don't over-tune

### Architecture Pivot Signals
- **"I need to restructure the scene tree"** → Consider if the current structure is fundamentally wrong or just needs adjustment
- **"This signal flow is getting circular"** → Introduce an EventBus pattern or mediator
- **"Performance is degrading"** → Profile before optimizing; switch to server API for bulk objects

## Anti-Patterns

- **Blind retry** — repeating the exact same approach hoping for a different result
- **Gold plating** — continuing to polish when the goal is already met
- **Scope creep** — fixing unrelated issues discovered during iteration
- **Premature optimization** — tuning performance before the feature works correctly
- **Ignoring convergence** — not tracking whether each iteration actually improves things
