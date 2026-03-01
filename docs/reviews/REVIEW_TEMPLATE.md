# Code Review: REVIEW-{NNN}

**Task:** {Task ID and title}
**Reviewer:** {Model/Agent}
**Date:** {YYYY-MM-DD}
**Status:** PASS / FAIL / PASS WITH NOTES

---

## Files Changed

| File | Action | Lines Changed |
| ---- | ------ | ------------- |
| `path/to/file.py` | Modified / Created / Deleted | +NN / -NN |

---

## Checklist

- [ ] All tests pass (`pytest tests/ -v`)
- [ ] No pygame imports in `core/`, `systems/`, or `entities/`
- [ ] No `hasattr(renderer, "screen")` checks in UI code
- [ ] New code has type hints on public functions
- [ ] New classes have docstrings
- [ ] Entity serialization (to_dict/from_dict) maintained if entities changed
- [ ] Save file schema backward-compatible (if applicable)
- [ ] No hardcoded game content in Python source
- [ ] Event bus used for cross-system communication (no direct system-to-system calls)

---

## Test Results

```text
{Paste pytest output here}
```

---

## EAL Compliance Check

```text
{Paste output of: grep -r "import pygame" src/whisper_crystals/core/ src/whisper_crystals/systems/ src/whisper_crystals/entities/}
```

---

## Issues Found

| Severity | Description | Recommendation |
| -------- | ----------- | -------------- |
| — | — | — |

---

## Notes

{Any additional observations, suggestions, or concerns}
