extends GutTest

## Coverage for InputRebindViewModel (Sprint 6b task 3). Uses a FakeInputApi
## that mirrors the shape of the engine InputMap so tests don't mutate real
## bindings. The VM's `_snapshot_defaults()` runs in `_init`, so the defaults
## it reports are the ones present at the moment the VM is constructed.


class FakeInputApi:
	extends RefCounted
	var events: Dictionary = {}  # action -> Array[InputEvent]

	func seed(action: String, evs: Array) -> void:
		var copy: Array[InputEvent] = []
		for ev in evs:
			copy.append(ev)
		events[action] = copy

	func has_action(action: StringName) -> bool:
		return events.has(String(action))

	func action_get_events(action: StringName) -> Array:
		return events.get(String(action), [])

	func action_erase_events(action: StringName) -> void:
		events[String(action)] = []

	func action_add_event(action: StringName, event: InputEvent) -> void:
		var key := String(action)
		if not events.has(key):
			events[key] = []
		events[key].append(event)


func _make_key(keycode: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	return ev


func _make_joy_button(idx: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = idx
	return ev


func _make_joy_motion(axis: int, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	return ev


func _seed_default_api() -> FakeInputApi:
	var api := FakeInputApi.new()
	# Every rebindable action needs at least a stub so `has_action` returns true
	# when the VM's `_snapshot_defaults` walks the list.
	for action in InputRebindViewModel.REBINDABLE_ACTIONS:
		api.seed(action, [])
	# Populate the ones we exercise in tests.
	api.seed("move_up", [_make_key(87), _make_joy_button(11)])
	api.seed("fire", [_make_key(32), _make_joy_button(2)])
	api.seed("pause", [_make_key(4194305), _make_joy_button(6)])
	api.seed("move_left", [_make_joy_motion(0, -1.0)])
	return api


# ---------------------------------------------------------------------------

func test_primary_keyboard_event_returns_first_key() -> void:
	var api := _seed_default_api()
	var vm := InputRebindViewModel.new(api)
	var ev := vm.primary_keyboard_event("move_up")
	assert_not_null(ev)
	assert_eq(ev.keycode, 87)


func test_primary_keyboard_event_null_when_none() -> void:
	var api := _seed_default_api()
	var vm := InputRebindViewModel.new(api)
	assert_null(vm.primary_keyboard_event("move_left"))


func test_primary_joypad_event_returns_button() -> void:
	var api := _seed_default_api()
	var vm := InputRebindViewModel.new(api)
	var ev := vm.primary_joypad_event("fire")
	assert_true(ev is InputEventJoypadButton)
	assert_eq((ev as InputEventJoypadButton).button_index, 2)


func test_primary_joypad_event_returns_motion_when_only_axis() -> void:
	var api := _seed_default_api()
	var vm := InputRebindViewModel.new(api)
	var ev := vm.primary_joypad_event("move_left")
	assert_true(ev is InputEventJoypadMotion)
	assert_eq((ev as InputEventJoypadMotion).axis, 0)


func test_set_keyboard_binding_replaces_existing_key() -> void:
	var api := _seed_default_api()
	var vm := InputRebindViewModel.new(api)
	vm.set_keyboard_binding("move_up", _make_key(38))
	var evs: Array = api.events["move_up"]
	assert_eq(evs.size(), 2, "Expected keyboard replacement, not append")
	assert_eq((evs[0] as InputEventKey).keycode, 38)
	assert_true(evs[1] is InputEventJoypadButton, "Joypad event must survive")


func test_set_keyboard_binding_appends_when_none_exists() -> void:
	var api := _seed_default_api()
	var vm := InputRebindViewModel.new(api)
	vm.set_keyboard_binding("move_left", _make_key(65))
	var evs: Array = api.events["move_left"]
	assert_eq(evs.size(), 2)
	assert_true(evs[0] is InputEventJoypadMotion, "Original axis event first")
	assert_eq((evs[1] as InputEventKey).keycode, 65, "Key appended")


func test_set_joypad_binding_replaces_existing_button() -> void:
	var api := _seed_default_api()
	var vm := InputRebindViewModel.new(api)
	vm.set_joypad_binding("fire", _make_joy_button(3))
	var evs: Array = api.events["fire"]
	assert_eq(evs.size(), 2)
	assert_true(evs[0] is InputEventKey, "Key survives")
	assert_eq((evs[1] as InputEventJoypadButton).button_index, 3)


func test_reset_to_defaults_restores_snapshot() -> void:
	var api := _seed_default_api()
	var vm := InputRebindViewModel.new(api)
	vm.set_keyboard_binding("move_up", _make_key(99))
	vm.reset_to_defaults()
	var ev := vm.primary_keyboard_event("move_up")
	assert_not_null(ev)
	assert_eq(ev.keycode, 87, "Default restored")


func test_save_and_load_round_trip() -> void:
	var api := _seed_default_api()
	var vm := InputRebindViewModel.new(api)
	vm.set_keyboard_binding("move_up", _make_key(42))
	var path := "user://test_input_rebind_%d.cfg" % Time.get_ticks_usec()
	assert_eq(vm.save(path), OK)

	# New API that starts with the seeded defaults, then loads the saved file.
	var api2 := _seed_default_api()
	var vm2 := InputRebindViewModel.new(api2)
	assert_eq(vm2.load(path), OK)
	var ev := vm2.primary_keyboard_event("move_up")
	assert_not_null(ev)
	assert_eq(ev.keycode, 42)

	# Cleanup
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_load_returns_error_when_file_missing() -> void:
	var api := _seed_default_api()
	var vm := InputRebindViewModel.new(api)
	var err := vm.load("user://definitely_not_there_%d.cfg" % Time.get_ticks_usec())
	assert_ne(err, OK)


func test_describe_event_handles_all_kinds() -> void:
	var vm := InputRebindViewModel.new(_seed_default_api())
	assert_eq(vm.describe_event(null), "(unbound)")
	assert_eq(vm.describe_event(_make_joy_button(0)), "A")
	assert_eq(vm.describe_event(_make_joy_button(6)), "Start")
	assert_eq(vm.describe_event(_make_joy_motion(1, -1.0)), "L-Stick Up")
	assert_eq(vm.describe_event(_make_joy_motion(0, 1.0)), "L-Stick Right")


func test_rebindable_actions_list_covers_all_project_actions() -> void:
	# The rebind UI is the only surface users have for changing bindings; any
	# user-defined action omitted from REBINDABLE_ACTIONS becomes effectively
	# uneditable. This test keeps the list honest by walking the real InputMap.
	for action in InputMap.get_actions():
		var s := String(action)
		if s.begins_with("ui_"):
			continue
		assert_true(
			s in InputRebindViewModel.REBINDABLE_ACTIONS,
			"Action '%s' is in project.godot but missing from REBINDABLE_ACTIONS" % s
		)
