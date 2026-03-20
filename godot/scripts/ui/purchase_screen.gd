## Purchase/shipyard overlay — repair hull, buy upgrades, purchase ships.
## Mirrors Python ui/purchase_screen.py PurchaseScreenState.
extends Control

@onready var ship_preview: TextureRect = $Panel/MarginContainer/HBox/LeftPanel/VBox/ShipPreview
@onready var ship_name_label: Label = $Panel/MarginContainer/HBox/LeftPanel/VBox/ShipNameLabel
@onready var info_label: Label = $Panel/MarginContainer/HBox/LeftPanel/VBox/InfoLabel
@onready var ship_stats_label: Label = $Panel/MarginContainer/HBox/LeftPanel/VBox/ShipStatsLabel
@onready var repair_btn: Button = $Panel/MarginContainer/HBox/LeftPanel/VBox/RepairBtn
@onready var upgrade_list: VBoxContainer = $Panel/MarginContainer/HBox/RightPanel/VBox/ScrollContainer/UpgradeList
@onready var ship_list: VBoxContainer = $Panel/MarginContainer/HBox/RightPanel/VBox/ShipList
@onready var close_btn: Button = $Panel/MarginContainer/HBox/LeftPanel/VBox/CloseBtn

var _upgrade_data: Array = []
var _ship_data: Array = []


func _ready() -> void:
	repair_btn.pressed.connect(_on_repair)
	close_btn.pressed.connect(_on_close)
	_upgrade_data = GameSession.data_loader.load_upgrades()
	_ship_data = GameSession.data_loader.load_purchasable_ships()
	_refresh()
	close_btn.grab_focus()


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
	var ship: Ship = gs.player_ship
	# Ship preview image
	_update_ship_preview(ship)
	# Ship name
	if ship:
		ship_name_label.text = "%s (%s)" % [ship.ship_name, ship.ship_class.replace("_", " ").capitalize()]
	else:
		ship_name_label.text = "No Ship"
	info_label.text = "Crystals: %d  |  Salvage: %d  |  Hull: %d/%d" % [
		gs.crystal_inventory,
		gs.salvage,
		ship.current_hull if ship else 0,
		ship.max_hull if ship else 0,
	]
	if ship:
		ship_stats_label.text = "Speed: %d  |  Armour: %d  |  Firepower: %d  |  Cargo: %d  |  Crew: %d" % [
			ship.speed, ship.armour, ship.firepower, ship.crystal_capacity, ship.crew_capacity,
		]
	# Repair button label with cost
	if ship and ship.current_hull < ship.max_hull:
		var repair_amount: int = mini(25, ship.max_hull - ship.current_hull)
		var cost: int = GameSession.economy_system.calculate_repair_cost(ship, repair_amount)
		repair_btn.text = "Repair Hull (+%d HP) — %d salvage" % [repair_amount, cost]
		repair_btn.disabled = gs.salvage < cost
	else:
		repair_btn.text = "Hull at maximum"
		repair_btn.disabled = true
	_build_ship_list()
	_build_upgrade_list()


func _update_ship_preview(ship: Ship) -> void:
	"""Load and display the current ship's sprite."""
	if ship == null or ship.sprite_id.is_empty():
		ship_preview.texture = null
		return
	var path := "res://assets/%s" % ship.sprite_id
	if ResourceLoader.exists(path):
		ship_preview.texture = load(path)
	else:
		ship_preview.texture = null


