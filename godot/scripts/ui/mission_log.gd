## Mission log overlay — active and completed side missions.
## Mirrors Python ui/mission_log.py MissionLogState.
extends Control

@onready var mission_list: VBoxContainer = $Panel/VBox/MissionList
@onready var close_btn: Button = $Panel/VBox/CloseBtn

var _all_missions: Array[SideMission] = []
var _selected_idx: int = -1
var _entry_buttons: Array[Button] = []
var _detail_label: RichTextLabel = null

const STATUS_COLORS := {
	"active": "#dca245",
	"available": "#7f98bb",
	"completed": "#6fd37d",
	"failed": "#e06363",
}


func _ready() -> void:
	close_btn.pressed.connect(_on_close)
	_build_list()
	close_btn.grab_focus()


func _build_list() -> void:
	for child in mission_list.get_children():
		child.queue_free()
	_entry_buttons.clear()
	_selected_idx = -1
	if GameSession.game_state == null:
		var empty_lbl := Label.new()
		empty_lbl.text = "No mission data available."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mission_list.add_child(empty_lbl)
		return

	var status_order := {
		"active": 0,
		"available": 1,
		"completed": 2,
		"failed": 3,
	}
	_all_missions = []
	for mission in GameSession.game_state.side_missions.values():
		_all_missions.append(mission)
	_all_missions.sort_custom(func(a: SideMission, b: SideMission) -> bool:
		var a_is_main: bool = a.mission_type.to_lower() == "main" or a.mission_id.to_lower().begins_with("main_")
		var b_is_main: bool = b.mission_type.to_lower() == "main" or b.mission_id.to_lower().begins_with("main_")
		var a_is_crew: bool = a.mission_type == "crew_recruitment"
		var b_is_crew: bool = b.mission_type == "crew_recruitment"
		# Sort order: main > crew > side
		var a_group: int = 0 if a_is_main else (1 if a_is_crew else 2)
		var b_group: int = 0 if b_is_main else (1 if b_is_crew else 2)
		if a_group != b_group:
			return a_group < b_group
		var sa: int = status_order.get(a.status, 9)
		var sb: int = status_order.get(b.status, 9)
		if sa != sb:
			return sa < sb
		if a.priority != b.priority:
			return a.priority > b.priority
		return a.title.naturalnocasecmp_to(b.title) < 0
	)

	if _all_missions.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "No missions discovered yet."
		none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mission_list.add_child(none_lbl)
		return

	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 260
	mission_list.add_child(split)

	var left_scroller := ScrollContainer.new()
	left_scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(left_scroller)

	var left_box := VBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroller.add_child(left_box)

	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right_panel)

	_detail_label = RichTextLabel.new()
	_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_label.bbcode_enabled = true
	_detail_label.fit_content = false
	_detail_label.scroll_active = true
	right_panel.add_child(_detail_label)

	var has_main_header := false
	var has_crew_header := false
	var has_side_header := false
	for i in range(_all_missions.size()):
		var mission := _all_missions[i]
		var is_main: bool = mission.mission_type.to_lower() == "main" or mission.mission_id.to_lower().begins_with("main_")
		var is_crew: bool = mission.mission_type == "crew_recruitment"
		if is_main and not has_main_header:
			left_box.add_child(_build_group_header("MAIN MISSIONS"))
			has_main_header = true
		elif is_crew and not has_crew_header:
			left_box.add_child(_build_group_header("CREW MISSIONS"))
			has_crew_header = true
		elif not is_main and not is_crew and not has_side_header:
			left_box.add_child(_build_group_header("SIDE MISSIONS"))
			has_side_header = true

		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = "%s  [%s]" % [mission.title, mission.status.to_upper()]
		btn.pressed.connect(_on_select_mission.bind(i))
		left_box.add_child(btn)
		_entry_buttons.append(btn)

	_select_mission(0)


func _build_group_header(text: String) -> Label:
	var header := Label.new()
	header.text = text
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_theme_color_override("font_color", Color(0.7, 0.84, 1.0))
	return header


func _on_select_mission(index: int) -> void:
	_select_mission(index)


func _select_mission(index: int) -> void:
	if index < 0 or index >= _all_missions.size():
		return
	_selected_idx = index
	for i in range(_entry_buttons.size()):
		var btn := _entry_buttons[i]
		btn.modulate = Color(1, 1, 1, 1)
		if i == _selected_idx:
			btn.add_theme_color_override("font_color", Color(1.0, 0.93, 0.62))
			var tween := create_tween()
			tween.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 0.86), 0.09)
			tween.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.09)
		else:
			btn.add_theme_color_override("font_color", Color(0.86, 0.89, 0.95))

	_render_selected_details()


func _render_selected_details() -> void:
	if _detail_label == null or _selected_idx < 0 or _selected_idx >= _all_missions.size():
		return
	var mission: SideMission = _all_missions[_selected_idx]
	var color_hex: String = STATUS_COLORS.get(mission.status, "#9fb2cc")
	var lines: Array[String] = []
	lines.append("[font_size=26][b]%s[/b][/font_size]" % mission.title)
	lines.append("[color=%s][b]STATUS:[/b] %s[/color]" % [color_hex, mission.status.to_upper()])
	lines.append("[color=#a6c6f0][b]TYPE:[/b] %s[/color]" % mission.mission_type.to_upper())
	if not mission.region.is_empty():
		lines.append("[color=#9fb3cc][b]REGION:[/b] %s[/color]" % mission.region.replace("_", " ").capitalize())
	lines.append("")
	lines.append(mission.description)
	lines.append("")

	if not mission.objectives.is_empty():
		lines.append("[color=#8fdbff][b]OBJECTIVES[/b][/color]")
		for objective in mission.objectives:
			var marker := "[X]" if objective.completed else "[ ]"
			var obj_color := "#6fd37d" if objective.completed else "#e8eef8"
			lines.append("[color=%s]%s %s[/color]" % [obj_color, marker, objective.description])
		lines.append("")

	if not mission.rewards.is_empty() or not mission.faction_rewards.is_empty():
		lines.append("[color=#8fdbff][b]REWARDS[/b][/color]")
		for resource in mission.rewards.keys():
			lines.append("[color=#f2d27a]%s: +%s[/color]" % [str(resource).capitalize(), str(mission.rewards[resource])])
		for faction_id in mission.faction_rewards.keys():
			var delta: int = int(mission.faction_rewards[faction_id])
			var sign_prefix := "+" if delta >= 0 else ""
			var rep_color := "#76da83" if delta >= 0 else "#e27f7f"
			lines.append("[color=%s]%s: %s%d rep[/color]" % [rep_color, str(faction_id), sign_prefix, delta])

	_detail_label.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		if _selected_idx > 0:
			_select_mission(_selected_idx - 1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		if _selected_idx < _all_missions.size() - 1:
			_select_mission(_selected_idx + 1)
	elif event.is_action_pressed("cancel") or event.is_action_pressed("pause") or event.is_action_pressed("mission_log"):
		_on_close()


func _on_close() -> void:
	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()
