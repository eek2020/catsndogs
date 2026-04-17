## Multi-slot save/load overlay. Opened from the pause menu; routes all
## SaveManager access through SaveLoadViewModel so tests can exercise the
## VM against a SessionDouble without touching disk.
##
## Mode is set by the caller (via `setup(mode)` before push) — "save" for
## writing to a slot, "load" for reading. Delete is available in both modes.
extends Control

@onready var title_label: Label = $Panel/VBox/Title
@onready var slot_rows: VBoxContainer = $Panel/VBox/SlotRows
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var back_btn: Button = $Panel/VBox/BackBtn

enum Mode { SAVE, LOAD }

var _vm: SaveLoadViewModel
var _mode: int = Mode.LOAD
var _row_buttons: Dictionary = {}  # slot -> {"action": Button, "delete": Button, "label": Label}


func setup(mode: int) -> void:
	_mode = mode


func initialize(vm: SaveLoadViewModel) -> void:
	_vm = vm


func _ready() -> void:
	if _vm == null:
		_vm = SaveLoadViewModel.new(GameSession)
	title_label.text = "SAVE GAME" if _mode == Mode.SAVE else "LOAD GAME"
	status_label.text = ""
	back_btn.pressed.connect(_on_back)
	_build_rows()
	back_btn.grab_focus()


func _build_rows() -> void:
	for child in slot_rows.get_children():
		child.queue_free()
	_row_buttons.clear()
	var info: Array = _vm.slot_info()
	for slot in range(SaveLoadViewModel.SLOT_COUNT):
		_add_slot_row(slot, info[slot] if slot < info.size() else null)


func _add_slot_row(slot: int, info: Variant) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var label := Label.new()
	var descriptor: String = SaveLoadViewModel.describe_slot(info)
	label.text = "Slot %d — %s" % [slot + 1, descriptor]
	label.custom_minimum_size = Vector2(320, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var action_btn := Button.new()
	action_btn.custom_minimum_size = Vector2(96, 32)
	if _mode == Mode.SAVE:
		action_btn.text = "Save"
		action_btn.disabled = not _vm.has_state()
	else:
		action_btn.text = "Load"
		action_btn.disabled = (info == null)
	action_btn.pressed.connect(_on_action.bind(slot))
	row.add_child(action_btn)

	var delete_btn := Button.new()
	delete_btn.custom_minimum_size = Vector2(80, 32)
	delete_btn.text = "Delete"
	delete_btn.disabled = (info == null)
	delete_btn.pressed.connect(_on_delete.bind(slot))
	row.add_child(delete_btn)

	_row_buttons[slot] = {"action": action_btn, "delete": delete_btn, "label": label}
	slot_rows.add_child(row)


func _refresh() -> void:
	_build_rows()


func _on_action(slot: int) -> void:
	var ok: bool = false
	if _mode == Mode.SAVE:
		ok = _vm.save_to_slot(slot)
		status_label.text = "Saved to slot %d." % (slot + 1) if ok else "Save failed."
		_refresh()
	else:
		ok = _vm.load_from_slot(slot)
		if ok:
			EventBus.load_game.emit()
			status_label.text = "Loading slot %d…" % (slot + 1)
			var main: Control = get_tree().current_scene
			if main != null and main.has_method("switch_scene"):
				main.switch_scene("navigation")
		else:
			status_label.text = "Load failed."


func _on_delete(slot: int) -> void:
	_vm.delete_slot(slot)
	status_label.text = "Deleted slot %d." % (slot + 1)
	_refresh()


func _on_back() -> void:
	var main: Control = get_tree().current_scene
	if main != null and main.has_method("pop_overlay"):
		main.pop_overlay()
