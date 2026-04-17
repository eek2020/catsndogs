extends GutTest

## Regression: Mar-27 §2.4 — R-key collision between `menu_select` and `repair`.
## Both actions used to share keycode 82 (R); `repair` was rebound to T (84).
## This test guards against any two user-defined actions sharing a keycode
## going forward. Built-in ui_* actions are excluded because they're owned by
## Godot and legitimately share some keys with our bindings.


# Known, documented collisions that are intentional because the owning actions
# are context-separated (never active on the same screen). Any new pair landing
# here needs a MASTER_PLAN §5 entry justifying the overlap.
const KNOWN_CONTEXT_SEPARATED_COLLISIONS: Array[Array] = []


func _user_actions() -> Array[StringName]:
	var actions: Array[StringName] = []
	for action in InputMap.get_actions():
		var s := String(action)
		if s.begins_with("ui_"):
			continue
		actions.append(action)
	return actions


func _is_known_tolerated_pair(a: String, b: String) -> bool:
	for pair in KNOWN_CONTEXT_SEPARATED_COLLISIONS:
		if (pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a):
			return true
	return false


func test_no_unexpected_user_action_keycode_collisions() -> void:
	var seen: Dictionary = {}  # keycode -> owning action name
	var collisions: Array[String] = []
	for action in _user_actions():
		for event in InputMap.action_get_events(action):
			if not (event is InputEventKey):
				continue
			var key_event: InputEventKey = event
			var key: int = key_event.keycode
			if key == 0:
				continue  # physical-only binding; skip
			var action_name: String = String(action)
			if seen.has(key) and seen[key] != action_name:
				if _is_known_tolerated_pair(seen[key], action_name):
					continue
				collisions.append("keycode %d used by both '%s' and '%s'" % [key, seen[key], action_name])
			else:
				seen[key] = action_name
	assert_eq(collisions.size(), 0, "Input collisions: %s" % [collisions])


func test_menu_select_and_repair_have_distinct_keycodes() -> void:
	# Direct regression for the specific bug in the tracker.
	if not InputMap.has_action("menu_select") or not InputMap.has_action("repair"):
		pending("menu_select/repair actions not present in InputMap")
		return
	var menu_keys: Array[int] = []
	for ev in InputMap.action_get_events("menu_select"):
		if ev is InputEventKey and ev.keycode != 0:
			menu_keys.append(ev.keycode)
	var repair_keys: Array[int] = []
	for ev in InputMap.action_get_events("repair"):
		if ev is InputEventKey and ev.keycode != 0:
			repair_keys.append(ev.keycode)
	for k in menu_keys:
		assert_false(k in repair_keys, "menu_select and repair share keycode %d" % k)


func test_essential_actions_have_joypad_bindings() -> void:
	# Regression for Sprint 6b task 2: gamepad support.
	# Every action the player uses during normal play should have at least one
	# joypad event (button or axis) so the game is playable without a keyboard.
	# Niche actions (`repair`, `skip`) stay keyboard-only — `skip` rides on
	# `pause`'s Start button via cutscene.gd's fallback, `repair` is surfaced
	# via UI buttons in the ship/station screens.
	var essential: Array[String] = [
		"move_up", "move_down", "move_left", "move_right",
		"confirm", "cancel", "fire", "interact", "pause",
		"menu_select", "mission_log", "star_map",
	]
	for action in essential:
		if not InputMap.has_action(action):
			assert_true(false, "Essential action '%s' missing from InputMap" % action)
			continue
		var has_joy := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				has_joy = true
				break
		assert_true(has_joy, "Action '%s' has no joypad binding" % action)


func test_pause_and_skip_have_distinct_keycodes() -> void:
	# Regression for Sprint 6b ESC pause/skip fix.
	# Both actions used to share ESC (4194305). `skip` was rebound to X (88);
	# cutscene/intro_crawl handlers still accept `pause` so ESC keeps skipping
	# those scenes by user-facing behavior.
	if not InputMap.has_action("pause") or not InputMap.has_action("skip"):
		pending("pause/skip actions not present in InputMap")
		return
	var pause_keys: Array[int] = []
	for ev in InputMap.action_get_events("pause"):
		if ev is InputEventKey and ev.keycode != 0:
			pause_keys.append(ev.keycode)
	var skip_keys: Array[int] = []
	for ev in InputMap.action_get_events("skip"):
		if ev is InputEventKey and ev.keycode != 0:
			skip_keys.append(ev.keycode)
	for k in pause_keys:
		assert_false(k in skip_keys, "pause and skip share keycode %d" % k)
