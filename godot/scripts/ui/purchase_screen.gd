## Purchase/shipyard overlay — repair hull, buy upgrades.
## Mirrors Python ui/purchase_screen.py PurchaseScreenState.
extends Control

@onready var info_label: Label = $Panel/VBox/InfoLabel
@onready var repair_btn: Button = $Panel/VBox/RepairBtn
@onready var close_btn: Button = $Panel/VBox/CloseBtn


func _ready() -> void:
	repair_btn.pressed.connect(_on_repair)
	close_btn.pressed.connect(_on_close)
	close_btn.grab_focus()
	_refresh()


func _on_repair() -> void:
	if GameSession.game_state == null:
		return
	GameSession.economy_system.repair_ship(GameSession.game_state, 25)
	_refresh()


func _on_close() -> void:
	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()


func _refresh() -> void:
	var gs: GameStateData = GameSession.game_state
	if gs == null:
		return
	info_label.text = "Salvage: %d | Hull: %d/%d" % [
		gs.salvage,
		gs.player_ship.current_hull if gs.player_ship else 0,
		gs.player_ship.max_hull if gs.player_ship else 0,
	]
