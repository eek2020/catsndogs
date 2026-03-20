# Issue Log

**Project:** Whisper Crystals
**Last Updated:** 2026-03-18

## Open Issues

| Issue ID | Title | Severity | Linked Task | Reported | Assigned |
| -------- | ----- | -------- | ----------- | -------- | -------- |
| — | No open issues | — | — | — | — |

## In Progress

| Issue ID | Title | Severity | Linked Task | Started | Assigned |
| -------- | ----- | -------- | ----------- | ------- | -------- |
| — | — | — | — | — | — |

## Closed

| Issue ID | Title | Severity | Resolved | Resolution |
| -------- | ----- | -------- | -------- | ---------- |
| ISSUE-001 | Character Selection Feature | High | 2026-03-18 | Dual-protagonist support implemented in Godot 4.6. See MASTER_PLAN § 5. |
| ISSUE-002 | Invalid access to 'theme_override_colors' on Label | High | 2026-03-18 | BUG-8: Replaced `theme_override_colors.font_color` with `add_theme_color_override()` in ship_screen.gd (5) and mission_log.gd (3). |
| BUG-9 | InputMap actions "menu_up"/"menu_down" don't exist | Medium | 2026-03-18 | Replaced with `ui_up`/`ui_down` in mission_log.gd. |
| BUG-10 | combat_overlay variable declared twice in dialogue_ui.gd | Low | 2026-03-18 | Renamed second declaration to `combat_screen`. |
| BUG-11 | Unused parameter warnings in game_session.gd | Low | 2026-03-18 | Prefixed `old_arc`, `faction_id`, `protagonist_id` with underscore. |
| BUG-12 | Local `is_contested` shadows method in realm_control_system.gd | Low | 2026-03-18 | Renamed local to `region_contested`. |
| BUG-13 | Variable `sign` shadows built-in in mission_log.gd | Low | 2026-03-18 | Renamed to `sign_prefix`. |
| BUG-14 | Unused `angle_deg` variable in navigation.gd | Low | 2026-03-18 | Prefixed with underscore. |
