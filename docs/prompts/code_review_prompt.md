# Code Review Guidelines and Documentation Template (Godot Edition)

## Primary Objective

Conduct a thorough code review of a Godot project with actionable recommendations documented for team review and implementation planning.

---

## Review Criteria

### 1. Code Quality & Best Practices

- Evaluate adherence to the GDScript style guide (and/or C# conventions for Mono projects), including typed GDScript usage, naming conventions, and file organisation
- Assess scene composition, node hierarchy, and inheritance vs composition decisions
- Review use of autoloads (singletons), signals, groups, and event buses for appropriate coupling
- Check for proper error handling, `assert` usage, and `push_error` / `push_warning` logging
- Verify appropriate use of engine features (resources, tool scripts, `@export`, `@onready`) and avoidance of anti-patterns (e.g. `get_node` chains, tight scene coupling)
- Identify and analyse all forms of redundant code, including but not limited to:
  - Duplicate or near-duplicate logic, functions, classes, or code blocks
  - Repeated calculations, conditionals, or data transformations that could be centralised
  - Unused, unreachable, or dead code paths, including orphaned scenes, scripts, or resources
  - Redundant abstractions or over-engineered layers that do not provide clear value
  - Repeated configuration values, constants, or hard-coded literals that should live in a shared `Resource`, autoload, or constants script
  - Duplicate scenes or near-identical node trees that could be unified via inheritance or instancing
  - Redundant comments or documentation that restate what the code already expresses
- For each instance of redundancy, explain why it is redundant and propose a concrete refactoring or simplification.

### 2. Bug Detection & Edge Cases

- Identify potential null references, freed-object access (`is_instance_valid`), and type mismatches
- Analyse boundary conditions and input validation (including `InputEvent` handling)
- Check for frame-order issues between `_process`, `_physics_process`, `_ready`, and deferred calls
- Review signal connection/disconnection lifecycle and potential double-connects or dangling connections
- Evaluate coroutine/`await` usage, scene tree timing, and async resource loading pitfalls
- Check save/load robustness, resource serialisation, and migration of persisted data
- Review data validation and sanitisation for user-generated or imported content

### 3. Performance Optimization

- Identify computational bottlenecks in `_process` / `_physics_process` loops
- Review node count, scene instancing cost, and use of pooling vs frequent `queue_free`/`instantiate`
- Assess physics usage (areas vs bodies, collision layers/masks) and raycast frequency
- Review rendering cost: draw calls, overdraw, texture sizes, shader complexity, `VisibleOnScreenNotifier`, culling
- Evaluate memory patterns, resource caching, and avoidable reloads
- Check for unnecessary signal emissions, redundant UI redraws, or per-frame allocations
- Review export/import settings for textures, audio, and meshes against target platforms

### 4. Readability & Maintainability

- Assess code clarity, naming conventions (snake_case for GDScript), and self-documentation
- Evaluate function/method length and cyclomatic complexity
- Review scene readability: node naming, grouping, and folder structure under `res://`
- Review comment quality and necessity
- Check for code and scene duplication and refactoring opportunities
- Assess test coverage and testability (GUT, GdUnit4, or custom smoke scenes)

### 5. Security & Robustness Considerations

- Review handling of user input, file I/O, and any networking (`ENetMultiplayerPeer`, HTTP requests)
- Check for exposed secrets, API keys, or sensitive data in scripts, resources, or exported builds
- Assess safety of `load`/`ResourceLoader` paths and any use of `Expression` or dynamic code
- Review multiplayer authority, RPC modes, and trust boundaries if applicable
- Evaluate save file integrity and tamper resistance appropriate to the project's needs
- Review addon and plugin dependencies for maintenance status and known issues

---

## Output Requirements

For each identified issue or suggestion, provide:

- **Issue/Opportunity:** Clear description of the finding
- **Severity:** Critical / High / Medium / Low
- **Current Implementation:** Relevant code, scene, or resource excerpt
- **Proposed Solution:** Specific code example or approach
- **Reasoning:** Why this change matters
- **Expected Benefits:** Quantifiable improvements where possible (e.g. frame time, memory, draw calls)
- **Trade-offs:** Any downsides, complexity increases, or resource requirements
- **Effort Estimate:** Small / Medium / Large
- **Priority Recommendation:** Must-fix / Should-fix / Nice-to-have

---

## Deliverable Format

Create a structured document organised by review criteria, with a summary section highlighting:

- Critical issues requiring immediate attention
- Quick wins (high impact, low effort)
- Longer-term improvements for roadmap planning
- Overall code health score or assessment

---

## Code Review Documentation Template

### Executive Summary

- **Overall Assessment:** [Excellent / Good / Needs Improvement / Poor]
- **Total Issues Found:** [Number]
- **Critical Issues:** [Number]
- **Review Date:** [Date]
- **Reviewer:** [Name]
- **Project / Module Reviewed:** [Name / res:// path]
- **Godot Version:** [e.g. 4.x.y]

### Critical Issues (Immediate Action Required)

#### Issue #1: [Title]

- **Severity:** Critical
- **Category:** [Security / Performance / Bug / Architecture]
- **Location:** [res:// path, scene, or node]
- **Current Implementation:**

```gdscript
# code or scene excerpt
```

- **Proposed Solution:**

```gdscript
# improved code or scene excerpt
```

- **Reasoning:** [Explanation]
- **Expected Benefits:** [Specific improvements]
- **Trade-offs:** [Any drawbacks]
- **Effort Estimate:** [Small/Medium/Large]
- **Priority:** Must-fix

---

### High Priority Issues

#### Issue #2: [Title]

[Same structure as above]

---

### Medium Priority Issues

#### Issue #3: [Title]

[Same structure as above]

---

### Low Priority / Enhancements

#### Issue #4: [Title]

[Same structure as above]

---

### Quick Wins

List of high-impact, low-effort improvements:

1. [Issue #X] - [Brief description]
2. [Issue #Y] - [Brief description]

---

### Long-term Improvements

Items for technical roadmap:

1. [Issue #Z] - [Brief description with timeline recommendation]

---

### Positive Findings

Highlight well-implemented patterns and good practices:

- [Observation 1]
- [Observation 2]

---

### Recommendations Summary

| Issue ID | Title   | Severity | Effort | Priority   | Category    |
| -------- | ------- | -------- | ------ | ---------- | ----------- |
| #1       | [Title] | Critical | Medium | Must-fix   | Security    |
| #2       | [Title] | High     | Small  | Must-fix   | Bug         |
| #3       | [Title] | Medium   | Large  | Should-fix | Performance |

---

### Next Steps

1. [Action item with owner and timeline]
2. [Action item with owner and timeline]
3. [Action item with owner and timeline]

---

## Review Sign-off

- **Reviewed by:** [Name]
- **Date:** [Date]
- **Approved for implementation:** [ ] Yes [ ] No [ ] Partial
- **Follow-up review needed:** [ ] Yes [ ] No
- **Notes:** [Any additional context]

## Output

- MD file called `CODE_REVIEW_YYYY-MM-DD` where the date is the date the review was conducted
