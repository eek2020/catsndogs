## InputRebindViewModel — wraps InputMap + ConfigFile persistence for the
## controls-rebind screen. Tests construct a VM with a FakeInputApi double
## (any object exposing has_action / action_get_events / action_erase_events /
## action_add_event) so the VM can be exercised headlessly without touching
## the real engine InputMap. Pattern matches NavigationViewModel / StarMapVM
## from CODE_REVIEW.md §2.1.
class_name InputRebindViewModel
extends RefCounted

# Actions surfaced in the rebind UI, in display order. `skip` ships keyboard-only
# (X by default) because cutscene handlers also accept `pause`, so Start on a
# gamepad already skips. `repair` stays keyboard-only for the same reason ship
# screens surface it as a button.
const REBINDABLE_ACTIONS: Array[String] = [
	"move_up", "move_down", "move_left", "move_right",
	"fire", "interact", "confirm", "cancel", "pause",
	"menu_select", "mission_log", "star_map", "repair", "skip",
]

const SAVE_PATH := "user://input_bindings.cfg"

var _api  # duck-typed: has_action / action_get_events / action_erase_events / action_add_event
# action name → Array[InputEvent] captured at VM construction, BEFORE any load()
var _defaults: Dictionary = {}


func _init(api = null) -> void:
	_api = api if api != null else _DefaultApi.new()
	_snapshot_defaults()


func _snapshot_defaults() -> void:
	for action in REBINDABLE_ACTIONS:
		if _api.has_action(action):
			var events: Array = _api.action_get_events(action)
			var copy: Array[InputEvent] = []
			for ev in events:
				copy.append(ev)
			_defaults[action] = copy


# ---------------------------------------------------------------------------
# Read helpers
# ---------------------------------------------------------------------------

func primary_keyboard_event(action: String) -> InputEventKey:
	if not _api.has_action(action):
		return null
	for ev in _api.action_get_events(action):
		if ev is InputEventKey:
			return ev
	return null


func primary_joypad_event(action: String) -> InputEvent:
	if not _api.has_action(action):
		return null
	for ev in _api.action_get_events(action):
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			return ev
	return null


# ---------------------------------------------------------------------------
# Write helpers — replace the FIRST event of the matching type, or append if
# no event of that type exists yet.
# ---------------------------------------------------------------------------

func set_keyboard_binding(action: String, event: InputEventKey) -> void:
	_replace_first_of_type(action, event, [InputEventKey])


func set_joypad_binding(action: String, event: InputEvent) -> void:
	_replace_first_of_type(action, event, [InputEventJoypadButton, InputEventJoypadMotion])


func _replace_first_of_type(action: String, event: InputEvent, types: Array) -> void:
	if not _api.has_action(action) or event == null:
		return
	var existing: Array = _api.action_get_events(action)
	var rebuilt: Array[InputEvent] = []
	var inserted := false
	for ev in existing:
		var matches := false
		for t in types:
			if is_instance_of(ev, t):
				matches = true
				break
		if matches and not inserted:
			rebuilt.append(event)
			inserted = true
		else:
			rebuilt.append(ev)
	if not inserted:
		rebuilt.append(event)
	_api.action_erase_events(action)
	for ev in rebuilt:
		_api.action_add_event(action, ev)


# ---------------------------------------------------------------------------
# Reset + persistence
# ---------------------------------------------------------------------------

func reset_to_defaults() -> void:
	for action in REBINDABLE_ACTIONS:
		if not _defaults.has(action):
			continue
		_api.action_erase_events(action)
		for ev in _defaults[action]:
			_api.action_add_event(action, ev)


func save(path: String = SAVE_PATH) -> Error:
	var cfg := ConfigFile.new()
	for action in REBINDABLE_ACTIONS:
		if not _api.has_action(action):
			continue
		var serialized: Array = []
		for ev in _api.action_get_events(action):
			var dict := _serialize_event(ev)
			if not dict.is_empty():
				serialized.append(dict)
		cfg.set_value(action, "events", serialized)
	return cfg.save(path)


func load(path: String = SAVE_PATH) -> Error:
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err != OK:
		return err
	for action in REBINDABLE_ACTIONS:
		if not cfg.has_section(action) or not _api.has_action(action):
			continue
		var serialized: Array = cfg.get_value(action, "events", [])
		_api.action_erase_events(action)
		for dict in serialized:
			var ev := _deserialize_event(dict)
			if ev != null:
				_api.action_add_event(action, ev)
	return OK


# ---------------------------------------------------------------------------
# Serialization — hand-rolled dict form avoids engine-specific resource
# encoding and keeps tests clean.
# ---------------------------------------------------------------------------

func _serialize_event(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"type": "key", "keycode": ev.keycode}
	if ev is InputEventJoypadButton:
		return {"type": "joy_button", "button_index": ev.button_index}
	if ev is InputEventJoypadMotion:
		return {"type": "joy_motion", "axis": ev.axis, "axis_value": ev.axis_value}
	return {}


func _deserialize_event(dict: Dictionary) -> InputEvent:
	match dict.get("type", ""):
		"key":
			var ev := InputEventKey.new()
			ev.keycode = int(dict.get("keycode", 0))
			return ev
		"joy_button":
			var ev := InputEventJoypadButton.new()
			ev.button_index = int(dict.get("button_index", 0))
			return ev
		"joy_motion":
			var ev := InputEventJoypadMotion.new()
			ev.axis = int(dict.get("axis", 0))
			ev.axis_value = float(dict.get("axis_value", 0.0))
			return ev
	return null


# ---------------------------------------------------------------------------
# Human-readable labels for UI.
# ---------------------------------------------------------------------------

func describe_event(ev: InputEvent) -> String:
	if ev == null:
		return "(unbound)"
	if ev is InputEventKey:
		return OS.get_keycode_string(ev.keycode)
	if ev is InputEventJoypadButton:
		return _joypad_button_label(ev.button_index)
	if ev is InputEventJoypadMotion:
		return _joypad_axis_label(ev.axis, ev.axis_value)
	return "?"


func _joypad_button_label(idx: int) -> String:
	match idx:
		0: return "A"
		1: return "B"
		2: return "X"
		3: return "Y"
		4: return "Back"
		5: return "Guide"
		6: return "Start"
		7: return "L3"
		8: return "R3"
		9: return "LB"
		10: return "RB"
		11: return "D-pad Up"
		12: return "D-pad Down"
		13: return "D-pad Left"
		14: return "D-pad Right"
	return "Btn %d" % idx


func _joypad_axis_label(axis: int, value: float) -> String:
	var direction := "+" if value > 0.0 else "-"
	match axis:
		0: return "L-Stick " + ("Right" if value > 0.0 else "Left")
		1: return "L-Stick " + ("Down" if value > 0.0 else "Up")
		2: return "R-Stick " + ("Right" if value > 0.0 else "Left")
		3: return "R-Stick " + ("Down" if value > 0.0 else "Up")
		4: return "L-Trigger"
		5: return "R-Trigger"
	return "Axis %d%s" % [axis, direction]


# ---------------------------------------------------------------------------
# Default wrapper around the engine InputMap. Tests pass their own double.
# ---------------------------------------------------------------------------

class _DefaultApi:
	extends RefCounted

	func has_action(action: StringName) -> bool:
		return InputMap.has_action(action)

	func action_get_events(action: StringName) -> Array:
		return InputMap.action_get_events(action)

	func action_erase_events(action: StringName) -> void:
		InputMap.action_erase_events(action)

	func action_add_event(action: StringName, event: InputEvent) -> void:
		InputMap.action_add_event(action, event)
