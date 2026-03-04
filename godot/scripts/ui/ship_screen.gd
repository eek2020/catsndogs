## Ship status overlay — hull, stats, crew roster.
## Mirrors Python ui/ship_screen.py ShipScreenState.
extends Control

@onready var ship_name_label: Label = $Panel/VBox/ShipName
@onready var hull_label: Label = $Panel/VBox/HullLabel
@onready var stats_label: Label = $Panel/VBox/StatsLabel
@onready var cargo_label: Label = $Panel/VBox/CargoLabel
@onready var crew_list: VBoxContainer = $Panel/VBox/CrewList
@onready var close_btn: Button = $Panel/VBox/CloseBtn


func _ready() -> void:
	close_btn.pressed.connect(_on_close)
	close_btn.grab_focus()
	_refresh()


func _refresh() -> void:
	var gs: GameStateData = GameSession.game_state
	if gs == null or gs.player_ship == null:
		return
	var ship: Ship = gs.player_ship
	ship_name_label.text = "Ship: %s (%s)" % [ship.ship_name, ship.ship_class]
	hull_label.text = "Hull: %d / %d" % [ship.current_hull, ship.max_hull]
	stats_label.text = "Speed: %d | Armour: %d | Firepower: %d" % [ship.speed, ship.armour, ship.firepower]
	var cap: Array = GameSession.economy_system.get_cargo_capacity(gs)
	cargo_label.text = "Cargo: %d / %d" % [cap[0], cap[1]]
	# Crew
	for child in crew_list.get_children():
		child.queue_free()
	var crew_header := Label.new()
	crew_header.text = "— Crew —"
	crew_list.add_child(crew_header)
	for c in ship.crew:
		var lbl := Label.new()
		lbl.text = "%s  Morale: %d  (%s)" % [c.crew_name, c.morale, CrewMoraleSystem.morale_label(c.morale)]
		crew_list.add_child(lbl)


func _on_close() -> void:
	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()
