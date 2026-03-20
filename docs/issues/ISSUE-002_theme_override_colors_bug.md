# Issue: ISSUE-002 — Invalid access to 'theme_override_colors' on Label

**Severity:** High
**Status:** Closed
**Reported:** 2026-03-18
**Linked Task:** BUG-8
**Assigned To:** Cascade

---

## Description

When selecting "Ship" from the menu, the game throws an error:

```text
Invalid access to property or key 'theme_override_colors' on a base object of type 'Label'.
```

In Godot 4, `theme_override_colors` is not a directly accessible dictionary property on Control nodes. The correct API is `add_theme_color_override("font_color", color)`.

The bug exists in two files:

- `scripts/ui/ship_screen.gd` — 5 occurrences (crew header, role labels, morale labels, trait labels, empty slot labels)
- `scripts/ui/mission_log.gd` — 3 occurrences (group header, selected button, unselected button)

## Steps to Reproduce

1. Start the game
2. Open the Ship screen (press Space)
3. Error: `Invalid access to property or key 'theme_override_colors' on a base object of type 'Label'.`

## Environment

- Godot 4.6
- GDScript
- macOS

## Files Affected

- `godot/scripts/ui/ship_screen.gd` — lines 37, 48, 57, 67, 74
- `godot/scripts/ui/mission_log.gd` — lines 134, 150, 155

## Proposed Fix

Replace all `label.theme_override_colors.font_color = Color(...)` with `label.add_theme_color_override("font_color", Color(...))`.

Similarly for Button nodes.

## Resolution

**Resolved:** 2026-03-18
**Fix:** Replaced all `label.theme_override_colors.font_color = Color(...)` with `label.add_theme_color_override("font_color", Color(...))` — the correct Godot 4 API. Fixed 5 occurrences in `ship_screen.gd` and 3 in `mission_log.gd`.
**Verified:** Ship screen and mission log should now open without errors.
