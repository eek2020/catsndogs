## Controls rebind overlay — shows every rebindable action with its current
## keyboard and joypad bindings and lets the player replace either. All
## InputMap access routes through InputRebindViewModel; tests cover the VM,
## and the scene itself stays thin (row construction + capture flow only).
extends Control

@onready var action_list: VBoxContainer = $Panel/VBox/ScrollContainer/ActionList
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var reset_btn: Button = $Panel/VBox/ButtonRow/ResetBtn
@onready var back_btn: Button = $Panel/VBox/ButtonRow/BackBtn

var _vm: InputRebindViewModel
var _capturing_action: String = ""
var _capturing_kind: String = ""  # "keyboard" or "joypad"
var _row_buttons: Dictionary = {}  # action -> {"keyboard": Button, "joypad": Button}


func initialize(vm: InputRebindViewModel) -> void:
	_vm = vm


func _ready() -> void:
	if _vm == null:
		_vm = InputRebindViewModel.new()
	_build_rows()
	reset_btn.pressed.connect(_on_reset)
	back_btn.pressed.connect(_on_back)
	back_btn.grab_focus()
	status_label.text = ""


func _build_rows() -> void:
	for child in action_list.get_children():
		child.queue_free()
	_row_buttons.clear()
	for action in InputRebindViewModel.REBINDABLE_ACTIONS:
		_add_action_row(action)


func _add_action_row(action: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var label := Label.new()
	label.text = action.replace("_", " ").capitalize()
	label.custom_minimum_size = Vector2(160, 0)
	row.add_child(label)

	var kb_btn := Button.new()
	kb_btn.custom_minimum_size = Vector2(140, 0)
	kb_btn.pressed.connect(_on_rebind.bind(action, "keyboard"))
	row.add_child(kb_btn)

	var joy_btn := Button.new()
	joy_btn.custom_minimum_size = Vector2(140, 0)
	joy_btn.pressed.connect(_on_rebind.bind(action, "joypad"))
	row.add_child(joy_btn)

	_row_buttons[action] = {"keyboard": kb_btn, "joypad": joy_btn}
	_refresh_row(action)
	action_list.add_child(row)


func _refresh_row(action: String) -> void:
	if not _row_buttons.has(action):
		return
	var kb_ev := _vm.primary_keyboard_event(action)
	var joy_ev := _vm.primary_joypad_event(action)
	_row_buttons[action]["keyboard"].text = _vm.describe_event(kb_ev)
	_row_buttons[action]["joypad"].text = _vm.describe_event(joy_ev)


func _on_rebind(action: String, kind: String) -> void:
	_capturing_action = action
	_capturing_kind = kind
	status_label.text = "Press a %s input for '%s'…  (ESC to cancel)" % [kind, action]
	_set_rows_disabled(true)


func _cancel_capture() -> void:
	_capturing_action = ""
	_capturing_kind = ""
	status_label.text = ""
	_set_rows_disabled(false)


func _set_rows_disabled(disabled: bool) -> void:
	for entry in _row_buttons.values():
		entry["keyboard"].disabled = disabled
		entry["joypad"].disabled = disabled
	reset_btn.disabled = disabled
	back_btn.disabled = disabled


func _unhandled_input(event: InputEvent) -> void:
	if _capturing_action.is_empty():
		return
	if event is InputEventKey:
		if not event.pressed or event.echo:
			return
		if event.keycode == KEY_ESCAPE:
			_cancel_capture()
			get_viewport().set_input_as_handled()
			return
		if _capturing_kind == "keyboard":
			var captured := InputEventKey.new()
			captured.keycode = event.keycode
			_vm.set_keyboard_binding(_capturing_action, captured)
			_refresh_row(_capturing_action)
			_cancel_capture()
			get_viewport().set_input_as_handled()
		return
	if _capturing_kind != "joypad":
		return
	if event is InputEventJoypadButton and event.pressed:
		var btn := InputEventJoypadButton.new()
		btn.button_index = event.button_index
		_vm.set_joypad_binding(_capturing_action, btn)
		_refresh_row(_capturing_action)
		_cancel_capture()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion and absf(event.axis_value) >= 0.7:
		var motion := InputEventJoypadMotion.new()
		motion.axis = event.axis
		motion.axis_value = 1.0 if event.axis_value > 0.0 else -1.0
		_vm.set_joypad_binding(_capturing_action, motion)
		_refresh_row(_capturing_action)
		_cancel_capture()
		get_viewport().set_input_as_handled()


func _on_reset() -> void:
	_vm.reset_to_defaults()
	for action in InputRebindViewModel.REBINDABLE_ACTIONS:
		_refresh_row(action)
	status_label.text = "Reset to defaults."


func _on_back() -> void:
	if not _capturing_action.is_empty():
		_cancel_capture()
		return
	_vm.save()
	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()
