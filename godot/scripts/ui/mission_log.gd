## Mission log overlay — active and completed side missions.
## Mirrors Python ui/mission_log.py MissionLogState.
extends Control

@onready var mission_list: VBoxContainer = $Panel/VBox/MissionList
@onready var close_btn: Button = $Panel/VBox/CloseBtn


func _ready() -> void:
	close_btn.pressed.connect(_on_close)
	close_btn.grab_focus()
	_build_list()


func _build_list() -> void:
	for child in mission_list.get_children():
		child.queue_free()
	if GameSession.game_state == null:
		return
	var active: Array = GameSession.side_mission_system.get_active_missions(GameSession.game_state)
	var completed: Array = GameSession.side_mission_system.get_completed_missions(GameSession.game_state)
	if active.is_empty() and completed.is_empty():
		var lbl := Label.new()
		lbl.text = "No missions yet."
		mission_list.add_child(lbl)
		return
	if not active.is_empty():
		var header := Label.new()
		header.text = "— Active —"
		mission_list.add_child(header)
		for m in active:
			var lbl := Label.new()
			lbl.text = "%s  [%s]" % [m.title, m.mission_type]
			mission_list.add_child(lbl)
	if not completed.is_empty():
		var header := Label.new()
		header.text = "— Completed —"
		mission_list.add_child(header)
		for m in completed:
			var lbl := Label.new()
			lbl.text = "%s  [DONE]" % m.title
			mission_list.add_child(lbl)


func _on_close() -> void:
	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()
