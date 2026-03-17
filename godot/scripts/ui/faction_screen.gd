## Faction standings overlay — shows all faction reputations.
## Mirrors Python ui/faction_screen.py FactionScreenState.
extends Control

@onready var faction_list: VBoxContainer = $Panel/VBox/FactionList
@onready var close_btn: Button = $Panel/VBox/CloseBtn


func _ready() -> void:
	close_btn.pressed.connect(_on_close)
	close_btn.grab_focus()
	_build_list()


func _build_list() -> void:
	for child in faction_list.get_children():
		child.queue_free()
	var standings: Array = GameSession.faction_system.get_all_standings(GameSession.game_state)
	for s in standings:
		var lbl := Label.new()
		lbl.text = "%s  [%d]  %s" % [s["name"], s["reputation"], _state_label(s["state"])]
		faction_list.add_child(lbl)


static func _state_label(state: int) -> String:
	match state:
		0: return "Hostile"
		1: return "Unfriendly"
		2: return "Neutral"
		3: return "Friendly"
		4: return "Allied"
		_: return "Unknown"


func _on_close() -> void:
	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()