func _build_ship_list() -> void:
	"""Populate the ships-for-sale section."""
	for child in ship_list.get_children():
		child.queue_free()
	var gs: GameStateData = GameSession.game_state
	if gs == null or gs.player_ship == null:
		return
	if _ship_data.is_empty():
		var label := Label.new()
		label.text = "No ships for sale"
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		ship_list.add_child(label)
		return
	for tmpl in _ship_data:
		var tid: String = tmpl.get("template_id", "")
		var tname: String = tmpl.get("name", tid)
		var cost_c: int = tmpl.get("cost_crystals", 0)
		var cost_s: int = tmpl.get("cost_salvage", 0)
		var bs: Dictionary = tmpl.get("base_stats", {})
		var is_current: bool = gs.player_ship.ship_class == tid

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Ship sprite thumbnail
		var sprite_id: String = tmpl.get("sprite_id", "")
		if not sprite_id.is_empty():
			var thumb := TextureRect.new()
			thumb.custom_minimum_size = Vector2(48, 48)
			thumb.expand_mode = 3  # FIT_WIDTH_PROPORTIONAL
			thumb.stretch_mode = 5  # KEEP_ASPECT_CENTERED
			var tex_path := "res://assets/%s" % sprite_id
			if ResourceLoader.exists(tex_path):
				thumb.texture = load(tex_path)
			row.add_child(thumb)

		if is_current:
			var owned_label := Label.new()
			owned_label.text = "%s — CURRENT SHIP" % tname
			owned_label.add_theme_color_override("font_color", Color(0.4, 0.7, 0.4))
			owned_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(owned_label)
			ship_list.add_child(row)
			continue

		# Ship name + stats summary
		var desc_label := Label.new()
		desc_label.text = "%s  (Spd:%d Arm:%d Fp:%d Hull:%d)" % [
			tname,
			bs.get("speed", 0),
			bs.get("armour", 0),
			bs.get("firepower", 0),
			tmpl.get("max_hull", 0),
		]
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
		row.add_child(desc_label)

		# Cost label
		var cost_label := Label.new()
		cost_label.text = "%dC %dS" % [cost_c, cost_s]
		cost_label.custom_minimum_size.x = 80
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var can_afford: bool = gs.crystal_inventory >= cost_c and gs.salvage >= cost_s
		cost_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.9) if can_afford else Color(0.7, 0.3, 0.3))
		row.add_child(cost_label)

		# Buy button
		var buy_btn := Button.new()
		buy_btn.text = "Buy"
		buy_btn.custom_minimum_size.x = 60
		buy_btn.disabled = not can_afford
		buy_btn.pressed.connect(_on_buy_ship.bind(tmpl))
		row.add_child(buy_btn)

		ship_list.add_child(row)


func _build_upgrade_list() -> void:
	"""Populate the upgrade list with available upgrades."""
	for child in upgrade_list.get_children():
		child.queue_free()
	var gs: GameStateData = GameSession.game_state
	if gs == null or gs.player_ship == null:
		return
	var ship: Ship = gs.player_ship
	# Collect already-installed upgrade IDs
	var installed: Dictionary = {}
	for u in ship.upgrades:
		installed[u.upgrade_id] = true
	if _upgrade_data.is_empty():
		var label := Label.new()
		label.text = "No upgrades available"
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		upgrade_list.add_child(label)
		return
	for upgrade in _upgrade_data:
		var uid: String = upgrade.get("upgrade_id", "")
		var uname: String = upgrade.get("name", uid)
		var target_stat: String = upgrade.get("target_stat", "")
		var modifier: int = upgrade.get("modifier", 0)
		var cost_crystals: int = upgrade.get("cost_crystals", 0)
		var cost_salvage: int = upgrade.get("cost_salvage", 0)
		var side_effect: Dictionary = upgrade.get("side_effect", {})

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Already installed?
		if installed.has(uid):
			var installed_label := Label.new()
			installed_label.text = "%s — INSTALLED" % uname
			installed_label.add_theme_color_override("font_color", Color(0.4, 0.7, 0.4))
			installed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(installed_label)
			upgrade_list.add_child(row)
			continue

		# Effect description
		var sign_str: String = "+" if modifier > 0 else ""
		var effect_text := "%s%d %s" % [sign_str, modifier, target_stat.replace("_", " ")]
		if not side_effect.is_empty():
			var se_mod: int = side_effect.get("modifier", 0)
			var se_sign: String = "+" if se_mod > 0 else ""
			effect_text += ", %s%d %s" % [se_sign, se_mod, side_effect.get("target_stat", "").replace("_", " ")]

		var desc_label := Label.new()
		desc_label.text = "%s  (%s)" % [uname, effect_text]
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
		row.add_child(desc_label)

		# Cost label
		var cost_label := Label.new()
		cost_label.text = "%dC %dS" % [cost_crystals, cost_salvage]
		cost_label.custom_minimum_size.x = 80
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var can_afford: bool = gs.crystal_inventory >= cost_crystals and gs.salvage >= cost_salvage
		cost_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.9) if can_afford else Color(0.7, 0.3, 0.3))
		row.add_child(cost_label)

		# Buy button
		var buy_btn := Button.new()
		buy_btn.text = "Buy"
		buy_btn.custom_minimum_size.x = 60
		buy_btn.disabled = not can_afford
		buy_btn.pressed.connect(_on_buy_upgrade.bind(upgrade))
		row.add_child(buy_btn)

		upgrade_list.add_child(row)


func _on_buy_ship(template: Dictionary) -> void:
	if GameSession.game_state == null:
		return
	if GameSession.economy_system.purchase_ship(GameSession.game_state, template):
		_refresh()


func _on_buy_upgrade(upgrade: Dictionary) -> void:
	if GameSession.game_state == null:
		return
	if GameSession.economy_system.purchase_upgrade(GameSession.game_state, upgrade):
		_refresh()
