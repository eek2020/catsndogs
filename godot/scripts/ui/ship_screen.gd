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


const CREW_ROLES := ["first_mate", "gunner", "navigator", "surgeon"]


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
	crew_header.text = "— Crew (%d/%d) —" % [ship.crew.size(), ship.crew_capacity]
	crew_header.add_theme_color_override("font_color", Color(0.7, 0.84, 1.0))
	crew_list.add_child(crew_header)
	# Show recruited crew members with details
	var filled_roles: Dictionary = {}
	for c in ship.crew:
		filled_roles[c.role] = true
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var role_lbl := Label.new()
		role_lbl.text = "[%s]" % c.role.replace("_", " ").to_upper()
		role_lbl.custom_minimum_size.x = 120
		role_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		row.add_child(role_lbl)
		var name_lbl := Label.new()
		name_lbl.text = c.crew_name
		name_lbl.custom_minimum_size.x = 120
		row.add_child(name_lbl)
		var morale_lbl := Label.new()
		var morale_color := Color(0.43, 0.83, 0.49) if c.morale >= 60 else Color(0.88, 0.39, 0.39)
		morale_lbl.text = "Morale: %d (%s)" % [c.morale, CrewMoraleSystem.morale_label(c.morale)]
		morale_lbl.add_theme_color_override("font_color", morale_color)
		row.add_child(morale_lbl)
		crew_list.add_child(row)
		# Show trait description below
		if GameSession.crew_trait_system != null:
			var defn: Dictionary = GameSession.crew_trait_system.get_definition(c.crew_id)
			var trait_desc: String = defn.get("trait_description", "")
			if not trait_desc.is_empty():
				var trait_lbl := Label.new()
				trait_lbl.text = "    ↳ %s" % trait_desc
				trait_lbl.add_theme_color_override("font_color", Color(0.55, 0.7, 0.55))
				crew_list.add_child(trait_lbl)
	# Show empty slots for unfilled roles
	for role in CREW_ROLES:
		if not filled_roles.has(role):
			var empty_lbl := Label.new()
			empty_lbl.text = "[%s]  ?  — Recruitment mission available" % role.replace("_", " ").to_upper()
			empty_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
			crew_list.add_child(empty_lbl)


func _on_close() -> void:
	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()
